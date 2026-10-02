import AppKit
import SwiftUI

enum ArchiveSidebarRowID: Hashable {
    case home, allEntries, trips, folders, allYears, year(String)
}

@MainActor
final class ArchiveSidebarNavigation: ObservableObject {
    @Published private(set) var cursor: ArchiveSidebarRowID = .home
    @Published private(set) var rows: [ArchiveSidebarRowID] = [.home, .allEntries, .trips, .folders, .allYears]
    func reconcile(years: [String]) {
        let next: [ArchiveSidebarRowID] = [.home, .allEntries, .trips, .folders, .allYears] + Array(NSOrderedSet(array: years)).compactMap { $0 as? String }.map { .year($0) }
        guard rows != next else { return }
        let previousIndex = rows.firstIndex(of: cursor) ?? 0
        rows = next
        if !next.contains(cursor) { cursor = next[min(previousIndex, next.count - 1)] }
    }
    func move(_ delta: Int) {
        let index = rows.firstIndex(of: cursor) ?? 0
        cursor = rows[min(max(index + delta, 0), rows.count - 1)]
    }
    func select(_ row: ArchiveSidebarRowID) { if rows.contains(row) { cursor = row } }
    func apply(to state: AppState) {
        guard state.workspaceMode == .archiveView else { return }
        switch cursor {
        case .home: state.setArchiveKindFilter(.all); state.setArchiveYearFilter(nil)
        case .allEntries: state.setArchiveKindFilter(.all)
        case .trips: state.setArchiveKindFilter(.trips)
        case .folders: state.setArchiveKindFilter(.unorganisedFolders)
        case .allYears: state.setArchiveYearFilter(nil)
        case .year(let year): state.setArchiveYearFilter(year)
        }
    }
}

struct CommandSidebarContainer<Content: View>: NSViewRepresentable {
    let appState: AppState
    let content: Content
    func makeNSView(context: Context) -> CommandSidebarContainerView { CommandSidebarContainerView() }
    func updateNSView(_ view: CommandSidebarContainerView, context: Context) {
        view.host.rootView = AnyView(content)
        view.configure(appState: appState)
    }
    static func dismantleNSView(_ view: CommandSidebarContainerView, coordinator: ()) { view.unregisterCommands() }
}

final class CommandSidebarContainerView: NSView {
    let host = NSHostingView(rootView: AnyView(EmptyView()))
    weak var appState: AppState?
    let token = UUID()
    private var lease: CommandSurfaceLease?
    override init(frame: NSRect) {
        super.init(frame: frame); host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var acceptsFirstResponder: Bool { true }
    func configure(appState: AppState) {
        if self.appState !== appState { unregisterCommands() }
        self.appState = appState; registerCommands()
    }
    func unregisterCommands() { appState?.commandCoordinator.unregisterSurface(token); lease = nil }
    private func registerCommands() {
        guard let state = appState, window != nil else { return }
        if lease == nil {
            lease = CommandSurfaceLease(view: self, token: token, scope: .archiveSidebar, active: true,
                supports: { [.sidebarPrevious, .sidebarNext, .sidebarApply, .closeSurface].contains($0) },
                availability: { [weak self] _ in self?.appState?.workspaceMode == .archiveView },
                run: { [weak self] in self?.perform($0) ?? false })
            lease?.focusTarget = { [weak self] in self?.ownedFocusTarget() }
        }
        lease?.scope = state.workspaceMode == .archiveView ? .archiveSidebar : .sourceSidebar
        lease?.active = state.isSidebarVisible
        state.commandCoordinator.register(lease!)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); if window == nil { unregisterCommands() } else { registerCommands() }
    }
    func ownedFocusTarget() -> NSView? {
        guard appState?.workspaceMode != .archiveView else { return self }
        // Search only this explicitly owned Sidebar host, never the entire window.
        func table(in view: NSView) -> NSView? {
            if view is NSOutlineView || view is NSTableView { return view }
            return view.subviews.lazy.compactMap { table(in: $0) }.first
        }
        return table(in: host) ?? self
    }
    func perform(_ id: AppCommandID) -> Bool {
        guard let state = appState else { return false }
        switch id {
        case .sidebarPrevious: state.archiveSidebarNavigation.move(-1)
        case .sidebarNext: state.archiveSidebarNavigation.move(1)
        case .sidebarApply: state.archiveSidebarNavigation.apply(to: state)
        case .closeSurface: state.focusReviewSurface()
        default: return false
        }
        return true
    }
    override func keyDown(with event: NSEvent) {
        guard let window, appState?.commandCoordinator.handle(event, in: window) == true else { super.keyDown(with: event); return }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let window else { return false }; return appState?.commandCoordinator.handle(event, in: window) ?? false
    }
}

struct CommandPaneInputView: NSViewRepresentable {
    let coordinator: CommandKeyboardCoordinator
    let scope: AppCommandScope
    let handlers: [AppCommandID: () -> Void]
    func makeNSView(context: Context) -> CommandPaneResponderView { CommandPaneResponderView() }
    func updateNSView(_ view: CommandPaneResponderView, context: Context) {
        view.configure(coordinator: coordinator, scope: scope, handlers: handlers)
    }
    static func dismantleNSView(_ view: CommandPaneResponderView, coordinator: ()) { view.unregisterCommands() }
}

final class CommandPaneResponderView: NSView {
    weak var coordinator: CommandKeyboardCoordinator?
    let token = UUID()
    private var lease: CommandSurfaceLease?
    var handlers: [AppCommandID: () -> Void] = [:]
    var scope: AppCommandScope = .archiveCards
    private var requestedInitialFocus = false
    override var acceptsFirstResponder: Bool { true }
    func configure(coordinator: CommandKeyboardCoordinator, scope: AppCommandScope, handlers: [AppCommandID: () -> Void]) {
        if self.coordinator !== coordinator { unregisterCommands() }
        self.coordinator = coordinator; self.scope = scope; self.handlers = handlers
        registerCommands()
    }
    func unregisterCommands() { coordinator?.unregisterSurface(token); lease = nil }
    private func registerCommands() {
        guard window != nil, let coordinator else { return }
        if lease == nil {
            lease = CommandSurfaceLease(view: self, token: token, scope: scope, active: true,
                supports: { [weak self] in self?.handlers[$0] != nil }, availability: { _ in true },
                run: { [weak self] id in guard let action = self?.handlers[id] else { return false }; action(); return true })
        }
        lease?.scope = scope; coordinator.register(lease!)
        if !requestedInitialFocus, let window, let state = coordinator.appState {
            requestedInitialFocus = true
            let prior = window.firstResponder, fingerprint = CommandSelectionFingerprint(state), token = self.token
            DispatchQueue.main.async { [weak self, weak window, weak prior] in
                guard let self, let window, self.window === window, self.token == token, let state = self.coordinator?.appState,
                      window.firstResponder === prior, fingerprint == .init(state), (prior == nil || prior === window), window.attachedSheet == nil else { return }
                self.coordinator?.requestFocus(scope: self.scope, in: window)
            }
        }
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { unregisterCommands() } else { registerCommands() } }
    override func keyDown(with event: NSEvent) {
        guard let window, coordinator?.handle(event, in: window) == true else { super.keyDown(with: event); return }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let window else { return false }; return coordinator?.handle(event, in: window) ?? false
    }
}
