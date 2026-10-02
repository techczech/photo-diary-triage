import Darwin
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

    struct WalkPlan: Equatable, Codable {
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
        var archiveRoot: URL?
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

    private struct Recovery: Codable {
        var walks: [WalkPlan]
        var months: [URL]
        var complete = false
    }
    private static let recoveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // MARK: - Planning

    func plan(archiveRoot: URL) -> Plan {
        var plan = Plan(archiveRoot: archiveRoot)
        do {
            if let saved = try ArchiveOperationRecovery(archiveRoot: archiveRoot).load(Recovery.self, kind: "migration", sessionID: Self.recoveryID), !saved.complete {
                plan.walks = saved.walks
                plan.legacyMonthURLs = saved.months
                return plan
            }
        } catch { plan.skipped.append((archiveRoot, "unreadable migration recovery: \(error.localizedDescription)")); return plan }
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
                    let manifest = walkURL.appendingPathComponent("\(walkName).md")
                    guard let text = try? String(contentsOf: manifest, encoding: .utf8),
                          let identityLine = text.components(separatedBy: "## Notes")[0].components(separatedBy: "\n").first(where: { $0.hasPrefix("- Session ID: `") }),
                          UUID(uuidString: String(identityLine.dropFirst(15).dropLast())) != nil,
                          let archiveLine = text.components(separatedBy: "## Notes")[0].components(separatedBy: "\n").first(where: { $0.hasPrefix("- Archive folder: `") }),
                          URL(fileURLWithPath: String(archiveLine.dropFirst(19).dropLast())).resolvingSymlinksInPath().standardizedFileURL.path == walkURL.resolvingSymlinksInPath().standardizedFileURL.path else {
                        plan.skipped.append((walkURL, "no verified app-written Walk manifest (historical material retained)"))
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
        guard let root = plan.archiveRoot else { result.failures = ["Missing migration archive root."]; return result }
        let lock: ArchiveMutationLock
        do {
            lock = try ArchiveMutationLock(archiveRoot: root)
            for walk in plan.walks { try ArchiveLocationEditor.assertNoPending(overlapping: walk.oldWalkURL, archiveRoot: root) }
            try ArchiveOperationRecovery(archiveRoot: root).save(Recovery(walks: plan.walks, months: plan.legacyMonthURLs), kind: "migration", sessionID: Self.recoveryID)
        } catch { result.failures = [error.localizedDescription]; return result }
        defer { withExtendedLifetime(lock) {} }
        for walk in plan.walks {
            do {
                let counts = try migrate(walk, archiveRoot: root)
                result.migratedWalks += 1
                result.renamedFiles += counts.renamedFiles
                result.rewrittenTextFiles += counts.rewrittenTextFiles
            } catch {
                result.failures.append("\(walk.oldWalkURL.path): \(error.localizedDescription)")
            }
        }

        for monthURL in plan.legacyMonthURLs where fileManager.fileExists(atPath: monthURL.path) {
            do {
                let remaining = try fileManager.contentsOfDirectory(at: monthURL, includingPropertiesForKeys: nil)
                if remaining.isEmpty {
                    guard Darwin.rmdir(monthURL.path) == 0 else { throw CocoaError(.fileWriteNoPermission) }
                    result.removedLegacyMonthFolders += 1
                }
            } catch { result.failures.append("remove \(monthURL.path): \(error.localizedDescription)") }
        }
        if result.failures.isEmpty {
            do { try ArchiveOperationRecovery(archiveRoot: root).save(Recovery(walks: plan.walks, months: plan.legacyMonthURLs, complete: true), kind: "migration", sessionID: Self.recoveryID) }
            catch { result.failures.append(error.localizedDescription) }
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
            let contents: [URL]
            do {
                contents = try fileManager.contentsOfDirectory(at: walk.newWalkURL, includingPropertiesForKeys: nil)
                if let root = plan.archiveRoot {
                    let operation = ArchiveFolderOperation(archiveRoot: root, fileManager: fileManager)
                    guard let record = try operation.recorded(for: walk.oldWalkURL), record.complete else {
                        problems.append("unfinished migration: \(walk.newWalkURL.path)"); continue
                    }
                    for change in record.changes {
                        if try String(contentsOf: walk.newWalkURL.appendingPathComponent(change.name), encoding: .utf8) != change.replacement {
                            problems.append("unverified sidecar: \(change.name)")
                        }
                    }
                }
            } catch { problems.append(error.localizedDescription); continue }
            for file in contents where file.lastPathComponent.hasPrefix(walk.oldStemBase) {
                problems.append("legacy-named file survived: \(file.path)")
            }
            if fileManager.fileExists(atPath: walk.oldWalkURL.path) && walk.oldWalkURL != walk.newWalkURL {
                problems.append("legacy folder still present: \(walk.oldWalkURL.path)")
            }
        }
        return problems
    }

    private func migrate(_ walk: WalkPlan, archiveRoot: URL) throws -> (renamedFiles: Int, rewrittenTextFiles: Int) {
        let operation = ArchiveFolderOperation(archiveRoot: archiveRoot, fileManager: fileManager)
        let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: walk.oldWalkURL.path, newAbsoluteFolderPath: walk.newWalkURL.path,
            oldRelativeFolderPath: "\(walk.yearName)/\(walk.oldMonthName)/\(walk.oldWalkName)",
            newRelativeFolderPath: "\(walk.yearName)/\(walk.newMonthName)/\(walk.newWalkName)",
            oldTripRelativePath: "\(walk.yearName)/\(walk.oldMonthName)", newTripRelativePath: "\(walk.yearName)/\(walk.newMonthName)",
            oldStemBase: walk.oldStemBase, newStemBase: walk.newStemBase)
        var names: [String: String] = [:]
        if fileManager.fileExists(atPath: walk.oldWalkURL.path) {
            let extensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff", "tif", "cr3", "cr2", "raf", "nef", "arw", "dng", "md", "json", "jsonl", "mov", "mp4"]
            for file in try fileManager.contentsOfDirectory(at: walk.oldWalkURL, includingPropertiesForKeys: [.isRegularFileKey]) {
                let name = file.lastPathComponent
                guard extensions.contains(file.pathExtension.lowercased()), name.hasPrefix(walk.oldStemBase) else { continue }
                let suffix = String(name.dropFirst(walk.oldStemBase.count))
                if suffix.range(of: #"^-\d{3}(?:[-.]|$)"#, options: .regularExpression) != nil {
                    names[name] = walk.newStemBase + suffix
                } else if name == walk.oldWalkName + ".md" || name == walk.oldWalkName + "-session-log.jsonl" {
                    names[name] = walk.newWalkName + suffix
                }
            }
        }
        let record = try operation.prepare(source: walk.oldWalkURL, destination: walk.newWalkURL, spec: spec, names: names)
        _ = try operation.execute(record)
        _ = try ArchiveIndexStore(fileManager: fileManager).loadWalkManifest(folder: walk.newWalkURL, archiveRoot: archiveRoot)
        try operation.complete(record)
        return (record.renames.count, record.changes.count)
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
