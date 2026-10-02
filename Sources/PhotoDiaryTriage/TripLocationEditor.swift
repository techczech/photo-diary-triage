import Foundation

struct TripLocationTarget: Hashable, Sendable {
    let relativePath: String
    let tripID: UUID?
    let expectedOverride: String?
}

enum TripManifestText {
    static func headerValue(_ label: String, in text: String) -> String? {
        let header = text.components(separatedBy: "\n## ")[0]
        let prefix = "- \(label):"
        return header.components(separatedBy: "\n").first { $0.hasPrefix(prefix) }
            .map { ArchiveManifestText.unquote(String($0.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)) }
    }

    /// Replace only the owned membership section and date fields; preserve human sections verbatim.
    static func settingMembership(_ manifest: TripManifest, in text: String, renderer: ManifestRenderer = ManifestRenderer()) throws -> String {
        let marker = "## Member Walks\n"
        guard let start = text.range(of: marker), let boundary = text.range(of: "\n## ") else {
            throw ArchiveFileVerification.failure("The existing Trip membership could not be read.")
        }
        let after = text[start.upperBound...]
        let end = after.range(of: "\n## ")?.lowerBound ?? text.endIndex
        let rendered = try GooglePhotosRecord.removing(in: MachineDescriptionHistory.removing(in: renderer.renderTripManifest(manifest)))
        guard let newStart = rendered.range(of: marker) else { throw ArchiveFileVerification.failure("Trip membership rendering failed.") }
        var body = String(text[boundary.lowerBound...])
        let bodyStart = body.range(of: marker)!
        let bodyEnd = body[bodyStart.upperBound...].range(of: "\n## ")?.lowerBound ?? body.endIndex
        body.replaceSubrange(bodyStart.upperBound..<bodyEnd, with: String(rendered[newStart.upperBound...]) + (end == text.endIndex ? "" : "\n"))
        var header = String(text[..<boundary.lowerBound]).components(separatedBy: "\n")
        for (label, value) in [("Start date", manifest.startDate), ("End date", manifest.endDate)] {
            let prefix = "- \(label):"
            let matches = header.indices.filter { header[$0].hasPrefix(prefix) }
            guard matches.count <= 1 else { throw ArchiveFileVerification.failure("The Trip has conflicting date fields.") }
            if let index = matches.first {
                if let value { header[index] = "\(prefix) \(DateFormatting.iso8601.string(from: value))" }
                else { header.remove(at: index) }
            } else if let value { header.append("\(prefix) \(DateFormatting.iso8601.string(from: value))") }
        }
        return header.joined(separator: "\n") + body
    }

    static func settingLabel(_ label: String?, in text: String) throws -> String {
        guard text.contains("\n## Member Walks"), let boundary = text.range(of: "\n## ") else {
            throw ArchiveFileVerification.failure("The canonical Trip membership section is missing. Its text has been retained.")
        }
        var lines = String(text[..<boundary.lowerBound]).components(separatedBy: "\n")
        let prefix = "- Location label override:"
        let matches = lines.indices.filter { lines[$0].hasPrefix(prefix) }
        guard matches.count <= 1 else { throw ArchiveFileVerification.failure("This Trip has conflicting location label fields.") }
        if let index = matches.first {
            if let label { lines[index] = prefix + " " + ArchiveManifestText.quotedScalar(label) }
            else { lines.remove(at: index) }
        } else if let label {
            lines.append(prefix + " " + ArchiveManifestText.quotedScalar(label))
        }
        return lines.joined(separator: "\n") + text[boundary.lowerBound...]
    }
}

struct TripLocationEditor: Sendable {
    var writeText: @Sendable (String, URL) throws -> Void = { text, url in
        try text.write(to: url, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }; try handle.synchronize()
    }

    func save(target: TripLocationTarget, label: String?, archiveRoot: URL) throws -> TripManifest {
        let label = label?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        guard label?.contains("\n") != true, label?.contains("\r") != true else {
            throw ArchiveFileVerification.failure("Use a single-line Trip location label.")
        }
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot)
        defer { withExtendedLifetime(lock) {} }
        let folder = try ArchiveIndexMediaLoader().indexedURL(target.relativePath, archiveRoot: archiveRoot)
        guard folder != archiveRoot.standardizedFileURL else { throw ArchiveFileVerification.failure("Choose a recognised Trip.") }
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let expectedFolder = archiveRoot.resolvingSymlinksInPath().appendingPathComponent(target.relativePath).standardizedFileURL
        guard values.isDirectory == true, values.isSymbolicLink != true,
              folder.resolvingSymlinksInPath().standardizedFileURL == expectedFolder else {
            throw ArchiveFileVerification.failure("Trip labels require a real archive folder without linked ancestors.")
        }
        try ArchiveLocationEditor.assertNoPending(overlapping: folder, archiveRoot: archiveRoot)
        try ArchiveLocationEditor.assertNoUnfinishedFolderOperation(overlapping: folder, archiveRoot: archiveRoot)
        let url = folder.appendingPathComponent(folder.lastPathComponent + ".md")
        let original: String?
        if FileManager.default.fileExists(atPath: url.path) {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ArchiveFileVerification.failure("The Trip manifest must be a regular file.") }
            original = try String(contentsOf: url, encoding: .utf8)
        } else { original = nil }
        let store = TripManifestStore()
        var manifest = store.loadTripManifest(folder: folder, oneDrivePicturesRoot: archiveRoot)
        let text: String
        if let original {
            let header = original.components(separatedBy: "\n## ")[0]
            guard header.components(separatedBy: "\n").filter({ $0.hasPrefix("- Trip ID:") }).count == 1 else {
                throw ArchiveFileVerification.failure("The Trip identity is ambiguous. Its text has been retained.")
            }
            guard TripManifestText.headerValue("Trip ID", in: original).flatMap({ UUID(uuidString: $0.trimmingCharacters(in: CharacterSet(charactersIn: "`"))) }) == manifest.tripID,
                  target.tripID == nil || manifest.tripID == target.tripID else {
                throw ArchiveFileVerification.failure("The Trip identity changed. Reload the Archive before editing its label.")
            }
            guard manifest.locationLabelOverride == target.expectedOverride || manifest.locationLabelOverride == label else {
                throw ArchiveFileVerification.failure("The Trip label changed since this view was loaded. Reload before saving.")
            }
            text = original
        } else {
            guard target.tripID == nil, target.expectedOverride == nil else { throw ArchiveFileVerification.failure("The canonical Trip manifest is unavailable.") }
            let members = try store.canonicalWalkMembers(in: folder, oneDrivePicturesRoot: archiveRoot)
            guard !members.isEmpty else { throw ArchiveFileVerification.failure("This folder has no canonical Walks and cannot receive a Trip label.") }
            manifest.memberWalkFolderPaths = members.map(\.relativePath)
            manifest.startDate = members.compactMap(\.date).min(); manifest.endDate = members.compactMap(\.date).max()
            text = ManifestRenderer().renderTripManifest(manifest)
        }
        let replacement = try TripManifestText.settingLabel(label, in: text)
        // A file changed by another editor must not be replaced from an old snapshot.
        if let original {
            guard try String(contentsOf: url, encoding: .utf8) == original else { throw ArchiveFileVerification.failure("The Trip manifest changed while saving. Its latest text has been retained.") }
        } else {
            guard !FileManager.default.fileExists(atPath: url.path) else { throw ArchiveFileVerification.failure("A Trip manifest appeared while saving. Reload before editing.") }
        }
        if original != replacement { try writeText(replacement, url) }
        manifest.locationLabelOverride = label
        return manifest
    }
}

struct TripLocationSaveResult: Sendable {
    let manifest: TripManifest
    let indexError: String?
}

enum TripLocationProjection {
    static func derivedLabel(from walks: [ArchiveWalkSummary]) -> String? {
        let counts = Dictionary(grouping: walks.compactMap { $0.location?.nonEmpty }, by: { $0 }).mapValues(\.count)
        return counts.keys.sorted { left, right in
            counts[left] == counts[right] ? left.localizedStandardCompare(right) == .orderedAscending : counts[left]! > counts[right]!
        }.first
    }

    static func refreshingDerivedLabels(in initial: ArchiveCatalogue) -> ArchiveCatalogue {
        var catalogue = initial
        for index in catalogue.entries.indices where catalogue.entries[index].kind == .trip {
            let trip = catalogue.entries[index]
            catalogue.entries[index].location = trip.locationLabelOverride ?? derivedLabel(from: catalogue.walksByTripPath[trip.archiveRelativePath] ?? [])
        }
        return catalogue
    }

    static func applying(_ manifest: TripManifest, to initial: ArchiveCatalogue) -> ArchiveCatalogue {
        var catalogue = initial
        if let index = catalogue.entries.firstIndex(where: { $0.kind == .trip && $0.archiveRelativePath == manifest.folderRelativePath }) {
            catalogue.entries[index].tripID = manifest.tripID
            catalogue.entries[index].locationLabelOverride = manifest.locationLabelOverride
        }
        return refreshingDerivedLabels(in: catalogue)
    }
}
