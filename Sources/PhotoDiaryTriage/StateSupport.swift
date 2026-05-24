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

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(current) / Double(total)))
    }

    static func expectedTotalEntries(for session: ImportSession) -> Int {
        let total = session.mediaItems
            .filter { $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond }
            .reduce(0) { count, item in
                count + 1 + (item.importRawCompanions ? item.companionFiles.count : 0)
            }
        return max(total, 0)
    }
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

struct SessionLoadResult: Sendable {
    let session: ImportSession
    let bursts: [BurstGroup]
    let clusters: [TimeCluster]
}

struct SessionOpenResult: Sendable {
    let session: ImportSession
    let bursts: [BurstGroup]
    let clusters: [TimeCluster]
}

struct PersistedSessionNormalizationResult {
    let records: [(ImportSession, [BurstGroup], [TimeCluster])]
    let legacyRecoveredSessionCount: Int
    let deduplicatedInboxCount: Int
}

struct PhotoLogSelectionCounts: Equatable, Sendable {
    let included: Int
    let candidate: Int
    let excluded: Int
    let undecided: Int

    var decidedCount: Int {
        included + candidate + excluded
    }
}

struct PhotoLogCollision: Equatable, Sendable {
    let relativePath: String
    let owningSessionID: UUID
    let owningTitle: String
}

struct PhotoLogCreationPlan: Equatable, Sendable {
    let scope: PhotoLogScopeDescriptor
    let mode: PhotoLogCreationMode
    let scopeMediaItemIDs: [UUID]
    let candidateMediaItemIDs: [UUID]
    let counts: PhotoLogSelectionCounts
    let collisions: [PhotoLogCollision]
    let disabledReason: String?

    var candidateCount: Int {
        candidateMediaItemIDs.count
    }

    var canCreate: Bool {
        disabledReason == nil && candidateMediaItemIDs.isEmpty == false && collisions.isEmpty
    }
}

struct PhotoLogCreationResolver {
    func resolve(
        currentSession: ImportSession?,
        activePane: ActivePane,
        selectedFolderNodeIDs: Set<String>,
        selectedBrowserNode: BrowserNode?,
        browserNodeMap: [String: BrowserNode],
        visibleItems: [MediaItem],
        selectedMediaItemIDs: Set<UUID>,
        existingPhotoLogs: [ImportSession],
        mode: PhotoLogCreationMode
    ) -> PhotoLogCreationPlan? {
        guard let currentSession else { return nil }
        guard currentSession.sessionKind == .inbox else { return nil }

        let scopeResolution = resolveScope(
            currentSession: currentSession,
            activePane: activePane,
            selectedFolderNodeIDs: selectedFolderNodeIDs,
            selectedBrowserNode: selectedBrowserNode,
            browserNodeMap: browserNodeMap,
            visibleItems: visibleItems
        )

        let counts = selectionCounts(for: scopeResolution.items)
        let availableItems = scopeResolution.items.filter { !$0.lifecycleState.isImportedOrBeyond }
        let copiedItemCount = scopeResolution.items.count - availableItems.count
        let candidateItems: [MediaItem]
        let disabledReason: String?

        switch mode {
        case .decidedInScope:
            candidateItems = availableItems.filter { !$0.selectionState.isUndecided }
            if let scopeReason = scopeResolution.disabledReason {
                disabledReason = scopeReason
            } else if candidateItems.isEmpty, copiedItemCount > 0 {
                disabledReason = "Marked photos in this scope are already copied on disk. Choose uncopied source photos before creating a photo log."
            } else if candidateItems.isEmpty {
                disabledReason = "Mark included, candidate, or excluded photos in this scope before creating a photo log."
            } else {
                disabledReason = nil
            }
        case .selectedOnly:
            candidateItems = availableItems.filter { selectedMediaItemIDs.contains($0.id) }
            if let scopeReason = scopeResolution.disabledReason {
                disabledReason = scopeReason
            } else if candidateItems.isEmpty, copiedItemCount > 0 {
                disabledReason = "Selected photos in this scope are already copied on disk. Select uncopied source photos before creating a photo log."
            } else if candidateItems.isEmpty {
                disabledReason = "Select one or more photos in this scope before creating a photo log."
            } else {
                disabledReason = nil
            }
        }

        let workspacePath = currentSession.workspaceSourceFolder.standardizedFileURL.path
        var ownerByRelativePath: [String: (id: UUID, title: String)] = [:]
        for log in existingPhotoLogs where log.workspaceSourceFolder.standardizedFileURL.path == workspacePath {
            let owner = (id: log.id, title: log.walkMetadata.title.nonEmpty ?? "Untitled Photo Log")
            for item in log.mediaItems where ownerByRelativePath[item.relativePath] == nil {
                ownerByRelativePath[item.relativePath] = owner
            }
        }

        let collisions = candidateItems.compactMap { item in
            ownerByRelativePath[item.relativePath].map { owner in
                PhotoLogCollision(relativePath: item.relativePath, owningSessionID: owner.id, owningTitle: owner.title)
            }
        }

        return PhotoLogCreationPlan(
            scope: scopeResolution.scope,
            mode: mode,
            scopeMediaItemIDs: scopeResolution.items.map(\.id),
            candidateMediaItemIDs: candidateItems.map(\.id),
            counts: counts,
            collisions: collisions,
            disabledReason: collisions.isEmpty ? disabledReason : "Some photos in this plan already belong to another photo log."
        )
    }

    private func resolveScope(
        currentSession: ImportSession,
        activePane: ActivePane,
        selectedFolderNodeIDs: Set<String>,
        selectedBrowserNode: BrowserNode?,
        browserNodeMap: [String: BrowserNode],
        visibleItems: [MediaItem]
    ) -> (scope: PhotoLogScopeDescriptor, items: [MediaItem], disabledReason: String?) {
        let defaultDateRange = capturedDateRange(for: visibleItems)
        let defaultScope = PhotoLogScopeDescriptor(
            kind: .folder,
            label: currentSession.workspaceSourceFolder.lastPathComponent,
            sourceFolderPaths: [currentSession.workspaceSourceFolder.path],
            startDate: defaultDateRange.start,
            endDate: defaultDateRange.end
        )

        let items: [MediaItem]
        let scope: PhotoLogScopeDescriptor
        let disabledReason: String?

        if activePane == .folders,
           selectedFolderNodeIDs.count == 1,
           let folderNodeID = selectedFolderNodeIDs.first,
           let folderNode = browserNodeMap[folderNodeID] {
            let mediaByID = Dictionary(uniqueKeysWithValues: currentSession.mediaItems.map { ($0.id, $0) })
            items = folderNode.mediaItemIDs.compactMap { mediaByID[$0] }
            let dateRange = capturedDateRange(for: items)
            scope = PhotoLogScopeDescriptor(
                kind: .folder,
                label: folderNode.title,
                sourceFolderPaths: [currentSession.workspaceSourceFolder.path],
                startDate: dateRange.start,
                endDate: dateRange.end
            )
            disabledReason = items.isEmpty ? "The selected folder does not contain any visible photos." : nil
        } else if activePane == .media, visibleItems.isEmpty == false {
            let label = selectedBrowserNode.map { node in
                if let subtitle = node.subtitle?.nonEmpty {
                    return "\(node.title) • \(subtitle)"
                }
                return node.title
            } ?? currentSession.workspaceSourceFolder.lastPathComponent
            items = visibleItems
            let dateRange = capturedDateRange(for: items)
            scope = PhotoLogScopeDescriptor(
                kind: .dateRange,
                label: label,
                sourceFolderPaths: [currentSession.workspaceSourceFolder.path],
                startDate: dateRange.start,
                endDate: dateRange.end
            )
            disabledReason = nil
        } else {
            items = []
            scope = defaultScope
            disabledReason = "Select one folder or focus the review grid before creating a photo log."
        }

        return (scope, items, disabledReason)
    }

    private func capturedDateRange(for items: [MediaItem]) -> (start: Date?, end: Date?) {
        var start: Date?
        var end: Date?

        for item in items {
            guard let capturedAt = item.capturedAt else { continue }
            if start.map({ capturedAt < $0 }) ?? true {
                start = capturedAt
            }
            if end.map({ capturedAt > $0 }) ?? true {
                end = capturedAt
            }
        }

        return (start, end)
    }

    private func selectionCounts(for items: [MediaItem]) -> PhotoLogSelectionCounts {
        items.reduce(into: PhotoLogSelectionCounts(included: 0, candidate: 0, excluded: 0, undecided: 0)) { counts, item in
            switch item.selectionState {
            case .included:
                counts = PhotoLogSelectionCounts(
                    included: counts.included + 1,
                    candidate: counts.candidate,
                    excluded: counts.excluded,
                    undecided: counts.undecided
                )
            case .candidate:
                counts = PhotoLogSelectionCounts(
                    included: counts.included,
                    candidate: counts.candidate + 1,
                    excluded: counts.excluded,
                    undecided: counts.undecided
                )
            case .excluded:
                counts = PhotoLogSelectionCounts(
                    included: counts.included,
                    candidate: counts.candidate,
                    excluded: counts.excluded + 1,
                    undecided: counts.undecided
                )
            case .undecided:
                counts = PhotoLogSelectionCounts(
                    included: counts.included,
                    candidate: counts.candidate,
                    excluded: counts.excluded,
                    undecided: counts.undecided + 1
                )
            }
        }
    }
}

struct PersistedSessionNormalizer {
    func normalize(
        _ records: [(ImportSession, [BurstGroup], [TimeCluster])]
    ) -> PersistedSessionNormalizationResult {
        let sortedRecords = records.sorted { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }
        let legacyRecoveredSessionCount = sortedRecords.filter { !$0.0.sessionKindWasExplicit }.count
        var seenInboxWorkspacePaths: Set<String> = []
        var deduplicatedInboxCount = 0
        var normalizedRecords: [(ImportSession, [BurstGroup], [TimeCluster])] = []

        for record in sortedRecords {
            if record.0.sessionKind == .inbox {
                let workspacePath = record.0.workspaceSourceFolder.standardizedFileURL.path
                guard seenInboxWorkspacePaths.insert(workspacePath).inserted else {
                    deduplicatedInboxCount += 1
                    continue
                }
            }

            normalizedRecords.append(record)
        }

        return PersistedSessionNormalizationResult(
            records: normalizedRecords,
            legacyRecoveredSessionCount: legacyRecoveredSessionCount,
            deduplicatedInboxCount: deduplicatedInboxCount
        )
    }
}

struct SourceWorkspaceFolderResolver {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolve(selectedFolder: URL) -> URL {
        let standardizedFolder = selectedFolder.standardizedFileURL
        guard standardizedFolder.lastPathComponent.localizedCaseInsensitiveCompare("DCIM") != .orderedSame else {
            return standardizedFolder
        }

        let dcimFolder = standardizedFolder.appendingPathComponent("DCIM", isDirectory: true).standardizedFileURL
        if fileManager.fileExists(atPath: dcimFolder.path) {
            return dcimFolder
        }

        return standardizedFolder
    }
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

        var session = ImportSession(
            sourceFolder: folder,
            workspaceSourceFolder: folder,
            archiveRoot: settings.archiveRoot,
            oneDrivePicturesRoot: settings.oneDrivePicturesRoot,
            archiveMachineRole: settings.archiveMachineRole,
            sessionKind: .inbox
        )
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
        importProgress = ImportProgress(current: 0, total: ImportProgress.expectedTotalEntries(for: session))
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
