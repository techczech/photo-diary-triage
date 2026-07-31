import Foundation
import SQLite3

enum ArchiveBrowseEntryKind: String, Codable, Hashable, Sendable {
    case trip
    case unorganisedFolder

    var title: String {
        switch self {
        case .trip:
            return "Trip"
        case .unorganisedFolder:
            return "Unorganised folder"
        }
    }
}

enum ArchiveBrowseViewMode: String, Codable, CaseIterable, Hashable, Sendable {
    case timeline
    case contactSheet

    var title: String {
        switch self {
        case .timeline:
            return "Timeline"
        case .contactSheet:
            return "Contact Sheet"
        }
    }
}

enum ArchiveBrowseSort: String, Codable, CaseIterable, Hashable, Sendable {
    case newest
    case title

    var title: String {
        switch self {
        case .newest:
            return "Newest first"
        case .title:
            return "Title"
        }
    }
}

enum ArchiveBrowseKindFilter: String, Codable, CaseIterable, Hashable, Sendable {
    case all
    case trips
    case unorganisedFolders

    var title: String {
        switch self {
        case .all:
            return "All entries"
        case .trips:
            return "Trips"
        case .unorganisedFolders:
            return "Unorganised folders"
        }
    }

    func includes(_ kind: ArchiveBrowseEntryKind) -> Bool {
        switch (self, kind) {
        case (.all, _), (.trips, .trip), (.unorganisedFolders, .unorganisedFolder):
            return true
        default:
            return false
        }
    }
}

struct ArchiveBrowseEntry: Identifiable, Hashable, Sendable {
    let id: String
    let kind: ArchiveBrowseEntryKind
    let year: String
    let archiveRelativePath: String
    let title: String
    let startDate: Date?
    let endDate: Date?
    let location: String?
    let photoCount: Int
    let walkCount: Int
    let coverThumbnailPath: String?

    var sortDate: Date {
        endDate ?? startDate ?? .distantPast
    }
}

struct ArchiveWalkSummary: Identifiable, Hashable, Sendable {
    let id: String
    let tripPath: String
    let archiveRelativePath: String
    let title: String
    let date: Date?
    let location: String?
    let photoCount: Int
    let coverThumbnailPath: String?
}

struct ArchivePhotoSummary: Identifiable, Hashable, Sendable {
    let id: String
    let archiveRelativePath: String
    let title: String
    let date: Date?
    let location: String?
    let camera: String?
    let aiDescription: String?
    let notes: String?
    let thumbnailPath: String?
    let walkPath: String?
    let tripPath: String?
}

struct ArchiveCatalogue: Equatable, Sendable {
    var entries: [ArchiveBrowseEntry]
    var walksByTripPath: [String: [ArchiveWalkSummary]]
    var photos: [ArchivePhotoSummary]

    static let empty = ArchiveCatalogue(entries: [], walksByTripPath: [:], photos: [])

    var years: [String] {
        Array(Set(entries.map(\.year))).sorted(by: >)
    }
}

enum ArchiveBrowseProjection {
    static func entries(
        from catalogue: ArchiveCatalogue,
        year: String?,
        kind: ArchiveBrowseKindFilter,
        searchQuery: String,
        matchingPaths: Set<String>,
        sort: ArchiveBrowseSort
    ) -> [ArchiveBrowseEntry] {
        var entries = catalogue.entries.filter {
            (year == nil || $0.year == year)
                && kind.includes($0.kind)
        }

        if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entries = entries.filter { entry in
                matchingPaths.contains(entry.archiveRelativePath)
                    || matchingPaths.contains { $0.hasPrefix(entry.archiveRelativePath + "/") }
            }
        }

        switch sort {
        case .newest:
            entries.sort {
                if $0.sortDate != $1.sortDate { return $0.sortDate > $1.sortDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .title:
            entries.sort {
                let comparison = $0.title.localizedStandardCompare($1.title)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return $0.sortDate > $1.sortDate
            }
        }
        return entries
    }

    static func reconciledSelection(currentID: String?, entries: [ArchiveBrowseEntry]) -> String? {
        if let currentID, entries.contains(where: { $0.id == currentID }) {
            return currentID
        }
        return entries.first?.id
    }
}

struct ArchiveCatalogueBuilder {
    let fileManager: FileManager
    let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
    }

    func build(archiveRoot: URL, supportedExtensions: Set<String>) throws -> ArchiveCatalogue {
        let indexedEntries = try readIndexEntries(archiveRoot: archiveRoot)
        let walkRows = indexedEntries.filter { $0.kind == .walk }
        let photoRows = indexedEntries.filter { $0.kind == .photo }
        let indexedWalkTripPaths = Set(walkRows.compactMap(\.tripPath))
        let tripRows = indexedEntries.filter { row in
            guard row.kind == .trip else { return false }
            return indexedWalkTripPaths.contains(row.archiveRelativePath)
                || hasTripManifest(relativePath: row.archiveRelativePath, archiveRoot: archiveRoot)
        }
        let recognisedRoots = Set(tripRows.map(\.archiveRelativePath))
            .union(walkRows.map(\.archiveRelativePath))

        let photos = photoRows.map {
            ArchivePhotoSummary(
                id: $0.archiveRelativePath,
                archiveRelativePath: $0.archiveRelativePath,
                title: $0.title,
                date: parseDate($0.date),
                location: $0.location?.nonEmpty,
                camera: $0.exifSummary?.nonEmpty,
                aiDescription: $0.aiDescription?.nonEmpty,
                notes: $0.notes?.nonEmpty,
                thumbnailPath: $0.thumbnailPath,
                walkPath: $0.walkPath,
                tripPath: $0.tripPath
            )
        }
        let photosByTripPath = Dictionary(grouping: photos.compactMap { photo -> ArchivePhotoSummary? in
            photo.tripPath == nil ? nil : photo
        }) { $0.tripPath ?? "" }
        let photosByWalkPath = Dictionary(grouping: photos.compactMap { photo -> ArchivePhotoSummary? in
            photo.walkPath == nil ? nil : photo
        }) { $0.walkPath ?? "" }

        let walksByTripPath = Dictionary(grouping: walkRows.compactMap { row -> ArchiveWalkSummary? in
            guard let tripPath = row.tripPath?.nonEmpty else { return nil }
            let memberPhotos = photosByWalkPath[row.archiveRelativePath] ?? []
            return ArchiveWalkSummary(
                id: row.archiveRelativePath,
                tripPath: tripPath,
                archiveRelativePath: row.archiveRelativePath,
                title: row.title,
                date: parseDate(row.date),
                location: row.location?.nonEmpty,
                photoCount: memberPhotos.count,
                coverThumbnailPath: row.thumbnailPath ?? memberPhotos.compactMap(\.thumbnailPath).first
            )
        }) { $0.tripPath }
            .mapValues { $0.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) } }

        var browseEntries = tripRows.map { row -> ArchiveBrowseEntry in
            let tripPhotos = photosByTripPath[row.archiveRelativePath]
                ?? photos.filter { $0.archiveRelativePath.hasPrefix(row.archiveRelativePath + "/") }
            let walks = walksByTripPath[row.archiveRelativePath] ?? []
            let dates = (tripPhotos.compactMap(\.date) + walks.compactMap(\.date)).sorted()
            return ArchiveBrowseEntry(
                id: "trip|\(row.archiveRelativePath)",
                kind: .trip,
                year: row.year,
                archiveRelativePath: row.archiveRelativePath,
                title: row.title,
                startDate: parseDate(row.date) ?? dates.first,
                endDate: dates.last ?? parseDate(row.date),
                location: row.location?.nonEmpty ?? mostFrequent(walks.compactMap(\.location)),
                photoCount: tripPhotos.count,
                walkCount: walks.count,
                coverThumbnailPath: row.thumbnailPath
                    ?? walks.compactMap(\.coverThumbnailPath).first
                    ?? tripPhotos.compactMap(\.thumbnailPath).first
            )
        }

        browseEntries.append(contentsOf: try unorganisedFolders(
            archiveRoot: archiveRoot,
            recognisedRoots: recognisedRoots,
            supportedExtensions: supportedExtensions
        ))
        browseEntries.sort(by: archiveEntryOrder)

        return ArchiveCatalogue(
            entries: browseEntries,
            walksByTripPath: walksByTripPath,
            photos: photos
        )
    }

    func readIndexEntries(archiveRoot: URL) throws -> [ArchiveIndexEntry] {
        let indexRoot = ArchiveIndexStore.indexRoot(for: archiveRoot)
        let shards = ((try? fileManager.contentsOfDirectory(
            at: indexRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { $0.lastPathComponent.range(of: #"^index-.+\.jsonl$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var entries: [ArchiveIndexEntry] = []
        for shard in shards {
            let text = try String(contentsOf: shard, encoding: .utf8)
            for line in text.split(separator: "\n") {
                entries.append(try decoder.decode(ArchiveIndexEntry.self, from: Data(line.utf8)))
            }
        }
        return entries
    }

    private func unorganisedFolders(
        archiveRoot: URL,
        recognisedRoots: Set<String>,
        supportedExtensions: Set<String>
    ) throws -> [ArchiveBrowseEntry] {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: archiveRoot,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        struct FolderAccumulator {
            var year: String
            var path: String
            var photoURLs: [URL]
            var dates: [Date]
        }

        var folders: [String: FolderAccumulator] = [:]
        let calendar = Calendar(identifier: .gregorian)

        for case let url as URL in enumerator {
            try Task.checkCancellation()
            let relativePath = ArchiveIndexStore.archiveRelativePath(for: url, archiveRoot: archiveRoot) ?? ""
            if relativePath == "_index" || relativePath.hasPrefix("_index/") {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            let values = try url.resourceValues(forKeys: resourceKeys)
            if values.isDirectory == true {
                if recognisedRoots.contains(relativePath) {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true,
                  supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }

            let components = relativePath.split(separator: "/").map(String.init)
            guard !isCovered(relativePath: relativePath, by: recognisedRoots) else { continue }

            let modificationDate = values.contentModificationDate
            let path: String
            let year: String
            if let first = components.first, isYear(first) {
                year = first
                path = components.count >= 2 ? [first, components[1]].joined(separator: "/") : first
            } else {
                year = modificationDate.map { String(calendar.component(.year, from: $0)) } ?? "Unknown"
                path = components.dropLast().joined(separator: "/").nonEmpty ?? "."
            }

            var accumulator = folders[path] ?? FolderAccumulator(year: year, path: path, photoURLs: [], dates: [])
            accumulator.photoURLs.append(url)
            if let modificationDate {
                accumulator.dates.append(modificationDate)
            }
            folders[path] = accumulator
        }

        return folders.values.map { folder in
            let sortedDates = folder.dates.sorted()
            let cover = folder.photoURLs.sorted { $0.path < $1.path }.compactMap { photoURL -> String? in
                let thumbnailURL = ArchiveIndexStore.thumbnailURL(for: photoURL, archiveRoot: archiveRoot)
                guard fileManager.fileExists(atPath: thumbnailURL.path) else { return nil }
                return ArchiveIndexStore.archiveRelativePath(for: thumbnailURL, archiveRoot: archiveRoot)
            }.first
            let title = folder.path == "."
                ? archiveRoot.lastPathComponent.nonEmpty ?? "Archive"
                : URL(fileURLWithPath: folder.path).lastPathComponent
            return ArchiveBrowseEntry(
                id: "folder|\(folder.path)",
                kind: .unorganisedFolder,
                year: folder.year,
                archiveRelativePath: folder.path,
                title: title,
                startDate: sortedDates.first,
                endDate: sortedDates.last,
                location: folder.path.replacingOccurrences(of: "/", with: " / "),
                photoCount: folder.photoURLs.count,
                walkCount: 0,
                coverThumbnailPath: cover
            )
        }
        .sorted(by: archiveEntryOrder)
    }

    private func archiveEntryOrder(_ lhs: ArchiveBrowseEntry, _ rhs: ArchiveBrowseEntry) -> Bool {
        if lhs.sortDate != rhs.sortDate { return lhs.sortDate > rhs.sortDate }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return DateFormatting.iso8601.date(from: value)
    }

    private func isYear(_ value: String) -> Bool {
        value.range(of: #"^(19|20)\d\d$"#, options: .regularExpression) != nil
    }

    private func hasTripManifest(relativePath: String, archiveRoot: URL) -> Bool {
        let folder = archiveRoot.appendingPathComponent(relativePath, isDirectory: true)
        let manifestURL = folder.appendingPathComponent("\(folder.lastPathComponent).md")
        guard let text = try? String(contentsOf: manifestURL, encoding: .utf8) else { return false }
        return text.contains("Trip ID:")
    }

    private func mostFrequent(_ values: [String]) -> String? {
        Dictionary(grouping: values.filter { !$0.isEmpty }, by: { $0 })
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }

    private func isCovered(relativePath: String, by recognisedRoots: Set<String>) -> Bool {
        let components = relativePath.split(separator: "/")
        guard !components.isEmpty else { return false }
        var prefix = ""
        for component in components.dropLast() {
            prefix = prefix.isEmpty ? String(component) : "\(prefix)/\(component)"
            if recognisedRoots.contains(prefix) {
                return true
            }
        }
        return recognisedRoots.contains(relativePath)
    }
}

struct ArchiveSearchCache {
    let databaseURL: URL

    func rebuild(indexEntries: [ArchiveIndexEntry], browseEntries: [ArchiveBrowseEntry]) throws {
        try AppDirectories.ensureExists(databaseURL.deletingLastPathComponent())
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            defer { sqlite3_close(db) }
            throw sqliteError(db, message: "Could not open the Archive search cache")
        }
        defer { sqlite3_close(db) }

        let schema = """
        DROP TABLE IF EXISTS archive_search;
        CREATE VIRTUAL TABLE archive_search USING fts5(
            row_kind UNINDEXED,
            archive_path UNINDEXED,
            title,
            filename,
            description,
            notes,
            location,
            camera,
            year,
            tokenize='unicode61 remove_diacritics 2'
        );
        """
        guard sqlite3_exec(db, schema, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(db, message: "Could not create the Archive search cache")
        }

        guard sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(db, message: "Could not start the Archive search update")
        }
        do {
            for entry in indexEntries {
                try insert(
                    db: db,
                    kind: entry.kind.rawValue,
                    path: entry.archiveRelativePath,
                    title: entry.kind == .photo ? "" : entry.title,
                    filename: entry.kind == .photo ? entry.title : "",
                    description: entry.aiDescription ?? "",
                    notes: entry.notes ?? "",
                    location: entry.location ?? "",
                    camera: entry.exifSummary ?? "",
                    year: entry.year
                )
            }
            for entry in browseEntries where entry.kind == .unorganisedFolder {
                try insert(
                    db: db,
                    kind: "unorganised_folder",
                    path: entry.archiveRelativePath,
                    title: entry.title,
                    filename: "",
                    description: "",
                    notes: "",
                    location: entry.location ?? "",
                    camera: "",
                    year: entry.year
                )
            }
            guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError(db, message: "Could not commit the Archive search update")
            }
        } catch {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }
    }

    func matchingPaths(query: String) throws -> Set<String> {
        let expression = ftsExpression(query)
        guard !expression.isEmpty else { return [] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(db) }
            throw sqliteError(db, message: "Could not open the Archive search cache")
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        let sql = "SELECT archive_path FROM archive_search WHERE archive_search MATCH ? ORDER BY rank LIMIT 5000;"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(db, message: "Could not prepare Archive search")
        }
        defer { sqlite3_finalize(statement) }
        try bind(expression, statement: statement, index: 1, db: db)

        var paths = Set<String>()
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = sqlite3_column_text(statement, 0) {
                paths.insert(String(cString: value))
            }
        }
        return paths
    }

    private func insert(
        db: OpaquePointer?,
        kind: String,
        path: String,
        title: String,
        filename: String,
        description: String,
        notes: String,
        location: String,
        camera: String,
        year: String
    ) throws {
        var statement: OpaquePointer?
        let sql = """
        INSERT INTO archive_search(
            row_kind, archive_path, title, filename, description, notes, location, camera, year
        ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(db, message: "Could not prepare an Archive search row")
        }
        defer { sqlite3_finalize(statement) }

        for (offset, value) in [kind, path, title, filename, description, notes, location, camera, year].enumerated() {
            try bind(value, statement: statement, index: Int32(offset + 1), db: db)
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(db, message: "Could not add an Archive search row")
        }
    }

    private func bind(_ value: String, statement: OpaquePointer?, index: Int32, db: OpaquePointer?) throws {
        let result = value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, archiveSearchTransientDestructor)
        }
        guard result == SQLITE_OK else {
            throw sqliteError(db, message: "Could not bind Archive search text")
        }
    }

    private func ftsExpression(_ query: String) -> String {
        query
            .split(whereSeparator: \.isWhitespace)
            .map {
                let escaped = String($0).replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\"*"
            }
            .joined(separator: " AND ")
    }

    private func sqliteError(_ db: OpaquePointer?, message: String) -> NSError {
        let detail = db.flatMap { sqlite3_errmsg($0) }.map(String.init(cString:)) ?? "unknown"
        return NSError(
            domain: "ArchiveSearchCache",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "\(message): \(detail)"]
        )
    }
}

private let archiveSearchTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
