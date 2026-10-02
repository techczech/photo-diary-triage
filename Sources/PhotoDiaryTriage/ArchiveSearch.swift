import Foundation

enum ArchiveSearchItemID: Hashable, Sendable {
    case photo(String)
    case entry(String)
}

enum ArchiveFolderLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

/// A catalogue owns this isolated derived database. Tasks retain it while reading.
final class ArchiveSearchDatabaseSnapshot: @unchecked Sendable {
    let id = UUID()
    let archiveRoot: URL
    let databaseURL: URL
    private let ownedDirectory: URL?

    init(archiveRoot: URL, supportRoot: URL) {
        self.archiveRoot = archiveRoot.standardizedFileURL
        let directory = supportRoot.appendingPathComponent("archive-search-snapshots", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        ownedDirectory = directory
        databaseURL = directory.appendingPathComponent("search.sqlite")
    }

    init(borrowing databaseURL: URL, archiveRoot: URL) {
        self.archiveRoot = archiveRoot.standardizedFileURL
        self.databaseURL = databaseURL
        ownedDirectory = nil
    }

    deinit {
        // Only the UUID directory created for this lease can be removed.
        if let ownedDirectory { try? FileManager.default.removeItem(at: ownedDirectory) }
    }
}

enum ArchiveEntryContainment {
    static func entryID(for path: String, entriesByPath: [String: ArchiveBrowseEntry]) -> String? {
        var parent = path
        while !parent.isEmpty && parent != "." {
            if let entry = entriesByPath[parent] { return entry.id }
            let next = (parent as NSString).deletingLastPathComponent
            if next == parent { break }
            parent = next
        }
        return entriesByPath["."]?.id
    }
}

/// Preserve identity when a fresh historical scan assigns new UUIDs to the same paths.
struct ArchiveFolderSelection {
    let selectedPaths: Set<String>
    let focusedPath: String?
    let anchorPath: String?
    let previewPath: String?
    let comparePaths: [String]
}
