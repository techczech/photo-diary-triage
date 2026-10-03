import Foundation

/// Durable work may finish for the captured photo; presentation changes additionally
/// require the exact uninterrupted viewing lifetime, including close/reopen round trips.
struct ImageOperationContext {
    let authority: String, revision: Int
    let sessionID: UUID?, preview: UUID?, compare: [UUID]
    @MainActor init(_ state: AppState) {
        authority = state.commandDescriptionContextKey; revision = state.imagePresentationRevision
        sessionID = state.currentSession?.id; preview = state.previewingMediaItemID; compare = state.comparingMediaItemIDs
    }
    @MainActor func hasCurrentAuthority(_ state: AppState) -> Bool {
        authority == state.commandDescriptionContextKey
    }
    @MainActor func hasCurrentPresentation(_ state: AppState) -> Bool {
        hasCurrentAuthority(state) && revision == state.imagePresentationRevision
    }
}
