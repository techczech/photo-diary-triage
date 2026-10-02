import Foundation

/// The view and keyboard use these same explicit columns, including narrow panes.
struct ArchiveGridLayout: Equatable, Sendable {
    let columnCount: Int
    let maximumCardWidth: Double
    let spacing: Double

    init(availableWidth: Double, walkCards: Bool = false) {
        let minimum = walkCards ? 230.0 : 190.0
        spacing = walkCards ? 16 : 14
        maximumCardWidth = walkCards ? 340 : 280
        let width = availableWidth.isFinite ? max(availableWidth - 36, 0) : 0
        columnCount = max(1, Int(floor((width + spacing) / (minimum + spacing))))
    }
}

struct ArchiveBrowseYearGroup: Equatable, Sendable {
    let year: String
    let entries: [ArchiveBrowseEntry]
}

/// Rows restart at every year header. Preserve the intended column through short rows.
struct ArchiveGridNavigator {
    private var preferredColumn: Int?
    private var previousColumns: [Int]?

    mutating func reset() { preferredColumn = nil; previousColumns = nil }

    mutating func target(sections: [[String]], selectedID: String?, horizontal: Int,
                         vertical: Int, columns: Int) -> String? {
        let columns = max(columns, 1)
        let rows = sections.flatMap { section in
            stride(from: 0, to: section.count, by: columns).map {
                Array(section[$0..<min($0 + columns, section.count)])
            }
        }
        return targetRows(rows: rows, selectedID: selectedID, horizontal: horizontal, vertical: vertical, layoutKey: [columns])
    }

    mutating func targetRows<ID: Hashable>(rows: [[ID]], selectedID: ID?, horizontal: Int,
                                           vertical: Int, layoutKey: [Int]) -> ID? {
        if previousColumns != layoutKey { preferredColumn = nil }
        previousColumns = layoutKey
        let all = rows.flatMap { $0 }
        guard !all.isEmpty else { return nil }
        let current = selectedID.flatMap { all.contains($0) ? $0 : nil } ?? all[0]
        if horizontal != 0 {
            preferredColumn = nil
            let index = all.firstIndex(of: current) ?? 0
            return all[min(max(index + horizontal, 0), all.count - 1)]
        }
        guard vertical != 0, let row = rows.firstIndex(where: { $0.contains(current) }),
              let column = rows[row].firstIndex(of: current) else { return current }
        let nextRow = min(max(row + vertical, 0), rows.count - 1)
        guard nextRow != row else { return current }
        let desiredColumn = preferredColumn ?? column
        preferredColumn = desiredColumn
        return rows[nextRow][min(desiredColumn, rows[nextRow].count - 1)]
    }
}

enum ArchiveMapItemID: Hashable, Sendable {
    case walk(String)
    case folder(String)
    case photo(String)
}

struct ArchiveBrowseContent {
    let entries: [ArchiveBrowseEntry]
    let yearGroups: [ArchiveBrowseYearGroup]
    let allEntriesByID: [String: ArchiveBrowseEntry]
    let tripsByPath: [String: ArchiveBrowseEntry]
    let yearFilters: [ArchiveYearFilterSnapshot]
    let tripCount: Int
    let unorganisedFolderCount: Int
    let searchResults: [ArchivePhotoSummary]
    let map: ArchiveMapSnapshot
    let mapNavigationIDs: [ArchiveMapItemID]

    init(catalogue: ArchiveCatalogue, year: String?, kind: ArchiveBrowseKindFilter,
         searchQuery: String, matchingPaths: Set<String>, sort: ArchiveBrowseSort) {
        let filtered = ArchiveBrowseProjection.entries(from: catalogue, year: year, kind: kind,
            searchQuery: searchQuery, matchingPaths: matchingPaths, sort: sort)
        let groups = Dictionary(grouping: filtered, by: \.year)
        yearGroups = groups.keys.sorted(by: >).map { ArchiveBrowseYearGroup(year: $0, entries: groups[$0] ?? []) }
        let visibleEntries = yearGroups.flatMap(\.entries)
        entries = visibleEntries
        let visibleEntryIDs = Set(visibleEntries.map(\.id))
        let entriesByPath = Dictionary(catalogue.entries.map { ($0.archiveRelativePath, $0) }, uniquingKeysWith: { first, _ in first })
        allEntriesByID = Dictionary(catalogue.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        tripsByPath = Dictionary(catalogue.entries.filter { $0.kind == .trip }.map { ($0.archiveRelativePath, $0) }, uniquingKeysWith: { first, _ in first })
        let years = Dictionary(grouping: catalogue.entries, by: \.year)
        yearFilters = years.keys.sorted(by: >).map { ArchiveYearFilterSnapshot(year: $0, count: years[$0]?.count ?? 0) }
        tripCount = tripsByPath.count
        unorganisedFolderCount = catalogue.entries.count - tripCount
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchResults = []
        } else {
            searchResults = catalogue.photos.filter { photo in
                matchingPaths.contains(photo.archiveRelativePath)
                    && ArchiveEntryContainment.entryID(for: photo.archiveRelativePath, entriesByPath: entriesByPath)
                        .map { visibleEntryIDs.contains($0) } == true
            }.sorted {
                if $0.date != $1.date { return ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                return $0.archiveRelativePath < $1.archiveRelativePath
            }
        }
        let projectedMap = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: visibleEntries,
            searchQuery: searchQuery, matchingPaths: matchingPaths)
        map = projectedMap
        mapNavigationIDs = searchResults.map { .photo($0.id) } + projectedMap.locatedWalks.map { .walk($0.archiveRelativePath) }
            + projectedMap.unlocatedWalks.map { .walk($0.archiveRelativePath) }
            + projectedMap.unlocatedHistoricalFolders.map { .folder($0.id) }
    }

}
