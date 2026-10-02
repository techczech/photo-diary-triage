import Foundation

extension ArchiveIndexStore {
    func historicalEntries(_ discovery: (entries: [ArchiveBrowseEntry], photos: [String: [URL]]),
                           archiveRoot: URL) throws -> [ArchiveIndexEntry] {
        var rows: [ArchiveIndexEntry] = []
        for folder in discovery.entries {
            let urls = discovery.photos[folder.archiveRelativePath] ?? []
            let groups = Dictionary(grouping: urls) { Self.historicalGroupingKey($0) }
            let sorted = groups.values.sorted { ($0.first?.path ?? "") < ($1.first?.path ?? "") }
            for group in sorted {
                let primary = group.sorted { priority($0) < priority($1) }.first!
                guard let path = Self.archiveRelativePath(for: primary, archiveRoot: archiveRoot) else { continue }
                let values = try primary.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let raw = group.filter { $0 != primary && isRaw($0) }
                rows.append(ArchiveIndexEntry(kind: .photo, year: folder.year, archiveRelativePath: path,
                    date: values.contentModificationDate.map(DateFormatting.iso8601.string(from:)), title: primary.lastPathComponent,
                    location: nil, exifSummary: nil, aiDescription: nil, notes: nil,
                    thumbnailPath: existingThumbnailRelativePathForProjection(primary, archiveRoot: archiveRoot),
                    walkPath: nil, tripPath: nil, folderPath: folder.archiveRelativePath,
                    fileSizeBytes: values.fileSize.map(Int64.init),
                    companionPaths: raw.compactMap { Self.archiveRelativePath(for: $0, archiveRoot: archiveRoot) }))
            }
            rows.append(ArchiveIndexEntry(kind: .unorganisedFolder, year: folder.year,
                archiveRelativePath: folder.archiveRelativePath, date: folder.startDate.map(DateFormatting.iso8601.string(from:)),
                title: folder.title, location: folder.location, exifSummary: nil, aiDescription: nil,
                thumbnailPath: folder.coverThumbnailPath, walkPath: nil, tripPath: nil,
                endDate: folder.endDate.map(DateFormatting.iso8601.string(from:)), photoCount: sorted.count, googlePhotos: try historicalGoogleRecord(folder: archiveRoot.appendingPathComponent(folder.archiveRelativePath))))
        }
        return rows
    }

    static func historicalGroupingKey(_ url: URL) -> String {
        url.deletingLastPathComponent().standardizedFileURL.path + "/" + url.deletingPathExtension().lastPathComponent.lowercased()
    }

    private func existingThumbnailRelativePathForProjection(_ photo: URL, archiveRoot: URL) -> String? {
        let thumbnail = Self.thumbnailURL(for: photo, archiveRoot: archiveRoot)
        return fileManager.fileExists(atPath: thumbnail.path) ? Self.archiveRelativePath(for: thumbnail, archiveRoot: archiveRoot) : nil
    }

    private func isRaw(_ url: URL) -> Bool {
        ["cr2", "cr3", "dng", "raf", "nef", "arw"].contains(url.pathExtension.lowercased())
    }

    private func priority(_ url: URL) -> String {
        let order = ["jpg": 0, "jpeg": 1, "heic": 2, "png": 3, "tif": 4, "tiff": 5]
        return "\(order[url.pathExtension.lowercased()] ?? (isRaw(url) ? 9 : 6))-\(url.path)"
    }
}
