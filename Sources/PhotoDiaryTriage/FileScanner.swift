import Foundation

enum FileScannerMetadataMode {
    case full
    case fileAttributesOnly
}

struct FileScanner {
    let fileManager: FileManager
    let metadataExtractor: MetadataExtractor

    init(fileManager: FileManager = .default, metadataExtractor: MetadataExtractor = MetadataExtractor()) {
        self.fileManager = fileManager
        self.metadataExtractor = metadataExtractor
    }

    func scanFolder(
        _ folder: URL,
        settings: AppSettings,
        metadataMode: FileScannerMetadataMode = .full
    ) throws -> [MediaItem] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: Array(resourceKeys))!
        let baseFolder = folder.resolvingSymlinksInPath().standardizedFileURL
        var candidates: [ScanCandidate] = []
        var cropManifestURLs: [URL] = []
        var fileManifestURLs: [URL] = []

        for case let fileURL as URL in enumerator {
            try Task.checkCancellation()

            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            if fileURL.lastPathComponent.hasSuffix(".crops.json") {
                cropManifestURLs.append(fileURL)
                continue
            }
            if ext == "md" {
                fileManifestURLs.append(fileURL)
                continue
            }
            guard settings.supportedExtensions.contains(ext) else { continue }

            let relativePath = relativePath(for: fileURL, relativeTo: baseFolder)
            let fileSize = Int64(values.fileSize ?? 0)
            let baseName = fileURL.deletingPathExtension().lastPathComponent
            let relativeDirectory = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
            let mediaKind = mediaKind(for: ext)

            candidates.append(
                ScanCandidate(
                    sourceURL: fileURL,
                    relativePath: relativePath,
                    relativeDirectory: relativeDirectory,
                    fileName: fileURL.lastPathComponent,
                    baseName: baseName,
                    extensionName: ext,
                    fileSizeBytes: fileSize,
                    mediaKind: mediaKind,
                    contentModificationDate: values.contentModificationDate,
                    cropRelationship: nil
                )
            )
        }

        let cropRelationships = cropRelationships(
            for: candidates,
            manifestURLs: cropManifestURLs,
            baseFolder: baseFolder
        )
        let archiveFileManifests = archiveFileManifests(
            for: fileManifestURLs,
            baseFolder: baseFolder
        )
        for index in candidates.indices {
            candidates[index].cropRelationship = cropRelationships[canonicalPath(candidates[index].sourceURL)]
        }

        var items: [MediaItem] = []
        let groupedCandidates = Dictionary(grouping: candidates) { "\($0.relativeDirectory)|\($0.baseName.lowercased())" }

        for (_, group) in groupedCandidates {
            try Task.checkCancellation()

            let primary = primaryCandidate(in: group)
            let archiveManifest = archiveFileManifests[canonicalPath(primary.sourceURL)]
            let metadata = metadata(for: primary, mode: metadataMode, archiveManifest: archiveManifest)
            let companions = group
                .filter { $0.sourceURL != primary.sourceURL && $0.mediaKind == .raw }
                .map {
                    CompanionFile(
                        sourceURL: $0.sourceURL,
                        relativePath: $0.relativePath,
                        fileName: $0.fileName,
                        fileSizeBytes: $0.fileSizeBytes,
                        kind: $0.mediaKind
                    )
                }
                .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }

            items.append(
                MediaItem(
                    id: archiveManifest?.mediaItemID ?? UUID(),
                    sourceURL: primary.sourceURL,
                    relativePath: primary.relativePath,
                    fileName: primary.fileName,
                    baseName: primary.baseName,
                    mediaKind: primary.mediaKind,
                    fileSizeBytes: primary.fileSizeBytes,
                    capturedAt: metadata.capturedAt,
                    metadata: metadata,
                    thumbnailCacheKey: archiveManifest?.thumbnailCacheKey ?? CacheKeyBuilder.key(for: primary.sourceURL),
                    companionFiles: companions,
                    destinationURL: archiveManifest == nil ? nil : primary.sourceURL,
                    archiveRelativePath: archiveManifest?.archiveRelativePath,
                    cropRelationship: primary.cropRelationship
                )
            )
        }

        return MediaItemSort.sorted(items)
    }

    private func mediaKind(for extensionName: String) -> MediaKind {
        if ["jpg", "jpeg"].contains(extensionName) {
            return .jpeg
        }
        if ["cr2", "cr3", "dng", "raf", "nef"].contains(extensionName) {
            return .raw
        }
        return .other
    }

    private func primaryCandidate(in group: [ScanCandidate]) -> ScanCandidate {
        group.sorted { lhs, rhs in
            priority(for: lhs.mediaKind, ext: lhs.extensionName) < priority(for: rhs.mediaKind, ext: rhs.extensionName)
        }.first!
    }

    private func priority(for kind: MediaKind, ext: String) -> Int {
        switch kind {
        case .jpeg:
            return ext == "jpg" ? 0 : 1
        case .other:
            return 2
        case .raw:
            return 3
        }
    }

    private func relativePath(for fileURL: URL, relativeTo folder: URL) -> String {
        let resolvedFileURL = fileURL.resolvingSymlinksInPath().standardizedFileURL
        let folderComponents = folder.pathComponents
        let fileComponents = resolvedFileURL.pathComponents

        if fileComponents.starts(with: folderComponents) {
            return fileComponents.dropFirst(folderComponents.count).joined(separator: "/")
        }

        return resolvedFileURL.lastPathComponent
    }

    private func metadata(
        for candidate: ScanCandidate,
        mode: FileScannerMetadataMode,
        archiveManifest: ArchiveFileManifest?
    ) -> MediaMetadata {
        switch mode {
        case .full:
            return metadataExtractor.extract(from: candidate.sourceURL)
        case .fileAttributesOnly:
            return MediaMetadata(
                capturedAt: archiveManifest?.capturedAt ?? candidate.contentModificationDate,
                pixelWidth: archiveManifest?.pixelWidth,
                pixelHeight: archiveManifest?.pixelHeight,
                cameraModel: archiveManifest?.cameraModel,
                lensModel: archiveManifest?.lensModel,
                latitude: archiveManifest?.latitude,
                longitude: archiveManifest?.longitude,
                raw: [:]
            )
        }
    }

    private func cropRelationships(
        for candidates: [ScanCandidate],
        manifestURLs: [URL],
        baseFolder: URL
    ) -> [String: CropRelationship] {
        let candidatesByPath = Dictionary(uniqueKeysWithValues: candidates.map { (canonicalPath($0.sourceURL), $0) })
        var relationships: [String: CropRelationship] = [:]
        let decoder = JSONDecoder()

        for manifestURL in manifestURLs {
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? decoder.decode(CropManifest.self, from: data) else { continue }

            let manifestFolder = manifestURL.deletingLastPathComponent()
            let sourceURL = URL(fileURLWithPath: manifest.sourcePath)
            let sourceCandidate = candidatesByPath[canonicalPath(sourceURL)]
                ?? candidatesByPath[canonicalPath(manifestFolder.appendingPathComponent(manifest.sourceFileName))]
            guard let sourceCandidate else { continue }

            let cropCandidates = manifest.crops.compactMap { entry -> ScanCandidate? in
                let outputURL = URL(fileURLWithPath: entry.outputPath)
                if let candidate = candidatesByPath[canonicalPath(outputURL)] {
                    return candidate
                }
                return candidatesByPath[canonicalPath(manifestFolder.appendingPathComponent(entry.outputFileName))]
            }
            guard !cropCandidates.isEmpty else { continue }

            let manifestRelativePath = relativePath(for: manifestURL, relativeTo: baseFolder)
            let cropRelativePaths = cropCandidates.map(\.relativePath)
            let cropFileNames = cropCandidates.map(\.fileName)
            let latestCrop = cropCandidates.last
            let originalRelationship = CropRelationship(
                role: .original,
                originalRelativePath: sourceCandidate.relativePath,
                originalFileName: sourceCandidate.fileName,
                cropRelativePaths: cropRelativePaths,
                cropFileNames: cropFileNames,
                manifestRelativePath: manifestRelativePath,
                latestCropRelativePath: latestCrop?.relativePath,
                latestCropFileName: latestCrop?.fileName
            )
            relationships[canonicalPath(sourceCandidate.sourceURL)] = originalRelationship

            for cropCandidate in cropCandidates {
                relationships[canonicalPath(cropCandidate.sourceURL)] = CropRelationship(
                    role: .crop,
                    originalRelativePath: sourceCandidate.relativePath,
                    originalFileName: sourceCandidate.fileName,
                    cropRelativePaths: cropRelativePaths,
                    cropFileNames: cropFileNames,
                    manifestRelativePath: manifestRelativePath,
                    latestCropRelativePath: cropCandidate.relativePath,
                    latestCropFileName: cropCandidate.fileName
                )
            }
        }

        return relationships
    }

    private func archiveFileManifests(
        for manifestURLs: [URL],
        baseFolder: URL
    ) -> [String: ArchiveFileManifest] {
        var manifests: [String: ArchiveFileManifest] = [:]

        for manifestURL in manifestURLs {
            guard let manifest = ArchiveFileManifest(url: manifestURL) else { continue }
            let siblingMediaURL = manifestURL.deletingPathExtension()
            manifests[canonicalPath(siblingMediaURL)] = manifest

            if let archivePath = manifest.archivePath {
                manifests[canonicalPath(URL(fileURLWithPath: archivePath))] = manifest
            }

            if let archiveRelativePath = manifest.archiveRelativePath {
                manifests[canonicalPath(baseFolder.appendingPathComponent(archiveRelativePath))] = manifest
            }
        }

        return manifests
    }

    private func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

}

private struct ArchiveFileManifest {
    let mediaItemID: UUID?
    let archivePath: String?
    let archiveRelativePath: String?
    let thumbnailCacheKey: String?
    let capturedAt: Date?
    let cameraModel: String?
    let lensModel: String?
    let pixelWidth: Int?
    let pixelHeight: Int?
    let latitude: Double?
    let longitude: Double?

    init?(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let frontMatter = FrontMatterParser.values(from: text)
        guard frontMatter["archive_path"] != nil || frontMatter["media_item_id"] != nil else { return nil }

        if let mediaItemID = frontMatter["media_item_id"].flatMap(UUID.init(uuidString:)) {
            self.mediaItemID = mediaItemID
        } else {
            self.mediaItemID = nil
        }
        archivePath = frontMatter["archive_path"]?.nonEmpty
        archiveRelativePath = frontMatter["archive_relative_path"]?.nonEmpty
        thumbnailCacheKey = frontMatter["thumbnail_cache_key"]?.nonEmpty
        capturedAt = frontMatter["captured_at"].flatMap(DateFormatting.iso8601.date(from:))
        cameraModel = frontMatter["camera_model"]?.nonEmpty
        lensModel = frontMatter["lens_model"]?.nonEmpty
        pixelWidth = frontMatter["pixel_width"].flatMap(Int.init)
        pixelHeight = frontMatter["pixel_height"].flatMap(Int.init)
        latitude = frontMatter["latitude"].flatMap(Double.init)
        longitude = frontMatter["longitude"].flatMap(Double.init)
    }
}

private struct ScanCandidate {
    var sourceURL: URL
    var relativePath: String
    var relativeDirectory: String
    var fileName: String
    var baseName: String
    var extensionName: String
    var fileSizeBytes: Int64
    var mediaKind: MediaKind
    var contentModificationDate: Date?
    var cropRelationship: CropRelationship?
}
