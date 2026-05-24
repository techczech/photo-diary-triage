import Foundation

struct PhotoLogSyncDocument: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var exportedAt: Date
    var sourceMachineName: String
    var sourceArchiveRootPath: String
    var sourceOneDrivePicturesRootPath: String
    var session: ImportSession
    var bursts: [BurstGroup]
    var timeClusters: [TimeCluster]
}

struct PhotoLogSyncRecord: Hashable, Sendable {
    var document: PhotoLogSyncDocument
    var sourceURL: URL
}

final class PhotoLogSyncStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func export(
        session: ImportSession,
        bursts: [BurstGroup],
        timeClusters: [TimeCluster],
        to oneDrivePicturesRoot: URL,
        machineName: String = Host.current().localizedName ?? "Unknown Mac"
    ) throws -> URL {
        let syncRoot = syncRootURL(in: oneDrivePicturesRoot)
        try AppDirectories.ensureExists(syncRoot, fileManager: fileManager)

        let document = PhotoLogSyncDocument(
            schemaVersion: 1,
            exportedAt: Date(),
            sourceMachineName: machineName,
            sourceArchiveRootPath: session.archiveRoot.path,
            sourceOneDrivePicturesRootPath: session.oneDrivePicturesRoot.path,
            session: session,
            bursts: bursts,
            timeClusters: timeClusters
        )
        let url = syncRoot.appendingPathComponent("\(session.id.uuidString).json")
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
        return url
    }

    func importRecords(
        from oneDrivePicturesRoot: URL,
        localArchiveRoot: URL,
        localOneDrivePicturesRoot: URL,
        localMachineRole: ArchiveMachineRole
    ) throws -> [PhotoLogSyncRecord] {
        let syncRoot = syncRootURL(in: oneDrivePicturesRoot)
        guard let enumerator = fileManager.enumerator(
            at: syncRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var records: [PhotoLogSyncRecord] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "json" {
            let data = try Data(contentsOf: url)
            var document = try decoder.decode(PhotoLogSyncDocument.self, from: data)
            document.session = remap(
                document.session,
                localArchiveRoot: localArchiveRoot,
                localOneDrivePicturesRoot: localOneDrivePicturesRoot,
                localMachineRole: localMachineRole
            )
            records.append(PhotoLogSyncRecord(document: document, sourceURL: url))
        }

        return records.sorted {
            $0.document.exportedAt > $1.document.exportedAt
        }
    }

    func syncRootURL(in oneDrivePicturesRoot: URL) -> URL {
        oneDrivePicturesRoot
            .appendingPathComponent(".photo-diary-triage", isDirectory: true)
            .appendingPathComponent("photo-logs", isDirectory: true)
    }

    private func remap(
        _ session: ImportSession,
        localArchiveRoot: URL,
        localOneDrivePicturesRoot: URL,
        localMachineRole: ArchiveMachineRole
    ) -> ImportSession {
        let resolver = ArchiveRelativePathResolver(root: localOneDrivePicturesRoot)
        var remapped = session
        remapped.archiveRoot = localArchiveRoot
        remapped.oneDrivePicturesRoot = localOneDrivePicturesRoot
        remapped.archiveMachineRole = localMachineRole

        for index in remapped.mediaItems.indices {
            if let relativePath = remapped.mediaItems[index].archiveRelativePath {
                remapped.mediaItems[index].destinationURL = resolver.url(for: relativePath)
            }
            for companionIndex in remapped.mediaItems[index].companionFiles.indices {
                guard let relativePath = remapped.mediaItems[index].companionFiles[companionIndex].archiveRelativePath else { continue }
                remapped.mediaItems[index].companionFiles[companionIndex].destinationURL = resolver.url(for: relativePath)
            }
        }

        return remapped
    }
}
