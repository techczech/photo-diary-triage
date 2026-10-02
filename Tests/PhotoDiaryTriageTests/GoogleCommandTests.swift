import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
@Test func googleJobErrorTextKeepsNativeEditingAndContextualJobOwnership() throws {
    let jobScope = try #require(AppCommandScope(rawValue: "googleJob"))
    let editorScope = try #require(AppCommandScope(rawValue: "googleJobEditor"))
    let find = try #require(AppCommandID(rawValue: "findGoogleAlbum"))
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
    var found: [String] = [], closed = 0
    parent.configure(coordinator: f.state.commandCoordinator, scope: .information, contextKey: "queue", actions: [.closeSheet: .init(run: { closed += 1 })])
    let a = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 180)), b = CommandLocalSurfaceView(frame: NSRect(x: 220, y: 0, width: 200, height: 180))
    parent.addSubview(a); parent.addSubview(b)
    a.configure(coordinator: f.state.commandCoordinator, scope: jobScope, contextKey: "job A", actions: [find: .init(run: { found.append("A") })])
    b.configure(coordinator: f.state.commandCoordinator, scope: jobScope, contextKey: "job B", actions: [find: .init(run: { found.append("B") })])
    let text = NSTextView(frame: NSRect(x: 5, y: 5, width: 180, height: 100)); text.isEditable = false; text.isSelectable = true; text.string = "Job B error"; b.addSubview(text)
    f.window.makeFirstResponder(text)
    #expect(f.state.commandCoordinator.invocation(in: f.window)?.scope == editorScope)
    #expect(!f.window.performKeyEquivalent(with: f.event("a", modifiers: [.command])))
    #expect(!f.window.performKeyEquivalent(with: f.event("c", modifiers: [.command])))
    #expect(f.window.performKeyEquivalent(with: f.event("k", modifiers: [.command])))
    let session = try #require(f.state.commandCoordinator.panels.current)
    #expect(session.commands.contains { $0.id == find }); #expect(session.commands.contains { $0.id == .closeSheet })
    session.highlighted = find; f.state.commandCoordinator.panels.runHighlighted(session)
    #expect(found == ["B"])
    #expect(f.window.performKeyEquivalent(with: f.event("\u{1b}", code: 53))); #expect(closed == 1)
}

@MainActor
@Test func googleJobAndAlbumRebindingRejectsTransitiveQueueCollisions() throws {
    let find = try #require(AppCommandID(rawValue: "findGoogleAlbum"))
    let adopt = try #require(AppCommandID(rawValue: "adoptGoogleAlbum"))
    let chord = AppShortcut(key: "n", modifiers: [.command, .option])
    let registry = AppCommandRegistry(overrides: [AppCommandID.resumeGoogleDelivery.rawValue: .init(shortcut: chord)])
    #expect(registry.validate(.init(shortcut: chord), for: find) != nil)
    #expect(registry.validate(.init(shortcut: chord), for: adopt) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "c", modifiers: [.command])), for: adopt) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "n")), for: find) != nil)
}

@MainActor
@Test func actualGoogleQueueHostsAlbumJobAndQueueCapabilitiesInOrder() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    f.state.commandCoordinator.unregisterWindow(f.token)
    let account = GooglePhotosAccount(id: "fixture-account", clientID: "fixture-client", subject: "fixture-subject", displayName: "test-account@example.invalid")
    let scope = GooglePhotosDeliveryScope(kind: .trip, id: UUID(), path: "2026/fixture-trip", title: "Fixture trip", photos: [])
    var job = GooglePhotosDeliveryJob(account: account, scope: scope, photos: [], machineRole: .mainArchive)
    job.state = .needsReconciliation; job.albumCreationStarted = true; job.error = "Selectable fixture error"
    let album = GooglePhotosAlbum(id: "fixture-album", title: "Fixture trip", productURL: nil)
    f.state.googleDeliveryJobs = [job]; f.state.googleAlbumCandidates[job.id] = [album]
    f.window.setContentSize(NSSize(width: 800, height: 560))
    let host = NSHostingView(rootView: GooglePhotosQueueView(appState: f.state))
    host.frame = f.window.contentView!.bounds; host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host); host.layoutSubtreeIfNeeded()
    func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] { ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(surfaces) }
    var scopes: Set<AppCommandScope> = []
    for surface in surfaces(host) {
        f.window.makeFirstResponder(surface)
        let origin = try #require(f.state.commandCoordinator.invocation(in: f.window)); scopes.insert(origin.scope)
        if origin.scope == .googleAlbum {
            #expect(origin.surfaces.map(\.effectiveScope) == [.googleAlbum, .googleJob, .information])
            #expect(f.state.commandCoordinator.unavailableReason(.adoptGoogleAlbum, invocation: origin) == nil)
            #expect(f.state.commandCoordinator.unavailableReason(.findGoogleAlbum, invocation: origin) == nil)
            #expect(f.state.commandCoordinator.unavailableReason(.closeSheet, invocation: origin) == nil)
        }
    }
    #expect(scopes == [.information, .googleJob, .googleAlbum]); #expect(!f.window.isVisible); host.removeFromSuperview()
}

@MainActor
@Test func googleSettingsUsesAvailableTabHeightForItsScrollableForm() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let host = NSHostingView(rootView: GooglePhotosSettingsView(appState: f.state))
    f.window.setContentSize(NSSize(width: 580, height: 380)); host.frame = f.window.contentView!.bounds
    host.autoresizingMask = [.width, .height]; f.window.contentView!.addSubview(host); host.layoutSubtreeIfNeeded()
    func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] { ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(surfaces) }
    let surface = try #require(surfaces(host).first)
    let actualHeight = surface.bounds.height
    #expect(actualHeight >= 370 && actualHeight <= 390)
    #expect(surface.bounds.width >= 570 && surface.bounds.width <= 590)
    #expect(!f.window.isVisible); host.removeFromSuperview()
}
