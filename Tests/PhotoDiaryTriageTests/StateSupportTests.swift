import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func persistedSessionNormalizerDeduplicatesInboxesAndCountsLegacySessions() {
    let root = URL(fileURLWithPath: "/tmp/persisted-normalizer", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let base = Date(timeIntervalSince1970: 50_000)

    var newestInbox = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [],
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    newestInbox.lastUpdatedAt = base.addingTimeInterval(20)

    var duplicateInbox = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [],
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    duplicateInbox.lastUpdatedAt = base
    duplicateInbox.sessionKindWasExplicit = false

    var explicitDraft = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [],
        workspaceSourceFolder: root,
        sessionKind: .walkDraft
    )
    explicitDraft.lastUpdatedAt = base.addingTimeInterval(10)

    let normalized = PersistedSessionNormalizer().normalize([
        (duplicateInbox, [], []),
        (explicitDraft, [], []),
        (newestInbox, [], [])
    ])

    #expect(normalized.records.count == 2)
    #expect(normalized.deduplicatedInboxCount == 1)
    #expect(normalized.legacyRecoveredSessionCount == 1)
    #expect(normalized.records[0].0.id == newestInbox.id)
    #expect(normalized.records.contains(where: { $0.0.id == explicitDraft.id }))
}

@Test func sourceWorkspaceFolderResolverPrefersDCIMWhenPresent() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let selectedFolder = root.appendingPathComponent("EOS_DIGITAL", isDirectory: true)
    let dcimFolder = selectedFolder.appendingPathComponent("DCIM", isDirectory: true)
    try FileManager.default.createDirectory(at: dcimFolder, withIntermediateDirectories: true)

    let resolved = SourceWorkspaceFolderResolver(fileManager: .default).resolve(selectedFolder: selectedFolder)

    #expect(resolved.standardizedFileURL.path == dcimFolder.standardizedFileURL.path)
}

@Test func sourceWorkspaceFolderResolverLeavesFolderUnchangedWhenDCIMMissing() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let selectedFolder = root.appendingPathComponent("EOS_DIGITAL", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedFolder, withIntermediateDirectories: true)

    let resolved = SourceWorkspaceFolderResolver(fileManager: .default).resolve(selectedFolder: selectedFolder)

    #expect(resolved.standardizedFileURL.path == selectedFolder.standardizedFileURL.path)
}

@MainActor
@Test func appStateDefaultsToArchiveViewMode() {
    let state = AppState(testing: true)

    #expect(state.workspaceMode == .archiveView)
    #expect(state.browserRoots.map(\.id) == ["section-archive-library"])
    #expect(state.selectedSidebarNodeID == "archive-root")
    #expect(!state.canMutateImportSelection)
}

@MainActor
@Test func workspaceModeSeparatesArchiveAndCameraBrowserRoots() {
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/workspace-mode-state", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let item = makeTestMediaItem(
        sourceRoot: root,
        fileName: "IMG_0001.jpg",
        capturedAt: Date(timeIntervalSince1970: 90_000),
        selectionState: .included
    )
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: archiveRoot, items: [item])

    #expect(state.workspaceMode == .archiveView)
    #expect(state.browserRoots.map(\.id) == ["section-archive-library"])
    #expect(!state.canMutateImportSelection)

    state.setWorkspaceMode(.cameraTriage)

    #expect(state.browserRoots.map(\.id) == ["section-current-session"])
    #expect(state.selectedSidebarNodeID != "archive-root")
    #expect(state.canMutateImportSelection)

    state.setWorkspaceMode(.archiveTriage)

    #expect(state.browserRoots.map(\.id) == ["section-archive-library"])
    #expect(state.selectedSidebarNodeID == "archive-root")
    #expect(!state.canMutateImportSelection)
}

@Test func archiveBrowserTreeIsReusedUntilInvalidated() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let month = root
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05 - May", isDirectory: true)
    try AppDirectories.ensureExists(month.appendingPathComponent("Walk A", isDirectory: true))

    let viewModel = BrowserViewModel(scanner: FileScanner())
    let firstRoots = viewModel.browserRoots(
        currentSession: nil,
        bursts: [],
        clusters: [],
        archiveRoot: root,
        sourceWorkspaceState: .idle,
        workspaceMode: .archiveView
    )

    try AppDirectories.ensureExists(month.appendingPathComponent("Walk B", isDirectory: true))
    let cachedRoots = viewModel.browserRoots(
        currentSession: nil,
        bursts: [],
        clusters: [],
        archiveRoot: root,
        sourceWorkspaceState: .idle,
        workspaceMode: .archiveView
    )

    viewModel.invalidateArchiveTreeCache()
    let refreshedRoots = viewModel.browserRoots(
        currentSession: nil,
        bursts: [],
        clusters: [],
        archiveRoot: root,
        sourceWorkspaceState: .idle,
        workspaceMode: .archiveView
    )

    #expect(archiveWalkCount(in: firstRoots) == 1)
    #expect(archiveWalkCount(in: cachedRoots) == 1)
    #expect(archiveWalkCount(in: refreshedRoots) == 2)
}

@Test func sessionBrowserDateNodesUseReadableMonthAndWeekdayLabels() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    let capturedAt = try #require(calendar.date(from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: 2024,
        month: 5,
        day: 8,
        hour: 12
    )))
    let item = makeTestMediaItem(
        sourceRoot: root,
        fileName: "IMG_0001.jpg",
        capturedAt: capturedAt
    )
    let session = makeTestSession(sourceRoot: root, archiveRoot: archiveRoot, items: [item])

    let roots = BrowserViewModel(scanner: FileScanner()).browserRoots(
        currentSession: session,
        bursts: [],
        clusters: [],
        archiveRoot: archiveRoot,
        sourceWorkspaceState: .loaded(itemCount: 1, sourcePath: root.path),
        workspaceMode: .cameraTriage
    )

    let section = try #require(roots.first)
    let sessionRoot = try #require(section.children?.first)
    let yearNode = try #require(sessionRoot.children?.first)
    let monthNode = try #require(yearNode.children?.first)
    let dayNode = try #require(monthNode.children?.first)

    #expect(yearNode.title == "2024")
    #expect(monthNode.title == "05 - May")
    #expect(dayNode.title == "08 - Wed")
}

@Test func archiveBrowserMonthFolderEnrichesNumericMonthTitle() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let month = root
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05", isDirectory: true)
    try AppDirectories.ensureExists(month.appendingPathComponent("Walk A", isDirectory: true))

    let roots = BrowserViewModel(scanner: FileScanner()).browserRoots(
        currentSession: nil,
        bursts: [],
        clusters: [],
        archiveRoot: root,
        sourceWorkspaceState: .idle,
        workspaceMode: .archiveView
    )

    let section = try #require(roots.first)
    let archiveRoot = try #require(section.children?.first)
    let yearNode = try #require(archiveRoot.children?.first)
    let monthNode = try #require(yearNode.children?.first)

    #expect(monthNode.title == "05 - May")
    #expect(monthNode.folderURL?.lastPathComponent == "05")
}

@Test func archiveMediaLoadUsesFastFileAttributeScan() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let walk = root
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05 - May", isDirectory: true)
        .appendingPathComponent("Tiny Walk", isDirectory: true)
    let imageURL = walk.appendingPathComponent("IMG_0001.jpg")
    try writeTestFile(imageURL, contents: "not real image data")
    let modifiedAt = Date(timeIntervalSince1970: 1_779_532_200)
    try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: imageURL.path)

    let node = BrowserNode(
        id: "archive-walk-\(walk.path)",
        title: "Tiny Walk",
        subtitle: walk.path,
        kind: .archiveWalkFolder,
        parentID: nil,
        mediaItemIDs: [],
        children: nil,
        folderURL: walk
    )

    let maybeResult = try BrowserViewModel(scanner: FileScanner()).loadArchiveMedia(for: node, settings: makeTestSettings(root: root))
    let result = try #require(maybeResult)
    let item = try #require(result.items.first)

    #expect(result.items.count == 1)
    #expect(item.capturedAt?.timeIntervalSince1970 == modifiedAt.timeIntervalSince1970)
    #expect(item.metadata.pixelWidth == nil)
    #expect(item.metadata.raw.isEmpty)
}

@Test func archiveMediaLoadReusesFileManifestIdentityAndThumbnailKey() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let walk = root
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05 - May", isDirectory: true)
        .appendingPathComponent("Manifest Walk", isDirectory: true)
    let imageURL = walk.appendingPathComponent("IMG_0002.jpg")
    let sidecarURL = walk.appendingPathComponent("IMG_0002.md")
    try writeTestFile(imageURL, contents: "not real image data")
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000)], ofItemAtPath: imageURL.path)

    let mediaItemID = UUID()
    let capturedAt = Date(timeIntervalSince1970: 1_779_600_000)
    let sidecar = """
    ---
    media_item_id: \(mediaItemID.uuidString)
    archive_path: \(imageURL.path)
    archive_relative_path: "2026/05 - May/Manifest Walk/IMG_0002.jpg"
    thumbnail_cache_key: "source-thumbnail-cache-key"
    source_file_name: IMG_0002.jpg
    captured_at: \(DateFormatting.iso8601.string(from: capturedAt))
    camera_model: "Canon Test"
    lens_model: "RF Test"
    pixel_width: 6000
    pixel_height: 4000
    latitude: 51.75
    longitude: -1.25
    walk_title: "Manifest Walk"
    walk_location: "Oxford"
    ---
    """
    try sidecar.write(to: sidecarURL, atomically: true, encoding: .utf8)

    let node = BrowserNode(
        id: "archive-walk-\(walk.path)",
        title: "Manifest Walk",
        subtitle: walk.path,
        kind: .archiveWalkFolder,
        parentID: nil,
        mediaItemIDs: [],
        children: nil,
        folderURL: walk
    )

    let maybeResult = try BrowserViewModel(scanner: FileScanner()).loadArchiveMedia(for: node, settings: makeTestSettings(root: root))
    let item = try #require(maybeResult?.items.first)

    #expect(item.id == mediaItemID)
    #expect(item.thumbnailCacheKey == "source-thumbnail-cache-key")
    #expect(item.capturedAt == capturedAt)
    #expect(item.metadata.cameraModel == "Canon Test")
    #expect(item.metadata.lensModel == "RF Test")
    #expect(item.metadata.pixelWidth == 6000)
    #expect(item.metadata.pixelHeight == 4000)
    #expect(item.metadata.latitude == 51.75)
    #expect(item.metadata.longitude == -1.25)
    #expect(item.destinationURL?.standardizedFileURL.path == imageURL.standardizedFileURL.path)
    #expect(item.archiveRelativePath == "2026/05 - May/Manifest Walk/IMG_0002.jpg")
}

@Test func thumbnailCacheKeyResolverReusesKnownImportedDestinationKeys() {
    let root = URL(fileURLWithPath: "/tmp/thumb-key-resolver", isDirectory: true)
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let archiveURL = archiveRoot
        .appendingPathComponent("2026/05 - May/Walk", isDirectory: true)
        .appendingPathComponent("Walk-001.jpg")
    var importedItem = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0003.jpg",
        capturedAt: Date(timeIntervalSince1970: 1_779_700_000)
    )
    importedItem.thumbnailCacheKey = "source-cache-key"
    importedItem.destinationURL = archiveURL
    importedItem.archiveRelativePath = "2026/05 - May/Walk/Walk-001.jpg"
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [importedItem])
    let archiveItem = MediaItem(
        sourceURL: archiveURL,
        relativePath: "Walk-001.jpg",
        fileName: "Walk-001.jpg",
        baseName: "Walk-001",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: importedItem.capturedAt,
        metadata: importedItem.metadata,
        thumbnailCacheKey: "archive-path-cache-key",
        destinationURL: archiveURL,
        archiveRelativePath: importedItem.archiveRelativePath
    )

    let resolved = ThumbnailCacheKeyResolver().applyingKnownKeys(to: [archiveItem], knownSessions: [session])

    #expect(resolved.first?.thumbnailCacheKey == "source-cache-key")
}

@Test func photoLogCreationResolverFindsCollisionsOnlyInSameWorkspace() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let otherRoot = root.appendingPathComponent("other-source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let base = Date(timeIntervalSince1970: 80_000)
    for name in ["0.jpg", "1.jpg"] {
        try writeTestFile(sourceRoot.appendingPathComponent(name), contents: name)
        try writeTestFile(otherRoot.appendingPathComponent(name), contents: name)
    }
    let items = ["0.jpg", "1.jpg"].enumerated().map { index, name in
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: name,
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: .included
        )
    }
    let current = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: items,
        workspaceSourceFolder: sourceRoot,
        sessionKind: .inbox
    )
    let sameWorkspaceOwner = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: [items[0]],
        title: "Existing Same Source",
        workspaceSourceFolder: sourceRoot,
        sessionKind: .walkDraft
    )
    let otherWorkspaceItem = makeTestMediaItem(
        sourceRoot: otherRoot,
        fileName: "1.jpg",
        capturedAt: base,
        selectionState: .included
    )
    let otherWorkspaceOwner = makeTestSession(
        sourceRoot: otherRoot,
        archiveRoot: archiveRoot,
        items: [otherWorkspaceItem],
        title: "Existing Other Source",
        workspaceSourceFolder: otherRoot,
        sessionKind: .walkDraft
    )

    let plan = PhotoLogCreationResolver().resolve(
        currentSession: current,
        activePane: .media,
        selectedFolderNodeIDs: [],
        selectedBrowserNode: nil,
        browserNodeMap: [:],
        visibleItems: items,
        selectedMediaItemIDs: [],
        existingPhotoLogs: [sameWorkspaceOwner, otherWorkspaceOwner],
        mode: .decidedInScope
    )

    let resolved = try #require(plan)
    #expect(resolved.collisions.map(\.relativePath) == ["0.jpg"])
    #expect(resolved.collisions.first?.owningTitle == "Existing Same Source")
    #expect(resolved.disabledReason == "Some photos in this plan already belong to another photo log.")
}

private func archiveWalkCount(in nodes: [BrowserNode]) -> Int {
    nodes.reduce(0) { count, node in
        count + (node.kind == .archiveWalkFolder ? 1 : 0) + archiveWalkCount(in: node.children ?? [])
    }
}

@Test func copyReadinessGuidesPhotoLogContinuationWhenNoIncludedFilesExist() {
    let readiness = ImportReadinessSnapshot(
        sessionKind: .walkDraft,
        includedItems: 0,
        candidateItems: 2,
        excludedItems: 1,
        undecidedItems: 3,
        rawCompanionFiles: 0,
        totalFiles: 0,
        destinationPath: nil,
        verifiedAwaitingBackupItems: 0,
        cleanupPendingItems: 0,
        backupConfirmed: false,
        cleanupRequiresBackupConfirmation: true
    )

    #expect(readiness.idleDetail.contains("C/X choices"))
    #expect(readiness.idleDetail.contains("S (include)"))
    #expect(readiness.copyButtonHelp.contains("Continue this photo log"))
}

@Test func copyReadinessExplainsInboxAndReadyStates() {
    let inboxWaiting = ImportReadinessSnapshot(
        sessionKind: .inbox,
        includedItems: 0,
        candidateItems: 0,
        excludedItems: 0,
        undecidedItems: 5,
        rawCompanionFiles: 0,
        totalFiles: 0,
        destinationPath: nil,
        verifiedAwaitingBackupItems: 0,
        cleanupPendingItems: 0,
        backupConfirmed: false,
        cleanupRequiresBackupConfirmation: true
    )
    let ready = ImportReadinessSnapshot(
        sessionKind: .walkDraft,
        includedItems: 1,
        candidateItems: 0,
        excludedItems: 0,
        undecidedItems: 0,
        rawCompanionFiles: 1,
        totalFiles: 2,
        destinationPath: "/archive/photo-log",
        verifiedAwaitingBackupItems: 0,
        cleanupPendingItems: 0,
        backupConfirmed: false,
        cleanupRequiresBackupConfirmation: true
    )
    let inboxReady = ImportReadinessSnapshot(
        sessionKind: .inbox,
        includedItems: 1,
        candidateItems: 0,
        excludedItems: 1,
        undecidedItems: 0,
        rawCompanionFiles: 0,
        totalFiles: 1,
        destinationPath: "/archive/dated-log",
        verifiedAwaitingBackupItems: 0,
        cleanupPendingItems: 0,
        backupConfirmed: false,
        cleanupRequiresBackupConfirmation: true
    )

    #expect(inboxWaiting.idleDetail.contains("Open an existing photo log"))
    #expect(ready.idleDetail.contains("1 S (include) photo"))
    #expect(ready.idleDetail.contains("RAW companion"))
    #expect(ready.copyButtonHelp.contains("Copy every S"))
    #expect(inboxReady.idleDetail.contains("dated photo log"))
    #expect(inboxReady.copyButtonHelp.contains("Create a dated photo log"))
}

@Test func photoLogStatusPolicyLocksImportedMembershipEdits() {
    #expect(!PhotoLogStatusPolicy.isMembershipLocked(status: "draft"))
    #expect(PhotoLogStatusPolicy.isMembershipLocked(status: "imported"))
    #expect(PhotoLogStatusPolicy.isMembershipLocked(status: "source_cleaned"))
    #expect(PhotoLogStatusPolicy.membershipLockMessage(status: "imported")?.contains("Copied") == true)
    #expect(PhotoLogStatusPolicy.editLogActionTitle == "Edit Log")
    #expect(PhotoLogStatusPolicy.editLogHelp.contains("Add or remove photos"))
    #expect(PhotoLogStatusPolicy.editLogHelp.contains("S/C/X status"))
    #expect(PhotoLogStatusPolicy.editLogHelp.contains("add them"))
    #expect(PhotoLogStatusPolicy.detailsActionTitle == "Details")
    #expect(PhotoLogStatusPolicy.detailsHelp.contains("does not change which photos belong"))
    #expect(PhotoLogStatusPolicy.detailsSheetSubtitle.contains("Use Edit Log"))
}

@Test func workflowGuidanceShowsSourceInboxReadyToCreatePhotoLog() {
    let candidateID = UUID()
    let plan = PhotoLogCreationPlan(
        scope: PhotoLogScopeDescriptor(
            kind: .folder,
            label: "Morning walk",
            sourceFolderPaths: ["/source"],
            startDate: nil,
            endDate: nil
        ),
        mode: .decidedInScope,
        scopeMediaItemIDs: [candidateID],
        candidateMediaItemIDs: [candidateID],
        counts: PhotoLogSelectionCounts(included: 1, candidate: 0, excluded: 0, undecided: 3),
        collisions: [],
        disabledReason: nil
    )

    let guidance = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 4, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .inbox, itemCount: 4, included: 1),
        creationPlan: plan,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .inbox),
        importOperation: .idle
    )

    #expect(guidance.title == "Source Inbox Ready")
    #expect(guidance.state.contains("Photo log can be created"))
    #expect(guidance.nextAction.contains("Create Photo Log"))
}

@Test func workflowGuidanceShowsPhotoLogNeedsIncludedPhotosBeforeCopy() {
    let guidance = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 3, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, itemCount: 3, candidate: 2, excluded: 1),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, candidateItems: 2, excludedItems: 1),
        importOperation: .idle
    )

    #expect(guidance.title == "Photo Log In Progress")
    #expect(guidance.state.contains("No uncopied S"))
    #expect(guidance.nextAction.contains("Use Edit Log"))
    #expect(guidance.nextAction.contains("add or remove"))
}

@Test func workflowGuidanceShowsPhotoLogReadyToCopy() {
    let guidance = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, includedItems: 2, totalFiles: 2),
        importOperation: .idle
    )

    #expect(guidance.title == "Photo Log Ready To Copy")
    #expect(guidance.state.contains("2 S"))
    #expect(guidance.nextAction == "Use Copy To Archive.")

    let afterPreviousCopy = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, includedItems: 2, totalFiles: 2),
        importOperation: ImportOperationSnapshot(
            phase: .completed,
            title: "Copy complete",
            detail: "Previous copy finished.",
            progress: nil,
            destinationPath: "/archive"
        )
    )

    #expect(afterPreviousCopy.title == "Photo Log Ready To Copy")
    #expect(afterPreviousCopy.nextAction == "Use Copy To Archive.")
}

@Test func workflowGuidanceShowsCopyProgressAndFailureStates() {
    let copying = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, includedItems: 2, totalFiles: 2),
        importOperation: ImportOperationSnapshot(
            phase: .copying,
            title: "Copying to archive",
            detail: "Copied 1 of 2 file(s).",
            progress: ImportProgress(current: 1, total: 2),
            destinationPath: "/archive"
        )
    )
    let failed = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, includedItems: 2, totalFiles: 2),
        importOperation: ImportOperationSnapshot(
            phase: .failed,
            title: "Copy failed",
            detail: "Permission denied.",
            progress: nil,
            destinationPath: "/archive"
        )
    )

    #expect(copying.title == "Copying To Archive")
    #expect(copying.state == "1/2 files")
    #expect(copying.nextAction.contains("Wait"))
    #expect(failed.title == "Copy Failed")
    #expect(failed.nextAction.contains("Copy To Archive again"))
}

@Test func workflowGuidanceShowsBackupAndCleanupStates() {
    let backup = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, status: "imported", itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, verifiedAwaitingBackupItems: 2),
        importOperation: .idle
    )
    let cleanupLocked = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, status: "imported", itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, cleanupPendingItems: 2),
        importOperation: .idle
    )
    let cleanupReady = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, status: "imported", itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: false,
        importReadiness: makeWorkflowReadiness(sessionKind: .walkDraft, cleanupPendingItems: 2, backupConfirmed: true),
        importOperation: .idle
    )

    #expect(backup.state.contains("Files verified"))
    #expect(backup.nextAction.contains("Open Archive Folder"))
    #expect(backup.nextAction.contains("Confirm Backup"))
    #expect(cleanupLocked.state.contains("Waiting for backup"))
    #expect(cleanupLocked.nextAction.contains("Open Archive Folder"))
    #expect(cleanupLocked.nextAction.contains("Confirm Backup"))
    #expect(cleanupReady.state.contains("Ready for source cleanup"))
    #expect(cleanupReady.detail.contains("Backup is confirmed"))
    #expect(cleanupReady.nextAction.contains("Start New Photo Log"))
    #expect(cleanupReady.nextAction.contains("Clean Source SSD"))
}

@Test func workflowGuidanceShowsArchiveBrowsingAsReadOnly() {
    let guidance = WorkflowGuidanceResolver().resolve(
        sourceWorkspaceState: .loaded(itemCount: 2, sourcePath: "/source"),
        sessionSummary: makeWorkflowSummary(sessionKind: .walkDraft, itemCount: 2, included: 2),
        creationPlan: nil,
        isBrowsingArchive: true,
        importReadiness: nil,
        importOperation: .idle
    )

    #expect(guidance.title == "Archive Browsing")
    #expect(guidance.state.contains("Read-only"))
    #expect(guidance.nextAction.contains("source inbox"))
}

@MainActor
@Test func workspaceContextNamesSourceInboxAndActivePhotoLog() {
    let root = URL(fileURLWithPath: "/tmp/workspace-context", isDirectory: true)
    let state = AppState(testing: true)
    let item = makeTestMediaItem(
        sourceRoot: root,
        fileName: "IMG_0001.jpg",
        capturedAt: Date(timeIntervalSince1970: 10_000)
    )

    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: [item],
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    #expect(state.workspaceContextTitle == "Source Inbox Triage")
    #expect(state.workspaceModeNextAction.contains("Source inbox decisions"))

    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: [item],
        workspaceSourceFolder: root,
        sessionKind: .walkDraft
    )
    state.setWorkspaceMode(.cameraTriage)
    #expect(state.workspaceContextTitle == "Active Photo Log")
    #expect(state.workspaceModeDetail.contains("active photo log"))
    #expect(state.workspaceModeNextAction.contains("inside a photo log"))
}

private func makeWorkflowSummary(
    sessionKind: SessionKind,
    status: String = "draft",
    itemCount: Int,
    included: Int = 0,
    candidate: Int = 0,
    excluded: Int = 0
) -> SessionSummary {
    SessionSummary(
        sessionID: UUID(),
        sourceFolderPath: "/source",
        workspaceSourceFolderPath: "/source",
        itemCount: itemCount,
        includedCount: included,
        candidateCount: candidate,
        excludedCount: excluded,
        sessionKind: sessionKind,
        status: status,
        walkMetadata: .empty,
        photoLogScope: nil
    )
}

private func makeWorkflowReadiness(
    sessionKind: SessionKind,
    includedItems: Int = 0,
    candidateItems: Int = 0,
    excludedItems: Int = 0,
    undecidedItems: Int = 0,
    totalFiles: Int = 0,
    verifiedAwaitingBackupItems: Int = 0,
    cleanupPendingItems: Int = 0,
    backupConfirmed: Bool = false
) -> ImportReadinessSnapshot {
    ImportReadinessSnapshot(
        sessionKind: sessionKind,
        includedItems: includedItems,
        candidateItems: candidateItems,
        excludedItems: excludedItems,
        undecidedItems: undecidedItems,
        rawCompanionFiles: 0,
        totalFiles: totalFiles,
        destinationPath: totalFiles > 0 ? "/archive/photo-log" : nil,
        verifiedAwaitingBackupItems: verifiedAwaitingBackupItems,
        cleanupPendingItems: cleanupPendingItems,
        backupConfirmed: backupConfirmed,
        cleanupRequiresBackupConfirmation: true
    )
}
