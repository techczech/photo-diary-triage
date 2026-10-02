import AppKit
import SwiftUI

private struct LocalCommandAuthority: Equatable {
    let root: URL, pictures: URL, role: ArchiveMachineRole, generation: Int
    @MainActor init(_ state: AppState) {
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
    init(coordinator: CommandKeyboardCoordinator, lease: CommandSurfaceLease?) {
        self.coordinator = coordinator; self.lease = lease
        authority = coordinator.appState.map(LocalCommandAuthority.init)
        windowRegistrationID = lease?.view?.window.flatMap { coordinator.registration(for: $0)?.instanceID }
    }
    func run(_ id: AppCommandID) {
        guard let coordinator, let lease, let window = lease.view?.window,
              let state = coordinator.appState, let owner = coordinator.registration(for: window),
              authority == LocalCommandAuthority(state),
              (windowRegistrationID ?? lease.firstOwnerRegistrationID) == owner.instanceID else { return }
        let origin = CommandInvocation(window: window, scope: lease.scope, lease: lease, state: state,
            windowRegistrationID: owner.instanceID, requiresFocusedOwner: false)
        coordinator.execute(id, invocation: origin)
    }
}

/// Contains the actual controls, so a shared native field editor can be traced to
/// its owning container. It never claims ownership of the whole application window.
struct CommandLocalSurface<Content: View>: NSViewRepresentable {
    let coordinator: CommandKeyboardCoordinator
    let scope: AppCommandScope
    let contextKey: String
    let actions: [AppCommandID: SheetCommandAction]
    @ViewBuilder let content: (LocalCommandHandle) -> Content

    func makeNSView(context: Context) -> CommandLocalSurfaceView { CommandLocalSurfaceView() }
    func updateNSView(_ view: CommandLocalSurfaceView, context: Context) {
        view.renderContent = { AnyView(content($0)) }
        view.configure(coordinator: coordinator, scope: scope, contextKey: contextKey, actions: actions)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: CommandLocalSurfaceView, context: Context) -> CGSize? {
        view.measure(width: proposal.width.flatMap { $0.isFinite ? $0 : nil })
    }
    static func dismantleNSView(_ view: CommandLocalSurfaceView, coordinator: ()) { view.unregister() }
}

final class CommandLocalSurfaceView: NSView {
    let host = NSHostingView(rootView: AnyView(EmptyView()))
    weak var coordinator: CommandKeyboardCoordinator?
    var renderContent: ((LocalCommandHandle) -> AnyView)?
    private let token = UUID()
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
                   actions: [AppCommandID: SheetCommandAction]) -> LocalCommandHandle {
        let owner = window.flatMap { coordinator.registration(for: $0)?.instanceID }
        if self.coordinator !== coordinator || self.scope != scope || self.contextKey != contextKey
            || (lease?.firstOwnerRegistrationID != nil && owner != lease?.firstOwnerRegistrationID) { unregister() }
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
        register()
        let handle = LocalCommandHandle(coordinator: coordinator, lease: lease)
        if let renderContent { hostedContent = renderContent(handle); applyMeasuredWidth(); invalidateIntrinsicContentSize() }
        return handle
    }
    private func register() { if let lease, window != nil { coordinator?.register(lease) } }
    func unregister() { coordinator?.unregisterSurface(token); lease = nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { unregister() } else if let coordinator, let contextKey {
            configure(coordinator: coordinator, scope: scope, contextKey: contextKey, actions: actions)
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
