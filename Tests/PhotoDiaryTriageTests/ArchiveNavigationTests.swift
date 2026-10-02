import Foundation
import Testing
@testable import PhotoDiaryTriage

private func navigationEntry(_ id: String, year: String = "2025", title: String? = nil, kind: ArchiveBrowseEntryKind = .trip) -> ArchiveBrowseEntry {
    ArchiveBrowseEntry(id: id, kind: kind, year: year, archiveRelativePath: "\(year)/\(id)", title: title ?? id,
        startDate: nil, endDate: nil, location: nil, photoCount: 0, walkCount: 0, coverThumbnailPath: nil)
}

@MainActor private func navigationState(root: URL, entries: [ArchiveBrowseEntry], walks: [String: [ArchiveWalkSummary]] = [:], photos: [ArchivePhotoSummary] = []) -> AppState {
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = root.appendingPathComponent("archive")
    settings.archiveMachineRole = .travel
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    state.testingInstallArchiveCatalogue(ArchiveCatalogue(entries: entries, walksByTripPath: walks, photos: photos))
    return state
}

@Test @MainActor func archiveTimelineKeyboardFollowsVisibleYearGroupsUnderTitleSort() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let entries = [navigationEntry("old-a", year: "2019", title: "A"), navigationEntry("new-b", title: "B"),
        navigationEntry("old-c", year: "2019", title: "C"), navigationEntry("new-z", title: "Z")]
    let state = navigationState(root: root, entries: entries)
    state.setArchiveSort(.title)
    state.selectArchiveEntry("new-b")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-z")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-a")
}

@Test @MainActor func archiveContactSheetVerticalNavigationRespectsShortYearRows() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let entries = (0..<6).map { navigationEntry("new-\($0)") } + (0..<5).map { navigationEntry("old-\($0)", year: "2019") }
    let state = navigationState(root: root, entries: entries)
    state.setArchiveBrowseViewMode(.contactSheet)
    state.selectArchiveEntry("new-5")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-1")
    state.moveArchiveSelection(horizontal: 0, vertical: -1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-5")
}

@Test @MainActor func archiveBackRetainsTheWalkJustOpened() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let trip = navigationEntry("trip")
    let walks = (0..<3).map { ArchiveWalkSummary(id: "walk-\($0)", tripPath: trip.archiveRelativePath,
        archiveRelativePath: "\(trip.archiveRelativePath)/walk-\($0)", title: "Walk \($0)", date: nil, location: nil, photoCount: 0, coverThumbnailPath: nil) }
    let state = navigationState(root: root, entries: [trip], walks: [trip.archiveRelativePath: walks])
    state.openCurrentSelection()
    state.selectArchiveWalk("walk-2")
    state.openCurrentSelection()
    state.navigateToParent()
    #expect(state.archiveBrowserState.snapshot.level == .trip(path: trip.archiveRelativePath))
    #expect(state.archiveBrowserState.snapshot.selectedWalkID == "walk-2")
}

@Test @MainActor func archiveCardSurfaceCanBeFocusedWithoutLoadedPhotos() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let state = navigationState(root: root, entries: [navigationEntry("trip")])
    #expect(state.visibleMediaItems.isEmpty)
    #expect(state.canFocusReviewSurface)
    state.focusReviewSurface()
    #expect(state.activePane == .media)
}


@Test func archiveGridWidthsMatchCardAndWalkColumnThresholds() {
    #expect(ArchiveGridLayout(availableWidth: 225).columnCount == 1)
    #expect(ArchiveGridLayout(availableWidth: 429).columnCount == 1)
    #expect(ArchiveGridLayout(availableWidth: 430).columnCount == 2)
    #expect(ArchiveGridLayout(availableWidth: 838).columnCount == 4)
    #expect(ArchiveGridLayout(availableWidth: 511, walkCards: true).columnCount == 1)
    #expect(ArchiveGridLayout(availableWidth: 512, walkCards: true).columnCount == 2)
    #expect(ArchiveGridLayout(availableWidth: 1004, walkCards: true).columnCount == 4)
    #expect(ArchiveGridLayout(availableWidth: -1).columnCount == 1)
    #expect(ArchiveGridLayout(availableWidth: .nan).columnCount == 1)
    #expect(ArchiveGridLayout(availableWidth: .infinity).columnCount == 1)
}

@Test @MainActor func archiveGridPreservesIntendedColumnThroughShortRowsAndResetsAfterMouseSelection() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let state = navigationState(root: root, entries: (0..<6).map { navigationEntry("new-\($0)") }
        + (0..<5).map { navigationEntry("old-\($0)", year: "2019") })
    state.setArchiveBrowseViewMode(.contactSheet)
    state.selectArchiveEntry("new-3")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-5")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-3")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-4")
    state.moveArchiveSelection(horizontal: 0, vertical: -1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-3")
    state.selectArchiveEntry("new-4")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-0")
}

@Test @MainActor func archiveGridResizeRecomputesRowsAndHorizontalMovementUsesVisibleOrder() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let state = navigationState(root: root, entries: (0..<6).map { navigationEntry("new-\($0)") }
        + (0..<3).map { navigationEntry("old-\($0)", year: "2019") })
    state.setArchiveBrowseViewMode(.contactSheet)
    state.selectArchiveEntry("new-3")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: ArchiveGridLayout(availableWidth: 838).columnCount)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-5")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: ArchiveGridLayout(availableWidth: 430).columnCount)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "old-1")
    state.moveArchiveSelection(horizontal: -1, vertical: 0, contactSheetColumns: 2)
    state.moveArchiveSelection(horizontal: -1, vertical: 0, contactSheetColumns: 2)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-5")
    state.moveArchiveSelection(horizontal: 0, vertical: -1, contactSheetColumns: 1)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-4")
}

@Test func archiveGridEmptyAndBoundaryNavigationKeepSelectionStable() {
    var navigator = ArchiveGridNavigator()
    #expect(navigator.target(sections: [], selectedID: nil, horizontal: 0, vertical: 1, columns: 2) == nil)
    let sections = [["a", "b", "c"], ["d", "e"]]
    #expect(navigator.target(sections: sections, selectedID: "b", horizontal: 0, vertical: -1, columns: 2) == "b")
    #expect(navigator.target(sections: sections, selectedID: "e", horizontal: 0, vertical: 1, columns: 2) == "e")
    #expect(navigator.target(sections: sections, selectedID: "e", horizontal: 1, vertical: 0, columns: 2) == "e")
    #expect(navigator.target(sections: sections, selectedID: "a", horizontal: -1, vertical: 0, columns: 0) == "a")
}

@Test @MainActor func archiveEnteringTripClearsThePreviousGridsPreferredColumn() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let entries = (0..<8).map { navigationEntry("trip-\($0)") }
    let trip = entries[5]
    let walks = (0..<7).map { ArchiveWalkSummary(id: "walk-\($0)", tripPath: trip.archiveRelativePath,
        archiveRelativePath: "\(trip.archiveRelativePath)/walk-\($0)", title: "Walk \($0)", date: nil, location: nil, photoCount: 0, coverThumbnailPath: nil) }
    let state = navigationState(root: root, entries: entries, walks: [trip.archiveRelativePath: walks])
    state.setArchiveBrowseViewMode(.contactSheet)
    state.selectArchiveEntry("trip-2")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 3)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == trip.id)
    state.openCurrentSelection()
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 3)
    #expect(state.archiveBrowserState.snapshot.selectedWalkID == "walk-3")
}

@Test @MainActor func archiveChangingViewModeClearsRememberedGridColumn() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let state = navigationState(root: root, entries: (0..<8).map { navigationEntry("new-\($0)") })
    state.setArchiveBrowseViewMode(.contactSheet)
    state.selectArchiveEntry("new-3")
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    state.setArchiveBrowseViewMode(.timeline)
    state.moveArchiveSelection(horizontal: 0, vertical: -1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-6")
    state.setArchiveBrowseViewMode(.contactSheet)
    state.moveArchiveSelection(horizontal: 0, vertical: -1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == "new-2")
}

@Test @MainActor func archiveMapKeyboardSelectionTargetsVisibleWalksAndHistoricalFolders() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    var tripA = navigationEntry("trip-a"); tripA.tripID = UUID()
    var tripB = navigationEntry("trip-b"); tripB.tripID = UUID()
    let folder = navigationEntry("folder", year: "2013", kind: .unorganisedFolder)
    let located = ArchiveWalkSummary(id: "located", tripPath: tripB.archiveRelativePath,
        archiveRelativePath: "\(tripB.archiveRelativePath)/located", title: "Located", date: nil, location: nil,
        photoCount: 1, coverThumbnailPath: nil, latitude: 51, longitude: -1, coordinateSource: .walkPin)
    let missing = ArchiveWalkSummary(id: "missing", tripPath: tripA.archiveRelativePath,
        archiveRelativePath: "\(tripA.archiveRelativePath)/missing", title: "Missing", date: nil, location: nil, photoCount: 0, coverThumbnailPath: nil)
    let state = navigationState(root: root, entries: [tripA, tripB, folder],
        walks: [tripA.archiveRelativePath: [missing], tripB.archiveRelativePath: [located]])
    state.selectArchiveEntry(tripA.id)
    state.setArchiveBrowseViewMode(.map)
    #expect(state.archiveBrowserState.snapshot.selectedMapItemID == .walk(located.archiveRelativePath))
    #expect(state.contextualDescriptionTargets.map { $0.0 } == [.walk])
    #expect(state.contextualDescriptionTargets.map { $0.1 } == [located.archiveRelativePath])
    #expect(state.descriptionTripPath == tripB.archiveRelativePath)
    #expect(!state.canOrganiseSelectedUnorganisedFolder)
    state.openCurrentSelection()
    #expect(state.archiveBrowserState.snapshot.level == .photos(path: located.archiveRelativePath, parentTripPath: tripB.archiveRelativePath))
    state.navigateToParent()
    #expect(state.archiveBrowserState.snapshot.selectedWalkID == located.id)
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == tripB.id)
    state.navigateToParent()
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedMapItemID == .walk(missing.archiveRelativePath))
    #expect(state.descriptionTripPath == tripA.archiveRelativePath)
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 4)
    #expect(state.archiveBrowserState.snapshot.selectedMapItemID == .folder(folder.id))
    #expect(state.canOrganiseSelectedUnorganisedFolder)
    #expect(state.canMarkGoogleMaterial)
    #expect(state.contextualDescriptionTargets.isEmpty)
    #expect(state.descriptionTripPath == nil)
    state.openCurrentSelection()
    #expect(state.archiveBrowserState.snapshot.level == .photos(path: folder.archiveRelativePath, parentTripPath: nil))
    state.navigateToParent()
    #expect(state.archiveBrowserState.snapshot.selectedEntryID == folder.id)
    #expect(state.archiveBrowserState.snapshot.selectedMapItemID == .folder(folder.id))
    state.setArchiveKindFilter(.trips)
    #expect(state.archiveBrowserState.snapshot.selectedMapItemID == .walk(located.archiveRelativePath))
    #expect(!state.canOrganiseSelectedUnorganisedFolder)
    state.setArchiveYearFilter("1999")
    #expect(state.archiveBrowserState.snapshot.selectedMapItemID == nil)
    #expect(!state.canOpenCurrentSelection)
}

@Test @MainActor func archiveMapHistoricalOrganiseUsesHighlightedFolderInsteadOfOldEntry() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = navigationEntry("a", year: "2013", kind: .unorganisedFolder)
    let second = navigationEntry("b", year: "2013", kind: .unorganisedFolder)
    let state = navigationState(root: root, entries: [first, second])
    try AppDirectories.ensureExists(state.settings.archiveRoot.appendingPathComponent(second.archiveRelativePath))
    state.setArchiveBrowseViewMode(.map)
    state.selectArchiveEntry(first.id)
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 2)
    state.organiseSelectedUnorganisedFolder()
    for _ in 0..<100 where state.currentSession == nil { try await Task.sleep(for: .milliseconds(10)) }
    #expect(state.currentSession?.sourceFolder == state.settings.archiveRoot.appendingPathComponent(second.archiveRelativePath))
}

@Test @MainActor func archiveSelectionReusesPhotoDerivedProjectionForLargeCatalogues() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let entries = (0..<100).map { navigationEntry(String(format: "trip-%03d", $0)) }
    var walks: [String: [ArchiveWalkSummary]] = [:]
    var photos: [ArchivePhotoSummary] = []
    for entry in entries {
        let walkPath = entry.archiveRelativePath + "/Walk"
        walks[entry.archiveRelativePath] = [ArchiveWalkSummary(id: walkPath, tripPath: entry.archiveRelativePath,
            archiveRelativePath: walkPath, title: "Walk", date: nil, location: nil, photoCount: 500, coverThumbnailPath: nil)]
        for n in 0..<500 {
            let path = walkPath + "/\(n).jpg"
            photos.append(ArchivePhotoSummary(id: path, archiveRelativePath: path, title: "\(n).jpg", date: nil,
                location: nil, camera: nil, aiDescription: nil, notes: nil, thumbnailPath: nil, walkPath: walkPath,
                tripPath: entry.archiveRelativePath, latitude: 51, longitude: -1, coordinateSource: .photoGPS))
        }
    }
    let state = navigationState(root: root, entries: entries, walks: walks, photos: photos)
    state.setArchiveBrowseViewMode(.contactSheet)
    let builds = state.archiveProjectionBuildCount
    let map = state.archiveBrowserState.snapshot.map
    for _ in 0..<500 {
        state.moveArchiveSelection(horizontal: 1, vertical: 0, contactSheetColumns: 4)
        state.moveArchiveSelection(horizontal: -1, vertical: 0, contactSheetColumns: 4)
    }
    #expect(state.archiveProjectionBuildCount == builds)
    #expect(state.archiveBrowserState.snapshot.map == map)
    #expect(map.walks.count == 100)
    #expect(map.locatedWalks.allSatisfy { abs(($0.coordinate?.latitude ?? 0) - 51) < 1e-9 })
    state.setArchiveYearFilter("1999")
    #expect(state.archiveProjectionBuildCount == builds + 1)
    #expect(state.archiveBrowserState.snapshot.map.walks.isEmpty)
    state.setArchiveYearFilter(nil)
    #expect(state.archiveProjectionBuildCount == builds + 2)
    #expect(state.archiveBrowserState.snapshot.map == map)
}

@Test @MainActor func archiveProjectionInvalidatesForCatalogueSortFiltersAndRoot() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let trip = navigationEntry("z", title: "Zed")
    let folder = navigationEntry("a", year: "2019", title: "Alpha", kind: .unorganisedFolder)
    let state = navigationState(root: root, entries: [trip, folder])
    var builds = state.archiveProjectionBuildCount
    state.setArchiveSort(.title)
    #expect(state.archiveProjectionBuildCount == builds + 1)
    #expect(state.archiveBrowserState.snapshot.entries.map(\.id) == [trip.id, folder.id])
    builds = state.archiveProjectionBuildCount
    state.setArchiveSort(.title)
    state.setShowArchivePreviews(false)
    state.setArchiveBrowseViewMode(.contactSheet)
    state.requestArchiveSearchFocus()
    #expect(state.archiveProjectionBuildCount == builds)
    state.setArchiveKindFilter(.unorganisedFolders)
    #expect(state.archiveProjectionBuildCount == builds + 1)
    #expect(state.archiveBrowserState.snapshot.entries.map(\.id) == [folder.id])
    state.setArchiveKindFilter(.all)
    builds = state.archiveProjectionBuildCount
    let newer = navigationEntry("b", year: "2026")
    state.testingInstallArchiveCatalogue(ArchiveCatalogue(entries: [folder, trip, newer], walksByTripPath: [:], photos: []))
    #expect(state.archiveProjectionBuildCount == builds + 1)
    #expect(state.archiveBrowserState.snapshot.yearGroups.map(\.year) == ["2026", "2025", "2019"])
    #expect(state.archiveBrowserState.snapshot.tripCount == 2)
    #expect(state.archiveBrowserState.snapshot.yearFilters.map(\.count) == [1, 1, 1])
    builds = state.archiveProjectionBuildCount
    state.settings.archiveRoot = root.appendingPathComponent("other")
    #expect(state.archiveProjectionBuildCount == builds + 1)
}

@Test @MainActor func archiveProjectionSearchPublicationAndClearRefreshCachedEntriesAndPhotos() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let trip = navigationEntry("trip")
    let folder = navigationEntry("folder", year: "2019", kind: .unorganisedFolder)
    let photos = [trip, folder].map { entry in
        ArchivePhotoSummary(id: entry.id + "/Beacon.jpg", archiveRelativePath: entry.archiveRelativePath + "/Beacon.jpg",
            title: "Beacon.jpg", date: nil, location: nil, camera: nil, aiDescription: nil, notes: nil, thumbnailPath: nil,
            walkPath: nil, tripPath: entry.kind == .trip ? entry.archiveRelativePath : nil)
    }
    let state = navigationState(root: root, entries: [trip, folder], photos: photos)
    let indexRows = photos.map { ArchiveIndexEntry(kind: .photo, year: String($0.archiveRelativePath.prefix(4)),
        archiveRelativePath: $0.archiveRelativePath, date: nil, title: $0.title, location: nil, exifSummary: nil,
        aiDescription: nil, thumbnailPath: nil, walkPath: nil, tripPath: $0.tripPath) }
    try ArchiveSearchCache(databaseURL: root.appendingPathComponent("support/archive-search.sqlite"))
        .rebuild(indexEntries: indexRows, browseEntries: [trip, folder])
    state.updateArchiveSearch("Beacon")
    for _ in 0..<100 where state.archiveBrowserState.snapshot.searchResults.count != 2 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(state.archiveBrowserState.snapshot.entries.count == 2)
    #expect(state.archiveBrowserState.snapshot.searchResults.count == 2)
    let builds = state.archiveProjectionBuildCount
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 2)
    #expect(state.archiveProjectionBuildCount == builds)
    state.setArchiveKindFilter(.trips)
    #expect(state.archiveBrowserState.snapshot.searchResults.map(\.id) == [photos[0].id])
    state.updateArchiveSearch("")
    #expect(state.archiveBrowserState.snapshot.searchResults.isEmpty)
    #expect(state.archiveBrowserState.snapshot.entries.map(\.id) == [trip.id])
}

@Test @MainActor func archivePhotoOpenPreviewsTheFocusedItemInsideARealLoadedTravelFolder() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source"), archive = root.appendingPathComponent("archive")
    try writeTestFile(source.appendingPathComponent("photo.jpg"), contents: "fixture original")
    let item = makeTestMediaItem(sourceRoot: source, fileName: "photo.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included)
    _ = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item]))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: archive, supportedExtensions: ["jpg"], machineRole: .travel)
    let state = navigationState(root: root, entries: catalogue.entries, walks: catalogue.walksByTripPath, photos: catalogue.photos)
    state.openCurrentSelection(); state.openCurrentSelection()
    for _ in 0..<100 where state.visibleMediaItems.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    #expect(state.visibleMediaItems.count == 1)
    state.focusReviewSurface()
    let focused = try #require(state.focusedReviewItemID)
    #expect(state.previewingMediaItemID == nil)
    state.openCurrentSelection()
    #expect(state.previewingMediaItemID == focused)
    #expect(!state.reviewNavigationState.snapshot.reviewGridHasFocus || state.activePane == .media)
}

@Test @MainActor func archiveFocusCommandPublishesARequestForTheCurrentCardSurface() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let trip = navigationEntry("trip")
    let walk = ArchiveWalkSummary(id: "walk", tripPath: trip.archiveRelativePath, archiveRelativePath: trip.archiveRelativePath + "/walk",
        title: "Walk", date: nil, location: nil, photoCount: 0, coverThumbnailPath: nil)
    let state = navigationState(root: root, entries: [trip], walks: [trip.archiveRelativePath: [walk]])
    let revision = state.archiveBrowserState.snapshot.browseFocusRevision
    state.focusReviewSurface()
    #expect(state.archiveBrowserState.snapshot.browseFocusRevision == revision + 1)
    state.openCurrentSelection()
    state.focusReviewSurface()
    #expect(state.archiveBrowserState.snapshot.browseFocusRevision == revision + 2)
    state.openCurrentSelection(); state.navigateToParent()
    #expect(state.archiveBrowserState.snapshot.browseFocusRevision == revision + 3)
}
