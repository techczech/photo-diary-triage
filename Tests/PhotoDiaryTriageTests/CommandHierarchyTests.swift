import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
@Test func containingModalKeepsTheFocusedChildAndExplicitParentCommands() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let parent = NSView(frame: f.window.contentView!.bounds), row = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 260, height: 180))
    f.window.contentView!.addSubview(parent); parent.addSubview(row)
    var saved = 0, confirmed = 0, closed = 0
    let parentLease = CommandSurfaceLease(view: parent, token: UUID(), scope: .form, active: true,
        supports: { [.confirmSheet, .closeSheet].contains($0) }, availability: { _ in true }, run: { id in
            if id == .confirmSheet { confirmed += 1 } else { closed += 1 }; return true
        })
    f.state.commandCoordinator.register(parentLease)
    row.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "row B",
        actions: [.saveLogDetails: .init(run: { saved += 1 })])
    let rebound = f.state.setCommandShortcut(.saveLogDetails, override: .init(shortcut: .init(key: "n", modifiers: [.command, .option])))
    #expect(rebound)
    let field = NSTextField(string: "B draft"); field.frame = NSRect(x: 10, y: 10, width: 230, height: 28); row.addSubview(field); field.selectText(nil)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(origin.scope == .logDetailsEditor)
    #expect(f.window.performKeyEquivalent(with: f.event("n", modifiers: [.command, .option]))); #expect(saved == 1)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command]))); #expect(confirmed == 1)
    #expect(!f.window.performKeyEquivalent(with: f.event("\r", code: 36)))
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53))); #expect(closed == 1)
}

@MainActor
@Test func disabledChildActionBlocksAnEnabledContainingFormAction() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    let child = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 220, height: 150))
    f.window.contentView!.addSubview(parent)
    var closed = 0
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan",
        actions: [.closeSheet: .init(run: { closed += 1 })])
    parent.addSubview(child)
    child.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "disabled row",
        actions: [.closeSheet: .init(enabled: false, run: { closed += 100 })])
    f.window.makeFirstResponder(child)
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53)))
    #expect(closed == 0)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(f.state.commandCoordinator.unavailableReason(.closeSheet, invocation: origin) != nil)
}

@MainActor
@Test func replacedParentInvalidatesRetainedChildButtonsAndPaletteWithoutChangingChild() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let rebound = f.state.setCommandShortcut(.saveLogDetails, override: .init(shortcut: .init(key: "n", modifiers: [.command, .option])))
    #expect(rebound)
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    let child = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 220, height: 150))
    f.window.contentView!.addSubview(parent)
    var saved = 0, confirmed = 0
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan A",
        actions: [.confirmSheet: .init(run: { confirmed += 1 })])
    parent.addSubview(child)
    let old = child.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "unchanged child",
        actions: [.saveLogDetails: .init(run: { saved += 1 })])
    f.window.makeFirstResponder(child)
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
    let session = try #require(f.state.commandCoordinator.panels.present(.contextual, from: origin))
    #expect(session.commands.contains { $0.id == .confirmSheet })
    session.highlighted = .saveLogDetails
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan B",
        actions: [.confirmSheet: .init(run: { confirmed += 10 })])
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan A",
        actions: [.confirmSheet: .init(run: { confirmed += 100 })])
    old.run(.saveLogDetails); f.state.commandCoordinator.panels.runHighlighted(session)
    #expect(saved == 0); #expect(confirmed == 0); #expect(session.error != nil)
    #expect(!f.state.commandCoordinator.execute(.confirmSheet, invocation: origin))
    f.state.commandCoordinator.panels.close(session, restore: false)
    let fresh = child.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "unchanged child",
        actions: [.saveLogDetails: .init(run: { saved += 1 })])
    fresh.run(.saveLogDetails); #expect(saved == 1)
    let current = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(f.state.commandCoordinator.execute(.confirmSheet, invocation: current)); #expect(confirmed == 100)
}

@MainActor
@Test func containingWindowRegistrationSurvivesDraftReplacementAndKeepsChildKeys() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    f.state.commandCoordinator.unregisterWindow(f.token)
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    f.window.contentView!.addSubview(parent)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan 0", actions: [:], ownsWindow: true)
    let ownerID = try #require(f.state.commandCoordinator.registration(for: f.window)?.instanceID)
    let child = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 200, height: 140)); parent.addSubview(child)
    var saved = 0
    let old = child.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "child",
        actions: [.saveLogDetails: .init(run: { saved += 1 })])
    let field = NSTextField(string: "child draft"); field.frame = NSRect(x: 5, y: 5, width: 180, height: 28); child.addSubview(field); field.selectText(nil)
    for i in 1...3 {
        parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan \(i)", actions: [:], ownsWindow: true)
        #expect(f.state.commandCoordinator.registration(for: f.window)?.instanceID == ownerID)
        old.run(.saveLogDetails)
        #expect(saved == i - 1)
        #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command])))
        #expect(saved == i)
    }
    parent.unregister()
}

@MainActor
@Test func reparentedChildCannotInheritANewFormsAuthorityOrASiblingHandler() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let rebound = f.state.setCommandShortcut(.saveLogDetails, override: .init(shortcut: .init(key: "n", modifiers: [.command, .option])))
    #expect(rebound)
    let outer = NSView(frame: f.window.contentView!.bounds), a = CommandLocalSurfaceView(frame: outer.bounds)
    f.window.contentView!.addSubview(outer); outer.addSubview(a)
    var confirmed = 0, saved = 0, sibling = 0
    a.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "A", actions: [.confirmSheet: .init(run: { confirmed += 1 })])
    let child = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 150, height: 120)); a.addSubview(child)
    let old = child.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "row", actions: [.saveLogDetails: .init(run: { saved += 1 })])
    let b = CommandLocalSurfaceView(frame: outer.bounds); outer.addSubview(b)
    b.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "B", actions: [.confirmSheet: .init(run: { confirmed += 10 })])
    b.addSubview(child)
    old.run(.confirmSheet); old.run(.saveLogDetails); #expect(confirmed == 0); #expect(saved == 0)
    let side = CommandLocalSurfaceView(frame: NSRect(x: 170, y: 10, width: 150, height: 120)); b.addSubview(side)
    side.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "sibling", actions: [.saveLogAndStartNext: .init(run: { sibling += 1 })])
    f.window.makeFirstResponder(child)
    let fresh = try #require(f.state.commandCoordinator.invocation(in: f.window))
    #expect(!f.state.commandCoordinator.execute(.saveLogAndStartNext, invocation: fresh)); #expect(sibling == 0)
    #expect(f.state.commandCoordinator.execute(.confirmSheet, invocation: fresh)); #expect(confirmed == 10)
}

@MainActor
@Test func rowCommandsRejectContainingFormCollisionsAndRestoredConflictsFailClosed() throws {
    let merge = try #require(AppCommandID(rawValue: "mergeWalkProposal"))
    let rowScope = try #require(AppCommandScope(rawValue: "walkProposal"))
    let editorScope = try #require(AppCommandScope(rawValue: "walkProposalEditor"))
    let registry = AppCommandRegistry()
    #expect(registry.validate(.init(shortcut: .init(key: "return", modifiers: [.command])), for: merge) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "n")), for: merge) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "c", modifiers: [.command])), for: merge) != nil)
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
    var count = 0
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: "plan", actions: [.confirmSheet: .init(run: { count += 10 })])
    let row = CommandLocalSurfaceView(frame: NSRect(x: 10, y: 10, width: 200, height: 150)); parent.addSubview(row)
    row.configure(coordinator: f.state.commandCoordinator, scope: rowScope, contextKey: "row", actions: [merge: .init(run: { count += 1 })])
    let field = NSTextField(string: "Row draft"); field.frame = NSRect(x: 5, y: 5, width: 180, height: 28); row.addSubview(field); field.selectText(nil)
    f.state.settings.commandShortcutOverrides[merge.rawValue] = .init(shortcut: .init(key: "return", modifiers: [.command]))
    let origin = try #require(f.state.commandCoordinator.invocation(in: f.window)); #expect(origin.scope == editorScope)
    #expect(f.window.performKeyEquivalent(with: f.event("\r", code: 36, modifiers: [.command]))); #expect(count == 0)
    #expect(!f.state.commandCoordinator.execute(merge, invocation: origin))
    #expect(!f.state.commandCoordinator.execute(.confirmSheet, invocation: origin))
}

@MainActor
@Test func proposalActionsKeepTheClickedWalkDraftAndCanonicalTrip() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let trip = TripTarget.existing(title: "Reviewed trip", folderRelativePath: "2026/reviewed-trip")
    let ids = (0..<5).map { _ in UUID() }
    let a = Walk(title: "A", date: Date(timeIntervalSince1970: 0), mediaItemIDs: [ids[0]], tripTarget: trip)
    let b = Walk(title: "Edited B", date: a.date, mediaItemIDs: [ids[1], ids[2], ids[3], ids[4]], tripTarget: trip)
    var editor = WalkCommitEditorState(id: UUID(), walks: [a, b], existingTrips: [], tripDisplayLabel: "Trip", walkDisplayLabel: "Walk")
    f.state.updateWalkCommitEditor(editor)
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: walkCommitCommandContextKey(editor), actions: [:])
    let rowA = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 140))
    let rowB = CommandLocalSurfaceView(frame: NSRect(x: 220, y: 0, width: 200, height: 140))
    parent.addSubview(rowA); parent.addSubview(rowB)
    rowA.configure(coordinator: f.state.commandCoordinator, scope: .walkProposal, contextKey: "A",
        actions: walkProposalCommandActions(appState: f.state, editor: editor, walkID: a.id, onEdited: { editor = $0 }))
    let button = rowB.configure(coordinator: f.state.commandCoordinator, scope: .walkProposal, contextKey: "B",
        actions: walkProposalCommandActions(appState: f.state, editor: editor, walkID: b.id, onEdited: { editor = $0 }))
    let field = NSTextField(string: "Keep typing in A"); field.frame = NSRect(x: 5, y: 5, width: 180, height: 28); rowA.addSubview(field); field.selectText(nil)
    button.run(.splitWalkProposal)
    #expect(editor.walks.count == 3); #expect(editor.walks[0] == a)
    #expect(editor.walks[1].id == b.id); #expect(editor.walks[1].mediaItemIDs == Array(ids[1...2]))
    #expect(editor.walks[2].id != b.id); #expect(editor.walks[2].mediaItemIDs == Array(ids[3...4]))
    #expect(editor.walks[1].tripTarget == trip); #expect(editor.walks[2].tripTarget == trip)
    #expect(editor.walks[2].title == "Edited B 2")
    let rebound = f.state.setCommandShortcut(.mergeWalkProposal, override: .init(shortcut: .init(key: "m", modifiers: [.command, .option])))
    #expect(rebound)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .form, contextKey: walkCommitCommandContextKey(editor), actions: [:])
    rowB.configure(coordinator: f.state.commandCoordinator, scope: .walkProposal, contextKey: "B split",
        actions: walkProposalCommandActions(appState: f.state, editor: editor, walkID: b.id, onEdited: { editor = $0 }))
    f.window.makeFirstResponder(rowB)
    #expect(f.window.performKeyEquivalent(with: f.event("m", modifiers: [.command, .option])))
    #expect(editor.walks.count == 2); #expect(editor.walks[0].id == a.id)
    #expect(editor.walks[0].mediaItemIDs == Array(ids[0...2])); #expect(editor.walks[0].tripTarget == trip)
}

@MainActor
@Test func proposalActionsCannotEditRecoveryPlansOrResurrectAReplacedEditor() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let a = Walk(title: "Fixed A", date: Date(), mediaItemIDs: [UUID()])
    let b = Walk(title: "Fixed B", date: a.date, mediaItemIDs: [UUID(), UUID()])
    let original = WalkCommitEditorState(id: UUID(), walks: [a, b], existingTrips: [], tripDisplayLabel: "Trip", walkDisplayLabel: "Walk")
    f.state.updateWalkCommitEditor(original)
    var edits = 0
    let prior = walkProposalCommandActions(appState: f.state, editor: original, walkID: b.id, onEdited: { _ in edits += 1 })
    var recovery = original; recovery.isRecoveryPlan = true; f.state.updateWalkCommitEditor(recovery)
    let locked = walkProposalCommandActions(appState: f.state, editor: recovery, walkID: b.id, onEdited: { _ in edits += 1 })
    #expect(locked[.mergeWalkProposal]?.enabled == false); #expect(locked[.splitWalkProposal]?.enabled == false)
    prior[.mergeWalkProposal]?.run(); prior[.splitWalkProposal]?.run()
    f.state.mergeWalkProposalWithPrevious(b.id); f.state.splitWalkProposal(b.id)
    #expect(f.state.presentationState.snapshot.activeWalkCommitEditor == recovery); #expect(edits == 0)
    f.state.dismissWalkCommitEditor()
    let replacement = WalkCommitEditorState(id: UUID(), walks: [a, b], existingTrips: [], tripDisplayLabel: "Trip", walkDisplayLabel: "Walk")
    f.state.updateWalkCommitEditor(replacement)
    prior[.splitWalkProposal]?.run(); #expect(f.state.presentationState.snapshot.activeWalkCommitEditor == replacement)
    f.state.dismissWalkCommitEditor(); prior[.mergeWalkProposal]?.run()
    #expect(f.state.presentationState.snapshot.activeWalkCommitEditor == nil); #expect(edits == 0)
}

@MainActor
@Test func actualCopyPlanMountsContainingRowsWithoutShowingItsWindow() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    f.state.commandCoordinator.unregisterWindow(f.token)
    let editor = WalkCommitEditorState(id: UUID(), walks: [
        Walk(title: "First", date: Date(), mediaItemIDs: [UUID()]),
        Walk(title: "Second", date: Date(), mediaItemIDs: [UUID(), UUID()])
    ], existingTrips: [], tripDisplayLabel: "Trip", walkDisplayLabel: "Walk")
    f.state.updateWalkCommitEditor(editor)
    f.window.setContentSize(NSSize(width: 800, height: 620))
    let host = NSHostingView(rootView: WalkCommitEditorSheet(appState: f.state, editor: editor))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host)
    host.layoutSubtreeIfNeeded()
    // Keep traversing through containing surfaces to include hosted row children.
    func allSurfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
        ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(allSurfaces)
    }
    let mounted = allSurfaces(host); #expect(mounted.count == 3)
    for surface in mounted {
        f.window.makeFirstResponder(surface)
        let origin = try #require(f.state.commandCoordinator.invocation(in: f.window))
        #expect([AppCommandScope.form, .walkProposal].contains(origin.scope))
        if origin.scope == .walkProposal {
            #expect(origin.surfaces.count == 2)
            #expect(f.state.commandCoordinator.unavailableReason(.confirmSheet, invocation: origin) == nil)
            #expect(f.state.commandCoordinator.unavailableReason(.closeSheet, invocation: origin) == nil)
        }
    }
    #expect(!f.window.isVisible)
    host.removeFromSuperview()
}

@MainActor
private final class HostedHierarchyModel: ObservableObject {
    @Published var draft = "plan A"
    var parent: LocalCommandHandle?, child: LocalCommandHandle?
    var renders = 0, saved = 0, confirmed = 0
}

@MainActor
private struct HostedHierarchyView: View {
    let coordinator: CommandKeyboardCoordinator
    @ObservedObject var model: HostedHierarchyModel
    var body: some View {
        CommandLocalSurface(coordinator: coordinator, scope: .form, contextKey: model.draft,
            actions: [.confirmSheet: .init(run: { model.confirmed += 1 })], ownsWindow: true) { parent in
            let _ = model.parent = parent
            CommandLocalSurface(coordinator: coordinator, scope: .walkProposal, contextKey: "unchanged row",
                actions: [.splitWalkProposal: .init(run: { model.saved += 1 })]) { child in
                let _ = model.child = child
                let _ = model.renders += 1
                VStack { TextField("Draft", text: $model.draft); Button("Split") { child.run(.splitWalkProposal) } }.padding(12)
            }
        }
    }
}

@MainActor
@Test func hostedNestedButtonsKeepFreshAncestorAuthorityAcrossDraftsAndReattachment() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    f.state.commandCoordinator.unregisterWindow(f.token)
    let model = HostedHierarchyModel()
    let host = NSHostingView(rootView: HostedHierarchyView(coordinator: f.state.commandCoordinator, model: model))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host)
    host.layoutSubtreeIfNeeded()
    let original = try #require(model.child)
    original.run(.splitWalkProposal); #expect(model.saved == 1)
    let parent = try #require(model.parent); parent.run(.confirmSheet); #expect(model.confirmed == 1)
    let owner = try #require(f.state.commandCoordinator.registration(for: f.window)?.instanceID)
    let before = model.renders; model.draft = "plan B"
    for _ in 0..<20 where model.renders == before { try await Task.sleep(for: .milliseconds(10)); host.layoutSubtreeIfNeeded() }
    #expect(model.renders > before); #expect(f.state.commandCoordinator.registration(for: f.window)?.instanceID == owner)
    original.run(.splitWalkProposal); #expect(model.saved == 1)
    let updated = try #require(model.child); updated.run(.splitWalkProposal); #expect(model.saved == 2)
    host.removeFromSuperview(); updated.run(.splitWalkProposal); #expect(model.saved == 2)
    f.window.contentView!.addSubview(host); host.layoutSubtreeIfNeeded()
    for _ in 0..<3 { try await Task.sleep(for: .milliseconds(10)); host.layoutSubtreeIfNeeded() }
    updated.run(.splitWalkProposal); #expect(model.saved == 2)
    let reattached = try #require(model.child); reattached.run(.splitWalkProposal); #expect(model.saved == 3)
    let currentParent = try #require(model.parent); currentParent.run(.confirmSheet); #expect(model.confirmed == 2)
    #expect(!f.window.isVisible); host.removeFromSuperview()
}
