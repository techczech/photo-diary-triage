import Foundation
import OSLog

protocol SessionPersisting: AnyObject {
    func save(session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) throws
    func loadSessions() throws -> [(ImportSession, [BurstGroup], [TimeCluster])]
    func replaceAllSessions(with sessions: [(ImportSession, [BurstGroup], [TimeCluster])]) throws
}

protocol PreviewCaching: AnyObject {
    var isPersistentCacheAvailable: Bool { get }
    func cachedThumbnailURL(for item: MediaItem) -> URL
    func generateThumbnail(for item: MediaItem) async -> Bool
}

protocol SettingsPersisting: AnyObject {
    func load(defaults: @autoclosure () -> AppSettings) -> AppSettings
    func save(_ settings: AppSettings) throws
}

protocol ImportCoordinating {
    func commit(
        session: ImportSession,
        progress: (@Sendable (ImportProgress) async -> Void)?
    ) async throws -> ImportResult
    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession
}

struct ImportProgress: Equatable, Sendable {
    let current: Int
    let total: Int
}

struct AppStartupAlert: Identifiable, Equatable {
    enum RecoveryAction: Equatable {
        case resetSupportData
    }

    let id = UUID()
    let title: String
    let message: String
    let recoveryAction: RecoveryAction?
}

struct SessionLoadResult {
    let session: ImportSession
    let bursts: [BurstGroup]
    let clusters: [TimeCluster]
}

struct SessionOpenResult {
    let session: ImportSession
    let bursts: [BurstGroup]
    let clusters: [TimeCluster]
}

final class InMemorySessionStore: SessionPersisting {
    private var sessions: [(ImportSession, [BurstGroup], [TimeCluster])] = []

    func save(session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) throws {
        sessions.removeAll { $0.0.id == session.id }
        sessions.append((session, bursts, clusters))
        sessions.sort { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }
    }

    func loadSessions() throws -> [(ImportSession, [BurstGroup], [TimeCluster])] {
        sessions
    }

    func replaceAllSessions(with sessions: [(ImportSession, [BurstGroup], [TimeCluster])]) throws {
        self.sessions = sessions.sorted { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }
    }
}

final class NoCachePreviewStore: PreviewCaching {
    private let cacheRoot: URL

    init(cacheRoot: URL) {
        self.cacheRoot = cacheRoot
    }

    var isPersistentCacheAvailable: Bool { false }

    func cachedThumbnailURL(for item: MediaItem) -> URL {
        cacheRoot.appendingPathComponent("\(item.thumbnailCacheKey).png")
    }

    func generateThumbnail(for item: MediaItem) async -> Bool {
        false
    }
}

struct AppLogger {
    static let appState = Logger(subsystem: "PhotoDiaryTriage", category: "AppState")
    static let sessionLifecycle = Logger(subsystem: "PhotoDiaryTriage", category: "SessionLifecycle")
    static let sessionMutation = Logger(subsystem: "PhotoDiaryTriage", category: "SessionMutation")
    static let sessionManager = Logger(subsystem: "PhotoDiaryTriage", category: "SessionManager")
    static let importWorkflow = Logger(subsystem: "PhotoDiaryTriage", category: "ImportWorkflow")
    static let sessionStore = Logger(subsystem: "PhotoDiaryTriage", category: "SessionStore")
    static let previewStore = Logger(subsystem: "PhotoDiaryTriage", category: "PreviewStore")
    static let settingsStore = Logger(subsystem: "PhotoDiaryTriage", category: "SettingsStore")
    static let metadataExtractor = Logger(subsystem: "PhotoDiaryTriage", category: "MetadataExtractor")
    static let importCoordinator = Logger(subsystem: "PhotoDiaryTriage", category: "ImportCoordinator")
}

final class SessionManager {
    private let scanner: FileScanner
    private let groupingService: GroupingService
    private let logger: Logger

    init(
        scanner: FileScanner,
        groupingService: GroupingService,
        logger: Logger = AppLogger.sessionManager
    ) {
        self.scanner = scanner
        self.groupingService = groupingService
        self.logger = logger
    }

    func openSession(for folder: URL, settings: AppSettings) throws -> SessionOpenResult {
        let scannedItems = try scanner.scanFolder(folder, settings: settings)
        let grouped = groupingService.group(items: scannedItems, settings: settings)

        var session = ImportSession(sourceFolder: folder, archiveRoot: settings.archiveRoot)
        session.mediaItems = grouped.items
        logger.log("Opened session for \(folder.path, privacy: .public) with \(grouped.items.count) items")

        return SessionOpenResult(session: session, bursts: grouped.burstGroups, clusters: grouped.timeClusters)
    }

    func loadMostRecentSession(from store: SessionPersisting) throws -> SessionLoadResult? {
        guard let latest = try store.loadSessions().first else { return nil }
        return SessionLoadResult(session: latest.0, bursts: latest.1, clusters: latest.2)
    }

    func save(
        _ session: ImportSession,
        bursts: [BurstGroup],
        clusters: [TimeCluster],
        to store: SessionPersisting
    ) throws {
        try store.save(session: session, bursts: bursts, clusters: clusters)
    }
}

@MainActor
final class ImportWorkflow: ObservableObject {
    @Published private(set) var importProgress: ImportProgress?

    private let coordinator: ImportCoordinating
    private let logger: Logger

    init(coordinator: ImportCoordinating, logger: Logger = AppLogger.importWorkflow) {
        self.coordinator = coordinator
        self.logger = logger
    }

    func commit(
        session: ImportSession,
        progressHandler: (@MainActor (ImportProgress?) -> Void)? = nil
    ) async throws -> ImportResult {
        importProgress = ImportProgress(current: 0, total: session.mediaItems.filter { $0.selectionState.isIncluded }.count)
        progressHandler?(importProgress)
        defer {
            importProgress = nil
            progressHandler?(nil)
        }

        do {
            let result = try await coordinator.commit(session: session) { progress in
                await MainActor.run {
                    self.importProgress = progress
                    progressHandler?(progress)
                }
            }
            return result
        } catch {
            logger.error("Import commit failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession {
        do {
            return try await coordinator.cleanupImportedSources(in: session)
        } catch {
            logger.error("Source cleanup failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

struct ReviewSelectionState {
    var selectedMediaItemIDs: Set<UUID>
    var focusedReviewItemID: UUID?
    var reviewSelectionAnchorID: UUID?
    var activePane: ActivePane
    var reviewGridHasFocus: Bool
}

final class SelectionManager {
    func selectMediaItems(_ itemIDs: Set<UUID>, state: inout ReviewSelectionState) {
        state.selectedMediaItemIDs = itemIDs
        state.activePane = .media
        state.reviewSelectionAnchorID = itemIDs.first
        if let first = itemIDs.first {
            state.focusedReviewItemID = first
        }
    }

    func activateReviewGridFocus(visibleItems: [MediaItem], state: inout ReviewSelectionState) {
        state.activePane = .media
        state.reviewGridHasFocus = true
        if state.focusedReviewItemID == nil {
            state.focusedReviewItemID = state.selectedMediaItemIDs.first ?? visibleItems.first?.id
        }
    }

    func handleGridSelection(
        for itemID: UUID,
        visibleItems: [MediaItem],
        isShiftPressed: Bool,
        isCommandPressed: Bool,
        state: inout ReviewSelectionState
    ) {
        state.activePane = .media
        state.reviewGridHasFocus = true
        state.focusedReviewItemID = itemID

        if isShiftPressed {
            extendSelection(to: itemID, visibleItems: visibleItems, state: &state)
            return
        }

        if isCommandPressed {
            if state.selectedMediaItemIDs.contains(itemID) {
                state.selectedMediaItemIDs.remove(itemID)
            } else {
                state.selectedMediaItemIDs.insert(itemID)
            }
            state.reviewSelectionAnchorID = itemID
            return
        }

        state.selectedMediaItemIDs = [itemID]
        state.reviewSelectionAnchorID = itemID
    }

    func moveSelection(
        by offset: Int,
        visibleItems: [MediaItem],
        extending: Bool,
        state: inout ReviewSelectionState
    ) {
        guard !visibleItems.isEmpty else { return }
        let currentID = state.focusedReviewItemID ?? state.selectedMediaItemIDs.first ?? state.reviewSelectionAnchorID ?? visibleItems.first?.id
        guard let currentID,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == currentID }) else { return }
        let targetIndex = min(max(currentIndex + offset, 0), visibleItems.count - 1)
        let targetID = visibleItems[targetIndex].id

        if extending {
            if state.reviewSelectionAnchorID == nil {
                state.reviewSelectionAnchorID = currentID
            }
            extendSelection(to: targetID, visibleItems: visibleItems, state: &state)
        } else {
            state.selectedMediaItemIDs = [targetID]
            state.reviewSelectionAnchorID = targetID
        }

        state.focusedReviewItemID = targetID
    }

    func selectAllVisibleMedia(_ visibleItems: [MediaItem], state: inout ReviewSelectionState) {
        state.selectedMediaItemIDs = Set(visibleItems.map(\.id))
        state.reviewSelectionAnchorID = visibleItems.first?.id
        state.focusedReviewItemID = state.focusedReviewItemID ?? visibleItems.first?.id
        state.activePane = .media
        state.reviewGridHasFocus = true
    }

    func deselectAllVisibleMedia(_ visibleItems: [MediaItem], state: inout ReviewSelectionState) {
        state.selectedMediaItemIDs.removeAll()
        state.reviewSelectionAnchorID = nil
        state.focusedReviewItemID = state.focusedReviewItemID ?? visibleItems.first?.id
    }

    func toggleFocusedReviewItemSelection(_ visibleItems: [MediaItem], state: inout ReviewSelectionState) {
        guard let focusedID = state.focusedReviewItemID ?? visibleItems.first?.id else { return }
        state.activePane = .media
        state.reviewGridHasFocus = true

        if state.selectedMediaItemIDs.contains(focusedID) {
            state.selectedMediaItemIDs.remove(focusedID)
        } else {
            state.selectedMediaItemIDs.insert(focusedID)
        }

        state.reviewSelectionAnchorID = focusedID
        state.focusedReviewItemID = focusedID
    }

    func selectFocusedReviewItemOnly(_ visibleItems: [MediaItem], state: inout ReviewSelectionState) {
        guard let focusedID = state.focusedReviewItemID ?? visibleItems.first?.id else { return }
        state.selectedMediaItemIDs = [focusedID]
        state.reviewSelectionAnchorID = focusedID
        state.focusedReviewItemID = focusedID
        state.activePane = .media
        state.reviewGridHasFocus = true
    }

    private func extendSelection(to targetID: UUID, visibleItems: [MediaItem], state: inout ReviewSelectionState) {
        guard !visibleItems.isEmpty else { return }
        let anchorID = state.reviewSelectionAnchorID ?? state.selectedMediaItemIDs.first ?? targetID
        guard let anchorIndex = visibleItems.firstIndex(where: { $0.id == anchorID }),
              let targetIndex = visibleItems.firstIndex(where: { $0.id == targetID }) else {
            state.selectedMediaItemIDs = [targetID]
            state.reviewSelectionAnchorID = targetID
            return
        }

        let lower = min(anchorIndex, targetIndex)
        let upper = max(anchorIndex, targetIndex)
        state.selectedMediaItemIDs = Set(visibleItems[lower...upper].map(\.id))
        state.reviewSelectionAnchorID = anchorID
    }
}
