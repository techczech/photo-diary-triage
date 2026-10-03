import AppKit
import SwiftUI

private struct LocalCommandAuthority: Equatable {
    let root: URL, pictures: URL, role: ArchiveMachineRole, generation: Int
    let googleContext: String
    @MainActor init(_ state: AppState) {
        googleContext = state.commandGoogleContextKey
        root = state.settings.archiveRoot.standardizedFileURL
        pictures = state.settings.oneDrivePicturesRoot.standardizedFileURL
        role = state.settings.archiveMachineRole; generation = ArchiveByteReadPolicyContext.shared.generation
    }
}

/// A button retains this exact capability rather than looking up a newer target.
@MainActor
struct LocalCommandHandle {
    weak var coordinator: CommandKeyboardCoordinator?
    weak var lease: CommandSurfaceLease?
    private let authority: LocalCommandAuthority?
    private let windowRegistrationID: UUID?
    private let surfaces: [CommandSurfaceSnapshot]
    init(coordinator: CommandKeyboardCoordinator, lease: CommandSurfaceLease?) {
        self.coordinator = coordinator; self.lease = lease
        surfaces = lease.map { coordinator.surfaceChain(for: $0) } ?? []
        authority = coordinator.appState.map(LocalCommandAuthority.init)
        windowRegistrationID = lease?.view?.window.flatMap { coordinator.registration(for: $0)?.instanceID }
    }
    private func capturedInvocation() -> (CommandKeyboardCoordinator, CommandInvocation)? {
        guard let coordinator, let lease, let window = lease.view?.window,
              let state = coordinator.appState, let owner = coordinator.registration(for: window),
              authority == LocalCommandAuthority(state),
              (windowRegistrationID ?? lease.firstOwnerRegistrationID) == owner.instanceID else { return nil }
        let origin = CommandInvocation(window: window, scope: lease.scope, lease: lease, state: state,
            windowRegistrationID: owner.instanceID, requiresFocusedOwner: false, surfaces: surfaces)
        return (coordinator, origin)
    }
    func isEnabled(_ id: AppCommandID) -> Bool {
        guard let (coordinator, origin) = capturedInvocation() else { return false }
        return coordinator.unavailableReason(id, invocation: origin) == nil
    }
    func run(_ id: AppCommandID) {
        guard let (coordinator, origin) = capturedInvocation() else { return }
        coordinator.execute(id, invocation: origin)
    }
}

/// Contains the actual controls, so a shared native field editor can be traced to
/// its owning container. Containing modal roots can also own their sheet window.
struct CommandLocalSurface<Content: View>: NSViewRepresentable {
    let coordinator: CommandKeyboardCoordinator
    let scope: AppCommandScope
    let contextKey: String
    let actions: [AppCommandID: SheetCommandAction]
    var ownsWindow = false
    var fillsAvailableHeight = false
    var focusesOnAttachment = false
    var focusTarget: ((CommandLocalSurfaceView) -> NSView?)? = nil
    @Environment(\.openSettings) private var openSettings
    @ViewBuilder let content: (LocalCommandHandle) -> Content

    func makeNSView(context: Context) -> CommandLocalSurfaceView { CommandLocalSurfaceView() }
    func updateNSView(_ view: CommandLocalSurfaceView, context: Context) {
        view.renderContent = { AnyView(content($0)) }
        view.configure(coordinator: coordinator, scope: scope, contextKey: contextKey, actions: actions, ownsWindow: ownsWindow, focusesOnAttachment: focusesOnAttachment, focusTarget: focusTarget, openSettings: { openSettings() })
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: CommandLocalSurfaceView, context: Context) -> CGSize? {
        let measured = view.measure(width: proposal.width.flatMap { $0.isFinite ? $0 : nil })
        // A scrollable Form consumes the tab's proposal instead of its entire
        // unconstrained ideal height. Inline fields keep their content height.
        return CGSize(width: measured.width, height: fillsAvailableHeight ? proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? measured.height : measured.height)
    }
    static func dismantleNSView(_ view: CommandLocalSurfaceView, coordinator: ()) { view.unregister() }
}

final class CommandLocalSurfaceView: NSView {
    let host = NSHostingView(rootView: AnyView(EmptyView()))
    weak var coordinator: CommandKeyboardCoordinator?
    var renderContent: ((LocalCommandHandle) -> AnyView)?
    private let token = UUID(), windowToken = UUID()
    private weak var registeredWindow: NSWindow?
    private var ownsWindow = false
    private var focusesOnAttachment = false
    private var ownedFocusTarget: ((CommandLocalSurfaceView) -> NSView?)?
    private weak var focusRequestedWindow: NSWindow?
    private var openSettings: (() -> Void)?
    private var lease: CommandSurfaceLease?
    private var contextKey: String?
    private var scope: AppCommandScope = .logDetails
    private var actions: [AppCommandID: SheetCommandAction] = [:]
    private var hostedContent = AnyView(EmptyView())
    private var measuredWidth: CGFloat?
    override init(frame: NSRect) {
        super.init(frame: frame)
        host.frame = bounds; host.autoresizingMask = [.width, .height]; addSubview(host)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { host.fittingSize }
    private func applyMeasuredWidth() { host.rootView = AnyView(hostedContent.frame(width: measuredWidth, alignment: .leading)) }
    func measure(width: CGFloat?) -> CGSize {
        // NSHostingView.fittingSize otherwise asks SwiftUI for an unconstrained ideal
        // width: changing the NSView frame alone cannot measure wrapped fields/grids.
        if measuredWidth != width { measuredWidth = width; applyMeasuredWidth() }
        let size = host.fittingSize
        return CGSize(width: width ?? size.width, height: size.height)
    }

    @discardableResult
    func configure(coordinator: CommandKeyboardCoordinator, scope: AppCommandScope, contextKey: String,
                   actions: [AppCommandID: SheetCommandAction], ownsWindow: Bool = false, focusesOnAttachment: Bool = false, focusTarget: ((CommandLocalSurfaceView) -> NSView?)? = nil, openSettings: (() -> Void)? = nil) -> LocalCommandHandle {
        if self.coordinator !== coordinator || self.ownsWindow != ownsWindow { unregister() }
        self.coordinator = coordinator; self.ownsWindow = ownsWindow; self.focusesOnAttachment = focusesOnAttachment; self.ownedFocusTarget = focusTarget; self.openSettings = openSettings
        registerOwnedWindow(scope: scope)
        let owner = window.flatMap { coordinator.registration(for: $0)?.instanceID }
        if self.scope != scope || self.contextKey != contextKey
            || (lease?.firstOwnerRegistrationID != nil && owner != lease?.firstOwnerRegistrationID) { unregisterLease() }
        self.coordinator = coordinator; self.scope = scope; self.contextKey = contextKey; self.actions = actions
        if lease == nil {
            lease = CommandSurfaceLease(view: self, token: token, scope: scope, active: true,
                supports: { [weak self] in self?.actions[$0] != nil },
                availability: { [weak self] in self?.actions[$0]?.enabled == true },
                run: { [weak self] id in
                    guard let action = self?.actions[id], action.enabled else { return false }
                    action.run(); return true
                })
        }
        // An explicit provider returning nil is not permission to focus the container.
        lease?.focusTarget = focusTarget == nil ? nil : { [weak self] in
            guard let self else { return nil }; return self.ownedFocusTarget?(self)
        }
        register()
        let handle = LocalCommandHandle(coordinator: coordinator, lease: lease)
        if focusesOnAttachment, let window, focusRequestedWindow !== window {
            focusRequestedWindow = window; coordinator.requestFocus(scope: scope, in: window)
        }
        if let renderContent { hostedContent = renderContent(handle); applyMeasuredWidth(); invalidateIntrinsicContentSize() }
        return handle
    }
    private func register() { if let lease, window != nil { coordinator?.register(lease) } }
    private func registerOwnedWindow(scope: AppCommandScope) {
        guard ownsWindow else { return }
        if registeredWindow !== window { coordinator?.unregisterWindow(windowToken); registeredWindow = nil }
        if let window {
            coordinator?.register(window: window, token: windowToken, scope: scope, openSettings: openSettings)
            registeredWindow = window
        }
    }
    private func unregisterLease() { coordinator?.unregisterSurface(token); lease = nil }
    func unregister() {
        unregisterLease(); coordinator?.unregisterWindow(windowToken); registeredWindow = nil; focusRequestedWindow = nil
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { unregister() } else if let coordinator, let contextKey {
            configure(coordinator: coordinator, scope: scope, contextKey: contextKey, actions: actions, ownsWindow: ownsWindow, focusesOnAttachment: focusesOnAttachment, focusTarget: ownedFocusTarget, openSettings: openSettings)
        }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let window else { return false }; return coordinator?.handle(event, in: window) ?? false
    }
    override func keyDown(with event: NSEvent) {
        guard let window, coordinator?.handle(event, in: window) == true else { super.keyDown(with: event); return }
    }
}

func localCommandContextKey(_ components: [String]) -> String {
    components.map { "\($0.utf8.count):\($0)" }.joined()
}

struct LogDetailsCommandSurface<Content: View>: View {
    let appState: AppState
    let sessionID: UUID
    let title: String, location: String, notes: String
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .logDetails,
            contextKey: localCommandContextKey([sessionID.uuidString, title, location, notes]),
            actions: [
                .saveLogDetails: .init(enabled: appState.currentSession?.id == sessionID && !appState.importOperation.isRunning,
                    run: { appState.updateWalkMetadata(title: title, location: location, notes: notes, sessionID: sessionID) }),
                .saveLogAndStartNext: .init(enabled: appState.currentSession?.id == sessionID && appState.canStartNewPhotoLogSession,
                    run: { appState.saveCurrentLogDetailsAndStartNext(title: title, location: location, notes: notes, sessionID: sessionID) })
            ], content: content)
    }
}

func tripLabelCommandContextKey(root: URL, trip: ArchiveBrowseEntry, draft: String, isEditing: Bool) -> String {
    localCommandContextKey([root.standardizedFileURL.path, trip.archiveRelativePath,
        trip.tripID?.uuidString ?? "no-canonical-trip", trip.locationLabelOverride ?? "", draft, String(isEditing)])
}

func walkCommitCommandContextKey(_ editor: WalkCommitEditorState) -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    let walks = (try? encoder.encode(editor.walks)).flatMap { String(data: $0, encoding: .utf8) } ?? "invalid-walk-draft"
    return localCommandContextKey([editor.id.uuidString, String(editor.isRecoveryPlan), editor.tripDisplayLabel,
        editor.walkDisplayLabel, walks] + editor.existingTrips.map {
            localCommandContextKey([$0.title, $0.folder.standardizedFileURL.path, $0.folderRelativePath, $0.year])
        })
}

@MainActor
func walkProposalCommandActions(appState: AppState, editor: WalkCommitEditorState, walkID: UUID,
                                onEdited: @escaping (WalkCommitEditorState) -> Void) -> [AppCommandID: SheetCommandAction] {
    let index = editor.walks.firstIndex { $0.id == walkID }
    let current = appState.presentationState.snapshot.activeWalkCommitEditor
    let editable = current?.id == editor.id && current?.isRecoveryPlan == false && !editor.isRecoveryPlan
    func apply(_ id: AppCommandID) {
        guard let current = appState.presentationState.snapshot.activeWalkCommitEditor,
              current.id == editor.id, !current.isRecoveryPlan, !editor.isRecoveryPlan else { return }
        appState.updateWalkCommitEditor(editor)
        if id == .mergeWalkProposal { appState.mergeWalkProposalWithPrevious(walkID) }
        else { appState.splitWalkProposal(walkID) }
        if let updated = appState.presentationState.snapshot.activeWalkCommitEditor, updated.id == editor.id { onEdited(updated) }
    }
    return [
        .mergeWalkProposal: .init(enabled: editable && index.map { $0 > 0 } == true, run: { apply(.mergeWalkProposal) }),
        .splitWalkProposal: .init(enabled: editable && index.map { editor.walks[$0].mediaItemIDs.count > 1 } == true, run: { apply(.splitWalkProposal) })
    ]
}
