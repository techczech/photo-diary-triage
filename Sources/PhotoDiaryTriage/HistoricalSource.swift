import Foundation

enum HistoricalDatePreference: String, Codable, Hashable, Sendable { case camera, folder }
enum CaptureDatePrecision: String, Codable, Hashable, Sendable { case time, day, month, year, unknown }
enum CaptureDateSource: String, Codable, Hashable, Sendable { case camera, folder, fileModification, unknown }

struct CaptureDateEvidence: Codable, Hashable, Sendable {
    let source: CaptureDateSource
    let precision: CaptureDatePrecision
    let originalCameraDate: Date?
    let folderDate: Date?
    let conflictsWithFolder: Bool

    static func read(in text: String) throws -> Self? {
        guard let sourceName = ArchiveManifestText.scalar("capture_date_source", in: text) else { return nil }
        guard let source = CaptureDateSource(rawValue: sourceName),
              let precision = ArchiveManifestText.scalar("capture_date_precision", in: text).flatMap(CaptureDatePrecision.init(rawValue:)) else {
            throw ArchiveFileVerification.failure("The capture-date evidence is invalid.")
        }
        return Self(source: source, precision: precision,
            originalCameraDate: ArchiveManifestText.scalar("original_captured_at", in: text).flatMap { DateFormatting.iso8601.date(from: $0) },
            folderDate: ArchiveManifestText.scalar("folder_date_hint", in: text).flatMap { DateFormatting.iso8601.date(from: $0) },
            conflictsWithFolder: ArchiveManifestText.scalar("capture_date_conflicts_with_folder", in: text) == "true")
    }
}

struct HistoricalSourceContext: Codable, Hashable, Sendable {
    let root: URL
    var datePreference: HistoricalDatePreference = .camera
    var proposedTripTitle: String? { HistoricalSourceHints.title(from: root.lastPathComponent) }
}

struct HistoricalFolderDate: Equatable, Sendable {
    let date: Date
    let precision: CaptureDatePrecision
}

enum HistoricalSourceHints {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!; return calendar
    }

    static func title(from name: String) -> String? {
        let cleaned = name.replacingOccurrences(of: #"^(?:19|20)\d{2}(?:[-_ .]\d{1,2}){0,2}(?:[-_ .]+|$)"#,
            with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.range(of: #"^\d{1,4}$|^\d{3}[A-Za-z]+$"#, options: .regularExpression) == nil,
              cleaned.range(of: #"^(?:IMG|DSC|DSCF|DSCN|PXL|MOV)[-_ ]?\d+$"#, options: [.regularExpression, .caseInsensitive]) == nil,
              !["dcim", "camera", "camera roll", "100canon", "private", "tmp"].contains(cleaned.lowercased()) else { return nil }
        return cleaned
    }

    static func folderDate(for file: URL, root: URL) -> HistoricalFolderDate? {
        // Use folders, never numeric camera filenames. Look back for a selected date-only leaf.
        let folder = file.deletingLastPathComponent()
        let rootDepth = root.pathComponents.count
        let parts = Array(folder.pathComponents.dropFirst(max(0, rootDepth - 3)))
        var candidates: [(Int, HistoricalFolderDate)] = []
        for index in parts.indices {
            let name = parts[index]
            if let values = captures(#"^((?:19|20)\d{2})(?:[-_ .](\d{1,2}))?(?:[-_ .](\d{1,2}))?(?:[^0-9]|$)"#, in: name),
               let year = Int(values[0]) {
                let month = values.count > 1 ? Int(values[1]) : nil
                let day = values.count > 2 ? Int(values[2]) : nil
                if let hint = date(year: year, month: month, day: day) { candidates.append((index, hint)) }
            }
            if name.range(of: #"^(19|20)\d{2}$"#, options: .regularExpression) != nil, let year = Int(name) {
                let month = index + 1 < parts.count ? Int(parts[index + 1]) : nil
                let day = index + 2 < parts.count ? Int(parts[index + 2]) : nil
                if let hint = date(year: year, month: month, day: day) { candidates.append((index, hint)) }
            }
        }
        return candidates.max { left, right in
            if left.0 != right.0 { return left.0 < right.0 }
            return precisionRank(left.1.precision) < precisionRank(right.1.precision)
        }?.1
    }

    static func applying(to item: MediaItem, context: HistoricalSourceContext, now: Date = Date()) -> MediaItem {
        var item = item
        let camera = item.metadata.capturedAt
        let validCamera = camera.flatMap { value -> Date? in
            let year = calendar.component(.year, from: value)
            return year >= 1850 && value <= now.addingTimeInterval(86_400) ? value : nil
        }
        let folder = folderDate(for: item.sourceURL, root: context.root)
        let conflict = validCamera.map { value in
            guard let folder else { return false }
            let units: Set<Calendar.Component> = folder.precision == .year ? [.year]
                : (folder.precision == .month ? [.year, .month] : [.year, .month, .day])
            return calendar.dateComponents(units, from: value) != calendar.dateComponents(units, from: folder.date)
        } ?? false
        let useFolder = folder != nil && (validCamera == nil || context.datePreference == .folder)
        let modified = item.sourceModificationTime.map(Date.init(timeIntervalSince1970:))
        item.capturedAt = useFolder ? folder?.date : (validCamera ?? modified)
        item.captureDateEvidence = CaptureDateEvidence(source: useFolder ? .folder : (validCamera != nil ? .camera : (modified != nil ? .fileModification : .unknown)),
            precision: useFolder ? folder!.precision : (item.capturedAt != nil ? .time : .unknown),
            originalCameraDate: camera, folderDate: folder?.date, conflictsWithFolder: conflict)
        return item
    }

    static func walkTitle(for items: [MediaItem], context: HistoricalSourceContext) -> String? {
        let names = Set(items.compactMap { item -> String? in
            let parent = item.sourceURL.deletingLastPathComponent()
            return parent.standardizedFileURL == context.root.standardizedFileURL ? nil : title(from: parent.lastPathComponent)
        })
        return names.count == 1 ? names.first : context.proposedTripTitle
    }

    private static func date(year: Int, month: Int?, day: Int?) -> HistoricalFolderDate? {
        guard (1850...2099).contains(year), month.map({ (1...12).contains($0) }) ?? true,
              day.map({ (1...31).contains($0) }) ?? true else { return nil }
        let components = DateComponents(year: year, month: month ?? 1, day: day ?? 1, hour: 12)
        guard let date = calendar.date(from: components), calendar.component(.year, from: date) == year,
              calendar.component(.month, from: date) == (month ?? 1), calendar.component(.day, from: date) == (day ?? 1) else { return nil }
        return HistoricalFolderDate(date: date, precision: day != nil ? .day : (month != nil ? .month : .year))
    }

    private static func captures(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } }
    }

    private static func precisionRank(_ value: CaptureDatePrecision) -> Int {
        switch value { case .day: return 3; case .month: return 2; case .year: return 1; default: return 0 }
    }
}

enum HistoricalSourceSafety {
    static func validate(root: URL, archiveRoot: URL, fileManager: FileManager = .default) throws {
        guard root.standardizedFileURL != archiveRoot.standardizedFileURL,
              try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
              try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
            throw ArchiveFileVerification.failure("Choose a specific historical folder, not the Archive root or a symbolic link.")
        }
        var enumerationError: Error?
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles], errorHandler: { _, error in enumerationError = error; return false }) else {
            throw ArchiveFileVerification.failure("The historical source folder could not be enumerated.")
        }
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            if url.lastPathComponent == "_index" { enumerator.skipDescendants(); continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw ArchiveFileVerification.failure("Historical sources must not contain symbolic links.") }
            guard values.isRegularFile == true, url.pathExtension.lowercased() == "md",
                  url.deletingPathExtension().lastPathComponent == url.deletingLastPathComponent().lastPathComponent else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            let header = text.components(separatedBy: "## Notes")[0]
            if header.contains("- Session ID: `") || header.contains("- Trip ID: `") {
                throw ArchiveFileVerification.failure("This source contains canonical Walk/Trip material. Choose an unorganised historical folder instead.")
            }
        }
        if let enumerationError { throw enumerationError }
    }

    static func context(for source: URL, in session: ImportSession) -> HistoricalSourceContext? {
        session.sourceProvenances.compactMap(\.historical).first { context in
            let resolver = ArchiveRelativePathResolver(root: context.root.resolvingSymlinksInPath())
            return resolver.relativePath(for: source.resolvingSymlinksInPath()) != nil
        }
    }
}
