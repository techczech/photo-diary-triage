import AppKit
import SwiftUI

func sourceFolderBrowserIsDisplayed(mode: WorkspaceMode, contextMediaItemCount: Int, hasFolders: Bool) -> Bool {
    mode != .archiveView && mode != .photoLogs && contextMediaItemCount == 0 && hasFolders
}

@MainActor
func sourceBrowserCommandContextKey(_ state: AppState) -> String {
    localCommandContextKey([String(state.browserTreeRevision), state.workspaceMode.rawValue,
        state.settings.archiveRoot.standardizedFileURL.path,
        state.settings.oneDrivePicturesRoot.standardizedFileURL.path,
        state.settings.archiveMachineRole.rawValue, String(ArchiveByteReadPolicyContext.shared.generation)])
}

@MainActor
func sourceFolderCommandContextKey(_ state: AppState) -> String {
    localCommandContextKey([sourceBrowserCommandContextKey(state), String(state.reviewPaneRevision),
        state.selectedSidebarNodeID ?? ""])
}

@MainActor
private func sourceTreeIsCurrent(_ state: AppState, context: String) -> Bool {
    context == sourceBrowserCommandContextKey(state)
        && (state.workspaceMode == .cameraTriage || state.workspaceMode == .photoLogs)
}

@MainActor
func sourceSidebarSelectionBinding(_ state: AppState, context: String, handle: LocalCommandHandle) -> Binding<String?> {
    .init(get: { state.selectedSidebarNodeID }, set: { id in
        guard handle.isCurrent(), sourceTreeIsCurrent(state, context: context),
              id == nil || id.flatMap({ state.browserNodeMap[$0] }) != nil else { return }
        state.selectSidebarNode(id)
    })
}

@MainActor
func selectDisplayedSourceNode(_ state: AppState, node: BrowserNode, context: String, handle: LocalCommandHandle) {
    guard handle.isCurrent(), sourceTreeIsCurrent(state, context: context),
          state.browserNodeMap[node.id] == node else { return }
    state.selectSidebarNode(node.id)
}

@MainActor
func sourceFolderSelectionBinding(_ state: AppState, context: String, handle: LocalCommandHandle) -> Binding<Set<String>> {
    .init(get: { state.selectedFolderNodeIDs }, set: { ids in
        guard handle.isCurrent(), context == sourceFolderCommandContextKey(state),
              ids.isSubset(of: Set(state.detailFolderNodes.map(\.id))) else { return }
        state.selectFolderNodes(ids)
    })
}

@MainActor
func openDisplayedSourceFolder(_ state: AppState, node: BrowserNode, context: String, handle: LocalCommandHandle) {
    guard handle.isCurrent(), context == sourceFolderCommandContextKey(state),
          state.detailFolderNodes.contains(node) else { return }
    // A row opens its displayed node; a failed selection must never fall through
    // to whichever folder another surface currently has selected.
    state.selectFolderNodes([node.id])
    handle.run(.open)
}

@MainActor
func sourceFolderCommandActions(_ state: AppState, context: String) -> [AppCommandID: SheetCommandAction] {
    func current() -> Bool {
        context == sourceFolderCommandContextKey(state)
            && sourceTreeIsCurrent(state, context: sourceBrowserCommandContextKey(state))
            && state.isSourceFolderBrowserDisplayed
    }
    func selected() -> BrowserNode? {
        guard state.selectedFolderNodeIDs.count == 1, let id = state.selectedFolderNodeIDs.first else { return nil }
        return state.detailFolderNodes.first { $0.id == id }
    }
    return [
        .selectAllFolders: .init(run: {
            guard current() else { return }
            state.selectFolderNodes(Set(state.detailFolderNodes.map(\.id)))
        }, liveEnabled: current),
        .deselectFolders: .init(run: {
            guard current(), !state.selectedFolderNodeIDs.isEmpty else { return }; state.selectFolderNodes([])
        }, liveEnabled: { current() && !state.selectedFolderNodeIDs.isEmpty }),
        .open: .init(run: {
            guard current(), let node = selected() else { return }
            state.selectSidebarNode(node.id); state.focusReviewSurface()
        }, liveEnabled: { current() && selected() != nil })
    ]
}

@MainActor
func sourceNavigationFocusTarget(_ owner: CommandLocalSurfaceView) -> NSView? {
    func table(_ view: NSView) -> NSView? {
        if view is NSTableView || view is NSOutlineView { return view }
        for child in view.subviews { if let found = table(child) { return found } }
        return nil
    }
    return table(owner.host)
}

struct SourceSidebarCommandSurface<Content: View>: View {
    let appState: AppState, contextKey: String
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .sourceSidebar,
            contextKey: contextKey, actions: [.open: .init(run: {
                guard sourceTreeIsCurrent(appState, context: contextKey), appState.canFocusBrowserDetail else { return }
                appState.focusReviewSurface()
            }, liveEnabled: { sourceTreeIsCurrent(appState, context: contextKey) && appState.canFocusBrowserDetail })], contextIsCurrent: { sourceTreeIsCurrent(appState, context: contextKey) },
            fillsAvailableHeight: true, focusTarget: sourceNavigationFocusTarget, content: content)
    }
}
