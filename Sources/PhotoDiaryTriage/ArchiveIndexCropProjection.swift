import Foundation

extension ArchiveIndexStore {
    // Relationships in the index use Archive-relative paths. The grid rebases them to
    // the open folder, without loading crop manifests or images on a travel machine.
    func includingCropRelationships(_ input: [ArchiveIndexEntry], archiveRoot: URL) throws -> [ArchiveIndexEntry] {
        var rows = input
        var positions: [String: Int] = [:]
        for (index, row) in rows.enumerated() where row.kind == .photo {
            guard positions.updateValue(index, forKey: row.archiveRelativePath) == nil else {
                throw ArchiveFileVerification.failure("Multiple photo manifests describe the same Archive path: \(row.archiveRelativePath)")
            }
        }
        var visited = Set<String>()
        var cursor = 0
        while cursor < rows.count {
            let source = rows[cursor]
            cursor += 1
            guard source.kind == .photo, visited.insert(source.archiveRelativePath).inserted else { continue }
            let sourceURL = try ArchiveIndexMediaLoader(fileManager: fileManager).indexedURL(source.archiveRelativePath, archiveRoot: archiveRoot)
            let manifestURL = sourceURL.deletingPathExtension().appendingPathExtension("crops.json")
            guard fileManager.fileExists(atPath: manifestURL.path) else { continue }
            let manifestPath = try ArchiveIndexMediaLoader(fileManager: fileManager).indexedURL(
                Self.archiveRelativePath(for: manifestURL, archiveRoot: archiveRoot) ?? "", archiveRoot: archiveRoot)
            let manifest = try JSONDecoder().decode(CropManifest.self, from: Data(contentsOf: manifestPath))
            let recordedPath = Self.archiveRelativePath(for: URL(fileURLWithPath: manifest.sourcePath), archiveRoot: archiveRoot)
            guard manifest.sourceMediaItemID == source.mediaItemID || recordedPath == source.archiveRelativePath
                || manifest.sourceFileName == sourceURL.lastPathComponent else {
                throw ArchiveFileVerification.failure("A crop manifest does not identify its original photo: \(manifestURL.lastPathComponent)")
            }
            var crops: [(CropManifestEntry, String)] = []
            for crop in manifest.crops {
                guard URL(fileURLWithPath: crop.outputFileName).lastPathComponent == crop.outputFileName,
                      !crop.outputFileName.isEmpty, crop.outputFileName != ".", crop.outputFileName != ".." else {
                    throw ArchiveFileVerification.failure("A crop manifest contains an invalid photo name.")
                }
                let url = sourceURL.deletingLastPathComponent().appendingPathComponent(crop.outputFileName)
                guard let path = Self.archiveRelativePath(for: url, archiveRoot: archiveRoot) else {
                    throw ArchiveFileVerification.failure("A cropped photo is outside the Archive.")
                }
                _ = try ArchiveIndexMediaLoader(fileManager: fileManager).indexedURL(path, archiveRoot: archiveRoot)
                guard fileManager.fileExists(atPath: url.path) else { continue }
                crops.append((crop, path))
                if positions[path] == nil {
                    var row = source
                    row.archiveRelativePath = path
                    row.title = crop.outputFileName
                    row.mediaItemID = crop.id
                    row.pixelWidth = crop.outputPixelWidth
                    row.pixelHeight = crop.outputPixelHeight
                    row.fileSizeBytes = nil
                    row.companionPaths = []
                    row.thumbnailPath = Self.thumbnailRelativePath(for: url, archiveRoot: archiveRoot).flatMap {
                        fileManager.fileExists(atPath: archiveRoot.appendingPathComponent($0).path) ? $0 : nil
                    }
                    positions[path] = rows.count
                    rows.append(row)
                }
            }
            guard !crops.isEmpty, let sourcePosition = positions[source.archiveRelativePath] else { continue }
            let relativeManifest = Self.archiveRelativePath(for: manifestURL, archiveRoot: archiveRoot)
            func relationship(_ role: CropRelationshipRole, latest: (CropManifestEntry, String)?) -> CropRelationship {
                CropRelationship(role: role, originalRelativePath: source.archiveRelativePath,
                    originalFileName: sourceURL.lastPathComponent, cropRelativePaths: crops.map { $0.1 },
                    cropFileNames: crops.map { $0.0.outputFileName }, manifestRelativePath: relativeManifest,
                    latestCropRelativePath: latest?.1, latestCropFileName: latest?.0.outputFileName)
            }
            rows[sourcePosition].cropRelationship = relationship(.original, latest: crops.last)
            for crop in crops {
                if let position = positions[crop.1] {
                    rows[position].cropRelationship = relationship(.crop, latest: crop)
                    rows[position].isDerivedPhoto = true
                    rows[position].googlePhotos = nil
                }
            }
        }
        return rows
    }
}
