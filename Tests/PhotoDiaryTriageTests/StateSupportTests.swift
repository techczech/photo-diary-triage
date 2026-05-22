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

    #expect(inboxWaiting.idleDetail.contains("Open an existing photo log"))
    #expect(ready.idleDetail.contains("1 S (include) photo"))
    #expect(ready.idleDetail.contains("RAW companion"))
    #expect(ready.copyButtonHelp.contains("Copy every S"))
}

@Test func photoLogStatusPolicyLocksImportedMembershipEdits() {
    #expect(!PhotoLogStatusPolicy.isMembershipLocked(status: "draft"))
    #expect(PhotoLogStatusPolicy.isMembershipLocked(status: "imported"))
    #expect(PhotoLogStatusPolicy.isMembershipLocked(status: "source_cleaned"))
    #expect(PhotoLogStatusPolicy.membershipLockMessage(status: "imported")?.contains("Copied") == true)
}
