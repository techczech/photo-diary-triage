import AppKit
import SwiftUI

struct ReviewKeyInputView: NSViewRepresentable {
    let appState: AppState
    var commandScope: AppCommandScope = .review
    let isFocused: Bool
    let onArrow: (_ dx: Int, _ dy: Int, _ extending: Bool) -> Void
    let onSectionArrow: (_ dx: Int, _ dy: Int) -> Void
    let onSectionExpandCollapse: (_ expand: Bool) -> Void
    let onSingleKey: (_ key: String) -> Void
    let onPan: ((_ dx: Int, _ dy: Int) -> Void)?
    let onSpace: () -> Void
    let onOpen: () -> Void
    let onCommandOpen: () -> Void
    let onEscape: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    let onCropVisible: () -> Void
    let onToggleSidebar: () -> Void
    let onToggleInspector: () -> Void

    func makeNSView(context: Context) -> ReviewKeyResponderView {
        let view = ReviewKeyResponderView()
        view.onArrow = onArrow
        view.onSectionArrow = onSectionArrow
        view.onSectionExpandCollapse = onSectionExpandCollapse
        view.onSingleKey = onSingleKey
        view.onPan = onPan
        view.onSpace = onSpace
        view.onOpen = onOpen
        view.onCommandOpen = onCommandOpen
        view.onEscape = onEscape
        view.onSelectAll = onSelectAll
        view.onDeselectAll = onDeselectAll
        view.onZoomIn = onZoomIn
        view.onZoomOut = onZoomOut
        view.onZoomReset = onZoomReset
        view.onCropVisible = onCropVisible
        view.onToggleSidebar = onToggleSidebar
        view.onToggleInspector = onToggleInspector
        return view
    }

    func updateNSView(_ nsView: ReviewKeyResponderView, context: Context) {
        nsView.onArrow = onArrow
        nsView.onSectionArrow = onSectionArrow
        nsView.onSectionExpandCollapse = onSectionExpandCollapse
        nsView.onSingleKey = onSingleKey
        nsView.onPan = onPan
        nsView.onSpace = onSpace
        nsView.onOpen = onOpen
        nsView.onCommandOpen = onCommandOpen
        nsView.onEscape = onEscape
        nsView.onSelectAll = onSelectAll
        nsView.onDeselectAll = onDeselectAll
        nsView.onZoomIn = onZoomIn
        nsView.onZoomOut = onZoomOut
        nsView.onZoomReset = onZoomReset
        nsView.onCropVisible = onCropVisible
        nsView.onToggleSidebar = onToggleSidebar
        nsView.onToggleInspector = onToggleInspector

        nsView.configureCommands(coordinator: appState.commandCoordinator, scope: commandScope, focused: isFocused)
    }
}

final class ReviewKeyResponderView: NSView {
    var isHandlingKeys = false
    weak var coordinator: CommandKeyboardCoordinator?
    private let commandToken = UUID()
    private var lease: CommandSurfaceLease?
    static let surfaceCommands: Set<AppCommandID> = [.moveLeft, .moveRight, .moveUp, .moveDown, .extendLeft, .extendRight, .extendUp, .extendDown,
        .previousGroup, .nextGroup, .expandGroup, .collapseGroup, .toggleSelection, .activateFocused, .open, .closeSurface,
        .selectAll, .deselectAll, .zoomIn, .zoomOut, .zoomReset, .cropVisible, .panLeft, .panRight, .panUp, .panDown,
        .removeCompareItem, .markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW, .toggleSidebar, .toggleInspector]
    func configureCommands(coordinator: CommandKeyboardCoordinator, scope: AppCommandScope, focused: Bool) {
        let gainedFocus = focused && !isHandlingKeys
        if self.coordinator !== coordinator { self.coordinator?.unregisterSurface(commandToken); lease = nil }
        self.coordinator = coordinator; commandScope = scope; isHandlingKeys = focused
        registerCommands()
        if gainedFocus, let window { coordinator.requestFocus(scope: scope, in: window) }
    }
    private func registerCommands() {
        guard window != nil, let coordinator else { return }
        if lease == nil {
            lease = CommandSurfaceLease(view: self, token: commandToken, scope: commandScope, active: isHandlingKeys,
                supports: { Self.surfaceCommands.contains($0) }, availability: { [weak self] in self?.commandIsAvailable($0) ?? false },
                run: { [weak self] in self?.perform($0) ?? false })
        }
        lease!.scope = commandScope; lease!.active = isHandlingKeys; coordinator.register(lease!)
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { coordinator?.unregisterSurface(commandToken); lease = nil }
        else { registerCommands(); if isHandlingKeys { coordinator?.requestFocus(scope: commandScope, in: window) } }
    }
    func commandIsAvailable(_ id: AppCommandID) -> Bool {
        guard let state = coordinator?.appState else { return false }
        if [.markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW].contains(id), commandScope == .preview {
            guard state.canMutateImportSelection, let item = state.previewingMediaItem, !item.lifecycleState.isImportedOrBeyond else { return false }
            return id != .toggleRAW || !item.companionFiles.isEmpty
        }
        if [.markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW].contains(id), commandScope == .review {
            let ids = state.selectedMediaItemIDs.isEmpty ? Set(state.focusedReviewItemID.map { [$0] } ?? []) : state.selectedMediaItemIDs
            guard state.canMutateImportSelection, !ids.isEmpty else { return false }
            return id != .toggleRAW || state.currentSession?.mediaItems.contains { ids.contains($0.id) && !$0.companionFiles.isEmpty } == true
        }
        let definition = AppCommandRegistry.definition(id)
        return definition.needsSurfaceHandler || definition.enabled(state)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let window else { return false }; return coordinator?.handle(event, in: window) ?? false
    }
    var onArrow: ((_ dx: Int, _ dy: Int, _ extending: Bool) -> Void)?
    var onSectionArrow: ((_ dx: Int, _ dy: Int) -> Void)?
    var onSectionExpandCollapse: ((_ expand: Bool) -> Void)?
    var onSingleKey: ((_ key: String) -> Void)?
    var onPan: ((_ dx: Int, _ dy: Int) -> Void)?
    var onSpace: (() -> Void)?
    var onOpen: (() -> Void)?
    var onCommandOpen: (() -> Void)?
    var onEscape: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onZoomReset: (() -> Void)?
    var onCropVisible: (() -> Void)?
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    var commandScope: AppCommandScope = .review
    var shortcutOverrides: [String: AppShortcutOverride] = [:]

    override func keyDown(with event: NSEvent) {
        if let coordinator, let window {
            if !coordinator.handle(event, in: window) { super.keyDown(with: event) }
            return
        }
        guard isHandlingKeys, window?.firstResponder === self,
              let command = AppCommandRegistry(overrides: shortcutOverrides).command(for: event, scope: commandScope),
              perform(command) else { super.keyDown(with: event); return }
    }

    @discardableResult
    func perform(_ command: AppCommandID) -> Bool {
        switch command {
        case .moveLeft: onArrow?(-1,0,false)
        case .moveRight: onArrow?(1,0,false)
        case .moveUp: onArrow?(0,-1,false)
        case .moveDown: onArrow?(0,1,false)
        case .extendLeft: onArrow?(-1,0,true)
        case .extendRight: onArrow?(1,0,true)
        case .extendUp: onArrow?(0,-1,true)
        case .extendDown: onArrow?(0,1,true)
        case .previousGroup: onSectionArrow?(0,-1)
        case .nextGroup: onSectionArrow?(0,1)
        case .expandGroup: onSectionExpandCollapse?(true)
        case .collapseGroup: onSectionExpandCollapse?(false)
        case .toggleSelection: onSpace?()
        case .activateFocused: onOpen?()
        case .open: onCommandOpen?()
        case .closeSurface: onEscape?()
        case .selectAll: onSelectAll?()
        case .deselectAll: onDeselectAll?()
        case .zoomIn: onZoomIn?()
        case .zoomOut: onZoomOut?()
        case .zoomReset: onZoomReset?()
        case .cropVisible: onCropVisible?()
        case .panLeft: onPan?(-1,0)
        case .panRight: onPan?(1,0)
        case .panUp: onPan?(0,-1)
        case .panDown: onPan?(0,1)
        case .removeCompareItem: onSingleKey?("Q")
        case .markIncluded: onSingleKey?("S")
        case .markExcluded: onSingleKey?("X")
        case .markCandidate: onSingleKey?("C")
        case .clearTriage: onSingleKey?("D")
        case .toggleRAW: onSingleKey?("R")
        case .toggleSidebar: onToggleSidebar?()
        case .toggleInspector: onToggleInspector?()
        default: return false
        }
        return true
    }

}

