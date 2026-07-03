import Foundation

/// Migrates app-written archive folders from the legacy layout
/// (`YYYY / "MM - MMMM" / dd-Weekday-Slug / <walkname>-NNN.ext`) to layout v2 (ADR 0001):
/// `YYYY / MM-MonthName / DD-Ddd-Slug / yyyy-MM-dd-slug-NNN.ext`.
/// Pre-app folders (no recognisable legacy names) are skipped — they are historical-
/// processing (WP7) material, not migration material.
struct ArchiveLayoutMigrator {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    struct WalkPlan: Equatable {
        var yearName: String
        var oldMonthName: String
        var newMonthName: String
        var oldWalkName: String
        var newWalkName: String
        /// Old media stem base (== old walk folder name) → new date-bearing stem base.
        var oldStemBase: String
        var newStemBase: String
        var oldWalkURL: URL
        var newWalkURL: URL
    }

    struct Plan {
        var walks: [WalkPlan] = []
        var skipped: [(URL, String)] = []
        /// Legacy month folders that should be removed once emptied.
        var legacyMonthURLs: [URL] = []
    }

    struct ExecutionResult {
        var migratedWalks: Int = 0
        var renamedFiles: Int = 0
        var rewrittenTextFiles: Int = 0
        var removedLegacyMonthFolders: Int = 0
        var failures: [String] = []
    }

    private static let weekdayAbbreviations: [String: String] = [
        "Monday": "Mon", "Tuesday": "Tue", "Wednesday": "Wed", "Thursday": "Thu",
        "Friday": "Fri", "Saturday": "Sat", "Sunday": "Sun",
    ]

    static let legacyMonthPattern = #"^(\d{2}) - (\p{L}+)$"#
    static let v2MonthPattern = #"^(\d{2})-(\p{L}+)"#
    static let legacyWalkPattern = #"^(\d{2})-(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)-(.+)$"#

    // MARK: - Planning

    func plan(archiveRoot: URL) -> Plan {
        var plan = Plan()
        for yearURL in subdirectories(of: archiveRoot) {
            let yearName = yearURL.lastPathComponent
            guard yearName.range(of: #"^(19|20)\d\d$"#, options: .regularExpression) != nil else { continue }

            for monthURL in subdirectories(of: yearURL) {
                let monthName = monthURL.lastPathComponent
                let isLegacyMonth = monthName.range(of: Self.legacyMonthPattern, options: .regularExpression) != nil
                let isV2Month = monthName.range(of: Self.v2MonthPattern, options: .regularExpression) != nil
                guard isLegacyMonth || isV2Month else {
                    plan.skipped.append((monthURL, "unrecognised month folder (pre-app material)"))
                    continue
                }

                let newMonthName = isLegacyMonth
                    ? monthName.replacingOccurrences(of: " - ", with: "-")
                    : monthName
                if isLegacyMonth {
                    plan.legacyMonthURLs.append(monthURL)
                }
                let monthNumber = String(monthName.prefix(2))

                for walkURL in subdirectories(of: monthURL) {
                    let walkName = walkURL.lastPathComponent
                    guard let match = firstMatch(Self.legacyWalkPattern, in: walkName) else {
                        if isLegacyMonth {
                            plan.skipped.append((walkURL, "unrecognised walk folder in legacy month"))
                        }
                        continue
                    }
                    let day = match[0]
                    let weekday = match[1]
                    let slug = match[2]
                    let abbreviation = Self.weekdayAbbreviations[weekday] ?? String(weekday.prefix(3))
                    let newWalkName = "\(day)-\(abbreviation)-\(slug)"
                    let newStemBase = "\(yearName)-\(monthNumber)-\(day)-\(Slugifier.makeSlug(from: slug))"
                    let newWalkURL = yearURL
                        .appendingPathComponent(newMonthName, isDirectory: true)
                        .appendingPathComponent(newWalkName, isDirectory: true)

                    plan.walks.append(WalkPlan(
                        yearName: yearName,
                        oldMonthName: monthName,
                        newMonthName: newMonthName,
                        oldWalkName: walkName,
                        newWalkName: newWalkName,
                        oldStemBase: walkName,
                        newStemBase: newStemBase,
                        oldWalkURL: walkURL,
                        newWalkURL: newWalkURL
                    ))
                }
            }
        }
        return plan
    }

    // MARK: - Execution

    func execute(_ plan: Plan) -> ExecutionResult {
        var result = ExecutionResult()

        for walk in plan.walks {
            do {
                let counts = try migrate(walk)
                result.migratedWalks += 1
                result.renamedFiles += counts.renamedFiles
                result.rewrittenTextFiles += counts.rewrittenTextFiles
            } catch {
                result.failures.append("\(walk.oldWalkURL.path): \(error.localizedDescription)")
            }
        }

        for monthURL in plan.legacyMonthURLs {
            let remaining = (try? fileManager.contentsOfDirectory(at: monthURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            if remaining.isEmpty {
                do {
                    try fileManager.removeItem(at: monthURL)
                    result.removedLegacyMonthFolders += 1
                } catch {
                    result.failures.append("remove \(monthURL.path): \(error.localizedDescription)")
                }
            }
        }

        return result
    }

    /// Verifies a migrated plan: every planned destination exists and contains no legacy-named files.
    func verify(_ plan: Plan) -> [String] {
        var problems: [String] = []
        for walk in plan.walks {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: walk.newWalkURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                problems.append("missing migrated folder: \(walk.newWalkURL.path)")
                continue
            }
            let contents = (try? fileManager.contentsOfDirectory(at: walk.newWalkURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for file in contents where file.lastPathComponent.hasPrefix(walk.oldStemBase) {
                problems.append("legacy-named file survived: \(file.path)")
            }
            if fileManager.fileExists(atPath: walk.oldWalkURL.path) && walk.oldWalkURL != walk.newWalkURL {
                problems.append("legacy folder still present: \(walk.oldWalkURL.path)")
            }
        }
        return problems
    }

    private func migrate(_ walk: WalkPlan) throws -> (renamedFiles: Int, rewrittenTextFiles: Int) {
        // 1. Move the walk folder into the (possibly new) v2 month folder.
        let newMonthURL = walk.newWalkURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: newMonthURL, withIntermediateDirectories: true)
        if walk.oldWalkURL.standardizedFileURL != walk.newWalkURL.standardizedFileURL {
            try fileManager.moveItem(at: walk.oldWalkURL, to: walk.newWalkURL)
        }

        // 2. Rename files: media stems (walkname-NNN…) get the date-bearing stem base;
        //    the walk manifest and session log follow the new walk folder name.
        var renamedFiles = 0
        let contents = try fileManager.contentsOfDirectory(at: walk.newWalkURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for file in contents {
            let name = file.lastPathComponent
            guard name.hasPrefix(walk.oldStemBase) else { continue }
            let suffix = String(name.dropFirst(walk.oldStemBase.count))
            let newName: String
            if suffix.range(of: #"^-\d{3}"#, options: .regularExpression) != nil {
                newName = walk.newStemBase + suffix
            } else {
                newName = walk.newWalkName + suffix
            }
            guard newName != name else { continue }
            try fileManager.moveItem(at: file, to: walk.newWalkURL.appendingPathComponent(newName))
            renamedFiles += 1
        }

        // 3. Rewrite paths and stems inside all text sidecars.
        var rewrittenTextFiles = 0
        let textExtensions: Set<String> = ["md", "json", "jsonl"]
        let updatedContents = try fileManager.contentsOfDirectory(at: walk.newWalkURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for file in updatedContents where textExtensions.contains(file.pathExtension.lowercased()) {
            guard var text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let original = text
            // Full old folder path → new (absolute references).
            text = text.replacingOccurrences(of: walk.oldWalkURL.path, with: walk.newWalkURL.path)
            // Old month path segment → new (relative and remaining absolute references).
            text = text.replacingOccurrences(
                of: "\(walk.yearName)/\(walk.oldMonthName)/\(walk.oldWalkName)",
                with: "\(walk.yearName)/\(walk.newMonthName)/\(walk.newWalkName)"
            )
            // Media stems first (walkname-NNN…), then any remaining walk-name references.
            text = text.replacingOccurrences(
                of: "\(walk.oldStemBase)-(\\d{3})",
                with: "\(walk.newStemBase)-$1",
                options: .regularExpression
            )
            text = text.replacingOccurrences(of: walk.oldWalkName, with: walk.newWalkName)
            if text != original {
                try text.write(to: file, atomically: true, encoding: .utf8)
                rewrittenTextFiles += 1
            }
        }

        return (renamedFiles, rewrittenTextFiles)
    }

    // MARK: - Helpers

    private func subdirectories(of url: URL) -> [URL] {
        let entries = (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return entries.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func firstMatch(_ pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
        else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: string) else { return nil }
            return String(string[range])
        }
    }
}
