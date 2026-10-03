import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
private func drainReviewFocus() async throws {
    try await Task.sleep(for: .milliseconds(30))
}

@MainActor @Test func reviewQueuedFocusRejectsHiddenOwnerAndHiddenExplicitChild() async throws {
    for hiddenOwner in [true, false] {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        let owner = NSView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(owner)
        let target = ReviewKeyResponderView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)); owner.addSubview(target)
        let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior)
        let lease = CommandSurfaceLease(view: owner, token: UUID(), scope: .review, active: true,
            supports: { _ in false }, availability: { _ in true }, run: { _ in false })
        lease.focusTarget = { target }; f.state.commandCoordinator.register(lease)
        f.window.makeFirstResponder(prior)
        f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
        if hiddenOwner { owner.isHidden = true } else { target.isHidden = true }
        try await drainReviewFocus()
        #expect(f.window.firstResponder === prior)
        #expect(!f.window.isVisible)
    }
}

@MainActor @Test func reviewQueuedFocusCannotEscapeNewModalWithoutAResponderChange() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let target = ReviewKeyResponderView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)); f.window.contentView!.addSubview(target)
    target.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    try await drainReviewFocus()
    let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior)
    f.window.makeFirstResponder(prior)
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    let modal = CommandLocalSurfaceView(frame: NSRect(x: 100, y: 0, width: 100, height: 100)); f.window.contentView!.addSubview(modal)
    modal.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "new modal", actions: [:])
    #expect(f.window.firstResponder === prior)
    try await drainReviewFocus()
    #expect(f.window.firstResponder === prior)
}

@MainActor @Test func reviewQueuedFocusRejectsExplicitTargetOutsideItsOwner() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let owner = NSView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(owner)
    let target = ReviewKeyResponderView(frame: .zero); f.window.contentView!.addSubview(target)
    let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior)
    let lease = CommandSurfaceLease(view: owner, token: UUID(), scope: .review, active: true,
        supports: { _ in false }, availability: { _ in true }, run: { _ in false })
    lease.focusTarget = { target }; f.state.commandCoordinator.register(lease)
    f.window.makeFirstResponder(prior)
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    try await drainReviewFocus()
    #expect(f.window.firstResponder === prior)
}

@MainActor @Test func reviewQueuedFocusDoesNotFallbackWhenAnExplicitTargetIsMissing() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let owner = ReviewKeyResponderView(frame: .zero); f.window.contentView!.addSubview(owner)
    let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior)
    let lease = CommandSurfaceLease(view: owner, token: UUID(), scope: .review, active: true,
        supports: { _ in false }, availability: { _ in true }, run: { _ in false })
    lease.focusTarget = { nil }; f.state.commandCoordinator.register(lease)
    f.window.makeFirstResponder(prior)
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    try await drainReviewFocus()
    #expect(f.window.firstResponder === prior)
}


@MainActor
private func prepareReviewPane(_ f: LocalSurfaceFixture) throws -> [MediaItem] {
    let items = (0..<3).map { makeTestMediaItem(sourceRoot: f.root, fileName: "Review-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    let node = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })
    f.state.selectedSidebarNodeID = node.id
    f.state.selectedMediaItemIDs = [items[0].id]; f.state.focusedReviewItemID = items[0].id
    return items
}

@MainActor
private final class ReviewMapFlag { var value = false; var binding: Binding<Bool> { .init(get: { self.value }, set: { self.value = $0 }) } }

@MainActor
private func mountReviewCommands(_ f: LocalSurfaceFixture, map: ReviewMapFlag) -> (CommandLocalSurfaceView, LocalCommandHandle, ReviewKeyResponderView) {
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
    let handle = parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
        actions: reviewPaneCommandActions(f.state, showMap: map.binding), focusTarget: reviewPaneKeyboardTarget)
    let child = ReviewKeyResponderView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)); parent.host.addSubview(child)
    child.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    return (parent, handle, child)
}

@MainActor @Test func reviewMapBindingIsInheritedWhileKeyboardChildKeepsArrowAndSpace() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    let map = ReviewMapFlag(); let (_, handle, child) = mountReviewCommands(f, map: map)
    var arrows = 0, spaces = 0; child.onArrow = { _, _, _ in arrows += 1 }; child.onSpace = { spaces += 1 }
    try await drainReviewFocus(); #expect(f.window.firstResponder === child)
    #expect(f.state.commandCoordinator.registry.bindings(.toggleReviewMap).isEmpty)
    #expect(f.state.setCommandShortcut(.toggleReviewMap, override: .init(shortcut: .init(key: "m", modifiers: [.command, .option]))))
    #expect(f.window.performKeyEquivalent(with: f.event("m", modifiers: [.command, .option]))); #expect(map.value)
    handle.run(.toggleReviewMap); #expect(!map.value)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f703}", code: 124)))
    #expect(f.window.performKeyEquivalent(with: f.event(" ", code: 49)))
    #expect(arrows == 1); #expect(spaces == 1); #expect(!f.window.isVisible)
}

@MainActor @Test func reviewMenuCommandsRetainLivePhotoSelectionAcrossTriageAndMetadataRedraws() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try prepareReviewPane(f)
    let map = ReviewMapFlag(); let (parent, handle, child) = mountReviewCommands(f, map: map)
    try await drainReviewFocus()
    let context = reviewPaneCommandContextKey(f.state)
    f.state.selectedMediaItemIDs = [items[1].id]; f.state.focusedReviewItemID = items[1].id
    f.state.selectedFolderNodeIDs = [f.state.selectedSidebarNodeID!]; f.state.activePane = .sidebar
    handle.run(.markIncluded)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == items[1].id }?.selectionState == .included)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == items[0].id }?.selectionState != .included)
    var session = try #require(f.state.currentSession); session.walkMetadata.notes = "Ordinary saved metadata"; f.state.currentSession = session
    #expect(reviewPaneCommandContextKey(f.state) == context)
    let refreshed = parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
        actions: reviewPaneCommandActions(f.state, showMap: map.binding), focusTarget: reviewPaneKeyboardTarget)
    // The first triage action intentionally advances. The generic menu now uses
    // this explicitly selected current photo, not its original selection.
    f.state.selectedMediaItemIDs = [items[2].id]; f.state.focusedReviewItemID = items[2].id
    handle.run(.markCandidate)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == items[2].id }?.selectionState == .candidate)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == items[1].id }?.selectionState == .included)
    refreshed.run(.deselectReviewPhotos)
    #expect(f.state.selectedMediaItemIDs.isEmpty); #expect(!f.state.selectedFolderNodeIDs.isEmpty)
    try await drainReviewFocus(); #expect(f.window.firstResponder === child)
}

@MainActor @Test func reviewControlsRejectNavigationSourceAndAuthorityABABeforeRedraw() throws {
    for change in ["Log", "sidebar", "workspace", "source", "authority"] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
        let map = ReviewMapFlag(); let (_, old, _) = mountReviewCommands(f, map: map)
        let original = try #require(f.state.currentSession), node = f.state.selectedSidebarNodeID
        switch change {
        case "Log":
            f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: original.mediaItems)
            f.state.currentSession = original
        case "sidebar": f.state.selectedSidebarNodeID = "different"; f.state.selectedSidebarNodeID = node
        case "workspace": f.state.setWorkspaceMode(.photoLogs); f.state.setWorkspaceMode(.cameraTriage); f.state.selectedSidebarNodeID = node
        case "source": var other = original; other.workspaceSourceFolder = f.root.appendingPathComponent("other"); f.state.currentSession = other; f.state.currentSession = original
        default: let root = f.state.settings.archiveRoot; f.state.settings.archiveRoot = root.appendingPathComponent("other"); f.state.settings.archiveRoot = root
        }
        old.run(.toggleReviewMap); #expect(!map.value)
        old.run(.filterExcluded); #expect(f.state.reviewFilter == .all)
    }
}

@MainActor @Test func reviewEmptyFilterRetainsRecoveryAndParentReplacementFocusesRetainedKeyboardChild() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    let map = ReviewMapFlag(); let (parent, old, child) = mountReviewCommands(f, map: map)
    try await drainReviewFocus()
    let node = f.state.selectedSidebarNodeID
    f.state.selectedSidebarNodeID = "replacement"; f.state.selectedSidebarNodeID = node
    let fresh = parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
        actions: reviewPaneCommandActions(f.state, showMap: map.binding), focusTarget: reviewPaneKeyboardTarget)
    old.run(.toggleReviewMap); #expect(!map.value)
    let field = NSTextField(string: "Map name"); field.frame = NSRect(x: 10, y: 20, width: 200, height: 28); parent.host.addSubview(field); field.selectText(nil)
    fresh.run(.filterExcluded); #expect(f.state.visibleMediaItems.isEmpty)
    try await drainReviewFocus(); #expect(f.window.firstResponder === child)
    let empty = parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
        actions: reviewPaneCommandActions(f.state, showMap: map.binding), focusTarget: reviewPaneKeyboardTarget)
    #expect(empty.isEnabled(.filterAll)); #expect(empty.isEnabled(.listLayout))
    empty.run(.listLayout); #expect(f.state.reviewPresentationMode == .list)
    try await drainReviewFocus(); #expect(f.window.firstResponder === child)
    empty.run(.filterAll); #expect(f.state.visibleMediaItems.count == 3)
    try await drainReviewFocus()
    var moves = 0, toggles = 0; child.onArrow = { _, _, _ in moves += 1 }; child.onSpace = { toggles += 1 }
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f703}", code: 124)))
    #expect(f.window.performKeyEquivalent(with: f.event(" ", code: 49)))
    #expect(moves == 1); #expect(toggles == 1)
}

@MainActor @Test func reviewGridControlsRecheckBoundsEvenWhenTheirRenderedAvailabilityIsOld() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    f.state.setReviewGridColumnCount(2)
    let map = ReviewMapFlag(); let (parent, handle, _) = mountReviewCommands(f, map: map)
    f.state.setReviewGridColumnCount(1); handle.run(.zoomOut); #expect(f.state.settings.reviewGridColumnCount == 1)
    f.state.setReviewGridColumnCount(ReviewGridMetrics.maxSuggestedColumns); handle.run(.zoomIn)
    #expect(f.state.settings.reviewGridColumnCount == ReviewGridMetrics.maxSuggestedColumns)
    let current = parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
        actions: reviewPaneCommandActions(f.state, showMap: map.binding), focusTarget: reviewPaneKeyboardTarget)
    #expect(!current.isEnabled(.zoomIn)); #expect(current.isEnabled(.zoomReset))
    current.run(.zoomReset); #expect(f.state.settings.reviewGridColumnCount == ReviewGridMetrics.defaultRequestedColumnCount())
}

@MainActor @Test func reviewMapFieldKeepsNativeTypingAndRedrawDoesNotStealFocus() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    let map = ReviewMapFlag(); let (parent, handle, child) = mountReviewCommands(f, map: map)
    try await drainReviewFocus()
    let field = NSTextField(string: "Location draft"); field.frame = NSRect(x: 10, y: 20, width: 200, height: 28); parent.host.addSubview(field); field.selectText(nil)
    let editor = try #require(field.currentEditor() as? NSTextView)
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == .editor)
    #expect(f.state.setCommandShortcut(.toggleReviewMap, override: .init(shortcut: .init(key: "m", modifiers: [.command, .option]))))
    #expect(!f.window.performKeyEquivalent(with: f.event("m", modifiers: [.command, .option])))
    #expect(!f.window.performKeyEquivalent(with: f.event("a", modifiers: [.command])))
    #expect(!f.window.performKeyEquivalent(with: f.event("c", modifiers: [.command])))
    #expect(!f.window.performKeyEquivalent(with: f.event("i", modifiers: [.command])))
    #expect(f.window.performKeyEquivalent(with: f.event("/", modifiers: [.command])))
    #expect(!map.value)
    child.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
        actions: reviewPaneCommandActions(f.state, showMap: map.binding), focusTarget: reviewPaneKeyboardTarget)
    try await drainReviewFocus(); #expect(f.window.firstResponder === editor)
    // A clicked Map control owns this pane, but does not force a grid focus transition.
    handle.run(.toggleReviewMap); #expect(map.value); try await drainReviewFocus(); #expect(f.window.firstResponder === editor)
}

@MainActor @Test func reviewQueuedFocusRejectsReplacedExplicitChildAndPreservesOtherWindow() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    let map = ReviewMapFlag(); let (parent, _, child) = mountReviewCommands(f, map: map)
    try await drainReviewFocus()
    let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior); f.window.makeFirstResponder(prior)
    // Re-register parent after child so the request captures its explicit descendant.
    parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: "new parent", actions: [:], focusTarget: reviewPaneKeyboardTarget)
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    child.removeFromSuperview()
    let replacement = ReviewKeyResponderView(frame: .zero); parent.host.addSubview(replacement)
    try await drainReviewFocus(); #expect(f.window.firstResponder === prior)
    let other = try LocalSurfaceFixture(); defer { other.close() }
    let otherEditor = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 60)); other.window.contentView!.addSubview(otherEditor); other.window.makeFirstResponder(otherEditor)
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    try await drainReviewFocus(); #expect(f.window.firstResponder === replacement); #expect(other.window.firstResponder === otherEditor)
    #expect(!f.window.isVisible); #expect(!other.window.isVisible)
}

@MainActor @Test func actualHostedReviewFillsWindowWithAndWithoutMapAndRetainsItsKeyboardChild() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    f.window.setContentSize(NSSize(width: 1100, height: 800))
    let host = NSHostingView(rootView: ReviewPaneView(appState: f.state, state: f.state.reviewState, navigationState: f.state.reviewNavigationState))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host)
    func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
        (view as? CommandLocalSurfaceView).map { [$0] } ?? view.subviews.flatMap { surfaces($0) }
    }
    for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await drainReviewFocus() }
    let parent = try #require(surfaces(host).first)
    let child = try #require(reviewPaneKeyboardTarget(in: parent))
    #expect(parent.bounds.height >= 790); #expect(parent.bounds.width >= 1090)
    let before = child.convert(.zero, to: parent).y
    f.window.makeFirstResponder(child)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(f.state.commandCoordinator.execute(.toggleReviewMap, invocation: origin))
    for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await drainReviewFocus() }
    let afterChild = try #require(reviewPaneKeyboardTarget(in: parent))
    #expect(parent.bounds.height >= 790)
    #expect(abs(afterChild.convert(.zero, to: parent).y - before) >= 300)
    #expect(f.state.reviewState.snapshot.visibleItems.count == 3)
    let freshOrigin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(f.state.commandCoordinator.execute(.listLayout, invocation: freshOrigin))
    for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await drainReviewFocus() }
    let focusedChild = try #require(reviewPaneKeyboardTarget(in: parent))
    #expect(f.window.firstResponder === focusedChild)
    let first = try #require(f.state.focusedReviewItemID)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f703}", code: 124)))
    let moved = try #require(f.state.focusedReviewItemID); #expect(moved != first)
    let wasSelected = f.state.selectedMediaItemIDs.contains(moved)
    #expect(f.window.performKeyEquivalent(with: f.event(" ", code: 49)))
    #expect(f.state.selectedMediaItemIDs.contains(moved) != wasSelected)
    #expect(!f.window.isVisible)
}

@MainActor @Test func clickedReviewControlFocusesItsOwnGridWhenAnotherReviewContainerIsNewer() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
    let mapA = ReviewMapFlag(), mapB = ReviewMapFlag()
    let (_, buttonA, childA) = mountReviewCommands(f, map: mapA)
    let (_, _, childB) = mountReviewCommands(f, map: mapB)
    try await drainReviewFocus(); f.window.makeFirstResponder(childB)
    buttonA.run(.listLayout)
    try await drainReviewFocus()
    #expect(f.window.firstResponder === childA)
    var arrowsA = 0, arrowsB = 0
    childA.onArrow = { _, _, _ in arrowsA += 1 }; childB.onArrow = { _, _, _ in arrowsB += 1 }
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f703}", code: 124)))
    #expect(arrowsA == 1); #expect(arrowsB == 0)
}

@MainActor @Test func reviewOwnedFocusDoesNotFallbackAfterItsActionUnregistersOrDetachesTheOwner() async throws {
    for detach in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try prepareReviewPane(f)
        let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
        let handle = parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: "removed during action",
            actions: [.listLayout: .init(run: { [weak parent] in
                if detach { parent?.removeFromSuperview() } else { parent?.unregister() }
                f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
            })])
        let (_, _, otherChild) = mountReviewCommands(f, map: ReviewMapFlag())
        try await drainReviewFocus()
        let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior); f.window.makeFirstResponder(prior)
        handle.run(.listLayout)
        try await drainReviewFocus()
        #expect(f.window.firstResponder === prior)
        #expect(f.window.firstResponder !== otherChild)
    }
}
