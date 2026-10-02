import Foundation
import SQLite3
import Testing
@testable import PhotoDiaryTriage

private func searchEntry(path: String, year: String = "2025", kind: ArchiveBrowseEntryKind = .unorganisedFolder) -> ArchiveBrowseEntry {
    ArchiveBrowseEntry(id: path, kind: kind, year: year, archiveRelativePath: path, title: "Folder", startDate: nil,
        endDate: nil, location: nil, photoCount: 1, walkCount: 0, coverThumbnailPath: nil)
}
private func searchPhoto(path: String, walk: String? = nil, trip: String? = nil) -> ArchivePhotoSummary {
    ArchivePhotoSummary(id: path, archiveRelativePath: path, title: (path as NSString).lastPathComponent, date: nil,
        location: nil, camera: nil, aiDescription: nil, notes: nil, thumbnailPath: nil, walkPath: walk, tripPath: trip)
}

@Test func archiveSearchHistoricalYearUsesItsVisibleContainingEntry() {
    let entry = searchEntry(path: "Old scans/Family", year: "2019")
    let photo = searchPhoto(path: "Old scans/Family/Beacon.jpg")
    let content = ArchiveBrowseContent(catalogue: ArchiveCatalogue(entries: [entry], walksByTripPath: [:], photos: [photo]),
        year: "2019", kind: .all, searchQuery: "Beacon", matchingPaths: [photo.archiveRelativePath], sort: .newest)
    #expect(content.entries.map(\.id) == [entry.id])
    #expect(content.searchResults.map(\.id) == [photo.id])
}

@Test func archiveSearchRootFolderContainsItsIndexedPhotoMatches() {
    let entry = searchEntry(path: ".", year: "2019")
    let photo = searchPhoto(path: "Beacon.jpg")
    let content = ArchiveBrowseContent(catalogue: ArchiveCatalogue(entries: [entry], walksByTripPath: [:], photos: [photo]),
        year: "2019", kind: .all, searchQuery: "Beacon", matchingPaths: [photo.archiveRelativePath], sort: .newest)
    #expect(content.entries.map(\.id) == [entry.id])
    #expect(content.searchResults.map(\.id) == [photo.id])
}

@Test @MainActor func archiveOpenSelectedSearchHitOpensItsPhotoFolderInsteadOfTheContainingTrip() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let trip = searchEntry(path: "2025/Trip", kind: .trip)
    let walk = "2025/Trip/Walk"
    let photo = searchPhoto(path: walk + "/Beacon.jpg", walk: walk, trip: trip.archiveRelativePath)
    var settings = makeTestSettings(root: root); settings.archiveMachineRole = .travel
    let support = root.appendingPathComponent("support")
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: support)
    state.testingInstallArchiveCatalogue(ArchiveCatalogue(entries: [trip], walksByTripPath: [:], photos: [photo]))
    let row = ArchiveIndexEntry(kind: .photo, year: "2025", archiveRelativePath: photo.archiveRelativePath, date: nil,
        title: photo.title, location: nil, exifSummary: nil, aiDescription: nil, thumbnailPath: nil, walkPath: walk, tripPath: trip.archiveRelativePath)
    try ArchiveSearchCache(databaseURL: support.appendingPathComponent("archive-search.sqlite")).rebuild(indexEntries: [row], browseEntries: [trip])
    state.updateArchiveSearch("Beacon")
    for _ in 0..<100 where state.archiveBrowserState.snapshot.searchResults.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
    state.selectArchiveSearchResult(photo.id)
    state.openCurrentSelection()
    #expect(state.archiveBrowserState.snapshot.level == .photos(path: walk, parentTripPath: trip.archiveRelativePath))
}

private actor ArchiveResponseGate<Input: Sendable, Output: Sendable> {
    struct Request: Sendable { let id: UUID; let input: Input }
    private var requests: [Request] = []
    private var waiting: CheckedContinuation<Request, Never>?
    private var responses: [UUID: CheckedContinuation<Output, any Error>] = [:]

    func call(_ input: Input) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let request = Request(id: UUID(), input: input)
            responses[request.id] = continuation
            if let waiting { self.waiting = nil; waiting.resume(returning: request) }
            else { requests.append(request) }
        }
    }
    func next() async -> Request {
        if !requests.isEmpty { return requests.removeFirst() }
        return await withCheckedContinuation { waiting = $0 }
    }
    func succeed(_ request: Request, _ output: Output) { responses.removeValue(forKey: request.id)?.resume(returning: output) }
    func fail(_ request: Request) { responses.removeValue(forKey: request.id)?.resume(throwing: CocoaError(.fileReadNoPermission)) }
}

private func finishArchiveTasks(_ tasks: [Task<Void, Never>]) async { for task in tasks { await task.value } }
private func searchIndexRow(_ photo: ArchivePhotoSummary, year: String = "2019") -> ArchiveIndexEntry {
    ArchiveIndexEntry(kind: .photo, year: year, archiveRelativePath: photo.archiveRelativePath, date: nil,
        title: photo.title, location: nil, exifSummary: nil, aiDescription: nil, thumbnailPath: nil,
        walkPath: photo.walkPath, tripPath: photo.tripPath)
}
private struct ArchiveFolderRequest: Sendable { let node: BrowserNode; let settings: AppSettings }

@MainActor private func searchWorkflowState(root: URL, photos: [ArchivePhotoSummary], role: ArchiveMachineRole = .travel,
    sessions: (any SessionPersisting)? = nil) throws -> AppState {
    var settings = makeTestSettings(root: root); settings.archiveMachineRole = role
    try AppDirectories.ensureExists(settings.archiveRoot)
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingSessionStore: sessions)
    let paths = Set(photos.map { ($0.archiveRelativePath as NSString).deletingLastPathComponent }).sorted()
    let entries = paths.map { searchEntry(path: $0.isEmpty ? "." : $0, year: "2019") }
    state.testingInstallArchiveCatalogue(ArchiveCatalogue(entries: entries, walksByTripPath: [:], photos: photos))
    try ArchiveSearchCache(databaseURL: root.appendingPathComponent("support/archive-search.sqlite"))
        .rebuild(indexEntries: photos.map { searchIndexRow($0) }, browseEntries: entries)
    state.setWorkspaceMode(.archiveView)
    return state
}
@MainActor private func readySearch(_ state: AppState, query: String = "Beacon") async {
    state.updateArchiveSearch(query)
    for _ in 0..<8 {
        let tasks = state.testingPendingArchiveTasks
        if tasks.isEmpty { break }
        await finishArchiveTasks(tasks)
    }
}
private func folderResult(_ request: ArchiveFolderRequest, paths: [String], selection: SelectionState = .included) -> ArchiveLoadResult {
    let items = paths.map { path in
        makeTestMediaItem(sourceRoot: request.settings.archiveRoot, fileName: path,
            capturedAt: Date(timeIntervalSince1970: 1_550_000_000), selectionState: selection)
    }
    return ArchiveLoadResult(nodeID: request.node.id, items: items, statusMessage: "Fixture folder loaded.")
}

@Test @MainActor func archiveSearchABAReverseCompletionsKeepOnlyLatestResultsAndError() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let a = searchPhoto(path: "Old/Beacon-old.jpg"), b = searchPhoto(path: "Old/Beacon-new.jpg")
    let state = try searchWorkflowState(root: root, photos: [a, b])
    let gate = ArchiveResponseGate<String, Set<String>>()
    state.testingArchiveSearchHandler = { _, query in try await gate.call(query) }
    state.updateArchiveSearch("Beacon"); let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    state.updateArchiveSearch("Changed"); let second = await gate.next(), secondTasks = state.testingPendingArchiveTasks
    #expect(state.archiveBrowserState.snapshot.searchResults.isEmpty && state.archiveBrowserState.snapshot.isSearching)
    #expect(!state.canOpenSelectedArchiveItem)
    state.updateArchiveSearch("Beacon"); let latest = await gate.next(), latestTasks = state.testingPendingArchiveTasks
    await gate.succeed(latest, [b.archiveRelativePath]); await finishArchiveTasks(latestTasks)
    await gate.fail(second); await finishArchiveTasks(secondTasks)
    await gate.succeed(first, [a.archiveRelativePath]); await finishArchiveTasks(firstTasks)
    #expect(first.input == latest.input)
    #expect(state.archiveBrowserState.snapshot.searchResults.map(\.id) == [b.id])
    #expect(state.archiveBrowserState.snapshot.searchError == nil && !state.archiveBrowserState.snapshot.isSearching)
}

@Test @MainActor func archiveSearchClearRejectsAnOlderFailureAndRetainsCatalogue() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let state = try searchWorkflowState(root: root, photos: [searchPhoto(path: "Old/Beacon.jpg")])
    let gate = ArchiveResponseGate<String, Set<String>>()
    state.testingArchiveSearchHandler = { _, query in try await gate.call(query) }
    state.updateArchiveSearch("Beacon"); let request = await gate.next(), tasks = state.testingPendingArchiveTasks
    state.updateArchiveSearch("")
    await gate.fail(request); await finishArchiveTasks(tasks)
    #expect(state.archiveBrowserState.snapshot.searchError == nil)
    #expect(!state.archiveBrowserState.snapshot.isSearching && state.archiveBrowserState.snapshot.entries.count == 1)
}

@Test @MainActor func archiveSearchFolderFailureRetryFocusesExactPathAndBackRetainsHit() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg"), other = searchPhoto(path: "Old/another.jpg")
    let state = try searchWorkflowState(root: root, photos: [hit, other]); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.setReviewFilter(.excluded)
    state.openArchiveSearchPhoto(hit); let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    #expect(state.archiveBrowserState.snapshot.folderLoadState == .loading && !state.canOpenSelectedArchiveItem)
    await gate.fail(first); await finishArchiveTasks(firstTasks)
    guard case .failed = state.archiveBrowserState.snapshot.folderLoadState else { Issue.record("Folder failure must have explicit Retry state."); return }
    state.retryArchiveFolderLoad(); let retry = await gate.next(), retryTasks = state.testingPendingArchiveTasks
    let loaded = folderResult(retry.input, paths: [other.archiveRelativePath, hit.archiveRelativePath])
    await gate.succeed(retry, loaded); await finishArchiveTasks(retryTasks)
    let hitID = try #require(loaded.items.first { $0.sourceURL.lastPathComponent == "Beacon.jpg" }?.id)
    #expect(state.focusedReviewItemID == hitID && state.selectedMediaItemIDs == [hitID])
    #expect(state.reviewFilter == .all && state.archiveBrowserState.snapshot.folderLoadState == .loaded)
    // Reopening within this catalogue uses the same exact-path route through its cache.
    state.openArchiveSearchPhoto(hit)
    #expect(state.focusedReviewItemID == hitID && state.archiveBrowserState.snapshot.folderLoadState == .loaded)
    state.navigateToParent()
    #expect(state.archiveBrowserState.snapshot.level == .archive)
    #expect(state.archiveBrowserState.snapshot.searchQuery == "Beacon" && state.archiveBrowserState.snapshot.searchSelection == .photo(hit.id))
}

@Test @MainActor func archiveSearchMainFreshUUIDsPreserveNewSelectionPreviewAndCompareAcrossRefresh() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg"), other = searchPhoto(path: "Old/another.jpg")
    let state = try searchWorkflowState(root: root, photos: [hit, other], role: .mainArchive); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.openArchiveSearchPhoto(hit); let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    let loaded = folderResult(first.input, paths: [hit.archiveRelativePath, other.archiveRelativePath])
    await gate.succeed(first, loaded); await finishArchiveTasks(firstTasks)
    let otherID = try #require(loaded.items.first { $0.sourceURL.lastPathComponent == "another.jpg" }?.id)
    state.selectMediaItems([otherID]); state.focusedReviewItemID = otherID
    state.reviewSelectionAnchorID = otherID; state.previewingMediaItemID = otherID
    state.openComparison(for: loaded.items.map(\.id), title: "Refresh comparison"); state.setReviewFilter(.included)
    state.testingArchiveCatalogueHandler = { _, _ in
        (ArchiveCatalogue(entries: [searchEntry(path: "Old", year: "2019")], walksByTripPath: [:], photos: [hit, other]),
         [searchIndexRow(hit), searchIndexRow(other)])
    }
    state.reloadArchiveCatalogue(); await finishArchiveTasks(state.testingPendingArchiveTasks)
    let refresh = await gate.next(), refreshTasks = state.testingPendingArchiveTasks
    let fresh = folderResult(refresh.input, paths: [hit.archiveRelativePath, other.archiveRelativePath])
    await gate.succeed(refresh, fresh); await finishArchiveTasks(refreshTasks)
    let freshOtherID = try #require(fresh.items.first { $0.sourceURL.lastPathComponent == "another.jpg" }?.id)
    #expect(freshOtherID != otherID)
    #expect(fresh.items.contains { $0.id == state.focusedReviewItemID })
    #expect(state.previewingMediaItemID == freshOtherID && Set(state.comparingMediaItemIDs) == Set(fresh.items.map(\.id)))
    #expect(state.reviewFilter == .included)
    state.closeComparison()
    #expect(state.focusedReviewItemID == freshOtherID && state.selectedMediaItemIDs == [freshOtherID])
    #expect(state.reviewSelectionAnchorID == freshOtherID)
}

@Test @MainActor func archiveSearchMissingHitNeverSelectsAnotherPhotoOrRepeatsAfterRefresh() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg"), other = searchPhoto(path: "Old/another.jpg")
    let state = try searchWorkflowState(root: root, photos: [hit, other]); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.openArchiveSearchPhoto(hit); let request = await gate.next(), tasks = state.testingPendingArchiveTasks
    await gate.succeed(request, folderResult(request.input, paths: [other.archiveRelativePath])); await finishArchiveTasks(tasks)
    #expect(state.selectedMediaItemIDs.isEmpty && state.focusedReviewItemID == nil)
    #expect(state.archiveBrowserState.snapshot.missingSearchHitMessage != nil)
    state.retryArchiveFolderLoad(); let retry = await gate.next(), retryTasks = state.testingPendingArchiveTasks
    await gate.succeed(retry, folderResult(retry.input, paths: [other.archiveRelativePath])); await finishArchiveTasks(retryTasks)
    #expect(state.archiveBrowserState.snapshot.missingSearchHitMessage == nil && state.selectedMediaItemIDs.isEmpty)
}

@Test @MainActor func archiveFolderEmptyNilForeignPathAndRetryAreExplicit() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg")
    let state = try searchWorkflowState(root: root, photos: [hit])
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.selectArchiveEntry("Old"); state.openSelectedArchiveItem()
    let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    await gate.succeed(first, nil); await finishArchiveTasks(firstTasks)
    guard case .failed = state.archiveBrowserState.snapshot.folderLoadState else { Issue.record("Nil load is a failure."); return }
    state.retryArchiveFolderLoad(); let foreign = await gate.next(), foreignTasks = state.testingPendingArchiveTasks
    await gate.succeed(foreign, folderResult(foreign.input, paths: ["Other/Beacon.jpg"])); await finishArchiveTasks(foreignTasks)
    guard case .failed = state.archiveBrowserState.snapshot.folderLoadState else { Issue.record("Foreign path must fail."); return }
    state.retryArchiveFolderLoad(); let empty = await gate.next(), emptyTasks = state.testingPendingArchiveTasks
    await gate.succeed(empty, folderResult(empty.input, paths: [])); await finishArchiveTasks(emptyTasks)
    #expect(state.archiveBrowserState.snapshot.folderLoadState == .loaded && !state.canOpenSelectedArchiveItem)
    #expect(state.archiveMediaCache[empty.input.node.id]?.isEmpty == true)
}

@Test @MainActor func archiveSearchSameFilenameAndSameFolderSupersededLoadsFocusLatestExactPath() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let a = searchPhoto(path: "Old/a/Beacon.jpg"), b = searchPhoto(path: "Old/b/Beacon.jpg")
    let state = try searchWorkflowState(root: root, photos: [a, b]); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.openArchiveSearchPhoto(a); let old = await gate.next(), oldTasks = state.testingPendingArchiveTasks
    state.openArchiveSearchPhoto(b); let latest = await gate.next(), latestTasks = state.testingPendingArchiveTasks
    let result = folderResult(latest.input, paths: [b.archiveRelativePath])
    await gate.succeed(latest, result); await finishArchiveTasks(latestTasks)
    await gate.fail(old); await finishArchiveTasks(oldTasks)
    #expect(state.focusedReviewItemID == result.items.first?.id)
    #expect(state.archiveBrowserState.snapshot.level == .photos(path: "Old/b", parentTripPath: nil))
    #expect(state.archiveBrowserState.snapshot.folderLoadState == .loaded)
}

@MainActor @Test(arguments: ["back", "year", "kind", "query", "workspace"])
func archiveSearchNavigationCancelsSuspendedPhotoLoad(_ action: String) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg")
    let state = try searchWorkflowState(root: root, photos: [hit]); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.openArchiveSearchPhoto(hit); let request = await gate.next(), tasks = state.testingPendingArchiveTasks
    switch action {
    case "back": state.navigateToParent()
    case "year": state.setArchiveYearFilter("2018")
    case "kind": state.setArchiveKindFilter(.trips)
    case "query": state.updateArchiveSearch("Different")
    default: state.setWorkspaceMode(.cameraTriage)
    }
    await gate.succeed(request, folderResult(request.input, paths: [hit.archiveRelativePath])); await finishArchiveTasks(tasks)
    #expect(state.focusedReviewItemID == nil && state.selectedMediaItemIDs.isEmpty)
    #expect(state.archiveMediaCache[request.input.node.id] == nil)
    #expect(state.archiveBrowserState.snapshot.folderLoadState == .idle)
    await finishArchiveTasks(state.testingPendingArchiveTasks)
}

@MainActor @Test(arguments: ["root", "role", "pictures", "restore"])
func archiveSearchContextReplacementRejectsSuspendedFolderLoad(_ action: String) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg")
    let store = try SessionStore(databaseURL: root.appendingPathComponent("support/session-fixture.sqlite"))
    let state = try searchWorkflowState(root: root, photos: [hit], sessions: store); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.openArchiveSearchPhoto(hit); let request = await gate.next(), tasks = state.testingPendingArchiveTasks
    state.testingArchiveCatalogueHandler = { _, _ in (.empty, []) }
    switch action {
    case "root": state.setArchiveRoot(root.appendingPathComponent("second-archive"))
    case "role": state.setArchiveMachineRole(.mainArchive)
    case "pictures": state.setOneDrivePicturesRoot(root.appendingPathComponent("pictures"))
    default:
        let backup = root.appendingPathComponent("restore.json")
        try state.exportBackup(to: backup); try state.restoreBackup(from: backup)
    }
    await gate.succeed(request, folderResult(request.input, paths: [hit.archiveRelativePath])); await finishArchiveTasks(tasks)
    await finishArchiveTasks(state.testingPendingArchiveTasks)
    #expect(state.archiveBrowserState.snapshot.level == .archive && state.archiveBrowserState.snapshot.folderLoadState == .idle)
    #expect(state.focusedReviewItemID == nil && state.archiveMediaCache[request.input.node.id] == nil)
}

@Test @MainActor func archiveCatalogueReverseRootsPublishTheirOwnSearchDatabaseOnly() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let a = searchPhoto(path: "Old/Beacon-A.jpg"), b = searchPhoto(path: "Old/Beacon-B.jpg")
    let state = try searchWorkflowState(root: root, photos: [a])
    let gate = ArchiveResponseGate<URL, (ArchiveCatalogue, [ArchiveIndexEntry])>()
    state.testingArchiveCatalogueHandler = { root, _ in try await gate.call(root) }
    state.reloadArchiveCatalogue(); let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    state.setArchiveRoot(root.appendingPathComponent("second-archive")); let second = await gate.next(), secondTasks = state.testingPendingArchiveTasks
    await gate.succeed(second, (ArchiveCatalogue(entries: [searchEntry(path: "Old", year: "2019")], walksByTripPath: [:], photos: [b]), [searchIndexRow(b)]))
    await finishArchiveTasks(secondTasks)
    await gate.succeed(first, (ArchiveCatalogue(entries: [searchEntry(path: "Old", year: "2019")], walksByTripPath: [:], photos: [a]), [searchIndexRow(a)]))
    await finishArchiveTasks(firstTasks)
    await readySearch(state)
    #expect(first.input != second.input)
    #expect(state.archiveBrowserState.snapshot.searchResults.map(\.id) == [b.id])
    #expect(!state.archiveBrowserState.snapshot.isLoading && state.archiveBrowserState.snapshot.errorMessage == nil)
}

@Test func archiveSearchFailedSchemaReplacementRollsBackPreviousResults() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let cache = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    try cache.rebuild(indexEntries: [searchIndexRow(searchPhoto(path: "Old/Beacon.jpg"))], browseEntries: [])
    let failing = ArchiveSearchCache(databaseURL: cache.databaseURL, configureConnection: { db in
        sqlite3_set_authorizer(db, { _, action, _, _, _, _ in action == SQLITE_CREATE_VTABLE ? SQLITE_DENY : SQLITE_OK }, nil)
    })
    #expect(throws: (any Error).self) { try failing.rebuild(indexEntries: [], browseEntries: []) }
    #expect(try cache.matchingPaths(query: "Beacon") == ["Old/Beacon.jpg"])
}

@Test func archiveSearchCorruptAndInterruptedReadsFailInsteadOfReturningEmptyOrPartialMatches() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("corrupt.sqlite"); try writeTestFile(url, contents: "broken database")
    #expect(throws: (any Error).self) { try ArchiveSearchCache(databaseURL: url).matchingPaths(query: "Beacon") }
    let cache = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    let rows = (0..<5_100).map { searchIndexRow(searchPhoto(path: "Old/Beacon-\($0).jpg")) }
    try cache.rebuild(indexEntries: rows, browseEntries: [])
    #expect(try cache.matchingPaths(query: "Beacon").count == rows.count)
    let interrupted = ArchiveSearchCache(databaseURL: cache.databaseURL, configureConnection: { db in
        sqlite3_progress_handler(db, 100, { _ in 1 }, nil)
    })
    #expect(throws: (any Error).self) { try interrupted.matchingPaths(query: "Beacon") }
}

@Test func archiveSearchDatabaseLeaseRetainsOnlyItsOwnedFilesAndNeverDeletesBorrowedCache() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    var lease: ArchiveSearchDatabaseSnapshot? = ArchiveSearchDatabaseSnapshot(archiveRoot: root, supportRoot: root)
    let url = try #require(lease?.databaseURL)
    try ArchiveSearchCache(databaseURL: url).rebuild(indexEntries: [], browseEntries: [])
    var heldByTask = lease
    lease = nil
    #expect(FileManager.default.fileExists(atPath: url.path))
    withExtendedLifetime(heldByTask) {}
    heldByTask = nil
    #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    let borrowedURL = root.appendingPathComponent("borrowed.sqlite"); try writeTestFile(borrowedURL)
    var borrowed: ArchiveSearchDatabaseSnapshot? = ArchiveSearchDatabaseSnapshot(borrowing: borrowedURL, archiveRoot: root)
    withExtendedLifetime(borrowed) {}; borrowed = nil
    #expect(FileManager.default.fileExists(atPath: borrowedURL.path))
}

@Test @MainActor func archiveFolderRefreshRespectsClosingPreviewAndCompareWhileLoadIsSuspended() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let hit = searchPhoto(path: "Old/Beacon.jpg"), other = searchPhoto(path: "Old/another.jpg")
    let state = try searchWorkflowState(root: root, photos: [hit, other], role: .mainArchive); await readySearch(state)
    let gate = ArchiveResponseGate<ArchiveFolderRequest, ArchiveLoadResult?>()
    state.testingArchiveLoadHandler = { node, settings in try await gate.call(ArchiveFolderRequest(node: node, settings: settings)) }
    state.openArchiveSearchPhoto(hit); let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    let loaded = folderResult(first.input, paths: [hit.archiveRelativePath, other.archiveRelativePath])
    await gate.succeed(first, loaded); await finishArchiveTasks(firstTasks)
    let otherID = try #require(loaded.items.last?.id)
    state.selectMediaItems([otherID]); state.previewingMediaItemID = otherID
    state.openComparison(for: loaded.items.map(\.id), title: "Refresh comparison")
    state.retryArchiveFolderLoad(); let refresh = await gate.next(), refreshTasks = state.testingPendingArchiveTasks
    state.closeComparison(); state.previewingMediaItemID = nil
    let fresh = folderResult(refresh.input, paths: [hit.archiveRelativePath, other.archiveRelativePath])
    await gate.succeed(refresh, fresh); await finishArchiveTasks(refreshTasks)
    #expect(state.comparingMediaItemIDs.isEmpty && state.previewingMediaItemID == nil)
    let otherPath = try #require(loaded.items.last).sourceURL.path
    let freshOther = try #require(fresh.items.first { $0.sourceURL.path == otherPath })
    #expect(state.selectedMediaItemIDs == [freshOther.id] && state.focusedReviewItemID == freshOther.id)
}

@Test func archiveSearchClearedTripLocationDoesNotRestoreStaleIndexLabel() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let cache = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    let trip = searchEntry(path: "2019/Trip", kind: .trip)
    let row = ArchiveIndexEntry(kind: .trip, year: "2019", archiveRelativePath: trip.archiveRelativePath, date: nil,
        title: "Trip", location: "StaleBeaconLabel", exifSummary: nil, aiDescription: nil, thumbnailPath: nil, walkPath: nil, tripPath: nil)
    try cache.rebuild(indexEntries: [row], browseEntries: [trip])
    #expect(try cache.matchingPaths(query: "StaleBeaconLabel").isEmpty)
}

@MainActor @Test(arguments: [false, true])
func archiveTravelConsecutiveTripLabelSavesAndPlainRefreshRetainBothSearchableOverlays(_ legacyIdentity: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    var settings = makeTestSettings(root: root); settings.archiveMachineRole = .travel
    let archive = settings.archiveRoot
    let manifests = try ["TripA", "TripB"].map { title in
        try TripManifestStore().updateNamedTripManifest(folder: archive.appendingPathComponent("2019/" + title),
            title: title, oneDrivePicturesRoot: archive, adding: [])
    }
    let entries = manifests.map { manifest -> ArchiveBrowseEntry in
        var entry = searchEntry(path: manifest.folderRelativePath!, year: "2019", kind: .trip)
        entry.tripID = legacyIdentity ? nil : manifest.tripID; return entry
    }
    let rows = entries.map { entry in
        ArchiveIndexEntry(kind: .trip, year: entry.year, archiveRelativePath: entry.archiveRelativePath, date: nil,
            title: entry.title, location: nil, exifSummary: nil, aiDescription: nil, thumbnailPath: nil,
            walkPath: nil, tripPath: nil, tripID: entry.tripID)
    }
    let catalogue = ArchiveCatalogue(entries: entries, walksByTripPath: [:], photos: [])
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    state.testingInstallArchiveCatalogue(catalogue); state.setWorkspaceMode(.archiveView)
    let gate = ArchiveResponseGate<URL, (ArchiveCatalogue, [ArchiveIndexEntry])>()
    state.testingArchiveCatalogueHandler = { root, _ in try await gate.call(root) }
    state.reloadArchiveCatalogue(); let original = await gate.next(), originalTasks = state.testingPendingArchiveTasks
    await state.saveTripLocationLabel("BeaconAlpha", target: try #require(state.tripLocationTarget(for: entries[0])), archiveRoot: archive)
    let first = await gate.next(), firstTasks = state.testingPendingArchiveTasks
    await state.saveTripLocationLabel("BeaconBeta", target: try #require(state.tripLocationTarget(for: entries[1])), archiveRoot: archive)
    let second = await gate.next(), secondTasks = state.testingPendingArchiveTasks
    await gate.succeed(second, (catalogue, rows)); await finishArchiveTasks(secondTasks)
    await gate.fail(first); await finishArchiveTasks(firstTasks)
    await gate.succeed(original, (catalogue, rows)); await finishArchiveTasks(originalTasks)
    #expect(!state.archiveBrowserState.snapshot.isLoading)
    await readySearch(state, query: "BeaconAlpha")
    #expect(state.archiveBrowserState.snapshot.entries.map(\.id) == [entries[0].id])
    await readySearch(state, query: "BeaconBeta")
    #expect(state.archiveBrowserState.snapshot.entries.map(\.id) == [entries[1].id])
    state.reloadArchiveCatalogue(); let refresh = await gate.next(), refreshTasks = state.testingPendingArchiveTasks
    await gate.succeed(refresh, (catalogue, rows)); await finishArchiveTasks(refreshTasks)
    await readySearch(state, query: "BeaconAlpha")
    #expect(state.archiveBrowserState.snapshot.entries.first?.location == "BeaconAlpha")
    await readySearch(state, query: "BeaconBeta")
    #expect(state.archiveBrowserState.snapshot.entries.first?.location == "BeaconBeta")
    await readySearch(state, query: "BeaconAlpha")
    let publishedA = try #require(state.archiveBrowserState.snapshot.entries.first)
    #expect(publishedA.tripID == manifests[0].tripID)
    await state.saveTripLocationLabel(nil, target: try #require(state.tripLocationTarget(for: publishedA)), archiveRoot: archive)
    let cleared = await gate.next(), clearTasks = state.testingPendingArchiveTasks
    await gate.succeed(cleared, (catalogue, rows)); await finishArchiveTasks(clearTasks)
    await readySearch(state, query: "BeaconAlpha")
    #expect(state.archiveBrowserState.snapshot.entries.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: ArchiveIndexStore.indexRoot(for: archive).path))
}

@MainActor @Test(arguments: ["Old/Family/Beacon.jpg", "Beacon.jpg"])
func archiveFreshIndexOnlyTravelSearchOpensGridWithoutOriginalsOrManifests(_ path: String) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let settings = { var value = makeTestSettings(root: root); value.archiveMachineRole = .travel; return value }()
    let archive = settings.archiveRoot, indexRoot = ArchiveIndexStore.indexRoot(for: archive)
    let photo = searchPhoto(path: path)
    let row = searchIndexRow(photo)
    let folderPath = (path as NSString).deletingLastPathComponent
    let folder = ArchiveIndexEntry(kind: .unorganisedFolder, year: "2019", archiveRelativePath: folderPath.isEmpty ? "." : folderPath, date: nil,
        title: "Family", location: nil, exifSummary: nil, aiDescription: nil, thumbnailPath: nil,
        walkPath: nil, tripPath: nil, photoCount: 1)
    try AppDirectories.ensureExists(indexRoot)
    let encoder = JSONEncoder()
    let lines = try [folder, row].map { try String(decoding: encoder.encode($0), as: UTF8.self) }.joined(separator: "\n") + "\n"
    try lines.write(to: indexRoot.appendingPathComponent("index-2019.jsonl"), atomically: true, encoding: .utf8)
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    state.reloadArchiveCatalogue(); await finishArchiveTasks(state.testingPendingArchiveTasks)
    state.setArchiveYearFilter("2019"); await readySearch(state)
    let hit = try #require(state.archiveBrowserState.snapshot.searchResults.first)
    state.openArchiveSearchPhoto(hit); await finishArchiveTasks(state.testingPendingArchiveTasks)
    let selected = try #require(state.selectedMediaItems.first)
    #expect(selected.archiveRelativePath == photo.archiveRelativePath && state.focusedReviewItemID == selected.id)
    #expect(state.archiveBrowserState.snapshot.folderLoadState == .loaded)
    #expect(!FileManager.default.fileExists(atPath: selected.sourceURL.path))
    #expect(!ArchiveByteReadPolicyContext.shared.canReadBytes(at: selected.sourceURL))
    #expect(!ArchiveByteReadPolicyContext.shared.canPreheatOriginal(at: selected.sourceURL))
    #expect(!FileManager.default.fileExists(atPath: archive.appendingPathComponent("Old").path))
}

@MainActor @Test(arguments: [ArchiveBrowseViewMode.timeline, .contactSheet, .map])
func archiveSearchKeyboardTargetOwnsOpenAndContextualActions(_ mode: ArchiveBrowseViewMode) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let a = searchPhoto(path: "Old/Beacon-a.jpg"), b = searchPhoto(path: "Old/Beacon-b.jpg")
    let state = try searchWorkflowState(root: root, photos: [a, b]); await readySearch(state)
    state.setArchiveBrowseViewMode(mode)
    state.selectArchiveSearchResult(a.id)
    state.moveArchiveSelection(horizontal: mode == .map ? 0 : 1, vertical: mode == .map ? 1 : 0, contactSheetColumns: 2)
    #expect(state.archiveBrowserState.snapshot.searchSelection == .photo(b.id))
    #expect(!state.canOrganiseSelectedUnorganisedFolder)
    #expect(state.contextualDescriptionTargets.map { $0.1 } == [b.archiveRelativePath])
    state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: 2)
    #expect(state.archiveBrowserState.snapshot.searchSelection == .entry("Old"))
    #expect(state.canOrganiseSelectedUnorganisedFolder && state.contextualDescriptionTargets.isEmpty)
    state.testingArchiveLoadHandler = { node, settings in folderResult(ArchiveFolderRequest(node: node, settings: settings), paths: [a.archiveRelativePath, b.archiveRelativePath]) }
    state.selectArchiveSearchResult(b.id); state.openCurrentSelection()
    await finishArchiveTasks(state.testingPendingArchiveTasks)
    #expect(state.selectedMediaItems.first?.archiveRelativePath == b.archiveRelativePath)
}

@Test func archiveCatalogueAndSearchUseCapturedRowsWithoutRereadingChangedIndex() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let indexRoot = ArchiveIndexStore.indexRoot(for: root)
    try AppDirectories.ensureExists(indexRoot)
    try writeTestFile(indexRoot.appendingPathComponent("index-2019.jsonl"), contents: "changed invalid index")
    let photo = searchPhoto(path: "Old/Beacon.jpg")
    let folder = ArchiveIndexEntry(kind: .unorganisedFolder, year: "2019", archiveRelativePath: "Old", date: nil,
        title: "Old", location: nil, exifSummary: nil, aiDescription: nil, thumbnailPath: nil,
        walkPath: nil, tripPath: nil, photoCount: 1)
    let captured = [folder, searchIndexRow(photo)]
    let builder = ArchiveCatalogueBuilder()
    #expect(throws: (any Error).self) { try builder.readIndexEntries(archiveRoot: root) }
    let catalogue = try builder.build(archiveRoot: root, supportedExtensions: ["jpg"], machineRole: .travel, indexEntries: captured)
    let cache = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    try cache.rebuild(indexEntries: captured, browseEntries: catalogue.entries)
    #expect(catalogue.photos.map(\.id) == [photo.id])
    #expect(try cache.matchingPaths(query: "Beacon") == [photo.archiveRelativePath])
}
