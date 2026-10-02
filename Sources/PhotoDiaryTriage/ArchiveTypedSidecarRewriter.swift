import Foundation

// Transform each documented path value once; user text and source provenance stay intact.
extension ArchiveTextSidecarRewriter {
    func rewritePath(_ value: String, spec: ArchiveTextRewriteSpec) -> String {
        let pairs: [(String?, String?)] = [
            (spec.oldAbsoluteFolderPath, spec.newAbsoluteFolderPath),
            (spec.oldRelativeFolderPath, spec.newRelativeFolderPath),
            (spec.oldTripRelativePath, spec.newTripRelativePath)
        ]
        let original = value.hasPrefix("/") ? ArchivePathSafety.resolvedForWrite(URL(fileURLWithPath: value)).path : value
        let mappings = pairs.compactMap { old, new -> (String, String)? in
            guard let old, let new else { return nil }
            let canonicalOld = old.hasPrefix("/") ? ArchivePathSafety.resolvedForWrite(URL(fileURLWithPath: old)).path : old
            return (canonicalOld, new)
        }.sorted { $0.0.count > $1.0.count }
        var result = value
        var mapped = false
        for (old, new) in mappings where original == old || original.hasPrefix(old + "/") {
            result = new + original.dropFirst(old.count)
            mapped = true
            break
        }
        if mapped, let old = spec.oldStemBase, let new = spec.newStemBase {
            let url = URL(fileURLWithPath: result)
            let name = url.lastPathComponent
            if name.hasPrefix(old), String(name.dropFirst(old.count)).range(of: #"^-\d{3}(?:[-.]|$)"#, options: .regularExpression) != nil {
                let renamed = new + name.dropFirst(old.count)
                result = String(result.dropLast(name.count)) + renamed
            }
        }
        return result
    }

    func rewriteStructured(_ text: String, extension ext: String, spec: ArchiveTextRewriteSpec) throws -> String {
        if ext == "jsonl" {
            return try text.components(separatedBy: "\n").map { line in
                guard !line.isEmpty else { return line }
                guard var object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                    throw ArchiveFileVerification.failure("Invalid session event record.")
                }
                // Recorded sources describe history; only destination references follow the archive.
                if var details = object["details"] as? [String: Any] {
                    for key in ["destination", "archive_folder"] {
                        if let path = details[key] as? String { details[key] = rewritePath(path, spec: spec) }
                    }
                    object["details"] = details
                }
                if let path = object["archive_folder"] as? String { object["archive_folder"] = rewritePath(path, spec: spec) }
                return try jsonText(object)
            }.joined(separator: "\n")
        }
        if ext == "json" {
            guard var object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return text }
            let isCrop = object["sourceMediaItemID"] != nil && object["crops"] is [[String: Any]]
            let isLegacyReference = object["archiveRelativePath"] != nil && object["tripFolderRelativePath"] != nil
            guard isCrop || isLegacyReference else { return text }
            if isCrop {
                if let path = object["sourcePath"] as? String {
                    let updated = rewritePath(path, spec: spec)
                    object["sourcePath"] = updated
                    if updated != path { object["sourceFileName"] = URL(fileURLWithPath: updated).lastPathComponent }
                }
                object["crops"] = (object["crops"] as! [[String: Any]]).map { entry in
                    var entry = entry
                    if let path = entry["outputPath"] as? String {
                        let updated = rewritePath(path, spec: spec)
                        entry["outputPath"] = updated
                        if updated != path { entry["outputFileName"] = URL(fileURLWithPath: updated).lastPathComponent }
                    }
                    return entry
                }
            } else {
                for key in ["archiveRelativePath", "tripFolderRelativePath"] {
                    if let path = object[key] as? String { object[key] = rewritePath(path, spec: spec) }
                }
            }
            return try jsonText(object)
        }
        let pathKeys: Set<String> = ["archive_path", "archive_relative_path", "companion_archive_paths", "companion_archive_relative_paths"]
        let headers = ["Archive folder:", "OneDrive Pictures relative folder:", "Trip folder:", "Folder:"]
        var inFrontmatter = text.hasPrefix("---\n")
        var inLegacyHeader = text.hasPrefix("archive_path:")
        var listKey: String?
        var section = ""
        var isHeader = true
        let notesStart = text.range(of: "## Notes\n").map { text.distance(from: text.startIndex, to: $0.lowerBound) }
        let notesEnd = ArchiveManifestText.sourceReport(in: text).map { text.distance(from: text.startIndex, to: $0.lowerBound) + 1 }
        var offset = 0
        let lines = text.components(separatedBy: "\n")
        return lines.enumerated().map { index, line in
            let lineOffset = offset
            offset += line.count + 1
            if let notesStart, let notesEnd, lineOffset >= notesStart && lineOffset < notesEnd { return line }
            if line.isEmpty { inLegacyHeader = false }
            if line == "---" {
                if index > 0 { inFrontmatter = false }; return line
            }
            if line.hasPrefix("## ") {
                section = String(line.dropFirst(3)); isHeader = false; return line
            }
            if inFrontmatter || inLegacyHeader || listKey != nil {
                if line.hasPrefix("  - "), let key = listKey, pathKeys.contains(key) {
                    let value = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                    return "  - " + ArchiveManifestText.quotedScalar(rewritePath(ArchiveManifestText.unquote(value), spec: spec))
                }
                listKey = nil
            }
            if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon])
                if pathKeys.contains(key) && (inFrontmatter || inLegacyHeader) {
                    let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    if value.isEmpty { listKey = key; return line }
                    let updated = rewritePath(ArchiveManifestText.unquote(value), spec: spec)
                    return key + ": " + (value.hasPrefix("\"") ? ArchiveManifestText.quotedScalar(updated) : updated)
                }
            }
            if isHeader, let label = headers.first(where: { line.hasPrefix("- " + $0) || line.hasPrefix($0) }) {
                let prefix = line.hasPrefix("- ") ? "- " + label : label
                let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                let ticked = value.hasPrefix("`") && value.hasSuffix("`")
                let path = ticked ? String(value.dropFirst().dropLast()) : value
                let updated = rewritePath(path, spec: spec)
                return prefix + " " + (ticked ? "`\(updated)`" : updated)
            }
            if section == "Imported Files", let arrow = line.range(of: " -> ") {
                return String(line[..<arrow.upperBound]) + rewriteBacktickedPaths(String(line[arrow.upperBound...]), spec: spec)
            }
            if section == "Member Walks", line.hasPrefix("- `") {
                return rewriteBacktickedPaths(line, spec: spec)
            }
            return line
        }.joined(separator: "\n")
    }

    private func rewriteBacktickedPaths(_ value: String, spec: ArchiveTextRewriteSpec) -> String {
        let pieces = value.components(separatedBy: "`")
        return pieces.enumerated().map { index, piece in index % 2 == 1 ? rewritePath(piece, spec: spec) : piece }.joined(separator: "`")
    }

    private func jsonText(_ object: [String: Any]) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }
}
