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
    private static func makeWalkFolderFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "yyyy/MM/yyyy-MM-dd"
        return formatter
    }

    static func walkFolderPath(from date: Date) -> String {
        makeWalkFolderFormatter().string(from: date)
    }

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
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
