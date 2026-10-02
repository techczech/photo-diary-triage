import Foundation
import Testing
@testable import PhotoDiaryTriage

private func historicalRoot() throws -> URL { try makeTemporaryDirectory().resolvingSymlinksInPath() }
private func historicalSession(root: URL, insideArchive: Bool = false, count: Int = 2) throws -> ImportSession {
    let settings = makeTestSettings(root: root)
    let source = (insideArchive ? settings.archiveRoot : root).appendingPathComponent("2013-06 Croatia")
    for number in 1...count { try writeTestFile(source.appendingPathComponent("IMG_000\(number).jpg"), contents: "original-photo-\(number)") }
    return try SessionManager(scanner: FileScanner(), groupingService: GroupingService()).openSession(
        for: source, settings: settings, historical: HistoricalSourceContext(root: source)).session
}
private final class HistoricalFailureManager: FileManager, @unchecked Sendable {
    var failCopyName: String?
    var failDeleteName: String?
    override func copyItem(at source: URL, to destination: URL) throws {
        if source.lastPathComponent == failCopyName { throw CocoaError(.fileWriteOutOfSpace) }
        try super.copyItem(at: source, to: destination)
    }
    override func removeItem(at url: URL) throws {
        if url.lastPathComponent == failDeleteName { throw CocoaError(.fileWriteNoPermission) }
        try super.removeItem(at: url)
    }
}
private final class HistoricalFailingStore: SessionPersisting {
    let memory = InMemorySessionStore()
    var rejectSave = false
    func save(session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) throws {
        if rejectSave { throw CocoaError(.fileWriteOutOfSpace) }
        try memory.save(session: session, bursts: bursts, clusters: clusters)
    }
    func loadSessions() throws -> [(ImportSession, [BurstGroup], [TimeCluster])] { try memory.loadSessions() }
    func replaceAllSessions(with sessions: [(ImportSession, [BurstGroup], [TimeCluster])]) throws { try memory.replaceAllSessions(with: sessions) }
}
@MainActor private func historicalWait(_ condition: () -> Bool) async throws {
    for _ in 0..<500 { if condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
    Issue.record("Historical workflow did not reach the expected state within five seconds.")
}
private func historicalPhotos(_ root: URL) -> [URL] {
    FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL }.filter { $0.pathExtension == "jpg" } ?? []
}

@Test func historicalDefaultsKeepAllAndCameraDefaultsRemainUndecided() throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let historical = try historicalSession(root: root)
    let camera = try SessionManager(scanner: FileScanner(), groupingService: GroupingService()).openSession(for: historical.sourceFolder, settings: makeTestSettings(root: root)).session
    #expect(historical.mediaItems.allSatisfy { $0.selectionState == .included })
    #expect(camera.mediaItems.allSatisfy { $0.selectionState == .undecided })
    #expect(historical.walkMetadata.title == "Croatia")
    #expect(historical.mediaItems.allSatisfy { $0.captureDateEvidence?.precision == .month })
    let plan = try #require(ArchivePlanner().planWalks(for: historical).first)
    #expect(plan.archiveFolder.path.contains("/2013/06-June-Croatia/"))
    #expect(plan.walkTitle == "Croatia")
}

@Test func historicalDatesKeepOriginalAndRecordPartialPrecision() throws {
    let root = URL(fileURLWithPath: "/tmp/2020/03/28")
    var item = makeTestMediaItem(sourceRoot: root, fileName: "IMG_0001.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000))
    item.sourceModificationTime = 1_750_000_000
    let camera = HistoricalSourceHints.applying(to: item, context: HistoricalSourceContext(root: root))
    #expect(camera.capturedAt == item.metadata.capturedAt)
    #expect(camera.captureDateEvidence?.conflictsWithFolder == true)
    let folder = HistoricalSourceHints.applying(to: camera, context: HistoricalSourceContext(root: root, datePreference: .folder))
    #expect(DateFormatting.archiveFormatterForParsing.string(from: try #require(folder.capturedAt)) == "2020-03-28")
    #expect(folder.metadata.capturedAt == item.metadata.capturedAt)
    #expect(folder.captureDateEvidence?.originalCameraDate == item.metadata.capturedAt)
    #expect(folder.captureDateEvidence?.precision == .day)
    #expect(folder.compactCapturedAtLabel == "2020-03-28 (time unknown)")
    #expect(HistoricalSourceHints.folderDate(for: URL(fileURLWithPath: "/tmp/2023-02-30/IMG_0001.jpg"), root: URL(fileURLWithPath: "/tmp/2023-02-30")) == nil)
    #expect(HistoricalSourceHints.title(from: "IMG_0001") == nil)
    #expect(HistoricalSourceHints.title(from: "100CANON") == nil)
    #expect(HistoricalSourceHints.title(from: "2013-06 Croatia") == "Croatia")
    item.metadata.capturedAt = nil
    item.sourceURL = URL(fileURLWithPath: "/tmp/1987/IMG_0001.jpg")
    let year = HistoricalSourceHints.applying(to: item, context: HistoricalSourceContext(root: item.sourceURL.deletingLastPathComponent()))
    #expect(year.captureDateEvidence?.precision == .year)
    item.sourceURL = URL(fileURLWithPath: "/tmp/undated/IMG_0001.jpg")
    let fallback = HistoricalSourceHints.applying(to: item, context: HistoricalSourceContext(root: item.sourceURL.deletingLastPathComponent()))
    #expect(fallback.captureDateEvidence?.source == .fileModification)
    #expect(fallback.capturedAt == Date(timeIntervalSince1970: 1_750_000_000))
}

@MainActor @Test func historicalReloadPreservesChoicesPreferencesAndRefreshesRelationships() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root, count: 1)
    let store = InMemorySessionStore()
    let state = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support"), testingSessionStore: store)
    state.loadSourceWorkspace(folder: original.sourceFolder, origin: .historicalFolder)
    try await historicalWait { state.currentSession != nil }
    let initial = try #require(state.currentSession?.mediaItems.first)
    state.selectMediaItems([initial.id]); state.excludeCurrentSelectionFromImport(); state.toggleHistoricalFolderDates()
    try writeTestFile(original.sourceFolder.appendingPathComponent("IMG_0001.cr3"), contents: "new raw")
    try writeTestFile(original.sourceFolder.appendingPathComponent("IMG_0002.jpg"), contents: "new photo")
    await state.openSession(for: original.sourceFolder)
    let reloaded = try #require(state.currentSession?.mediaItems.first { $0.fileName == initial.fileName })
    #expect(reloaded.id == initial.id)
    #expect(reloaded.selectionState == .excluded)
    #expect(reloaded.companionFiles.count == 1)
    #expect(state.currentSession?.mediaItems.first { $0.fileName == "IMG_0002.jpg" }?.selectionState == .included)
    #expect(state.prefersHistoricalFolderDates)
    try FileManager.default.removeItem(at: reloaded.companionFiles[0].sourceURL)
    let reopened = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support-2"), testingSessionStore: store)
    reopened.currentSession = makeTestSession(sourceRoot: root.appendingPathComponent("other"), archiveRoot: original.archiveRoot, items: [])
    reopened.loadSourceWorkspace(folder: original.sourceFolder, origin: .historicalFolder)
    try await historicalWait { reopened.currentSession?.sourceFolder.resolvingSymlinksInPath().path == original.sourceFolder.resolvingSymlinksInPath().path }
    #expect(reopened.prefersHistoricalFolderDates)
    #expect(reopened.currentSession?.mediaItems.first { $0.id == initial.id }?.companionFiles.isEmpty == true)
}

@MainActor @Test func historicalActualCopyRetryReopensTheExactConfirmedPlan() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root)
    let store = InMemorySessionStore(), manager = HistoricalFailureManager()
    manager.failCopyName = "IMG_0002.jpg"
    let settings = makeTestSettings(root: root)
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingImportCoordinator: ImportCoordinator(fileManager: manager), testingSessionStore: store)
    state.loadSourceWorkspace(folder: original.sourceFolder, origin: .historicalFolder)
    try await historicalWait { state.currentSession != nil }
    state.focusReviewSurface()
    state.commitImport()
    var editor = try #require(state.activeWalkCommitEditor)
    editor.walks[0].title = "Edited outing"
    editor.walks[0].tripTarget = TripTarget(kind: .newNamedTrip, title: "Reviewed holiday", folderRelativePath: nil)
    state.updateWalkCommitEditor(editor); state.confirmWalkCommit()
    try await historicalWait { state.importOperation.phase == .failed }
    let sessionID = try #require(state.currentSession?.id)
    #expect(try store.loadSessions().first { $0.0.id == sessionID }?.0.proposedWalks == editor.walks)
    #expect(historicalPhotos(original.archiveRoot).count == 1)
    let reopened = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support-2"), testingSessionStore: store)
    reopened.openSavedWalk(sessionID); reopened.commitImport()
    let retry = try #require(reopened.activeWalkCommitEditor)
    #expect(retry.isRecoveryPlan)
    #expect(retry.walks == editor.walks)
    let beforeEdits = try #require(reopened.currentSession)
    reopened.addSourceFolderToCurrentTriage(original.sourceFolder, historical: true)
    reopened.updateWalkMetadata(title: "Change", location: "Elsewhere", notes: "Changed")
    reopened.selectMediaItems(Set(beforeEdits.mediaItems.map(\.id))); reopened.excludeCurrentSelectionFromImport()
    reopened.deletePhotoLog(sessionID)
    #expect(reopened.currentSession == beforeEdits)
    #expect(reopened.activeWalkCommitEditor?.walks == editor.walks)
    reopened.confirmWalkCommit()
    try await historicalWait { reopened.importOperation.phase == .completed || reopened.importOperation.phase == .failed }
    #expect(reopened.importOperation.phase == .completed)
    #expect(historicalPhotos(original.archiveRoot).count == 2)
    #expect(reopened.currentSession?.mediaItems.allSatisfy { $0.destinationURL?.path.contains("Reviewed-holiday") == true } == true)
    #expect(try Data(contentsOf: original.mediaItems[0].sourceURL) == Data("original-photo-1".utf8))
}

@MainActor @Test func historicalConfirmedPlanMustPersistBeforeAnyCopy() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root)
    let store = HistoricalFailingStore()
    let state = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support"), testingSessionStore: store)
    state.loadSourceWorkspace(folder: original.sourceFolder, origin: .historicalFolder)
    try await historicalWait { state.currentSession != nil }
    state.focusReviewSurface()
    state.commitImport(); #expect(state.activeWalkCommitEditor != nil)
    store.rejectSave = true; state.confirmWalkCommit()
    #expect(state.statusMessage.contains("Could not save the confirmed Copy plan"))
    #expect(historicalPhotos(original.archiveRoot).isEmpty)
}

@Test func historicalManifestsAndIndexRetainDateEvidenceAndSources() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root)
    let result = try await ImportCoordinator().commit(session: original)
    let loaded = try ArchiveIndexStore().loadFileManifests(folder: result.walkManifest.archiveFolder, archiveRoot: original.archiveRoot)
    #expect(loaded.count == 2)
    #expect(loaded.allSatisfy { $0.captureDateEvidence?.source == .folder && $0.captureDateEvidence?.precision == .month })
    let entries = try ArchiveIndexStore().entriesForWalkFolder(result.walkManifest.archiveFolder, archiveRoot: original.archiveRoot)
    #expect(entries.filter { $0.kind == .photo }.allSatisfy { $0.captureDateEvidence?.precision == .month })
    #expect(original.mediaItems.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@Test func historicalSurveyRequiresEqualBytesAndWorksAfterRelocationAndDateCorrection() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var original = try historicalSession(root: root)
    _ = try await ImportCoordinator().commit(session: original)
    let moved = root.appendingPathComponent("relocated")
    try FileManager.default.moveItem(at: original.archiveRoot, to: moved)
    original.mediaItems[0].capturedAt = Date()
    let matches = await ArchiveCopySurveyor().survey(items: original.mediaItems, archiveRoot: moved, historical: true)
    #expect(matches.count == 2)
    for match in matches.values {
        #expect(match.byteVerified)
        #expect(URL(fileURLWithPath: match.archivePath).resolvingSymlinksInPath().standardizedFileURL.path.hasPrefix(moved.resolvingSymlinksInPath().standardizedFileURL.path + "/"))
    }
    let source = original.mediaItems[0].sourceURL
    try Data(repeating: 0, count: Int(original.mediaItems[0].fileSizeBytes)).write(to: source)
    let mismatches = await ArchiveCopySurveyor().survey(items: original.mediaItems, archiveRoot: moved, historical: true)
    #expect(mismatches[original.mediaItems[0].relativePath] == nil)
    let travel = await ArchiveCopySurveyor().survey(items: original.mediaItems, archiveRoot: moved, machineRole: .travel, historical: true)
    #expect(travel.isEmpty)
}

@MainActor @Test func historicalAddSourceRecognisesPriorCopiesWithoutCleanupAuthority() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root, count: 1)
    _ = try await ImportCoordinator().commit(session: original)
    let state = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support"))
    state.currentSession = makeTestSession(sourceRoot: root.appendingPathComponent("camera"), archiveRoot: original.archiveRoot, items: [], sessionKind: .inbox)
    state.addSourceFolderToCurrentTriage(original.sourceFolder, historical: true)
    try await historicalWait { state.currentSession?.mediaItems.count == 1 }
    let item = try #require(state.currentSession?.mediaItems.first)
    #expect(item.recognisedArchiveCopy == true)
    #expect(item.lifecycleState == .verified && item.selectionState == .undecided)
    let backedUp = SessionMutationCoordinator().sessionByMarkingBackupConfirmed(try #require(state.currentSession))
    #expect(backedUp.mediaItems[0].lifecycleState == .verified)
}

@Test func historicalSymlinkDestinationIsRejectedBeforeRecordingOrWriting() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let session = try historicalSession(root: root, insideArchive: true)
    let plan = try #require(ArchivePlanner().planWalks(for: session).first)
    try AppDirectories.ensureExists(plan.tripFolder.deletingLastPathComponent())
    try FileManager.default.createSymbolicLink(at: plan.tripFolder, withDestinationURL: session.sourceFolder)
    await #expect(throws: (any Error).self) { try await ImportCoordinator().commit(session: session) }
    #expect(try ArchiveOperationRecovery(archiveRoot: session.archiveRoot).load(ImportRecoveryRecord.self, kind: "import", sessionID: session.id) == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: session.sourceFolder.path).sorted() == ["IMG_0001.jpg", "IMG_0002.jpg"])
}

@Test func historicalHiddenCanonicalFoldersAreNeitherScannedNorCleaned() throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root, insideArchive: true, count: 1)
    let hidden = original.sourceFolder.appendingPathComponent(".hidden/Canonical")
    try writeTestFile(hidden.appendingPathComponent("Canonical.md"), contents: "- Session ID: `\(UUID())`\n")
    try writeTestFile(hidden.appendingPathComponent("IMG_0002.jpg"))
    try HistoricalSourceSafety.validate(root: original.sourceFolder, archiveRoot: original.archiveRoot)
    #expect(try FileScanner().scanFolder(original.sourceFolder, settings: makeTestSettings(root: root)).count == 1)
    let visible = original.sourceFolder.appendingPathComponent("Visible")
    try writeTestFile(visible.appendingPathComponent("Visible.md"), contents: "- Session ID: `\(UUID())`\n")
    #expect(throws: (any Error).self) { try HistoricalSourceSafety.validate(root: original.sourceFolder, archiveRoot: original.archiveRoot) }
}

@Test func historicalArchiveCleanupIsRecordedDigestCheckedAndResumable() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var original = try historicalSession(root: root, insideArchive: true)
    let raw = original.sourceFolder.appendingPathComponent("IMG_0001.cr3")
    try writeTestFile(raw, contents: "raw original")
    original.mediaItems[0].companionFiles = [makeTestCompanionFile(sourceRoot: original.sourceFolder, fileName: raw.lastPathComponent)]
    original.mediaItems[0].importRawCompanions = true
    let excluded = original.sourceFolder.appendingPathComponent("leave.jpg"), unsupported = original.sourceFolder.appendingPathComponent("notes.txt")
    try writeTestFile(excluded); try writeTestFile(unsupported)
    let copied = try await ImportCoordinator().commit(session: original)
    let waiting = try await ImportCoordinator().cleanupImportedSources(in: copied.session)
    #expect(waiting == copied.session)
    let ready = SessionMutationCoordinator().sessionByMarkingBackupConfirmed(copied.session)
    let manager = HistoricalFailureManager(); manager.failDeleteName = raw.lastPathComponent
    await #expect(throws: (any Error).self) { try await ImportCoordinator(fileManager: manager).cleanupImportedSources(in: ready) }
    let cleaned = try await ImportCoordinator().cleanupImportedSources(in: ready)
    #expect(cleaned.mediaItems.allSatisfy { $0.lifecycleState == .sourceCleaned })
    #expect(FileManager.default.fileExists(atPath: excluded.path))
    #expect(FileManager.default.fileExists(atPath: unsupported.path))
    #expect(FileManager.default.fileExists(atPath: original.sourceFolder.path))
}

@Test func historicalCleanupRefusesChangedCopyBeforeDeletingAnySource() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root, insideArchive: true)
    let copied = try await ImportCoordinator().commit(session: original)
    let ready = SessionMutationCoordinator().sessionByMarkingBackupConfirmed(copied.session)
    let destination = try #require(ready.mediaItems.last?.destinationURL)
    try Data(repeating: 0, count: try Data(contentsOf: destination).count).write(to: destination)
    await #expect(throws: (any Error).self) { try await ImportCoordinator().cleanupImportedSources(in: ready) }
    #expect(original.mediaItems.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@Test(arguments: ["missing", "unrecorded", "alias", "canonical", "travel", "recognised"])
func historicalCleanupRefusesUnsafeBatches(_ reason: String) async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root, insideArchive: true)
    let copied = try await ImportCoordinator().commit(session: original)
    var ready = SessionMutationCoordinator().sessionByMarkingBackupConfirmed(copied.session)
    let destination = try #require(ready.mediaItems.last?.destinationURL)
    switch reason {
    case "missing": try FileManager.default.removeItem(at: destination)
    case "unrecorded": try FileManager.default.removeItem(at: ArchiveOperationRecovery(archiveRoot: original.archiveRoot).url(kind: "import", sessionID: original.id))
    case "alias":
        let source = try #require(ready.mediaItems.last?.sourceURL)
        try FileManager.default.removeItem(at: source)
        try FileManager.default.linkItem(at: destination, to: source)
    case "canonical":
        let folder = original.sourceFolder.appendingPathComponent("Canonical")
        try writeTestFile(folder.appendingPathComponent("Canonical.md"), contents: "- Session ID: `\(UUID())`\n")
    case "travel": ready.archiveMachineRole = .travel
    case "recognised": ready.mediaItems[0].recognisedArchiveCopy = true
    default: break
    }
    if reason == "travel" {
        #expect(try await ImportCoordinator().cleanupImportedSources(in: ready) == ready)
    } else {
        await #expect(throws: (any Error).self) { try await ImportCoordinator().cleanupImportedSources(in: ready) }
    }
    #expect(original.mediaItems.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@Test(arguments: [false, true])
func historicalReviewedTripTargetsOverrideTheFolderSuggestion(_ useExisting: Bool) async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var original = try historicalSession(root: root, count: 1)
    var walks = WalkBoundaryProposalService().proposedWalks(for: original)
    walks[0].tripTarget = useExisting ? TripTarget(kind: .existingNamedTrip, title: "Prior holiday", folderRelativePath: "2013/06-June-Prior-holiday") : .defaultMonth
    original.proposedWalks = walks
    let result = try await ImportCoordinator().commit(session: original)
    #expect(result.walkManifest.archiveFolder.deletingLastPathComponent().lastPathComponent == (useExisting ? "06-June-Prior-holiday" : "06-June"))
    #expect(original.mediaItems.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@MainActor @Test func historicalPendingCopyStaysLockedWhileArchiveIsDisconnectedAndAfterReopening() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    let original = try historicalSession(root: root)
    let store = InMemorySessionStore(), manager = HistoricalFailureManager()
    manager.failCopyName = "IMG_0002.jpg"
    let settings = makeTestSettings(root: root)
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingImportCoordinator: ImportCoordinator(fileManager: manager), testingSessionStore: store)
    state.loadSourceWorkspace(folder: original.sourceFolder, origin: .historicalFolder)
    try await historicalWait { state.currentSession != nil }
    state.focusReviewSurface(); state.commitImport(); state.confirmWalkCommit()
    try await historicalWait { state.importOperation.phase == .failed }
    let saved = try #require(state.currentSession)
    let disconnected = root.appendingPathComponent("disconnected")
    try FileManager.default.moveItem(at: original.archiveRoot, to: disconnected)
    state.updateWalkMetadata(title: "Must not change", location: "", notes: "")
    #expect(state.currentSession == saved)
    let reopened = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support-2"), testingSessionStore: store)
    reopened.openSavedWalk(saved.id)
    #expect(!reopened.canMutateImportSelection)
    reopened.updateWalkMetadata(title: "Must not change", location: "", notes: "")
    #expect(reopened.currentSession == saved)
    reopened.commitImport(); #expect(reopened.activeWalkCommitEditor == nil)
    try FileManager.default.moveItem(at: disconnected, to: original.archiveRoot)
    reopened.commitImport(); #expect(reopened.activeWalkCommitEditor?.isRecoveryPlan == true)
    reopened.confirmWalkCommit()
    try await historicalWait { reopened.importOperation.phase == .completed }
    #expect(historicalPhotos(original.archiveRoot).count == 2)
}

@MainActor @Test func historicalSlowSourceAdditionCannotRaceCopyOrOverwriteNewerMetadata() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var original = try historicalSession(root: root, count: 1); original.sessionKind = .walkDraft
    let second = root.appendingPathComponent("second")
    try writeTestFile(second.appendingPathComponent("new.jpg"), contents: "new photo")
    let state = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support"))
    state.currentSession = original
    state.testingSourceScanHandler = { folder, settings in
        try await Task.sleep(for: .milliseconds(100))
        return try SessionManager(scanner: FileScanner(), groupingService: GroupingService()).openSession(for: folder, settings: settings)
    }
    state.addSourceFolderToCurrentTriage(second)
    try await historicalWait { if case .loading = state.sourceWorkspaceState { return true }; return false }
    #expect(!state.canCommitImport)
    state.commitImport(); #expect(state.activeWalkCommitEditor == nil)
    state.updateWalkMetadata(title: "Newer title", location: "Newer place", notes: "Newer notes")
    try await historicalWait { state.currentSession?.mediaItems.count == 2 }
    #expect(state.currentSession?.walkMetadata.title == "Newer title")
    #expect(state.currentSession?.walkMetadata.notes == "Newer notes")
    #expect(state.canCommitImport)
}

@MainActor @Test func historicalCopyCancelsAnAdditionThatHasNotStartedScanning() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var original = try historicalSession(root: root, count: 1); original.sessionKind = .walkDraft
    let second = root.appendingPathComponent("second")
    try writeTestFile(second.appendingPathComponent("new.jpg"), contents: "new photo")
    let state = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support"))
    state.currentSession = original
    state.addSourceFolderToCurrentTriage(second)
    state.commitImport()
    #expect(state.activeWalkCommitEditor != nil)
    try await Task.sleep(for: .milliseconds(100))
    #expect(state.currentSession?.mediaItems.count == 1)
    #expect(state.canCommitImport)
    state.addSourceFolderToCurrentTriage(second)
    #expect(state.currentSession?.mediaItems.count == 1)
}

@MainActor @Test func historicalConfirmedPlanBeforeJournalSurvivesCancelAndReopen() async throws {
    let root = try historicalRoot(); defer { try? FileManager.default.removeItem(at: root) }
    var original = try historicalSession(root: root, count: 1); original.sessionKind = .walkDraft
    original.proposedWalks = WalkBoundaryProposalService().proposedWalks(for: original)
    original.proposedWalks[0].title = "Already confirmed title"
    original.proposedWalks[0].tripTarget = TripTarget(kind: .newNamedTrip, title: "Already confirmed Trip", folderRelativePath: nil)
    original.confirmedCopyPending = true
    try AppDirectories.ensureExists(original.archiveRoot)
    let store = InMemorySessionStore(); try store.save(session: original, bursts: [], clusters: [])
    let state = AppState(testing: true, testingSettings: makeTestSettings(root: root), testingSupportRoot: root.appendingPathComponent("support"), testingSessionStore: store)
    state.openSavedWalk(original.id); state.commitImport()
    #expect(state.activeWalkCommitEditor?.isRecoveryPlan == true)
    state.dismissWalkCommitEditor()
    #expect(state.currentSession?.proposedWalks == original.proposedWalks)
    state.commitImport()
    #expect(state.activeWalkCommitEditor?.walks == original.proposedWalks)
    state.confirmWalkCommit()
    try await historicalWait { state.importOperation.phase == .completed }
    #expect(state.currentSession?.mediaItems.first?.destinationURL?.path.contains("Already-confirmed-trip") == true)
}
