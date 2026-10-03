import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor private final class MenuWindowBox { weak var window: NSWindow? }
@MainActor private final class StandardMenuTarget: NSObject, NSMenuDelegate {
    var calls = 0
    @objc func run(_ sender: Any?) { calls += 1 }
}

/// Detached AppKit menu, injected hidden window. Never replaces NSApp.mainMenu.
@MainActor private final class NativeMenuFixture {
    let local: LocalSurfaceFixture
    let windowBox = MenuWindowBox()
    let root = NSMenu(title: "Fixture")
    let commands = NSMenu(title: "Walkfolio commands")
    let standard = StandardMenuTarget()
    let controller: CommandNativeMenus
    let review = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 240, height: 220))
    var calls: [AppCommandID] = []
    var items: [AppCommandID: NSMenuItem] = [:]
    init(_ ids: Set<AppCommandID>) throws {
        local = try LocalSurfaceFixture()
        windowBox.window = local.window
        let box = windowBox
        controller = CommandNativeMenus(coordinator: local.state.commandCoordinator, commandIDs: ids,
            windowProvider: { [weak box] in box?.window },
            placements: Dictionary(uniqueKeysWithValues: ids.map { ($0, "Walkfolio commands") }))
        local.state.commandCoordinator.nativeMenus = controller
        local.state.activePane = .media
        local.window.contentView!.addSubview(review)
        review.configure(coordinator: local.state.commandCoordinator, scope: .review, contextKey: "Review",
            actions: Dictionary(uniqueKeysWithValues: [AppCommandID.markIncluded, .toggleRAW, .selectAll, .deselectAll, .nextGroup].map { id in
                (id, SheetCommandAction(run: { [weak self] in self?.calls.append(id) }))
            }))
        local.window.makeFirstResponder(review)
        let parent = NSMenuItem(title: "Walkfolio commands", action: nil, keyEquivalent: ""); parent.submenu = commands; root.addItem(parent)
        for id in ids.sorted(by: { $0.rawValue < $1.rawValue }) {
            let item = generated(id); commands.addItem(item); items[id] = item
        }
        controller.attach(to: root)
    }
    func generated(_ id: AppCommandID) -> NSMenuItem {
        let item = NSMenuItem(title: AppCommandRegistry.definition(id).title, action: #selector(StandardMenuTarget.run(_:)), keyEquivalent: "")
        item.target = standard; return item
    }
    func item(_ id: AppCommandID) throws -> NSMenuItem { try #require(items[id]) }
    func send(_ id: AppCommandID) throws { commands.performActionForItem(at: commands.index(of: try item(id))) }
    func field(outsideReview: Bool = true) -> NSTextField {
        let field = NSTextField(string: "Native text selection")
        field.frame = NSRect(x: outsideReview ? 260 : 10, y: 10, width: 180, height: 28)
        (outsideReview ? local.window.contentView! : review.host).addSubview(field)
        field.selectText(nil); return field
    }
    func notify(_ name: Notification.Name) { NotificationCenter.default.post(name: name, object: commands) }
    func close() { local.close(); #expect(!local.window.isVisible) }
}

@MainActor @Test func nativeMenusFollowFieldEditorFocusWithoutAnAppStateRedraw() throws {
    let f = try NativeMenuFixture([.markIncluded, .toggleRAW]); defer { f.close() }
    let coordinator = f.local.state.commandCoordinator, mark = try f.item(.markIncluded)
    let before = CommandSelectionFingerprint(f.local.state)
    f.commands.update(); #expect(mark.isEnabled); #expect(mark.keyEquivalent == "i")
    let field = f.field(); let editor = try #require(field.currentEditor() as? NSTextView)
    f.commands.update()
    #expect(CommandSelectionFingerprint(f.local.state) == before)
    #expect(!mark.isEnabled); #expect(mark.keyEquivalent.isEmpty)
    #expect(!coordinator.handle(f.local.event("a", modifiers: [.command]), in: f.local.window))
    #expect(!coordinator.handle(f.local.event("c", modifiers: [.command]), in: f.local.window))
    let edit = NSMenu(title: "Edit"), select = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    select.target = editor; select.keyEquivalentModifierMask = [.command]; edit.addItem(select)
    #expect(edit.performKeyEquivalent(with: f.local.event("a", modifiers: [.command])))
    #expect(editor.selectedRange().length == editor.string.utf16.count)
    f.local.window.makeFirstResponder(f.review); f.commands.update()
    #expect(mark.isEnabled); #expect(mark.keyEquivalent == "i")
    try f.send(.markIncluded); #expect(f.calls == [.markIncluded])
}

@MainActor @Test func nativeMenusAndDiscoveryUseExplicitContainingReviewBindings() throws {
    for scope: AppCommandScope in [.reviewItem, .reviewGroup] {
        let f = try NativeMenuFixture([.markIncluded, .toggleRAW]); defer { f.close() }
        let row = CommandLocalSurfaceView(frame: NSRect(x: 5, y: 5, width: 180, height: 100)); f.review.host.addSubview(row)
        row.configure(coordinator: f.local.state.commandCoordinator, scope: scope, contextKey: "Child", actions: [:])
        f.local.window.makeFirstResponder(row); f.commands.update()
        let origin = try #require(f.local.state.commandCoordinator.invocation(in: f.local.window))
        #expect(origin.scope == scope)
        #expect(try f.item(.markIncluded).keyEquivalent == "i")
        #expect(f.local.state.commandCoordinator.effectiveShortcutLabel(.markIncluded, invocation: origin).contains("I"))
        try f.send(.markIncluded); #expect(f.calls == [.markIncluded])
        let field = f.field(outsideReview: false)
        #expect(field.currentEditor() != nil); f.commands.update()
        #expect(try f.item(.markIncluded).keyEquivalent.isEmpty)
        #expect(try f.item(.markIncluded).isEnabled == false)
    }
}

@MainActor @Test func nativeMenusDoNotBorrowReviewBindingsAcrossCompareBoundary() throws {
    let f = try NativeMenuFixture([.nextGroup]); defer { f.close() }
    let compare = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 220, height: 150)); f.review.host.addSubview(compare)
    compare.configure(coordinator: f.local.state.commandCoordinator, scope: .compare, contextKey: "Compare", actions: [:])
    f.local.window.makeFirstResponder(compare); f.commands.update()
    let origin = try #require(f.local.state.commandCoordinator.invocation(in: f.local.window))
    #expect(origin.scope == .compare); #expect(try f.item(.nextGroup).keyEquivalent.isEmpty)
    #expect(try f.item(.nextGroup).isEnabled == false)
    #expect(f.local.state.commandCoordinator.effectiveShortcutLabel(.nextGroup, invocation: origin) == "Available in another pane")
    try f.send(.nextGroup); #expect(f.calls.isEmpty)
}

@MainActor @Test func nativeMenusShowSaveAndContainingConfirmInAChildFieldEditor() throws {
    let f = try NativeMenuFixture([.saveLogDetails, .confirmSheet]); defer { f.close() }
    let coordinator = f.local.state.commandCoordinator
    let form = CommandLocalSurfaceView(frame: f.local.window.contentView!.bounds); f.local.window.contentView!.addSubview(form)
    var saves = 0, confirms = 0
    form.configure(coordinator: coordinator, scope: .form, contextKey: "Form", actions: [.confirmSheet: .init(run: { confirms += 1 })])
    let child = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 240, height: 150)); form.host.addSubview(child)
    child.configure(coordinator: coordinator, scope: .logDetails, contextKey: "Draft", actions: [.saveLogDetails: .init(run: { saves += 1 })])
    #expect(f.local.state.setCommandShortcut(.saveLogDetails, override: .init(shortcut: .init(key: "n", modifiers: [.command, .option]))))
    let field = NSTextField(string: "Draft"); field.frame = NSRect(x: 5, y: 5, width: 200, height: 28); child.host.addSubview(field); field.selectText(nil)
    f.commands.update()
    #expect(try f.item(.saveLogDetails).keyEquivalent == "n")
    #expect(try f.item(.confirmSheet).keyEquivalent == "\r")
    #expect(try f.item(.confirmSheet).keyEquivalentModifierMask == [.command])
    try f.send(.saveLogDetails); try f.send(.confirmSheet)
    #expect(saves == 1); #expect(confirms == 1)
}

@MainActor @Test func nativeMenuKeysRefreshBeforeDispatchAfterRebindUnassignAndDefaults() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    let coordinator = f.local.state.commandCoordinator, item = try f.item(.markIncluded)
    #expect(item.keyEquivalent == "i")
    #expect(f.local.state.setCommandShortcut(.markIncluded, override: .init(shortcut: .init(key: "y", modifiers: [.command, .option]))))
    // Actual registered-window dispatch refreshes the native item before fallback.
    #expect(!f.local.window.performKeyEquivalent(with: f.local.event("i", modifiers: [.command])))
    #expect(item.keyEquivalent == "y"); #expect(item.keyEquivalentModifierMask == [.command, .option])
    #expect(!f.root.performKeyEquivalent(with: f.local.event("i", modifiers: [.command])))
    #expect(f.root.performKeyEquivalent(with: f.local.event("y", modifiers: [.command, .option])))
    #expect(f.calls == [.markIncluded])
    #expect(f.local.state.setCommandShortcut(.markIncluded, override: .init(shortcut: nil)))
    #expect(!f.local.window.performKeyEquivalent(with: f.local.event("y", modifiers: [.command, .option])))
    #expect(item.keyEquivalent.isEmpty); #expect(!f.root.performKeyEquivalent(with: f.local.event("y", modifiers: [.command, .option])))
    #expect(f.local.state.setCommandShortcut(.markIncluded, override: nil))
    #expect(!coordinator.handle(f.local.event("q", modifiers: [.command, .option]), in: f.local.window))
    #expect(item.keyEquivalent == "i"); #expect(item.keyEquivalentModifierMask == [.command])
    #expect(f.root.performKeyEquivalent(with: f.local.event("i", modifiers: [.command]))); #expect(f.calls.count == 2)
    #expect(!f.controller.isTracking)
}

@MainActor @Test func nativeAdoptionPreservesStandardMenusTargetsDelegatesAndFlags() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    let edit = NSMenu(title: "Edit"); edit.delegate = f.standard; edit.autoenablesItems = false
    let parent = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); parent.submenu = edit; f.root.addItem(parent)
    let copy = NSMenuItem(title: "Copy", action: #selector(StandardMenuTarget.run(_:)), keyEquivalent: "c")
    copy.target = f.standard; copy.identifier = .init("native.copy"); copy.keyEquivalentModifierMask = [.command]; copy.isEnabled = true
    let represented = NSObject(); copy.representedObject = represented; edit.addItem(copy)
    f.commands.autoenablesItems = false; f.commands.delegate = f.standard
    for _ in 0..<5 { f.controller.refresh(); f.commands.update() }
    #expect(edit.delegate === f.standard); #expect(f.commands.delegate === f.standard)
    #expect(!edit.autoenablesItems); #expect(!f.commands.autoenablesItems)
    #expect(copy.target === f.standard); #expect(copy.action == #selector(StandardMenuTarget.run(_:)))
    #expect(copy.identifier?.rawValue == "native.copy"); #expect(copy.representedObject as AnyObject? === represented)
    #expect(copy.keyEquivalent == "c"); #expect(copy.keyEquivalentModifierMask == [.command]); #expect(copy.isEnabled)
    #expect(f.root.performKeyEquivalent(with: f.local.event("c", modifiers: [.command]))); #expect(f.standard.calls == 1)
    #expect(try f.item(.markIncluded).target === f.controller)
}

@MainActor @Test func nativeAdoptionHandlesReplacementAndStableIdentityIdempotently() async throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    let prior = try f.item(.markIncluded); let index = f.commands.index(of: prior)
    f.commands.removeItem(prior)
    let replacement = f.generated(.markIncluded); f.commands.insertItem(replacement, at: index)
    try await Task.sleep(for: .milliseconds(40))
    #expect(replacement.target === f.controller)
    #expect(replacement.identifier?.rawValue == CommandNativeMenus.identifierPrefix + AppCommandID.markIncluded.rawValue)
    replacement.title = "Reviewed selection: include"
    for _ in 0..<5 { f.controller.refresh() }
    #expect(replacement.title == "Reviewed selection: include"); #expect(replacement.keyEquivalent == "i")
    #expect(replacement.target === f.controller); #expect(prior !== replacement)
    #expect(!f.local.window.isVisible)
}

@MainActor @Test func nativeAdoptionRefusesAmbiguousTitlesForeignIdentifiersAndOtherOwners() throws {
    for foreign in 0..<3 {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        let root = NSMenu(title: "Fixture"), menu = NSMenu(title: "Triage"), target = StandardMenuTarget()
        let parent = NSMenuItem(title: "Triage", action: nil, keyEquivalent: ""); parent.submenu = menu; root.addItem(parent)
        let item = NSMenuItem(title: AppCommandRegistry.definition(.markIncluded).title, action: #selector(StandardMenuTarget.run(_:)), keyEquivalent: ""); item.target = target; menu.addItem(item)
        let controller = CommandNativeMenus(coordinator: f.state.commandCoordinator, commandIDs: [.markIncluded], windowProvider: { f.window })
        var other: CommandNativeMenus?
        if foreign == 0 { menu.addItem(NSMenuItem(title: item.title, action: nil, keyEquivalent: "")) }
        if foreign == 1 { item.identifier = .init("foreign.owner") }
        if foreign == 2 {
            other = CommandNativeMenus(coordinator: f.state.commandCoordinator, commandIDs: [.markIncluded], windowProvider: { f.window })
            other!.attach(to: root)
        }
        let originalTarget = item.target, originalAction = item.action, originalID = item.identifier
        controller.attach(to: root); controller.refresh()
        #expect(item.target === originalTarget); #expect(item.action == originalAction); #expect(item.identifier == originalID)
        #expect(item.target !== controller)
        withExtendedLifetime(other) {}
    }
}

@MainActor @Test func trackingMenuCapturesItsWindowAndRefusesSwitchesAndNewRegistrations() throws {
    for change in 0..<3 {
        let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
        let other = try LocalSurfaceFixture(); defer { other.close() }
        f.notify(NSMenu.didBeginTrackingNotification); #expect(f.controller.isTracking)
        if change == 0 { f.windowBox.window = other.window }
        if change == 1 { f.local.state.commandCoordinator.unregisterWindow(f.local.token) }
        if change == 2 {
            f.local.state.commandCoordinator.unregisterWindow(f.local.token)
            f.local.state.commandCoordinator.register(window: f.local.window, token: f.local.token, scope: .main)
        }
        // AppKit can end tracking before delivering the selected menu action.
        f.notify(NSMenu.didEndTrackingNotification); #expect(!f.controller.isTracking)
        f.commands.update(); #expect(try f.item(.markIncluded).isEnabled == false)
        try f.send(.markIncluded); #expect(f.calls.isEmpty)
        f.notify(NSMenu.didSendActionNotification)
    }
}

@MainActor @Test func trackingMenuRejectsSelectionAndLeaseReplacementAndOwnsNavigation() throws {
    for change in 0..<2 {
        let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
        f.notify(NSMenu.didBeginTrackingNotification)
        #expect(!f.local.state.commandCoordinator.handle(f.local.event("i", modifiers: [.command]), in: f.local.window)); #expect(f.calls.isEmpty)
        if change == 0 { f.local.state.selectedMediaItemIDs = [UUID()] }
        else { f.review.configure(coordinator: f.local.state.commandCoordinator, scope: .review, contextKey: "Replacement", actions: [.markIncluded: .init(run: { f.calls.append(.markIncluded) })]) }
        f.notify(NSMenu.didEndTrackingNotification)
        try f.send(.markIncluded); #expect(f.calls.isEmpty)
    }
}

@MainActor @Test func cancelledMenuReleasesItsCaptureAtTheNextMenuOrKey() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    f.notify(NSMenu.didBeginTrackingNotification); f.notify(NSMenu.didEndTrackingNotification)
    f.local.state.selectedMediaItemIDs = [UUID()]
    #expect(f.local.window.performKeyEquivalent(with: f.local.event("i", modifiers: [.command]))); #expect(f.calls.count == 1)
    f.notify(NSMenu.didBeginTrackingNotification)
    f.local.state.selectedMediaItemIDs = [UUID()]; f.notify(NSMenu.didEndTrackingNotification)
    f.notify(NSMenu.didBeginTrackingNotification); try f.send(.markIncluded)
    #expect(f.calls.count == 2)
    f.notify(NSMenu.didSendActionNotification); f.notify(NSMenu.didEndTrackingNotification)
    #expect(!f.controller.isTracking)
}

@MainActor @Test func nativeMenusFailClosedForUnknownAndClosedWindowsButAllowWindowlessSettings() throws {
    let f = try NativeMenuFixture([.markIncluded, .settings]); defer { f.close() }
    let unknown = try LocalSurfaceFixture(); defer { unknown.close() }
    f.local.window.close(); f.commands.update()
    #expect(try f.item(.markIncluded).isEnabled == false); #expect(!f.controller.perform(.markIncluded))
    f.windowBox.window = unknown.window; f.commands.update()
    #expect(try f.item(.markIncluded).isEnabled == false); #expect(try f.item(.settings).isEnabled == false)
    try f.send(.markIncluded); #expect(f.calls.isEmpty)
    var settings = 0; f.controller.settingsOpener = { settings += 1 }
    f.windowBox.window = nil; f.commands.update()
    #expect(try f.item(.settings).isEnabled); #expect(try f.item(.settings).keyEquivalent == ",")
    try f.send(.settings); #expect(settings == 1)
    #expect(try f.item(.markIncluded).keyEquivalent.isEmpty)
}

@MainActor @Test func effectiveHelpDistinguishesScopedAliasesUnavailablePanesAndUnassignedCommands() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    let coordinator = f.local.state.commandCoordinator
    let origin = try #require(coordinator.invocation(in: f.local.window))
    let help = try #require(coordinator.panels.present(.help, from: origin)); defer { coordinator.panels.close(help, restore: false) }
    let bindings = coordinator.effectiveBindings(.open, invocation: help.origin)
    #expect(bindings.allSatisfy { $0.scopes.contains(.review) })
    #expect(coordinator.effectiveShortcutLabel(.open, invocation: help.origin) == bindings.map(\.shortcut.display).joined(separator: " · "))
    #expect(coordinator.effectiveShortcutLabel(.panLeft, invocation: help.origin) == "Available in another pane")
    #expect(f.local.state.setCommandShortcut(.markIncluded, override: .init(shortcut: nil)))
    #expect(coordinator.effectiveShortcutLabel(.markIncluded, invocation: help.origin) == "Unassigned")
    #expect(help.commands.contains { $0.id == .markIncluded }); #expect(!help.panel!.isVisible)
}

@MainActor @Test func contextualDiscoveryIncludesDisplayedRAWGroupRetryAndCropControls() throws {
    let scopes: [(AppCommandScope, [AppCommandID])] = [
        (.reviewItem, [.includeDisplayedRAW, .excludeDisplayedRAW, .retryDisplayedThumbnail]),
        (.reviewGroup, [.compareDisplayedGroup, .toggleDisplayedGroup, .focusDisplayedGroup]),
        (.cropVersion, [.showCropVersion])
    ]
    for (scope, ids) in scopes {
        let f = try NativeMenuFixture([]); defer { f.close() }
        let row = CommandLocalSurfaceView(frame: NSRect(x: 5, y: 5, width: 180, height: 100)); f.review.host.addSubview(row)
        row.configure(coordinator: f.local.state.commandCoordinator, scope: scope, contextKey: "Exact target",
            actions: Dictionary(uniqueKeysWithValues: ids.map { ($0, SheetCommandAction(run: {})) }))
        f.local.window.makeFirstResponder(row)
        let origin = try #require(f.local.state.commandCoordinator.invocation(in: f.local.window))
        let session = try #require(f.local.state.commandCoordinator.panels.present(.contextual, from: origin))
        #expect(Set(ids).isSubset(of: Set(session.commands.map(\.id))))
        for id in ids { #expect(f.local.state.commandCoordinator.unavailableReason(id, invocation: session.origin) == nil) }
        f.local.state.commandCoordinator.panels.close(session, restore: false)
    }
}

@MainActor @Test func unadoptedNativePlaceholderRetainsTrackingOriginAndFailsAfterOwnerSwitch() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    // A duplicate label deliberately prevents the new item from being adopted.
    let duplicate = f.generated(.markIncluded); f.commands.addItem(duplicate)
    f.notify(NSMenu.didBeginTrackingNotification)
    let other = try LocalSurfaceFixture(); defer { other.close() }
    let coordinator = f.local.state.commandCoordinator
    coordinator.register(window: other.window, token: other.token, scope: .main)
    defer { coordinator.unregisterWindow(other.token) }
    let review = CommandLocalSurfaceView(frame: other.window.contentView!.bounds); other.window.contentView!.addSubview(review)
    var borrowed = 0
    review.configure(coordinator: coordinator, scope: .review, contextKey: "Other Review", actions: [.markIncluded: .init(run: { borrowed += 1 })])
    other.window.makeFirstResponder(review)
    f.windowBox.window = other.window
    f.notify(NSMenu.didEndTrackingNotification)
    #expect(!f.controller.perform(.markIncluded)); #expect(f.calls.isEmpty); #expect(borrowed == 0)
    f.notify(NSMenu.didSendActionNotification); f.windowBox.window = f.local.window
    #expect(f.controller.perform(.markIncluded)); #expect(f.calls == [.markIncluded])
}

@MainActor @Test func nativeAdoptionLeavesUniqueGeneratedTitlesInUnrelatedMenusUntouched() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let root = NSMenu(title: "Root"), unrelated = NSMenu(title: "Third-party tools"), target = StandardMenuTarget()
    let parent = NSMenuItem(title: "Third-party tools", action: nil, keyEquivalent: ""); parent.submenu = unrelated; root.addItem(parent)
    let item = NSMenuItem(title: AppCommandRegistry.definition(.markIncluded).title, action: #selector(StandardMenuTarget.run(_:)), keyEquivalent: "u")
    item.target = target; unrelated.addItem(item)
    let originalID = item.identifier
    let controller = CommandNativeMenus(coordinator: f.state.commandCoordinator, commandIDs: [.markIncluded], windowProvider: { f.window })
    controller.attach(to: root)
    #expect(item.target === target); #expect(item.identifier == originalID); #expect(item.keyEquivalent == "u")
    #expect(item.action == #selector(StandardMenuTarget.run(_:)))
}

@MainActor @Test func nestedMenuTrackingDoesNotRecaptureAfterAChildMenuEnds() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    let child = NSMenu(title: "Child"), sibling = NSMenu(title: "Sibling")
    for menu in [child, sibling] {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: ""); item.submenu = menu; f.commands.addItem(item)
    }
    f.notify(NSMenu.didBeginTrackingNotification)
    NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: child)
    NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: child)
    #expect(f.controller.isTracking)
    f.local.state.selectedMediaItemIDs = [UUID()]
    NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: sibling)
    #expect(!f.controller.perform(.markIncluded)); #expect(f.calls.isEmpty)
    NotificationCenter.default.post(name: NSMenu.didSendActionNotification, object: child)
    #expect(!f.controller.perform(.markIncluded)); #expect(f.calls.isEmpty)
    NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: sibling)
    f.notify(NSMenu.didEndTrackingNotification); #expect(!f.controller.isTracking)
    #expect(f.local.window.performKeyEquivalent(with: f.local.event("i", modifiers: [.command])))
    #expect(f.calls == [.markIncluded])
}

@MainActor @Test func nativeMenuCaptureWithoutALeaseRejectsChangedFirstResponder() throws {
    let f = try NativeMenuFixture([.settings]); defer { f.close() }
    f.review.unregister(); f.local.window.makeFirstResponder(f.local.window)
    var opened = 0; f.controller.settingsOpener = { opened += 1 }
    f.notify(NSMenu.didBeginTrackingNotification)
    let field = f.field(); #expect(field.currentEditor() != nil)
    f.notify(NSMenu.didEndTrackingNotification)
    #expect(!f.controller.perform(.settings)); #expect(opened == 0)
    f.notify(NSMenu.didSendActionNotification)
    #expect(f.controller.perform(.settings)); #expect(opened == 1)
}

@MainActor @Test func nativeMenuRefreshStaysResponsiveWithLargeReviewAndMountedRows() throws {
    let f = try NativeMenuFixture(PhotoDiaryCommands.nativeCommandIDs); defer { f.close() }
    let photos = (0..<30_000).map { makeTestMediaItem(sourceRoot: f.local.root, fileName: "Menu-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    f.local.state.currentSession = makeTestSession(sourceRoot: f.local.root, archiveRoot: f.local.root, items: photos, sessionKind: .inbox)
    f.local.state.setWorkspaceMode(.cameraTriage)
    f.local.state.focusedReviewItemID = photos[0].id; f.local.state.selectedMediaItemIDs = [photos[0].id]
    for i in 0..<100 {
        let row = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 120, height: 80)); f.review.host.addSubview(row)
        row.configure(coordinator: f.local.state.commandCoordinator, scope: .reviewItem, contextKey: "Row \(i)", actions: [:])
    }
    for selectAll in [false, true] {
        f.local.state.selectedMediaItemIDs = selectAll ? Set(photos.map(\.id)) : [photos[0].id]
        f.review.configure(coordinator: f.local.state.commandCoordinator, scope: .review,
            contextKey: reviewPaneCommandContextKey(f.local.state),
            actions: reviewPaneCommandActions(f.local.state, showMap: .constant(false)))
        f.local.window.makeFirstResponder(f.review)
        f.controller.refresh()
        let clock = ContinuousClock(), start = clock.now
        for _ in 0..<100 {
            #expect(!f.local.state.commandCoordinator.handle(f.local.event("q", modifiers: [.command, .option]), in: f.local.window))
        }
        let elapsed = start.duration(to: clock.now)
        print("Native menus: 30,000 photos, 100 mounted rows, production Review, selected \(selectAll ? 30_000 : 1), 100 unclaimed keys: \(elapsed)")
        #expect(elapsed < .seconds(3))
    }
}

@MainActor @Test func detachedTrackedMenuStillReleasesKeyboardOwnershipWhenItsRootIsReplaced() throws {
    let f = try NativeMenuFixture([.markIncluded]); defer { f.close() }
    f.notify(NSMenu.didBeginTrackingNotification)
    let replacement = NSMenu(title: "Replacement"), menu = NSMenu(title: "Walkfolio commands")
    let parent = NSMenuItem(title: "Walkfolio commands", action: nil, keyEquivalent: ""); parent.submenu = menu; replacement.addItem(parent)
    menu.addItem(f.generated(.markIncluded)); f.controller.attach(to: replacement)
    f.notify(NSMenu.didEndTrackingNotification)
    #expect(!f.controller.isTracking)
    #expect(f.local.window.performKeyEquivalent(with: f.local.event("i", modifiers: [.command])))
    #expect(f.calls == [.markIncluded]); #expect(!f.local.window.isVisible)
}
