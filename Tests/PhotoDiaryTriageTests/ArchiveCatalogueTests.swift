import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func archiveCatalogueMergesIndexedTripsWithIrregularUnorganisedFolders() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)

    let tripPhotoPath = "2025/07-July/03-Thu-River/2025-07-03-river-001.jpg"
    let tripPhotoURL = archiveRoot.appendingPathComponent(tripPhotoPath)
    try writeTestFile(tripPhotoURL, contents: "indexed")
    let oldNestedPhoto = archiveRoot.appendingPathComponent("2013/Czech Republic Visit/Prague/IMG_0001.jpg")
    let oldSecondPhoto = archiveRoot.appendingPathComponent("2013/Czech Republic Visit/Liberec/IMG_0002.jpg")
    let monthShapedButUnrecognised = archiveRoot.appendingPathComponent("2016/05-May/IMG_0003.jpg")
    try writeTestFile(oldNestedPhoto, contents: "old-1")
    try writeTestFile(oldSecondPhoto, contents: "old-2")
    try writeTestFile(monthShapedButUnrecognised, contents: "old-3")

    try writeArchiveIndexShard(entries: [
        ArchiveIndexEntry(
            kind: .trip,
            year: "2025",
            archiveRelativePath: "2025/07-July",
            date: "2025-07-03T10:00:00Z",
            title: "River Walk",
            location: "Oxford",
            exifSummary: nil,
            aiDescription: "",
            thumbnailPath: nil,
            walkPath: nil,
            tripPath: "2025/07-July"
        ),
        ArchiveIndexEntry(
            kind: .walk,
            year: "2025",
            archiveRelativePath: "2025/07-July/03-Thu-River",
            date: "2025-07-03T10:00:00Z",
            title: "River",
            location: "Oxford",
            exifSummary: nil,
            aiDescription: "",
            notes: "Herons by the river",
            thumbnailPath: nil,
            walkPath: "2025/07-July/03-Thu-River",
            tripPath: "2025/07-July"
        ),
        ArchiveIndexEntry(
            kind: .photo,
            year: "2025",
            archiveRelativePath: tripPhotoPath,
            date: "2025-07-03T10:05:00Z",
            title: "IMG_1001.jpg",
            location: "Oxford",
            exifSummary: "Canon R5",
            aiDescription: "A heron over the water",
            notes: "Favourite frame",
            thumbnailPath: nil,
            walkPath: "2025/07-July/03-Thu-River",
            tripPath: "2025/07-July"
        ),
    ], archiveRoot: archiveRoot, year: "2025")

    let catalogue = try ArchiveCatalogueBuilder().build(
        archiveRoot: archiveRoot,
        supportedExtensions: ["jpg"]
    )

    #expect(catalogue.entries.count == 3)
    let trip = try #require(catalogue.entries.first { $0.kind == .trip })
    #expect(trip.title == "River Walk")
    #expect(trip.photoCount == 1)
    #expect(trip.walkCount == 1)

    let folders = catalogue.entries.filter { $0.kind == .unorganisedFolder }
    #expect(Set(folders.map(\.archiveRelativePath)) == [
        "2013/Czech Republic Visit",
        "2016/05-May",
    ])
    #expect(folders.first { $0.archiveRelativePath == "2013/Czech Republic Visit" }?.photoCount == 2)
    #expect(folders.first { $0.archiveRelativePath == "2016/05-May" }?.title == "05-May")
}

@Test func archiveCatalogueDoesNotUse2016OrFolderDepthAsTripRules() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)

    try writeTestFile(archiveRoot.appendingPathComponent("2015/12-December/25-Fri-Walk/photo.jpg"))
    try writeTestFile(archiveRoot.appendingPathComponent("2017/01-January/01-Sun-Walk/photo.jpg"))

    let catalogue = try ArchiveCatalogueBuilder().build(
        archiveRoot: archiveRoot,
        supportedExtensions: ["jpg"]
    )

    #expect(catalogue.entries.allSatisfy { $0.kind == .unorganisedFolder })
    #expect(Set(catalogue.entries.map(\.archiveRelativePath)) == [
        "2015/12-December",
        "2017/01-January",
    ])
}

@Test func archiveCatalogueRejectsLegacyIndexTripRowsWithoutManifestOrWalkEvidence() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let historicalPath = "2013/Czech Republic Visit"
    try writeTestFile(archiveRoot.appendingPathComponent("\(historicalPath)/IMG_0001.jpg"))
    try writeArchiveIndexShard(entries: [
        ArchiveIndexEntry(
            kind: .trip,
            year: "2013",
            archiveRelativePath: historicalPath,
            date: nil,
            title: "Czech Republic Visit",
            location: nil,
            exifSummary: nil,
            aiDescription: "",
            thumbnailPath: nil,
            walkPath: nil,
            tripPath: historicalPath
        ),
    ], archiveRoot: archiveRoot, year: "2013")

    let catalogue = try ArchiveCatalogueBuilder().build(
        archiveRoot: archiveRoot,
        supportedExtensions: ["jpg"]
    )

    #expect(catalogue.entries.count == 1)
    #expect(catalogue.entries.first?.kind == .unorganisedFolder)
    #expect(catalogue.entries.first?.archiveRelativePath == historicalPath)
}

@Test func archiveSearchCacheIndexesFilenamesDescriptionsNotesLocationsAndCamera() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let databaseURL = root.appendingPathComponent("archive-search.sqlite")
    let cache = ArchiveSearchCache(databaseURL: databaseURL)
    let photoPath = "2025/07-July/03-Thu-River/IMG_1001.jpg"
    let entry = ArchiveIndexEntry(
        kind: .photo,
        year: "2025",
        archiveRelativePath: photoPath,
        date: "2025-07-03T10:05:00Z",
        title: "IMG_1001.jpg",
        location: "Port Meadow",
        exifSummary: "Canon R5 100-500mm",
        aiDescription: "A heron flying above water",
        notes: "Favourite wingspan",
        thumbnailPath: nil,
        walkPath: "2025/07-July/03-Thu-River",
        tripPath: "2025/07-July"
    )

    try cache.rebuild(indexEntries: [entry], browseEntries: [])

    #expect(try cache.matchingPaths(query: "IMG_1001") == [photoPath])
    #expect(try cache.matchingPaths(query: "heron water") == [photoPath])
    #expect(try cache.matchingPaths(query: "wingspan") == [photoPath])
    #expect(try cache.matchingPaths(query: "Port Meadow") == [photoPath])
    #expect(try cache.matchingPaths(query: "Canon") == [photoPath])
}

@Test func archiveBrowsePreferencesRoundTripAndDefaultSafely() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let fileURL = root.appendingPathComponent("settings.json")
    let store = SettingsStore(fileURL: fileURL)
    var settings = makeTestSettings(root: root)
    settings.archiveBrowseViewMode = .contactSheet
    settings.showArchivePreviews = false

    try store.save(settings)
    let loaded = store.load(defaults: AppSettings.default())

    #expect(loaded.archiveBrowseViewMode == .contactSheet)
    #expect(loaded.showArchivePreviews == false)
}

@Test func archiveProjectionKeepsYearsAsFiltersAndPreservesVisibleSelection() {
    let newest = makeBrowseEntry(id: "new", kind: .trip, year: "2025", title: "New", timestamp: 300)
    let folder = makeBrowseEntry(id: "folder", kind: .unorganisedFolder, year: "2013", title: "Folder", timestamp: 100)
    let older = makeBrowseEntry(id: "old", kind: .trip, year: "2024", title: "Old", timestamp: 200)
    let catalogue = ArchiveCatalogue(entries: [folder, older, newest], walksByTripPath: [:], photos: [])

    let all = ArchiveBrowseProjection.entries(
        from: catalogue,
        year: nil,
        kind: .all,
        searchQuery: "",
        matchingPaths: [],
        sort: .newest
    )
    let year = ArchiveBrowseProjection.entries(
        from: catalogue,
        year: "2024",
        kind: .all,
        searchQuery: "",
        matchingPaths: [],
        sort: .newest
    )
    let folders = ArchiveBrowseProjection.entries(
        from: catalogue,
        year: nil,
        kind: .unorganisedFolders,
        searchQuery: "",
        matchingPaths: [],
        sort: .newest
    )

    #expect(all.map(\.id) == ["new", "old", "folder"])
    #expect(year.map(\.id) == ["old"])
    #expect(folders.map(\.id) == ["folder"])
    #expect(ArchiveBrowseProjection.reconciledSelection(currentID: "old", entries: all) == "old")
    #expect(ArchiveBrowseProjection.reconciledSelection(currentID: "new", entries: year) == "old")
}

@Test func archiveProjectionMapsPhotoSearchMatchesBackToTheirArchiveEntry() {
    let trip = makeBrowseEntry(id: "trip", kind: .trip, year: "2025", title: "River", timestamp: 300)
    let folder = makeBrowseEntry(id: "folder", kind: .unorganisedFolder, year: "2013", title: "Prague", timestamp: 100)
    let catalogue = ArchiveCatalogue(entries: [trip, folder], walksByTripPath: [:], photos: [])

    let matches = ArchiveBrowseProjection.entries(
        from: catalogue,
        year: nil,
        kind: .all,
        searchQuery: "heron",
        matchingPaths: ["2025/trip/walk/photo.jpg"],
        sort: .newest
    )

    #expect(matches.map(\.id) == ["trip"])
}

private func writeArchiveIndexShard(
    entries: [ArchiveIndexEntry],
    archiveRoot: URL,
    year: String
) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let text = try entries.map {
        String(decoding: try encoder.encode($0), as: UTF8.self)
    }.joined(separator: "\n")
    let url = ArchiveIndexStore.indexRoot(for: archiveRoot)
        .appendingPathComponent("index-\(year).jsonl")
    try AppDirectories.ensureExists(url.deletingLastPathComponent())
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private func makeBrowseEntry(
    id: String,
    kind: ArchiveBrowseEntryKind,
    year: String,
    title: String,
    timestamp: TimeInterval
) -> ArchiveBrowseEntry {
    ArchiveBrowseEntry(
        id: id,
        kind: kind,
        year: year,
        archiveRelativePath: kind == .trip ? "\(year)/trip" : "\(year)/folder",
        title: title,
        startDate: Date(timeIntervalSince1970: timestamp),
        endDate: Date(timeIntervalSince1970: timestamp),
        location: nil,
        photoCount: 1,
        walkCount: kind == .trip ? 1 : 0,
        coverThumbnailPath: nil
    )
}
