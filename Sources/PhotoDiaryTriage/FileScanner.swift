import Foundation

struct FileScanner {
    let fileManager: FileManager
    let metadataExtractor: MetadataExtractor

    init(fileManager: FileManager = .default, metadataExtractor: MetadataExtractor = MetadataExtractor()) {
        self.fileManager = fileManager
        self.metadataExtractor = metadataExtractor
    }

    func scanFolder(_ folder: URL, settings: AppSettings) throws -> [MediaItem] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: Array(resourceKeys))!
        let baseFolder = folder.resolvingSymlinksInPath().standardizedFileURL
        var candidates: [ScanCandidate] = []

        for case let fileURL as URL in enumerator {
            try Task.checkCancellation()

            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
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
                    mediaKind: mediaKind
                )
            )
        }

        var items: [MediaItem] = []
        let groupedCandidates = Dictionary(grouping: candidates) { "\($0.relativeDirectory)|\($0.baseName.lowercased())" }

        for (_, group) in groupedCandidates {
            try Task.checkCancellation()

            let primary = primaryCandidate(in: group)
            let metadata = metadataExtractor.extract(from: primary.sourceURL)
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
                    sourceURL: primary.sourceURL,
                    relativePath: primary.relativePath,
                    fileName: primary.fileName,
                    baseName: primary.baseName,
                    mediaKind: primary.mediaKind,
                    fileSizeBytes: primary.fileSizeBytes,
                    capturedAt: metadata.capturedAt,
                    metadata: metadata,
                    thumbnailCacheKey: CacheKeyBuilder.key(for: primary.sourceURL),
                    companionFiles: companions
                )
            )
        }

        return items.sorted {
            let lhsDate = $0.capturedAt ?? .distantPast
            let rhsDate = $1.capturedAt ?? .distantPast
            if lhsDate == rhsDate {
                return $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
            }
            return lhsDate < rhsDate
        }
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
}
