import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
@Test func inlineEditorsOwnSharedFieldEditorCommandsAndInvalidateChangedDrafts() throws {
    let logScope = try #require(AppCommandScope(rawValue: "logDetails"))
    let editingScope = try #require(AppCommandScope(rawValue: "logDetailsEditor"))
    let save = try #require(AppCommandID(rawValue: "saveLogDetails"))
    _ = NSApplication.shared
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    var settings = AppSettings.default(); settings.archiveRoot = root; settings.oneDrivePicturesRoot = root
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root)
    let coordinator = state.commandCoordinator; coordinator.presentsPanels = false
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 240), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let token = UUID(); coordinator.register(window: window, token: token, scope: .main)
    defer { coordinator.unregisterWindow(token); window.close() }
    let a = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 200)), b = NSView(frame: NSRect(x: 230, y: 0, width: 220, height: 200))
    window.contentView!.addSubview(a); window.contentView!.addSubview(b)
    let fieldA = NSTextField(string: "Log A draft"), fieldB = NSTextField(string: "Log B draft")
    fieldA.frame = NSRect(x: 10, y: 10, width: 200, height: 30); fieldB.frame = fieldA.frame
    a.addSubview(fieldA); b.addSubview(fieldB)
    var saved: [String] = []
    let leaseA = CommandSurfaceLease(view: a, token: UUID(), scope: logScope, active: true, supports: { $0 == save }, availability: { _ in true }, run: { _ in saved.append("A"); return true })
    let leaseB = CommandSurfaceLease(view: b, token: UUID(), scope: logScope, active: true, supports: { $0 == save }, availability: { _ in true }, run: { _ in saved.append("B"); return true })
    coordinator.register(leaseA); coordinator.register(leaseB)
    fieldA.selectText(nil)
    let originA = try #require(coordinator.invocation(in: window))
    #expect(originA.scope == editingScope); #expect(originA.lease === leaseA)
    fieldB.selectText(nil)
    let originB = try #require(coordinator.invocation(in: window))
    #expect(originB.scope == editingScope); #expect(originB.lease === leaseB)
    #expect(!coordinator.execute(save, invocation: originA)); #expect(coordinator.execute(save, invocation: originB))
    #expect(saved == ["B"])
    let editor = try #require(fieldB.currentEditor() as? NSTextView)
    let beforeEdit = try #require(coordinator.invocation(in: window))
    editor.insertText(" revised", replacementRange: NSRange(location: editor.string.utf16.count, length: 0))
    #expect(!coordinator.execute(save, invocation: beforeEdit)); #expect(saved == ["B"])
    #expect(!window.isVisible)
}

@MainActor
final class LocalSurfaceFixture {
    let root: URL, state: AppState, window: NSWindow, token = UUID()
    init() throws {
        _ = NSApplication.shared
        root = try makeTemporaryDirectory()
        var settings = AppSettings.default(); settings.archiveRoot = root; settings.oneDrivePicturesRoot = root
        state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root)
        state.commandCoordinator.presentsPanels = false
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 260), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        state.commandCoordinator.register(window: window, token: token, scope: .main)
    }
    func close() {
        state.commandCoordinator.unregisterWindow(token); window.close()
        try? FileManager.default.removeItem(at: root)
    }
    func event(_ key: String, code: UInt16 = 0, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 1,
            windowNumber: window.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code)!
    }
}

@MainActor
@Test func localButtonAndPaletteCapabilitiesRejectTargetRoundTripsAndModalOverlays() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let surface = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 180))
    f.window.contentView!.addSubview(surface)
    var saved: [String] = []
    let old = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A|draft1",
        actions: [.saveLogDetails: .init(run: { saved.append("old A") })])
    f.window.makeFirstResponder(surface)
    let oldOrigin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "B|draft2",
        actions: [.saveLogDetails: .init(run: { saved.append("B") })])
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A|draft1",
        actions: [.saveLogDetails: .init(run: { saved.append("new A") })])
    old.run(.saveLogDetails)
    #expect(!f.state.commandCoordinator.execute(.saveLogDetails, invocation: oldOrigin)); #expect(saved.isEmpty)
    fresh.run(.saveLogDetails); #expect(saved == ["new A"])
    let overlay = ReviewKeyResponderView(frame: .zero); f.window.contentView!.addSubview(overlay)
    overlay.configureCommands(coordinator: f.state.commandCoordinator, scope: .compare, focused: true)
    fresh.run(.saveLogDetails); #expect(saved == ["new A"])
    overlay.removeFromSuperview()
    surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A|draft1",
        actions: [.saveLogDetails: .init(enabled: false, run: { saved.append("disabled") })])
    fresh.run(.saveLogDetails); #expect(saved == ["new A"])
    #expect(!f.window.isVisible)
}

@MainActor
@Test func clickedLocalButtonUsesItsOwnTargetWhileAnotherEditorHasFocus() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 220, height: 180))
    let b = CommandLocalSurfaceView(frame: NSRect(x: 230, y: 0, width: 220, height: 180))
    f.window.contentView!.addSubview(a); f.window.contentView!.addSubview(b)
    var saved: [String] = []
    a.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A", actions: [.saveLogDetails: .init(run: { saved.append("A") })])
    let buttonB = b.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "B", actions: [.saveLogDetails: .init(run: { saved.append("B") })])
    let fieldA = NSTextField(string: "Keep typing in A"); fieldA.frame = NSRect(x: 5, y: 10, width: 200, height: 28); a.addSubview(fieldA)
    fieldA.selectText(nil)
    buttonB.run(.saveLogDetails); #expect(saved == ["B"])
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command])))
    #expect(saved == ["B", "A"])
}

@MainActor
@Test func everyInlineEditorPreservesNativeTypingAndRejectsComposingDraftCommands() throws {
    let scopes: [(AppCommandScope, AppCommandScope, AppCommandID)] = [(.logDetails, .logDetailsEditor, .saveLogDetails), (.location, .locationEditor, .saveLocation), (.tripLabel, .tripLabelEditor, .saveTripLabel)]
    for (scope, editing, save) in scopes {
        let f = try LocalSurfaceFixture(); defer { f.close() }
        let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(surface)
        var count = 0
        surface.configure(coordinator: f.state.commandCoordinator, scope: scope, contextKey: "draft", actions: [save: .init(run: { count += 1 }), .saveLogAndStartNext: .init(run: { count += 10 })])
        let editor = NSTextView(frame: NSRect(x: 10, y: 10, width: 240, height: 100)); editor.string = "Notes"; surface.addSubview(editor)
        f.window.makeFirstResponder(editor); editor.setSelectedRange(NSRange(location: 5, length: 0))
        #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == editing)
        #expect(!f.window.performKeyEquivalent(with: f.event("\r", code: 36)))
        editor.keyDown(with: f.event("\r", code: 36)); #expect(editor.string == "Notes\n")
        #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command]))); #expect(count == 1)
        let registry = f.state.commandCoordinator.registry
        for chord in [AppShortcut(key: "s"), AppShortcut(key: "c", modifiers: [.command])] {
            #expect(registry.validate(.init(shortcut: chord), for: save) != nil)
            #expect(AppCommandRegistry(overrides: [save.rawValue: .init(shortcut: chord)]).bindings(save).isEmpty)
        }
        editor.setMarkedText("composing", selectedRange: NSRange(location: 1, length: 0), replacementRange: editor.selectedRange())
        let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
        #expect(!f.state.commandCoordinator.execute(save, invocation: origin))
        if scope == .logDetails { #expect(!f.state.commandCoordinator.execute(.saveLogAndStartNext, invocation: origin)) }
        #expect(count == 1)
        editor.unmarkText()
        let fresh = try #require(f.state.commandCoordinator.invocation(in: f.window))
        #expect(f.state.commandCoordinator.execute(save, invocation: fresh)); #expect(count == 2)
    }
}

@MainActor
@Test func nestedLocalEditorOwnsCommandsIndependentOfAncestorRegistrationOrder() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let outer = NSView(frame: f.window.contentView!.bounds), inner = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 250, height: 180))
    f.window.contentView!.addSubview(outer); outer.addSubview(inner)
    var saved = 0
    inner.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "Log A", actions: [.saveLogDetails: .init(run: { saved += 1 })])
    let outerLease = CommandSurfaceLease(view: outer, token: UUID(), scope: .sourceSidebar, active: true, supports: { _ in false }, availability: { _ in false }, run: { _ in false })
    f.state.commandCoordinator.register(outerLease)
    let field = NSTextField(string: "A draft"); field.frame = NSRect(x: 10, y: 10, width: 200, height: 30); inner.addSubview(field); field.selectText(nil)
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == .logDetailsEditor)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command]))); #expect(saved == 1)
}

@MainActor
@Test func reattachedLocalSurfaceRebuildsVisibleButtonCapabilities() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(surface)
    var rendered: LocalCommandHandle?, saved = 0
    surface.renderContent = { rendered = $0; return AnyView(Text("Save Log")) }
    surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A", actions: [.saveLogDetails: .init(run: { saved += 1 })])
    let prior = try #require(rendered)
    surface.removeFromSuperview(); f.window.contentView!.addSubview(surface)
    prior.run(.saveLogDetails); #expect(saved == 0)
    let current = try #require(rendered); current.run(.saveLogDetails); #expect(saved == 1)
    f.window.makeFirstResponder(surface)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command]))); #expect(saved == 2)
}

@MainActor
@Test func retainedLogDraftCannotSaveIntoAReplacementCurrentLog() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: [], sessionKind: .walkDraft)
    let b = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: [], sessionKind: .walkDraft)
    f.state.currentSession = b
    f.state.updateWalkMetadata(title: "A's draft", location: "A's location", notes: "A's notes", sessionID: a.id)
    #expect(f.state.currentSession?.id == b.id); #expect(f.state.currentSession?.walkMetadata == b.walkMetadata)
    f.state.saveCurrentLogDetailsAndStartNext(title: "A's draft", location: "A's location", notes: "A's notes", sessionID: a.id)
    #expect(f.state.currentSession?.id == b.id); #expect(f.state.currentSession?.walkMetadata == b.walkMetadata)
    f.state.updateWalkMetadata(title: "B's draft", location: "B's location", notes: "B's notes", sessionID: b.id)
    #expect(f.state.currentSession?.walkMetadata.title == "B's draft")
    #expect(f.state.currentSession?.walkMetadata.location == "B's location")
}

@MainActor
@Test func windowControlsCannotBypassAnActiveModalSurface() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let original = f.state.workspaceMode
    let compare = ReviewKeyResponderView(frame: .zero); f.window.contentView!.addSubview(compare)
    compare.configureCommands(coordinator: f.state.commandCoordinator, scope: .compare, focused: true)
    #expect(!f.state.commandCoordinator.executeWindowControl(.showPhotoLogs, in: f.window))
    #expect(f.state.workspaceMode == original)
    compare.removeFromSuperview()
    #expect(f.state.commandCoordinator.executeWindowControl(.showPhotoLogs, in: f.window))
    #expect(f.state.workspaceMode == .photoLogs)
}

@MainActor
@Test func localButtonAuthorityDoesNotSurviveAnArchiveRootRoundTrip() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(surface)
    var count = 0
    let actions: [AppCommandID: SheetCommandAction] = [.saveLogDetails: .init(run: { count += 1 })]
    let old = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "same Log and draft", actions: actions)
    let initial = f.state.settings
    var changed = initial; changed.archiveRoot = f.root.appendingPathComponent("other-root")
    f.state.settings = changed; f.state.settings = initial
    old.run(.saveLogDetails); #expect(count == 0)
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "same Log and draft", actions: actions)
    fresh.run(.saveLogDetails); #expect(count == 1)
}

@MainActor
@Test func localButtonRetainsTheOriginalWindowRegistrationIncludingLateRegistration() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(surface)
    f.state.commandCoordinator.unregisterWindow(f.token)
    var count = 0
    let actions: [AppCommandID: SheetCommandAction] = [.saveLogDetails: .init(run: { count += 1 })]
    let old = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A", actions: actions)
    f.state.commandCoordinator.register(window: f.window, token: f.token, scope: .main)
    old.run(.saveLogDetails); #expect(count == 1)
    f.state.commandCoordinator.unregisterWindow(f.token)
    f.state.commandCoordinator.register(window: f.window, token: f.token, scope: .main)
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A", actions: actions)
    old.run(.saveLogDetails); #expect(count == 1)
    fresh.run(.saveLogDetails); #expect(count == 2)
}

@MainActor
private final class LocalLayoutDraft: ObservableObject { @Published var notes = "Short notes" }

@MainActor
private struct LocalLayoutFixtureView: View {
    let state: AppState
    @ObservedObject var draft: LocalLayoutDraft
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CommandLocalSurface(coordinator: state.commandCoordinator, scope: .photoLogActions, contextKey: "Log A",
                actions: [.deletePhotoLog: .init(run: {})]) { commands in
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 6)], spacing: 6) {
                    Button("Continue") {}; Button("Contents") {}; Button("Details") {}
                    Button("Edit Log") {}; Button("Add Marked") {}; Button("Delete") { commands.run(.deletePhotoLog) }
                }.buttonStyle(.bordered).controlSize(.small)
            }
            CommandLocalSurface(coordinator: state.commandCoordinator, scope: .logDetails, contextKey: draft.notes,
                actions: [.saveLogDetails: .init(run: {})]) { commands in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Title", text: .constant("A Photo Log"))
                    TextField("Location", text: .constant("A place"))
                    TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(4...8)
                    Button("Save Log Details") { commands.run(.saveLogDetails) }.buttonStyle(.bordered)
                }
            }
        }.padding(12)
    }
}

@MainActor
@Test func hiddenInlineEditorLayoutFitsAdaptiveButtonsAndWrappedNotesAtNarrowWidths() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let draft = LocalLayoutDraft()
    for width in [260.0, 320.0, 420.0] {
        let host = NSHostingView(rootView: LocalLayoutFixtureView(state: f.state, draft: draft).frame(width: width, alignment: .leading))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 600)
        f.window.contentView!.addSubview(host)
        defer { host.removeFromSuperview() }
        var heights: [CGFloat] = []
        for notes in ["Short notes", Array(repeating: "These are deliberately long notes that need several lines in this narrow editor.", count: 8).joined(separator: " ")] {
            draft.notes = notes
            try await Task.sleep(for: .milliseconds(30))
            host.layoutSubtreeIfNeeded()
            func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
                (view as? CommandLocalSurfaceView).map { [$0] } ?? view.subviews.flatMap(surfaces)
            }
            let locals = surfaces(host)
            #expect(locals.count == 2)
            for local in locals {
                #expect(local.bounds.width > 200)
                #expect(local.bounds.height >= 40)
                #expect(local.host.fittingSize.height <= local.bounds.height + 1)
                #expect(local.convert(local.bounds, to: host).maxY <= host.bounds.maxY + 1)
            }
            heights.append(locals.last?.bounds.height ?? 0)
        }
        #expect(heights[1] > heights[0])
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try data.write(to: URL(fileURLWithPath: "/private/tmp/walkfolio-inline-layout-\(Int(width)).png"))
            }
        }
        #expect(!f.window.isVisible)
    }
}

@MainActor
@Test func retainedTripLabelButtonCannotEditAReplacementCanonicalTripAtTheSamePath() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(surface)
    var trip = ArchiveBrowseEntry(id: "same-path", kind: .trip, year: "2026", archiveRelativePath: "2026/10/Trip", title: "Trip",
        startDate: nil, endDate: nil, location: "Same label", photoCount: 0, walkCount: 1, coverThumbnailPath: nil, tripID: UUID(), locationLabelOverride: "Same label")
    var saved: [UUID] = []
    let oldID = try #require(trip.tripID)
    let old = surface.configure(coordinator: f.state.commandCoordinator, scope: .tripLabel,
        contextKey: tripLabelCommandContextKey(root: f.root, trip: trip, draft: "Same label", isEditing: true),
        actions: [.saveTripLabel: .init(run: { saved.append(oldID) })])
    trip.tripID = UUID(); let newID = try #require(trip.tripID)
    let fresh = surface.configure(coordinator: f.state.commandCoordinator, scope: .tripLabel,
        contextKey: tripLabelCommandContextKey(root: f.root, trip: trip, draft: "Same label", isEditing: true),
        actions: [.saveTripLabel: .init(run: { saved.append(newID) })])
    old.run(.saveTripLabel); #expect(saved.isEmpty)
    fresh.run(.saveTripLabel); #expect(saved == [newID])
}

@MainActor
@Test func hiddenInlineEditorsCannotReceiveRetainedButtonsOrKeyboardCommands() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let container = NSView(frame: f.window.contentView!.bounds), surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    f.window.contentView!.addSubview(container); container.addSubview(surface)
    var count = 0
    let handle = surface.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "A", actions: [.saveLogDetails: .init(run: { count += 1 })])
    f.window.makeFirstResponder(surface)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    container.isHidden = true
    handle.run(.saveLogDetails); #expect(count == 0)
    #expect(!f.state.commandCoordinator.execute(.saveLogDetails, invocation: origin)); #expect(count == 0)
    container.isHidden = false
    handle.run(.saveLogDetails); #expect(count == 1)
}

@MainActor @Test func settingsRootAndBackupCommandsAreAvailableWithoutBorrowingMainWindowScope() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    coordinator.unregisterWindow(f.token); coordinator.register(window: f.window, token: f.token, scope: .settings)
    let origin = try #require(coordinator.invocation(in: f.window))
    for id: AppCommandID in [.chooseArchiveRoot, .exportBackup, .importBackup, .descriptionQueue] {
        #expect(AppCommandRegistry.definition(id).scopes.contains(.settings))
        #expect(AppCommandRegistry.definition(id).scopes.contains(.settingsEditor))
        #expect(coordinator.unavailableReason(id, invocation: origin) == nil)
    }
    let chooseDefault = try #require(AppCommandID(rawValue: "chooseDefaultSourceRoot"))
    #expect(coordinator.unavailableReason(chooseDefault, invocation: origin) == nil)
    let editor = NSTextView(frame: NSRect(x: 10, y: 10, width: 250, height: 100)); editor.string = "Backup and model settings"; f.window.contentView!.addSubview(editor)
    f.window.makeFirstResponder(editor)
    #expect(!f.window.performKeyEquivalent(with: f.event("a", modifiers: [.command])))
    #expect(!f.window.isVisible)
}

@MainActor @Test func settingsFieldEditorRetainsItsActualLocalCommandOwner() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let coordinator = f.state.commandCoordinator
    coordinator.unregisterWindow(f.token); coordinator.register(window: f.window, token: f.token, scope: .settings)
    let surface = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(surface)
    var openedLocally = 0
    surface.configure(coordinator: coordinator, scope: .settings, contextKey: "Local AI tab", actions: [.descriptionQueue: .init(run: { openedLocally += 1 })])
    let field = NSTextField(string: "Model draft"); field.frame = NSRect(x: 10, y: 10, width: 240, height: 28); surface.addSubview(field); field.selectText(nil)
    let origin = try #require(coordinator.invocation(in: f.window)); #expect(origin.scope == .settingsEditor); #expect(origin.lease != nil)
    let assigned = f.state.setCommandShortcut(.descriptionQueue, override: .init(shortcut: .init(key: "n", modifiers: [.command, .option]))); #expect(assigned)
    #expect(f.window.performKeyEquivalent(with: f.event("n", modifiers: [.command, .option])))
    #expect(openedLocally == 1); #expect(!f.state.showDescriptionQueue)
    #expect(!f.window.performKeyEquivalent(with: f.event("a", modifiers: [.command])))
}

@MainActor @Test func actualDescriptionQueueContainsSelectableTextAndOwnsItsCloseCommand() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; f.state.commandCoordinator.unregisterWindow(f.token)
    f.window.setContentSize(NSSize(width: 800, height: 560)); var closed = false
    let host = NSHostingView(rootView: DescriptionQueueView(appState: f.state, onClose: { closed = true }))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host); host.layoutSubtreeIfNeeded()
    func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] { ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(surfaces) }
    let surface = try #require(surfaces(host).first)
    let text = NSTextView(frame: NSRect(x: 20, y: 20, width: 240, height: 80)); text.string = "Selectable saved description"; text.isEditable = false; text.isSelectable = true; surface.addSubview(text)
    f.window.makeFirstResponder(text)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(origin.scope == .information); #expect(origin.lease?.view === surface)
    #expect(f.state.commandCoordinator.unavailableReason(.resumeDescriptions, invocation: origin) == nil)
    #expect(f.state.commandCoordinator.unavailableReason(.cancelDescriptions, invocation: origin) != nil)
    #expect(!f.window.performKeyEquivalent(with: f.event("a", modifiers: [.command])))
    #expect(!f.window.performKeyEquivalent(with: f.event("c", modifiers: [.command])))
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53))); #expect(closed)
    #expect(!f.window.isVisible); host.removeFromSuperview()
}

@MainActor @Test func actualDescriptionSettingsUsesAvailableHeightAndCapturesItsLocalSurface() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    f.state.commandCoordinator.unregisterWindow(f.token); f.state.commandCoordinator.register(window: f.window, token: f.token, scope: .settings)
    f.window.setContentSize(NSSize(width: 580, height: 380))
    let host = NSHostingView(rootView: DescriptionSettingsView(appState: f.state))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host); host.layoutSubtreeIfNeeded()
    func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] { ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(surfaces) }
    let surface = try #require(surfaces(host).first)
    #expect(surface.bounds.height >= 370 && surface.bounds.height <= 390)
    #expect(surface.bounds.width >= 570 && surface.bounds.width <= 590)
    let field = NSTextField(string: "Local AI model"); field.frame = NSRect(x: 10, y: 10, width: 240, height: 28); surface.addSubview(field); field.selectText(nil)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(origin.scope == .settingsEditor); #expect(origin.lease?.view === surface)
    #expect(f.state.commandCoordinator.unavailableReason(.descriptionQueue, invocation: origin) == nil)
    #expect(!f.window.isVisible); host.removeFromSuperview()
}
