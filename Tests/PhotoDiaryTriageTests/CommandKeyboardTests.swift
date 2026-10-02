import AppKit
import Foundation
import Testing
@testable import PhotoDiaryTriage

@MainActor private func keyboardFixture() -> (NSWindow, ReviewKeyResponderView) {
    _ = NSApplication.shared
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 240), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ReviewKeyResponderView(frame: window.contentView!.bounds)
    window.contentView!.addSubview(view); view.isHandlingKeys = true
    window.makeFirstResponder(view)
    #expect(!window.isVisible)
    return (window, view)
}

private func keyboardEvent(_ window: NSWindow, key: String, keyCode: UInt16 = 0, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 1,
        windowNumber: window.windowNumber, context: nil, characters: key,
        charactersIgnoringModifiers: key, isARepeat: false, keyCode: keyCode)!
}

@MainActor
@Test func nativeReviewResponderDoesNotConsumeModifiedTextMovement() {
    let (window, view) = keyboardFixture(); defer { window.close() }
    var moves = 0, groups = 0
    view.onArrow = { _, _, _ in moves += 1 }; view.onSectionArrow = { _, _ in groups += 1 }
    for modifiers: NSEvent.ModifierFlags in [[.command], [.command, .shift], [.control], [.command, .control]] {
        view.keyDown(with: keyboardEvent(window, key: "\u{f700}", keyCode: 126, modifiers: modifiers))
    }
    #expect(moves == 0); #expect(groups == 0)
}

@MainActor
@Test func nativeReviewResponderDoesNotMatchCommandSelectAllWithExtraModifiers() {
    let (window, view) = keyboardFixture(); defer { window.close() }
    var selections = 0, opens = 0
    view.onSelectAll = { selections += 1 }; view.onCommandOpen = { opens += 1 }
    view.keyDown(with: keyboardEvent(window, key: "a", modifiers: [.command, .control]))
    view.keyDown(with: keyboardEvent(window, key: "\r", keyCode: 36, modifiers: [.control]))
    #expect(selections == 0); #expect(opens == 0)
}

@MainActor
@Test func staleReviewResponderCannotMutateSelectionWhileEditorOwnsFocus() {
    let (window, view) = keyboardFixture(); defer { window.close() }
    let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
    editor.string = "Notes remain in the editor"; window.contentView!.addSubview(editor)
    #expect(window.makeFirstResponder(editor))
    var selections = 0; view.onSelectAll = { selections += 1 }
    // A queued callback/update can leave isHandlingKeys stale; actual ownership wins.
    view.keyDown(with: keyboardEvent(window, key: "a", modifiers: [.command]))
    #expect(selections == 0); #expect(window.firstResponder === editor)
}

@MainActor
@Test func commandRegistryHasCompleteReservedDefaultsAndNoCollisions() throws {
    let registry = AppCommandRegistry()
    #expect(Set(AppCommandRegistry.commands.map(\.id)) == Set(AppCommandID.allCases))
    #expect(AppCommandRegistry.commands.allSatisfy { !$0.title.isEmpty && !$0.task.isEmpty && !$0.scopes.isEmpty })
    #expect(registry.collisions().isEmpty)
    for (shortcut, id) in AppCommandRegistry.reserved {
        #expect(registry.bindings(id).contains { $0.shortcut == shortcut })
    }
    for shortcut in AppCommandRegistry.reservedUnbound {
        #expect(AppCommandID.allCases.allSatisfy { id in !registry.bindings(id).contains { $0.shortcut == shortcut } })
    }
}

@MainActor
@Test func commandOverrideReplacesEveryAliasAndExplicitUnboundSurvivesReload() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = SettingsStore(fileURL: root.appendingPathComponent("settings.json"))
    let state = AppState(testing: true, testingSupportRoot: root, testingSettingsStore: store)
    let custom = AppShortcut(key: "p", modifiers: [.command, .option])
    #expect(state.setCommandShortcut(.toggleInspector, override: .init(shortcut: custom)))
    #expect(AppCommandRegistry(overrides: state.settings.commandShortcutOverrides).bindings(.toggleInspector).map(\.shortcut) == [custom])
    #expect(state.setCommandShortcut(.toggleInspector, override: .init(shortcut: nil)))
    let restored = try store.loadBackupSnapshot(defaults: .default())
    #expect(restored.commandShortcutOverrides[AppCommandID.toggleInspector.rawValue] != nil)
    #expect(AppCommandRegistry(overrides: restored.commandShortcutOverrides).bindings(.toggleInspector).isEmpty)
    #expect(state.setCommandShortcut(.toggleInspector, override: nil))
    #expect(AppCommandRegistry(overrides: state.settings.commandShortcutOverrides).bindings(.toggleInspector).count == 2)
}

private final class KeyboardFailingSettingsStore: SettingsPersisting {
    func load(defaults: @autoclosure () -> AppSettings) -> AppSettings { defaults() }
    func loadBackupSnapshot(defaults: AppSettings) throws -> AppSettings { defaults }
    func save(_ settings: AppSettings) throws { throw CocoaError(.fileWriteOutOfSpace) }
}

@MainActor
@Test func failedShortcutSaveDoesNotChangeDispatchOrDiscardUnknownOverrides() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    var initial = AppSettings.default(); initial.commandShortcutOverrides["future.command"] = .init(shortcut: .init(key: "z", modifiers: [.command, .option]))
    let state = AppState(testing: true, testingSettings: initial, testingSupportRoot: root, testingSettingsStore: KeyboardFailingSettingsStore())
    let saved = state.setCommandShortcut(.toggleInspector, override: .init(shortcut: nil))
    #expect(saved == false)
    #expect(state.settings.commandShortcutOverrides == initial.commandShortcutOverrides)
    #expect(state.commandShortcutSaveError != nil)
}

@MainActor
@Test func shortcutRebindingRejectsReservedCollisionsAndNativeNavigation() {
    let registry = AppCommandRegistry()
    #expect(registry.validate(.init(shortcut: .init(key: "p", modifiers: [.command, .shift])), for: .cleanupSource) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "k", modifiers: [.command, .shift])), for: .cleanupSource) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "1", modifiers: [.command, .control])), for: .groupDays) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "up", modifiers: [.command, .shift])), for: .groupDays) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "right", modifiers: [.control])), for: .groupDays) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "y", modifiers: [.command, .option, .shift, .control])), for: .groupDays) != nil)
}

@Test func legacyKeyboardSettingsDecodeAndUnknownSchemaRoundTrip() throws {
    let legacy = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
    #expect(legacy.commandShortcutSchemaVersion == 1); #expect(legacy.commandShortcutOverrides.isEmpty)
    var future = legacy; future.commandShortcutSchemaVersion = 9
    future.commandShortcutOverrides["future.command"] = .init(shortcut: nil)
    let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(future))
    #expect(decoded.commandShortcutSchemaVersion == 9)
    #expect(decoded.commandShortcutOverrides == future.commandShortcutOverrides)
}

@MainActor
@Test func resetToDefaultDoesNotDisplaceAnExistingUserBinding() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    var settings = AppSettings.default(); settings.archiveRoot = root; settings.oneDrivePicturesRoot = root
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root)
    let unassigned = state.setCommandShortcut(.zoomIn, override: .init(shortcut: nil)); #expect(unassigned)
    let assigned = state.setCommandShortcut(.zoomOut, override: .init(shortcut: .init(key: "="))); #expect(assigned)
    let previous = state.settings.commandShortcutOverrides
    let reset = state.setCommandShortcut(.zoomIn, override: nil)
    #expect(reset == false); #expect(state.settings.commandShortcutOverrides == previous)
    #expect(state.commandShortcutSaveError != nil)
}

@MainActor
@Test func restoredChordCanonicalisationAndAmbiguityAreSafe() throws {
    let data = Data("{\"key\":\"A\",\"modifiers\":6}".utf8)
    let shortcut = try JSONDecoder().decode(AppShortcut.self, from: data)
    #expect(shortcut.key == "a")
    #expect(AppShortcut(key: "\r").isValid == false)
    #expect(AppShortcut(key: "up", modifiers: [.command, .control]).isValid)
    let overrides: [String:AppShortcutOverride] = [AppCommandID.zoomOut.rawValue: .init(shortcut: .init(key: "="))]
    let registry = AppCommandRegistry(overrides: overrides)
    let (window, _) = keyboardFixture(); defer { window.close() }
    #expect(registry.command(for: keyboardEvent(window, key: "="), scope: .review) == nil)
    #expect(!registry.collisions().isEmpty)
}
