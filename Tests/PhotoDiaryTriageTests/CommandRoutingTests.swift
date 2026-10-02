import AppKit
import Foundation
import Testing
@testable import PhotoDiaryTriage

@MainActor
private final class NativeCommandFixture {
    let root: URL
    let state: AppState
    let window: NSWindow
    let anchor: CommandWindowAnchorView
    let review: ReviewKeyResponderView
    init(scope: AppCommandScope = .main) throws {
        root = try makeTemporaryDirectory()
        var settings = AppSettings.default(); settings.archiveRoot = root; settings.oneDrivePicturesRoot = root
        state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root)
        state.commandCoordinator.presentsPanels = false
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 260), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        anchor = CommandWindowAnchorView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        anchor.coordinator = state.commandCoordinator; anchor.scope = scope
        window.contentView!.addSubview(anchor)
        review = ReviewKeyResponderView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        window.contentView!.addSubview(review)
        review.configureCommands(coordinator: state.commandCoordinator, scope: .review, focused: true)
        window.makeFirstResponder(review)
        #expect(!window.isVisible)
    }
    func close() {
        state.commandCoordinator.panels.close(restore: false)
        anchor.unregisterWindow(); window.close(); try? FileManager.default.removeItem(at: root)
    }
    func event(_ key: String, code: UInt16 = 0, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 1,
            windowNumber: window.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code)!
    }
}

@MainActor
@Test func nativeWindowDispatchUsesEffectiveShortcutOnceAndUnbindRemovesAlias() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    var zooms = 0; f.review.onZoomIn = { zooms += 1 }
    #expect(f.window.performKeyEquivalent(with: f.event("=")))
    #expect(zooms == 1)
    let saved = f.state.setCommandShortcut(.zoomIn, override: .init(shortcut: .init(key: "y", modifiers: [.command, .option])))
    #expect(saved)
    #expect(!f.window.performKeyEquivalent(with: f.event("=")))
    #expect(f.window.performKeyEquivalent(with: f.event("y", modifiers: [.command, .option])))
    #expect(zooms == 2)
    let unbound = f.state.setCommandShortcut(.zoomIn, override: .init(shortcut: nil)); #expect(unbound)
    #expect(!f.window.performKeyEquivalent(with: f.event("y", modifiers: [.command, .option])))
    #expect(zooms == 2)
}

@MainActor
@Test func nativeMultilineEditorCanOpenHelpAndKeepsTextSelection() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 240, height: 130)); editor.string = "Keep these notes\nAnd this selection"
    f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor)
    let range = NSRange(location: 5, length: 7); editor.setSelectedRange(range)
    var marks = 0; f.review.onSingleKey = { _ in marks += 1 }
    #expect(!f.window.performKeyEquivalent(with: f.event("s")))
    #expect(f.window.performKeyEquivalent(with: f.event("/", modifiers: [.command])))
    let help = try #require(f.state.commandCoordinator.panels.current)
    #expect(help.mode == .help); #expect(help.panel?.isVisible == false)
    #expect(help.origin.scope == .editor); #expect(marks == 0)
    f.state.commandCoordinator.panels.close()
    #expect(f.window.firstResponder === editor); #expect(editor.selectedRange() == range)
    #expect(editor.string == "Keep these notes\nAnd this selection")
}

@MainActor
@Test func nativeSettingsFieldEditorOpensPaletteAndRestoresActualControlSelection() throws {
    let f = try NativeCommandFixture(scope: .settings); defer { f.close() }
    let field = NSTextField(string: "http://localhost:1234/v1"); field.frame = NSRect(x: 20, y: 20, width: 260, height: 30)
    f.window.contentView!.addSubview(field); field.selectText(nil)
    let editor = try #require(field.currentEditor() as? NSTextView)
    #expect(f.window.firstResponder === editor); editor.setSelectedRange(NSRange(location: 7, length: 9))
    #expect(f.window.performKeyEquivalent(with: f.event("p", modifiers: [.command, .shift])))
    let session = try #require(f.state.commandCoordinator.panels.current)
    #expect(session.mode == .palette); #expect(session.origin.fieldControl === field)
    #expect(session.commands.count == AppCommandID.allCases.count)
    session.query = "backup export"; #expect(session.commands.map(\.id) == [.exportBackup])
    #expect(f.state.commandCoordinator.unavailableReason(.copyIncluded, invocation: session.origin) != nil)
    f.state.commandCoordinator.panels.close()
    let restored = try #require(field.currentEditor() as? NSTextView)
    #expect(f.window.firstResponder === restored); #expect(restored.selectedRange() == NSRange(location: 7, length: 9))
    #expect(field.stringValue == "http://localhost:1234/v1")
}

@MainActor
@Test func stalePaletteInvocationCannotActOnChangedSelectionOrRoot() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    var zooms = 0; f.review.onZoomIn = { zooms += 1 }
    #expect(f.window.performKeyEquivalent(with: f.event("p", modifiers: [.command, .shift])))
    let session = try #require(f.state.commandCoordinator.panels.current); session.highlighted = .zoomIn
    f.state.selectedMediaItemIDs = [UUID()]
    f.state.commandCoordinator.panels.runHighlighted()
    #expect(zooms == 0); #expect(session.error != nil); #expect(f.state.commandCoordinator.panels.current === session)
    f.state.selectedMediaItemIDs = []
    var changed = f.state.settings; changed.archiveRoot = f.root.appendingPathComponent("different"); f.state.settings = changed
    #expect(!f.state.commandCoordinator.execute(.zoomIn, invocation: session.origin)); #expect(zooms == 0)
}

@MainActor
@Test func detachedOrReplacedSurfaceDoesNotReceiveCapturedCommand() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let captured = try #require(f.state.commandCoordinator.invocation(in: f.window))
    var oldZoom = 0; f.review.onZoomIn = { oldZoom += 1 }; f.review.removeFromSuperview()
    let replacement = ReviewKeyResponderView(frame: .zero); f.window.contentView!.addSubview(replacement)
    replacement.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    var newZoom = 0; replacement.onZoomIn = { newZoom += 1 }; f.window.makeFirstResponder(replacement)
    #expect(!f.state.commandCoordinator.execute(.zoomIn, invocation: captured))
    #expect(f.window.performKeyEquivalent(with: f.event("=")))
    #expect(oldZoom == 0); #expect(newZoom == 1)
}

@MainActor
@Test func delayedReviewFocusCannotStealAnEditorThatGainedFocus() async throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 200, height: 100)); editor.string = "Still typing"
    f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor)
    f.review.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    try await Task.sleep(for: .milliseconds(20))
    #expect(f.window.firstResponder === editor)
}

@MainActor
@Test func nativeUnclaimedCommandArrowStillMovesInTextView() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 250, height: 100)); editor.string = "First line\nSecond line"
    f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor); editor.setSelectedRange(NSRange(location: 17, length: 0))
    let event = f.event("\u{f702}", code: 123, modifiers: [.command])
    #expect(!f.window.performKeyEquivalent(with: event))
    editor.keyDown(with: event)
    #expect(editor.selectedRange() == NSRange(location: 11, length: 0))
    #expect(editor.string == "First line\nSecond line")
}

@MainActor
@Test func compareLeaseSuppressesUnderlyingReviewEvenBeforeItsInitialFocus() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    var underlying = 0, comparison = 0; f.review.onZoomIn = { underlying += 1 }
    let compare = ReviewKeyResponderView(frame: .zero); f.window.contentView!.addSubview(compare)
    compare.configureCommands(coordinator: f.state.commandCoordinator, scope: .compare, focused: true)
    compare.onZoomIn = { comparison += 1 }
    #expect(f.window.firstResponder === f.review)
    #expect(f.window.performKeyEquivalent(with: f.event("=")))
    #expect(underlying == 0); #expect(comparison == 1)
}

@MainActor
@Test func paletteRebindCaptureEscapeCancelsWithoutClosingAndSavedKeyExecutes() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    var zooms = 0; f.review.onZoomIn = { zooms += 1 }
    #expect(f.window.performKeyEquivalent(with: f.event("p", modifiers: [.command, .shift])))
    let session = try #require(f.state.commandCoordinator.panels.current); session.highlighted = .zoomIn
    let panel = try #require(session.panel)
    func panelEvent(_ key: String, code: UInt16 = 0, mods: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: mods, timestamp: 2,
            windowNumber: panel.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code)!
    }
    #expect(f.state.commandCoordinator.handle(panelEvent(",", mods: [.command, .shift]), in: panel))
    #expect(session.capturing == .zoomIn)
    #expect(f.state.commandCoordinator.handle(panelEvent("\u{1b}", code: 53), in: panel))
    #expect(session.capturing == nil); #expect(f.state.commandCoordinator.panels.current === session)
    f.state.commandCoordinator.panels.beginRebinding()
    #expect(f.state.commandCoordinator.handle(panelEvent("y", mods: [.command, .option]), in: panel))
    #expect(session.capturing == nil); #expect(session.error == nil)
    f.state.commandCoordinator.panels.close()
    #expect(f.window.performKeyEquivalent(with: f.event("y", modifiers: [.command, .option])))
    #expect(zooms == 1)
}

@MainActor
@Test func readOnlySelectableTextKeepsNativeSelectAllAndDoesNotClaimPhotoKeys() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 200, height: 100))
    editor.string = "Readable evidence"; editor.isEditable = false; editor.isSelectable = true
    f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor)
    let select = f.event("a", modifiers: [.command])
    let claimed = f.state.commandCoordinator.handle(select, in: f.window)
    #expect(claimed == false)
    // Command-A is a native Edit menu equivalent, not a text key-binding event.
    let edit = NSMenu(title: "Edit")
    let item = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    item.keyEquivalentModifierMask = [.command]; item.target = editor; edit.addItem(item)
    #expect(edit.performKeyEquivalent(with: select))
    #expect(editor.selectedRange() == NSRange(location: 0, length: editor.string.utf16.count))
}

@MainActor
@Test func capturedInvocationStaysInvalidAfterRootRoundTripAndDeallocatedLease() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let captured = try #require(f.state.commandCoordinator.invocation(in: f.window))
    f.review.removeFromSuperview()
    #expect(f.state.commandCoordinator.isCurrent(captured) == false)
    f.window.contentView!.addSubview(f.review)
    f.review.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    f.window.makeFirstResponder(f.review)
    let rootContext = try #require(f.state.commandCoordinator.invocation(in: f.window))
    let original = f.state.settings
    var changed = original; changed.archiveRoot = f.root.appendingPathComponent("elsewhere"); f.state.settings = changed
    f.state.settings = original
    #expect(f.state.commandCoordinator.isCurrent(rootContext) == false)
}

@MainActor
@Test func twoOwnedPalettesCaptureAndRunTheirOwnWindowWithoutClosingTheOther() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let second = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    second.isReleasedWhenClosed = false; defer { second.close() }
    let anchor = CommandWindowAnchorView(frame: .zero); anchor.coordinator = f.state.commandCoordinator
    second.contentView!.addSubview(anchor); defer { anchor.unregisterWindow() }
    let review = ReviewKeyResponderView(frame: .zero); second.contentView!.addSubview(review)
    review.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true); second.makeFirstResponder(review)
    var firstRuns = 0, secondRuns = 0
    f.review.onZoomIn = { firstRuns += 1 }; review.onZoomOut = { secondRuns += 1 }
    f.state.commandCoordinator.execute(.palette, in: f.window)
    let first = try #require(f.state.commandCoordinator.panels.current); first.highlighted = .zoomIn
    f.state.commandCoordinator.execute(.palette, in: second)
    let other = try #require(f.state.commandCoordinator.panels.current); other.highlighted = .zoomOut
    let firstPanel = try #require(first.panel)
    f.state.commandCoordinator.execute(.rebindCommand, in: firstPanel)
    #expect(first.capturing == .zoomIn); #expect(other.capturing == nil)
    first.capturing = nil
    f.state.commandCoordinator.execute(.paletteRun, in: firstPanel)
    #expect(firstRuns == 1); #expect(secondRuns == 0)
    #expect(first.panel == nil); #expect(other.panel != nil)
    #expect(other.panel?.isVisible == false); #expect(second.isVisible == false)
}

@MainActor
@Test func helpToPaletteRetainsUnderlyingActionContext() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    var zooms = 0; f.review.onZoomIn = { zooms += 1 }
    f.state.commandCoordinator.execute(.keyboardHelp, in: f.window)
    let help = try #require(f.state.commandCoordinator.panels.current)
    f.state.commandCoordinator.execute(.palette, in: help.panel)
    let palette = try #require(f.state.commandCoordinator.panels.current)
    #expect(palette.origin.scope == .review)
    palette.highlighted = .zoomIn
    f.state.commandCoordinator.panels.runHighlighted()
    #expect(zooms == 1)
}

@MainActor
@Test func nativeSidebarMovesItsCursorAndAppliesFilterOnlyOnReturn() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let sidebar = CommandSidebarContainerView(frame: NSRect(x: 0, y: 0, width: 140, height: 200))
    f.window.contentView!.addSubview(sidebar); sidebar.configure(appState: f.state); f.window.makeFirstResponder(sidebar)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f701}", code: 125)))
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f701}", code: 125)))
    #expect(f.state.archiveSidebarNavigation.cursor == .trips)
    #expect(f.state.archiveBrowserState.snapshot.kindFilter == .all)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36)))
    #expect(f.state.archiveBrowserState.snapshot.kindFilter == .trips)
    #expect(f.window.firstResponder === sidebar)
}

@MainActor
@Test func sidebarCursorPreservesYearIdentityAndHasDeterministicMissingRowFallback() {
    let cursor = ArchiveSidebarNavigation(); cursor.reconcile(years: ["2023", "2021", "2020"])
    cursor.select(.year("2021")); cursor.reconcile(years: ["2024", "2023", "2021", "2020"])
    #expect(cursor.cursor == .year("2021"))
    cursor.reconcile(years: ["2024", "2023", "2020"])
    #expect(cursor.cursor == .year("2020"))
    cursor.reconcile(years: []); #expect(cursor.cursor == .allYears)
    cursor.move(100); #expect(cursor.cursor == .allYears)
    cursor.move(-100); #expect(cursor.cursor == .home)
}

@MainActor
@Test func nativeSourceSidebarFocusStaysInsideItsOwnedContainer() async throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    f.state.setWorkspaceMode(.cameraTriage)
    let unrelated = NSOutlineView(frame: .zero); f.window.contentView!.addSubview(unrelated)
    let sidebar = CommandSidebarContainerView(frame: NSRect(x: 0, y: 0, width: 140, height: 200))
    f.window.contentView!.addSubview(sidebar); sidebar.configure(appState: f.state)
    let owned = NSOutlineView(frame: NSRect(x: 0, y: 0, width: 120, height: 100))
    owned.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
    sidebar.host.addSubview(owned)
    #expect(owned.window === f.window); #expect(owned.acceptsFirstResponder)
    #expect(sidebar.ownedFocusTarget() === owned)
    let executed = f.state.commandCoordinator.execute(.focusSidebar, in: f.window); #expect(executed)
    try await Task.sleep(for: .milliseconds(20))
    #expect(f.window.firstResponder === owned); #expect(f.window.firstResponder !== unrelated)
}

@MainActor
@Test func nativeArchiveCardsNavigateActualRenderedYearRowsAndPreserveModifiedArrows() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    func entry(_ id: String, year: String) -> ArchiveBrowseEntry {
        .init(id: id, kind: .trip, year: year, archiveRelativePath: year + "/" + id, title: id,
            startDate: nil, endDate: nil, location: nil, photoCount: 0, walkCount: 0, coverThumbnailPath: nil)
    }
    let entries = (0..<6).map { entry("new-\($0)", year: "2025") } + (0..<3).map { entry("old-\($0)", year: "2019") }
    f.state.testingInstallArchiveCatalogue(.init(entries: entries, walksByTripPath: [:], photos: []))
    f.state.setArchiveBrowseViewMode(.contactSheet); f.state.selectArchiveEntry("new-5")
    let layout = ArchiveGridLayout(availableWidth: 838); #expect(layout.columnCount == 4)
    let pane = CommandPaneResponderView(frame: .zero); f.window.contentView!.addSubview(pane)
    pane.configure(coordinator: f.state.commandCoordinator, scope: .archiveCards, handlers: [
        .moveDown: { f.state.moveArchiveSelection(horizontal: 0, vertical: 1, contactSheetColumns: layout.columnCount) },
        .activateFocused: { f.state.openSelectedArchiveItem() }, .closeSurface: { f.state.navigateToParent() }])
    f.window.makeFirstResponder(pane)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f701}", code: 125)))
    #expect(f.state.archiveBrowserState.snapshot.selectedEntryID == "old-1")
    #expect(!f.window.performKeyEquivalent(with: f.event("\u{f701}", code: 125, modifiers: [.command])))
    #expect(f.state.archiveBrowserState.snapshot.selectedEntryID == "old-1")
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36)))
    #expect(f.state.archiveBrowserState.snapshot.level == .trip(path: "2019/old-1"))
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53)))
    #expect(f.state.archiveBrowserState.snapshot.level == .archive)
}

@MainActor
@Test func nativeFindFocusesTheInvokingWindowsTextField() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let field = NSTextField(string: ""); field.frame = NSRect(x: 0, y: 30, width: 200, height: 28)
    f.window.contentView!.addSubview(field)
    f.anchor.findAction = { field.selectText(nil) }; f.anchor.registerWindow()
    #expect(f.window.performKeyEquivalent(with: f.event("f", modifiers: [.command])))
    let editor = try #require(field.currentEditor())
    #expect(f.window.firstResponder === editor)
}

@MainActor
@Test func currentViewFindFiltersActualPhotosAndClearsStaleSelection() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let names = ["Brána-blue.jpg", "Brána-red.jpg", "Other.jpg"]
    let items = names.map { makeTestMediaItem(sourceRoot: f.root, fileName: $0, capturedAt: Date(timeIntervalSince1970: 1)) }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, workspaceSourceFolder: f.root, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    let node = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })
    f.state.selectedSidebarNodeID = node.id
    f.state.selectedMediaItemIDs = [items[2].id]; f.state.focusedReviewItemID = items[2].id
    f.state.reviewSearchQuery = "brana blue"
    #expect(f.state.visibleMediaItems.map(\.id) == [items[0].id])
    #expect(f.state.reviewInteractionItems.map(\.id) == [items[0].id])
    #expect(!f.state.selectedMediaItemIDs.contains(items[2].id))
    #expect(f.state.reviewState.snapshot.findQuery == "brana blue")
    f.state.reviewSearchQuery = ""; #expect(f.state.visibleMediaItems.count == 3)
    f.state.setReviewFilter(.included); f.state.reviewSearchQuery = "brana"
    #expect(f.state.visibleMediaItems.isEmpty)
    f.state.setReviewFilter(.all); #expect(f.state.visibleMediaItems.count == 2)
    f.state.selectedSidebarNodeID = nil; #expect(f.state.reviewSearchQuery.isEmpty)
}

@MainActor
@Test func nativePreviewTriageChangesDisplayedPhotoInsteadOfHiddenMultiSelection() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let items = (0..<3).map { makeTestMediaItem(sourceRoot: f.root, fileName: "Photo-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, workspaceSourceFolder: f.root, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    let node = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })
    f.state.selectedSidebarNodeID = node.id
    f.state.selectedMediaItemIDs = [items[0].id, items[1].id]; f.state.focusedReviewItemID = items[0].id
    f.state.previewingMediaItemID = items[2].id
    f.review.configureCommands(coordinator: f.state.commandCoordinator, scope: .preview, focused: true)
    f.review.onSingleKey = { key in if key == "S" { f.state.markPreviewItemForImport(items[2].id) } }
    #expect(f.window.performKeyEquivalent(with: f.event("s")))
    let changed = try #require(f.state.currentSession)
    #expect(changed.mediaItems[0].selectionState == .undecided); #expect(changed.mediaItems[1].selectionState == .undecided)
    #expect(changed.mediaItems[2].selectionState == .included)
}

@MainActor
@Test func newlyMountedArchiveCardsCannotStealExplicitSidebarFocus() async throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let sidebar = CommandSidebarContainerView(frame: NSRect(x: 0, y: 0, width: 140, height: 200))
    f.window.contentView!.addSubview(sidebar); sidebar.configure(appState: f.state); f.window.makeFirstResponder(sidebar)
    let pane = CommandPaneResponderView(frame: .zero); f.window.contentView!.addSubview(pane)
    pane.configure(coordinator: f.state.commandCoordinator, scope: .archiveCards, handlers: [.moveDown: {}])
    try await Task.sleep(for: .milliseconds(30))
    #expect(f.window.firstResponder === sidebar)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{f701}", code: 125)))
    #expect(f.state.archiveSidebarNavigation.cursor == .allEntries)
}

@MainActor
@Test func editingShortcutInReusedPaletteDoesNotArmAnotherWindowsPalette() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    other.isReleasedWhenClosed = false; defer { other.close() }
    let anchor = CommandWindowAnchorView(frame: .zero); anchor.coordinator = f.state.commandCoordinator
    other.contentView!.addSubview(anchor); defer { anchor.unregisterWindow() }
    f.state.commandCoordinator.execute(.palette, in: f.window)
    let first = try #require(f.state.commandCoordinator.panels.current)
    f.state.commandCoordinator.execute(.palette, in: other)
    let second = try #require(f.state.commandCoordinator.panels.current)
    let before = second.highlighted
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    f.state.commandCoordinator.panels.edit(.zoomReset, from: origin)
    #expect(first.highlighted == .zoomReset); #expect(first.capturing == .zoomReset)
    #expect(second.highlighted == before); #expect(second.capturing == nil)
    f.state.commandCoordinator.panels.close(first, restore: false)
}

@MainActor
@Test func capturedReviewCommandsRejectFindAndFilterChangesWithTheSameSelectedPhoto() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let a = makeTestMediaItem(sourceRoot: f.root, fileName: "Beacon.jpg", capturedAt: Date(timeIntervalSince1970: 1), selectionState: .included)
    let b = makeTestMediaItem(sourceRoot: f.root, fileName: "Other.jpg", capturedAt: Date(timeIntervalSince1970: 1))
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: [a,b], workspaceSourceFolder: f.root, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    let node = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == 2 })
    f.state.selectedSidebarNodeID = node.id; f.state.selectedMediaItemIDs = [a.id]; f.state.focusedReviewItemID = a.id
    let captured = try #require(f.state.commandCoordinator.invocation(in: f.window))
    f.state.reviewSearchQuery = "Beacon"
    #expect(f.state.selectedMediaItemIDs == [a.id]); #expect(f.state.visibleMediaItems.count == 1)
    #expect(f.state.commandCoordinator.isCurrent(captured) == false)
    f.state.reviewSearchQuery = ""
    let second = try #require(f.state.commandCoordinator.invocation(in: f.window))
    f.state.setReviewFilter(.included)
    #expect(f.state.selectedMediaItemIDs == [a.id]); #expect(f.state.visibleMediaItems.count == 1)
    #expect(f.state.commandCoordinator.isCurrent(second) == false)
}


@MainActor
@Test func closedOwnedWindowInvalidatesCapturedCommandsAndOnlyItsPanels() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    let captured = try #require(coordinator.invocation(in: f.window))
    var runs = 0; f.review.onZoomIn = { runs += 1 }
    let first = try #require(coordinator.panels.present(.palette, from: captured))
    let second = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    second.isReleasedWhenClosed = false; defer { second.close() }
    let token = UUID(); coordinator.register(window: second, token: token, scope: .main)
    let otherOrigin = try #require(coordinator.invocation(in: second))
    let other = try #require(coordinator.panels.present(.palette, from: otherOrigin))
    f.window.close()
    #expect(coordinator.registration(for: f.window) == nil)
    #expect(coordinator.invocation(in: f.window) == nil)
    let executed = coordinator.execute(.zoomIn, invocation: captured)
    #expect(executed == false); #expect(runs == 0)
    #expect(first.panel == nil)
    #expect(coordinator.panels.sessions.count == 1)
    #expect(coordinator.panels.sessions.first === other)
    coordinator.panels.close(other, restore: false)
}

@MainActor
@Test func independentWindowsCanCompleteTheirOwnDeferredFocusRequests() async throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    let second = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    second.isReleasedWhenClosed = false; defer { second.close() }
    coordinator.register(window: second, token: UUID(), scope: .main)
    let firstTarget = CommandPaneResponderView(frame: .zero), secondTarget = CommandPaneResponderView(frame: .zero)
    f.window.contentView!.addSubview(firstTarget); second.contentView!.addSubview(secondTarget)
    firstTarget.configure(coordinator: coordinator, scope: .archiveSidebar, handlers: [:])
    secondTarget.configure(coordinator: coordinator, scope: .archiveSidebar, handlers: [:])
    // Let unrelated initial mount requests settle, then exercise explicit requests.
    try await Task.sleep(for: .milliseconds(20))
    f.window.makeFirstResponder(f.review); second.makeFirstResponder(nil)
    coordinator.requestFocus(scope: .archiveSidebar, in: f.window)
    coordinator.requestFocus(scope: .archiveSidebar, in: second)
    try await Task.sleep(for: .milliseconds(20))
    #expect(f.window.firstResponder === firstTarget)
    #expect(second.firstResponder === secondTarget)
    f.window.makeFirstResponder(f.review)
    coordinator.requestFocus(scope: .archiveSidebar, in: f.window)
    secondTarget.removeFromSuperview()
    try await Task.sleep(for: .milliseconds(20))
    #expect(f.window.firstResponder === firstTarget)
}

@MainActor
@Test func deferredFocusCannotTransferToAReplacementSurface() async throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    let original = CommandPaneResponderView(frame: .zero), replacement = CommandPaneResponderView(frame: .zero)
    f.window.contentView!.addSubview(original)
    let token = UUID()
    let old = CommandSurfaceLease(view: original, token: token, scope: .archiveSidebar, active: true, supports: { _ in false }, availability: { _ in false }, run: { _ in false })
    coordinator.register(old)
    coordinator.requestFocus(scope: .archiveSidebar, in: f.window)
    original.removeFromSuperview(); f.window.contentView!.addSubview(replacement)
    let new = CommandSurfaceLease(view: replacement, token: token, scope: .archiveSidebar, active: true, supports: { _ in false }, availability: { _ in false }, run: { _ in false })
    coordinator.register(new)
    try await Task.sleep(for: .milliseconds(20))
    #expect(f.window.firstResponder === f.review)
}


@MainActor
@Test func paletteCompositionKeepsCandidateKeysAndCannotRunDuringShortcutCapture() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    var runs = 0; f.review.onZoomIn = { runs += 1 }
    coordinator.execute(.palette, in: f.window)
    let session = try #require(coordinator.panels.current), panel = try #require(session.panel)
    session.highlighted = .zoomIn
    let editor = NSTextView(frame: NSRect(x: 10, y: 10, width: 250, height: 100))
    panel.contentView!.addSubview(editor); panel.makeFirstResponder(editor)
    editor.setMarkedText("候", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    #expect(editor.hasMarkedText())
    for capturing in [false, true] {
        session.capturing = capturing ? .zoomIn : nil
        for (key, code) in [("\r", UInt16(36)), ("\u{f700}", UInt16(126)), ("\u{f701}", UInt16(125)), ("\u{1b}", UInt16(53))] {
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 1,
                windowNumber: panel.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code)!
            let claimed = coordinator.handle(event, in: panel)
            #expect(claimed == false)
            #expect(session.highlighted == .zoomIn); #expect(runs == 0)
            #expect(session.panel === panel)
        }
    }
}

@MainActor
@Test func globalAndPanelOverridesCannotCaptureTypingOrNativeEditChords() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let cases: [(AppCommandID, AppShortcut)] = [(.toggleSidebar, .init(key: "b")), (.keyboardHelp, .init(key: "c", modifiers: [.command])),
        (.paletteRun, .init(key: "b")), (.closeCommandPanel, .init(key: "space")), (.palette, .init(key: "e", modifiers: [.control]))]
    for (id, shortcut) in cases {
        let saved = f.state.setCommandShortcut(id, override: .init(shortcut: shortcut))
        #expect(saved == false)
        #expect(f.state.commandShortcutSaveError != nil)
        let restored = AppCommandRegistry(overrides: [id.rawValue: .init(shortcut: shortcut)])
        #expect(restored.bindings(id).isEmpty)
    }
    let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 240, height: 100))
    f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor)
    let event = f.event("b")
    #expect(f.state.commandCoordinator.handle(event, in: f.window) == false)
    editor.keyDown(with: event)
    #expect(editor.string == "b")
}


@MainActor
@Test func reviewCommandUsesItsOwnedPhotoSelectionAfterAnotherWindowFocusesSidebar() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let items = (0..<3).map { makeTestMediaItem(sourceRoot: f.root, fileName: "Owned-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, workspaceSourceFolder: f.root, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    let node = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })
    f.state.selectedSidebarNodeID = node.id; f.state.selectedMediaItemIDs = [items[0].id]; f.state.focusedReviewItemID = items[0].id
    f.state.activateReviewGridFocus()
    f.review.onSingleKey = { key in f.state.performReviewShortcut(key) }
    let second = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    second.isReleasedWhenClosed = false; defer { second.close() }
    f.state.commandCoordinator.register(window: second, token: UUID(), scope: .main)
    f.state.commandCoordinator.execute(.focusSidebar, in: second)
    #expect(f.state.activePane == .sidebar)
    #expect(f.state.reviewGridHasFocus == false)
    // SwiftUI redraws both windows from the shared flag, while A still owns focus.
    f.review.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: false)
    #expect(f.window.firstResponder === f.review)
    #expect(f.window.performKeyEquivalent(with: f.event("s")))
    let changed = try #require(f.state.currentSession)
    #expect(changed.mediaItems[0].selectionState == .included)
    #expect(changed.mediaItems[1].selectionState == .undecided)
    #expect(changed.mediaItems[2].selectionState == .undecided)
}


@MainActor
@Test func ownedFormCommandsPreserveNewlinesRebindAndRespectDisabledConfirm() throws {
    let form = try #require(AppCommandScope(rawValue: "form"))
    let formEditor = try #require(AppCommandScope(rawValue: "formEditor"))
    let confirm = try #require(AppCommandID(rawValue: "confirmSheet")), close = try #require(AppCommandID(rawValue: "closeSheet"))
    let f = try NativeCommandFixture(scope: form); defer { f.close() }
    var saves = 0, cancels = 0, enabled = true
    let surface = CommandPaneResponderView(frame: NSRect(x: 10, y: 10, width: 300, height: 200))
    f.window.contentView!.addSubview(surface)
    let lease = CommandSurfaceLease(view: surface, token: UUID(), scope: form, active: true,
        supports: { $0 == confirm || $0 == close }, availability: { $0 == close || enabled },
        run: { id in if id == confirm { saves += 1 } else { cancels += 1 }; return true })
    f.state.commandCoordinator.register(lease)
    let editor = NSTextView(frame: NSRect(x: 10, y: 10, width: 240, height: 120)); editor.string = "Notes"
    surface.addSubview(editor); f.window.makeFirstResponder(editor); editor.setSelectedRange(NSRange(location: 5, length: 0))
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == formEditor)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36)) == false)
    editor.keyDown(with: f.event("\r", code: 36)); #expect(editor.string == "Notes\n")
    #expect(saves == 0)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command])))
    #expect(saves == 1)
    enabled = false
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command])))
    #expect(saves == 1)
    enabled = true
    let rebound = f.state.setCommandShortcut(confirm, override: .init(shortcut: .init(key: "y", modifiers: [.command, .option])))
    #expect(rebound)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command])) == false)
    #expect(f.window.performKeyEquivalent(with: f.event("y", modifiers: [.command, .option])))
    #expect(saves == 2)
    let closeRebound = f.state.setCommandShortcut(close, override: .init(shortcut: .init(key: "escape", modifiers: [.command, .option])))
    #expect(closeRebound)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53)) == false)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53, modifiers: [.command, .option])))
    #expect(cancels == 1)
    #expect(f.state.commandCoordinator.registry.bindings(try #require(AppCommandID(rawValue: "confirmGoogleDelivery"))).isEmpty)
}


@MainActor
@Test func dismantledSheetClosesOnlyItsOwnedCommandPanels() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    f.anchor.unregisterWindow()
    let anchor = CommandSheetAnchorView(frame: .zero); f.window.contentView!.addSubview(anchor)
    anchor.configure(coordinator: coordinator, scope: .form, actions: [.closeSheet: .init(run: {})])
    let origin = try #require(coordinator.invocation(in: f.window))
    let sheetPanel = try #require(coordinator.panels.present(.help, from: origin))
    let second = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
    second.isReleasedWhenClosed = false; defer { second.close() }
    coordinator.register(window: second, token: UUID(), scope: .main)
    let otherOrigin = try #require(coordinator.invocation(in: second))
    let other = try #require(coordinator.panels.present(.palette, from: otherOrigin))
    anchor.unregister()
    #expect(coordinator.isCurrent(origin) == false)
    #expect(sheetPanel.panel == nil)
    #expect(coordinator.panels.sessions.count == 1)
    #expect(coordinator.panels.sessions.first === other)
    coordinator.panels.close(other, restore: false)
}

@MainActor
@Test func formCannotConfirmWhileInputCompositionIsUncommitted() throws {
    let f = try NativeCommandFixture(scope: .form); defer { f.close() }
    f.anchor.unregisterWindow()
    var saved = 0
    let anchor = CommandSheetAnchorView(frame: .zero); f.window.contentView!.addSubview(anchor)
    anchor.configure(coordinator: f.state.commandCoordinator, scope: .form, actions: [.confirmSheet: .init(run: { saved += 1 })])
    let editor = NSTextView(frame: NSRect(x: 10, y: 10, width: 250, height: 120)); f.window.contentView!.addSubview(editor); f.window.makeFirstResponder(editor)
    editor.setMarkedText("候", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    #expect(editor.hasMarkedText())
    let claimed = f.state.commandCoordinator.handle(f.event("\r", code: 36, modifiers: [.command]), in: f.window)
    #expect(claimed == false); #expect(saved == 0)
}

@MainActor
@Test func contextualPaletteIncludesActualFolderAndPhotoLogCommands() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let entry = ArchiveBrowseEntry(id: "historical", kind: .unorganisedFolder, year: "2019", archiveRelativePath: "2019/historical", title: "Historical", startDate: nil, endDate: nil, location: nil, photoCount: 0, walkCount: 0, coverThumbnailPath: nil)
    f.state.testingInstallArchiveCatalogue(.init(entries: [entry], walksByTripPath: [:], photos: []))
    f.state.selectArchiveEntry(entry.id)
    let pane = CommandPaneResponderView(frame: .zero); f.window.contentView!.addSubview(pane)
    pane.configure(coordinator: f.state.commandCoordinator, scope: .archiveCards, handlers: [:]); f.window.makeFirstResponder(pane)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    let panel = try #require(f.state.commandCoordinator.panels.present(.contextual, from: origin))
    #expect(panel.commands.contains { $0.id == .organiseFolder })
    #expect(f.state.commandCoordinator.unavailableReason(.organiseFolder, invocation: origin) == nil)
    #expect(panel.commands.contains { $0.id == .moveWalk })
    #expect(panel.commands.contains { $0.id == .createPhotoLog })
    panel.query = "organise trip"
    #expect(panel.commands.map(\.id) == [.organiseFolder])
}

@MainActor
@Test func generatedHintsResolveScopedOverridesAndUnassignedCommands() throws {
    let f = try NativeCommandFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    #expect(coordinator.registry.displayedShortcuts(.markIncluded, scope: .preview).contains("S"))
    let rebound = f.state.setCommandShortcut(.markIncluded, override: .init(shortcut: .init(key: "y", modifiers: [.command, .option])))
    #expect(rebound)
    #expect(coordinator.registry.displayedShortcuts(.markIncluded, scope: .preview) == "⌥⌘Y")
    #expect(coordinator.registry.displayedShortcuts(.markIncluded, scope: .editor) == "Unassigned")
    let unbound = f.state.setCommandShortcut(.markIncluded, override: .init(shortcut: nil)); #expect(unbound)
    #expect(coordinator.registry.displayedShortcuts(.markIncluded, scope: .preview) == "Unassigned")
    #expect(coordinator.registry.displayedShortcuts(.groupDays, scope: .review) == "Unassigned")
    #expect(coordinator.registry.displayedShortcuts(.focusSidebar, scope: .review) == "⌃⌘1")
    #expect(coordinator.registry.displayedShortcuts(.confirmSheet, scope: .formEditor) == "⌘↩")
    #expect(coordinator.registry.displayedShortcuts(.confirmSheet, scope: .form).contains("↩"))
}


@MainActor
@Test func sourceAndSettingsActionsAreDiscoverableKeylessAndUseOwnedDispatch() throws {
    let groups: [(AppCommandScope, [String])] = [(.main, ["chooseHistoricalSource", "openDefaultSource", "reloadSource", "showCamera", "showPhotoLogs", "showArchive", "showArchiveMap", "retryArchiveSearch", "retryArchiveFolderLoad", "openSelectedFolderInFinder", "toggleHistoricalDateSource"]),
        (.settings, ["importSyncedPhotoLogs", "refreshDescriptionModels", "chooseOneDrivePictures", "useArchiveForOneDrivePictures"])]
    for (scope, names) in groups {
        let f = try NativeCommandFixture(scope: scope); defer { f.close() }
        let ids = try names.map { try #require(AppCommandID(rawValue: $0)) }
        let surface = CommandPaneResponderView(frame: .zero); f.window.contentView!.addSubview(surface)
        var ran: [AppCommandID] = []
        let lease = CommandSurfaceLease(view: surface, token: UUID(), scope: scope, active: true,
            supports: { ids.contains($0) }, availability: { _ in true }, run: { ran.append($0); return true })
        f.state.commandCoordinator.register(lease); f.window.makeFirstResponder(surface)
        for id in ids {
            #expect(f.state.commandCoordinator.registry.bindings(id).isEmpty)
            let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
            let palette = try #require(f.state.commandCoordinator.panels.present(.palette, from: origin))
            #expect(palette.commands.contains { $0.id == id })
            #expect(f.state.commandCoordinator.unavailableReason(id, invocation: origin) == nil)
            palette.highlighted = id; f.state.commandCoordinator.panels.runHighlighted(palette)
            #expect(ran.last == id)
            #expect(f.state.commandCoordinator.panels.sessions.isEmpty)
        }
        #expect(ran == ids)
    }
}
