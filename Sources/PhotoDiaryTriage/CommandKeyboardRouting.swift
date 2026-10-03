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
    var firstOwnerRegistrationID: UUID?
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
    let imagePresentationRevision: Int
    let reviewPaneRevision: Int
    let sessionID: UUID?, node: String?, folders: Set<String>, photos: Set<UUID>, focused: UUID?, preview: UUID?, compare: [UUID]
    let archiveSelection: String
    let reviewContext: String
    let googleContext: String
    @MainActor init(_ state: AppState) {
        googleContext = state.commandGoogleContextKey
        contextGeneration = ArchiveByteReadPolicyContext.shared.generation
        imagePresentationRevision = state.imagePresentationRevision
        reviewPaneRevision = state.reviewPaneRevision
        root = state.settings.archiveRoot.standardizedFileURL.path; role = state.settings.archiveMachineRole
        pictures = state.settings.oneDrivePicturesRoot.standardizedFileURL.path
        sessionID = state.currentSession?.id; node = state.selectedSidebarNodeID
        folders = state.selectedFolderNodeIDs; photos = state.selectedMediaItemIDs
        focused = state.focusedReviewItemID; preview = state.previewingMediaItemID; compare = state.comparingMediaItemIDs
        archiveSelection = state.commandArchiveSelectionFingerprint; reviewContext = state.commandReviewContextFingerprint
    }
}

/// Exact containing capabilities, captured when an action is issued. A new parent
/// cannot lend its authority to an old child button or palette invocation.
@MainActor
struct CommandSurfaceSnapshot {
    weak var lease: CommandSurfaceLease?
    let token: UUID
    let sourceScope: AppCommandScope
    let effectiveScope: AppCommandScope
    init(_ lease: CommandSurfaceLease, effectiveScope: AppCommandScope) {
        self.lease = lease; token = lease.token; sourceScope = lease.scope; self.effectiveScope = effectiveScope
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
    let requiresFocusedOwner: Bool
    let surfaces: [CommandSurfaceSnapshot]
    init(window: NSWindow, scope: AppCommandScope, lease: CommandSurfaceLease?, state: AppState, windowRegistrationID: UUID, requiresFocusedOwner: Bool = true, surfaces: [CommandSurfaceSnapshot]? = nil) {
        self.surfaces = surfaces ?? lease.map { [CommandSurfaceSnapshot($0, effectiveScope: scope)] } ?? []
        self.requiresFocusedOwner = requiresFocusedOwner
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
    // Retain only for synchronous command execution, so unregistering an owner
    // cannot erase its identity and turn restoration into a search for another pane.
    private var executingSurface: CommandSurfaceLease?
    private var executingSurfaceChain: [CommandSurfaceLease] = []
    private var executingSurfaceSnapshots: [CommandSurfaceSnapshot] = []
    lazy var panels = CommandPanelController(coordinator: self)
    lazy var nativeMenus = CommandNativeMenus(coordinator: self)
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
        for lease in leases.values where lease.firstOwnerRegistrationID == nil {
            if let attached = lease.view?.window { lease.firstOwnerRegistrationID = registration(for: attached)?.instanceID }
        }
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
        if lease.firstOwnerRegistrationID == nil, let window = lease.registeredWindow { lease.firstOwnerRegistrationID = registration(for: window)?.instanceID }
        leases[lease.token] = lease
    }
    func unregisterSurface(_ token: UUID) {
        // Focus validates its exact target and ancestor capabilities. Replacing a
        // different child must not cancel a stable containing pane's request.
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
    private func focusedView(in window: NSWindow) -> NSView? {
        if let editor = window.firstResponder as? NSTextView, editor.isFieldEditor,
           let control = editor.delegate as? NSControl, control.window === window { return control }
        return window.firstResponder as? NSView
    }
    private func modalLease(in window: NSWindow) -> CommandSurfaceLease? {
        leases.values.filter { $0.view?.window === window && $0.view?.isHiddenOrHasHiddenAncestor == false && $0.active && [.compare, .preview, .form, .information].contains($0.scope) }
            .max { leaseOrders[$0.token, default: 0] < leaseOrders[$1.token, default: 0] }
    }
    func surfaceChain(for lease: CommandSurfaceLease, editing: Bool = false) -> [CommandSurfaceSnapshot] {
        guard let window = lease.view?.window else { return [.init(lease, effectiveScope: editing ? lease.scope.textEditingScope : lease.scope)] }
        var result = [CommandSurfaceSnapshot(lease, effectiveScope: editing ? lease.scope.textEditingScope : lease.scope)]
        let boundary = modalLease(in: window)
        if lease === boundary { return result }
        var candidate = lease.view?.superview
        while let view = candidate {
            if let parent = leases.values.first(where: { $0.view === view && $0.active }) {
                result.append(.init(parent, effectiveScope: editing ? parent.scope.textEditingScope : parent.scope))
                if parent === boundary { break }
            }
            candidate = view.superview
        }
        return result
    }
    private func activeLease(in window: NSWindow) -> CommandSurfaceLease? {
        let visible = leases.values.filter { $0.view?.window === window && $0.view?.isHiddenOrHasHiddenAncestor == false }.sorted { leaseOrders[$0.token, default: 0] > leaseOrders[$1.token, default: 0] }
        let boundary = modalLease(in: window)
        var candidate = focusedView(in: window)
        if let boundary, let boundaryView = boundary.view,
           candidate.map({ $0 === boundaryView || $0.isDescendant(of: boundaryView) }) != true { return boundary }
        while let view = candidate {
            if let lease = visible.first(where: { $0.view === view && ($0.active || $0.scope == .review) }) { return lease }
            if view === boundary?.view { break }
            candidate = view.superview
        }
        return boundary
    }
    func invocation(in window: NSWindow) -> CommandInvocation? {
        guard let state = appState, let registration = registration(for: window) else { return nil }
        let lease = activeLease(in: window)
        let scope: AppCommandScope
        if registration.scope == .commandPanel || registration.scope == .helpPanel {
            scope = panels.session(in: window)?.capturing != nil ? .shortcutCapture : registration.scope
        }
        else if let text = window.firstResponder as? NSTextView, text.isEditable || text.isSelectable {
            scope = (lease?.scope ?? registration.scope).textEditingScope
        }
        else if window.sheetParent != nil && lease == nil { scope = .editor }
        else { scope = lease?.scope ?? registration.scope }
        // An actual containing Settings/editor surface owns its field editor too.
        // Generic window text has no lease; native editing still limits commands
        // through the effective editor scope and the registry's text protections.
        let retained = lease
        return .init(window: window, scope: scope, lease: retained, state: state, windowRegistrationID: registration.instanceID,
            surfaces: retained.map { surfaceChain(for: $0, editing: scope.isTextEditing) })
    }
    func isCurrent(_ invocation: CommandInvocation) -> Bool {
        guard let state = appState, let window = invocation.window, registration(for: window)?.instanceID == invocation.windowRegistrationID,
              invocation.fingerprint == .init(state) else { return false }
        guard window.attachedSheet == nil else { return false }
        if let modal = modalLease(in: window), invocation.lease !== modal {
            guard let child = invocation.lease?.view, let container = modal.view, child.isDescendant(of: container) else { return false }
        }
        if let token = invocation.leaseToken {
            guard let lease = invocation.lease, leases[token] === lease, (lease.active || lease.scope == .review), lease.view?.window === window, lease.view?.isHiddenOrHasHiddenAncestor == false,
                  (!invocation.requiresFocusedOwner || activeLease(in: window) === lease) else { return false }
        }
        if let lease = invocation.lease {
            let currentChain = surfaceChain(for: lease, editing: invocation.scope.isTextEditing)
            guard currentChain.count == invocation.surfaces.count else { return false }
            for (current, captured) in zip(currentChain, invocation.surfaces) {
                guard let exact = captured.lease, current.lease === exact, current.token == captured.token,
                      current.sourceScope == captured.sourceScope, current.effectiveScope == captured.effectiveScope,
                      leases[captured.token] === exact, exact.active || exact.scope == .review,
                      exact.view?.window === window, exact.view?.isHiddenOrHasHiddenAncestor == false else { return false }
            }
        }
        if invocation.scope.isTextEditing {
            guard window.firstResponder === invocation.responder else { return false }
            if let editor = window.firstResponder as? NSTextView {
                guard editor.string == invocation.text, editor.selectedRange() == invocation.selection else { return false }
            }
            if let control = invocation.fieldControl, let editor = window.firstResponder as? NSTextView {
                guard editor.delegate as AnyObject? === control, control.window === window else { return false }
            }
        }
        return true
    }
    func unavailableReason(_ id: AppCommandID, invocation: CommandInvocation?) -> String? {
        guard let state = appState, let invocation, isCurrent(invocation) else { return "The original selection or window has changed." }
        let definition = AppCommandRegistry.definition(id)
        let handler = handler(for: id, invocation: invocation)
        guard definition.scopes.contains(invocation.scope) || handler != nil else { return "Available in another pane." }
        _ = registry
        if cachedConflictingIDs.contains(id) || conflictingIDs(in: invocation).contains(id) { return "A saved shortcut conflicts with another command. Change it in Settings." }
        if id == .rebindCommand || [.palettePrevious, .paletteNext, .paletteRun, .closeCommandPanel, .cancelShortcutCapture].contains(id) {
            return invocation.window.flatMap { panels.session(in: $0) } != nil ? nil : "Open the command palette first."
        }
        if definition.commitsDraft,
           let editor = invocation.window?.firstResponder as? NSTextView, editor.hasMarkedText() { return "Finish composing the text before confirming this form." }
        if id == .toggleInspector, registration(for: invocation.window!)?.scope != .main,
           !(registration(for: invocation.window!)?.scope == .preview && invocation.scope == .preview && handler != nil) { return "The Inspector belongs to the main Walkfolio window." }
        if id == .find { return registration(for: invocation.window!)?.findAction != nil ? nil : "Find is available in the main Walkfolio view." }
        if isPresentationCommand(id) { return nil }
        if let handler {
            return handler.availability(id) ? nil : "Unavailable for the current photo or selection."
        }
        guard !definition.needsSurfaceHandler else { return "Focus the pane that offers this action." }
        return definition.enabled(state) ? nil : "Unavailable for the current selection or operation."
    }
    private func handler(for id: AppCommandID, invocation: CommandInvocation) -> CommandSurfaceLease? {
        let definition = AppCommandRegistry.definition(id)
        guard invocation.surfaces.contains(where: { definition.scopes.contains($0.effectiveScope) }) else { return nil }
        // An explicit child handler shadows its ancestor, including when disabled.
        return invocation.surfaces.first { $0.lease?.supports(id) == true }?.lease
    }
    /// The same explicit leaf/containing-handler route powers events and discovery.
    private func bindingsForCurrentOrigin(_ id: AppCommandID, _ invocation: CommandInvocation) -> [AppCommandBinding] {
        let definition = AppCommandRegistry.definition(id)
        let active = invocation.surfaces.filter { definition.scopes.contains($0.effectiveScope) }
        return registry.bindings(id).filter { binding in
            binding.scopes.contains(invocation.scope) || active.contains {
                binding.scopes.contains($0.effectiveScope) && $0.lease?.supports(id) == true
            }
        }
    }
    func effectiveBindings(_ id: AppCommandID, invocation: CommandInvocation?) -> [AppCommandBinding] {
        guard let invocation, isCurrent(invocation) else { return [] }
        return bindingsForCurrentOrigin(id, invocation)
    }
    /// One synchronous native refresh shares the ownership check across its keys.
    func effectiveBindings(_ ids: Set<AppCommandID>, invocation: CommandInvocation?) -> [AppCommandID: [AppCommandBinding]] {
        guard let invocation, isCurrent(invocation) else { return [:] }
        return Dictionary(uniqueKeysWithValues: ids.map { ($0, bindingsForCurrentOrigin($0, invocation)) })
    }
    func effectiveShortcutLabel(_ id: AppCommandID, invocation: CommandInvocation?) -> String {
        let chords = effectiveBindings(id, invocation: invocation).map(\.shortcut.display)
        if !chords.isEmpty { return Array(NSOrderedSet(array: chords)).compactMap { $0 as? String }.joined(separator: " · ") }
        return registry.bindings(id).isEmpty ? "Unassigned" : "Available in another pane"
    }
    func offeredIDs(in invocation: CommandInvocation) -> Set<AppCommandID> {
        Set(AppCommandRegistry.commands.filter { command in
            command.scopes.contains(invocation.scope) || invocation.surfaces.dropFirst().contains {
                command.scopes.contains($0.effectiveScope) && $0.lease?.supports(command.id) == true
            }
        }.map(\.id))
    }
    private var cachedOfferedIDs: Set<AppCommandID>?
    private var cachedRuntimeScopes: [AppCommandScope]?
    private var cachedRuntimeOverrides: [String: AppShortcutOverride]?
    private var cachedRuntimeConflicts: Set<AppCommandID> = []
    private func conflictingIDs(in invocation: CommandInvocation) -> Set<AppCommandID> {
        let offered = offeredIDs(in: invocation), overrides = appState?.settings.commandShortcutOverrides ?? [:]
        let scopes = [invocation.scope] + invocation.surfaces.map(\.effectiveScope)
        if cachedOfferedIDs != offered || cachedRuntimeOverrides != overrides || cachedRuntimeScopes != scopes {
            cachedOfferedIDs = offered; cachedRuntimeOverrides = overrides; cachedRuntimeScopes = scopes
            var chords: [AppShortcut: Set<AppCommandID>] = [:]
            for id in offered {
                for binding in effectiveBindings(id, invocation: invocation) {
                    chords[binding.shortcut, default: []].insert(id)
                }
            }
            cachedRuntimeConflicts = Set(chords.values.filter { $0.count > 1 }.flatMap { $0 })
        }
        return cachedRuntimeConflicts
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
        let effectiveHandler = handler(for: id, invocation: captured)
        if captured.scope == .review || effectiveHandler?.scope == .review { state.activePane = .media; state.reviewGridHasFocus = true }
        else if captured.scope == .sourceSidebar { state.activePane = .sidebar }
        let invocation = CommandInvocation(window: window, scope: captured.scope, lease: captured.lease, state: state, windowRegistrationID: captured.windowRegistrationID, requiresFocusedOwner: captured.requiresFocusedOwner, surfaces: captured.surfaces)
        guard unavailableReason(id, invocation: invocation) == nil else { return false }
        let previous = executingWindow, previousSurface = executingSurface, previousChain = executingSurfaceChain, previousSnapshots = executingSurfaceSnapshots
        executingWindow = window; executingSurface = effectiveHandler ?? invocation.lease
        let chain = invocation.surfaces.compactMap(\.lease)
        if let handler = executingSurface, let index = chain.firstIndex(where: { $0 === handler }) {
            executingSurfaceChain = Array(chain[index...])
            executingSurfaceSnapshots = Array(invocation.surfaces[index...])
        } else { executingSurfaceChain = chain; executingSurfaceSnapshots = invocation.surfaces }
        defer { executingWindow = previous; executingSurface = previousSurface; executingSurfaceChain = previousChain; executingSurfaceSnapshots = previousSnapshots }
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
            if let handler = handler(for: id, invocation: invocation) { return handler.run(id) }
            AppCommandRegistry.definition(id).run(state)
        }
        return true
    }
    @discardableResult
    func execute(_ id: AppCommandID, in window: NSWindow? = NSApp?.keyWindow) -> Bool {
        execute(id, invocation: window.flatMap { invocation(in: $0) })
    }
    @discardableResult
    func executeWindowControl(_ id: AppCommandID, in requested: NSWindow? = NSApp?.keyWindow) -> Bool {
        guard let window = requested, let state = appState, let owner = registration(for: window),
              owner.scope == .main || owner.scope == .settings, window.attachedSheet == nil else { return false }
        // Clicking an app-window control explicitly invokes that window's action,
        // even when a text field was the first responder. Local target actions use
        // their own captured surface capability instead of this window route.
        let current = invocation(in: window)
        if let current, AppCommandRegistry.definition(id).scopes.contains(current.scope) {
            return execute(id, invocation: current)
        }
        return execute(id, invocation: CommandInvocation(window: window, scope: owner.scope, lease: nil, state: state, windowRegistrationID: owner.instanceID))
    }

    @discardableResult
    func handle(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard event.type == .keyDown, registration(for: window) != nil else { return false }
        nativeMenus.prepareForKeyboardDispatch(in: window)
        // Menu navigation owns its key events while tracking, including Return.
        guard !nativeMenus.isTracking else { return false }
        // Composition owns candidate navigation, Return and cancellation, including
        // shortcut capture. Falling through would execute the highlighted command.
        if let text = window.firstResponder as? NSTextView, text.hasMarkedText(),
           !event.modifierFlags.contains(.command) || ["return", "escape"].contains(AppShortcut(event: event)?.key ?? "") { return false }
        if panels.handleCapture(event, in: window) { return true }
        guard let origin = invocation(in: window) else { return false }
        guard let shortcut = AppShortcut(event: event) else { return false }
        let claims = offeredIDs(in: origin).filter { id in
            // Filter the chord before repeating native ownership checks.
            registry.bindings(id).contains { $0.shortcut == shortcut }
                && effectiveBindings(id, invocation: origin).contains { $0.shortcut == shortcut }
        }
        guard !claims.isEmpty else { return false }
        guard claims.count == 1 else { return true }
        let id = claims.first!
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
        let targetLease: CommandSurfaceLease?
        let focusChain: [CommandSurfaceSnapshot]?
        if let index = executingSurfaceChain.firstIndex(where: { $0.scope == scope }) {
            let surface = executingSurfaceChain[index]
            guard surface.active, surface.view?.window === window, leases[surface.token] === surface else { return }
            // Use the captured containing ancestor. A new parent cannot lend its
            // authority after an action synchronously replaces or removes the old one.
            targetLease = surface
            focusChain = Array(executingSurfaceSnapshots[index...])
        } else {
            focusChain = nil
            targetLease = leases.values.filter { $0.scope == scope && $0.active && $0.view?.window === window }
                .max { leaseOrders[$0.token, default: 0] < leaseOrders[$1.token, default: 0] }
        }
        let targetToken = targetLease?.token, prior = window.firstResponder
        let focusOrigin = targetLease.map { CommandInvocation(window: window, scope: scope, lease: $0, state: state,
            windowRegistrationID: registrationID!, requiresFocusedOwner: false, surfaces: focusChain ?? surfaceChain(for: $0)) }
        let requestedTarget = targetLease.flatMap { $0.focusTarget.map { $0() } ?? $0.view }
        DispatchQueue.main.async { [weak self, weak window, weak prior, weak targetLease, weak requestedTarget] in
            guard let self, let state = self.appState, let window, self.focusRevisions[owner] == revision,
                  self.registration(for: window)?.instanceID == registrationID,
                  fingerprint == .init(state), window.attachedSheet == nil, window.firstResponder === prior else { return }
            if let focusOrigin, !self.isCurrent(focusOrigin) { return }
            let lease: CommandSurfaceLease?
            if let targetToken {
                guard let targetLease, self.leases[targetToken] === targetLease else { return }
                lease = targetLease
            } else {
                // A just-shown pane may mount on the next layout pass.
                lease = self.leases.values.filter { $0.scope == scope && $0.active && $0.view?.window === window }
                    .max { self.leaseOrders[$0.token, default: 0] < self.leaseOrders[$1.token, default: 0] }
            }
            guard let lease, lease.active, lease.scope == scope, let view = lease.view,
                  view.window === window, !view.isHiddenOrHasHiddenAncestor else { return }
            let target: NSView
            if let resolve = lease.focusTarget {
                guard let explicit = resolve() else { return }; target = explicit
            } else { target = view }
            guard targetToken == nil || requestedTarget === target,
                  target.window === window, !target.isHiddenOrHasHiddenAncestor,
                  target === view || target.isDescendant(of: view), target.acceptsFirstResponder else { return }
            if let boundary = self.modalLease(in: window)?.view {
                guard (view === boundary || view.isDescendant(of: boundary)),
                      (target === boundary || target.isDescendant(of: boundary)) else { return }
            }
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
