import AppKit
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
private func sourceNavigationFolder(_ f: LocalSurfaceFixture) throws -> BrowserNode {
    let items = (0..<3).map { makeTestMediaItem(sourceRoot: f.root, fileName: "Folder-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    f.state.selectSidebarNode("section-current-session")
    #expect(f.state.visibleMediaItems.isEmpty)
    #expect(f.state.detailFolderNodes.count == 1)
    return try #require(f.state.detailFolderNodes.first)
}

@MainActor
private func sourceNavigationTable(_ view: NSView) -> NSTableView? {
    if let table = view as? NSTableView { return table }
    for child in view.subviews { if let table = sourceNavigationTable(child) { return table } }
    return nil
}

@MainActor
private func sourceNavigationMount(_ f: LocalSurfaceFixture) async throws -> NSTableView {
    let host = NSHostingView(rootView: FolderBrowserPaneView(appState: f.state, state: f.state.reviewState))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]
    f.window.contentView!.addSubview(host)
    f.window.contentView!.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(60))
    host.layoutSubtreeIfNeeded()
    return try #require(sourceNavigationTable(host))
}

@MainActor @Test func sourceNavigationRealFolderListCommandASelectsFoldersWithoutPhotoSelection() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let node = try sourceNavigationFolder(f)
    let table = try await sourceNavigationMount(f)
    #expect(f.window.makeFirstResponder(table))
    // This is the exact production local-monitor/coordinator event path, focused
    // on the native List produced by the real Current Triage route.
    #expect(f.state.commandCoordinator.handle(f.event("a", code: 0, modifiers: [.command]), in: f.window))
    #expect(f.state.selectedFolderNodeIDs == [node.id])
    try await Task.sleep(for: .milliseconds(30))
    #expect(table.selectedRowIndexes.count == 1)
    #expect(f.state.selectedMediaItemIDs.isEmpty)
    #expect(!f.window.isVisible)
}


@MainActor
private func sourceNavigationSurface(_ f: LocalSurfaceFixture, folders: Bool) -> (CommandLocalSurfaceView, LocalCommandHandle) {
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    f.window.contentView!.addSubview(surface)
    let context = folders ? f.state.reviewState.snapshot.folderCommandContextKey : f.state.sidebarState.snapshot.tree.commandContextKey
    let handle = surface.configure(coordinator: f.state.commandCoordinator, scope: folders ? .sourceFolders : .sourceSidebar,
        contextKey: context, actions: folders ? sourceFolderCommandActions(f.state, context: context) : [:])
    return (surface, handle)
}

@MainActor @Test func sourceNavigationFolderOpenUsesCurrentDisplayedSelectionAndRejectsInvalidIDs() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
    let (surface, handle) = sourceNavigationSurface(f, folders: true); f.window.makeFirstResponder(surface)
    #expect(!handle.isEnabled(.open))
    f.state.selectedFolderNodeIDs = ["missing"]
    #expect(!handle.isEnabled(.open)); handle.run(.open)
    #expect(f.state.selectedSidebarNodeID == "section-current-session")
    f.state.selectFolderNodes([node.id]); f.state.activePane = .media
    #expect(handle.isEnabled(.open))
    #expect(surface.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command])))
    #expect(f.state.selectedSidebarNodeID == node.id)
    #expect(f.state.selectedMediaItemIDs.isEmpty)
}

@MainActor @Test func sourceNavigationFolderSelectionAndDoubleClickRejectParentABARoundTrips() throws {
    for change in ["parent", "source", "tree", "root", "workspace"] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
        let (_, handle) = sourceNavigationSurface(f, folders: true)
        let context = f.state.reviewState.snapshot.folderCommandContextKey
        let binding = sourceFolderSelectionBinding(f.state, context: context, handle: handle)
        let session = try #require(f.state.currentSession)
        switch change {
        case "parent": f.state.selectSidebarNode(node.id); f.state.selectSidebarNode("section-current-session")
        case "source": f.state.currentSession = nil; f.state.currentSession = session; f.state.selectSidebarNode("section-current-session")
        case "tree": let groups = f.state.burstGroups; f.state.burstGroups = groups
        case "workspace": f.state.setWorkspaceMode(.photoLogs); f.state.setWorkspaceMode(.cameraTriage); f.state.selectSidebarNode("section-current-session")
        default: f.state.settings.archiveRoot = f.root.appendingPathComponent("other"); f.state.settings.archiveRoot = f.root
        }
        binding.wrappedValue = [node.id]
        openDisplayedSourceFolder(f.state, node: node, context: context, handle: handle)
        #expect(f.state.selectedFolderNodeIDs.isEmpty)
        #expect(f.state.selectedSidebarNodeID == "section-current-session")
        let (_, fresh) = sourceNavigationSurface(f, folders: true)
        let updated = try #require(f.state.detailFolderNodes.first)
        openDisplayedSourceFolder(f.state, node: updated, context: f.state.reviewState.snapshot.folderCommandContextKey, handle: fresh)
        #expect(f.state.selectedSidebarNodeID == node.id)
    }
}

@MainActor @Test func sourceNavigationFolderBindingAcceptsSelectionChangesAndClearingButRejectsForeignIDs() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
    let (_, handle) = sourceNavigationSurface(f, folders: true)
    let context = f.state.reviewState.snapshot.folderCommandContextKey
    let binding = sourceFolderSelectionBinding(f.state, context: context, handle: handle)
    binding.wrappedValue = [node.id]; #expect(f.state.selectedFolderNodeIDs == [node.id])
    #expect(f.state.reviewState.snapshot.selectedFolderNodeIDs == [node.id])
    #expect(f.state.reviewState.snapshot.folderCommandContextKey == context)
    binding.wrappedValue = [node.id, "foreign"]; #expect(f.state.selectedFolderNodeIDs == [node.id])
    binding.wrappedValue = []; #expect(f.state.selectedFolderNodeIDs.isEmpty)
    #expect(f.state.reviewState.snapshot.folderCommandContextKey == context)
    openDisplayedSourceFolder(f.state, node: node, context: context, handle: handle)
    #expect(f.state.selectedSidebarNodeID == node.id)
}

@MainActor @Test func sourceNavigationSidebarRowsAndBindingSurviveSelectionButRejectReplacedTrees() throws {
    for change in ["session", "tree", "workspace", "root"] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
        let (_, handle) = sourceNavigationSurface(f, folders: false)
        let context = f.state.sidebarState.snapshot.tree.commandContextKey
        let binding = sourceSidebarSelectionBinding(f.state, context: context, handle: handle)
        binding.wrappedValue = node.id; #expect(f.state.selectedSidebarNodeID == node.id)
        #expect(f.state.sidebarState.snapshot.tree.commandContextKey == context)
        selectDisplayedSourceNode(f.state, node: node, context: context, handle: handle)
        #expect(f.state.selectedSidebarNodeID == node.id)
        binding.wrappedValue = "missing"; #expect(f.state.selectedSidebarNodeID == node.id)
        let session = try #require(f.state.currentSession)
        switch change {
        case "session": f.state.currentSession = nil; f.state.currentSession = session
        case "tree": let groups = f.state.timeClusters; f.state.timeClusters = groups
        case "workspace": f.state.setWorkspaceMode(.photoLogs); f.state.setWorkspaceMode(.cameraTriage)
        default: f.state.settings.archiveRoot = f.root.appendingPathComponent("other"); f.state.settings.archiveRoot = f.root
        }
        f.state.selectSidebarNode("section-current-session")
        binding.wrappedValue = node.id
        selectDisplayedSourceNode(f.state, node: node, context: context, handle: handle)
        #expect(f.state.selectedSidebarNodeID == "section-current-session")
        let (_, fresh) = sourceNavigationSurface(f, folders: false)
        let updated = try #require(f.state.browserNodeMap[node.id])
        selectDisplayedSourceNode(f.state, node: updated, context: f.state.sidebarState.snapshot.tree.commandContextKey, handle: fresh)
        #expect(f.state.selectedSidebarNodeID == node.id)
    }
}

@MainActor @Test func sourceNavigationNativeFolderCommandIUsesFolderOwnershipAndLeavesArrowsToTheList() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
    let table = try await sourceNavigationMount(f); f.window.makeFirstResponder(table)
    #expect(f.state.commandCoordinator.handle(f.event("a", modifiers: [.command]), in: f.window))
    f.state.activePane = .media
    #expect(f.state.commandCoordinator.handle(f.event("i", modifiers: [.command]), in: f.window))
    #expect(f.state.currentSession?.mediaItems.allSatisfy { $0.selectionState == .included } == true)
    #expect(f.state.selectedMediaItemIDs.isEmpty); #expect(f.state.selectedFolderNodeIDs == [node.id])
    for flags: NSEvent.ModifierFlags in [[], [.shift], [.command], [.command, .shift]] {
        #expect(!f.state.commandCoordinator.handle(f.event("\u{f701}", code: 125, modifiers: flags), in: f.window))
    }
    #expect(!f.state.commandCoordinator.handle(f.event("\r", code: 36), in: f.window))
    #expect(!f.window.isVisible)
}

@MainActor @Test func sourceNavigationFolderRebindingAndTextSelectionKeepIndependentNativeScopes() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try sourceNavigationFolder(f)
    let table = try await sourceNavigationMount(f); f.window.makeFirstResponder(table)
    #expect(f.state.setCommandShortcut(.selectAllFolders, override: .init(shortcut: .init(key: "a", modifiers: [.command, .option]))))
    #expect(!f.state.commandCoordinator.handle(f.event("a", modifiers: [.command]), in: f.window))
    #expect(f.state.commandCoordinator.handle(f.event("a", modifiers: [.command, .option]), in: f.window))
    #expect(!f.state.selectedFolderNodeIDs.isEmpty)
    let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)); editor.string = "Native text selection"
    f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor)
    #expect(!f.state.commandCoordinator.handle(f.event("a", modifiers: [.command]), in: f.window))
    editor.selectAll(nil); #expect(editor.selectedRange().length == editor.string.utf16.count)
}

@MainActor @Test func sourceNavigationFolderFocusFindsItsOwnNativeListWithoutEnablingPhotoCommands() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try sourceNavigationFolder(f)
    let table = try await sourceNavigationMount(f)
    #expect(f.state.canFocusBrowserDetail); #expect(!f.state.canFocusReviewSurface)
    #expect(f.state.commandCoordinator.executeWindowControl(.focusReview, in: f.window)); try await Task.sleep(for: .milliseconds(60))
    #expect(f.window.firstResponder === table); #expect(f.state.activePane == .folders)
    let invocation = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(invocation.scope == .sourceFolders)
    #expect(f.state.commandCoordinator.unavailableReason(.selectAll, invocation: invocation) != nil)
    #expect(!f.window.isVisible)
}

@MainActor @Test func sourceNavigationBindingsRejectRemovedContainersReplacedWindowsAndModalBoundaries() throws {
    for change in ["removed", "window", "modal", "container"] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
        let (surface, handle) = sourceNavigationSurface(f, folders: true)
        let context = f.state.reviewState.snapshot.folderCommandContextKey
        let binding = sourceFolderSelectionBinding(f.state, context: context, handle: handle)
        switch change {
        case "removed": surface.removeFromSuperview()
        case "window": f.state.commandCoordinator.unregisterWindow(f.token); f.state.commandCoordinator.register(window: f.window, token: f.token, scope: .main)
        case "container": surface.configure(coordinator: f.state.commandCoordinator, scope: .sourceFolders, contextKey: "replacement", actions: [:])
        default:
            let modal = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(modal)
            modal.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "modal", actions: [:])
        }
        binding.wrappedValue = [node.id]
        openDisplayedSourceFolder(f.state, node: node, context: context, handle: handle)
        #expect(f.state.selectedFolderNodeIDs.isEmpty)
        #expect(f.state.selectedSidebarNodeID == "section-current-session")
    }
}


@MainActor @Test func sourceNavigationFilteredReviewAndPhotoLogsNeverClaimTheFolderSurface() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
    f.state.selectSidebarNode(node.id); f.state.setReviewFilter(.included)
    #expect(!f.state.contextMediaItems.isEmpty); #expect(f.state.visibleMediaItems.isEmpty)
    #expect(!f.state.isSourceFolderBrowserDisplayed)
    #expect(!sourceFolderBrowserIsDisplayed(mode: f.state.workspaceMode, contextMediaItemCount: f.state.reviewState.snapshot.contextMediaItemCount, hasFolders: !f.state.reviewState.snapshot.detailFolderNodes.isEmpty))
    f.state.setWorkspaceMode(.photoLogs); f.state.selectSidebarNode("section-current-session")
    #expect(!f.state.isSourceFolderBrowserDisplayed); #expect(!f.state.canFocusBrowserDetail)
}

@MainActor
private func sourceNavigationReviewResponder(_ view: NSView) -> ReviewKeyResponderView? {
    if let review = view as? ReviewKeyResponderView { return review }
    for child in view.subviews { if let review = sourceNavigationReviewResponder(child) { return review } }
    return nil
}

@MainActor @Test func sourceNavigationActualSidebarContainerCommandReturnEntersTheFolderList() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try sourceNavigationFolder(f)
    let host = NSHostingView(rootView: HStack {
        CommandSidebarContainer(appState: f.state, content:
            SidebarPaneView(appState: f.state, state: f.state.sidebarState, archiveState: f.state.archiveBrowserState, appRelease: .current)
        ).frame(width: 180)
        BrowserOrReviewPaneView(appState: f.state, state: f.state.reviewState, navigationState: f.state.reviewNavigationState,
            sidebarState: f.state.sidebarState, archiveState: f.state.archiveBrowserState)
    })
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host)
    try await Task.sleep(for: .milliseconds(80)); host.layoutSubtreeIfNeeded()
    let sidebarTable = try #require(sourceNavigationTable(host))
    #expect(f.window.makeFirstResponder(sidebarTable))
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window)); #expect(origin.scope == .sourceSidebar)
    let down = f.event("\u{f701}", code: 125), up = f.event("\u{f700}", code: 126)
    #expect(!f.state.commandCoordinator.handle(down, in: f.window))
    sidebarTable.keyDown(with: down); try await Task.sleep(for: .milliseconds(30))
    #expect(f.state.selectedSidebarNodeID == "session-root")
    sidebarTable.keyDown(with: up); try await Task.sleep(for: .milliseconds(30))
    #expect(f.state.selectedSidebarNodeID == "section-current-session")
    #expect(f.state.commandCoordinator.handle(f.event("\r", code: 36, modifiers: [.command]), in: f.window))
    try await Task.sleep(for: .milliseconds(80)); host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(30))
    let focused = try #require(f.window.firstResponder as? NSTableView)
    #expect(focused !== sidebarTable)
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == .sourceFolders)
    #expect(f.state.selectedSidebarNodeID == "section-current-session"); #expect(!f.window.isVisible)
}

@MainActor @Test func sourceNavigationActualBrowserFolderOpenReplacesTheListAndFocusesReview() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
    let host = NSHostingView(rootView: BrowserOrReviewPaneView(appState: f.state, state: f.state.reviewState,
        navigationState: f.state.reviewNavigationState, sidebarState: f.state.sidebarState, archiveState: f.state.archiveBrowserState))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host)
    try await Task.sleep(for: .milliseconds(80)); host.layoutSubtreeIfNeeded()
    let table = try #require(sourceNavigationTable(host)); f.window.makeFirstResponder(table)
    #expect(f.state.commandCoordinator.handle(f.event("a", modifiers: [.command]), in: f.window))
    #expect(f.state.commandCoordinator.handle(f.event("\r", code: 36, modifiers: [.command]), in: f.window))
    try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    // Explicit hidden-window layout can mount the new responder here. Its guarded
    // focus request runs on the next turn, just as in the real event loop.
    try await Task.sleep(for: .milliseconds(30))
    #expect(f.state.selectedSidebarNodeID == node.id)
    let review = try #require(sourceNavigationReviewResponder(host))
    #expect(Bool(f.window.firstResponder === review))
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == .review)
    #expect(!f.window.isVisible)
}


@MainActor @Test func sourceNavigationOldNativeFolderListRejectsGenericTriageBeforeRedraw() async throws {
    for change in ["parent", "tree", "source"] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
        let table = try await sourceNavigationMount(f); f.window.makeFirstResponder(table)
        #expect(f.state.commandCoordinator.handle(f.event("a", modifiers: [.command]), in: f.window))
        let session = try #require(f.state.currentSession)
        switch change {
        case "parent": f.state.selectSidebarNode(node.id); f.state.selectSidebarNode("section-current-session")
        case "tree": let groups = f.state.timeClusters; f.state.timeClusters = groups
        default: f.state.currentSession = nil; f.state.currentSession = session; f.state.selectSidebarNode("section-current-session")
        }
        // Keep the actual old native List attached, without allowing SwiftUI to
        // issue a replacement snapshot/capability between transition and command.
        f.state.selectFolderNodes([node.id]); f.state.activePane = .folders
        #expect(table.window === f.window)
        #expect(!f.state.commandCoordinator.handle(f.event("i", modifiers: [.command]), in: f.window))
        #expect(f.state.currentSession?.mediaItems.allSatisfy { $0.selectionState == .undecided } == true)
        #expect(f.state.selectedMediaItemIDs.isEmpty)
    }
}


@MainActor @Test func sourceNavigationStaleContainingContextRejectsAValidChildCommand() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    var current = true, calls = 0
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .sourceFolders, contextKey: "parent", actions: [:], contextIsCurrent: { current })
    let child = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 50, height: 50)); parent.host.addSubview(child)
    let handle = child.configure(coordinator: f.state.commandCoordinator, scope: .reviewItem, contextKey: "child", actions: [.markIncluded: .init(run: { calls += 1 })])
    #expect(handle.isEnabled(.markIncluded)); handle.run(.markIncluded); #expect(calls == 1)
    current = false; #expect(!handle.isEnabled(.markIncluded)); handle.run(.markIncluded); #expect(calls == 1)
}

@MainActor @Test func sourceNavigationQueuedFocusRejectsNewlyMountedStaleLeafOrAncestor() async throws {
    for staleAncestor in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        let prior = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 80)); f.window.contentView!.addSubview(prior); f.window.makeFirstResponder(prior)
        f.state.commandCoordinator.requestFocus(scope: .sourceFolders, in: f.window)
        let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
        parent.configure(coordinator: f.state.commandCoordinator, scope: .sourceSidebar, contextKey: "parent", actions: [:], contextIsCurrent: { !staleAncestor })
        let child = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 50, height: 50)); parent.host.addSubview(child)
        child.configure(coordinator: f.state.commandCoordinator, scope: .sourceFolders, contextKey: "new leaf", actions: [:], contextIsCurrent: { staleAncestor })
        try await Task.sleep(for: .milliseconds(30))
        #expect(f.window.firstResponder === prior); #expect(!f.window.isVisible)
    }
}

@MainActor @Test func sourceNavigationOldNativeSidebarRejectsGenericTriageBeforeRedraw() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let node = try sourceNavigationFolder(f)
    f.state.selectSidebarNode(node.id)
    let host = NSHostingView(rootView: CommandSidebarContainer(appState: f.state, content:
        SidebarPaneView(appState: f.state, state: f.state.sidebarState, archiveState: f.state.archiveBrowserState, appRelease: .current)))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host)
    try await Task.sleep(for: .milliseconds(60)); host.layoutSubtreeIfNeeded()
    let table = try #require(sourceNavigationTable(host)); f.window.makeFirstResponder(table)
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == .sourceSidebar)
    f.state.activePane = .sidebar; #expect(f.state.canMarkSelectionForImport)
    let groups = f.state.timeClusters; f.state.timeClusters = groups
    #expect(table.window === f.window)
    #expect(!f.state.commandCoordinator.handle(f.event("i", modifiers: [.command]), in: f.window))
    #expect(f.state.currentSession?.mediaItems.allSatisfy { $0.selectionState == .undecided } == true)
}
