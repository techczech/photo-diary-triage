import SwiftUI

@MainActor
func sessionWorkflowCommandContextKey(_ appState: AppState) -> String {
    localCommandContextKey([appState.currentSession?.id.uuidString ?? "no-Log",
        String(appState.currentSessionRevision), appState.settings.archiveRoot.standardizedFileURL.path,
        appState.settings.oneDrivePicturesRoot.standardizedFileURL.path,
        appState.settings.archiveMachineRole.rawValue, String(ArchiveByteReadPolicyContext.shared.generation)])
}

@MainActor
func sessionWorkflowCommandActions(_ appState: AppState) -> [AppCommandID: SheetCommandAction] {
    let context = sessionWorkflowCommandContextKey(appState)
    let creationScope = photoLogCreationCommandContextKey(appState)
    return Dictionary(uniqueKeysWithValues: AppCommandRegistry.sessionWorkflowIDs.map { id in
        let command = AppCommandRegistry.definition(id)
        return (id, .init(enabled: command.enabled(appState), run: {
            guard context == sessionWorkflowCommandContextKey(appState), command.enabled(appState) else { return }
            if id == .newPhotoLog, creationScope != photoLogCreationCommandContextKey(appState) { return }
            command.run(appState)
        }))
    })
}

@MainActor
private func photoLogCreationCommandContextKey(_ appState: AppState) -> String {
    guard appState.currentSession?.sessionKind == .inbox else { return "saved-Log" }
    return localCommandContextKey([String(appState.imagePresentationRevision), String(describing: appState.activePane),
        appState.selectedSidebarNodeID ?? "", appState.commandReviewContextFingerprint] + appState.selectedFolderNodeIDs.sorted())
}

@MainActor
func sessionWorkflowSurfaceContextKey(_ appState: AppState) -> String {
    localCommandContextKey([sessionWorkflowCommandContextKey(appState), photoLogCreationCommandContextKey(appState)])
}

struct SessionWorkflowCommandSurface<Content: View>: View {
    @ObservedObject var appState: AppState
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .sessionWorkflow,
            contextKey: sessionWorkflowSurfaceContextKey(appState), actions: sessionWorkflowCommandActions(appState), content: content)
    }
}
