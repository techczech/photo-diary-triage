import Foundation

enum ArchiveManifestText {
    static func quotedScalar(_ value: String) -> String {
        String(decoding: try! JSONEncoder().encode(value), as: UTF8.self)
    }

    static func unquote(_ value: String) -> String {
        (try? JSONDecoder().decode(String.self, from: Data(value.utf8))) ?? value
    }

    static func frontmatter(in text: String) -> String {
        guard text.hasPrefix("---\n"), let end = text.range(of: "\n---", range: text.index(text.startIndex, offsetBy: 4)..<text.endIndex) else { return text }
        return String(text[text.index(text.startIndex, offsetBy: 4)..<end.lowerBound])
    }

    static func scalar(_ key: String, in text: String) -> String? {
        guard let line = frontmatter(in: text).split(separator: "\n", omittingEmptySubsequences: false)
            .first(where: { $0.hasPrefix("\(key):") }) else { return nil }
        return unquote(String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces))
    }

    static func sourceReport(in text: String) -> Range<String.Index>? {
        text.range(of: "\n## Source Report\n\n- Total source files:", options: .backwards)
            ?? text.range(of: "\n## Source Report", options: .backwards)
    }

    static func body(in text: String) -> String {
        guard text.hasPrefix("---\n"), let end = text.range(of: "\n---\n") else { return "" }
        return String(text[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removingScalar(_ key: String, in text: String) -> String {
        guard let end = text.range(of: "\n---\n"), text.hasPrefix("---\n") else { return text }
        let header = String(text[..<end.lowerBound]).components(separatedBy: "\n")
            .filter { !$0.hasPrefix("\(key):") }.joined(separator: "\n")
        return header + text[end.lowerBound...]
    }

    static func settingScalar(_ key: String, to value: String, in text: String) -> String {
        guard let end = text.range(of: "\n---\n"), text.hasPrefix("---\n") else { return text }
        var header = String(text[..<end.lowerBound]).components(separatedBy: "\n")
        let line = "\(key): \(quotedScalar(value))"
        if let index = header.firstIndex(where: { $0.hasPrefix("\(key):") }) { header[index] = line }
        else { header.append(line) }
        return header.joined(separator: "\n") + text[end.lowerBound...]
    }
}

struct ArchiveMetadataChange: Codable {
    var url: URL
    var original: String
    var replacement: String
}

struct ArchiveMetadataRecovery: Codable {
    var metadata: WalkMetadata
    var changes: [ArchiveMetadataChange]
    var complete = false
}

struct ArchiveManifestEditor {
    func saveMetadata(for session: ImportSession, previousMetadata: WalkMetadata? = nil) throws {
        let folders = Set(session.mediaItems.compactMap { $0.destinationURL?.deletingLastPathComponent() })
        guard !folders.isEmpty else { return }
        let mutationLock = try ArchiveMutationLock(archiveRoot: session.archiveRoot)
        defer { withExtendedLifetime(mutationLock) {} }
        for folder in folders { try ArchiveLocationEditor.assertNoPending(overlapping: folder, archiveRoot: session.archiveRoot) }
        let recovery = ArchiveOperationRecovery(archiveRoot: session.archiveRoot)
        var record: ArchiveMetadataRecovery
        if let saved = try recovery.load(ArchiveMetadataRecovery.self, kind: "metadata", sessionID: session.id), !saved.complete {
            guard saved.metadata == session.walkMetadata else {
                throw ArchiveFileVerification.failure("Finish the previous metadata save before changing these notes again.")
            }
            record = saved
        } else {
            var changes: [ArchiveMetadataChange] = []
            var titles: [URL: (String, String)] = [:]
            var locations: [URL: (String, String)] = [:]
            for folder in folders.sorted(by: { $0.path < $1.path }) {
                let url = folder.appendingPathComponent("\(folder.lastPathComponent).md")
                let original = try String(contentsOf: url, encoding: .utf8)
                var replacement = original
                let oldTitle = original.components(separatedBy: "\n").first?.dropFirst(2).description ?? ""
                let oldLocation = headerValue("Location", in: original) ?? ""
                if (previousMetadata == nil || (previousMetadata!.title != session.walkMetadata.title && oldTitle == previousMetadata!.title)),
                   let heading = replacement.range(of: "# "), heading.lowerBound == replacement.startIndex,
                   let end = replacement.range(of: "\n", range: heading.upperBound..<replacement.endIndex) {
                    replacement.replaceSubrange(heading.lowerBound..<end.lowerBound, with: "# \(session.walkMetadata.title)")
                }
                let headerValues: [(String, String?, String?)] = [
                    ("Location", session.walkMetadata.location.nonEmpty, previousMetadata?.location.nonEmpty),
                    ("Latitude", session.walkMetadata.latitude.map { String($0) }, previousMetadata?.latitude.map { String($0) }),
                    ("Longitude", session.walkMetadata.longitude.map { String($0) }, previousMetadata?.longitude.map { String($0) })
                ]
                for (label, value, oldDefault) in headerValues {
                    if previousMetadata == nil || (value != oldDefault && headerValue(label, in: original) == oldDefault) {
                        replacement = Self.settingHeader(label, value: value, in: replacement)
                    }
                }
                guard let notes = replacement.range(of: "## Notes\n"),
                      let report = ArchiveManifestText.sourceReport(in: replacement), report.lowerBound > notes.upperBound else {
                    throw ArchiveFileVerification.failure("The Walk notes section could not be read: \(url.lastPathComponent)")
                }
                guard let originalNotes = original.range(of: "## Notes\n"),
                      let originalReport = ArchiveManifestText.sourceReport(in: original), originalReport.lowerBound > originalNotes.upperBound else {
                    throw ArchiveFileVerification.failure("The original Walk notes section could not be read.")
                }
                let oldNotes = String(original[originalNotes.upperBound..<originalReport.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if previousMetadata == nil || (previousMetadata!.notes != session.walkMetadata.notes
                    && oldNotes == (previousMetadata!.notes.nonEmpty ?? "_No notes provided._")) {
                    replacement.replaceSubrange(notes.upperBound..<report.lowerBound,
                        with: "\n\(session.walkMetadata.notes.nonEmpty ?? "_No notes provided._")\n")
                }
                titles[folder] = (oldTitle, replacement.components(separatedBy: "\n").first?.dropFirst(2).description ?? oldTitle)
                locations[folder] = (oldLocation, headerValue("Location", in: replacement) ?? "")
                changes.append(ArchiveMetadataChange(url: url, original: original, replacement: replacement))
            }
            for item in session.mediaItems {
                guard let destination = item.destinationURL else { continue }
                let url = destination.deletingPathExtension().appendingPathExtension("md")
                let original = try String(contentsOf: url, encoding: .utf8)
                var replacement = original
                let folder = destination.deletingLastPathComponent()
                if let values = titles[folder], ArchiveManifestText.scalar("walk_title", in: original) == values.0 {
                    replacement = ArchiveManifestText.settingScalar("walk_title", to: values.1, in: replacement)
                }
                if let values = locations[folder], ArchiveManifestText.scalar("walk_location", in: original) == values.0 {
                    replacement = ArchiveManifestText.settingScalar("walk_location", to: values.1, in: replacement)
                }
                changes.append(ArchiveMetadataChange(url: url, original: original, replacement: replacement))
            }
            record = ArchiveMetadataRecovery(metadata: session.walkMetadata, changes: changes)
            try recovery.save(record, kind: "metadata", sessionID: session.id)
        }
        for change in record.changes {
            let current = try String(contentsOf: change.url, encoding: .utf8)
            guard current == change.original || current == change.replacement else {
                throw ArchiveFileVerification.failure("This manifest changed while saving: \(change.url.lastPathComponent). Your existing text has been retained.")
            }
            if current != change.replacement {
                try change.replacement.write(to: change.url, atomically: true, encoding: .utf8)
            }
        }
        record.complete = true
        try recovery.save(record, kind: "metadata", sessionID: session.id)
    }

    private func headerValue(_ label: String, in text: String) -> String? {
        text.components(separatedBy: "## Notes")[0].components(separatedBy: "\n")
            .first { $0.hasPrefix("- \(label):") }?
            .dropFirst(label.count + 3).trimmingCharacters(in: .whitespaces).nonEmpty
    }

    static func settingHeader(_ label: String, value: String?, in text: String) -> String {
        guard let notes = text.range(of: "## Notes") else { return text }
        var header = String(text[..<notes.lowerBound]).components(separatedBy: "\n")
        let prefix = "- \(label):"
        if let index = header.firstIndex(where: { $0.hasPrefix(prefix) }) {
            if let value { header[index] = "\(prefix) \(value)" }
            else { header.remove(at: index) }
        } else if let value {
            header.insert("\(prefix) \(value)", at: max(0, header.count - 1))
        }
        return header.joined(separator: "\n") + text[notes.lowerBound...]
    }
}
