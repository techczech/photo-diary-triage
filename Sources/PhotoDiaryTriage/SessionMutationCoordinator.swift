import Foundation
import OSLog

final class SessionMutationCoordinator {
    private let logger: Logger

    init(logger: Logger = AppLogger.sessionMutation) {
        self.logger = logger
    }

    func walkDetailsShouldExpand(for session: ImportSession?) -> Bool {
        guard let session else { return true }

        let metadata = session.walkMetadata
        let hasMetadata = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || metadata.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return !hasMetadata
    }

    func sessionByUpdatingWalkMetadata(
        _ session: ImportSession,
        title: String,
        location: String,
        notes: String
    ) -> ImportSession {
        var updatedSession = session
        updatedSession.walkMetadata.title = title
        updatedSession.walkMetadata.location = location
        updatedSession.walkMetadata.notes = notes
        return updatedSession
    }

    func sessionBySettingWalkLocation(
        _ session: ImportSession,
        location: String,
        latitude: Double?,
        longitude: Double?
    ) -> ImportSession {
        var updatedSession = session
        updatedSession.walkMetadata.location = location
        updatedSession.walkMetadata.latitude = latitude
        updatedSession.walkMetadata.longitude = longitude
        return updatedSession
    }

    func sessionBySettingImportRawCompanions(
        _ session: ImportSession,
        for itemID: UUID,
        enabled: Bool
    ) -> ImportSession {
        var updatedSession = session
        guard let index = updatedSession.mediaItems.firstIndex(where: { $0.id == itemID }) else {
            return updatedSession
        }
        guard !updatedSession.mediaItems[index].lifecycleState.isImportedOrBeyond else {
            return updatedSession
        }
        if enabled {
            do {
                updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .selectedForImport)
            } catch {
                logger.error("Failed to promote RAW-enabled item for \(updatedSession.mediaItems[index].sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            updatedSession.mediaItems[index].selectionState = .included
        }
        updatedSession.mediaItems[index].importRawCompanions = enabled
        return updatedSession
    }

    func sessionByMarkingBackupConfirmed(
        _ session: ImportSession,
        confirmedAt: Date = Date()
    ) -> ImportSession {
        var updatedSession = session
        updatedSession.walkMetadata.backupConfirmedAt = confirmedAt

        for index in updatedSession.mediaItems.indices where updatedSession.mediaItems[index].lifecycleState == .verified {
            do {
                updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .sourceCleanupPending)
            } catch {
                logger.error("Failed to mark cleanup pending for \(updatedSession.mediaItems[index].sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        return updatedSession
    }

    func sessionByUpdatingImportSelection(
        _ session: ImportSession,
        mediaIDs: Set<UUID>,
        selected: Bool
    ) -> ImportSession {
        sessionByUpdatingTriageState(session, mediaIDs: mediaIDs, selectionState: selected ? .included : .undecided)
    }

    func sessionByUpdatingTriageState(
        _ session: ImportSession,
        mediaIDs: Set<UUID>,
        selectionState: SelectionState
    ) -> ImportSession {
        var updatedSession = session

        for index in updatedSession.mediaItems.indices where mediaIDs.contains(updatedSession.mediaItems[index].id) {
            guard !updatedSession.mediaItems[index].lifecycleState.isImportedOrBeyond else {
                continue
            }
            do {
                let targetState: LifecycleState = selectionState.isIncluded ? .selectedForImport : .discovered
                updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: targetState)
            } catch {
                logger.error("Failed to update import selection for \(updatedSession.mediaItems[index].sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }

            updatedSession.mediaItems[index].selectionState = selectionState
            if selectionState.isIncluded == false {
                updatedSession.mediaItems[index].importRawCompanions = false
            }
        }

        return updatedSession
    }

    func sessionByTogglingRawCompanions(
        _ session: ImportSession,
        selectedIDs: Set<UUID>
    ) -> ImportSession {
        var updatedSession = session

        for index in updatedSession.mediaItems.indices
        where selectedIDs.contains(updatedSession.mediaItems[index].id)
            && !updatedSession.mediaItems[index].companionFiles.isEmpty
            && !updatedSession.mediaItems[index].lifecycleState.isImportedOrBeyond {
            let enabled = !updatedSession.mediaItems[index].importRawCompanions
            if enabled {
                do {
                    updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .selectedForImport)
                } catch {
                    logger.error("Failed to promote RAW-toggled item for \(updatedSession.mediaItems[index].sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
                updatedSession.mediaItems[index].selectionState = .included
            }
            updatedSession.mediaItems[index].importRawCompanions = enabled
        }

        return updatedSession
    }
}
