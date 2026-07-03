import CryptoKit
import Foundation

enum AppPaths {
    static func supportRoot(fileManager: FileManager = .default) -> URL {
        let libraryRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return libraryRoot.appendingPathComponent("PhotoDiaryTriage", isDirectory: true)
    }
}

enum Slugifier {
    static func makeSlug(from input: String) -> String {
        let lowered = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowedScalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(allowedScalars).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-")).nonEmpty ?? "photo-walk"
    }

    static func makeDisplaySlug(from input: String) -> String {
        let slug = makeSlug(from: input)
        guard let first = slug.first else { return slug }
        return String(first).uppercased() + slug.dropFirst()
    }
}

extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

enum AppDirectories {
    static func ensureExists(_ url: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
}

enum CacheKeyBuilder {
    static func key(for url: URL) -> String {
        let digest = Insecure.MD5.hash(data: Data(url.path.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

enum DateFormatting {
    private static func archiveFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    static func archiveYearFolderName(from date: Date) -> String {
        archiveFormatter("yyyy").string(from: date)
    }

    // Layout v2 (ADR 0001): YYYY / MM-MonthName[-Trip-Slug] / DD-Ddd-Walk-Slug / yyyy-MM-dd-slug-NNN.ext
    static func archiveTripFolderName(from date: Date, tripTitle: String? = nil) -> String {
        let month = archiveFormatter("MM-MMMM").string(from: date)
        guard let tripTitle = tripTitle?.nonEmpty else { return month }
        return "\(month)-\(Slugifier.makeDisplaySlug(from: tripTitle))"
    }

    static func archiveWalkFolderName(from date: Date, title: String) -> String {
        "\(archiveFormatter("dd-\(weekdayFormat)").string(from: date))-\(Slugifier.makeDisplaySlug(from: title))"
    }

    static func archiveFileStem(from date: Date, title: String) -> String {
        "\(archiveFormatter("yyyy-MM-dd").string(from: date))-\(Slugifier.makeSlug(from: title))"
    }

    // Weekday token in walk folder names; user-configurable style, fixed per archive.
    // "EEE" = English abbreviation (Thu), the default per ADR 0001.
    static var weekdayFormat: String = "EEE"

    // Legacy (pre-v2) names, kept for the layout migrator to recognise and rewrite.
    static func legacyArchiveMonthFolderName(from date: Date) -> String {
        archiveFormatter("MM - MMMM").string(from: date)
    }

    static func legacyArchiveWalkFolderPrefix(from date: Date) -> String {
        archiveFormatter("dd-EEEE").string(from: date)
    }

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let reviewCardTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "dd MMM HH:mm"
        return formatter
    }()

    static let automaticPhotoLogTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "yyyy-MM-dd EEEE"
        return formatter
    }()
}

enum ArchiveLibraryInspector {
    static func existingYearFolders(in root: URL, fileManager: FileManager = .default) -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        return entries.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            let name = url.lastPathComponent
            guard name.range(of: #"^(19|20)\d\d$"#, options: .regularExpression) != nil else { return nil }
            return name
        }
        .sorted()
    }
}
