import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
private func workflowSession(_ f: LocalSurfaceFixture, name: String, verified: Bool = false) throws -> ImportSession {
    let source = f.root.appendingPathComponent("source/" + name, isDirectory: true)
    try writeTestFile(source.appendingPathComponent("photo.jpg"), contents: "fixture-photo-" + name)
    var item = makeTestMediaItem(sourceRoot: source, fileName: "photo.jpg", capturedAt: Date(timeIntervalSince1970: 1_779_532_200),
        selectionState: .included, lifecycleState: verified ? .verified : .selectedForImport)
    if verified {
        let destination = f.root.appendingPathComponent("copied/" + name + "/photo.jpg")
        try writeTestFile(destination, contents: "fixture-photo-" + name); item.destinationURL = destination
    }
    return makeTestSession(sourceRoot: source, archiveRoot: f.root, items: [item], title: name)
}

@MainActor
private func workflowSurface(_ f: LocalSurfaceFixture) -> (CommandLocalSurfaceView, LocalCommandHandle) {
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    f.window.contentView!.addSubview(surface)
    let handle = surface.configure(coordinator: f.state.commandCoordinator, scope: .sessionWorkflow,
        contextKey: sessionWorkflowSurfaceContextKey(f.state), actions: sessionWorkflowCommandActions(f.state))
    return (surface, handle)
}

@MainActor @Test func retainedWorkflowCopyDoesNotFollowAnotherLogOrAnABARoundTripBeforeRedraw() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A"), b = try workflowSession(f, name: "B")
    f.state.currentSession = a; f.state.setWorkspaceMode(.cameraTriage)
    let (surface, old) = workflowSurface(f)
    #expect(old.isEnabled(.copyIncluded))
    f.state.currentSession = b
    old.run(.copyIncluded)
    #expect(f.state.presentationState.snapshot.activeWalkCommitEditor == nil)
    #expect(f.state.currentSession?.id == b.id)
    f.state.activeWalkCommitEditor = nil; f.state.currentSession = a
    old.run(.copyIncluded)
    #expect(f.state.presentationState.snapshot.activeWalkCommitEditor == nil)
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .sessionWorkflow,
        contextKey: sessionWorkflowSurfaceContextKey(f.state), actions: sessionWorkflowCommandActions(f.state))
    fresh.run(.copyIncluded)
    let plan = try #require(f.state.presentationState.snapshot.activeWalkCommitEditor)
    #expect(plan.walks.flatMap(\.mediaItemIDs) == a.mediaItems.map(\.id))
    #expect(!f.window.isVisible)
}

@MainActor @Test func retainedWorkflowBackupDoesNotConfirmAReplacementWithTheSameLogID() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A", verified: true)
    f.state.currentSession = a
    let (surface, old) = workflowSurface(f)
    #expect(old.isEnabled(.confirmBackup))
    var changed = a; changed.walkMetadata.title = "Changed after review"
    f.state.currentSession = changed
    old.run(.confirmBackup)
    #expect(f.state.currentSession?.walkMetadata.backupConfirmedAt == nil)
    f.state.currentSession = changed
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .sessionWorkflow,
        contextKey: sessionWorkflowSurfaceContextKey(f.state), actions: sessionWorkflowCommandActions(f.state))
    fresh.run(.confirmBackup)
    #expect(f.state.currentSession?.walkMetadata.backupConfirmedAt != nil)
    #expect(f.state.currentSession?.walkMetadata.title == "Changed after review")
}

@MainActor @Test func workflowButtonsRecheckLiveCopyOperationEligibilityBeforeRedraw() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A", verified: true)
    f.state.currentSession = a
    let (_, old) = workflowSurface(f)
    #expect(old.isEnabled(.confirmBackup))
    f.state.importOperation = ImportOperationSnapshot(phase: .copying, title: "Copying", detail: "Fixture operation", progress: nil, destinationPath: nil)
    old.run(.confirmBackup)
    #expect(f.state.currentSession?.walkMetadata.backupConfirmedAt == nil)
    #expect(f.state.currentSession?.mediaItems.first?.lifecycleState == .verified)
}

@MainActor @Test func workflowActionsRejectArchiveAuthorityRoundTripsEvenBeforeRemount() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A", verified: true)
    f.state.currentSession = a
    let actions = sessionWorkflowCommandActions(f.state)
    let settings = f.state.settings
    f.state.settings.archiveRoot = f.root.appendingPathComponent("other-archive")
    f.state.settings = settings
    actions[.confirmBackup]?.run()
    #expect(f.state.currentSession?.walkMetadata.backupConfirmedAt == nil)
}


@MainActor @Test func workflowTextEditingAndCompareOverlayCannotBorrowCopyOrBackupShortcuts() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A", verified: true); f.state.currentSession = a
    let (surface, commands) = workflowSurface(f)
    let field = NSTextField(string: "Do not triage these letters"); field.frame = NSRect(x: 10, y: 10, width: 250, height: 28)
    surface.addSubview(field); field.selectText(nil)
    let editor = try #require(field.currentEditor() as? NSTextView)
    editor.setSelectedRange(NSRange(location: 4, length: 3))
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == .editor)
    #expect(!f.window.performKeyEquivalent(with: f.event("b", modifiers: [.command, .shift])))
    #expect(!f.window.performKeyEquivalent(with: f.event("a", modifiers: [.command])))
    #expect(!f.window.performKeyEquivalent(with: f.event("c", modifiers: [.command])))
    #expect(editor.selectedRange() == NSRange(location: 4, length: 3))
    let overlay = ReviewKeyResponderView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)); f.window.contentView!.addSubview(overlay)
    overlay.configureCommands(coordinator: f.state.commandCoordinator, scope: .compare, focused: true)
    commands.run(.confirmBackup)
    #expect(f.state.currentSession?.walkMetadata.backupConfirmedAt == nil)
    #expect(!f.state.commandCoordinator.executeWindowControl(.copyIncluded, in: f.window))
    #expect(!f.state.commandCoordinator.executeWindowControl(.openFocusedPhoto, in: f.window))
    overlay.removeFromSuperview()
    commands.run(.confirmBackup)
    #expect(f.state.currentSession?.walkMetadata.backupConfirmedAt != nil)
    #expect(editor.string == "Do not triage these letters")
}

@MainActor @Test func actualSidebarAndInspectorWorkflowControlsOwnTheirKeyboardCopyRoute() throws {
    for inspector in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        let a = try workflowSession(f, name: inspector ? "Inspector" : "Sidebar")
        f.state.currentSession = a; f.state.setWorkspaceMode(.cameraTriage)
        let root: AnyView = inspector
            ? AnyView(InspectorWorkflowActions(appState: f.state, readiness: f.state.sidebarState.snapshot.importReadiness))
            : AnyView(ActionButtonsPaneView(appState: f.state))
        let host = NSHostingView(rootView: root); host.frame = f.window.contentView!.bounds
        f.window.contentView!.addSubview(host); host.layoutSubtreeIfNeeded()
        func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
            ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(surfaces)
        }
        let mounted = surfaces(host); #expect(mounted.count == 1)
        let surface = try #require(mounted.first); f.window.makeFirstResponder(surface)
        let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
        #expect(origin.scope == .sessionWorkflow)
        #expect(f.state.commandCoordinator.unavailableReason(.copyIncluded, invocation: origin) == nil)
        #expect(f.window.performKeyEquivalent(with: f.event("m", modifiers: [.command, .shift])))
        let editor = try #require(f.state.presentationState.snapshot.activeWalkCommitEditor)
        #expect(editor.walks.flatMap(\.mediaItemIDs) == a.mediaItems.map(\.id))
        #expect(!f.window.isVisible)
        host.removeFromSuperview()
    }
}

@MainActor @Test func focusedPhotoToolbarCommandPreservesPhotoTargetWhileNavigationOwnsFolders() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A"); f.state.currentSession = a; f.state.setWorkspaceMode(.cameraTriage)
    let photo = try #require(a.mediaItems.first)
    f.state.focusedReviewItemID = photo.id; f.state.activePane = .sidebar
    #expect(f.state.commandCoordinator.executeWindowControl(.openFocusedPhoto, in: f.window))
    #expect(f.state.previewingMediaItemID == photo.id)
    #expect(f.state.workspaceMode == .cameraTriage)
    #expect(AppCommandRegistry.definition(.openFocusedPhoto).defaults.isEmpty)
    #expect(AppCommandRegistry.definition(.open).defaults.contains { $0.shortcut == AppShortcut(key: "return", modifiers: [.command]) })
    f.state.previewingMediaItemID = nil; f.state.focusedReviewItemID = nil
    #expect(!f.state.commandCoordinator.executeWindowControl(.openFocusedPhoto, in: f.window))
    #expect(f.state.previewingMediaItemID == nil)
}

@MainActor @Test func cleanupControlRetainsOriginalsWithCropsAndAllowsOnlyRemovableCandidates() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    var a = try workflowSession(f, name: "A", verified: true)
    a.walkMetadata.backupConfirmedAt = Date(); a.mediaItems[0].lifecycleState = .sourceCleanupPending
    a.mediaItems[0].cropRelationship = CropRelationship(role: .original, originalRelativePath: "photo.jpg", originalFileName: "photo.jpg",
        cropRelativePaths: ["photo-crop.jpg"], cropFileNames: ["photo-crop.jpg"], manifestRelativePath: nil,
        latestCropRelativePath: "photo-crop.jpg", latestCropFileName: "photo-crop.jpg")
    f.state.currentSession = a
    #expect(!f.state.canCleanupImportedSources)
    #expect(sessionWorkflowCommandActions(f.state)[.cleanupSource]?.enabled == false)
    a.mediaItems[0].cropRelationship = nil; f.state.currentSession = a
    #expect(f.state.canCleanupImportedSources)
    #expect(sessionWorkflowCommandActions(f.state)[.cleanupSource]?.enabled == true)
}

private actor WorkflowCleanupBarrier: ImportCoordinating {
    private var continuation: CheckedContinuation<ImportSession, Never>?
    private var session: ImportSession?
    func commit(session: ImportSession, progress: (@Sendable (ImportProgress) async -> Void)?) async throws -> ImportResult { throw CocoaError(.userCancelled) }
    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession {
        self.session = session
        return await withCheckedContinuation { continuation = $0 }
    }
    func entered() -> Bool { continuation != nil }
    func finish() { if let session { continuation?.resume(returning: session) }; continuation = nil }
}

@MainActor @Test func cleanupControlDisablesDuringAnAlreadyRunningCleanupThenRecovers() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let cleanup = WorkflowCleanupBarrier()
    let state = AppState(testing: true, testingSettings: f.state.settings, testingSupportRoot: f.root, testingImportCoordinator: cleanup)
    var a = try workflowSession(f, name: "A", verified: true)
    a.walkMetadata.backupConfirmedAt = Date(); a.mediaItems[0].lifecycleState = .sourceCleanupPending
    state.currentSession = a
    #expect(state.canCleanupImportedSources)
    state.startConfirmedSourceCleanup(a)
    for _ in 0..<100 { if await cleanup.entered() { break }; await Task.yield() }
    let entered = await cleanup.entered()
    #expect(entered)
    #expect(!state.canCleanupImportedSources)
    #expect(sessionWorkflowCommandActions(state)[.cleanupSource]?.enabled == false)
    await cleanup.finish()
    for _ in 0..<100 { await Task.yield() }
    #expect(state.canCleanupImportedSources)
}


@MainActor @Test func reviewToolbarDeselectClearsPhotosRegardlessOfSidebarOrFolderFocus() throws {
    for pane in [ActivePane.sidebar, .folders] {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        let a = try workflowSession(f, name: "A"); f.state.currentSession = a; f.state.setWorkspaceMode(.cameraTriage)
        let photo = try #require(a.mediaItems.first)
        f.state.selectedMediaItemIDs = [photo.id]; f.state.focusedReviewItemID = photo.id
        f.state.selectedFolderNodeIDs = ["selected-folder"]; f.state.activePane = pane
        #expect(f.state.commandCoordinator.executeWindowControl(.deselectReviewPhotos, in: f.window))
        #expect(f.state.selectedMediaItemIDs.isEmpty)
        #expect(f.state.selectedFolderNodeIDs == ["selected-folder"])
    }
}

@MainActor @Test func workflowControlsRetainTheirHorizontalAndCompactVerticalArrangement() async throws {
    for compact in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        f.state.currentSession = try workflowSession(f, name: "Layout"); f.state.setWorkspaceMode(.cameraTriage)
        f.window.setContentSize(NSSize(width: 1100, height: 420))
        let host = NSHostingView(rootView: ActionButtonsPaneView(appState: f.state, compact: compact))
        host.frame = f.window.contentView!.bounds; f.window.contentView!.addSubview(host)
        for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(10)) }
        func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
            ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(surfaces)
        }
        let surface = try #require(surfaces(host).first)
        let measured = surface.measure(width: compact ? 280 : 1000)
        if compact {
            #expect(measured.height > 100)
            #expect(measured.height < 220)
        } else {
            #expect(measured.height > 15)
            #expect(measured.height < 45)
        }
        #expect(!f.window.isVisible); host.removeFromSuperview()
    }
}

@MainActor @Test func retainedInboxNewLogDoesNotFollowFolderChangesOrAnABARoundTrip() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = try workflowSession(f, name: "A"), b = try workflowSession(f, name: "B")
    var first = a.mediaItems[0], second = b.mediaItems[0]
    first.relativePath = "A/photo.jpg"; second.relativePath = "B/photo.jpg"
    second.capturedAt = Date(timeIntervalSince1970: 1_779_618_600)
    let inbox = makeTestSession(sourceRoot: f.root.appendingPathComponent("source"), archiveRoot: f.root,
        items: [first, second], sessionKind: .inbox)
    f.state.currentSession = inbox; f.state.setWorkspaceMode(.cameraTriage)
    let folderA = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs == [first.id] })
    let folderB = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs == [second.id] })
    f.state.activePane = .folders; f.state.selectedFolderNodeIDs = [folderA.id]
    #expect(f.state.canStartNewPhotoLogSession)
    let (surface, old) = workflowSurface(f)
    f.state.selectedFolderNodeIDs = [folderB.id]
    old.run(.newPhotoLog)
    #expect(f.state.activePhotoLogEditor == nil)
    f.state.activePhotoLogEditor = nil; f.state.selectedFolderNodeIDs = [folderA.id]
    old.run(.newPhotoLog)
    #expect(f.state.activePhotoLogEditor == nil)
    f.state.activePhotoLogEditor = nil; f.state.selectedFolderNodeIDs = [folderB.id]
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .sessionWorkflow,
        contextKey: sessionWorkflowSurfaceContextKey(f.state), actions: sessionWorkflowCommandActions(f.state))
    old.run(.newPhotoLog)
    #expect(f.state.activePhotoLogEditor == nil)
    f.state.activePhotoLogEditor = nil
    fresh.run(.newPhotoLog)
    let editor = try #require(f.state.activePhotoLogEditor)
    #expect(editor.scopeLabel == folderB.title)
    #expect(f.state.proposedPhotoLogCreationPlan(mode: .decidedInScope)?.candidateMediaItemIDs == [second.id])
}
