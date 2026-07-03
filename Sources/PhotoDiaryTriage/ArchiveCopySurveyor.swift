import Foundation

struct ArchiveCopySurveyor: Sendable {
    func survey(items: [MediaItem], archiveRoot: URL) async -> [String: SourceArchiveCopySnapshot] {
        let sourceItems = items.map {
            ArchiveCopySurveySourceItem(
                relativePath: $0.relativePath,
                fileName: $0.fileName,
                fileSizeBytes: $0.fileSizeBytes,
                capturedAt: $0.capturedAt
            )
        }
        let root = archiveRoot.standardizedFileURL

        return await Task.detached(priority: .utility) {
            Self.survey(sourceItems: sourceItems, archiveRoot: root)
        }.value
    }

    private static func survey(
        sourceItems: [ArchiveCopySurveySourceItem],
        archiveRoot: URL,
        fileManager: FileManager = .default
    ) -> [String: SourceArchiveCopySnapshot] {
        guard !sourceItems.isEmpty else { return [:] }

        let itemsByFilename = Dictionary(grouping: sourceItems) {
            $0.fileName.lowercased()
        }
        var copiesByRelativePath: [String: SourceArchiveCopySnapshot] = [:]

        for root in surveyRoots(for: sourceItems, archiveRoot: archiveRoot, fileManager: fileManager) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let manifestURL as URL in enumerator {
                guard manifestURL.pathExtension.lowercased() == "md" else { continue }
                guard let manifest = ArchiveCopyManifest(url: manifestURL) else { continue }
                guard let candidateItems = itemsByFilename[manifest.sourceFileName.lowercased()] else { continue }
                guard fileManager.fileExists(atPath: manifest.archivePath) else { continue }
                guard let archivedSize = fileSize(at: manifest.archivePath, fileManager: fileManager) else { continue }

                for item in candidateItems where copiesByRelativePath[item.relativePath] == nil {
                    guard item.fileSizeBytes == archivedSize else { continue }
                    if let sourceCapturedAt = item.capturedAt, let archivedCapturedAt = manifest.capturedAt {
                        guard abs(sourceCapturedAt.timeIntervalSince(archivedCapturedAt)) < 1 else { continue }
                    }

                    copiesByRelativePath[item.relativePath] = SourceArchiveCopySnapshot(
                        archivePath: manifest.archivePath,
                        archiveRelativePath: manifest.archiveRelativePath,
                        sourceFileName: manifest.sourceFileName
                    )
                }
            }
        }

        return copiesByRelativePath
    }

    private static func surveyRoots(
        for sourceItems: [ArchiveCopySurveySourceItem],
        archiveRoot: URL,
        fileManager: FileManager
    ) -> [URL] {
        var monthRoots: [String: URL] = [:]
        var hasUndatedItems = false

        for item in sourceItems {
            guard let capturedAt = item.capturedAt else {
                hasUndatedItems = true
                continue
            }
            let yearRoot = archiveRoot
                .appendingPathComponent(DateFormatting.archiveYearFolderName(from: capturedAt), isDirectory: true)
            // v2 month Trips plus legacy "MM - MMMM" folders; named Trips share the month prefix.
            let monthPrefix = DateFormatting.archiveTripFolderName(from: capturedAt)
            let legacyName = DateFormatting.legacyArchiveMonthFolderName(from: capturedAt)
            let candidates = (try? fileManager.contentsOfDirectory(at: yearRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            for candidate in candidates {
                let name = candidate.lastPathComponent
                guard name == legacyName || name == monthPrefix || name.hasPrefix(monthPrefix + "-") else { continue }
                let root = candidate.standardizedFileURL
                monthRoots[root.path] = root
            }
        }

        if hasUndatedItems {
            monthRoots[archiveRoot.standardizedFileURL.path] = archiveRoot.standardizedFileURL
        }

        return monthRoots.values.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    private static func fileSize(at path: String, fileManager: FileManager) -> Int64? {
        guard let number = try? fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber else {
            return nil
        }
        return number.int64Value
    }
}

private struct ArchiveCopySurveySourceItem: Sendable {
    let relativePath: String
    let fileName: String
    let fileSizeBytes: Int64
    let capturedAt: Date?
}

private struct ArchiveCopyManifest {
    let archivePath: String
    let archiveRelativePath: String?
    let sourceFileName: String
    let capturedAt: Date?

    init?(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let frontMatter = Self.frontMatterLines(from: text)
        guard let archivePath = frontMatter["archive_path"]?.nonEmpty else { return nil }
        guard let sourceFileName = frontMatter["source_file_name"]?.nonEmpty else { return nil }

        self.archivePath = archivePath
        self.archiveRelativePath = frontMatter["archive_relative_path"]?.nonEmpty
        self.sourceFileName = sourceFileName
        if let captured = frontMatter["captured_at"] {
            self.capturedAt = DateFormatting.iso8601.date(from: captured)
        } else {
            self.capturedAt = nil
        }
    }

    private static func frontMatterLines(from text: String) -> [String: String] {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---" else { return [:] }
        lines.removeFirst()

        var values: [String: String] = [:]
        for line in lines {
            guard line != "---" else { break }
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = unquote(rawValue)
        }
        return values
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else {
            return value
        }
        let inner = value.dropFirst().dropLast()
        return inner.replacingOccurrences(of: "\\\"", with: "\"")
    }
}
