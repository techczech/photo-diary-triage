import AppKit
import SwiftUI

@MainActor
final class CommandWindowRegistration {
    weak var window: NSWindow?
    let token: UUID
    let instanceID: UUID
    let scope: AppCommandScope
    let openSettings: (() -> Void)?
    let findAction: (() -> Void)?
    let searchAction: (() -> Void)?
    init(window: NSWindow, token: UUID, scope: AppCommandScope, openSettings: (() -> Void)?, findAction: (() -> Void)?, searchAction: (() -> Void)?, instanceID: UUID) {
        self.instanceID = instanceID
        self.window = window; self.token = token; self.scope = scope; self.openSettings = openSettings; self.findAction = findAction; self.searchAction = searchAction
    }
}

@MainActor
final class CommandSurfaceLease {
    weak var view: NSView?
    weak var registeredWindow: NSWindow?
    let token: UUID
    var scope: AppCommandScope
    var active: Bool
    var supports: (AppCommandID) -> Bool
    var availability: (AppCommandID) -> Bool
    var run: (AppCommandID) -> Bool
    var focusTarget: (() -> NSView?)?
    init(view: NSView, token: UUID, scope: AppCommandScope, active: Bool,
         supports: @escaping (AppCommandID) -> Bool, availability: @escaping (AppCommandID) -> Bool,
         run: @escaping (AppCommandID) -> Bool) {
        self.view = view; self.token = token; self.scope = scope; self.active = active
        self.supports = supports; self.availability = availability; self.run = run
    }
}

struct CommandSelectionFingerprint: Equatable {
    let root: String, role: ArchiveMachineRole, pictures: String
    let contextGeneration: Int
    let sessionID: UUID?, node: String?, folders: Set<String>, photos: Set<UUID>, focused: UUID?, preview: UUID?, compare: [UUID]
    let archiveSelection: String
    let reviewContext: String
    @MainActor init(_ state: AppState) {
        contextGeneration = ArchiveByteReadPolicyContext.shared.generation
        root = state.settings.archiveRoot.standardizedFileURL.path; role = state.settings.archiveMachineRole
        pictures = state.settings.oneDrivePicturesRoot.standardizedFileURL.path
        sessionID = state.currentSession?.id; node = state.selectedSidebarNodeID
        folders = state.selectedFolderNodeIDs; photos = state.selectedMediaItemIDs
        focused = state.focusedReviewItemID; preview = state.previewingMediaItemID; compare = state.comparingMediaItemIDs
        archiveSelection = state.commandArchiveSelectionFingerprint; reviewContext = state.commandReviewContextFingerprint
    }
}

@MainActor
final class CommandInvocation {
    weak var window: NSWindow?
    weak var responder: NSResponder?
    weak var fieldControl: NSControl?
    weak var lease: CommandSurfaceLease?
    let scope: AppCommandScope
    let leaseToken: UUID?
    let windowRegistrationID: UUID
    let fingerprint: CommandSelectionFingerprint
    let text: String?
    let selection: NSRange?
    init(window: NSWindow, scope: AppCommandScope, lease: CommandSurfaceLease?, state: AppState, windowRegistrationID: UUID) {
        self.windowRegistrationID = windowRegistrationID
        self.window = window; self.scope = scope; self.lease = lease; self.leaseToken = lease?.token; self.fingerprint = .init(state)
        responder = window.firstResponder
        if let editor = responder as? NSTextView {
            text = editor.string; selection = editor.selectedRange()
            // A shared field editor is reusable; its owning control is the identity.
            fieldControl = editor.isFieldEditor ? editor.delegate as? NSControl : nil
        } else { text = nil; selection = nil }
    }
    func restoreFocus() {
        guard let window, window.attachedSheet == nil, let responder else { return }
        if let control = fieldControl {
            guard control.window === window, control.stringValue == text else { return }
            window.makeFirstResponder(control)
            if let editor = control.currentEditor() as? NSTextView, editor.delegate as AnyObject? === control, let selection {
                editor.setSelectedRange(selection)
            }
        } else if let view = responder as? NSView {
            guard view.window === window else { return }
            if let editor = view as? NSTextView {
                guard !editor.isFieldEditor, editor.string == text else { return }
                window.makeFirstResponder(editor); if let selection { editor.setSelectedRange(selection) }
            } else { window.makeFirstResponder(view) }
        }
    }
}

@MainActor
final class CommandKeyboardCoordinator: ObservableObject {
    weak var appState: AppState?
    private var windows: [UUID: CommandWindowRegistration] = [:]
    private var leases: [UUID: CommandSurfaceLease] = [:]
    private var monitor: Any?
    private var focusRevisions: [ObjectIdentifier: Int] = [:]
    private var leaseOrders: [UUID: Int] = [:]
    private var leaseOrder = 0
    private var closeObserver: Any?
    weak var executingWindow: NSWindow?
    lazy var panels = CommandPanelController(coordinator: self)
    var presentsPanels = true

    init(appState: AppState) {
        self.appState = appState
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let window = notification.object as? NSWindow else { return }
                self?.windowClosed(window)
            }
        }
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
    }
    private func windowClosed(_ window: NSWindow) {
        guard windows.values.contains(where: { $0.window === window }) else { return }
        focusRevisions[ObjectIdentifier(window), default: 0] &+= 1
        let removed = leases.values.filter { $0.registeredWindow === window }.map(\.token)
        for token in removed { leases[token] = nil; leaseOrders[token] = nil }
        windows = windows.filter { $0.value.window !== window }
        panels.ownerClosed(window)
    }
    private var cachedOverrides: [String: AppShortcutOverride]?
    private var cachedRegistry = AppCommandRegistry()
    private var cachedConflictingIDs: Set<AppCommandID> = []
    var registry: AppCommandRegistry {
        let overrides = appState?.settings.commandShortcutOverrides ?? [:]
        if cachedOverrides != overrides {
            cachedOverrides = overrides; cachedRegistry = .init(overrides: overrides)
            cachedConflictingIDs = Set(cachedRegistry.collisions().flatMap { [$0.0, $0.1] })
        }
        return cachedRegistry
    }
    func register(window: NSWindow, token: UUID, scope: AppCommandScope, openSettings: (() -> Void)? = nil, findAction: (() -> Void)? = nil, searchAction: (() -> Void)? = nil) {
        let instanceID = windows[token].flatMap { $0.window === window ? $0.instanceID : nil } ?? UUID()
        windows[token] = .init(window: window, token: token, scope: scope, openSettings: openSettings, findAction: findAction, searchAction: searchAction, instanceID: instanceID)
        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let window = event.window, self.handle(event, in: window) else { return event }
                return nil
            }
        }
    }
    func unregisterWindow(_ token: UUID) {
        guard let removed = windows.removeValue(forKey: token), let window = removed.window,
              !windows.values.contains(where: { $0.window === window }) else { return }
        focusRevisions[ObjectIdentifier(window), default: 0] &+= 1
        let surfaces = leases.values.filter { $0.registeredWindow === window }.map(\.token)
        for token in surfaces { leases[token] = nil; leaseOrders[token] = nil }
        // The panel controller already closes its own descendants. Root/sheet
        // dismantling, which need not close NSWindow, also ends owned panels.
        if removed.scope != .commandPanel && removed.scope != .helpPanel { panels.ownerClosed(window) }
    }
    func register(_ lease: CommandSurfaceLease) {
        if leases[lease.token] !== lease { leaseOrder &+= 1; leaseOrders[lease.token] = leaseOrder }
        lease.registeredWindow = lease.view?.window
        leases[lease.token] = lease
    }
    func unregisterSurface(_ token: UUID) {
        if let window = leases[token]?.registeredWindow { focusRevisions[ObjectIdentifier(window), default: 0] &+= 1 }
        leases[token] = nil; leaseOrders[token] = nil
    }
    func registration(for window: NSWindow) -> CommandWindowRegistration? {
        var candidate: NSWindow? = window
        while let current = candidate {
            if let registered = windows.values.first(where: { $0.window === current }) { return registered }
            candidate = current.sheetParent ?? current.parent
        }
        return nil
    }
    private func activeLease(in window: NSWindow) -> CommandSurfaceLease? {
        let visible = leases.values.filter { $0.view?.window === window }.sorted { leaseOrders[$0.token, default: 0] > leaseOrders[$1.token, default: 0] }
        // Overlays own their window even during the interval before initial focus.
        if let overlay = visible.first(where: { $0.active && ($0.scope == .compare || $0.scope == .preview || $0.scope == .form || $0.scope == .information) }) { return overlay }
        return visible.first { lease in
            guard let view = lease.view, let focused = window.firstResponder as? NSView else { return false }
            return (lease.active || lease.scope == .review) && (focused === view || focused.isDescendant(of: view))
        }
    }
    func invocation(in window: NSWindow) -> CommandInvocation? {
        guard let state = appState, let registration = registration(for: window) else { return nil }
        let lease = activeLease(in: window)
        let scope: AppCommandScope
        if registration.scope == .commandPanel || registration.scope == .helpPanel {
            scope = panels.session(in: window)?.capturing != nil ? .shortcutCapture : registration.scope
        }
        else if let text = window.firstResponder as? NSTextView, text.isEditable || text.isSelectable {
            scope = lease?.scope == .form ? .formEditor : (lease?.scope == .information ? .information : .editor)
        }
        else if window.sheetParent != nil && lease == nil { scope = .editor }
        else { scope = lease?.scope ?? registration.scope }
        return .init(window: window, scope: scope, lease: scope == .editor ? nil : lease, state: state, windowRegistrationID: registration.instanceID)
    }
    func isCurrent(_ invocation: CommandInvocation) -> Bool {
        guard let state = appState, let window = invocation.window, registration(for: window)?.instanceID == invocation.windowRegistrationID,
              invocation.fingerprint == .init(state) else { return false }
        guard window.attachedSheet == nil else { return false }
        if let token = invocation.leaseToken {
            guard let lease = invocation.lease, leases[token] === lease, (lease.active || lease.scope == .review), lease.view?.window === window,
                  activeLease(in: window) === lease else { return false }
        }
        if invocation.scope == .editor || invocation.scope == .formEditor {
            guard window.firstResponder === invocation.responder else { return false }
            if let control = invocation.fieldControl, let editor = window.firstResponder as? NSTextView {
                guard editor.delegate as AnyObject? === control, control.window === window else { return false }
            }
        }
        return true
    }
    func unavailableReason(_ id: AppCommandID, invocation: CommandInvocation?) -> String? {
        guard let state = appState, let invocation, isCurrent(invocation) else { return "The original selection or window has changed." }
        let definition = AppCommandRegistry.definition(id)
        guard definition.scopes.contains(invocation.scope) else { return "Available in another pane." }
        _ = registry
        if cachedConflictingIDs.contains(id) { return "A saved shortcut conflicts with another command. Change it in Settings." }
        if id == .rebindCommand || [.palettePrevious, .paletteNext, .paletteRun, .closeCommandPanel, .cancelShortcutCapture].contains(id) {
            return invocation.window.flatMap { panels.session(in: $0) } != nil ? nil : "Open the command palette first."
        }
        if [.confirmSheet, .confirmAndOpenSheet, .confirmGoogleDelivery].contains(id),
           let editor = invocation.window?.firstResponder as? NSTextView, editor.hasMarkedText() { return "Finish composing the text before confirming this form." }
        if id == .toggleInspector, registration(for: invocation.window!)?.scope != .main { return "The Inspector belongs to the main Walkfolio window." }
        if id == .find { return registration(for: invocation.window!)?.findAction != nil ? nil : "Find is available in the main Walkfolio view." }
        if isPresentationCommand(id) { return nil }
        if let lease = invocation.lease, lease.supports(id) {
            return lease.availability(id) ? nil : "Unavailable for the current photo or selection."
        }
        guard !definition.needsSurfaceHandler else { return "Focus the pane that offers this action." }
        return definition.enabled(state) ? nil : "Unavailable for the current selection or operation."
    }
    private func isPresentationCommand(_ id: AppCommandID) -> Bool {
        [.palette, .contextActions, .keyboardHelp, .settings, .rebindCommand, .palettePrevious, .paletteNext, .paletteRun, .closeCommandPanel, .cancelShortcutCapture].contains(id)
    }
    @discardableResult
    func execute(_ id: AppCommandID, invocation: CommandInvocation?, settingsOpener: (() -> Void)? = nil) -> Bool {
        if id == .settings, invocation == nil, let settingsOpener { settingsOpener(); return true }
        guard let captured = invocation, isCurrent(captured), let window = captured.window, let state = appState else { return false }
        // AppState is shared across app windows. Native ownership, rather than the
        // last window's pane flag, determines which selection this command uses.
        if captured.scope == .review { state.activePane = .media; state.reviewGridHasFocus = true }
        else if captured.scope == .sourceSidebar { state.activePane = .sidebar }
        let invocation = CommandInvocation(window: window, scope: captured.scope, lease: captured.lease, state: state, windowRegistrationID: captured.windowRegistrationID)
        guard unavailableReason(id, invocation: invocation) == nil else { return false }
        let previous = executingWindow; executingWindow = window; defer { executingWindow = previous }
        switch id {
        case .palette: panels.present(.palette, from: invocation)
        case .contextActions: panels.present(.contextual, from: invocation)
        case .keyboardHelp: panels.present(.help, from: invocation)
        case .settings:
            let rootWindow = panels.session(in: window)?.origin.window ?? window
            guard let action = settingsOpener ?? registration(for: rootWindow)?.openSettings else { return false }
            action()
        case .find: registration(for: window)?.findAction?()
        case .searchArchive:
            state.setWorkspaceMode(.archiveView); state.requestArchiveSearchFocus()
            registration(for: window)?.searchAction?()
        case .rebindCommand: panels.beginRebinding(panels.session(in: window))
        case .palettePrevious, .paletteNext, .paletteRun, .closeCommandPanel, .cancelShortcutCapture:
            return panels.perform(id, in: window)
        default:
            if let lease = invocation.lease, lease.supports(id) { return lease.run(id) }
            AppCommandRegistry.definition(id).run(state)
        }
        return true
    }
    @discardableResult
    func execute(_ id: AppCommandID, in window: NSWindow? = NSApp?.keyWindow) -> Bool {
        execute(id, invocation: window.flatMap { invocation(in: $0) })
    }
    @discardableResult
    func handle(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard event.type == .keyDown, registration(for: window) != nil else { return false }
        // Composition owns candidate navigation, Return and cancellation, including
        // shortcut capture. Falling through would execute the highlighted command.
        if let text = window.firstResponder as? NSTextView, text.hasMarkedText(),
           !event.modifierFlags.contains(.command) || ["return", "escape"].contains(AppShortcut(event: event)?.key ?? "") { return false }
        if panels.handleCapture(event, in: window) { return true }
        guard let origin = invocation(in: window) else { return false }
        let claims = registry.claims(for: event, scope: origin.scope)
        guard !claims.isEmpty else { return false }
        guard claims.count == 1 else { return true }
        let id = claims[0]
        // IME Escape belongs to composition, before any pane or panel cancellation.
        if let text = window.firstResponder as? NSTextView, text.hasMarkedText(), AppShortcut(event: event)?.key == "escape" { return false }
        _ = execute(id, invocation: origin)
        // A claimed but disabled key never falls through to a different menu/surface.
        return true
    }
    func requestFocus(scope: AppCommandScope, in requested: NSWindow? = nil) {
        guard let state = appState, let window = requested ?? executingWindow ?? NSApp?.keyWindow, registration(for: window) != nil else { return }
        let owner = ObjectIdentifier(window)
        focusRevisions[owner, default: 0] &+= 1
        let revision = focusRevisions[owner], fingerprint = CommandSelectionFingerprint(state)
        let registrationID = registration(for: window)?.instanceID
        let targetLease = leases.values.filter { $0.scope == scope && $0.active && $0.view?.window === window }
            .max { leaseOrders[$0.token, default: 0] < leaseOrders[$1.token, default: 0] }
        let targetToken = targetLease?.token, prior = window.firstResponder
        DispatchQueue.main.async { [weak self, weak window, weak prior, weak targetLease] in
            guard let self, let state = self.appState, let window, self.focusRevisions[owner] == revision,
                  self.registration(for: window)?.instanceID == registrationID,
                  fingerprint == .init(state), window.attachedSheet == nil, window.firstResponder === prior else { return }
            let lease: CommandSurfaceLease?
            if let targetToken {
                guard let targetLease, self.leases[targetToken] === targetLease else { return }
                lease = targetLease
            } else {
                // A just-shown pane may mount on the next layout pass.
                lease = self.leases.values.filter { $0.scope == scope && $0.active && $0.view?.window === window }
                    .max { self.leaseOrders[$0.token, default: 0] < self.leaseOrders[$1.token, default: 0] }
            }
            guard let lease, lease.active, lease.scope == scope, let view = lease.view, view.window === window else { return }
            let target = lease.focusTarget?() ?? view
            guard target.window === window, target.acceptsFirstResponder else { return }
            if !window.makeFirstResponder(target), let prior { window.makeFirstResponder(prior) }
        }
    }
}

struct CommandWindowAnchor: NSViewRepresentable {
    let coordinator: CommandKeyboardCoordinator
    var scope: AppCommandScope = .main
    var registersWindow = true
    var findAction: (() -> Void)? = nil
    var searchAction: (() -> Void)? = nil
    @Environment(\.openSettings) private var openSettings
    func makeNSView(context: Context) -> CommandWindowAnchorView { CommandWindowAnchorView() }
    func updateNSView(_ view: CommandWindowAnchorView, context: Context) {
        view.coordinator = coordinator; view.scope = scope; view.registersWindow = registersWindow; view.openSettings = { openSettings() }; view.findAction = findAction; view.searchAction = searchAction; view.registerWindow()
    }
    static func dismantleNSView(_ view: CommandWindowAnchorView, coordinator: ()) { view.unregisterWindow() }
}

final class CommandWindowAnchorView: NSView {
    weak var coordinator: CommandKeyboardCoordinator?
    var scope: AppCommandScope = .main
    var openSettings: (() -> Void)?
    var findAction: (() -> Void)?
    var searchAction: (() -> Void)?
    var registersWindow = true
    let token = UUID()
    private weak var registeredWindow: NSWindow?
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); registerWindow() }
    func registerWindow() {
        guard registersWindow else { return }
        if registeredWindow !== window { unregisterWindow() }
        if let window { coordinator?.register(window: window, token: token, scope: scope, openSettings: openSettings, findAction: findAction, searchAction: searchAction); registeredWindow = window }
    }
    func unregisterWindow() { coordinator?.unregisterWindow(token); registeredWindow = nil }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let window else { return false }; return coordinator?.handle(event, in: window) ?? false
    }
}


struct SheetCommandAction {
    var enabled = true
    let run: () -> Void
}

struct CommandSheetAnchor: NSViewRepresentable {
    let coordinator: CommandKeyboardCoordinator
    var scope: AppCommandScope = .form
    let actions: [AppCommandID: SheetCommandAction]
    @Environment(\.openSettings) private var openSettings
    func makeNSView(context: Context) -> CommandSheetAnchorView { CommandSheetAnchorView() }
    func updateNSView(_ view: CommandSheetAnchorView, context: Context) {
        view.configure(coordinator: coordinator, scope: scope, actions: actions, openSettings: { openSettings() })
    }
    static func dismantleNSView(_ view: CommandSheetAnchorView, coordinator: ()) { view.unregister() }
}

final class CommandSheetAnchorView: NSView {
    weak var coordinator: CommandKeyboardCoordinator?
    private weak var registeredWindow: NSWindow?
    private let windowToken = UUID(), surfaceToken = UUID()
    private var lease: CommandSurfaceLease?
    private var scope: AppCommandScope = .form
    private var actions: [AppCommandID: SheetCommandAction] = [:]
    private var openSettings: (() -> Void)?
    func configure(coordinator: CommandKeyboardCoordinator, scope: AppCommandScope, actions: [AppCommandID: SheetCommandAction], openSettings: (() -> Void)? = nil) {
        if self.coordinator !== coordinator { unregister() }
        self.coordinator = coordinator; self.scope = scope; self.actions = actions; self.openSettings = openSettings
        register()
    }
    private func register() {
        guard let window, let coordinator else { return }
        if registeredWindow !== window { unregister() }
        coordinator.register(window: window, token: windowToken, scope: scope, openSettings: openSettings)
        registeredWindow = window
        if lease == nil {
            lease = CommandSurfaceLease(view: self, token: surfaceToken, scope: scope, active: true,
                supports: { [weak self] in self?.actions[$0] != nil }, availability: { [weak self] in self?.actions[$0]?.enabled == true },
                run: { [weak self] id in guard let action = self?.actions[id], action.enabled else { return false }; action.run(); return true })
        }
        lease?.scope = scope; coordinator.register(lease!)
    }
    func unregister() {
        coordinator?.unregisterSurface(surfaceToken); coordinator?.unregisterWindow(windowToken)
        lease = nil; registeredWindow = nil
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { unregister() } else { register() } }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let window else { return false }; return coordinator?.handle(event, in: window) ?? false
    }
}
