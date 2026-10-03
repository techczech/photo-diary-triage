import AppKit
import SwiftUI

enum CommandPanelMode { case palette, contextual, help }

@MainActor
final class CommandPanelSession: ObservableObject {
    let token = UUID()
    let mode: CommandPanelMode
    let origin: CommandInvocation
    let returnOrigin: CommandInvocation
    weak var controller: CommandPanelController?
    var panel: NSPanel?
    @Published var query = "" { didSet { reconcileHighlight() } }
    @Published var highlighted: AppCommandID?
    @Published var capturing: AppCommandID?
    @Published var error: String?
    init(mode: CommandPanelMode, origin: CommandInvocation, returnOrigin: CommandInvocation, controller: CommandPanelController) {
        self.mode = mode; self.origin = origin; self.returnOrigin = returnOrigin; self.controller = controller
        reconcileHighlight()
    }
    var commands: [AppCommandDefinition] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        return AppCommandRegistry.commands.filter { command in
            let haystack = (command.title + " " + command.task).lowercased()
            let matches = words.allSatisfy { haystack.contains($0) }
            if mode != .contextual { return matches }
            return matches && AppCommandRegistry.contextualCommands.contains(command.id)
                && controller?.coordinator?.offeredIDs(in: origin).contains(command.id) == true
        }
    }
    func reconcileHighlight() {
        if !commands.contains(where: { $0.id == highlighted }) { highlighted = commands.first?.id }
    }
    func move(_ delta: Int) {
        let rows = commands; guard !rows.isEmpty else { highlighted = nil; return }
        let index = rows.firstIndex { $0.id == highlighted } ?? 0
        highlighted = rows[min(max(index + delta, 0), rows.count - 1)].id
    }
}

@MainActor
final class CommandPanelController: NSObject, NSWindowDelegate {
    weak var coordinator: CommandKeyboardCoordinator?
    private(set) var sessions: [CommandPanelSession] = []
    var current: CommandPanelSession? { sessions.last }
    init(coordinator: CommandKeyboardCoordinator) { self.coordinator = coordinator }
    func session(in window: NSWindow) -> CommandPanelSession? { sessions.first { $0.panel === window } }
    @discardableResult
    func present(_ mode: CommandPanelMode, from origin: CommandInvocation) -> CommandPanelSession? {
        guard let coordinator, coordinator.isCurrent(origin), let window = origin.window else { return nil }
        let actionOrigin = session(in: window)?.origin ?? origin
        guard coordinator.isCurrent(actionOrigin) else { return nil }
        if let existing = sessions.first(where: { $0.mode == mode && $0.origin.window === actionOrigin.window }) {
            if coordinator.isCurrent(existing.origin) {
                if coordinator.presentsPanels { existing.panel?.makeKeyAndOrderFront(nil) }; return existing
            }
            close(existing, restore: false)
        }
        let session = CommandPanelSession(mode: mode, origin: actionOrigin, returnOrigin: origin, controller: self)
        sessions.append(session)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 660, height: 540), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.delegate = self
        panel.title = mode == .help ? "Keyboard shortcuts" : (mode == .contextual ? "Actions for this selection" : "Commands")
        panel.contentViewController = NSHostingController(rootView: CommandPanelView(session: session, coordinator: coordinator)
            .background(CommandWindowAnchor(coordinator: coordinator, scope: mode == .help ? .helpPanel : .commandPanel, registersWindow: false)))
        session.panel = panel
        coordinator.register(window: panel, token: session.token, scope: mode == .help ? .helpPanel : .commandPanel)
        // Hidden native tests use this same panel/responder path without ordering it.
        guard coordinator.presentsPanels else { return session }
        let frame = window.frame
        panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
        window.addChildWindow(panel, ordered: .above); panel.makeKeyAndOrderFront(nil)
        return session
    }
    func close(_ session: CommandPanelSession? = nil, restore: Bool = true) {
        guard let target = session ?? current, sessions.contains(where: { $0 === target }) else { return }
        var descendants: [CommandPanelSession] = [target]
        var index = 0
        while index < descendants.count {
            let parentWindow = descendants[index].panel
            descendants += sessions.filter { candidate in candidate.returnOrigin.window === parentWindow && !descendants.contains(where: { $0 === candidate }) }
            index += 1
        }
        let mayRestore = NSApp?.keyWindow == nil || descendants.contains { $0.panel === NSApp?.keyWindow }
        for closing in descendants.reversed() {
            coordinator?.unregisterWindow(closing.token)
            closing.panel?.delegate = nil
            if let panel = closing.panel { panel.parent?.removeChildWindow(panel); panel.close() }
            closing.panel = nil; sessions.removeAll { $0 === closing }
        }
        if restore && mayRestore, coordinator?.isCurrent(target.returnOrigin) == true { target.returnOrigin.restoreFocus() }
    }

    func ownerClosed(_ window: NSWindow) {
        let owned = sessions.filter { $0.origin.window === window || $0.returnOrigin.window === window }
        for session in owned { close(session, restore: false) }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let session = sessions.first(where: { $0.panel === window }) else { return }
        close(session)
    }
    func beginRebinding(_ requested: CommandPanelSession? = nil) {
        guard let session = requested ?? current, session.mode != .help, let highlighted = session.highlighted else { return }
        session.capturing = highlighted; session.error = nil
    }
    func handleCapture(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard let session = session(in: window), let id = session.capturing else { return false }
        if let editor = window.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        guard let shortcut = AppShortcut(event: event) else { return true }
        if coordinator?.registry.command(for: event, scope: .shortcutCapture) == .cancelShortcutCapture { session.capturing = nil; session.error = nil; return true }
        guard let coordinator, let state = coordinator.appState else { return true }
        if state.setCommandShortcut(id, override: .init(shortcut: shortcut)) { session.capturing = nil; session.error = nil }
        else { session.error = state.commandShortcutSaveError }
        return true
    }
    @discardableResult
    func perform(_ id: AppCommandID, in window: NSWindow) -> Bool {
        guard let session = session(in: window) else { return false }
        switch id {
        case .palettePrevious: session.move(-1)
        case .paletteNext: session.move(1)
        case .paletteRun: runHighlighted(session)
        case .closeCommandPanel: close(session)
        case .cancelShortcutCapture: session.capturing = nil; session.error = nil
        default: return false
        }
        return true
    }
    func runHighlighted(_ requested: CommandPanelSession? = nil) {
        guard let session = requested ?? current, let id = session.highlighted, let coordinator else { return }
        if let reason = coordinator.unavailableReason(id, invocation: session.origin) { session.error = reason; return }
        let origin = session.origin
        close(session)
        _ = coordinator.execute(id, invocation: origin)
    }
    func edit(_ id: AppCommandID, from origin: CommandInvocation) {
        guard let selected = present(.palette, from: origin) else { return }
        selected.highlighted = id; beginRebinding(selected)
    }
}

struct CommandPanelView: View {
    @ObservedObject var session: CommandPanelSession
    @ObservedObject var coordinator: CommandKeyboardCoordinator
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(session.mode == .help ? "Find a shortcut or task" : "Find a command", text: $session.query)
                .textFieldStyle(.roundedBorder).focused($searchFocused)
            if let capturing = session.capturing {
                Text("Press the new shortcut for “\(AppCommandRegistry.definition(capturing).title)”. \(coordinator.registry.displayedShortcuts(.cancelShortcutCapture)) cancels.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if let error = session.error { Text(error).foregroundStyle(.red).font(.callout) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(session.commands) { command in
                            let reason = coordinator.unavailableReason(command.id, invocation: session.origin)
                            Button {
                                session.highlighted = command.id
                                if session.mode != .help { session.controller?.runHighlighted(session) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(command.title).font(.body)
                                        Text(reason ?? command.task)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(coordinator.effectiveShortcutLabel(command.id, invocation: session.origin)).font(.caption.monospaced())
                                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(session.highlighted == command.id ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain).id(command.id)
                        }
                    }
                }
                .onChange(of: session.highlighted) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
            }
            HStack {
                if session.mode != .help {
                    Button("Change shortcut…") { session.controller?.beginRebinding(session) }.disabled(session.highlighted == nil)
                    Button("Unassign") { change(.init(shortcut: nil)) }.disabled(session.highlighted == nil)
                    Button("Use default") { change(nil) }.disabled(session.highlighted == nil)
                }
                Spacer(); Button("Close") { session.controller?.close(session) }
            }
        }.padding(16).frame(minWidth: 560, minHeight: 360)
            .onAppear { searchFocused = true }
    }
    private func change(_ override: AppShortcutOverride?) {
        guard let id = session.highlighted, let state = coordinator.appState else { return }
        if state.setCommandShortcut(id, override: override) { session.error = nil; coordinator.objectWillChange.send() }
        else { session.error = state.commandShortcutSaveError }
    }
}

struct CommandShortcutSettingsView: View {
    @ObservedObject var appState: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search commands with \(appState.commandCoordinator.registry.displayedShortcuts(.palette)). Change a shortcut here or in the command palette.")
            if let error = appState.commandShortcutSaveError { Text(error).foregroundStyle(.red) }
            if !appState.commandCoordinator.registry.collisions().isEmpty {
                Text("Some saved shortcuts conflict. Conflicting commands are disabled until their shortcuts are changed.").foregroundStyle(.red)
            }
            List(AppCommandRegistry.commands) { command in
                HStack {
                    VStack(alignment: .leading) { Text(command.title); Text(command.task).font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Text(appState.commandCoordinator.registry.displayedShortcuts(command.id)).font(.caption.monospaced())
                    Button("Change…") {
                        let coordinator = appState.commandCoordinator
                        if let window = NSApp?.keyWindow, let origin = coordinator.invocation(in: window) { coordinator.panels.edit(command.id, from: origin) }
                    }
                    Button("Unassign") { appState.setCommandShortcut(command.id, override: .init(shortcut: nil)) }
                    Button("Default") { appState.setCommandShortcut(command.id, override: nil) }
                }
            }
        }.padding(20).tabItem { Label("Shortcuts", systemImage: "keyboard") }
    }
}
