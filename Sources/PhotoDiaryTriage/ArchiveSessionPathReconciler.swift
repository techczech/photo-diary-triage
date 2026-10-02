import Foundation

struct ArchiveSessionPathReconciler {
    func reconcile(_ session: ImportSession) throws -> ImportSession {
        let root = ArchiveOperationRecovery(archiveRoot: session.archiveRoot).root
        guard FileManager.default.fileExists(atPath: root.path) else { return session }
        let urls = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("folder-") && $0.pathExtension == "json" }
        let records = try urls.map { try JSONDecoder().decode(ArchiveFolderRecoveryRecord.self, from: Data(contentsOf: $0)) }
            .filter { $0.complete }
        // Resolve stable photo identities against current canonical records. Path history
        // can cycle or be reused by a different Walk, and must never redirect that Walk.
        var photos: [UUID: FileManifest] = [:]
        for folder in Set(records.map(\.destination)) where FileManager.default.fileExists(atPath: folder.path) {
            for photo in try ArchiveIndexStore().loadFileManifests(folder: folder, archiveRoot: session.archiveRoot) {
                if let previous = photos[photo.mediaItemID], previous.archivePath != photo.archivePath {
                    throw ArchiveFileVerification.failure("Two archive records have the same photo identity. Saved paths have been retained.")
                }
                photos[photo.mediaItemID] = photo
            }
        }
        var result = session
        let resolver = ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot)
        for index in result.mediaItems.indices {
            guard let photo = photos[result.mediaItems[index].id] else { continue }
            let destination = URL(fileURLWithPath: photo.archivePath)
            result.mediaItems[index].destinationURL = destination
            result.mediaItems[index].archiveRelativePath = resolver.relativePath(for: destination)
            for companion in result.mediaItems[index].companionFiles.indices {
                let ext = URL(fileURLWithPath: result.mediaItems[index].companionFiles[companion].fileName).pathExtension.lowercased()
                let matches = photo.companionArchivePaths.map { URL(fileURLWithPath: $0) }.filter { $0.pathExtension.lowercased() == ext }
                guard matches.count == 1 else { continue }
                result.mediaItems[index].companionFiles[companion].destinationURL = matches[0]
                result.mediaItems[index].companionFiles[companion].archiveRelativePath = resolver.relativePath(for: matches[0])
            }
        }
        return result
    }
}
