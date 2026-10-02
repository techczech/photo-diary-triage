import Foundation

struct PhotoLocationOverride: Codable, Hashable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    let assignmentID: UUID
    let assignedAt: Date
    let isShared: Bool

    var coordinate: ArchiveCoordinate? { ArchiveCoordinate(latitude: latitude, longitude: longitude) }

    static let keys = ["location_override_name", "location_override_latitude", "location_override_longitude",
                       "location_assignment_id", "location_assigned_at", "location_assignment_shared"]

    static func read(in text: String) throws -> Self? {
        let values = keys.map { ArchiveManifestText.scalar($0, in: text) }
        guard values.contains(where: { $0 != nil }) else { return nil }
        guard let latitude = values[1].flatMap(Double.init), let longitude = values[2].flatMap(Double.init),
              ArchiveCoordinate(latitude: latitude, longitude: longitude) != nil,
              let id = values[3].flatMap(UUID.init(uuidString:)),
              let date = values[4].flatMap({ DateFormatting.iso8601.date(from: $0) }),
              values[5] == nil || values[5] == "true" || values[5] == "false" else {
            throw ArchiveFileVerification.failure("The photo location override is incomplete or invalid. Its manifest has been retained.")
        }
        return Self(name: values[0] ?? "", latitude: latitude, longitude: longitude,
                    assignmentID: id, assignedAt: date, isShared: values[5] == "true")
    }

    func applying(to text: String) -> String {
        let values = [name, String(latitude), String(longitude), assignmentID.uuidString,
                      DateFormatting.iso8601.string(from: assignedAt), String(isShared)]
        return zip(Self.keys, values).reduce(text) { ArchiveManifestText.settingScalar($1.0, to: $1.1, in: $0) }
    }

    static func clearing(in text: String) -> String {
        keys.reduce(text) { ArchiveManifestText.removingScalar($1, in: $0) }
    }
}

struct ArchiveLocationPhotoTarget: Codable, Hashable, Sendable {
    let mediaItemID: UUID
    let archiveRelativePath: String
}

struct ArchiveLocationTarget: Codable, Hashable, Sendable {
    let walkRelativePath: String
    var sessionID: UUID? = nil
    var walkID: UUID? = nil
    var photos: [ArchiveLocationPhotoTarget] = []

    var key: String {
        walkRelativePath + "|" + (sessionID?.uuidString ?? "") + "|" + (walkID?.uuidString ?? "")
            + "|" + photos.sorted { $0.archiveRelativePath < $1.archiveRelativePath }
                .map { $0.mediaItemID.uuidString + ":" + $0.archiveRelativePath }.joined(separator: "|")
    }
}

struct ArchiveLocationChange: Codable, Sendable {
    let relativePath: String
    let original: String
    let replacement: String
}

struct ArchiveLocationRecovery: Codable, Sendable {
    let operationID: UUID
    let target: ArchiveLocationTarget
    let name: String
    let coordinate: ArchiveCoordinate?
    let changes: [ArchiveLocationChange]
    var complete = false
}

struct ArchiveLocationSaveResult: Sendable {
    let target: ArchiveLocationTarget
    let name: String
    let coordinate: ArchiveCoordinate?
    let photoOverride: PhotoLocationOverride?
}

struct ArchiveLocationEditor: Sendable {
    var writeText: @Sendable (String, URL) throws -> Void = { text, url in
        try text.write(to: url, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    func save(target: ArchiveLocationTarget, name: String, coordinate: ArchiveCoordinate?, archiveRoot: URL) throws -> ArchiveLocationSaveResult {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.contains("\n"), !name.contains("\r") else {
            throw ArchiveFileVerification.failure("Use a single-line location name.")
        }
        guard target.photos.isEmpty || coordinate != nil || name.isEmpty else {
            throw ArchiveFileVerification.failure("Drop a pin before assigning a photo location.")
        }
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot)
        defer { withExtendedLifetime(lock) {} }
        let loader = ArchiveIndexMediaLoader()
        let folder = try loader.indexedURL(target.walkRelativePath, archiveRoot: archiveRoot)
        let walkURL = folder.appendingPathComponent(folder.lastPathComponent + ".md")
        let walkText = try checkedText(at: walkURL, archiveRoot: archiveRoot)
        guard let sessionID = Self.identity("Session ID", in: walkText),
              target.sessionID == nil || target.sessionID == sessionID,
              target.walkID == nil || target.walkID == Self.identity("Walk ID", in: walkText) else {
            throw ArchiveFileVerification.failure("The canonical Walk identity changed. Reload the Archive before editing its location.")
        }
        var target = target
        target.sessionID = sessionID
        target.walkID = Self.identity("Walk ID", in: walkText)
        try Self.assertNoUnfinishedFolderOperation(overlapping: folder, archiveRoot: archiveRoot)
        if let record = try pending(for: target.walkRelativePath, archiveRoot: archiveRoot) {
            guard record.target.key == target.key, record.name == name, record.coordinate == coordinate else {
                throw ArchiveFileVerification.failure("An unfinished location save exists for this Walk. Retry that save before assigning another location.")
            }
            return try execute(record, archiveRoot: archiveRoot)
        }
        var changes: [ArchiveLocationChange] = []
        let operationID = UUID()
        let assignment = coordinate.map { PhotoLocationOverride(name: name, latitude: $0.latitude,
            longitude: $0.longitude, assignmentID: operationID, assignedAt: Date(), isShared: target.photos.count > 1) }
        if target.photos.isEmpty {
            guard walkText.contains("## Notes") else { throw ArchiveFileVerification.failure("The Walk manifest has no readable notes section.") }
            var replacement = walkText
            for (label, value) in [("Location", name.nonEmpty), ("Latitude", coordinate.map { String($0.latitude) }), ("Longitude", coordinate.map { String($0.longitude) })] {
                replacement = ArchiveManifestEditor.settingHeader(label, value: value, in: replacement)
            }
            changes.append(ArchiveLocationChange(relativePath: try relative(walkURL, root: archiveRoot), original: walkText, replacement: replacement))
        } else {
            guard Set(target.photos.map(\.mediaItemID)).count == target.photos.count,
                  Set(target.photos.map(\.archiveRelativePath)).count == target.photos.count else {
                throw ArchiveFileVerification.failure("The selected photo identities are ambiguous.")
            }
            for photo in target.photos.sorted(by: { $0.archiveRelativePath < $1.archiveRelativePath }) {
                let photoURL = try loader.indexedURL(photo.archiveRelativePath, archiveRoot: archiveRoot)
                guard photoURL.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL else {
                    throw ArchiveFileVerification.failure("Selected photos must belong to this canonical Walk.")
                }
                let url = photoURL.deletingPathExtension().appendingPathExtension("md")
                let text = try checkedText(at: url, archiveRoot: archiveRoot)
                guard ArchiveManifestText.scalar("media_item_id", in: text).flatMap(UUID.init(uuidString:)) == photo.mediaItemID,
                      text.hasPrefix("---\n"), text.range(of: "\n---\n") != nil else {
                    throw ArchiveFileVerification.failure("A selected photo has no matching canonical manifest. Nothing was changed.")
                }
                _ = try PhotoLocationOverride.read(in: text)
                changes.append(ArchiveLocationChange(relativePath: try relative(url, root: archiveRoot), original: text,
                    replacement: assignment?.applying(to: text) ?? PhotoLocationOverride.clearing(in: text)))
            }
        }
        let record = ArchiveLocationRecovery(operationID: operationID, target: target, name: name, coordinate: coordinate, changes: changes)
        try ArchiveOperationRecovery(archiveRoot: archiveRoot).save(record, kind: "location", sessionID: journalID(target.walkRelativePath))
        return try execute(record, archiveRoot: archiveRoot)
    }

    func resume(walkRelativePath: String, archiveRoot: URL) throws -> ArchiveLocationSaveResult {
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot)
        defer { withExtendedLifetime(lock) {} }
        guard let record = try pending(for: walkRelativePath, archiveRoot: archiveRoot) else {
            throw ArchiveFileVerification.failure("There is no unfinished location save for this Walk.")
        }
        return try execute(record, archiveRoot: archiveRoot)
    }

    func pending(for walkRelativePath: String, archiveRoot: URL) throws -> ArchiveLocationRecovery? {
        let record = try ArchiveOperationRecovery(archiveRoot: archiveRoot).load(ArchiveLocationRecovery.self,
            kind: "location", sessionID: journalID(walkRelativePath))
        return record?.complete == false ? record : nil
    }

    static func assertNoPending(overlapping folder: URL, archiveRoot: URL) throws {
        let recovery = ArchiveOperationRecovery(archiveRoot: archiveRoot)
        guard FileManager.default.fileExists(atPath: recovery.root.path) else { return }
        let paths = try FileManager.default.contentsOfDirectory(at: recovery.root, includingPropertiesForKeys: nil)
        for url in paths where url.lastPathComponent.hasPrefix("location-") && url.pathExtension == "json" {
            let record = try JSONDecoder().decode(ArchiveLocationRecovery.self, from: Data(contentsOf: url))
            guard !record.complete else { continue }
            let walk = try ArchiveIndexMediaLoader().indexedURL(record.target.walkRelativePath, archiveRoot: archiveRoot)
            let a = folder.standardizedFileURL.path, b = walk.standardizedFileURL.path
            if a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/") {
                throw ArchiveFileVerification.failure("Finish the recorded location save before moving or migrating its Walk.")
            }
        }
    }

    private static func assertNoUnfinishedFolderOperation(overlapping folder: URL, archiveRoot: URL) throws {
        let recovery = ArchiveOperationRecovery(archiveRoot: archiveRoot)
        let paths = try FileManager.default.contentsOfDirectory(at: recovery.root, includingPropertiesForKeys: nil)
        for url in paths where url.lastPathComponent.hasPrefix("folder-") && url.pathExtension == "json" {
            let record = try JSONDecoder().decode(ArchiveFolderRecoveryRecord.self, from: Data(contentsOf: url))
            if !record.complete && [record.source, record.destination].contains(where: { path in
                let a = folder.standardizedFileURL.path, b = path.standardizedFileURL.path
                return a == b || a.hasPrefix(b + "/") || b.hasPrefix(a + "/")
            }) { throw ArchiveFileVerification.failure("Finish the recorded folder move before editing its location.") }
        }
        for url in paths where url.lastPathComponent.hasPrefix("metadata-") && url.pathExtension == "json" {
            let record = try JSONDecoder().decode(ArchiveMetadataRecovery.self, from: Data(contentsOf: url))
            if !record.complete && record.changes.contains(where: { $0.url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL }) {
                throw ArchiveFileVerification.failure("Finish the recorded metadata save before editing its location.")
            }
        }
        for url in paths where url.lastPathComponent.hasPrefix("import-") && !url.lastPathComponent.hasPrefix("import-file-") && url.pathExtension == "json" {
            let record = try JSONDecoder().decode(ImportRecoveryRecord.self, from: Data(contentsOf: url))
            if !record.complete && record.plans.contains(where: { $0.archiveFolder.standardizedFileURL == folder.standardizedFileURL }) {
                throw ArchiveFileVerification.failure("Finish the recorded import before editing its location.")
            }
        }
    }

    private func execute(_ initial: ArchiveLocationRecovery, archiveRoot: URL) throws -> ArchiveLocationSaveResult {
        // Check the whole batch before resuming: an unrelated edit must not permit another partial write.
        let loader = ArchiveIndexMediaLoader()
        let folder = try loader.indexedURL(initial.target.walkRelativePath, archiveRoot: archiveRoot)
        let walkText = try checkedText(at: folder.appendingPathComponent(folder.lastPathComponent + ".md"), archiveRoot: archiveRoot)
        guard initial.target.sessionID != nil, Self.identity("Session ID", in: walkText) == initial.target.sessionID,
              Self.identity("Walk ID", in: walkText) == initial.target.walkID else {
            throw ArchiveFileVerification.failure("The Walk identity changed while recovering its location save.")
        }
        try Self.assertNoUnfinishedFolderOperation(overlapping: folder, archiveRoot: archiveRoot)
        for change in initial.changes { try validateCurrent(change, archiveRoot: archiveRoot) }
        for change in initial.changes {
            try Task.checkCancellation()
            try validateCurrent(change, archiveRoot: archiveRoot)
            let url = try loader.indexedURL(change.relativePath, archiveRoot: archiveRoot)
            if try String(contentsOf: url, encoding: .utf8) != change.replacement { try writeText(change.replacement, url) }
        }
        var record = initial; record.complete = true
        try ArchiveOperationRecovery(archiveRoot: archiveRoot).save(record, kind: "location", sessionID: journalID(initial.target.walkRelativePath))
        let photoOverride = initial.target.photos.isEmpty ? nil : try PhotoLocationOverride.read(in: initial.changes.first?.replacement ?? "")
        return ArchiveLocationSaveResult(target: initial.target, name: initial.name, coordinate: initial.coordinate, photoOverride: photoOverride)
    }

    private func validateCurrent(_ change: ArchiveLocationChange, archiveRoot: URL) throws {
        let url = try ArchiveIndexMediaLoader().indexedURL(change.relativePath, archiveRoot: archiveRoot)
        let text = try checkedText(at: url, archiveRoot: archiveRoot)
        guard text == change.original || text == change.replacement else {
            throw ArchiveFileVerification.failure("This manifest changed while saving: \(url.lastPathComponent). Its text has been retained.")
        }
    }

    private func checkedText(at url: URL, archiveRoot: URL) throws -> String {
        _ = try relative(url, root: archiveRoot)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ArchiveFileVerification.failure("Location editing requires a regular canonical manifest.")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func relative(_ url: URL, root: URL) throws -> String {
        guard let path = ArchiveRelativePathResolver(root: root.resolvingSymlinksInPath()).relativePath(for: ArchivePathSafety.resolvedForWrite(url)) else {
            throw ArchiveFileVerification.failure("A location manifest escapes the Archive.")
        }
        return path
    }

    private func journalID(_ path: String) -> UUID {
        let hex = Array(CacheKeyBuilder.key(for: path).prefix(32))
        return UUID(uuidString: [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(hex[$0]) }.joined(separator: "-"))!
    }

    static func identity(_ label: String, in text: String) -> UUID? {
        guard let line = text.components(separatedBy: "## Notes")[0].components(separatedBy: "\n")
            .first(where: { $0.hasPrefix("- \(label):") }) else { return nil }
        return UUID(uuidString: String(line.split(separator: "`").dropFirst().first ?? ""))
    }
}
