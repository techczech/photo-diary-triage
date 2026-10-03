import AppKit
import SwiftUI

private struct NativeMenuContext {
    weak var window: NSWindow?
    let hadWindow: Bool
    let origin: CommandInvocation?
    @MainActor init(_ coordinator: CommandKeyboardCoordinator, window: NSWindow?) {
        self.window = window; hadWindow = window != nil
        origin = window.flatMap { coordinator.invocation(in: $0) }
    }
    @MainActor func isCurrent(_ coordinator: CommandKeyboardCoordinator, window current: NSWindow?) -> Bool {
        guard window === current, hadWindow == (current != nil) else { return false }
        return origin.map { $0.window?.firstResponder === $0.responder && coordinator.isCurrent($0) } ?? !hadWindow
    }
}

/// Adopts only generated Walkfolio entries. Native Edit/Window/Services items,
/// delegates and auto-enabling policies remain owned by SwiftUI/AppKit.
@MainActor
final class CommandNativeMenus: NSObject, NSMenuItemValidation {
    static let identifierPrefix = "walkfolio.command."
    weak var coordinator: CommandKeyboardCoordinator?
    var windowProvider: () -> NSWindow?
    var settingsOpener: (() -> Void)?
    private let commandIDs: Set<AppCommandID>
    private let placements: [AppCommandID: String]
    private weak var root: NSMenu?
    private var rootProvider: (() -> NSMenu?)?
    private var observers: [NSObjectProtocol] = []
    private var synchronising = false
    private var refreshQueued = false
    private var trackingContext: NativeMenuContext?
    private var trackingMenus: Set<ObjectIdentifier> = []
    var isTracking: Bool { !trackingMenus.isEmpty }

    init(coordinator: CommandKeyboardCoordinator, commandIDs: Set<AppCommandID> = PhotoDiaryCommands.nativeCommandIDs,
         windowProvider: @escaping () -> NSWindow? = { NSApp?.keyWindow }, settingsOpener: (() -> Void)? = nil,
         placements: [AppCommandID: String]? = nil) {
        self.coordinator = coordinator; self.commandIDs = commandIDs
        self.windowProvider = windowProvider; self.settingsOpener = settingsOpener
        self.placements = placements ?? PhotoDiaryCommands.nativeCommandParentTitles
    }
    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func installForApplication(settingsOpener: @escaping () -> Void) {
        self.settingsOpener = settingsOpener; rootProvider = { NSApp?.mainMenu }
        observeMenus()
        refresh()
        queueRefresh() // The first window can attach before SwiftUI publishes its menu.
    }
    func attach(to root: NSMenu) {
        self.root = root; rootProvider = nil; observeMenus(); refresh()
    }
    private func allItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { [$0] + ($0.submenu.map { allItems(in: $0) } ?? []) }
    }
    private func belongsToRoot(_ menu: NSMenu) -> Bool {
        guard let root = rootProvider?() ?? root else { return false }
        return menu === root || allItems(in: root).contains { $0.submenu === menu }
    }
    private func commandID(for item: NSMenuItem) -> AppCommandID? {
        guard item.target === self, item.action == #selector(activate(_:)),
              let value = item.identifier?.rawValue, value.hasPrefix(Self.identifierPrefix),
              let id = AppCommandID(rawValue: String(value.dropFirst(Self.identifierPrefix.count))), commandIDs.contains(id) else { return nil }
        return id
    }
    private func allowedPlacement(_ id: AppCommandID, item: NSMenuItem) -> Bool {
        guard let root = rootProvider?() ?? root, let menu = item.menu, let expected = placements[id],
              item.submenu == nil, root.items.contains(where: { $0.submenu === menu }) else { return false }
        if expected == "@application" { return root.items.first?.submenu === menu }
        return menu.title == expected
    }
    private func adopt(_ items: [NSMenuItem]) {
        let titles = Dictionary(grouping: items.filter { !$0.isSeparatorItem && $0.submenu == nil }, by: \.title)
        for id in commandIDs {
            let identifier = NSUserInterfaceItemIdentifier(Self.identifierPrefix + id.rawValue)
            let tagged = items.filter { $0.identifier == identifier }
            let candidates = tagged.isEmpty ? titles[AppCommandRegistry.definition(id).title] ?? [] : tagged
            guard candidates.count == 1, let item = candidates.first, allowedPlacement(id, item: item),
                  item.identifier == nil || item.identifier == identifier || item.identifier?.rawValue == item.action.map(NSStringFromSelector),
                  !(item.target is CommandNativeMenus) || item.target === self else { continue }
            // Bootstrap requires a unique generated title in its declared menu.
            // An unrelated leaf elsewhere cannot acquire app-command authority.
            // AppKit derives an unset identifier from the action selector; that
            // default is accepted here, while explicit foreign IDs are retained.
            // Thereafter the stable ID survives display-title changes and redraws.
            if item.identifier != identifier { item.identifier = identifier }
            if item.target !== self { item.target = self }
            if item.action != #selector(activate(_:)) { item.action = #selector(activate(_:)) }
        }
    }
    private func liveContext(in window: NSWindow? = nil) -> NativeMenuContext? {
        guard let coordinator else { return nil }
        return trackingContext ?? NativeMenuContext(coordinator, window: window ?? windowProvider())
    }
    private func enabled(_ id: AppCommandID, context: NativeMenuContext?) -> Bool {
        guard let coordinator, let context, context.isCurrent(coordinator, window: windowProvider()) else { return false }
        if context.origin == nil { return id == .settings && !context.hadWindow && settingsOpener != nil }
        return coordinator.unavailableReason(id, invocation: context.origin) == nil
    }
    @discardableResult
    private func update(_ item: NSMenuItem, context: NativeMenuContext?) -> Bool {
        guard let id = commandID(for: item), let coordinator else { return false }
        let available = enabled(id, context: context)
        let binding = context.flatMap { $0.origin }.flatMap { coordinator.effectiveBindings(id, invocation: $0).first } ??
            (id == .settings && available ? coordinator.registry.bindings(id).first : nil)
        let key = binding?.shortcut.nativeKeyEquivalent ?? ""
        let modifiers = binding?.shortcut.modifiers.native ?? []
        if item.keyEquivalent != key { item.keyEquivalent = key }
        if item.keyEquivalentModifierMask != modifiers { item.keyEquivalentModifierMask = modifiers }
        if item.isEnabled != available { item.isEnabled = available }
        return available
    }
    private func updateKeys(_ item: NSMenuItem, binding: AppCommandBinding?) {
        let key = binding?.shortcut.nativeKeyEquivalent ?? ""
        let modifiers = binding?.shortcut.modifiers.native ?? []
        if item.keyEquivalent != key { item.keyEquivalent = key }
        if item.keyEquivalentModifierMask != modifiers { item.keyEquivalentModifierMask = modifiers }
    }
    func refresh(in window: NSWindow? = nil, validate: Bool = true) {
        guard !synchronising, let next = rootProvider?() ?? root, let coordinator else { return }
        synchronising = true; defer { synchronising = false }
        root = next
        let items = allItems(in: next); adopt(items)
        let context = liveContext(in: window)
        if validate {
            for item in items where commandID(for: item) != nil { update(item, context: context) }
        } else {
            // Native targets validate when menus open or actions dispatch. Each key
            // only needs fresh equivalents; repeating all eligibility/ownership
            // checks would make a large Review block while typing or navigating.
            let bindings = coordinator.effectiveBindings(commandIDs, invocation: context?.origin)
            for item in items {
                guard let id = commandID(for: item) else { continue }
                updateKeys(item, binding: bindings[id]?.first)
            }
        }
    }
    func prepareForKeyboardDispatch(in window: NSWindow) {
        guard !isTracking else { return }
        // An ended/cancelled menu cannot leave its capture attached to the next key.
        trackingContext = nil
        refresh(in: window, validate: false)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard !synchronising else { return menuItem.isEnabled }
        synchronising = true; defer { synchronising = false }
        return update(menuItem, context: liveContext())
    }
    @objc func activate(_ sender: NSMenuItem) {
        guard let id = commandID(for: sender) else { return }
        perform(id)
    }
    /// SwiftUI's unadopted/rebuilt placeholder uses the same captured authority.
    @discardableResult
    func perform(_ id: AppCommandID, settingsOpener fallback: (() -> Void)? = nil) -> Bool {
        guard commandIDs.contains(id), let coordinator else { return false }
        if settingsOpener == nil { settingsOpener = fallback }
        let context = liveContext()
        guard enabled(id, context: context) else { return false }
        return coordinator.execute(id, invocation: context?.origin, settingsOpener: settingsOpener)
    }
    private func queueRefresh() {
        guard !synchronising, !refreshQueued else { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }; self.refreshQueued = false; self.refresh()
        }
    }
    private func observeMenus() {
        guard observers.isEmpty else { return }
        for name in [NSMenu.didAddItemNotification, NSMenu.didChangeItemNotification, NSMenu.didBeginTrackingNotification,
                     NSMenu.didEndTrackingNotification, NSMenu.didSendActionNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                MainActor.assumeIsolated {
                    guard let self, !self.synchronising, let menu = note.object as? NSMenu else { return }
                    // A replaced/detached menu still owns its tracking-end receipt.
                    let knownEnd = note.name == NSMenu.didEndTrackingNotification && self.trackingMenus.contains(ObjectIdentifier(menu))
                    guard knownEnd || self.belongsToRoot(menu) else { return }
                    switch note.name {
                    case NSMenu.didBeginTrackingNotification:
                        if !self.isTracking, let coordinator = self.coordinator {
                            self.trackingContext = NativeMenuContext(coordinator, window: self.windowProvider())
                        }
                        self.trackingMenus.insert(ObjectIdentifier(menu)); self.refresh()
                    case NSMenu.didEndTrackingNotification:
                        // AppKit may end tracking before sending the selected action.
                        // Keep the exact origin until that action or the next key/menu.
                        self.trackingMenus.remove(ObjectIdentifier(menu))
                    case NSMenu.didSendActionNotification:
                        if !self.isTracking { self.trackingContext = nil }
                    default: self.queueRefresh()
                    }
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }
}

/// Only the real app scene installs application menus; hidden view fixtures don't.
struct CommandMenuInstallationAnchor: NSViewRepresentable {
    let coordinator: CommandKeyboardCoordinator
    @Environment(\.openSettings) private var openSettings
    func makeNSView(context: Context) -> CommandMenuInstallationView { CommandMenuInstallationView() }
    func updateNSView(_ view: CommandMenuInstallationView, context: Context) {
        view.coordinator = coordinator; view.settingsOpener = { openSettings() }; view.install()
    }
}
final class CommandMenuInstallationView: NSView {
    weak var coordinator: CommandKeyboardCoordinator?
    var settingsOpener: (() -> Void)?
    func install() {
        guard window != nil, let settingsOpener else { return }
        coordinator?.nativeMenus.installForApplication(settingsOpener: settingsOpener)
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); install() }
}
