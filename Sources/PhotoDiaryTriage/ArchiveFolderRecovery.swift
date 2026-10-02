import Foundation

struct ArchiveFolderRename: Codable {
    var oldName: String
    var newName: String
    var sha256: String?
    var fileSize: UInt64?
    var fileNumber: UInt64?
    var modifiedAt: Date?
}

struct ArchiveFolderTextChange: Codable {
    var name: String
    var original: String
    var replacement: String
}

struct ArchiveFolderRecoveryRecord: Codable {
    var source: URL
    var destination: URL
    var renames: [ArchiveFolderRename]
    var changes: [ArchiveFolderTextChange]
    var canonicalWalkSessionID: UUID?
    var canonicalWalkID: UUID?
    var complete = false
}

struct ArchiveFolderOperation {
    let archiveRoot: URL
    var fileManager: FileManager = .default

    func id(for source: URL) -> UUID {
        let hex = String(CacheKeyBuilder.key(for: source.standardizedFileURL.path).prefix(32))
        let chars = Array(hex)
        let pieces = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(chars[$0]) }
        return UUID(uuidString: pieces.joined(separator: "-"))!
    }

    func recorded(for source: URL) throws -> ArchiveFolderRecoveryRecord? {
        try ArchiveOperationRecovery(archiveRoot: archiveRoot).load(ArchiveFolderRecoveryRecord.self, kind: "folder", sessionID: id(for: source))
    }

    func prepare(source: URL, destination: URL, spec: ArchiveTextRewriteSpec,
                 names: [String: String] = [:]) throws -> ArchiveFolderRecoveryRecord {
        if let previous = try recorded(for: source), !previous.complete || !fileManager.fileExists(atPath: source.path) {
            guard previous.destination.standardizedFileURL == destination.standardizedFileURL else {
                throw ArchiveFileVerification.failure("Finish the previous folder move before choosing another destination.")
            }
            return previous
        }
        let resolver = ArchiveRelativePathResolver(root: archiveRoot.resolvingSymlinksInPath())
        guard resolver.relativePath(for: source.resolvingSymlinksInPath()) != nil,
              resolver.relativePath(for: ArchivePathSafety.resolvedForWrite(destination)) != nil,
              !destination.path.hasPrefix(source.path + "/") else {
            throw ArchiveFileVerification.failure("The move must stay inside the Archive and outside the original Walk.")
        }
        guard try source.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw ArchiveFileVerification.failure("A symbolic link cannot be moved as a Walk.")
        }
        guard let canonicalWalk = try ArchiveIndexStore(fileManager: fileManager).loadWalkManifest(folder: source, archiveRoot: archiveRoot) else {
            throw ArchiveFileVerification.failure("Only a Walk with a readable canonical manifest can be moved. Historical folders have been retained.")
        }
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ArchiveFileVerification.failure("The destination is occupied; existing files have been retained.")
        }
        let recoveryRoot = ArchiveOperationRecovery(archiveRoot: archiveRoot).root
        for url in try fileManager.contentsOfDirectory(at: recoveryRoot, includingPropertiesForKeys: nil)
            where url.lastPathComponent.hasPrefix("import-") && !url.lastPathComponent.hasPrefix("import-file-") && url.pathExtension == "json" {
            let importRecord = try JSONDecoder().decode(ImportRecoveryRecord.self, from: Data(contentsOf: url))
            if !importRecord.complete && importRecord.plans.contains(where: {
                $0.archiveFolder.standardizedFileURL == source.standardizedFileURL
            }) {
                throw ArchiveFileVerification.failure("Finish the recorded import before moving its Walk.")
            }
        }
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        var renames: [ArchiveFolderRename] = []
        for (old, new) in names.sorted(by: { $0.key < $1.key }) where old != new {
            guard !old.contains("/"), !new.contains("/"), !fileManager.fileExists(atPath: source.appendingPathComponent(new).path) else {
                throw ArchiveFileVerification.failure("A sidecar rename would overwrite existing material.")
            }
            let url = source.appendingPathComponent(old)
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw ArchiveFileVerification.failure("Only ordinary files can be renamed.")
            }
            let isText = ["md", "json", "jsonl"].contains(url.pathExtension.lowercased())
            renames.append(ArchiveFolderRename(oldName: old, newName: new,
                sha256: isText ? try ArchiveFileVerification.sha256(at: url) : nil,
                fileSize: (attributes[.size] as? NSNumber)?.uint64Value,
                fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
                modifiedAt: attributes[.modificationDate] as? Date))
        }
        guard Set(renames.map(\.newName)).count == renames.count else {
            throw ArchiveFileVerification.failure("Two files would receive the same name.")
        }
        let rewriter = ArchiveTextSidecarRewriter(fileManager: fileManager)
        var changes: [ArchiveFolderTextChange] = []
        for url in contents where ["md", "json", "jsonl"].contains(url.pathExtension.lowercased()) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ArchiveFileVerification.failure("Archive sidecars must be ordinary files.")
            }
            let original = try String(contentsOf: url, encoding: .utf8)
            let replacement = try rewriter.rewriteStructured(original, extension: url.pathExtension.lowercased(), spec: spec)
            if original != replacement {
                changes.append(ArchiveFolderTextChange(name: names[url.lastPathComponent] ?? url.lastPathComponent,
                    original: original, replacement: replacement))
            }
        }
        let sourceDevice = try fileManager.attributesOfItem(atPath: source.path)[.systemNumber] as? NSNumber
        var targetAncestor = destination.deletingLastPathComponent()
        while !fileManager.fileExists(atPath: targetAncestor.path) && targetAncestor.path != "/" { targetAncestor.deleteLastPathComponent() }
        let targetDevice = try fileManager.attributesOfItem(atPath: targetAncestor.path)[.systemNumber] as? NSNumber
        guard sourceDevice != nil, sourceDevice == targetDevice else {
            throw ArchiveFileVerification.failure("Walk moves must stay on the same filesystem. The original folder has been retained.")
        }
        let record = ArchiveFolderRecoveryRecord(source: source, destination: destination, renames: renames, changes: changes, canonicalWalkSessionID: canonicalWalk.sessionID, canonicalWalkID: canonicalWalk.walkID)
        let recovery = ArchiveOperationRecovery(archiveRoot: archiveRoot)
        if let previous = try recorded(for: source), previous.complete {
            try recovery.save(previous, kind: "folder-history-\(UUID().uuidString)", sessionID: id(for: source))
        }
        try recovery.save(record, kind: "folder", sessionID: id(for: source))
        return record
    }

    private func matchesIdentity(_ url: URL, rename: ArchiveFolderRename) throws -> Bool {
        if let digest = rename.sha256 { return try ArchiveFileVerification.sha256(at: url) == digest }
        let values = try fileManager.attributesOfItem(atPath: url.path)
        return values[.type] as? FileAttributeType == .typeRegular
            && (values[.size] as? NSNumber)?.uint64Value == rename.fileSize
            && (values[.systemFileNumber] as? NSNumber)?.uint64Value == rename.fileNumber
            && values[.modificationDate] as? Date == rename.modifiedAt
    }

    func complete(_ initial: ArchiveFolderRecoveryRecord) throws {
        var record = initial
        record.complete = true
        try ArchiveOperationRecovery(archiveRoot: archiveRoot).save(record, kind: "folder", sessionID: id(for: record.source))
    }

    func execute(_ initial: ArchiveFolderRecoveryRecord) throws -> ArchiveFolderRecoveryRecord {
        let record = initial
        let resolver = ArchiveRelativePathResolver(root: archiveRoot.resolvingSymlinksInPath())
        guard resolver.relativePath(for: ArchivePathSafety.resolvedForWrite(record.source)) != nil,
              resolver.relativePath(for: ArchivePathSafety.resolvedForWrite(record.destination)) != nil else {
            throw ArchiveFileVerification.failure("The recorded move now points outside the Archive. No files were moved.")
        }
        for url in [record.source, record.destination] where fileManager.fileExists(atPath: url.path) {
            guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                throw ArchiveFileVerification.failure("A recorded move location was replaced by a symbolic link.")
            }
        }
        let identityFolder = fileManager.fileExists(atPath: record.source.path) ? record.source : record.destination
        let identityNames = [record.source.lastPathComponent + ".md", record.destination.lastPathComponent + ".md"]
        guard let identityURL = identityNames.map({ identityFolder.appendingPathComponent($0) }).first(where: { fileManager.fileExists(atPath: $0.path) }),
              let identity = try String(contentsOf: identityURL, encoding: .utf8).components(separatedBy: "## Notes")[0]
                .components(separatedBy: "\n").first(where: { $0.hasPrefix("- Session ID: `") }),
              UUID(uuidString: String(identity.dropFirst(15).dropLast())) == record.canonicalWalkSessionID else {
            throw ArchiveFileVerification.failure("The recorded Walk identity changed. Existing files have been retained.")
        }
        let identityText = try String(contentsOf: identityURL, encoding: .utf8).components(separatedBy: "## Notes")[0]
        let walkID = identityText.components(separatedBy: "\n").first(where: { $0.hasPrefix("- Walk ID: `") })
            .flatMap { UUID(uuidString: String($0.dropFirst(12).dropLast())) }
        guard walkID == record.canonicalWalkID else {
            throw ArchiveFileVerification.failure("The recorded Walk identity changed. No files were moved.")
        }
        if fileManager.fileExists(atPath: record.source.path) {
            guard !fileManager.fileExists(atPath: record.destination.path) else {
                throw ArchiveFileVerification.failure("Both move locations exist; the original files have been retained.")
            }
            try AppDirectories.ensureExists(record.destination.deletingLastPathComponent(), fileManager: fileManager)
            try fileManager.moveItem(at: record.source, to: record.destination)
        }
        guard fileManager.fileExists(atPath: record.destination.path) else {
            throw ArchiveFileVerification.failure("The recorded move destination is unavailable.")
        }
        for rename in record.renames {
            let source = record.destination.appendingPathComponent(rename.oldName)
            let destination = record.destination.appendingPathComponent(rename.newName)
            if fileManager.fileExists(atPath: source.path) {
                guard try matchesIdentity(source, rename: rename) else {
                    throw ArchiveFileVerification.failure("A file changed before its recorded rename. Its contents have been retained.")
                }
                try fileManager.moveItem(at: source, to: destination)
            } else if !record.changes.contains(where: { $0.name == rename.newName }) {
                guard try matchesIdentity(destination, rename: rename) else {
                    throw ArchiveFileVerification.failure("The renamed file could not be verified.")
                }
            }
        }
        for change in record.changes {
            let url = record.destination.appendingPathComponent(change.name)
            let current = try String(contentsOf: url, encoding: .utf8)
            guard current == change.original || current == change.replacement else {
                throw ArchiveFileVerification.failure("A sidecar changed while moving. Its existing text has been retained: \(url.lastPathComponent)")
            }
            if current != change.replacement { try change.replacement.write(to: url, atomically: true, encoding: .utf8) }
        }
        try ArchiveOperationRecovery(archiveRoot: archiveRoot).save(record, kind: "folder", sessionID: id(for: record.source))
        return record
    }
}
