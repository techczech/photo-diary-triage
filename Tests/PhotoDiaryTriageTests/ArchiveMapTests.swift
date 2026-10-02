import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func archiveCentroidHandlesAntimeridianAndRejectsAntipodalOrInvalidPairs() throws {
    let east = try #require(ArchiveCoordinate(latitude: 10, longitude: 179))
    let west = try #require(ArchiveCoordinate(latitude: 10, longitude: -179))
    let centre = try #require(ArchiveCoordinate.centroid([east, west]))
    #expect(abs(centre.longitude) > 179.9)
    #expect(abs(centre.latitude - 10) < 0.01)
    #expect(ArchiveCoordinate.centroid([ArchiveCoordinate(latitude: 0, longitude: 0)!, ArchiveCoordinate(latitude: 0, longitude: 180)!]) == nil)
    for (latitude, longitude) in [(Double.nan, 1), (1, Double.infinity), (91, 0), (0, 181)] {
        #expect(ArchiveCoordinate(latitude: latitude, longitude: longitude) == nil)
    }
    #expect(ArchiveCoordinate(latitude: 50, longitude: nil) == nil)
}

@MainActor
@Test func archiveMapReconstructsIndexOnlyPinsAndOpensTheIndexedWalk() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let main = root.appendingPathComponent("main")
    try writeTestFile(source.appendingPathComponent("east.jpg"), contents: "east original")
    try writeTestFile(source.appendingPathComponent("west.jpg"), contents: "west original")
    var east = makeTestMediaItem(sourceRoot: source, fileName: "east.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included)
    var west = makeTestMediaItem(sourceRoot: source, fileName: "west.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_060), selectionState: .included)
    east.metadata.latitude = 10; east.metadata.longitude = 179
    west.metadata.latitude = 10; west.metadata.longitude = -179
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: main, items: [east, west]))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: main)
    let travel = root.appendingPathComponent("travel")
    try AppDirectories.ensureExists(travel)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: main), to: ArchiveIndexStore.indexRoot(for: travel))
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: travel, supportedExtensions: ["jpg"], machineRole: .travel)
    let map = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: catalogue.entries, searchQuery: "", matchingPaths: [])
    let pin = try #require(map.locatedWalks.first)
    #expect(pin.coordinateSource == .gpsCentroid)
    #expect(abs(try #require(pin.coordinate).longitude) > 179.9)
    #expect(pin.photoCount == 2)
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = travel; settings.oneDrivePicturesRoot = travel; settings.archiveMachineRole = .travel
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    var unrelated = imported.session
    unrelated.walkMetadata.latitude = 51; unrelated.walkMetadata.longitude = -1
    state.currentSession = unrelated
    state.testingInstallArchiveCatalogue(catalogue)
    #expect(state.archiveBrowserState.snapshot.map == map)
    state.openArchiveMapWalk(pin)
    for _ in 0..<100 where state.visibleMediaItems.count != 2 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(state.archiveBrowserState.snapshot.level == .photos(path: pin.archiveRelativePath, parentTripPath: pin.tripPath))
    #expect(state.visibleMediaItems.count == 2)
    #expect(state.visibleMediaItems.allSatisfy { $0.sourceURL.path.hasPrefix(travel.path) && !FileManager.default.fileExists(atPath: $0.sourceURL.path) })
    #expect(Set(state.visibleMediaItems.map(\.id)) == Set(imported.session.mediaItems.map(\.id)))
    state.setArchiveYearFilter("1999")
    #expect(state.archiveBrowserState.snapshot.map.walks.isEmpty)
}

@Test func archiveMapPinPrecedenceFiltersAndUnlocatedCoverageAreExplicit() throws {
    let trip = ArchiveBrowseEntry(id: "trip", kind: .trip, year: "2023", archiveRelativePath: "2023/Trip", title: "Trip",
        startDate: nil, endDate: nil, location: nil, photoCount: 2, walkCount: 2, coverThumbnailPath: nil)
    let located = ArchiveWalkSummary(id: "located", tripPath: trip.archiveRelativePath, archiveRelativePath: "2023/Trip/Located",
        title: "Located", date: nil, location: "Pin place", photoCount: 1, coverThumbnailPath: nil,
        latitude: 52, longitude: -1, coordinateSource: .walkPin)
    let missing = ArchiveWalkSummary(id: "missing", tripPath: trip.archiveRelativePath, archiveRelativePath: "2023/Trip/Missing",
        title: "Missing", date: nil, location: nil, photoCount: 1, coverThumbnailPath: nil)
    let photo = ArchivePhotoSummary(id: "photo", archiveRelativePath: "2023/Trip/Located/photo.jpg", title: "Photo",
        date: nil, location: nil, camera: nil, aiDescription: nil, notes: nil, thumbnailPath: nil,
        walkPath: located.archiveRelativePath, tripPath: trip.archiveRelativePath,
        latitude: 10, longitude: 20, coordinateSource: .photoGPS)
    let catalogue = ArchiveCatalogue(entries: [trip], walksByTripPath: [trip.archiveRelativePath: [located, missing]], photos: [photo])
    let snapshot = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: [trip], searchQuery: "", matchingPaths: [])
    #expect(snapshot.locatedWalks.first?.coordinate == ArchiveCoordinate(latitude: 52, longitude: -1))
    #expect(snapshot.locatedWalks.first?.coordinateSource == .walkPin)
    #expect(snapshot.unlocatedWalks.count == 1)
    let filtered = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: [trip], searchQuery: "Photo", matchingPaths: [photo.archiveRelativePath])
    #expect(filtered.walks.map(\.archiveRelativePath) == [located.archiveRelativePath])
    #expect(ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: [], searchQuery: "", matchingPaths: []).walks.isEmpty)
}

@Test func oldIndexCoordinatesRetainUnknownProvenanceRatherThanClaimingGPS() throws {
    let data = Data(#"{"kind":"photo","year":"2020","archive_relative_path":"2020/Trip/Walk/photo.jpg","title":"Photo","latitude":50,"longitude":14}"#.utf8)
    let row = try JSONDecoder().decode(ArchiveIndexEntry.self, from: data)
    #expect(row.coordinateSource == nil)
    #expect(ArchiveCoordinate(latitude: row.latitude, longitude: row.longitude) != nil)
}

@Test func partialPhotoCoordinatesDoNotSpliceWithWalkPin() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let archive = root.appendingPathComponent("archive")
    try writeTestFile(source.appendingPathComponent("photo.jpg"), contents: "partial GPS")
    var item = makeTestMediaItem(sourceRoot: source, fileName: "photo.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included)
    item.metadata.latitude = 50; item.metadata.longitude = nil
    var session = makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item])
    session.walkMetadata.latitude = 10; session.walkMetadata.longitude = 20
    _ = try await ImportCoordinator().commit(session: session)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let photo = try #require(ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).first { $0.kind == .photo })
    #expect(photo.latitude == 10)
    #expect(photo.longitude == 20)
    #expect(photo.coordinateSource == .walkPin)
}

@Test func derivedCropCoordinatesDoNotBiasWalkCentroid() throws {
    let trip = ArchiveBrowseEntry(id: "trip", kind: .trip, year: "2023", archiveRelativePath: "2023/Trip", title: "Trip",
        startDate: nil, endDate: nil, location: nil, photoCount: 3, walkCount: 1, coverThumbnailPath: nil)
    let walk = ArchiveWalkSummary(id: "walk", tripPath: trip.archiveRelativePath, archiveRelativePath: "2023/Trip/Walk",
        title: "Walk", date: nil, location: nil, photoCount: 3, coverThumbnailPath: nil)
    func photo(_ path: String, longitude: Double, derived: Bool = false) -> ArchivePhotoSummary {
        ArchivePhotoSummary(id: path, archiveRelativePath: walk.archiveRelativePath + "/" + path, title: path,
            date: nil, location: nil, camera: nil, aiDescription: nil, notes: nil, thumbnailPath: nil,
            walkPath: walk.archiveRelativePath, tripPath: trip.archiveRelativePath,
            latitude: 0, longitude: longitude, coordinateSource: .photoGPS, cropRole: .original, isDerivedPhoto: derived)
    }
    let catalogue = ArchiveCatalogue(entries: [trip], walksByTripPath: [trip.archiveRelativePath: [walk]],
        photos: [photo("east.jpg", longitude: 10), photo("west.jpg", longitude: -10), photo("east-crop.jpg", longitude: 10, derived: true)])
    let snapshot = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: [trip], searchQuery: "", matchingPaths: [])
    #expect(abs(try #require(snapshot.locatedWalks.first?.coordinate).longitude) < 0.0001)
}
