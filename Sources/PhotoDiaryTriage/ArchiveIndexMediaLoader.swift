import Foundation

struct ArchiveIndexMediaLoader {
    var fileManager: FileManager = .default

    func load(folder: URL, settings: AppSettings) throws -> [MediaItem] {
        guard let path = ArchiveIndexStore.archiveRelativePath(for: folder, archiveRoot: settings.archiveRoot)
            ?? (folder.standardizedFileURL == settings.archiveRoot.standardizedFileURL ? "." : nil) else {
            throw ArchiveFileVerification.failure("This indexed folder is outside the Archive.")
        }
        let rows = try ArchiveCatalogueBuilder(fileManager: fileManager).readIndexEntries(archiveRoot: settings.archiveRoot)
        let photos = rows.filter { row in
            guard row.kind == .photo else { return false }
            return path == "." || row.folderPath == path || row.walkPath == path || row.archiveRelativePath.hasPrefix(path + "/")
        }
        return try MediaItemSort.sorted(photos.map { row in
            let url = try indexedURL(row.archiveRelativePath, archiveRoot: settings.archiveRoot)
            let ext = url.pathExtension.lowercased()
            let kind: MediaKind = ["jpg", "jpeg"].contains(ext) ? .jpeg : (["cr2", "cr3", "dng", "raf", "nef", "arw"].contains(ext) ? .raw : .other)
            let date = row.date.flatMap { DateFormatting.iso8601.date(from: $0) }
            let name = url.lastPathComponent
            let itemID = row.mediaItemID ?? stableID(row.archiveRelativePath)
            let companions = try (row.companionPaths ?? []).map { relative -> CompanionFile in
                let companion = try indexedURL(relative, archiveRoot: settings.archiveRoot)
                return CompanionFile(id: stableID(relative), sourceURL: companion, relativePath: relative,
                    fileName: companion.lastPathComponent, fileSizeBytes: 0, kind: .raw,
                    destinationURL: companion, archiveRelativePath: relative)
            }
            return MediaItem(id: itemID, sourceURL: url,
                relativePath: path == "." ? row.archiveRelativePath : String(row.archiveRelativePath.dropFirst(path.count + 1)),
                fileName: name, baseName: url.deletingPathExtension().lastPathComponent,
                mediaKind: kind, fileSizeBytes: row.fileSizeBytes ?? 0, capturedAt: date,
                metadata: MediaMetadata(capturedAt: date, pixelWidth: row.pixelWidth, pixelHeight: row.pixelHeight,
                    cameraModel: row.cameraModel ?? row.exifSummary, lensModel: row.lensModel,
                    latitude: row.latitude, longitude: row.longitude, raw: [:]),
                thumbnailCacheKey: CacheKeyBuilder.key(for: url.path), selectionState: .included,
                companionFiles: companions, lifecycleState: .imported, destinationURL: url,
                archiveRelativePath: row.archiveRelativePath,
                cropRelationship: try rebased(row.cropRelationship, folderPath: path, archiveRoot: settings.archiveRoot), captureDateEvidence: row.captureDateEvidence, googlePhotos: row.googlePhotos)
        })
    }

    private func rebased(_ relationship: CropRelationship?, folderPath: String, archiveRoot: URL) throws -> CropRelationship? {
        guard var value = relationship else { return nil }
        func relative(_ path: String) throws -> String {
            _ = try indexedURL(path, archiveRoot: archiveRoot)
            guard folderPath == "." || path.hasPrefix(folderPath + "/") else {
                throw ArchiveFileVerification.failure("A crop relationship is outside the open indexed folder.")
            }
            return folderPath == "." ? path : String(path.dropFirst(folderPath.count + 1))
        }
        value.originalRelativePath = try relative(value.originalRelativePath)
        value.cropRelativePaths = try value.cropRelativePaths.map(relative)
        value.manifestRelativePath = try value.manifestRelativePath.map(relative)
        value.latestCropRelativePath = try value.latestCropRelativePath.map(relative)
        return value
    }

    func indexedURL(_ path: String, archiveRoot: URL) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !parts.isEmpty,
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ArchiveFileVerification.failure("An Archive Index path is invalid.")
        }
        let url = archiveRoot.appendingPathComponent(path)
        guard ArchiveRelativePathResolver(root: archiveRoot.resolvingSymlinksInPath())
            .relativePath(for: ArchivePathSafety.resolvedForWrite(url)) != nil else {
            throw ArchiveFileVerification.failure("An Archive Index path escapes the Archive.")
        }
        return url
    }

    private func stableID(_ path: String) -> UUID {
        let hex = Array(CacheKeyBuilder.key(for: path).prefix(32))
        let groups = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(hex[$0]) }
        return UUID(uuidString: groups.joined(separator: "-"))!
    }
}
