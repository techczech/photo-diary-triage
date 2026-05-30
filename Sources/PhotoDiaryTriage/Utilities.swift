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

enum FrontMatterParser {
    static func values(from text: String) -> [String: String] {
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

    static func archiveMonthFolderName(from date: Date) -> String {
        archiveFormatter("MM - MMMM").string(from: date)
    }

    static func archiveWalkFolderName(from date: Date, title: String) -> String {
        "\(archiveFormatter("dd-EEEE").string(from: date))-\(Slugifier.makeDisplaySlug(from: title))"
    }

    static func navigationMonthTitle(month: Int) -> String {
        guard let date = gregorianDate(year: 2024, month: month, day: 1) else {
            return String(format: "%02d", month)
        }
        return archiveFormatter("MM - MMMM").string(from: date)
    }

    static func navigationMonthTitle(fromFolderName folderName: String) -> String {
        let digits = folderName.prefix { $0.isNumber }
        guard let month = Int(digits), (1...12).contains(month) else {
            return folderName
        }
        return navigationMonthTitle(month: month)
    }

    static func navigationDayTitle(year: Int, month: Int, day: Int) -> String {
        guard let date = gregorianDate(year: year, month: month, day: day) else {
            return String(format: "%02d", day)
        }
        return archiveFormatter("dd - EEE").string(from: date)
    }

    private static func gregorianDate(year: Int, month: Int, day: Int) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)
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
            guard name.range(of: #"^202\d$"#, options: .regularExpression) != nil else { return nil }
            return name
        }
        .sorted()
    }
}
