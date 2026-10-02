import AppKit
import Foundation

enum ReviewKeyboardTarget {
    case items
    case sections
}

private enum CurrentSessionUpdateKind {
    case full
    case sessionOnly
}

private enum CopyPreparationError: LocalizedError {
    case cannotCreateAutomaticLog(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreateAutomaticLog(let message):
            return message
        }
    }
}

private struct CompareSelectionBackup {
    let selectionState: ReviewSelectionState
    let keyboardTarget: ReviewKeyboardTarget
}

struct ArchiveThumbnailPreparationProgress: Equatable {
    var scopeTitle: String
    var completed: Int
    var total: Int

    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            if oldValue.archiveBrowseViewMode != settings.archiveBrowseViewMode { archiveGridNavigator.reset() }
            if oldValue.archiveRoot != settings.archiveRoot || oldValue.archiveMachineRole != settings.archiveMachineRole || oldValue.oneDrivePicturesRoot != settings.oneDrivePicturesRoot {
                invalidateArchiveContext()
                ArchiveByteReadPolicyContext.shared.update(settings: settings)
                originalViewingTasks.values.forEach { $0.cancel() }
                originalViewingTasks.removeAll()
                originalViewingOperationIDs.removeAll()
                originalViewingRevision &+= 1
            }
            refreshSidebarState()
            refreshArchiveBrowserState()
            refreshReviewState()
            refreshInspectorState()
        }
    }
    @Published var currentSession: ImportSession? {
        didSet {
            if oldValue?.id != currentSession?.id { reviewSearchQuery = "" }
            let updateKind = currentSessionUpdateKind
            currentSessionUpdateKind = .full
            rebuildSessionCaches(clearThumbnailCache: updateKind == .full)
            if updateKind == .full {
                rebuildBrowserCaches()
            }
            invalidateReviewContentCaches()
            refreshAllUIState()
        }
    }
    @Published var sourceWorkspaceState: SourceWorkspaceState = .idle {
        didSet {
            guard sourceWorkspaceState != oldValue else { return }
            rebuildBrowserCaches()
            refreshSidebarState()
        }
    }
    @Published private(set) var workspaceMode: WorkspaceMode = .archiveView
    @Published var burstGroups: [BurstGroup] = [] {
        didSet {
            rebuildBrowserCaches()
            refreshAllUIState()
        }
    }
    @Published var timeClusters: [TimeCluster] = [] {
        didSet {
            rebuildBrowserCaches()
            refreshAllUIState()
        }
    }
    @Published var selectedSidebarNodeID: String? {
        didSet {
            if oldValue != selectedSidebarNodeID { reviewSearchQuery = "" }
            invalidateInlineSectionCaches()
            refreshSidebarState()
            refreshReviewState()
            refreshInspectorState()
            refreshNavigationState()
        }
    }
    @Published var selectedFolderNodeIDs: Set<String> = [] {
        didSet {
            refreshInspectorState()
            refreshNavigationState()
        }
    }
    @Published var isSavingLocation = false
    @Published var archiveLocationRecoveryWalkPath: String?
    @Published var selectedMediaItemIDs: Set<UUID> = [] {
        didSet {
            refreshReviewState()
            refreshInspectorState()
            refreshCompareState()
        }
    }
    @Published var focusedReviewItemID: UUID? {
        didSet {
            refreshReviewState()
            refreshInspectorState()
            refreshCompareState()
        }
    }
    @Published var reviewSelectionAnchorID: UUID?
    @Published var activePane: ActivePane = .sidebar {
        didSet {
            refreshNavigationState()
        }
    }
    @Published var archiveYearFolders: [String] = [] {
        didSet {
            refreshSidebarState()
        }
    }
    @Published private(set) var commandShortcutSaveError: String?
    let archiveSidebarNavigation = ArchiveSidebarNavigation()
    lazy var commandCoordinator = CommandKeyboardCoordinator(appState: self)
    var isBrowsingArchivePhotos: Bool { if case .photos = archiveNavigationLevel { return true }; return false }
    var commandReviewContextFingerprint: String {
        [String(reviewContentCacheGeneration), String(inlineSectionCacheGeneration), String(describing: reviewFilter), String(describing: dayOrganizationMode),
         String(describing: dayDetailDisplayMode), String(describing: settings.reviewPresentationMode), String(settings.reviewGridColumnCount)].joined(separator: "\0")
    }
    var commandArchiveSelectionFingerprint: String {
        [String(describing: workspaceMode), String(describing: archiveNavigationLevel), String(describing: settings.archiveBrowseViewMode), String(describing: archiveSort), String(describing: archiveKindFilter), archiveYearFilter ?? "", archiveSearchQuery,
         selectedArchiveEntryID ?? "", selectedArchiveWalkID ?? "", selectedArchiveSearchResultID ?? "", activePhotoLogEditor?.id.uuidString ?? "", activeWalkCommitEditor?.id.uuidString ?? ""].joined(separator: "\0")
    }

    @discardableResult
    func setCommandShortcut(_ id: AppCommandID, override: AppShortcutOverride?) -> Bool {
        guard settings.commandShortcutSchemaVersion == 1 else {
            commandShortcutSaveError = "These shortcuts were saved by a newer app. Update Walkfolio before changing them."
            return false
        }
        let registry = AppCommandRegistry(overrides: settings.commandShortcutOverrides)
        let reason = override.map { registry.validate($0, for: id) } ?? registry.validateDefault(for: id)
        if let reason { commandShortcutSaveError = reason; return false }
        var changed = settings; changed.commandShortcutOverrides[id.rawValue] = override
        // Publish only after the durable write; a failed save must not change dispatch.
        do {
            try settingsStore.save(changed)
            settings = changed; commandShortcutSaveError = nil; commandCoordinator.objectWillChange.send(); return true
        } catch {
            commandShortcutSaveError = "Shortcut save failed: " + error.localizedDescription
            statusMessage = commandShortcutSaveError!; return false
        }
    }

    @Published var showKeyboardHelp = false {
        didSet {
            refreshPresentationState()
        }
    }
    @Published var reviewGridHasFocus = false {
        didSet {
            refreshNavigationState()
        }
    }
    @Published var isDetailsInspectorVisible = true {
        didSet {
            refreshInspectorState()
        }
    }
    @Published var isWalkDetailsExpanded = true {
        didSet {
            refreshSidebarState()
        }
    }
    @Published var isSidebarVisible = true {
        didSet {
            guard isSidebarVisible != oldValue else { return }
            handleSidebarVisibilityChanged()
        }
    }
    @Published var reviewSearchQuery = "" {
        didSet {
            guard reviewSearchQuery != oldValue else { return }
            invalidateReviewContentCaches(); invalidateInlineSectionCaches()
            reconcileReviewSelectionWithVisibleItems()
            refreshReviewState(); refreshNavigationState(); refreshInspectorState(); refreshCompareState()
        }
    }
    @Published var reviewFilter: ReviewFilter = .all {
        didSet {
            guard reviewFilter != oldValue else { return }
            invalidateReviewContentCaches()
            invalidateInlineSectionCaches()
            if dayDetailDisplayMode == .sections {
                ensureFocusedInlineSection()
            }
            reconcileReviewSelectionWithVisibleItems()
            refreshReviewState()
            refreshSidebarState()
            refreshInspectorState()
            refreshCompareState()
        }
    }
    @Published var dayOrganizationMode: DayOrganizationMode = .days {
        didSet {
            invalidateOrganizedInlineSectionCache()
            refreshReviewState()
            refreshNavigationState()
        }
    }
    @Published var dayDetailDisplayMode: DayDetailDisplayMode = .review {
        didSet {
            refreshReviewState()
            refreshNavigationState()
        }
    }
    @Published var expandedInlineSectionIDs: Set<String> = [] {
        didSet {
            refreshReviewState()
        }
    }
    @Published var pendingInlineScrollTargetID: UUID? {
        didSet {
            refreshNavigationState()
        }
    }
    @Published var pendingReviewScrollTargetID: UUID? {
        didSet {
            refreshNavigationState()
        }
    }
    @Published var focusedInlineSectionID: String? {
        didSet {
            refreshReviewState()
            refreshNavigationState()
        }
    }
    @Published var pendingInlineSectionScrollTargetID: String? {
        didSet {
            refreshNavigationState()
        }
    }
    @Published var pendingInlineSectionScrollRevision: Int = 0 {
        didSet {
            refreshNavigationState()
        }
    }
    @Published var drilledInlineSectionID: String? {
        didSet {
            invalidateReviewContentCaches()
            refreshReviewState()
        }
    }
    @Published var drilledInlineSectionMediaItemIDs: [UUID] = [] {
        didSet {
            invalidateReviewContentCaches()
            refreshReviewState()
        }
    }
    @Published var previewingMediaItemID: UUID? {
        didSet {
            refreshPresentationState()
        }
    }
    @Published var activePhotoLogEditor: PhotoLogEditorState? {
        didSet {
            refreshPresentationState()
        }
    }
    @Published var activeWalkCommitEditor: WalkCommitEditorState? {
        didSet {
            refreshPresentationState()
        }
    }
    @Published var revealedPhotoLog: PhotoLogRevealState? {
        didSet {
            refreshPresentationState()
        }
    }
    @Published var comparingMediaItemIDs: [UUID] = [] {
        didSet {
            refreshCompareState()
        }
    }
    @Published var compareSheetTitle: String = "Compare Selection" {
        didSet {
            refreshCompareState()
        }
    }
    @Published var compareGridColumnCount: Int = CompareGridMetrics.defaultColumnCount(for: 0) {
        didSet {
            refreshCompareState()
        }
    }
    @Published var reviewGridColumnCount: Int = 1 {
        didSet {
            refreshReviewState()
        }
    }
    @Published var statusMessage: String = "Choose a source folder on the SSD to begin." {
        didSet {
            refreshSidebarState()
        }
    }
    @Published var thumbnailFailures: Set<UUID> = [] {
        didSet {
            refreshReviewState()
            refreshCompareState()
        }
    }
    @Published var archiveMediaCache: [String: [MediaItem]] = [:] {
        didSet {
            invalidateReviewContentCaches()
            invalidateInlineSectionCaches()
            refreshReviewState()
        }
    }
    @Published private var cropOperationItemIDs: Set<UUID> = [] {
        didSet {
            refreshReviewState()
            refreshCompareState()
            refreshPresentationState()
        }
    }
    @Published var startupAlert: AppStartupAlert? {
        didSet {
            refreshPresentationState()
        }
    }
    @Published var importProgress: ImportProgress? {
        didSet {
            refreshSidebarState()
        }
    }
    @Published var importOperation: ImportOperationSnapshot = .idle {
        didSet {
            if oldValue.phase == importOperation.phase {
                refreshSidebarState()
            } else {
                refreshAllUIState()
            }
        }
    }
    @Published private(set) var originalViewingRevision = 0
    var testingOriginalViewingService: ArchiveOriginalViewingService?
    private var originalViewingTasks: [UUID: Task<Void, Never>] = [:]
    private var originalViewingOperationIDs: [UUID: UUID] = [:]

    @Published private(set) var archiveBackfillIsRunning = false
    @Published private(set) var archiveBackfillProgress: ArchiveThumbnailPreparationProgress?

    let sidebarState = SidebarState()
    let archiveBrowserState = ArchiveBrowserState()
    let reviewState = ReviewState()
    let reviewNavigationState = ReviewNavigationState()
    let inspectorState = InspectorState()
    let compareState = CompareState()
    let presentationState = PresentationState()

    private let scanner: FileScanner
    private let groupingService: GroupingService
    private let importCoordinator: ImportCoordinator
    private let sessionLifecycleCoordinator: SessionLifecycleCoordinator
    private let sessionMutationCoordinator: SessionMutationCoordinator
    private var sessionStore: SessionPersisting
    private var hasDurableSessionPersistence = true
    private var previewStore: PreviewCaching
    private let settingsStore: SettingsPersisting
    private var sessionManager: SessionManager
    private var importWorkflow: ImportWorkflow
    private var browserViewModel: BrowserViewModel
    private let selectionManager = SelectionManager()
    private let backupStore = BackupStore()
    private let backupPersistenceGate: BackupPersistenceGate
    let backupRestoreCoordinator: BackupRestoreCoordinator
    private let photoLogSyncStore = PhotoLogSyncStore()
    private let persistedSessionNormalizer = PersistedSessionNormalizer()
    private let photoLogCreationResolver = PhotoLogCreationResolver()
    private let workflowGuidanceResolver = WorkflowGuidanceResolver()
    private let archiveCopySurveyor = ArchiveCopySurveyor()
    private let walkBoundaryProposalService = WalkBoundaryProposalService()
    private let tripLibraryScanner = TripLibraryScanner()
    private let walkMover = WalkMover()
    private let fileManager: FileManager
    private let sourceWorkspaceFolderResolver: SourceWorkspaceFolderResolver
    private let supportRoot: URL
    private let logger = AppLogger.appState
    private let latencyRecorder = LatencyRecorder()
    private var compareSelectionBackup: CompareSelectionBackup?
    var testingArchiveCatalogueHandler: (@Sendable (URL, AppSettings) async throws -> (ArchiveCatalogue, [ArchiveIndexEntry]))?
    var testingArchiveSearchHandler: (@Sendable (ArchiveSearchDatabaseSnapshot, String) async throws -> Set<String>)?
    var testingArchiveLoadHandler: (@Sendable (BrowserNode, AppSettings) async throws -> ArchiveLoadResult?)?
    var testingPendingArchiveTasks: [Task<Void, Never>] {
        [archiveCatalogueLoadTask, archiveSearchTask, archiveMediaLoadTask].compactMap { $0 }
    }
    var testingSourceScanHandler: ((URL, AppSettings) async throws -> SessionOpenResult)?

    func testingInstallArchiveCatalogue(_ catalogue: ArchiveCatalogue) {
        archiveSearchDatabaseSnapshot = ArchiveSearchDatabaseSnapshot(borrowing: supportRoot.appendingPathComponent("archive-search.sqlite"), archiveRoot: settings.archiveRoot)
        archiveCatalogue = catalogue
        archiveCatalogueIsLoading = false
        archiveCatalogueError = nil
        reconcileArchiveSelection()
        refreshArchiveBrowserState()
    }
    private let sessionPersistenceQueue = DispatchQueue(label: "PhotoDiaryTriage.session-persistence", qos: .utility)
    private let thumbnailScheduler = ThumbnailScheduler()
    private let thumbnailImageCache = NSCache<NSURL, NSImage>()
    private let thumbnailRegistry = ThumbnailRegistry()
    private var thumbnailDecodeTasks: [String: Task<Void, Never>] = [:]
    private var cachedBrowserRoots: [BrowserNode] = []
    private var cachedBrowserNodeMap: [String: BrowserNode] = [:]
    private var sessionMediaByID: [UUID: MediaItem] = [:]
    private var sessionVisibleMediaCacheByNodeID: [String: [MediaItem]] = [:]
    private var archivePreviewByMediaItemID: [UUID: String] = [:]
    private var sourceArchiveCopiesByRelativePath: [String: SourceArchiveCopySnapshot] = [:]
    private var missingThumbnailPaths: Set<String> = []
    private var thumbnailTasks: [UUID: Task<Void, Never>] = [:]
    private var volumeMountObserver: NSObjectProtocol?
    private var hasAttemptedInitialAutoLoad = false
    private let startupSelectionPolicy: StartupSelectionPolicy = .sourceInboxFirst
    private var sourceLoadTask: Task<Void, Never>?
    private var sourceLoadGeneration: Int = 0
    private var pendingLegacyMigrationNoticeCount: Int = 0
    private var hasShownLegacyMigrationNotice = false
    private var lastMeasuredReviewPaneWidth: Double = 0
    private var lastMeasuredReviewPaneHeight: Double = 0
    private var reviewKeyboardTarget: ReviewKeyboardTarget = .items
    private var archiveMediaLoadTask: Task<Void, Never>?
    private var archiveMediaLoadGeneration: Int = 0
    private var archiveMediaCatalogueRevision = UUID()
    private var archiveMediaCacheRevisions: [String: UUID] = [:]
    private var archiveCatalogueLoadTask: Task<Void, Never>?
    private var archiveCatalogueLoadGeneration: Int = 0
    private var archiveSearchTask: Task<Void, Never>?
    private var archiveBackfillTask: Task<Void, Never>?
    private var archiveMaintenanceIsRunning = false
    private var archiveLocationPhotosByPath: [String: ArchivePhotoSummary] = [:]
    private var archiveLocationWalksByPath: [String: ArchiveWalkSummary] = [:]
    private var archiveCatalogue: ArchiveCatalogue = .empty {
        didSet {
            archiveMediaCatalogueRevision = archiveSearchDatabaseSnapshot?.id ?? UUID()
            invalidateArchiveBrowseContent()
            archiveLocationPhotosByPath = Dictionary(archiveCatalogue.photos.map { ($0.archiveRelativePath, $0) }, uniquingKeysWith: { first, _ in first })
            archiveLocationWalksByPath = Dictionary(archiveCatalogue.walksByTripPath.values.flatMap { $0 }.map { ($0.archiveRelativePath, $0) }, uniquingKeysWith: { first, _ in first })
        }
    }
    private var archiveCatalogueIsLoading = false
    private var archiveCatalogueError: String?
    private var archiveYearFilter: String? {
        didSet { if oldValue != archiveYearFilter { invalidateArchiveBrowseContent() } }
    }
    private var archiveKindFilter: ArchiveBrowseKindFilter = .all {
        didSet { if oldValue != archiveKindFilter { invalidateArchiveBrowseContent() } }
    }
    private var archiveSort: ArchiveBrowseSort = .newest {
        didSet { if oldValue != archiveSort { invalidateArchiveBrowseContent() } }
    }
    private var archiveSearchQuery = "" {
        didSet { if oldValue != archiveSearchQuery { invalidateArchiveBrowseContent() } }
    }
    private var archiveSearchMatchingPaths: Set<String> = [] {
        didSet { if oldValue != archiveSearchMatchingPaths { invalidateArchiveBrowseContent() } }
    }
    private var archiveBrowseContentCache: ArchiveBrowseContent?
    private(set) var archiveProjectionBuildCount = 0
    private var archiveGridNavigator = ArchiveGridNavigator()
    private var selectedArchiveMapItemID: ArchiveMapItemID?
    private var archiveBrowseFocusRevision = 0
    private var archiveSearchDatabaseSnapshot: ArchiveSearchDatabaseSnapshot?
    private var archiveSavedTripLocationOverlays: [String: SavedTripLocationLabel] = [:]
    private var archiveSearchRequestID = UUID()
    private var archiveSearchIsLoading = false
    private var archiveSearchError: String?
    private var selectedArchiveSearchTarget: ArchiveSearchItemID?
    private var archiveFolderLoadState: ArchiveFolderLoadState = .idle
    private var archiveRequestedSearchPhotoPath: String?
    private var archiveFolderSelectionToRestore: ArchiveFolderSelection?
    private var archiveSearchReturnPhotoID: String?
    private var archiveMissingSearchHitMessage: String?
    private var archiveSearchFocusRevision = 0
    private var archiveNavigationLevel: ArchiveNavigationLevel = .archive
    private var selectedArchiveEntryID: String?
    private var selectedArchiveWalkID: String?
    private var selectedArchiveSearchResultID: String?
    private var activeArchiveContentNode: BrowserNode?
    private var currentSessionUpdateKind: CurrentSessionUpdateKind = .full
    private struct PendingSessionPersistence {
        let owners: Set<UUID>
        let workItem: DispatchWorkItem
        let outcome: SessionPersistenceOutcome
    }
    private var pendingSessionPersistence: [PendingSessionPersistence] = []
    private var sourceCleanupIsRunning = false
    private var restoredStateGeneration = 0
    private var estimatedVisibleReviewIndexRange: ClosedRange<Int>?
    private var inlineSectionCacheGeneration: Int = 0
    private var cachedInlineDaySectionsGeneration: Int = -1
    private var cachedInlineDaySectionsNodeID: String?
    private var cachedInlineDaySections: [InlineDaySection] = []
    private var cachedOrganizedInlineSectionsGeneration: Int = -1
    private var cachedOrganizedInlineSectionsMode: DayOrganizationMode = .days
    private var cachedOrganizedInlineSections: [InlineSection] = []
    private var reviewContentCacheGeneration: Int = 0
    private var cachedContextMediaGeneration: Int = -1
    private var cachedContextMediaItems: [MediaItem] = []
    private var cachedVisibleMediaGeneration: Int = -1
    private var cachedVisibleMediaItems: [MediaItem] = []
    private var cachedReviewInteractionGeneration: Int = -1
    private var cachedReviewInteractionItems: [MediaItem] = []
    private var cachedGroupableInlineDaySectionsGeneration: Int = -1
    private var cachedGroupableInlineDaySectionsNodeID: String?
    private var cachedGroupableInlineDaySections: [InlineDaySection] = []
    private var persistedSessions: [(ImportSession, [BurstGroup], [TimeCluster])] = []
    private var persistedSessionsGeneration: Int = 0
    private var cachedSourceLogOwnershipWorkspacePath: String?
    private var cachedSourceLogOwnershipExcludedSessionID: UUID?
    private var cachedSourceLogOwnershipPersistedGeneration: Int = -1
    private var cachedSourceLogOwnershipByRelativePath: [String: SourceLogOwnershipSnapshot] = [:]
    private var activePhotoLogMembershipEditID: UUID?
    private var cachedGroupedReviewSectionsGeneration: Int = -1
    private var cachedGroupedReviewSectionsMode: DayOrganizationMode = .days
    private var cachedGroupedReviewSections: [GroupedReviewSection] = []
    private var refreshTransactionDepth = 0
    private var pendingRefreshes: PendingRefreshKinds = []

    private struct PendingRefreshKinds: OptionSet {
        let rawValue: Int
        static let sidebar = PendingRefreshKinds(rawValue: 1 << 0)
        static let review = PendingRefreshKinds(rawValue: 1 << 1)
        static let navigation = PendingRefreshKinds(rawValue: 1 << 2)
        static let inspector = PendingRefreshKinds(rawValue: 1 << 3)
        static let compare = PendingRefreshKinds(rawValue: 1 << 4)
        static let presentation = PendingRefreshKinds(rawValue: 1 << 5)
    }

    init(testing: Bool = false, testingSettings: AppSettings? = nil, testingSupportRoot: URL? = nil, testingImportCoordinator: (any ImportCoordinating)? = nil, testingSessionStore: (any SessionPersisting)? = nil, testingDescriptionClient: (any DescriptionGenerating)? = nil, testingGoogleCredentials: (any GooglePhotosCredentials)? = nil, testingGoogleClient: (any GooglePhotosDelivering)? = nil, testingGoogleSecrets: (any GooglePhotosSecretStoring)? = nil, testingSettingsStore: (any SettingsPersisting)? = nil) {
        self.fileManager = .default
        self.descriptionClient = testingDescriptionClient ?? LMStudioDescriptionClient()
        let googleSecrets = testingGoogleSecrets ?? GooglePhotosKeychain()
        let googleAuth = GooglePhotosAuthentication(secrets: googleSecrets)
        self.googleSecrets = googleSecrets; self.googleAuthentication = googleAuth
        self.googleCredentials = testingGoogleCredentials ?? googleAuth
        self.googleClient = testingGoogleClient ?? GooglePhotosClient(credentials: testingGoogleCredentials ?? googleAuth)
        thumbnailImageCache.countLimit = 512
        thumbnailImageCache.totalCostLimit = 256 * 1024 * 1024
        self.sourceWorkspaceFolderResolver = SourceWorkspaceFolderResolver(fileManager: self.fileManager)
        self.supportRoot = testingSupportRoot ?? AppPaths.supportRoot()
        let gate = BackupPersistenceGate()
        self.backupPersistenceGate = gate
        let restore = BackupRestoreCoordinator(supportRoot: self.supportRoot, gate: gate)
        self.backupRestoreCoordinator = restore
        let rawSettingsStore: SettingsPersisting = testingSettingsStore ?? SettingsStore(fileURL: self.supportRoot.appendingPathComponent("settings.json"))
        var recoveryFailure: Error?
        var recoveredSessionStore: SessionPersisting?
        let recovering = restore.hasRecoveryRecord
        if recovering {
            do {
                let recoverySessions = try testingSessionStore ?? SessionStore(databaseURL: self.supportRoot.appendingPathComponent("sessions.sqlite"))
                try restore.recover(sessions: recoverySessions, settings: rawSettingsStore)
                recoveredSessionStore = recoverySessions
            } catch { recoveryFailure = error; gate.block(error.localizedDescription) }
        }
        let settingsStore = BackupGuardedSettingsStore(rawSettingsStore, gate: gate)
        let settings = recovering ? rawSettingsStore.load(defaults: testingSettings ?? AppSettings.default()) : (testingSettings ?? settingsStore.load(defaults: AppSettings.default()))
        self.settings = settings
        ArchiveByteReadPolicyContext.shared.update(settings: settings)
        self.settingsStore = settingsStore
        self.scanner = FileScanner()
        self.groupingService = GroupingService()
        self.importCoordinator = ImportCoordinator()
        self.sessionLifecycleCoordinator = SessionLifecycleCoordinator(
            scanner: self.scanner,
            groupingService: self.groupingService,
            importCoordinator: self.importCoordinator,
            fileManager: self.fileManager,
            supportRoot: self.supportRoot
        )
        self.sessionMutationCoordinator = SessionMutationCoordinator()
        self.sessionStore = BackupGuardedSessionStore(testingSessionStore ?? InMemorySessionStore(), gate: gate)
        self.previewStore = NoCachePreviewStore(cacheRoot: settings.cacheRoot)
        self.sessionManager = SessionManager(scanner: self.scanner, groupingService: self.groupingService)
        self.importWorkflow = ImportWorkflow(coordinator: testingImportCoordinator ?? self.importCoordinator)
        self.browserViewModel = BrowserViewModel(scanner: self.scanner)
        self.archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
        rebuildBrowserCaches()
        refreshAllUIState()

        if testing {
            if let recoveryFailure { showBackupRecoveryFailure(recoveryFailure) }
            else if testingSessionStore != nil { primePersistedSessionCache() }
            return
        }

        configurePersistence(reusing: recoveredSessionStore)
        if let recoveryFailure { showBackupRecoveryFailure(recoveryFailure); return }
        primePersistedSessionCache()
        startVolumeMonitoring()
        reloadArchiveCatalogue()
        refreshAllUIState()
    }

    deinit {
        archiveMediaLoadTask?.cancel()
        archiveCatalogueLoadTask?.cancel()
        archiveSearchTask?.cancel()
        archiveBackfillTask?.cancel()
        originalViewingTasks.values.forEach { $0.cancel() }
        if let volumeMountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(volumeMountObserver)
        }
    }

    func performStartupRecovery() {
        if startupAlert?.recoveryAction == .retryBackupRecovery {
            do {
                let rawSessions = try SessionStore(databaseURL: supportRoot.appendingPathComponent("sessions.sqlite"))
                let rawSettings = (settingsStore as? BackupGuardedSettingsStore)?.base ?? settingsStore
                try backupRestoreCoordinator.recover(sessions: rawSessions, settings: rawSettings)
                let restoredSettings = try rawSettings.loadBackupSnapshot(defaults: settings)
                let restoredSessions = try rawSessions.loadBackupSnapshot()
                let restored = AppBackupDocument(exportedAt: Date(), settings: restoredSettings,
                    sessions: restoredSessions.map { .init(session: $0.0, bursts: $0.1, timeClusters: $0.2) })
                try restored.validate()
                configurePersistence(reusing: rawSessions)
                publishRestoredBackup(restored)
                if volumeMountObserver == nil { startVolumeMonitoring() }
                startupAlert = nil
                statusMessage = "Recovered app state. Saved sessions and settings are available again."
            } catch { showBackupRecoveryFailure(error) }
            return
        }
        guard backupPersistenceGate.blockedReason == nil else { return }
        guard startupAlert?.recoveryAction == .resetSupportData else {
            startupAlert = nil
            return
        }

        do {
            invalidateInFlightSourceLoad()
            try sessionLifecycleCoordinator.resetSupportData()
            settings = settingsStore.load(defaults: AppSettings.default())
            configurePersistence()
            archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
            browserViewModel.invalidateArchiveTreeCache()
            archiveMediaCache.removeAll()
            primePersistedSessionCache()
            hasAttemptedInitialAutoLoad = false
            performInitialAutoLoadIfNeeded()
            startupAlert = nil
            statusMessage = "Reset local app support data and restarted persistence."
        } catch {
            logger.error("Failed to reset support data: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Reset failed: \(error.localizedDescription)"
        }
    }

    func dismissStartupAlert() {
        startupAlert = nil
    }

    var browserRoots: [BrowserNode] {
        cachedBrowserRoots
    }

    var browserNodeMap: [String: BrowserNode] {
        guard let activeArchiveContentNode else { return cachedBrowserNodeMap }
        var map = cachedBrowserNodeMap
        map[activeArchiveContentNode.id] = activeArchiveContentNode
        return map
    }

    var selectedBrowserNode: BrowserNode? {
        if let activeArchiveContentNode,
           selectedSidebarNodeID == activeArchiveContentNode.id {
            return activeArchiveContentNode
        }
        guard let selectedSidebarNodeID else { return browserRoots.first }
        return browserNodeMap[selectedSidebarNodeID] ?? browserRoots.first
    }

    var workspaceModeDetail: String {
        switch workspaceMode {
        case .archiveView:
            return "Browse Trips and Unorganised Folders in the Archive."
        case .cameraTriage:
            if currentSession?.sessionKind == .walkDraft {
                return "Review the active photo log. S photos copy to archive; C/X stay recorded in this log."
            }
            if currentSession?.sessionKind == .inbox {
                return "Review the source inbox. S/C/X decisions stay here until you create or add to a photo log."
            }
            return "Review photos from the current camera or SSD source."
        case .photoLogs:
            return "Log library. Continue opens a log; Add Marked moves source-inbox decisions into a log."
        case .archiveTriage:
            return "Review archive walks separately from source cleanup."
        }
    }

    var workspaceContextTitle: String {
        if workspaceMode == .cameraTriage {
            switch currentSession?.sessionKind {
            case .inbox:
                return "Source Inbox Triage"
            case .walkDraft:
                return "Active Photo Log"
            case .none:
                break
            }
        }
        return workspaceMode.title
    }

    var workspaceContextSystemImage: String {
        if workspaceMode == .cameraTriage {
            switch currentSession?.sessionKind {
            case .inbox:
                return "tray.full"
            case .walkDraft:
                return "doc.text.magnifyingglass"
            case .none:
                break
            }
        }
        return workspaceMode.systemImage
    }

    var workspaceModeNextAction: String {
        switch workspaceMode {
        case .archiveView:
            switch archiveNavigationLevel {
            case .archive:
                return "Choose a Trip or Unorganised Folder. Years and entry types filter this Archive view."
            case .trip:
                return "Choose a Walk to browse its photos."
            case .photos:
                return "Viewing \(visibleMediaItems.count) archived photo(s). Return to Archive to change the year or view."
            }
        case .cameraTriage:
            guard let currentSession else {
                return "Open a source folder, then use S, C, and X to decide what belongs in a photo log."
            }
            if currentSession.sessionKind == .walkDraft {
                if canCommitImport {
                    return "You are inside a photo log. Copy To Archive copies the uncopied S photos in this log."
                }
                return "You are inside a photo log. Change S/C/X here, or use Start New Photo Log to return to the source inbox."
            }
            let counts = triageCounts(for: currentSession.mediaItems)
            return "Source inbox decisions: \(counts.included) selected, \(counts.candidate) candidate, \(counts.excluded) excluded. Create Photo Log starts a log; copied/on-disk photos are locked."
        case .photoLogs:
            return "Use Continue to open a log for review/copying, or Add Marked to append current source-inbox S/C/X decisions."
        case .archiveTriage:
            return "Archive triage is separated but read-only in this build; browse the archive without changing import states."
        }
    }

    var canOpenSelectedBrowserFolder: Bool {
        selectedBrowserFolderURL != nil
    }

    var breadcrumbTitles: [String] {
        guard let selectedBrowserNode else { return [] }
        var path: [String] = []
        var current: BrowserNode? = selectedBrowserNode

        while let node = current {
            path.append(node.title)
            current = node.parentID.flatMap { browserNodeMap[$0] }
        }

        return path.reversed()
    }

    var detailFolderNodes: [BrowserNode] {
        guard let node = selectedBrowserNode else { return [] }
        return node.children ?? []
    }

    var inspectorBrowserNode: BrowserNode? {
        if activePane == .folders, selectedFolderNodeIDs.count == 1, let nodeID = selectedFolderNodeIDs.first {
            return browserNodeMap[nodeID] ?? selectedBrowserNode
        }
        return selectedBrowserNode
    }

    var contextMediaItems: [MediaItem] {
        if cachedContextMediaGeneration == reviewContentCacheGeneration {
            return cachedContextMediaItems
        }

        let items: [MediaItem]
        if !drilledInlineSectionMediaItemIDs.isEmpty {
            items = orderedMediaItems(for: drilledInlineSectionMediaItemIDs)
        } else if let node = selectedBrowserNode {
            items = baseVisibleMediaItems(for: node)
        } else {
            items = []
        }

        cachedContextMediaGeneration = reviewContentCacheGeneration
        cachedContextMediaItems = items
        return items
    }

    var visibleMediaItems: [MediaItem] {
        if cachedVisibleMediaGeneration == reviewContentCacheGeneration {
            return cachedVisibleMediaItems
        }

        let items = filterReviewItems(contextMediaItems)
        cachedVisibleMediaGeneration = reviewContentCacheGeneration
        cachedVisibleMediaItems = items
        return items
    }

    var inlineDaySections: [InlineDaySection] {
        let nodeID = selectedBrowserNode?.id
        if cachedInlineDaySectionsGeneration == inlineSectionCacheGeneration,
           cachedInlineDaySectionsNodeID == nodeID {
            return cachedInlineDaySections
        }

        let sections = inlineSectionOrganizer.inlineDaySections(from: selectedBrowserNode, visibleItems: visibleMediaItems)
        cachedInlineDaySectionsGeneration = inlineSectionCacheGeneration
        cachedInlineDaySectionsNodeID = nodeID
        cachedInlineDaySections = sections
        return sections
    }

    var shouldShowInlineDaySections: Bool {
        !groupableInlineDaySections.isEmpty
    }

    var canUseGroupedReviewMode: Bool {
        shouldShowInlineDaySections
    }

    var availableDayDetailDisplayModes: [DayDetailDisplayMode] {
        canUseGroupedReviewMode ? DayDetailDisplayMode.allCases : [.review]
    }

    var organizedInlineSections: [InlineSection] {
        if cachedOrganizedInlineSectionsGeneration == inlineSectionCacheGeneration,
           cachedOrganizedInlineSectionsMode == dayOrganizationMode {
            return cachedOrganizedInlineSections
        }

        let sections = inlineSectionOrganizer.organizedInlineSections(from: inlineDaySections, mode: dayOrganizationMode)
        cachedOrganizedInlineSectionsGeneration = inlineSectionCacheGeneration
        cachedOrganizedInlineSectionsMode = dayOrganizationMode
        cachedOrganizedInlineSections = sections
        return sections
    }

    var groupedReviewSections: [GroupedReviewSection] {
        if cachedGroupedReviewSectionsGeneration == inlineSectionCacheGeneration,
           cachedGroupedReviewSectionsMode == dayOrganizationMode {
            return cachedGroupedReviewSections
        }

        let sections = inlineSectionOrganizer.groupedReviewSections(from: organizedInlineSections)
        cachedGroupedReviewSectionsGeneration = inlineSectionCacheGeneration
        cachedGroupedReviewSectionsMode = dayOrganizationMode
        cachedGroupedReviewSections = sections
        return sections
    }

    var canFocusReviewSurface: Bool {
        if workspaceMode == .archiveView {
            switch archiveNavigationLevel {
            case .archive: return !filteredArchiveEntries.isEmpty
            case .trip: return !currentArchiveWalks.isEmpty
            case .photos: return archiveFolderLoadState == .loaded && !visibleMediaItems.isEmpty
            }
        }
        return !visibleMediaItems.isEmpty
    }

    var canUseGroupedSectionNavigation: Bool {
        dayDetailDisplayMode == .sections && !groupedReviewSections.isEmpty
    }

    var isGroupedSectionKeyboardTargetActive: Bool {
        canUseGroupedSectionNavigation && reviewKeyboardTarget == .sections
    }

    var canExpandAllGroupedSections: Bool {
        canUseGroupedSectionNavigation && !organizedInlineSections.isEmpty
    }

    var canCollapseAllGroupedSections: Bool {
        canUseGroupedSectionNavigation && !expandedInlineSectionIDs.isEmpty
    }

    var reviewInteractionItems: [MediaItem] {
        if cachedReviewInteractionGeneration == reviewContentCacheGeneration {
            return cachedReviewInteractionItems
        }

        let items: [MediaItem]
        guard shouldShowInlineDaySections, dayDetailDisplayMode == .sections else {
            items = visibleMediaItems
            cachedReviewInteractionGeneration = reviewContentCacheGeneration
            cachedReviewInteractionItems = items
            return items
        }

        var seen: Set<UUID> = []
        let orderedIDs = inlineSectionOrganizer
            .visibleMediaItemIDs(from: organizedInlineSections, expandedSectionIDs: expandedInlineSectionIDs)
            .filter { seen.insert($0).inserted }
        items = orderedMediaItems(for: orderedIDs)
        cachedReviewInteractionGeneration = reviewContentCacheGeneration
        cachedReviewInteractionItems = items
        return items
    }

    func mediaItems(for ids: [UUID]) -> [MediaItem] {
        let idSet = Set(ids)
        if let node = selectedBrowserNode, let cached = archiveMediaCache[node.id] {
            return cached.filter { idSet.contains($0.id) }
        }
        return MediaItemSort.sorted(ids.compactMap { sessionMediaByID[$0] })
    }

    func orderedMediaItems(for ids: [UUID]) -> [MediaItem] {
        ids.compactMap { mediaItem(for: $0) }
    }

    func openCropVersion(relativePath: String) {
        guard let target = mediaItem(relativePath: relativePath) else {
            statusMessage = "Crop version is not loaded in the current browser view."
            return
        }

        focusMediaItem(target)
        statusMessage = "Showing \(target.cropRelationship?.role == .crop ? "crop" : "original") \(target.fileName)."
    }

    var reviewPresentationMode: ReviewPresentationMode {
        settings.reviewPresentationMode
    }

    var reviewGridPreferredColumnCount: Int {
        settings.reviewGridColumnCount
    }

    var reviewGridCardWidth: Double {
        let width = max(lastMeasuredReviewPaneWidth, 0)
        guard width > 0 else { return ReviewGridMetrics.defaultCardWidth }
        return ReviewGridMetrics(
            availableWidth: width,
            requestedColumnCount: settings.reviewGridColumnCount
        ).cardWidth
    }

    var canOpenCurrentSelection: Bool {
        if workspaceMode == .archiveView {
            return canOpenSelectedArchiveItem
        }
        if activePane == .folders { return selectedFolderNodeIDs.count == 1 }
        if activePane == .sidebar { return canFocusReviewSurface }
        if activePane == .media { return focusedReviewItem != nil }
        return false
    }

    var canNavigateToParent: Bool {
        if workspaceMode == .archiveView {
            return archiveNavigationLevel != .archive
        }
        return selectedBrowserNode?.parentID != nil
    }

    var canClearCurrentSelection: Bool {
        if !comparingMediaItemIDs.isEmpty {
            return selectedMediaItemIDs.contains { comparingMediaItemIDs.contains($0) }
        }
        switch activePane {
        case .sidebar:
            return false
        case .folders:
            return !selectedFolderNodeIDs.isEmpty
        case .media:
            return !selectedMediaItemIDs.isEmpty
        }
    }

    var canMarkSelectionForImport: Bool {
        canMutateImportSelection && !currentSelectionMediaIDs().isEmpty
    }

    var canExcludeSelectionFromImport: Bool {
        canMutateImportSelection && !currentSelectionMediaIDs().isEmpty
    }

    var canMarkSelectionAsCandidate: Bool {
        canMutateImportSelection && !currentSelectionMediaIDs().isEmpty
    }

    var canUnmarkSelectionForImport: Bool {
        canMutateImportSelection && !currentSelectionMediaIDs().isEmpty
    }

    var canToggleRawForSelection: Bool {
        canMutateImportSelection && currentSelectionMediaIDs().contains { mediaID in
            mediaItem(for: mediaID)?.companionFiles.isEmpty == false
        }
    }

    var canPresentPhotoLogCreation: Bool {
        currentSession?.sessionKind == .inbox && proposedPhotoLogCreationPlan(mode: .decidedInScope)?.canCreate == true
    }

    var canCreateWalkDraftFromSelection: Bool {
        canPresentPhotoLogCreation
    }

    var canStartNewPhotoLogFromCurrentLog: Bool {
        guard importOperation.isRunning == false else { return false }
        return currentSession?.sessionKind == .walkDraft
    }

    var canStartNewPhotoLogSession: Bool {
        guard importOperation.isRunning == false else { return false }
        if currentSession?.sessionKind == .walkDraft {
            return true
        }
        return canPresentPhotoLogCreation
    }

    var photoLogSessionStartActionTitle: String {
        currentSession?.sessionKind == .walkDraft ? "Save & Start Next Log" : "Start New Photo Log"
    }

    var photoLogSessionStartActionHelp: String {
        if currentSession?.sessionKind == .walkDraft {
            return "Save the current log details, close this log, and reopen the source inbox for the next selection."
        }
        return "Create a new photo log from the currently marked source photos."
    }

    var selectedMediaItems: [MediaItem] {
        MediaItemSort.sorted(selectedMediaItemIDs.compactMap { mediaItem(for: $0) })
    }

    var focusedReviewItem: MediaItem? {
        guard let focusedReviewItemID else { return reviewInteractionItems.first }
        return reviewInteractionItems.first(where: { $0.id == focusedReviewItemID }) ?? reviewInteractionItems.first
    }

    var inspectorMediaItem: MediaItem? {
        if let focusedReviewItem {
            return focusedReviewItem
        }
        return selectedMediaItems.first
    }

    var previewingMediaItem: MediaItem? {
        guard let previewingMediaItemID else { return nil }
        return mediaItem(for: previewingMediaItemID)
    }

    var comparingMediaItems: [MediaItem] {
        let selectedIDs = Set(comparingMediaItemIDs)
        let orderedVisible = reviewInteractionItems.filter { selectedIDs.contains($0.id) }
        if orderedVisible.count == comparingMediaItemIDs.count {
            return orderedVisible
        }
        return comparingMediaItemIDs.compactMap { mediaItem(for: $0) }
    }

    var canOpenSettings: Bool { true }

    var canOpenComparison: Bool {
        currentSelectionMediaIDs().count >= 2
    }

    var canCommitImport: Bool {
        guard importOperation.isRunning == false else { return false }
        if case .loading = sourceWorkspaceState { return false }
        return currentSession?.mediaItems.contains {
            $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond
        } ?? false
    }

    var canOpenArchiveDestination: Bool {
        guard importOperation.isRunning == false else { return false }
        guard let url = currentCopiedArchiveDestinationURL else { return false }
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    var canConfirmBackup: Bool {
        guard importOperation.isRunning == false else { return false }
        guard let currentSession else { return false }
        guard currentSession.walkMetadata.backupConfirmedAt == nil else { return false }
        return currentSession.mediaItems.contains {
            $0.selectionState.isIncluded
                && ($0.lifecycleState == .verified || $0.lifecycleState == .imported || $0.lifecycleState == .sourceCleanupPending)
        }
    }

    var canCleanupImportedSources: Bool {
        guard importOperation.isRunning == false else { return false }
        guard let currentSession else { return false }
        guard currentSession.archiveMachineRole.allowsSourceCleanup else { return false }
        if settings.cleanupRequiresBackupConfirmation && currentSession.walkMetadata.backupConfirmedAt == nil {
            return false
        }
        return currentSession.mediaItems.contains { $0.lifecycleState == .sourceCleanupPending }
    }

    var canNavigatePreviewBackward: Bool {
        previewNavigationOffset(-1) != nil
    }

    var canNavigatePreviewForward: Bool {
        previewNavigationOffset(1) != nil
    }

    var isBrowsingArchive: Bool {
        switch selectedBrowserNode?.kind {
        case .archiveSection, .archiveRoot, .archiveWalkFolder:
            return true
        case .year, .month:
            return selectedBrowserNode?.id.hasPrefix("archive-") == true
        default:
            return selectedBrowserNode?.id.hasPrefix("archive-") == true
        }
    }

    var canMutateImportSelection: Bool {
        backupPersistenceGate.blockedReason == nil && workspaceMode.allowsImportSelectionMutation && !isBrowsingArchive && !importOperation.isRunning && !(currentSession.map(hasRecordedCopy) ?? false)
    }

    var sidebarSnapshotGeneration: Int {
        sidebarState.generation
    }

    var reviewSnapshotGeneration: Int {
        reviewState.generation
    }

    var navigationSnapshotGeneration: Int {
        reviewNavigationState.generation
    }

    var inspectorSnapshotGeneration: Int {
        inspectorState.generation
    }

    func beginLatencyMeasurement(_ action: String) {
        latencyRecorder.begin(action)
    }

    func endLatencyMeasurement(_ action: String) {
        latencyRecorder.end(action)
    }

    func setWorkspaceMode(_ mode: WorkspaceMode) {
        guard workspaceMode != mode else { return }
        let previousMode = workspaceMode
        let preserveSourceReviewContext = mode == .photoLogs && previousMode == .cameraTriage && !isBrowsingArchive
        workspaceMode = mode
        if mode == .archiveView {
            archiveNavigationLevel = .archive
            activeArchiveContentNode = nil
            if archiveCatalogue.entries.isEmpty && !archiveCatalogueIsLoading {
                reloadArchiveCatalogue()
            }
            refreshArchiveBrowserState()
        }
        rebuildBrowserCaches()
        if !preserveSourceReviewContext {
            selectedSidebarNodeID = preferredSidebarNodeID(for: mode)
            activePane = .sidebar
            dayDetailDisplayMode = .review
            reviewKeyboardTarget = .items
            drilledInlineSectionID = nil
            drilledInlineSectionMediaItemIDs = []
            clearDetailSelections()
        }
        loadArchiveMediaIfNeeded(for: selectedSidebarNodeID)
        resetInlineExpansionState()
        requestVisibleThumbnails()
        statusMessage = statusMessage(for: mode)
        refreshAllUIState()
    }

    func reloadArchiveCatalogue() {
        archiveCatalogueLoadTask?.cancel()
        archiveSearchTask?.cancel(); archiveSearchTask = nil
        archiveSearchRequestID = UUID()
        archiveSearchMatchingPaths = []
        archiveSearchIsLoading = !archiveSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        archiveSearchError = nil
        if case .photos = archiveNavigationLevel, archiveRequestedSearchPhotoPath == nil {
            archiveFolderSelectionToRestore = archiveFolderSelectionToRestore ?? captureArchiveFolderSelection()
        }
        cancelArchiveMediaLoad(clearPendingHit: false)
        if case .photos = archiveNavigationLevel {
            archiveFolderLoadState = .loading
            // Keep the prior items for mapping live Preview/Compare/selection changes to fresh IDs.
        }
        archiveCatalogueLoadGeneration &+= 1
        let generation = archiveCatalogueLoadGeneration
        let capturedSettings = settings
        let contextGeneration = ArchiveByteReadPolicyContext.shared.generation
        let snapshot = ArchiveSearchDatabaseSnapshot(archiveRoot: capturedSettings.archiveRoot, supportRoot: supportRoot)
        let handler = testingArchiveCatalogueHandler
        let savedTripLabels = archiveSavedTripLocationOverlays
        archiveCatalogueIsLoading = true
        archiveCatalogueError = nil
        refreshArchiveBrowserState()

        archiveCatalogueLoadTask = Task.detached(priority: .userInitiated) {
            let result: Result<(catalogue: ArchiveCatalogue, acknowledgedLabels: Set<String>), Error>
            do {
                var catalogue: ArchiveCatalogue
                let indexEntries: [ArchiveIndexEntry]
                if let handler {
                    (catalogue, indexEntries) = try await handler(capturedSettings.archiveRoot, capturedSettings)
                } else {
                    let builder = ArchiveCatalogueBuilder()
                    indexEntries = try builder.readIndexEntries(archiveRoot: capturedSettings.archiveRoot)
                    catalogue = try builder.build(archiveRoot: capturedSettings.archiveRoot,
                        supportedExtensions: capturedSettings.supportedExtensions,
                        machineRole: capturedSettings.archiveMachineRole, indexEntries: indexEntries)
                }
                let acknowledgedLabels = Set(indexEntries.compactMap { row -> String? in
                    guard row.kind == .trip, let saved = savedTripLabels[row.archiveRelativePath],
                          row.tripID == saved.manifest.tripID, row.tripLocationOverride == saved.manifest.locationLabelOverride else { return nil }
                    return row.archiveRelativePath
                })
                catalogue = TripLocationProjection.applyingSavedLabels(savedTripLabels, to: catalogue)
                try Task.checkCancellation()
                try ArchiveSearchCache(databaseURL: snapshot.databaseURL).rebuild(indexEntries: indexEntries, browseEntries: catalogue.entries)
                result = .success((catalogue, acknowledgedLabels))
            } catch { result = .failure(error) }

            await MainActor.run { [weak self] in
                guard let self, generation == self.archiveCatalogueLoadGeneration,
                      contextGeneration == ArchiveByteReadPolicyContext.shared.generation,
                      capturedSettings.archiveRoot.standardizedFileURL == self.settings.archiveRoot.standardizedFileURL,
                      !Task.isCancelled else { return }
                self.archiveCatalogueLoadTask = nil
                self.archiveCatalogueIsLoading = false
                switch result {
                case .success(let value):
                    let catalogue = value.catalogue
                    for path in value.acknowledgedLabels {
                        if self.archiveSavedTripLocationOverlays[path] == savedTripLabels[path] {
                            self.archiveSavedTripLocationOverlays.removeValue(forKey: path)
                        }
                    }
                    self.archiveSearchDatabaseSnapshot = snapshot
                    self.archiveCatalogue = self.googleProjectedCatalogue(catalogue)
                    self.archiveCatalogueError = nil
                    self.reconcileArchiveSelection()
                    self.statusMessage = "Archive catalogue refreshed: \(catalogue.entries.count) entries across \(catalogue.years.count) year(s)."
                    if !self.archiveSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.updateArchiveSearch(self.archiveSearchQuery)
                    } else { self.archiveSearchIsLoading = false }
                    if case .photos = self.archiveNavigationLevel {
                        self.loadArchiveMediaIfNeeded(for: self.selectedSidebarNodeID)
                    }
                case .failure(let error):
                    self.archiveCatalogueError = error.localizedDescription
                    self.archiveSearchIsLoading = false
                    self.archiveSearchError = "Search could not refresh: \(error.localizedDescription)"
                    self.statusMessage = "Archive catalogue could not be refreshed: \(error.localizedDescription)"
                    if case .photos = self.archiveNavigationLevel {
                        self.archiveFolderLoadState = .failed(error.localizedDescription)
                    }
                }
                self.refreshArchiveBrowserState()
            }
        }
    }

    func setArchiveBrowseViewMode(_ mode: ArchiveBrowseViewMode) {
        guard settings.archiveBrowseViewMode != mode else { return }
        settings.archiveBrowseViewMode = mode
        persistSettings()
        refreshArchiveBrowserState()
    }

    func setShowArchivePreviews(_ show: Bool) {
        guard settings.showArchivePreviews != show else { return }
        settings.showArchivePreviews = show
        persistSettings()
        refreshArchiveBrowserState()
    }

    func setArchiveYearFilter(_ year: String?) {
        archiveYearFilter = year
        let returnedFromNestedContent = returnToArchiveCatalogueFromFilter()
        reconcileArchiveSelection()
        if returnedFromNestedContent {
            refreshAllUIState()
        } else {
            refreshArchiveBrowserState()
        }
    }

    func setArchiveKindFilter(_ filter: ArchiveBrowseKindFilter) {
        archiveKindFilter = filter
        let returnedFromNestedContent = returnToArchiveCatalogueFromFilter()
        reconcileArchiveSelection()
        if returnedFromNestedContent {
            refreshAllUIState()
        } else {
            refreshArchiveBrowserState()
        }
    }

    private func returnToArchiveCatalogueFromFilter() -> Bool {
        guard archiveNavigationLevel != .archive || activeArchiveContentNode != nil else { return false }
        cancelArchiveMediaLoad()
        archiveNavigationLevel = .archive
        activeArchiveContentNode = nil
        selectedSidebarNodeID = preferredSidebarNodeID(for: .archiveView)
        activePane = .media
        clearDetailSelections()
        return true
    }

    func setArchiveSort(_ sort: ArchiveBrowseSort) {
        archiveSort = sort
        reconcileArchiveSelection()
        refreshArchiveBrowserState()
    }

    var canRetryCurrentArchiveSearch: Bool {
        workspaceMode == .archiveView && hasArchiveSearchQuery && !archiveSearchIsLoading
    }

    func retryCurrentArchiveSearch() {
        guard canRetryCurrentArchiveSearch else { return }
        updateArchiveSearch(archiveSearchQuery)
    }

    func updateArchiveSearch(_ query: String) {
        let changed = query != archiveSearchQuery
        if changed {
            _ = returnToArchiveCatalogueFromFilter()
            archiveSearchReturnPhotoID = nil
            selectedArchiveSearchTarget = nil
        }
        archiveSearchQuery = query
        archiveSearchTask?.cancel(); archiveSearchTask = nil
        archiveSearchRequestID = UUID()
        let requestID = archiveSearchRequestID
        archiveSearchMatchingPaths = []
        archiveSearchError = nil
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        archiveSearchIsLoading = !trimmed.isEmpty
        guard !trimmed.isEmpty else {
            selectedArchiveSearchResultID = nil
            selectedArchiveSearchTarget = nil
            reconcileArchiveSelection()
            refreshArchiveBrowserState()
            return
        }
        guard let database = archiveSearchDatabaseSnapshot,
              database.archiveRoot == settings.archiveRoot.standardizedFileURL else {
            archiveSearchIsLoading = archiveCatalogueIsLoading
            if !archiveCatalogueIsLoading { reloadArchiveCatalogue() }
            refreshArchiveBrowserState()
            return
        }
        let contextGeneration = ArchiveByteReadPolicyContext.shared.generation
        let handler = testingArchiveSearchHandler
        archiveSearchTask = Task.detached(priority: .userInitiated) {
            let result: Result<Set<String>, Error>
            do {
                if let handler { result = .success(try await handler(database, trimmed)) }
                else {
                    try await Task.sleep(for: .milliseconds(120))
                    try Task.checkCancellation()
                    result = .success(try ArchiveSearchCache(databaseURL: database.databaseURL).matchingPaths(query: trimmed))
                }
            } catch { result = .failure(error) }
            await MainActor.run { [weak self] in
                guard let self, self.archiveSearchRequestID == requestID,
                      self.archiveSearchDatabaseSnapshot?.id == database.id,
                      contextGeneration == ArchiveByteReadPolicyContext.shared.generation,
                      database.archiveRoot == self.settings.archiveRoot.standardizedFileURL,
                      !Task.isCancelled else { return }
                self.archiveSearchTask = nil
                self.archiveSearchIsLoading = false
                switch result {
                case .success(let paths): self.archiveSearchMatchingPaths = paths
                case .failure(let error): self.archiveSearchError = "Search unavailable: \(error.localizedDescription)"
                }
                self.reconcileArchiveSelection()
                self.refreshArchiveBrowserState()
            }
        }
        reconcileArchiveSelection()
        refreshArchiveBrowserState()
    }

    func requestArchiveSearchFocus() {
        archiveSearchFocusRevision &+= 1
        refreshArchiveBrowserState()
    }

    func selectArchiveEntry(_ entryID: String) {
        guard filteredArchiveEntries.contains(where: { $0.id == entryID }) else { return }
        archiveGridNavigator.reset()
        selectedArchiveEntryID = entryID
        if hasArchiveSearchQuery { selectedArchiveSearchTarget = .entry(entryID); selectedArchiveSearchResultID = nil }
        activePane = .media
        refreshArchiveBrowserState()
    }

    @Published var googleAccount: GooglePhotosAccount?
    @Published var googleDeliveryJobs: [GooglePhotosDeliveryJob] = []
    @Published var googleAlbumCandidates: [UUID: [GooglePhotosAlbum]] = [:]
    @Published var googleDeliveryReview: GooglePhotosDeliveryReview?
    @Published var showGoogleQueue = false
    @Published var isDeliveringGooglePhotos = false
    @Published var isConnectingGooglePhotos = false
    private let googleAuthentication: GooglePhotosAuthentication
    private let googleCredentials: any GooglePhotosCredentials
    private let googleClient: any GooglePhotosDelivering
    private let googleSecrets: any GooglePhotosSecretStoring
    private let googleContext = GooglePhotosContextCounter()
    private var googleQueue: GooglePhotosDeliveryQueue?
    private var googleQueueKey: String?
    private var googleDeliveryTask: Task<Void, Never>?
    private var googleDeliveryOperationID: UUID?
    private var googleDeliveryCancellation = 0
    private var googleFactsOverlay: [String: GooglePhotosRecord] = [:]
    private var googleFactsRoot: URL?
    private var googleSignInTask: Task<Void, Never>?

    private var googleRepository: GooglePhotosDeliveryRepository {
        .init(archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole, picturesRoot: settings.oneDrivePicturesRoot)
    }
    func setGooglePhotosClientID(_ value: String) {
        guard value != settings.googlePhotosClientID else { return }
        settings.googlePhotosClientID = value; googleContext.invalidate(); cancelGoogleDelivery(); cancelGoogleSignIn()
        googleAccount = nil; googleDeliveryReview = nil; persistSettings()
    }
    func saveGoogleClientSecret(_ value: String) async {
        do { try await googleAuthentication.storeClientSecret(value, clientID: settings.googlePhotosClientID); statusMessage = "Google client credential saved in Keychain." }
        catch { statusMessage = error.localizedDescription }
    }
    func loadGoogleAccount() async {
        let clientID = settings.googlePhotosClientID
        do {
            let account = try await googleCredentials.account()
            guard settings.googlePhotosClientID == clientID else { return }
            googleAccount = account?.clientID == clientID ? account : nil
            statusMessage = googleAccount == nil ? "Connect a Google account using the configured Desktop client." : "Google Photos account loaded. Delivery requires reviewing the account, album and originals."
        } catch { statusMessage = "Google account unavailable: " + error.localizedDescription }
    }
    func startGoogleSignIn() {
        guard !isConnectingGooglePhotos, !isDeliveringGooglePhotos else { return }
        isConnectingGooglePhotos = true
        let clientID = settings.googlePhotosClientID
        googleContext.invalidate()
        googleSignInTask = Task {
            defer { isConnectingGooglePhotos = false; googleSignInTask = nil }
            do {
                let account = try await googleAuthentication.connect(clientID: clientID)
                guard clientID == settings.googlePhotosClientID else { return }
                googleAccount = account; googleContext.invalidate(); statusMessage = "Google Photos connected to " + account.displayName + "."
            } catch { statusMessage = "Google sign-in stopped: " + error.localizedDescription }
        }
    }
    func cancelGoogleSignIn() { googleSignInTask?.cancel() }
    func disconnectGooglePhotos() async {
        googleContext.invalidate(); cancelGoogleDelivery(); googleDeliveryReview = nil
        do { try await googleAuthentication.disconnect(); googleAccount = nil; statusMessage = "Google Photos disconnected on this Mac. Remote albums and receipts are retained." }
        catch { statusMessage = error.localizedDescription }
    }
    private func currentGoogleQueue() -> GooglePhotosDeliveryQueue {
        let generation = ArchiveByteReadPolicyContext.shared.generation, accountGeneration = googleContext.generation
        let key = "\(generation)-\(accountGeneration)"
        if let googleQueue, googleQueueKey == key { return googleQueue }
        let context = googleContext
        let queue = GooglePhotosDeliveryQueue(archiveRoot: settings.archiveRoot, credentials: googleCredentials, client: googleClient, secrets: googleSecrets,
            repository: googleRepository, contextIsCurrent: { ArchiveByteReadPolicyContext.shared.generation == generation && context.generation == accountGeneration })
        googleQueue = queue; googleQueueKey = key; return queue
    }
    var canDeliverGooglePhotoLog: Bool {
        guard let log = currentSession, log.sessionKind == .walkDraft else { return false }
        return log.mediaItems.contains { $0.destinationURL != nil && $0.lifecycleState.isImportedOrBeyond && $0.recognisedArchiveCopy != true && $0.cropRelationship?.isCrop != true }
    }
    func reviewGoogleTrip() async {
        guard let path = descriptionTripPath, !isDeliveringGooglePhotos else { return }
        let repository = googleRepository, generation = ArchiveByteReadPolicyContext.shared.generation
        do {
            let scope = try await Task.detached { try repository.trip(path: path) }.value
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            await reviewGoogleScope(scope)
        } catch { statusMessage = "Could not review Google Photos delivery: " + error.localizedDescription }
    }
    func reviewGooglePhotoLog() async {
        guard canDeliverGooglePhotoLog, let log = currentSession else { return }
        let repository = googleRepository
        do {
            let paths = log.mediaItems.filter { $0.lifecycleState.isImportedOrBeyond && $0.cropRelationship?.isCrop != true && $0.recognisedArchiveCopy != true }.compactMap { item in
                item.destinationURL.flatMap { ArchiveIndexStore.archiveRelativePath(for: $0, archiveRoot: settings.archiveRoot) }
            }
            let scope = try repository.photoLog(id: log.id, title: log.walkMetadata.title.nonEmpty ?? "Photo Log", paths: paths)
            await reviewGoogleScope(scope)
        } catch { statusMessage = "Could not review Photo Log delivery: " + error.localizedDescription }
    }
    func reviewGoogleScope(_ scope: GooglePhotosDeliveryScope) async {
        let root = settings.archiveRoot, generation = ArchiveByteReadPolicyContext.shared.generation, repository = googleRepository
        do {
            guard let account = try await googleCredentials.account(), account.clientID == settings.googlePhotosClientID else { throw ArchiveFileVerification.failure("Connect the intended Google account in Settings first.") }
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            let bytes = try scope.photos.reduce(Int64(0)) { total, target in
                let url = try ArchiveIndexMediaLoader().indexedURL(target.path, archiveRoot: root)
                return total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            googleAccount = account
            googleDeliveryReview = .init(scope: scope, account: account, archiveRoot: root, generation: generation,
                photoCount: scope.photos.count, totalBytes: bytes, existingAlbum: try repository.binding(scope: scope, account: account)?.album)
        } catch { statusMessage = "Could not review delivery: " + error.localizedDescription }
    }
    func confirmGoogleDelivery(_ review: GooglePhotosDeliveryReview, includeMarked: Bool = false) async {
        guard !isDeliveringGooglePhotos, review.archiveRoot.standardizedFileURL == settings.archiveRoot.standardizedFileURL,
              review.generation == ArchiveByteReadPolicyContext.shared.generation, review.account.clientID == settings.googlePhotosClientID else { statusMessage = "Archive or account settings changed. Review the delivery again."; return }
        let queue = currentGoogleQueue(), operation = UUID(), cancellation = googleDeliveryCancellation
        googleDeliveryOperationID = operation
        isDeliveringGooglePhotos = true; googleDeliveryReview = nil
        let task = Task { [self] in
            defer {
                if googleDeliveryOperationID == operation { isDeliveringGooglePhotos = false; googleDeliveryTask = nil; googleDeliveryOperationID = nil }
            }
            do {
                let job = try await queue.enqueue(scope: review.scope, expectedAccount: review.account, includeMarked: includeMarked)
                try Task.checkCancellation()
                guard cancellation == googleDeliveryCancellation else { throw CancellationError() }
                googleDeliveryJobs = try await queue.jobs(); showGoogleQueue = true
                try Task.checkCancellation()
                guard cancellation == googleDeliveryCancellation else { throw CancellationError() }
                isDeliveringGooglePhotos = false
                await resumeGoogleDelivery(jobIDs: [job.id])
            } catch { statusMessage = error is CancellationError ? "Google Photos preparation cancelled. No automatic delivery will start." : "Could not queue delivery: " + error.localizedDescription }
        }
        googleDeliveryTask = task
        await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
    }

    func loadGoogleDeliveryQueue(show: Bool = true) async {
        guard !isDeliveringGooglePhotos else { if show { showGoogleQueue = true }; return }
        let queue = currentGoogleQueue(), generation = ArchiveByteReadPolicyContext.shared.generation
        do {
            let jobs = try await queue.jobs(); guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            googleDeliveryJobs = jobs; if show { showGoogleQueue = true }
        } catch { statusMessage = "Delivery queue unavailable: " + error.localizedDescription }
    }
    func resumeGoogleDelivery(jobIDs: Set<UUID>? = nil) async {
        guard !isDeliveringGooglePhotos else { return }
        let queue = currentGoogleQueue(), generation = ArchiveByteReadPolicyContext.shared.generation
        isDeliveringGooglePhotos = true; defer { isDeliveringGooglePhotos = false }
        do {
            try await queue.run(jobIDs: jobIDs) { [weak self] jobs in
                await MainActor.run { guard let self, generation == ArchiveByteReadPolicyContext.shared.generation else { return }; self.googleDeliveryJobs = jobs }
            }
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            googleDeliveryJobs = try await queue.jobs()
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            statusMessage = "Google Photos: \(googleDeliveryJobs.filter { $0.state == .completed }.count) completed deliveries; other saved jobs may need retry or reconciliation."
            let targets = googleDeliveryJobs.flatMap { $0.photos.map(\.target) }
            try refreshGoogleDisplayedFacts(targets: targets, scopes: googleDeliveryJobs.map(\.scope), ignoreUnavailable: true)
            if settings.archiveMachineRole == .mainArchive { reloadArchiveCatalogue() }
        } catch { statusMessage = "Google Photos delivery stopped: " + error.localizedDescription }
    }
    func startGoogleResume() {
        guard !isDeliveringGooglePhotos, googleDeliveryTask == nil else { return }
        let operation = UUID(); googleDeliveryOperationID = operation
        googleDeliveryTask = Task { await resumeGoogleDelivery(); if googleDeliveryOperationID == operation { googleDeliveryTask = nil; googleDeliveryOperationID = nil } }
    }
    func cancelGoogleDelivery() { googleDeliveryCancellation &+= 1; googleDeliveryTask?.cancel(); let queue = googleQueue; Task { await queue?.cancel() } }
    func loadGoogleAlbumCandidates(jobID: UUID) async {
        do { let candidates = try await currentGoogleQueue().candidates(jobID: jobID); googleAlbumCandidates[jobID] = candidates; statusMessage = candidates.isEmpty ? "No candidate album is visible. An empty listing does not establish that creation failed; check Google Photos before allowing another request." : "Choose the intended album explicitly before resuming." }
        catch { statusMessage = "Album reconciliation failed: " + error.localizedDescription }
    }
    func adoptGoogleAlbum(albumID: String, jobID: UUID) async {
        do { try await currentGoogleQueue().adopt(albumID: albumID, jobID: jobID); googleAlbumCandidates[jobID] = nil; await loadGoogleDeliveryQueue(show: false); statusMessage = "Album recorded. Resume this captured delivery when ready." }
        catch { statusMessage = "Album reconciliation failed: " + error.localizedDescription }
    }
    func confirmGoogleAlbumAbsent(jobID: UUID, accountID: String) async {
        do { try await currentGoogleQueue().confirmNoAlbumCreated(jobID: jobID, expectedAccountID: accountID); await loadGoogleDeliveryQueue(show: false); statusMessage = "Your confirmation is recorded. Resume may create the requested album." }
        catch { statusMessage = error.localizedDescription }
    }
    func abandonGoogleDelivery(jobID: UUID) async {
        do { try await currentGoogleQueue().abandon(jobID: jobID); await loadGoogleDeliveryQueue(show: false) }
        catch { statusMessage = "Could not stop delivery: " + error.localizedDescription }
    }
    var canMarkGoogleMaterial: Bool { !contextualDescriptionTargets.isEmpty || (workspaceMode == .archiveView && archiveNavigationLevel == .archive && selectedArchiveEntry?.kind == .unorganisedFolder) }
    func markGoogleMaterial(clear: Bool) async {
        let repository = googleRepository, generation = ArchiveByteReadPolicyContext.shared.generation
        do {
            if contextualDescriptionTargets.isEmpty, workspaceMode == .archiveView, archiveNavigationLevel == .archive, let folder = selectedArchiveEntry, folder.kind == .unorganisedFolder {
                try repository.markHistorical(path: folder.archiveRelativePath, note: "Marked by the user as uploaded before Walkfolio; not API verified.", clear: clear)
                if settings.archiveMachineRole == .mainArchive { try await ArchiveIndexMutationQueue.shared.refreshHistoricalGoogleRecord(path: folder.archiveRelativePath, archiveRoot: repository.archiveRoot, policy: archiveIndexWritePolicy)
                    guard generation == ArchiveByteReadPolicyContext.shared.generation, repository.archiveRoot == settings.archiveRoot else { return }
                    reloadArchiveCatalogue()
                }
                guard generation == ArchiveByteReadPolicyContext.shared.generation, repository.archiveRoot == settings.archiveRoot else { return }
                let record = try ArchiveIndexStore().historicalGoogleRecord(folder: repository.archiveRoot.appendingPathComponent(folder.archiveRelativePath)) ?? .init()
                setGoogleFactsOverlay(record, path: folder.archiveRelativePath)
                applyGoogleFactsToDisplayedState()
                statusMessage = "Historical upload mark saved; the folder remains unorganised."
                return
            }
            let targets = try contextualDescriptionTargets.map { try repository.canonical.snapshot(kind: $0.0, path: $0.1).target }
            for target in targets { try repository.mark(target, note: "Marked by the user as uploaded before Walkfolio; not API verified.", clear: clear) }
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            if settings.archiveMachineRole == .mainArchive {
                let walks = try targets.filter { $0.kind != .trip }.map { target -> URL in let url = try ArchiveIndexMediaLoader().indexedURL(target.path, archiveRoot: settings.archiveRoot); return target.kind == .photo ? url.deletingLastPathComponent() : url }
                let trips = try targets.filter { $0.kind == .trip }.map { try ArchiveIndexMediaLoader().indexedURL($0.path, archiveRoot: settings.archiveRoot) }
                try await ArchiveIndexMutationQueue.shared.replaceWalkFolders(walks, archiveRoot: settings.archiveRoot, policy: archiveIndexWritePolicy, tripFolders: trips)
                guard generation == ArchiveByteReadPolicyContext.shared.generation, repository.archiveRoot == settings.archiveRoot else { return }
                reloadArchiveCatalogue()
            }
            try refreshGoogleDisplayedFacts(targets: targets)
            statusMessage = clear ? "Previous-upload marks cleared; verified receipts retained." : "Marked previously uploaded. This is your record, not API verification or cleanup proof."
        } catch { statusMessage = "Could not save previous-upload marks: " + error.localizedDescription }
    }

    private func setGoogleFactsOverlay(_ record: GooglePhotosRecord, path: String) {
        if googleFactsRoot != settings.archiveRoot { googleFactsOverlay = [:]; googleFactsRoot = settings.archiveRoot }
        googleFactsOverlay[path] = record
    }
    private func refreshGoogleDisplayedFacts(targets: [DescriptionReference], scopes: [GooglePhotosDeliveryScope] = [], ignoreUnavailable: Bool = false) throws {
        let repository = googleRepository
        for target in Set(targets) {
            do { setGoogleFactsOverlay(try GooglePhotosRecord.read(in: repository.canonical.text(target)) ?? .init(), path: target.path) }
            catch { if !ignoreUnavailable { throw error } }
        }
        for scope in scopes where scope.kind == .trip {
            do { setGoogleFactsOverlay(try GooglePhotosRecord.read(in: repository.ownerText(scope)) ?? .init(), path: scope.path) }
            catch { if !ignoreUnavailable { throw error } }
        }
        applyGoogleFactsToDisplayedState()
    }
    private func googleProjectedItem(_ original: MediaItem) -> MediaItem {
        var item = original
        if item.cropRelationship?.isCrop == true { item.googlePhotos = nil; return item }
        guard googleFactsRoot == settings.archiveRoot,
              let path = item.archiveRelativePath ?? item.destinationURL.flatMap({ ArchiveIndexStore.archiveRelativePath(for: $0, archiveRoot: settings.archiveRoot) }),
              let record = googleFactsOverlay[path] else { return item }
        item.googlePhotos = record.badge == nil ? nil : record; return item
    }
    private func googleProjectedCatalogue(_ input: ArchiveCatalogue) -> ArchiveCatalogue {
        guard googleFactsRoot == settings.archiveRoot else { return input }
        var catalogue = input
        for i in catalogue.entries.indices {
            let entry = catalogue.entries[i]
            if var record = googleFactsOverlay[entry.archiveRelativePath] {
                if entry.kind == .trip {
                    let ids = Set(catalogue.photos.filter { $0.tripPath == entry.archiveRelativePath && !$0.isDerivedPhoto }.compactMap(\.mediaItemID))
                    record.memberships.removeAll { !ids.contains($0.photoID) }
                }
                catalogue.entries[i].googlePhotos = record.badge == nil ? nil : record
            }
        }
        for key in catalogue.walksByTripPath.keys {
            for i in catalogue.walksByTripPath[key]!.indices {
                let path = catalogue.walksByTripPath[key]![i].archiveRelativePath
                var displayed = catalogue.walksByTripPath[key]![i].googlePhotos ?? .init()
                if let record = googleFactsOverlay[path] { displayed.manualMarks = record.manualMarks }
                let originals = catalogue.photos.filter { $0.walkPath == path && !$0.isDerivedPhoto }
                let ids = Set(originals.compactMap(\.mediaItemID))
                displayed.memberships.removeAll { !ids.contains($0.photoID) }
                for photo in originals {
                    for receipt in googleFactsOverlay[photo.archiveRelativePath]?.memberships ?? [] where receipt.photoID == photo.mediaItemID { displayed.add(receipt) }
                }
                catalogue.walksByTripPath[key]![i].googlePhotos = displayed.badge == nil ? nil : displayed
            }
        }
        return catalogue
    }
    private func applyGoogleFactsToDisplayedState() {
        archiveCatalogue = googleProjectedCatalogue(archiveCatalogue)
        for key in Array(archiveMediaCache.keys) { archiveMediaCache[key] = archiveMediaCache[key]?.map(googleProjectedItem) }
        if var session = currentSession {
            session.mediaItems = session.mediaItems.map(googleProjectedItem)
            setCurrentSession(session, updateKind: .sessionOnly); persistCurrentSession(immediately: true)
        }
        refreshAllUIState()
    }

    @Published var descriptionJobs: [ArchiveDescriptionJob] = []
    @Published var isDescribing = false
    @Published var lmStudioModels: [String] = []
    @Published var isRefreshingLMStudioModels = false
    @Published var showDescriptionQueue = false
    private let descriptionClient: any DescriptionGenerating
    private var descriptionQueue: ArchiveDescriptionQueue?
    private var descriptionQueueGeneration: Int?
    private var descriptionTask: Task<Void, Never>?

    func setLMStudio(baseURL: String? = nil, model: String? = nil) {
        if let baseURL { settings.lmStudioConfiguration.baseURL = baseURL }
        if let model { settings.lmStudioConfiguration.model = model }
        persistSettings()
    }
    func refreshLMStudioModels() async {
        guard !isRefreshingLMStudioModels else { return }
        isRefreshingLMStudioModels = true; defer { isRefreshingLMStudioModels = false }
        let configuration = settings.lmStudioConfiguration
        do {
            let models = try await descriptionClient.models(configuration: configuration)
            guard settings.lmStudioConfiguration.baseURL == configuration.baseURL else { return }
            lmStudioModels = models
            statusMessage = models.isEmpty ? "LM Studio has no available models." : "Found \(models.count) LM Studio models. Choose a vision-capable model for photographs."
        } catch { statusMessage = "LM Studio model refresh failed: " + error.localizedDescription }
    }
    private func currentDescriptionQueue() -> ArchiveDescriptionQueue {
        let generation = ArchiveByteReadPolicyContext.shared.generation
        if let descriptionQueue, descriptionQueueGeneration == generation { return descriptionQueue }
        let queue = ArchiveDescriptionQueue(archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole,
            client: descriptionClient, oneDrivePicturesRoot: settings.oneDrivePicturesRoot,
            contextIsCurrent: { ArchiveByteReadPolicyContext.shared.generation == generation })
        descriptionQueue = queue; descriptionQueueGeneration = generation; return queue
    }
    var contextualDescriptionTargets: [(DescriptionTargetKind, String)] {
        guard workspaceMode == .archiveView else { return [] }
        switch archiveNavigationLevel {
        case .archive:
            if let photo = selectedArchiveSearchPhoto {
                guard !photo.isDerivedPhoto, photo.cropRole != .crop else { return [] }
                return [(.photo, photo.archiveRelativePath)]
            }
            if settings.archiveBrowseViewMode == .map {
                guard let walk = selectedArchiveMapWalk else { return [] }
                return [(.walk, walk.archiveRelativePath)]
            }
            guard let entry = selectedArchiveEntry, entry.kind == .trip, entry.tripID != nil else { return [] }
            return [(.trip, entry.archiveRelativePath)]
        case .trip:
            guard let walk = currentArchiveWalks.first(where: { $0.id == selectedArchiveWalkID }) else { return [] }
            return [(.walk, walk.archiveRelativePath)]
        case .photos(let path, _):
            let selected = selectedMediaItems.compactMap { item -> (DescriptionTargetKind, String)? in
                guard let relative = item.archiveRelativePath, relative.hasPrefix(path + "/"), item.cropRelationship?.isCrop != true else { return nil }
                return (.photo, relative)
            }
            return selected.isEmpty ? [(.walk, path)] : selected
        }
    }
    var descriptionTripPath: String? {
        guard workspaceMode == .archiveView else { return nil }
        switch archiveNavigationLevel {
        case .archive: return selectedArchiveEntry?.kind == .trip ? selectedArchiveEntry?.archiveRelativePath : nil
        case .trip(let path): return path
        case .photos(_, let parentTripPath): return parentTripPath
        }
    }
    var descriptionYear: String? { archiveYearFilter ?? selectedArchiveEntry?.year }
    func describeCurrentMaterial(regenerate: Bool = false) async { await enqueueDescriptions(targets: contextualDescriptionTargets, regenerate: regenerate) }
    func describeCurrentTrip(regenerate: Bool = false) async {
        guard let path = descriptionTripPath else { return }
        await enqueueDescriptions(targets: [(.trip, path)], regenerate: regenerate)
    }
    func describeCurrentYear() async {
        guard workspaceMode == .archiveView, let year = descriptionYear else { return }
        let root = settings.archiveRoot, generation = ArchiveByteReadPolicyContext.shared.generation
        do {
            let rows = try await Task.detached { try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: root) }.value
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            let targets = rows.filter { $0.year == year && (($0.kind == .trip && $0.tripID != nil) || ($0.kind == .walk && $0.sessionID != nil)) }
                .map { ($0.kind == .trip ? DescriptionTargetKind.trip : .walk, $0.archiveRelativePath) }
            await enqueueDescriptions(targets: targets, regenerate: false)
        } catch { statusMessage = "Description year queue failed: " + error.localizedDescription }
    }
    func enqueueDescriptions(targets: [(DescriptionTargetKind, String)], regenerate: Bool = false) async {
        guard !isDescribing, !targets.isEmpty, workspaceMode == .archiveView else { return }
        let queue = currentDescriptionQueue(), generation = ArchiveByteReadPolicyContext.shared.generation
        isDescribing = true
        do {
            let created = try await queue.enqueue(targets: targets, configuration: settings.lmStudioConfiguration, regenerate: regenerate)
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { isDescribing = false; return }
            descriptionJobs = try await queue.jobs(); showDescriptionQueue = true
            isDescribing = false
            if created.isEmpty { statusMessage = "The selected material already has descriptions. Use Regenerate to replace the active result." }
            else { await resumeDescriptions(jobIDs: Set(created.map(\.id))) }
        } catch { isDescribing = false; statusMessage = "Could not queue descriptions: " + error.localizedDescription }
    }
    func loadDescriptionQueue(show: Bool = true) async {
        guard !isDescribing else { if show { showDescriptionQueue = true }; return }
        let queue = currentDescriptionQueue(), generation = ArchiveByteReadPolicyContext.shared.generation
        do {
            let jobs = try await queue.jobs()
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            descriptionJobs = jobs; if show { showDescriptionQueue = true }
        } catch { statusMessage = "Description queue unavailable: " + error.localizedDescription }
    }
    func resumeDescriptions(jobIDs: Set<UUID>? = nil) async {
        guard !isDescribing else { return }
        let queue = currentDescriptionQueue(), generation = ArchiveByteReadPolicyContext.shared.generation
        isDescribing = true
        defer { isDescribing = false }
        do {
            try await queue.run(jobIDs: jobIDs) { [weak self] jobs in
                await MainActor.run {
                    guard let self, generation == ArchiveByteReadPolicyContext.shared.generation else { return }
                    self.descriptionJobs = jobs
                }
            }
            guard generation == ArchiveByteReadPolicyContext.shared.generation else { return }
            descriptionJobs = try await queue.jobs()
            let failed = descriptionJobs.filter { $0.state == .failed || $0.state == .cancelled }.count
            statusMessage = failed == 0 ? "Description queue completed." : "Description queue has \(failed) requests needing retry or a fresh request."
            if settings.archiveMachineRole == .mainArchive { reloadArchiveCatalogue() }
            else { statusMessage += " Canonical results are saved; the main Mac publishes the searchable index." }
        } catch { statusMessage = "Description queue stopped: " + error.localizedDescription }
    }
    func startDescriptionResume() {
        guard !isDescribing else { return }
        descriptionTask = Task { await resumeDescriptions(); descriptionTask = nil }
    }
    func cancelDescriptions() {
        descriptionTask?.cancel()
        let queue = descriptionQueue
        Task { await queue?.cancel() }
    }
    func discardFailedDescriptions() async {
        guard !isDescribing else { return }
        do { let queue = currentDescriptionQueue(); try await queue.discardFailed(); descriptionJobs = try await queue.jobs() }
        catch { statusMessage = "Could not discard failed requests: " + error.localizedDescription }
    }

    @Published var isSavingTripLocation = false

    func tripLocationTarget(for trip: ArchiveBrowseEntry) -> TripLocationTarget? {
        guard trip.kind == .trip else { return nil }
        return TripLocationTarget(relativePath: trip.archiveRelativePath, tripID: trip.tripID, expectedOverride: trip.locationLabelOverride)
    }

    func saveTripLocationLabel(_ label: String?, target: TripLocationTarget, archiveRoot root: URL) async {
        guard !isSavingTripLocation, root.standardizedFileURL == settings.archiveRoot.standardizedFileURL else { return }
        isSavingTripLocation = true
        defer { isSavingTripLocation = false }
        let policy = archiveIndexWritePolicy
        do {
            let result = try await ArchiveIndexMutationQueue.shared.saveTripLocation(target: target, label: label, archiveRoot: root, policy: policy)
            guard root.standardizedFileURL == settings.archiveRoot.standardizedFileURL else { return }
            if let path = result.manifest.folderRelativePath {
                let originalID: UUID?
                if let prior = archiveSavedTripLocationOverlays[path], prior.manifest.tripID == result.manifest.tripID {
                    originalID = prior.originalTripID
                } else { originalID = target.tripID }
                archiveSavedTripLocationOverlays[path] = SavedTripLocationLabel(manifest: result.manifest, originalTripID: originalID)
            }
            archiveCatalogue = TripLocationProjection.applying(result.manifest, to: archiveCatalogue)
            reloadArchiveCatalogue()
            if let error = result.indexError { statusMessage = "Saved Trip label, but Archive Index refresh failed: \(error)" }
            else {
                statusMessage = result.manifest.locationLabelOverride == nil ? "Restored the Trip location derived from its Walks." : "Saved Trip location label."
                if !policy.canWriteIndex { statusMessage += " The current view is updated; the main Mac publishes the index after rebuilding." }
            }
        } catch { statusMessage = "Trip label save failed: \(error.localizedDescription)" }
    }

    func selectArchiveWalk(_ walkID: String) {
        guard currentArchiveWalks.contains(where: { $0.id == walkID }) else { return }
        archiveGridNavigator.reset()
        selectedArchiveWalkID = walkID
        activePane = .media
        refreshArchiveBrowserState()
    }

    func selectArchiveSearchResult(_ resultID: String) {
        guard archiveSearchResults.contains(where: { $0.id == resultID }) else { return }
        archiveGridNavigator.reset()
        selectedArchiveSearchResultID = resultID
        selectedArchiveSearchTarget = .photo(resultID)
        if settings.archiveBrowseViewMode == .map { selectedArchiveMapItemID = .photo(resultID) }
        activePane = .media
        refreshArchiveBrowserState()
    }

    func moveArchiveSelection(horizontal: Int, vertical: Int, contactSheetColumns: Int) {
        switch archiveNavigationLevel {
        case .trip:
            selectedArchiveWalkID = archiveGridNavigator.target(sections: [currentArchiveWalks.map(\.id)],
                selectedID: selectedArchiveWalkID, horizontal: horizontal, vertical: vertical, columns: contactSheetColumns)
        case .photos:
            return
        case .archive:
            if hasArchiveSearchQuery, settings.archiveBrowseViewMode != .map {
                let photoIDs = archiveSearchResults.map { ArchiveSearchItemID.photo($0.id) }
                let rows = stride(from: 0, to: photoIDs.count, by: max(contactSheetColumns, 1)).map {
                    Array(photoIDs[$0..<min($0 + max(contactSheetColumns, 1), photoIDs.count)])
                }
                let entryColumns = settings.archiveBrowseViewMode == .timeline ? 1 : max(contactSheetColumns, 1)
                let entryRows = archiveBrowseContent.yearGroups.flatMap { group in
                    stride(from: 0, to: group.entries.count, by: entryColumns).map {
                        Array(group.entries[$0..<min($0 + entryColumns, group.entries.count)]).map { ArchiveSearchItemID.entry($0.id) }
                    }
                }
                selectedArchiveSearchTarget = archiveGridNavigator.targetRows(rows: rows + entryRows,
                    selectedID: selectedArchiveSearchTarget, horizontal: horizontal, vertical: vertical,
                    layoutKey: [max(contactSheetColumns, 1), entryColumns])
                switch selectedArchiveSearchTarget {
                case .photo(let id): selectedArchiveSearchResultID = id
                case .entry(let id): selectedArchiveEntryID = id; selectedArchiveSearchResultID = nil
                case nil: break
                }
            } else if settings.archiveBrowseViewMode == .map {
                let ids = archiveBrowseContent.mapNavigationIDs
                guard !ids.isEmpty else { return }
                let index = selectedArchiveMapItemID.flatMap { ids.firstIndex(of: $0) } ?? 0
                let delta = vertical != 0 ? vertical : horizontal
                selectedArchiveMapItemID = ids[min(max(index + delta, 0), ids.count - 1)]
                if hasArchiveSearchQuery {
                    switch selectedArchiveMapItemID {
                    case .photo(let id): selectedArchiveSearchTarget = .photo(id); selectedArchiveSearchResultID = id
                    case .folder(let id): selectedArchiveSearchTarget = .entry(id); selectedArchiveSearchResultID = nil
                    case .walk:
                        if let id = selectedArchiveMapWalk.flatMap({ archiveBrowseContent.tripsByPath[$0.tripPath]?.id }) {
                            selectedArchiveSearchTarget = .entry(id); selectedArchiveEntryID = id; selectedArchiveSearchResultID = nil
                        }
                    case nil: break
                    }
                }
            } else {
                let sections = archiveBrowseContent.yearGroups.map { $0.entries.map(\.id) }
                selectedArchiveEntryID = archiveGridNavigator.target(sections: sections,
                    selectedID: selectedArchiveEntryID, horizontal: settings.archiveBrowseViewMode == .timeline ? 0 : horizontal,
                    vertical: vertical, columns: settings.archiveBrowseViewMode == .timeline ? 1 : contactSheetColumns)
            }
        }
        activePane = .media
        refreshArchiveBrowserState()
    }

    func openSelectedArchiveItem() {
        switch archiveNavigationLevel {
        case .archive:
            guard !archiveSearchIsLoading else { return }
            if hasArchiveSearchQuery, settings.archiveBrowseViewMode != .map,
               case .photo(let id) = selectedArchiveSearchTarget {
                if let result = archiveSearchResults.first(where: { $0.id == id }) { openArchiveSearchPhoto(result) }
                return
            }
            if settings.archiveBrowseViewMode == .map {
                switch selectedArchiveMapItemID {
                case .walk(let path):
                    if let walk = archiveBrowseContent.map.walks.first(where: { $0.archiveRelativePath == path }) { openArchiveMapWalk(walk) }
                case .folder(let id):
                    if let entry = archiveBrowseContent.allEntriesByID[id] { openArchiveMapFolder(entry) }
                case .photo(let id):
                    if let result = archiveSearchResults.first(where: { $0.id == id }) { openArchiveSearchPhoto(result) }
                case nil: break
                }
                return
            }
            guard let entry = selectedArchiveEntry else { return }
            if entry.kind == .trip {
                archiveGridNavigator.reset()
                archiveNavigationLevel = .trip(path: entry.archiveRelativePath)
                selectedArchiveWalkID = archiveCatalogue.walksByTripPath[entry.archiveRelativePath]?.first?.id
                refreshArchiveBrowserState()
            } else {
                openArchivePhotoFolder(
                    relativePath: entry.archiveRelativePath,
                    title: entry.title,
                    parentTripPath: nil
                )
            }
        case .trip(let path):
            guard let walk = currentArchiveWalks.first(where: { $0.id == selectedArchiveWalkID })
                    ?? currentArchiveWalks.first else { return }
            openArchivePhotoFolder(
                relativePath: walk.archiveRelativePath,
                title: walk.title,
                parentTripPath: path
            )
        case .photos:
            focusReviewSurface()
            openFocusedReviewItem()
        }
    }

    func openArchiveMapWalk(_ walk: ArchiveMapWalk) {
        guard archiveCatalogue.walksByTripPath[walk.tripPath]?.contains(where: { $0.archiveRelativePath == walk.archiveRelativePath }) == true else { return }
        selectedArchiveMapItemID = .walk(walk.archiveRelativePath)
        selectedArchiveEntryID = archiveBrowseContent.tripsByPath[walk.tripPath]?.id
        openArchivePhotoFolder(relativePath: walk.archiveRelativePath, title: walk.title, parentTripPath: walk.tripPath)
    }

    func openArchiveMapFolder(_ entry: ArchiveBrowseEntry) {
        guard entry.kind == .unorganisedFolder,
              filteredArchiveEntries.contains(where: { $0.id == entry.id }) else { return }
        selectedArchiveMapItemID = .folder(entry.id)
        selectArchiveEntry(entry.id)
        openArchivePhotoFolder(relativePath: entry.archiveRelativePath, title: entry.title, parentTripPath: nil)
    }

    func organiseSelectedUnorganisedFolder() {
        guard let entry = selectedArchiveEntry,
              entry.kind == .unorganisedFolder else {
            statusMessage = "Select an Unorganised Folder before choosing Organise as a Trip."
            return
        }
        let folder = archiveURL(for: entry.archiveRelativePath)
        statusMessage = "Opening \(entry.title) as a Triage source. The Archive folder stays unchanged until you explicitly copy."
        loadSourceWorkspace(folder: folder, origin: .historicalFolder)
    }

    var canOpenSelectedArchiveItem: Bool {
        switch archiveNavigationLevel {
        case .archive:
            guard !archiveSearchIsLoading else { return false }
            if hasArchiveSearchQuery, settings.archiveBrowseViewMode != .map { return selectedArchiveSearchTarget != nil }
            return settings.archiveBrowseViewMode == .map ? selectedArchiveMapItemID != nil : selectedArchiveEntry != nil
        case .trip:
            return !currentArchiveWalks.isEmpty
        case .photos:
            return canFocusReviewSurface
        }
    }

    var canOrganiseSelectedUnorganisedFolder: Bool {
        guard archiveNavigationLevel == .archive, !archiveSearchIsLoading else { return false }
        if hasArchiveSearchQuery, settings.archiveBrowseViewMode != .map,
           case .photo = selectedArchiveSearchTarget { return false }
        if settings.archiveBrowseViewMode == .map, case .photo = selectedArchiveMapItemID { return false }
        return selectedArchiveEntry?.kind == .unorganisedFolder
    }

    func openArchiveSearchPhoto(_ result: ArchivePhotoSummary) {
        guard !archiveSearchIsLoading, archiveSearchResults.contains(where: { $0.id == result.id }) else { return }
        do { _ = try ArchiveIndexMediaLoader().indexedURL(result.archiveRelativePath, archiveRoot: settings.archiveRoot) }
        catch { statusMessage = "Search result cannot be opened: \(error.localizedDescription)"; return }
        selectArchiveSearchResult(result.id)
        let folder = result.walkPath ?? (result.archiveRelativePath as NSString).deletingLastPathComponent
        let folderPath = folder.isEmpty ? "." : folder
        guard folderPath == "." || result.archiveRelativePath.hasPrefix(folderPath + "/") else {
            statusMessage = "The search result has inconsistent folder metadata."; return
        }
        let title = archiveLocationWalksByPath[folderPath]?.title ?? URL(fileURLWithPath: folderPath).lastPathComponent
        openArchivePhotoFolder(relativePath: folderPath, title: title, parentTripPath: result.tripPath,
            requestedPhotoPath: result.archiveRelativePath)
        archiveSearchReturnPhotoID = result.id
    }

    private func openArchivePhotoFolder(relativePath: String, title: String, parentTripPath: String?, requestedPhotoPath: String? = nil) {
        let folderURL = archiveURL(for: relativePath)
        let nodeID = "archive-content-\(CacheKeyBuilder.key(for: relativePath))"
        let node = BrowserNode(
            id: nodeID,
            title: title,
            subtitle: relativePath.replacingOccurrences(of: "/", with: " / "),
            kind: .archiveWalkFolder,
            parentID: nil,
            mediaItemIDs: [],
            children: nil,
            folderURL: folderURL
        )
        archiveGridNavigator.reset()
        cancelArchiveMediaLoad()
        archiveSearchReturnPhotoID = nil
        archiveRequestedSearchPhotoPath = requestedPhotoPath
        archiveLocationRecoveryWalkPath = nil
        activeArchiveContentNode = node
        archiveNavigationLevel = .photos(path: relativePath, parentTripPath: parentTripPath)
        selectedSidebarNodeID = nodeID
        activePane = .media
        previewingMediaItemID = nil; comparingMediaItemIDs = []; compareSelectionBackup = nil
        clearDetailSelections()
        loadArchiveMediaIfNeeded(for: nodeID)
        refreshArchiveBrowserState()
    }

    private func moveArchiveSearchSelection(horizontal: Int, vertical: Int, columns: Int) {
        let results = archiveSearchResults
        guard !results.isEmpty else { return }
        let currentIndex = selectedArchiveSearchResultID.flatMap { id in results.firstIndex(where: { $0.id == id }) } ?? 0
        let delta = horizontal + (vertical * max(columns, 1))
        let target = min(max(currentIndex + delta, 0), results.count - 1)
        selectedArchiveSearchResultID = results[target].id
        refreshArchiveBrowserState()
    }

    func pickSourceFolder(historical: Bool = false) {
        let shouldAddToCurrentTriage: Bool
        if currentSession != nil && workspaceMode == .cameraTriage {
            let alert = NSAlert()
            alert.messageText = "Add another Source to this Triage?"
            alert.informativeText = "Add Source keeps the current Triage open and merges photos from the chosen folder. Open New Source replaces the current source view."
            alert.addButton(withTitle: "Add Source")
            alert.addButton(withTitle: "Open New Source")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertThirdButtonReturn {
                return
            }
            shouldAddToCurrentTriage = response == .alertFirstButtonReturn
        } else {
            shouldAddToCurrentTriage = false
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.defaultSourceRoot

        if panel.runModal() == .OK, let folder = panel.urls.first {
            if shouldAddToCurrentTriage {
                addSourceFolderToCurrentTriage(folder, historical: historical)
            } else {
                loadSourceWorkspace(folder: folder, origin: historical ? .historicalFolder : .manualPicker)
            }
        }
    }

    func addSourceFolderToCurrentTriage(_ folder: URL, historical: Bool = false) {
        guard activeWalkCommitEditor == nil else { statusMessage = "Finish or dismiss the Copy review before adding another Source."; return }
        guard let currentSession else {
            loadSourceWorkspace(folder: folder, origin: historical ? .historicalFolder : .manualPicker)
            return
        }
        guard allowEditingCopyInputs(currentSession) else { return }
        let historicalContext = currentSession.sourceProvenances.compactMap(\.historical).first { $0.root.standardizedFileURL == folder.resolvingSymlinksInPath().standardizedFileURL }
            ?? (historical ? HistoricalSourceContext(root: folder.resolvingSymlinksInPath()) : nil)
        let generation = invalidateInFlightSourceLoad()
        sourceLoadTask = Task { [weak self] in
            await self?.performAdditionalSourceLoad(folder: folder, into: currentSession, generation: generation, historical: historicalContext)
        }
    }

    func openSourceInbox(for workspaceSourceFolder: URL) {
        loadSourceWorkspace(folder: workspaceSourceFolder, origin: .savedWalkInbox)
    }

    func startNewPhotoLogFromCurrentLog() {
        guard canStartNewPhotoLogFromCurrentLog, let currentSession else {
            statusMessage = "Open a photo log before starting a new one."
            return
        }

        let sourceFolder = currentSession.workspaceSourceFolder.standardizedFileURL
        let sourceFolderPath = sourceFolder.path
        let logTitle = currentSession.walkMetadata.title.nonEmpty ?? "current photo log"

        importProgress = nil
        importOperation = .idle

        if let inboxRecord = persistedSessions.first(where: {
            $0.0.sessionKind == .inbox &&
            $0.0.workspaceSourceFolder.standardizedFileURL.path == sourceFolderPath
        }) {
            invalidateInFlightSourceLoad()
            sourceWorkspaceState = inboxRecord.0.mediaItems.isEmpty
                ? .empty(sourcePath: sourceFolderPath)
                : .loaded(itemCount: inboxRecord.0.mediaItems.count, sourcePath: sourceFolderPath)
            setWorkspaceMode(.cameraTriage)
            openPersistedSessionRecord(
                inboxRecord,
                status: "Closed \(logTitle). Opened the source inbox so you can start a new photo log."
            )
            requestVisibleThumbnails(prefetching: inboxRecord.0.mediaItems)
            return
        }

        statusMessage = "Closing \(logTitle) and scanning the source inbox..."
        loadSourceWorkspace(folder: sourceFolder, origin: .savedWalkInbox)
    }

    func startNewPhotoLogSession() {
        guard importOperation.isRunning == false else {
            statusMessage = "Wait for the current copy operation to finish before starting another photo log."
            return
        }
        guard let currentSession else {
            statusMessage = "Open a source inbox or photo log before starting a new photo log."
            return
        }

        switch currentSession.sessionKind {
        case .walkDraft:
            startNewPhotoLogFromCurrentLog()
        case .inbox:
            presentPhotoLogCreation()
        }
    }

    func saveCurrentLogDetailsAndStartNext(title: String, location: String, notes: String, sessionID: UUID? = nil) {
        if let sessionID, currentSession?.id != sessionID { return }
        if let currentSession {
            guard allowEditingCopyInputs(currentSession) else { return }
            let updated = sessionMutationCoordinator.sessionByUpdatingWalkMetadata(currentSession, title: title, location: location, notes: notes)
            guard save(updated) else { return }
        }
        startNewPhotoLogSession()
    }

    func openPhotoLogLibrary() {
        setWorkspaceMode(.photoLogs)
        statusMessage = "Opened Photo Logs. Continue, inspect, or return to the source inbox from the Current Log controls."
    }

    func openDefaultSourceWorkspace() {
        loadSourceWorkspace(folder: settings.defaultSourceRoot, origin: .openDefaultSource)
    }

    func reloadCurrentSourceWorkspace() {
        let sourceFolder = currentSession?.workspaceSourceFolder ?? settings.defaultSourceRoot
        loadSourceWorkspace(folder: sourceFolder, origin: .reloadCurrentSource)
    }

    func pickArchiveRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Set Archive Root"
        panel.message = "Choose the library root that contains year folders like 2024, 2025, and 2026."
        panel.directoryURL = settings.archiveRoot

        if panel.runModal() == .OK, let folder = panel.urls.first {
            setArchiveRoot(folder)
        }
    }

    func pickOneDrivePicturesRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Set OneDrive Pictures Root"
        panel.message = "Choose the OneDrive Pictures folder whose relative paths should match across your Macs."
        panel.directoryURL = settings.oneDrivePicturesRoot

        if panel.runModal() == .OK, let folder = panel.urls.first {
            setOneDrivePicturesRoot(folder)
        }
    }

    func pickDefaultSourceRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Set Default SSD Root"
        panel.message = "Choose the default SSD root the source folder picker should open in."
        panel.directoryURL = settings.defaultSourceRoot

        if panel.runModal() == .OK, let folder = panel.urls.first {
            setDefaultSourceRoot(folder)
        }
    }

    func openSession(for folder: URL) async {
        let generation = invalidateInFlightSourceLoad()
        await performSourceWorkspaceLoad(folder: folder, origin: .manualPicker, generation: generation)
    }

    func loadSourceWorkspace(folder: URL, origin: SourceLoadOrigin) {
        let generation = invalidateInFlightSourceLoad()
        sourceLoadTask = Task { [weak self] in
            await self?.performSourceWorkspaceLoad(folder: folder, origin: origin, generation: generation)
        }
    }

    private func performSourceWorkspaceLoad(
        folder: URL,
        origin: SourceLoadOrigin,
        generation: Int
    ) async {
        guard !Task.isCancelled, generation == sourceLoadGeneration else { return }
        let standardizedFolder = folder.standardizedFileURL
        var resolvedFolder = standardizedFolder
        do {
            flushPendingSessionPersistence()
            try reloadPersistedSessionsFromStore()
            let previousHistorical = ((currentSession?.sourceProvenances ?? []) + persistedSessions.flatMap { $0.0.sourceProvenances })
                .compactMap(\.historical).first { $0.root.standardizedFileURL == standardizedFolder.resolvingSymlinksInPath().standardizedFileURL }
            let historical = previousHistorical ?? (origin == .historicalFolder ? HistoricalSourceContext(root: standardizedFolder.resolvingSymlinksInPath()) : nil)
            resolvedFolder = historical?.root ?? sourceWorkspaceFolderResolver.resolve(selectedFolder: standardizedFolder)
            let resolvedFolderPath = resolvedFolder.path
            logger.log("Starting source workspace load from \(standardizedFolder.path, privacy: .public) resolved to \(resolvedFolder.path, privacy: .public) via \(origin.rawValue, privacy: .public)")
            sourceWorkspaceState = .loading(sourcePath: resolvedFolder.path)
            statusMessage = "Scanning source folder \(resolvedFolder.lastPathComponent)..."

            let scanned = try await scanSourceFolder(for: resolvedFolder, settings: settings, historical: historical)
            guard !Task.isCancelled, generation == sourceLoadGeneration else {
                logger.log("Discarded stale source load for \(resolvedFolder.path, privacy: .public)")
                return
            }

            let existingInbox = persistedSessions.first(where: {
                $0.0.sessionKind == .inbox && $0.0.workspaceSourceFolder.standardizedFileURL.path == resolvedFolderPath
            })
            var rebuiltInbox = rebuildInboxSession(
                from: scanned,
                workspaceSourceFolder: resolvedFolder,
                existingInbox: existingInbox?.0, historical: historical
            )
            let archiveCopySurvey = await archiveCopySurveyor.survey(
                items: rebuiltInbox.mediaItems,
                archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole,
                historical: historical != nil
            )
            guard !Task.isCancelled, generation == sourceLoadGeneration else {
                logger.log("Discarded stale source load after archive survey for \(resolvedFolder.path, privacy: .public)")
                return
            }

            rebuiltInbox = applyArchiveCopySurvey(archiveCopySurvey, to: rebuiltInbox)
            let regrouped = groupingService.group(items: rebuiltInbox.mediaItems, settings: settings)
            rebuiltInbox.mediaItems = regrouped.items
            let inboxRecord = (rebuiltInbox, regrouped.burstGroups, regrouped.timeClusters)
            try flushPendingSessionPersistenceOrThrow()
            try sessionManager.save(inboxRecord.0, bursts: inboxRecord.1, clusters: inboxRecord.2, to: sessionStore)
            storePersistedSession(inboxRecord.0, bursts: inboxRecord.1, clusters: inboxRecord.2)

            let message: String
            if inboxRecord.0.mediaItems.isEmpty {
                sourceWorkspaceState = .empty(sourcePath: resolvedFolder.path)
                message = sourceLoadStatusMessage(
                    base: "Loaded inbox for \(resolvedFolder.lastPathComponent); no supported media are currently visible.",
                    sourcePath: resolvedFolder.path
                )
            } else {
                sourceWorkspaceState = .loaded(itemCount: inboxRecord.0.mediaItems.count, sourcePath: resolvedFolder.path)
                message = sourceLoadStatusMessage(
                    base: "Loaded inbox with \(inboxRecord.0.mediaItems.count) items from \(resolvedFolder.lastPathComponent).",
                    sourcePath: resolvedFolder.path
                )
            }
            if shouldSwitchToCameraTriage(for: origin) {
                setWorkspaceMode(.cameraTriage)
            }
            openPersistedSessionRecord(
                inboxRecord,
                status: message,
                sourceArchiveCopiesByRelativePath: archiveCopySurvey
            )
            requestVisibleThumbnails(prefetching: inboxRecord.0.mediaItems)
        } catch {
            guard generation == sourceLoadGeneration else { return }
            logger.error("Failed to open session for \(folder.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            sourceWorkspaceState = .failed(sourcePath: resolvedFolder.path, message: error.localizedDescription)
            statusMessage = "Failed to load source folder: \(error.localizedDescription)"
        }
    }

    private func performAdditionalSourceLoad(
        folder: URL,
        into baseSession: ImportSession,
        generation: Int,
        historical: HistoricalSourceContext? = nil
    ) async {
        guard !Task.isCancelled, generation == sourceLoadGeneration else { return }
        let standardizedFolder = folder.standardizedFileURL
        let resolvedFolder = historical?.root ?? sourceWorkspaceFolderResolver.resolve(selectedFolder: standardizedFolder)
        do {
            flushPendingSessionPersistence()
            logger.log("Adding source \(resolvedFolder.path, privacy: .public) to current Triage \(baseSession.id.uuidString, privacy: .public)")
            sourceWorkspaceState = .loading(sourcePath: resolvedFolder.path)
            statusMessage = "Adding Source \(resolvedFolder.lastPathComponent)..."

            let scanned = try await scanSourceFolder(for: resolvedFolder, settings: settings, historical: historical)
            guard !Task.isCancelled, generation == sourceLoadGeneration else { return }

            let survey = await archiveCopySurveyor.survey(items: scanned.session.mediaItems,
                archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole, historical: historical != nil)
            guard !Task.isCancelled, generation == sourceLoadGeneration else { return }
            guard let latestSession = currentSession, latestSession.id == baseSession.id,
                  !importOperation.isRunning, allowEditingCopyInputs(latestSession) else { return }
            let provenance = latestSession.sourceProvenances.first { $0.folder.standardizedFileURL == resolvedFolder.standardizedFileURL }
                ?? SourceProvenance(folder: resolvedFolder, historical: historical)
            var newItems = applyArchiveCopySurvey(survey, to: scanned.session).mediaItems
            for index in newItems.indices {
                newItems[index].sourceProvenanceID = provenance.id
            }

            var merged = latestSession
            if !merged.sourceProvenances.contains(where: { $0.folder.standardizedFileURL.path == resolvedFolder.path }) {
                merged.sourceProvenances.append(provenance)
            }
            let existingKeys = Set(merged.mediaItems.map { "\($0.sourceURL.path)|\($0.fileSizeBytes)" })
            merged.mediaItems.append(contentsOf: newItems.filter { !existingKeys.contains("\($0.sourceURL.path)|\($0.fileSizeBytes)") })
            merged.proposedWalks = []
            merged.lastUpdatedAt = Date()
            merged.weekdayTokenStyle = settings.weekdayTokenStyle

            let grouped = groupingService.group(items: merged.mediaItems, settings: settings)
            merged.mediaItems = grouped.items
            try flushPendingSessionPersistenceOrThrow()
            try sessionManager.save(merged, bursts: grouped.burstGroups, clusters: grouped.timeClusters, to: sessionStore)
            storePersistedSession(merged, bursts: grouped.burstGroups, clusters: grouped.timeClusters)
            sourceWorkspaceState = .loaded(itemCount: merged.mediaItems.count, sourcePath: merged.workspaceSourceFolder.path)
            openPersistedSessionRecord(
                (merged, grouped.burstGroups, grouped.timeClusters),
                status: "Added Source \(resolvedFolder.lastPathComponent); Triage now has \(merged.mediaItems.count) item(s) from \(merged.sourceProvenances.count) Source(s).",
                sourceArchiveCopiesByRelativePath: sourceArchiveCopiesByRelativePath.merging(survey, uniquingKeysWith: { _, added in added })
            )
            requestVisibleThumbnails(prefetching: merged.mediaItems)
        } catch {
            guard generation == sourceLoadGeneration else { return }
            logger.error("Failed to add source \(folder.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            sourceWorkspaceState = .failed(sourcePath: resolvedFolder.path, message: error.localizedDescription)
            statusMessage = "Failed to add Source: \(error.localizedDescription)"
        }
    }

    func openSavedWalk(_ sessionID: UUID) {
        guard let record = persistedSessions.first(where: { $0.0.id == sessionID }) else {
            statusMessage = "Photo log could not be found in the local library."
            return
        }

        invalidateInFlightSourceLoad()
        sourceWorkspaceState = .idle
        setWorkspaceMode(.cameraTriage)
        openPersistedSessionRecord(record, status: "Resumed \(record.0.walkMetadata.title.nonEmpty ?? "Untitled Photo Log").")
        requestVisibleThumbnails(prefetching: record.0.mediaItems)
    }

    func openPhotoLog(_ sessionID: UUID) {
        openSavedWalk(sessionID)
    }

    func editPhotoLogMembership(_ sessionID: UUID) {
        guard let logRecord = persistedSessions.first(where: { $0.0.id == sessionID && $0.0.sessionKind == .walkDraft }) else {
            statusMessage = "Photo log could not be found in the local library."
            return
        }
        guard allowEditingCopyInputs(logRecord.0) else { return }
        if PhotoLogStatusPolicy.isMembershipLocked(status: logRecord.0.status) {
            statusMessage = PhotoLogStatusPolicy.membershipLockMessage(status: logRecord.0.status) ?? "This photo log's item list is locked."
            return
        }

        let workspacePath = logRecord.0.workspaceSourceFolder.standardizedFileURL.path
        let inboxRecord = persistedSessions.first {
            $0.0.id != sessionID &&
            $0.0.sessionKind == .inbox &&
            $0.0.workspaceSourceFolder.standardizedFileURL.path == workspacePath
        }

        var editableItemsByPath: [String: MediaItem] = [:]
        for item in logRecord.0.mediaItems where editableItemsByPath[item.relativePath] == nil {
            editableItemsByPath[item.relativePath] = item
        }
        if let inboxItems = inboxRecord?.0.mediaItems {
            for item in inboxItems where editableItemsByPath[item.relativePath] == nil {
                editableItemsByPath[item.relativePath] = item
            }
        }
        let editableItems = MediaItemSort.sorted(Array(editableItemsByPath.values))
        let grouped = groupingService.group(items: editableItems, settings: settings)

        var editableSession = logRecord.0
        editableSession.mediaItems = grouped.items
        editableSession.sourceProvenances = mergedSourceProvenances(logRecord.0.sourceProvenances, inboxRecord?.0.sourceProvenances ?? [])
        editableSession.lastUpdatedAt = Date()
        editableSession.status = "draft"

        activePhotoLogMembershipEditID = sessionID
        invalidateInFlightSourceLoad()
        sourceWorkspaceState = .idle
        setWorkspaceMode(.cameraTriage)
        openPersistedSessionRecord(
            (editableSession, grouped.burstGroups, grouped.timeClusters),
            status: PhotoLogStatusPolicy.editLogStatusMessage(title: editableSession.walkMetadata.title.nonEmpty ?? "Untitled Photo Log")
        )
        activePhotoLogMembershipEditID = sessionID
        requestVisibleThumbnails(prefetching: editableSession.mediaItems)
    }

    func presentPhotoLogCreation() {
        guard let currentSession else { return }
        guard currentSession.sessionKind == .inbox else {
            statusMessage = "Photo logs can only be created from a source inbox."
            return
        }
        guard let plan = proposedPhotoLogCreationPlan(mode: .decidedInScope) else {
            statusMessage = "Focus the review grid or select one folder before creating a photo log."
            return
        }

        let defaultTitle = currentSession.walkMetadata.title.nonEmpty ?? plan.scope.label.nonEmpty ?? "Untitled Photo Log"
        activePhotoLogEditor = PhotoLogEditorState(
            id: UUID(),
            mode: .create,
            creationMode: .decidedInScope,
            title: defaultTitle,
            location: currentSession.walkMetadata.location,
            notes: currentSession.walkMetadata.notes,
            scopeKind: plan.scope.kind,
            scopeLabel: plan.scope.label,
            sourceFolderPaths: plan.scope.sourceFolderPaths,
            startDate: plan.scope.startDate,
            endDate: plan.scope.endDate
        )
    }

    func dismissPhotoLogEditor() {
        activePhotoLogEditor = nil
    }

    func updateActivePhotoLogEditor(_ editor: PhotoLogEditorState) {
        activePhotoLogEditor = editor
    }

    func presentPhotoLogEditor(_ sessionID: UUID) {
        guard let record = persistedSessions.first(where: { $0.0.id == sessionID }) else {
            statusMessage = "Photo log could not be found in the local library."
            return
        }
        let scope = record.0.photoLogScope ?? defaultPhotoLogScope(for: record.0)
        activePhotoLogEditor = PhotoLogEditorState(
            id: UUID(),
            mode: .edit(sessionID: sessionID),
            creationMode: .decidedInScope,
            title: record.0.walkMetadata.title,
            location: record.0.walkMetadata.location,
            notes: record.0.walkMetadata.notes,
            scopeKind: scope.kind,
            scopeLabel: scope.label,
            sourceFolderPaths: scope.sourceFolderPaths,
            startDate: scope.startDate,
            endDate: scope.endDate
        )
    }

    func showPhotoLogContents(_ sessionID: UUID) {
        guard let record = persistedSessions.first(where: { $0.0.id == sessionID }) else {
            statusMessage = "Photo log could not be found in the local library."
            return
        }
        revealedPhotoLog = PhotoLogRevealState(
            sessionID: sessionID,
            title: record.0.walkMetadata.title.nonEmpty ?? "Untitled Photo Log",
            relativePaths: record.0.mediaItems.map(\.relativePath).sorted()
        )
    }

    func dismissRevealedPhotoLog() {
        revealedPhotoLog = nil
    }

    func createPhotoLog(openAfterCreate: Bool) {
        guard let currentSession else { return }
        guard currentSession.sessionKind == .inbox else {
            statusMessage = "Photo logs can only be created from a source inbox."
            return
        }
        guard let editor = activePhotoLogEditor else { return }
        guard case .create = editor.mode else { return }
        guard let plan = proposedPhotoLogCreationPlan(mode: editor.creationMode) else { return }
        guard plan.canCreate else {
            statusMessage = plan.disabledReason ?? "This photo log cannot be created yet."
            return
        }

        let selectedIDs = Set(plan.candidateMediaItemIDs)
        let selectedItems = currentSession.mediaItems.filter { selectedIDs.contains($0.id) }
        let remainingItems = currentSession.mediaItems.filter { !selectedIDs.contains($0.id) }
        let draftGrouped = groupingService.group(items: selectedItems, settings: settings)
        let inboxGrouped = groupingService.group(items: remainingItems, settings: settings)
        let updatedMetadata = WalkMetadata(
            title: editor.title,
            location: editor.location,
            notes: editor.notes,
            backupConfirmedAt: nil
        )
        let draftTitle = editor.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Photo Log" : editor.title
        let draftSession = ImportSession(
            sourceFolder: currentSession.sourceFolder,
            workspaceSourceFolder: currentSession.workspaceSourceFolder,
            startedAt: Date(),
            lastUpdatedAt: Date(),
            walkMetadata: updatedMetadata,
            photoLogScope: photoLogScope(from: editor, fallback: plan.scope),
            archiveRoot: currentSession.archiveRoot,
            oneDrivePicturesRoot: currentSession.oneDrivePicturesRoot,
            archiveMachineRole: currentSession.archiveMachineRole,
            sessionKind: .walkDraft,
            status: "draft",
            mediaItems: draftGrouped.items,
            sourceProvenances: currentSession.sourceProvenances,
            proposedWalks: [],
            weekdayTokenStyle: settings.weekdayTokenStyle
        )

        var updatedInbox = currentSession
        updatedInbox.mediaItems = inboxGrouped.items
        updatedInbox.lastUpdatedAt = Date()
        updatedInbox.walkMetadata = .empty
        updatedInbox.photoLogScope = nil
        updatedInbox.sessionKind = .inbox
        updatedInbox.sessionKindWasExplicit = true
        updatedInbox.status = updatedInbox.mediaItems.isEmpty ? "inbox_empty" : "draft"

        do {
            try flushPendingSessionPersistenceOrThrow()
            try sessionStore.saveSessions([(draftSession, draftGrouped.burstGroups, draftGrouped.timeClusters),
                                          (updatedInbox, inboxGrouped.burstGroups, inboxGrouped.timeClusters)])
            storePersistedSession(draftSession, bursts: draftGrouped.burstGroups, clusters: draftGrouped.timeClusters)
            storePersistedSession(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters)
            invalidateInFlightSourceLoad()
            activePhotoLogEditor = nil
            if openAfterCreate {
                openPersistedSessionRecord(
                    (draftSession, draftGrouped.burstGroups, draftGrouped.timeClusters),
                    status: "Created and opened photo log \(draftTitle) with \(draftSession.mediaItems.count) decided photo(s)."
                )
                requestVisibleThumbnails(prefetching: draftSession.mediaItems)
            } else {
                openPersistedSessionRecord(
                    (updatedInbox, inboxGrouped.burstGroups, inboxGrouped.timeClusters),
                    status: "Created photo log \(draftTitle) with \(draftSession.mediaItems.count) decided photo(s); remaining photos stayed in the source inbox."
                )
                requestVisibleThumbnails(prefetching: updatedInbox.mediaItems)
            }
        } catch {
            logger.error("Failed to create photo log: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Failed to create photo log: \(error.localizedDescription)"
        }
    }

    func createWalkDraftFromCurrentSelection() {
        presentPhotoLogCreation()
        createPhotoLog(openAfterCreate: true)
    }

    func canAddCurrentSourceDecisions(to sessionID: UUID) -> Bool {
        do {
            return try sourceDecisionAppendPlan(for: sessionID).itemsToAdd.isEmpty == false
        } catch {
            return false
        }
    }

    func addCurrentSourceDecisions(to sessionID: UUID) {
        do {
            let appendPlan = try sourceDecisionAppendPlan(for: sessionID)
            guard appendPlan.itemsToAdd.isEmpty == false else {
                statusMessage = "Mark source photos with S, C, or X before adding them to this log."
                return
            }

            let selectedIDs = Set(appendPlan.itemsToAdd.map(\.id))
            var itemsToAdd = appendPlan.itemsToAdd
            for index in itemsToAdd.indices where itemsToAdd[index].selectionState.isIncluded && itemsToAdd[index].lifecycleState == .discovered {
                itemsToAdd[index].lifecycleState = try itemsToAdd[index].lifecycleState.transition(to: .selectedForImport)
            }

            var mergedItemsByPath: [String: MediaItem] = [:]
            for item in appendPlan.target.mediaItems where mergedItemsByPath[item.relativePath] == nil {
                mergedItemsByPath[item.relativePath] = item
            }
            for item in itemsToAdd where mergedItemsByPath[item.relativePath] == nil {
                mergedItemsByPath[item.relativePath] = item
            }

            let mergedItems = MediaItemSort.sorted(Array(mergedItemsByPath.values))
            let logGrouped = groupingService.group(items: mergedItems, settings: settings)
            let inboxItems = appendPlan.inbox.mediaItems.filter { !selectedIDs.contains($0.id) }
            let inboxGrouped = groupingService.group(items: inboxItems, settings: settings)

            var updatedLog = appendPlan.target
            updatedLog.mediaItems = logGrouped.items
            updatedLog.sourceProvenances = mergedSourceProvenances(appendPlan.target.sourceProvenances, appendPlan.inbox.sourceProvenances)
            updatedLog.lastUpdatedAt = Date()
            updatedLog.status = appendPlan.target.status

            var updatedInbox = appendPlan.inbox
            updatedInbox.mediaItems = inboxGrouped.items
            updatedInbox.lastUpdatedAt = Date()
            updatedInbox.walkMetadata = .empty
            updatedInbox.photoLogScope = nil
            updatedInbox.sessionKind = .inbox
            updatedInbox.sessionKindWasExplicit = true
            updatedInbox.status = inboxGrouped.items.isEmpty ? "inbox_empty" : "draft"

            try flushPendingSessionPersistenceOrThrow()
            try sessionStore.saveSessions([(updatedLog, logGrouped.burstGroups, logGrouped.timeClusters),
                                          (updatedInbox, inboxGrouped.burstGroups, inboxGrouped.timeClusters)])
            storePersistedSession(updatedLog, bursts: logGrouped.burstGroups, clusters: logGrouped.timeClusters)
            storePersistedSession(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters)
            invalidateInFlightSourceLoad()
            openPersistedSessionRecord(
                (updatedLog, logGrouped.burstGroups, logGrouped.timeClusters),
                status: "Added \(itemsToAdd.count) marked photo(s) to \(updatedLog.walkMetadata.title.nonEmpty ?? "Untitled Photo Log"). Copy any new S photos when ready."
            )
            requestVisibleThumbnails(prefetching: updatedLog.mediaItems)
        } catch {
            statusMessage = userFacingCopyFailureMessage(for: error)
        }
    }

    private func prepareSessionForCopy(_ session: ImportSession) throws -> ImportSession {
        var prepared = session.sessionKind == .inbox ? try createAutomaticPhotoLogForCopy(from: session) : session
        if let record = try recordedCopyPlan(for: prepared) {
            let original = record.originalSession ?? record.session
            guard prepared.proposedWalks.isEmpty || prepared.proposedWalks == original.proposedWalks else {
                throw ArchiveFileVerification.failure("Finish the recorded copy before changing its Walk or Trip targets.")
            }
            prepared.proposedWalks = original.proposedWalks
            prepared.weekdayTokenStyle = original.weekdayTokenStyle
        } else if prepared.confirmedCopyPending != true || prepared.proposedWalks.isEmpty {
            prepared.weekdayTokenStyle = settings.weekdayTokenStyle
            prepared.proposedWalks = walkBoundaryProposalService.proposedWalks(for: prepared, timeClusters: timeClusters)
        }
        if prepared.proposedWalks.isEmpty {
            throw CopyPreparationError.cannotCreateAutomaticLog("Mark photos with S before copying. The app needs at least one proposed Walk.")
        }
        return prepared
    }

    private var cachedCopyRecords: [URL: (modified: Date?, size: Int?, record: ImportRecoveryRecord)] = [:]

    private func hasRecordedCopy(_ session: ImportSession) -> Bool {
        if session.confirmedCopyPending == true { return true }
        do { return try recordedCopyPlan(for: session) != nil } catch { return true }
    }

    @discardableResult private func allowEditingCopyInputs(_ session: ImportSession) -> Bool {
        guard !hasRecordedCopy(session) else {
            statusMessage = "Finish the recorded Copy before editing this photo log. You can open a separate Source for new Triage."
            return false
        }
        return true
    }

    private func recordedCopyPlan(for session: ImportSession) throws -> ImportRecoveryRecord? {
        let recovery = ArchiveOperationRecovery(archiveRoot: session.archiveRoot)
        let url = recovery.url(kind: "import", sessionID: session.id)
        guard fileManager.fileExists(atPath: url.path) else {
            if cachedCopyRecords[url]?.record.complete == false {
                throw ArchiveFileVerification.failure("The recorded Copy is unavailable. Reconnect the Archive before editing or retrying.")
            }
            if session.confirmedCopyPending == true {
                // The directory read distinguishes an accessible unstarted plan from unavailable storage.
                _ = try fileManager.contentsOfDirectory(at: session.archiveRoot, includingPropertiesForKeys: nil)
                if fileManager.fileExists(atPath: recovery.root.path) {
                    _ = try fileManager.contentsOfDirectory(at: recovery.root, includingPropertiesForKeys: nil)
                }
            }
            return nil
        }
        let attributes = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let record: ImportRecoveryRecord
        if let cached = cachedCopyRecords[url], cached.modified == attributes.contentModificationDate, cached.size == attributes.fileSize {
            record = cached.record
        } else {
            guard let loaded = try recovery.load(ImportRecoveryRecord.self, kind: "import", sessionID: session.id) else { return nil }
            record = loaded
            cachedCopyRecords[url] = (attributes.contentModificationDate, attributes.fileSize, loaded)
        }
        let pending = Set(session.mediaItems.filter { $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond }.map(\.id))
        return !record.complete || !record.mediaItemIDs.isDisjoint(with: pending) ? record : nil
    }

    private func sourceDecisionAppendPlan(for sessionID: UUID) throws -> (target: ImportSession, inbox: ImportSession, itemsToAdd: [MediaItem]) {
        guard let inbox = currentSession, inbox.sessionKind == .inbox else {
            throw CopyPreparationError.cannotCreateAutomaticLog("Open the source inbox before adding marked photos to an existing log.")
        }
        guard let target = persistedSessions.first(where: { $0.0.id == sessionID && $0.0.sessionKind == .walkDraft })?.0 else {
            throw CopyPreparationError.cannotCreateAutomaticLog("Photo log could not be found in the local library.")
        }
        guard !hasRecordedCopy(target) else { throw ArchiveFileVerification.failure("Finish the recorded Copy before adding photos to this log.") }
        guard target.status != LifecycleState.sourceCleaned.rawValue else {
            throw CopyPreparationError.cannotCreateAutomaticLog("Source-cleaned logs cannot accept more photos.")
        }
        guard target.workspaceSourceFolder.standardizedFileURL.path == inbox.workspaceSourceFolder.standardizedFileURL.path else {
            throw CopyPreparationError.cannotCreateAutomaticLog("This photo log belongs to a different source folder.")
        }
        guard let plan = proposedPhotoLogCreationPlan(mode: .decidedInScope) else {
            throw CopyPreparationError.cannotCreateAutomaticLog("Select a source folder or review area before adding marked photos to this log.")
        }

        let plannedIDs = Set(plan.candidateMediaItemIDs)
        let targetPaths = Set(target.mediaItems.map(\.relativePath))
        let otherOwnedPaths = Set(persistedSessions
            .map(\.0)
            .filter {
                $0.id != target.id &&
                $0.sessionKind == .walkDraft &&
                $0.workspaceSourceFolder.standardizedFileURL.path == inbox.workspaceSourceFolder.standardizedFileURL.path
            }
            .flatMap { $0.mediaItems.map(\.relativePath) })

        let itemsToAdd = inbox.mediaItems.filter {
            plannedIDs.contains($0.id) &&
            !$0.lifecycleState.isImportedOrBeyond &&
            !targetPaths.contains($0.relativePath) &&
            !otherOwnedPaths.contains($0.relativePath)
        }
        return (target, inbox, itemsToAdd)
    }

    private func createAutomaticPhotoLogForCopy(from inbox: ImportSession) throws -> ImportSession {
        guard let plan = proposedPhotoLogCreationPlan(mode: .decidedInScope) else {
            throw CopyPreparationError.cannotCreateAutomaticLog("Select a source folder or review area before copying. The app needs that scope to create the photo log.")
        }
        guard plan.canCreate else {
            throw CopyPreparationError.cannotCreateAutomaticLog(plan.disabledReason ?? "This selection cannot become a photo log yet.")
        }

        let plannedIDs = Set(plan.candidateMediaItemIDs)
        let selectedIDs = Set(inbox.mediaItems.filter {
            plannedIDs.contains($0.id) && !$0.lifecycleState.isImportedOrBeyond
        }.map(\.id))
        guard !selectedIDs.isEmpty else {
            throw CopyPreparationError.cannotCreateAutomaticLog("These photos already belong to copied logs. Start a new source selection or open the existing log.")
        }

        var selectedItems = inbox.mediaItems.filter { selectedIDs.contains($0.id) }
        for index in selectedItems.indices where selectedItems[index].selectionState.isIncluded && selectedItems[index].lifecycleState == .discovered {
            selectedItems[index].lifecycleState = try selectedItems[index].lifecycleState.transition(to: .selectedForImport)
        }

        let remainingItems = inbox.mediaItems.filter { !selectedIDs.contains($0.id) }
        let draftGrouped = groupingService.group(items: selectedItems, settings: settings)
        let inboxGrouped = groupingService.group(items: remainingItems, settings: settings)
        let autoTitle = inbox.sourceProvenances.contains(where: { $0.historical != nil }) ? (inbox.walkMetadata.title.nonEmpty ?? automaticPhotoLogTitle(for: selectedItems)) : automaticPhotoLogTitle(for: selectedItems)
        let metadata = WalkMetadata(
            title: autoTitle,
            location: inbox.walkMetadata.location,
            notes: inbox.walkMetadata.notes,
            backupConfirmedAt: nil
        )
        let draftSession = ImportSession(
            sourceFolder: inbox.sourceFolder,
            workspaceSourceFolder: inbox.workspaceSourceFolder,
            startedAt: Date(),
            lastUpdatedAt: Date(),
            walkMetadata: metadata,
            photoLogScope: PhotoLogScopeDescriptor(
                kind: plan.scope.kind,
                label: autoTitle,
                sourceFolderPaths: plan.scope.sourceFolderPaths,
                startDate: plan.scope.startDate,
                endDate: plan.scope.endDate
            ),
            archiveRoot: inbox.archiveRoot,
            oneDrivePicturesRoot: inbox.oneDrivePicturesRoot,
            archiveMachineRole: inbox.archiveMachineRole,
            sessionKind: .walkDraft,
            status: "draft",
            mediaItems: draftGrouped.items,
            sourceProvenances: inbox.sourceProvenances,
            proposedWalks: [],
            weekdayTokenStyle: settings.weekdayTokenStyle
        )

        var updatedInbox = inbox
        updatedInbox.mediaItems = inboxGrouped.items
        updatedInbox.lastUpdatedAt = Date()
        updatedInbox.walkMetadata = .empty
        updatedInbox.photoLogScope = nil
        updatedInbox.sessionKind = .inbox
        updatedInbox.sessionKindWasExplicit = true
        updatedInbox.status = updatedInbox.mediaItems.isEmpty ? "inbox_empty" : "draft"

        try flushPendingSessionPersistenceOrThrow()
        try sessionStore.saveSessions([(draftSession, draftGrouped.burstGroups, draftGrouped.timeClusters),
                                      (updatedInbox, inboxGrouped.burstGroups, inboxGrouped.timeClusters)])
        storePersistedSession(draftSession, bursts: draftGrouped.burstGroups, clusters: draftGrouped.timeClusters)
        storePersistedSession(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters)
        invalidateInFlightSourceLoad()
        openPersistedSessionRecord(
            (draftSession, draftGrouped.burstGroups, draftGrouped.timeClusters),
            status: "Created photo log \(autoTitle) and started copying \(draftSession.mediaItems.filter { $0.selectionState.isIncluded }.count) S photo(s)."
        )
        requestVisibleThumbnails(prefetching: draftSession.mediaItems)
        return draftSession
    }

    private func automaticPhotoLogTitle(for items: [MediaItem]) -> String {
        let date = items.compactMap(\.capturedAt).min() ?? Date()
        return DateFormatting.automaticPhotoLogTitle.string(from: date)
    }

    func saveActivePhotoLogEdits() {
        guard let editor = activePhotoLogEditor else { return }
        guard case .edit(let sessionID) = editor.mode else { return }
        guard let record = persistedSessions.first(where: { $0.0.id == sessionID }) else {
            statusMessage = "Photo log could not be found in the local library."
            activePhotoLogEditor = nil
            return
        }

        guard allowEditingCopyInputs(record.0) else { return }
        var updatedSession = record.0
        updatedSession.lastUpdatedAt = Date()
        updatedSession.walkMetadata.title = editor.title
        updatedSession.walkMetadata.location = editor.location
        updatedSession.walkMetadata.notes = editor.notes
        updatedSession.photoLogScope = photoLogScope(from: editor, fallback: defaultPhotoLogScope(for: updatedSession))

        do {
            try flushPendingSessionPersistenceOrThrow()
            try sessionManager.save(updatedSession, bursts: record.1, clusters: record.2, to: sessionStore)
            storePersistedSession(updatedSession, bursts: record.1, clusters: record.2)
            if currentSession?.id == sessionID {
                setCurrentSession(updatedSession, updateKind: .sessionOnly)
            }
            activePhotoLogEditor = nil
            statusMessage = "Updated photo log \(updatedSession.walkMetadata.title.nonEmpty ?? "Untitled Photo Log")."
        } catch {
            logger.error("Failed to update photo log: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Failed to update photo log: \(error.localizedDescription)"
        }
    }

    func deletePhotoLog(_ sessionID: UUID) {
        guard let logRecord = persistedSessions.first(where: { $0.0.id == sessionID && $0.0.sessionKind == .walkDraft }) else {
            statusMessage = "Photo log could not be found in the local library."
            return
        }

        guard allowEditingCopyInputs(logRecord.0) else { return }
        let returnableItems = logRecord.0.mediaItems.filter { !$0.lifecycleState.isImportedOrBeyond }
        let updatedInboxRecord = rebuildInboxAfterDeletingPhotoLog(logRecord.0, returning: returnableItems)
        var updatedRecords = persistedSessions.filter { $0.0.id != sessionID && $0.0.id != updatedInboxRecord.0.id }
        updatedRecords.append(updatedInboxRecord)
        updatedRecords.sort { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }

        do {
            try flushPendingSessionPersistenceOrThrow()
            try sessionStore.replaceAllSessions(with: updatedRecords)
            persistedSessions = updatedRecords
            activePhotoLogEditor = nil

            if currentSession?.id == sessionID || currentSession?.id == updatedInboxRecord.0.id {
                openPersistedSessionRecord(
                    updatedInboxRecord,
                    status: "Deleted photo log \(logRecord.0.walkMetadata.title.nonEmpty ?? "Untitled Photo Log") and returned \(returnableItems.count) photo(s) to the inbox."
                )
                requestVisibleThumbnails(prefetching: updatedInboxRecord.0.mediaItems)
            } else {
                refreshSidebarState()
                statusMessage = "Deleted photo log \(logRecord.0.walkMetadata.title.nonEmpty ?? "Untitled Photo Log")."
            }
        } catch {
            logger.error("Failed to delete photo log: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Failed to delete photo log: \(error.localizedDescription)"
        }
    }

    func performInitialAutoLoadIfNeeded() {
        guard hasAttemptedInitialAutoLoad == false else { return }
        hasAttemptedInitialAutoLoad = true

        Task {
            await selectInitialWorkspace()
        }
    }

    func updateWalkMetadata(title: String, location: String, notes: String, sessionID: UUID? = nil) {
        guard let currentSession, sessionID == nil || currentSession.id == sessionID else { return }
        guard save(sessionMutationCoordinator.sessionByUpdatingWalkMetadata(currentSession, title: title, location: location, notes: notes)) else { return }
        refreshArchiveIndexAfterMetadataEditIfNeeded()
    }

    var locationAssignmentContext: LocationAssignmentContext? {
        if workspaceMode == .archiveView || isBrowsingArchive {
            guard let node = selectedBrowserNode, let folder = node.folderURL,
                  let path = ArchiveIndexStore.archiveRelativePath(for: folder, archiveRoot: settings.archiveRoot),
                  let walk = archiveLocationWalksByPath[path] else { return nil }
            var target = ArchiveLocationTarget(walkRelativePath: path, sessionID: walk.sessionID, walkID: walk.walkID)
            var overrides: [PhotoLocationOverride?] = []
            let photosByPath = archiveLocationPhotosByPath
            for id in selectedMediaItemIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                guard let item = mediaItem(for: id), let itemPath = item.archiveRelativePath,
                      let photo = photosByPath[itemPath], photo.walkPath == path, !photo.isDerivedPhoto,
                      photo.cropRole != .crop, photo.mediaItemID == id else { return nil }
                target.photos.append(ArchiveLocationPhotoTarget(mediaItemID: id, archiveRelativePath: itemPath))
                overrides.append(photo.locationOverride)
            }
            let first = overrides.first ?? nil
            let mixed = overrides.contains { $0?.name != first?.name || $0?.coordinate != first?.coordinate }
            let isWalk = target.photos.isEmpty
            return LocationAssignmentContext(key: settings.archiveRoot.path + "|" + target.key,
                title: isWalk ? "This Walk" : (target.photos.count == 1 ? "Selected photo" : "\(target.photos.count) selected photos"),
                origin: .archive(target), archiveRoot: settings.archiveRoot,
                name: isWalk ? (walk.location ?? "") : (mixed ? "" : first?.name ?? ""),
                coordinate: isWalk ? ArchiveCoordinate(latitude: walk.latitude, longitude: walk.longitude) : (mixed ? nil : first?.coordinate),
                isMixed: mixed, hasSavedAssignment: isWalk ? walk.location != nil || ArchiveCoordinate(latitude: walk.latitude, longitude: walk.longitude) != nil : overrides.contains { $0 != nil })
        }
        guard canAssignWalkLocation, let session = currentSession else { return nil }
        return LocationAssignmentContext(key: "source|" + session.id.uuidString, title: "This Walk",
            origin: .sourceWalk(session.id), archiveRoot: session.archiveRoot, name: session.walkMetadata.location,
            coordinate: ArchiveCoordinate(latitude: session.walkMetadata.latitude, longitude: session.walkMetadata.longitude),
            isMixed: false, hasSavedAssignment: session.walkMetadata.location.nonEmpty != nil || currentWalkCoordinate != nil)
    }

    var locationAssignmentKey: String {
        locationAssignmentContext?.key ?? "readonly|\(selectedBrowserNode?.id ?? "")|\(selectedMediaItemIDs.map(\.uuidString).sorted().joined(separator: ","))"
    }

    var canRetryArchiveLocationSave: Bool {
        guard case .archive(let target) = locationAssignmentContext?.origin else { return false }
        return archiveLocationRecoveryWalkPath == target.walkRelativePath
    }

    func saveContextLocation(name: String, latitude: Double?, longitude: Double?, context captured: LocationAssignmentContext? = nil) async {
        guard !isSavingLocation, let context = captured ?? locationAssignmentContext else { return }
        let coordinate = ArchiveCoordinate(latitude: latitude, longitude: longitude)
        guard (latitude == nil && longitude == nil) || coordinate != nil,
              !name.contains("\n"), !name.contains("\r") else {
            statusMessage = "Use a single-line location name and a complete, valid coordinate pair."; return
        }
        switch context.origin {
        case .sourceWalk(let id):
            guard currentSession?.id == id, canAssignWalkLocation else { return }
            setCurrentWalkLocation(name: name, latitude: coordinate?.latitude, longitude: coordinate?.longitude)
        case .archive(let target):
            guard context.archiveRoot.standardizedFileURL == settings.archiveRoot.standardizedFileURL else { return }
            isSavingLocation = true
            defer { isSavingLocation = false }
            let root = context.archiveRoot
            do {
                let result = try await ArchiveIndexMutationQueue.shared.saveLocation(target: target, name: name, coordinate: coordinate, archiveRoot: root)
                guard root.standardizedFileURL == self.settings.archiveRoot.standardizedFileURL else { return }
                archiveLocationRecoveryWalkPath = nil
                applyArchiveLocationResult(result)
            } catch {
                guard root.standardizedFileURL == self.settings.archiveRoot.standardizedFileURL else { return }
                archiveLocationRecoveryWalkPath = (try? ArchiveLocationEditor().pending(for: target.walkRelativePath, archiveRoot: root))?.target.walkRelativePath
                statusMessage = "Location save failed: \(error.localizedDescription)"
            }
        }
    }

    func retryArchiveLocationSave(context captured: LocationAssignmentContext? = nil) async {
        guard !isSavingLocation, let context = captured ?? locationAssignmentContext,
              context.archiveRoot.standardizedFileURL == settings.archiveRoot.standardizedFileURL,
              case .archive(let target) = context.origin else { return }
        isSavingLocation = true
        defer { isSavingLocation = false }
        let root = settings.archiveRoot
        do {
            let result = try await ArchiveIndexMutationQueue.shared.resumeLocation(walkRelativePath: target.walkRelativePath, archiveRoot: root)
            guard root.standardizedFileURL == self.settings.archiveRoot.standardizedFileURL else { return }
            archiveLocationRecoveryWalkPath = nil
            applyArchiveLocationResult(result)
        } catch { statusMessage = "Location recovery failed: \(error.localizedDescription)" }
    }

    private func applyArchiveLocationResult(_ result: ArchiveLocationSaveResult) {
        archiveCatalogueLoadTask?.cancel()
        archiveCatalogueLoadTask = nil
        archiveCatalogueLoadGeneration &+= 1
        archiveCatalogueIsLoading = false
        archiveCatalogue = ArchiveLocationProjection.applying(result, to: archiveCatalogue)
        let photos = Dictionary(uniqueKeysWithValues: archiveCatalogue.photos.map { ($0.archiveRelativePath, $0) })
        for key in Array(archiveMediaCache.keys) {
            guard var items = archiveMediaCache[key] else { continue }
            for index in items.indices {
                guard let path = items[index].archiveRelativePath, let photo = photos[path],
                      photo.walkPath == result.target.walkRelativePath else { continue }
                items[index].metadata.latitude = photo.latitude
                items[index].metadata.longitude = photo.longitude
            }
            archiveMediaCache[key] = items
        }
        refreshAllUIState()
        statusMessage = result.target.photos.isEmpty ? "Saved Walk location." : "Saved location for \(result.target.photos.count) selected photos."
        if canWriteArchiveIndex {
            refreshArchiveIndexAfterWalkFolders([archiveURL(for: result.target.walkRelativePath)], statusPrefix: "Archive Index refreshed for updated locations")
        } else {
            statusMessage += " The travel view is updated; the main Mac will publish the index after rebuilding."
        }
    }

    var hasHistoricalSources: Bool { currentSession?.sourceProvenances.contains { $0.historical != nil } == true }

    var historicalDateSummary: String {
        let evidence = currentSession?.mediaItems.compactMap(\.captureDateEvidence) ?? []
        let conflicts = evidence.filter(\.conflictsWithFolder).count
        let partial = evidence.filter { $0.precision == .month || $0.precision == .year }.count
        return "Historical source · \(conflicts) camera/folder conflicts · \(partial) partial dates"
    }

    var prefersHistoricalFolderDates: Bool {
        currentSession?.sourceProvenances.compactMap(\.historical).contains { $0.datePreference == .folder } == true
    }

    func toggleHistoricalFolderDates() {
        guard var session = currentSession, hasHistoricalSources, !importOperation.isRunning else { return }
        do { guard try recordedCopyPlan(for: session) == nil else {
            statusMessage = "Finish the recorded Copy before changing its date preference."; return
        } } catch { statusMessage = error.localizedDescription; return }
        let preference: HistoricalDatePreference = prefersHistoricalFolderDates ? .camera : .folder
        for index in session.sourceProvenances.indices where session.sourceProvenances[index].historical != nil {
            session.sourceProvenances[index].historical!.datePreference = preference
        }
        for index in session.mediaItems.indices where !session.mediaItems[index].lifecycleState.isImportedOrBeyond {
            if let context = HistoricalSourceSafety.context(for: session.mediaItems[index].sourceURL, in: session) {
                session.mediaItems[index] = HistoricalSourceHints.applying(to: session.mediaItems[index], context: context)
            }
        }
        session.proposedWalks = []
        let grouped = groupingService.group(items: session.mediaItems, settings: settings)
        session.mediaItems = grouped.items
        burstGroups = grouped.burstGroups; timeClusters = grouped.timeClusters
        _ = save(session, updateKind: .full)
        statusMessage = preference == .folder ? "Using recorded folder date hints; camera dates remain in provenance." : "Using valid camera dates, with folder/file-date fallback."
    }

    var currentWalkLocationName: String {
        currentSession?.walkMetadata.location ?? ""
    }

    var currentWalkCoordinate: (latitude: Double, longitude: Double)? {
        guard let latitude = currentSession?.walkMetadata.latitude,
              let longitude = currentSession?.walkMetadata.longitude else { return nil }
        return (latitude, longitude)
    }

    var canAssignWalkLocation: Bool {
        currentSession != nil && canMutateImportSelection
    }

    func setCurrentWalkLocation(name: String, latitude: Double?, longitude: Double?) {
        guard let currentSession else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard save(sessionMutationCoordinator.sessionBySettingWalkLocation(
            currentSession,
            location: trimmed,
            latitude: latitude,
            longitude: longitude
        )) else { return }
        refreshArchiveIndexAfterMetadataEditIfNeeded()
        statusMessage = trimmed.isEmpty ? "Cleared walk location." : "Saved walk location: \(trimmed)."
    }

    func updateWalkDetailsExpansion(for session: ImportSession?) {
        isWalkDetailsExpanded = sessionMutationCoordinator.walkDetailsShouldExpand(for: session)
    }

    func setImportRawCompanions(for item: MediaItem, enabled: Bool) {
        guard let currentSession else { return }
        var updated = sessionMutationCoordinator.sessionBySettingImportRawCompanions(currentSession, for: item.id, enabled: enabled)
        updated.proposedWalks = []
        save(updated)
    }

    func markBackupConfirmed() {
        guard let currentSession else { return }
        save(sessionMutationCoordinator.sessionByMarkingBackupConfirmed(currentSession))
    }

    func openArchiveDestinationForCurrentSession() {
        guard let url = currentCopiedArchiveDestinationURL else {
            statusMessage = "No copied archive folder is available for this log yet."
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            statusMessage = "Archive folder is not available at \(url.path)."
            return
        }

        if NSWorkspace.shared.open(url) {
            statusMessage = "Opened archive folder \(url.path)."
        } else {
            statusMessage = "Could not open archive folder \(url.path)."
        }
    }

    func openSelectedBrowserFolder() {
        guard let url = selectedBrowserFolderURL else {
            statusMessage = "No folder is selected in the browser."
            return
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            statusMessage = "Folder is not available at \(url.path)."
            return
        }

        if NSWorkspace.shared.open(url) {
            statusMessage = "Opened \(url.path) in Finder."
        } else {
            statusMessage = "Could not open \(url.path) in Finder."
        }
    }

    func moveArchiveWalkToTrip(_ node: BrowserNode) {
        guard node.kind == .archiveWalkFolder, let walkFolder = node.folderURL else {
            statusMessage = "Select an archived Walk before moving it to a Trip."
            return
        }
        let yearURL = walkFolder.deletingLastPathComponent().deletingLastPathComponent()
        let year = yearURL.lastPathComponent
        let trips = tripLibraryScanner.namedTrips(in: settings.archiveRoot, year: year)

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 26), pullsDown: false)
        popup.addItem(withTitle: "New Trip...")
        for trip in trips {
            popup.addItem(withTitle: trip.folder.lastPathComponent)
        }
        let titleField = NSTextField(frame: NSRect(x: 0, y: 34, width: 360, height: 24))
        titleField.placeholderString = "New Trip title"
        titleField.stringValue = walkFolder.deletingLastPathComponent().lastPathComponent
            .replacingOccurrences(of: #"^\d\d-[^-]+-"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "-", with: " ")
        let stack = NSStackView(views: [popup, titleField])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 380, height: 70)

        let alert = NSAlert()
        alert.messageText = "Move Walk to Trip"
        alert.informativeText = "Choose an existing named Trip in \(year), or create a new named Trip beside the current month folder."
        alert.accessoryView = stack
        alert.addButton(withTitle: "Move")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let targetTripFolder: URL
        if popup.indexOfSelectedItem == 0 {
            let title = titleField.stringValue.nonEmpty ?? "Trip"
            let date = dateForArchiveWalkFolder(walkFolder) ?? Date()
            targetTripFolder = yearURL.appendingPathComponent(DateFormatting.archiveTripFolderName(from: date, tripTitle: title), isDirectory: true)
        } else {
            targetTripFolder = trips[popup.indexOfSelectedItem - 1].folder
        }

        let oldWalkRelativePath = ArchiveIndexStore.archiveRelativePath(for: walkFolder, archiveRoot: settings.archiveRoot)
        let sourceTripFolder = walkFolder.deletingLastPathComponent()
        do {
            guard importProgress == nil else {
                statusMessage = "Finish importing before moving an archived Walk."; return
            }
            try flushPendingSessionPersistenceOrThrow()
            let result = try walkMover.moveWalk(at: walkFolder, to: targetTripFolder, oneDrivePicturesRoot: settings.oneDrivePicturesRoot, archiveRoot: settings.archiveRoot)
            try reconcileSavedArchivePaths(syncChangedLogs: true)
            refreshArchiveIndexAfterWalkMove(
                destinationWalkFolder: result.destinationFolder,
                removingWalkPath: oldWalkRelativePath,
                tripFolders: [sourceTripFolder, targetTripFolder]
            )
            archiveMediaCache.removeAll()
            browserViewModel.invalidateArchiveTreeCache()
            rebuildBrowserCaches()
            selectedSidebarNodeID = "archive-walk-\(result.destinationFolder.path)"
            statusMessage = "Moved \(result.destinationFolder.lastPathComponent) to \(targetTripFolder.lastPathComponent)."
        } catch {
            statusMessage = "Could not move Walk: \(error.localizedDescription)"
        }
    }

    var canMoveSelectedArchiveWalkToTrip: Bool {
        selectedArchiveWalkNodeForMove != nil
    }

    func moveSelectedArchiveWalkToTrip() {
        guard let node = selectedArchiveWalkNodeForMove else {
            statusMessage = "Select an archived Walk before moving it to a Trip."
            return
        }
        moveArchiveWalkToTrip(node)
    }

    private var selectedArchiveWalkNodeForMove: BrowserNode? {
        let folderNode = activePane == .folders && selectedFolderNodeIDs.count == 1
            ? selectedFolderNodeIDs.first.flatMap { browserNodeMap[$0] }
            : nil
        let node = folderNode ?? selectedBrowserNode
        guard node?.kind == .archiveWalkFolder, node?.folderURL != nil else { return nil }
        return node
    }

    private func dateForArchiveWalkFolder(_ walkFolder: URL) -> Date? {
        let year = walkFolder.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        let monthFolder = walkFolder.deletingLastPathComponent().lastPathComponent
        let walk = walkFolder.lastPathComponent
        let month = String(monthFolder.prefix(2))
        let day = String(walk.prefix(2))
        return DateFormatting.archiveFormatterForParsing.date(from: "\(year)-\(month)-\(day)")
    }

    func commitImport() {
        guard let session = currentSession else { return }
        guard canCommitImport else { return }
        invalidateInFlightSourceLoad()
        do {
            let preparedSession = try prepareSessionForCopy(session)
            presentWalkCommitEditor(for: preparedSession)
        } catch {
            let message = userFacingCopyFailureMessage(for: error)
            importProgress = nil
            importOperation = ImportOperationSnapshot(
                phase: .failed,
                title: "Copy failed",
                detail: message,
                progress: nil,
                destinationPath: importReadinessSnapshot(for: session)?.destinationPath
            )
            statusMessage = message
        }
    }

    func dismissWalkCommitEditor() {
        activeWalkCommitEditor = nil
        clearCurrentSessionProposedWalks()
    }

    private func clearCurrentSessionProposedWalks() {
        guard var session = currentSession, !session.proposedWalks.isEmpty else { return }
        guard session.confirmedCopyPending != true else { return }
        do { if try recordedCopyPlan(for: session) != nil { return } }
        catch { statusMessage = "Copy recovery could not be read: \(error.localizedDescription)"; return }
        session.proposedWalks = []
        setCurrentSession(session, updateKind: .sessionOnly)
    }

    func updateWalkCommitEditor(_ editor: WalkCommitEditorState) {
        if let current = activeWalkCommitEditor, current.isRecoveryPlan, current.walks != editor.walks {
            statusMessage = "The recorded recovery targets are fixed until copying finishes."; return
        }
        activeWalkCommitEditor = editor
    }

    func confirmWalkCommit() {
        guard let editor = activeWalkCommitEditor, var session = currentSession else { return }
        session.proposedWalks = editor.walks
        session.confirmedCopyPending = true
        if !editor.isRecoveryPlan { session.weekdayTokenStyle = settings.weekdayTokenStyle }
        // The confirmed plan must be durable before the importer can copy its first file.
        do {
            flushPendingSessionPersistence()
            try flushPendingSessionPersistenceOrThrow()
            try sessionManager.save(session, bursts: burstGroups, clusters: timeClusters, to: sessionStore)
            storePersistedSession(session, bursts: burstGroups, clusters: timeClusters)
        } catch { statusMessage = "Could not save the confirmed Copy plan: \(error.localizedDescription)"; return }
        activeWalkCommitEditor = nil
        setCurrentSession(session, updateKind: .sessionOnly)
        performConfirmedImport(session)
    }

    func mergeWalkProposalWithPrevious(_ walkID: UUID) {
        guard var editor = activeWalkCommitEditor, !editor.isRecoveryPlan,
              let index = editor.walks.firstIndex(where: { $0.id == walkID }),
              index > 0 else { return }
        var previous = editor.walks[index - 1]
        let current = editor.walks[index]
        previous.mediaItemIDs.append(contentsOf: current.mediaItemIDs)
        var seenMediaIDs: Set<UUID> = []
        previous.mediaItemIDs = previous.mediaItemIDs.filter { seenMediaIDs.insert($0).inserted }
        previous.sourceProvenanceIDs.append(contentsOf: current.sourceProvenanceIDs)
        previous.sourceProvenanceIDs = Array(Set(previous.sourceProvenanceIDs)).sorted { $0.uuidString < $1.uuidString }
        editor.walks[index - 1] = previous
        editor.walks.remove(at: index)
        activeWalkCommitEditor = editor
    }

    func splitWalkProposal(_ walkID: UUID) {
        guard var editor = activeWalkCommitEditor, !editor.isRecoveryPlan,
              let index = editor.walks.firstIndex(where: { $0.id == walkID }) else { return }
        let walk = editor.walks[index]
        guard walk.mediaItemIDs.count > 1 else { return }
        let splitIndex = walk.mediaItemIDs.count / 2
        var first = walk
        var second = walk
        first.mediaItemIDs = Array(walk.mediaItemIDs.prefix(splitIndex))
        second = Walk(
            title: "\(walk.title) 2",
            date: walk.date,
            sourceProvenanceIDs: walk.sourceProvenanceIDs,
            mediaItemIDs: Array(walk.mediaItemIDs.suffix(from: splitIndex)),
            tripTarget: walk.tripTarget,
            location: walk.location,
            latitude: walk.latitude,
            longitude: walk.longitude
        )
        editor.walks[index] = first
        editor.walks.insert(second, at: index + 1)
        activeWalkCommitEditor = editor
    }

    private func presentWalkCommitEditor(for preparedSession: ImportSession) {
        setCurrentSession(preparedSession, updateKind: .sessionOnly)
        let years = Set(preparedSession.proposedWalks.map { DateFormatting.archiveYearFolderName(from: $0.date) })
        let existingTrips = years.isEmpty
            ? tripLibraryScanner.namedTrips(in: settings.archiveRoot)
            : years.flatMap { tripLibraryScanner.namedTrips(in: settings.archiveRoot, year: $0) }
                .sorted { $0.folderRelativePath < $1.folderRelativePath }
        activeWalkCommitEditor = WalkCommitEditorState(
            id: UUID(),
            walks: preparedSession.proposedWalks,
            existingTrips: existingTrips,
            tripDisplayLabel: settings.tripDisplayLabel,
            walkDisplayLabel: settings.walkDisplayLabel,
            isRecoveryPlan: preparedSession.confirmedCopyPending == true || (try? recordedCopyPlan(for: preparedSession)) != nil
        )
    }

    private func performConfirmedImport(_ preparedSession: ImportSession) {
        let readiness = importReadinessSnapshot(for: preparedSession)
        let destinationPath = readiness?.destinationPath

        Task {
            do {
                let initialProgress = ImportProgress(current: 0, total: readiness?.totalFiles ?? ImportProgress.expectedTotalEntries(for: preparedSession))
                importProgress = initialProgress
                importOperation = ImportOperationSnapshot(
                    phase: .copying,
                    title: "Copying to archive",
                    detail: "Copied 0 of \(initialProgress.total) file(s).",
                    progress: initialProgress,
                    destinationPath: destinationPath
                )
                statusMessage = "Copying marked files into archive..."
                let result = try await importWorkflow.commit(session: preparedSession) { [weak self] progress in
                    guard let self else { return }
                    self.importProgress = progress
                    if let progress {
                        self.importOperation = ImportOperationSnapshot(
                            phase: .copying,
                            title: "Copying to archive",
                            detail: "Copied \(progress.current) of \(progress.total) file(s).",
                            progress: progress,
                            destinationPath: destinationPath
                        )
                        self.statusMessage = "Importing \(progress.current)/\(progress.total)..."
                    }
                }
                setCurrentSession(result.session, updateKind: .sessionOnly)
                persistCurrentSession(immediately: true)
                do {
                    let syncURL = try photoLogSyncStore.export(
                        session: result.session,
                        bursts: burstGroups,
                        timeClusters: timeClusters,
                        to: settings.oneDrivePicturesRoot
                    )
                    statusMessage = "Imported \(result.fileManifests.count) marked items and synced log state to \(syncURL.lastPathComponent)."
                } catch {
                    statusMessage = "Copied files, but OneDrive log state sync failed: \(error.localizedDescription)"
                }
                importProgress = nil
                importOperation = ImportOperationSnapshot(
                    phase: .completed,
                    title: "Copy complete",
                    detail: "Copied and verified \(result.fileManifests.count) photo(s) into \(result.walkManifests.count) Walk(s). Manifests were written.",
                    progress: nil,
                    destinationPath: result.walkManifest.archiveFolder.path
                )
                archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
                browserViewModel.invalidateArchiveTreeCache()
                scheduleArchiveIndexUpdate(after: result)
            } catch {
                if var failed = currentSession, failed.id == preparedSession.id,
                   let contents = try? fileManager.contentsOfDirectory(at: ArchiveOperationRecovery(archiveRoot: failed.archiveRoot).root, includingPropertiesForKeys: nil),
                   !contents.contains(where: { $0.lastPathComponent == "import-\(failed.id.uuidString).json" }) {
                    failed.confirmedCopyPending = nil
                    setCurrentSession(failed, updateKind: .sessionOnly)
                    persistCurrentSession(immediately: true)
                }
                let message = userFacingCopyFailureMessage(for: error)
                importProgress = nil
                importOperation = ImportOperationSnapshot(
                    phase: .failed,
                    title: "Copy failed",
                    detail: message,
                    progress: nil,
                    destinationPath: destinationPath
                )
                statusMessage = message
            }
        }
    }

    func cleanupImportedSources() {
        guard let session = currentSession, canCleanupImportedSources else { return }
        let pending = session.mediaItems.filter { $0.lifecycleState == .sourceCleanupPending && !($0.cropRelationship?.role == .original && $0.cropRelationship?.hasCrops == true) }
        guard !pending.isEmpty else { statusMessage = "Originals with crops are retained."; return }
        let count = pending.reduce(0) { $0 + 1 + ($1.importRawCompanions ? $1.companionFiles.count : 0) }
        let alert = NSAlert()
        alert.messageText = "Remove \(count) verified copied source file(s)?"
        alert.informativeText = "Walkfolio will recheck every archived copy before deleting only these imported originals/RAW companions. Uncopied files and source folders remain. Backup confirmation is required."
        alert.addButton(withTitle: "Remove copied sources")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        startConfirmedSourceCleanup(session)
    }

    func startConfirmedSourceCleanup(_ session: ImportSession) {
        guard !sourceCleanupIsRunning, backupPersistenceGate.blockedReason == nil else { return }
        sourceCleanupIsRunning = true
        let generation = restoredStateGeneration
        Task {
            defer { sourceCleanupIsRunning = false }
            do {
                statusMessage = "Verifying and cleaning imported source files..."
                let cleaned = try await importWorkflow.cleanupImportedSources(in: session)
                guard generation == restoredStateGeneration else { return }
                if currentSession?.id == session.id {
                    setCurrentSession(cleaned, updateKind: .sessionOnly)
                    persistCurrentSession(immediately: true)
                } else {
                    try flushPendingSessionPersistenceOrThrow()
                    try sessionStore.save(session: cleaned, bursts: [], clusters: [])
                    storePersistedSession(cleaned, bursts: [], clusters: [])
                }
                statusMessage = "Removed verified imported source files."
            } catch { statusMessage = error.localizedDescription }
        }
    }

    private func userFacingCopyFailureMessage(for error: Error) -> String {
        if let lifecycleError = error as? LifecycleTransitionError {
            switch lifecycleError {
            case .invalidTransition:
                return "Copy could not continue because this log already contains copied photos. Start a new photo log for new selections, or continue a log that still has uncopied S photos."
            }
        }

        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("Invalid lifecycle transition") {
            return "Copy could not continue because this log already contains copied photos. Start a new photo log for new selections, or continue a log that still has uncopied S photos."
        }
        return message
    }

    func archivePreview(for item: MediaItem) -> String {
        archivePreviewByMediaItemID[item.id] ?? ""
    }

    func thumbnailURL(for item: MediaItem) -> URL {
        previewStore.cachedThumbnailURL(for: item)
    }

    func thumbnailSlot(for item: MediaItem) -> ThumbnailSlot {
        thumbnailRegistry.slot(for: item.id)
    }

    func thumbnailImage(for item: MediaItem) -> NSImage? {
        let imageURL = thumbnailURL(for: item)
        let url = imageURL as NSURL
        if let image = thumbnailImageCache.object(forKey: url) {
            thumbnailRegistry.update(itemID: item.id, image: image, isMissing: false)
            return image
        }

        if missingThumbnailPaths.contains(imageURL.path) {
            thumbnailRegistry.update(itemID: item.id, image: nil, isMissing: true)
            return nil
        }

        guard fileManager.fileExists(atPath: imageURL.path) else {
            missingThumbnailPaths.insert(imageURL.path)
            thumbnailRegistry.update(itemID: item.id, image: nil, isMissing: true)
            return nil
        }

        decodeThumbnailIfNeeded(from: imageURL, itemID: item.id)
        return nil
    }

    func requestThumbnail(for item: MediaItem) {
        let imageURL = thumbnailURL(for: item)
        if thumbnailImageCache.object(forKey: imageURL as NSURL) != nil {
            return
        }
        if fileManager.fileExists(atPath: imageURL.path) {
            decodeThumbnailIfNeeded(from: imageURL, itemID: item.id)
            return
        }
        enqueueThumbnailRequests([item], priority: .visible)
    }

    func isArchiveByteReadBlocked(for item: MediaItem) -> Bool {
        ArchiveByteReadPolicyContext.shared.canReadBytes(at: item.sourceURL) == false
    }

    func downloadArchiveItemForViewing(_ item: MediaItem) {
        guard originalViewingTasks[item.id] == nil else { return }
        let service = testingOriginalViewingService ?? ArchiveOriginalViewingService()
        let policy = ArchiveByteReadPolicyContext.shared
        let generation = policy.generation
        let operationID = UUID()
        let nodeID = selectedBrowserNode?.id
        originalViewingOperationIDs[item.id] = operationID
        statusMessage = "Preparing \(item.fileName) for viewing…"
        originalViewingTasks[item.id] = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.originalViewingOperationIDs[item.id] == operationID {
                    self.originalViewingTasks[item.id] = nil
                    self.originalViewingOperationIDs[item.id] = nil
                }
            }
            guard policy.generation == generation, self.originalViewingOperationIDs[item.id] == operationID else { return }
            do {
                try await service.prepare(item.sourceURL, policy: policy)
                guard policy.generation == generation, self.originalViewingOperationIDs[item.id] == operationID else { return }
                self.originalViewingRevision &+= 1
                if self.selectedBrowserNode?.id == nodeID { self.previewingMediaItemID = item.id }
                self.refreshPresentationState()
                self.refreshCompareState()
                self.statusMessage = "Original ready to view: \(item.fileName)."
            } catch is CancellationError {
                guard policy.generation == generation else { return }
                self.statusMessage = "Original viewing cancelled."
            } catch {
                guard policy.generation == generation else { return }
                self.statusMessage = "Could not prepare original: \(error.localizedDescription)"
            }
        }
    }

    var canDownloadBlockedArchiveSelectionToView: Bool {
        blockedArchiveSelectionItem != nil
    }

    func downloadBlockedArchiveSelectionToView() {
        guard let item = blockedArchiveSelectionItem else {
            statusMessage = "Select an archive photo before requesting Download to view."
            return
        }
        downloadArchiveItemForViewing(item)
    }

    private var blockedArchiveSelectionItem: MediaItem? {
        let preferredIDs = [focusedReviewItemID].compactMap { $0 } + Array(selectedMediaItemIDs)
        for id in preferredIDs {
            guard let item = mediaItem(for: id), isArchiveByteReadBlocked(for: item) else { continue }
            return item
        }
        return nil
    }

    func decodedImageRequest(for item: MediaItem, priority: TaskPriority = .userInitiated) -> DecodedImageRequest? {
        guard ArchiveByteReadPolicyContext.shared.canReadBytes(at: item.sourceURL) else { return nil }
        return .interactiveDisplay(item.sourceURL, priority: priority)
    }

    func setArchiveRoot(_ archiveRoot: URL) {
        cancelArchiveMediaLoad()
        invalidateArchiveContext()
        let shouldFollowArchiveRoot = settings.oneDrivePicturesRoot.standardizedFileURL == settings.archiveRoot.standardizedFileURL
        settings.archiveRoot = archiveRoot
        if shouldFollowArchiveRoot {
            settings.oneDrivePicturesRoot = archiveRoot
        }
        archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: archiveRoot)
        archiveMediaCache.removeAll()
        browserViewModel.invalidateArchiveTreeCache()
        rebuildBrowserCaches()
        archiveNavigationLevel = .archive
        activeArchiveContentNode = nil
        archiveYearFilter = nil
        ArchiveByteReadPolicyContext.shared.update(settings: settings)
        reloadArchiveCatalogue()

        if var session = currentSession {
            session.archiveRoot = archiveRoot
            if shouldFollowArchiveRoot {
                session.oneDrivePicturesRoot = archiveRoot
            }
            save(session)
        }

        persistSettings()
        let existingYears = archiveYearFolders.isEmpty ? "no existing 202x folders detected yet" : "found year folders: \(archiveYearFolders.joined(separator: ", "))"
        statusMessage = "Archive root set to \(archiveRoot.path); \(existingYears)."
    }

    func backfillArchiveIndexThumbnailsInteractively() {
        guard canWriteArchiveIndex else {
            statusMessage = archiveIndexWriteHelp
            return
        }
        let alert = NSAlert()
        alert.messageText = "Backfill Archive Index thumbnails?"
        alert.informativeText = "This scans the Archive and writes missing 512px JPEG thumbnails to _index/thumbs. Online-only originals are processed one at a time and evicted again. The backfill stops before free space falls below 15 GB. Existing thumbnails are left untouched."
        alert.addButton(withTitle: "Backfill")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            statusMessage = "Archive thumbnail backfill cancelled."
            return
        }

        startArchiveThumbnailBackfill(scopeTitle: "Archive")
    }

    var canPrepareCurrentArchiveFolderThumbnails: Bool {
        guard canWriteArchiveIndex,
              workspaceMode == .archiveView,
              case .photos = archiveNavigationLevel else { return false }
        return !currentArchivePhotoItems.isEmpty
    }

    func prepareCurrentArchiveFolderThumbnailsInteractively() {
        guard canPrepareCurrentArchiveFolderThumbnails else {
            statusMessage = canWriteArchiveIndex
                ? "Open an Archive photo folder before preparing thumbnails."
                : archiveIndexWriteHelp
            return
        }

        let items = currentArchivePhotoItems
        let archiveRoot = settings.archiveRoot
        let fileManager = fileManager
        let bytePolicy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: .mainArchive)
        var indexReady = 0
        var localCacheReady = 0
        var onlineOnly = 0
        var cachedThumbnailURLsByPhotoPath: [String: URL] = [:]

        for item in items {
            let indexThumbnailURL = ArchiveIndexStore.thumbnailURL(for: item.sourceURL, archiveRoot: archiveRoot)
            if fileManager.fileExists(atPath: indexThumbnailURL.path) {
                indexReady += 1
                continue
            }

            let cachedThumbnailURL = previewStore.cachedThumbnailURL(for: item)
            if fileManager.fileExists(atPath: cachedThumbnailURL.path) {
                cachedThumbnailURLsByPhotoPath[item.sourceURL.standardizedFileURL.path] = cachedThumbnailURL
                localCacheReady += 1
            } else if bytePolicy.isOnlineOnly(item.sourceURL) {
                onlineOnly += 1
            }
        }

        guard indexReady < items.count else {
            statusMessage = "All \(items.count) photos in \(activeArchiveContentNode?.title ?? "this folder") already have prepared thumbnails."
            requestInitialArchiveThumbnails(for: items)
            return
        }

        let localOriginals = items.count - indexReady - localCacheReady - onlineOnly
        let folderTitle = activeArchiveContentNode?.title ?? "this folder"
        let alert = NSAlert()
        alert.messageText = "Prepare thumbnails for \(folderTitle)?"
        alert.informativeText = "\(indexReady) already have Archive Index thumbnails. \(localCacheReady) can be copied from the local application cache. \(localOriginals) can be generated from local originals. \(onlineOnly) online-only original(s) will be downloaded one at a time, reduced to 512-pixel JPEGs, and evicted again. You can cancel safely, and preparation stops before free space falls below 15 GB."
        alert.addButton(withTitle: "Prepare")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            statusMessage = "Thumbnail preparation cancelled."
            return
        }

        startArchiveThumbnailBackfill(
            scopeTitle: folderTitle,
            items: items,
            cachedThumbnailURLsByPhotoPath: cachedThumbnailURLsByPhotoPath
        )
    }

    private var currentArchivePhotoItems: [MediaItem] {
        guard case .photos = archiveNavigationLevel,
              let nodeID = activeArchiveContentNode?.id else { return [] }
        return archiveMediaCache[nodeID] ?? []
    }

    private func startArchiveThumbnailBackfill(
        scopeTitle: String,
        items: [MediaItem]? = nil,
        cachedThumbnailURLsByPhotoPath: [String: URL] = [:]
    ) {
        let archiveRoot = settings.archiveRoot
        let supportedExtensions = settings.supportedExtensions
        let policy = archiveIndexWritePolicy
        let photoURLs = items?.map(\.sourceURL)
        let operationName = items == nil ? "Archive thumbnail backfill" : "Thumbnail preparation for \(scopeTitle)"

        archiveBackfillTask?.cancel()
        archiveBackfillIsRunning = true
        archiveBackfillProgress = ArchiveThumbnailPreparationProgress(
            scopeTitle: scopeTitle,
            completed: 0,
            total: photoURLs?.count ?? 0
        )
        statusMessage = "\(operationName) started…"
        archiveBackfillTask = Task {
            let result = await ArchiveIndexMutationQueue.shared.backfillThumbnails(
                archiveRoot: archiveRoot,
                supportedExtensions: supportedExtensions,
                policy: policy,
                photoURLs: photoURLs,
                cachedThumbnailURLsByPhotoPath: cachedThumbnailURLsByPhotoPath,
                progress: { current, total in
                    await MainActor.run { [weak self] in
                        self?.archiveBackfillProgress = ArchiveThumbnailPreparationProgress(
                            scopeTitle: scopeTitle,
                            completed: current,
                            total: total
                        )
                        self?.statusMessage = "\(operationName) \(current)/\(total)…"
                    }
                }
            )
            guard let result else {
                archiveBackfillIsRunning = false
                archiveBackfillProgress = nil
                archiveBackfillTask = nil
                statusMessage = policy.disabledHelp
                return
            }
            archiveBackfillIsRunning = false
            archiveBackfillProgress = nil
            archiveBackfillTask = nil
            if let items {
                refreshPreparedArchiveThumbnails(for: items)
            }
            reloadArchiveCatalogue()
            if result.stoppedForLowSpace {
                statusMessage = "\(operationName) paused before free space fell below 15 GB: \(result.generatedThumbnails) generated and \(result.evictedFiles) originals evicted."
            } else if result.cancelled {
                statusMessage = "\(operationName) cancelled safely: \(result.generatedThumbnails) generated and \(result.evictedFiles) originals evicted."
            } else {
                statusMessage = "\(operationName) finished: \(result.generatedThumbnails) generated, \(result.existingThumbnails) already present, \(result.evictedFiles) originals evicted, \(result.failures.count) failed."
            }
        }
    }

    private func refreshPreparedArchiveThumbnails(for items: [MediaItem]) {
        for item in items {
            let imageURL = thumbnailURL(for: item)
            thumbnailFailures.remove(item.id)
            missingThumbnailPaths.remove(imageURL.path)
            thumbnailImageCache.removeObject(forKey: imageURL as NSURL)
            decodeThumbnailIfNeeded(from: imageURL, itemID: item.id)
        }
    }

    func cancelArchiveIndexThumbnailBackfill() {
        guard archiveBackfillIsRunning else { return }
        archiveBackfillTask?.cancel()
        statusMessage = "Cancelling Archive thumbnail backfill after the current file…"
    }

    func rebuildArchiveIndexInteractively() {
        guard canWriteArchiveIndex else {
            statusMessage = archiveIndexWriteHelp
            return
        }
        let alert = NSAlert()
        alert.messageText = "Rebuild Archive Index?"
        alert.informativeText = "This rebuilds the Archive Index from the Trip, Walk, and file manifests. The manifests remain the source of truth."
        alert.addButton(withTitle: "Rebuild")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            statusMessage = "Archive Index rebuild cancelled."
            return
        }

        let archiveRoot = settings.archiveRoot
        let policy = archiveIndexWritePolicy
        archiveMaintenanceIsRunning = true
        statusMessage = "Rebuilding Archive Index…"
        Task {
            defer { archiveMaintenanceIsRunning = false }
            do {
                if let result = try await ArchiveIndexMutationQueue.shared.rebuildIndex(archiveRoot: archiveRoot, policy: policy) {
                    self.statusMessage = "Archive Index rebuilt with \(result.entryCount) entries across \(result.years.count) year shard(s)."
                    self.reloadArchiveCatalogue()
                } else {
                    self.statusMessage = policy.disabledHelp
                }
            } catch {
                self.statusMessage = "Archive Index rebuild failed: \(error.localizedDescription)"
            }
        }
    }

    var canWriteArchiveIndex: Bool {
        backupPersistenceGate.blockedReason == nil && !archiveMaintenanceIsRunning && archiveIndexWritePolicy.canWriteIndex
    }

    var archiveIndexWriteHelp: String {
        archiveIndexWritePolicy.disabledHelp
    }

    private var archiveIndexWritePolicy: ArchiveIndexWritePolicy {
        ArchiveIndexWritePolicy(machineRole: settings.archiveMachineRole)
    }

    func migrateArchiveLayoutInteractively() {
        guard backupPersistenceGate.blockedReason == nil, !archiveMaintenanceIsRunning else { return }
        archiveMaintenanceIsRunning = true
        let archiveRoot = settings.archiveRoot
        let migrator = ArchiveLayoutMigrator()
        statusMessage = "Scanning archive for layout v2 migration…"
        Task.detached(priority: .userInitiated) { [weak self] in
            let plan = migrator.plan(archiveRoot: archiveRoot)
            await MainActor.run {
                self?.presentArchiveMigrationPlan(plan, migrator: migrator, archiveRoot: archiveRoot)
            }
        }
    }

    private func presentArchiveMigrationPlan(_ plan: ArchiveLayoutMigrator.Plan, migrator: ArchiveLayoutMigrator, archiveRoot: URL) {
        var lines: [String] = ["Archive layout v2 migration dry run — \(DateFormatting.iso8601.string(from: Date()))", ""]
        for walk in plan.walks {
            lines.append("\(walk.yearName)/\(walk.oldMonthName)/\(walk.oldWalkName)")
            lines.append("  -> \(walk.yearName)/\(walk.newMonthName)/\(walk.newWalkName)")
            lines.append("  files: \(walk.oldStemBase)-NNN.* -> \(walk.newStemBase)-NNN.*")
        }
        if !plan.skipped.isEmpty {
            lines.append("")
            lines.append("Skipped (left untouched):")
            for (url, reason) in plan.skipped {
                lines.append("  \(url.path) — \(reason)")
            }
        }
        let reportURL = archiveRoot.appendingPathComponent("_layout-migration-dry-run.txt")
        try? lines.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)

        guard !plan.walks.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Archive already in layout v2"
            alert.informativeText = "No legacy walk folders found. \(plan.skipped.count) folder(s) were skipped as pre-app material (see \(reportURL.lastPathComponent))."
            alert.runModal()
            statusMessage = "Archive layout migration: nothing to migrate."
            archiveMaintenanceIsRunning = false
            return
        }

        let alert = NSAlert()
        alert.messageText = "Migrate archive to layout v2?"
        alert.informativeText = "\(plan.walks.count) walk folder(s) will be renamed and moved, their files renamed to date-bearing names, and manifests rewritten. \(plan.skipped.count) unrecognised folder(s) stay untouched. The full plan was written to \(reportURL.lastPathComponent) in the archive root — review it first if unsure."
        alert.addButton(withTitle: "Migrate")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            statusMessage = "Archive layout migration cancelled; dry run saved to \(reportURL.lastPathComponent)."
            archiveMaintenanceIsRunning = false
            return
        }

        statusMessage = "Migrating archive layout…"
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = migrator.execute(plan)
            let problems = migrator.verify(plan)
            await MainActor.run {
                self?.finishArchiveMigration(result: result, problems: problems, archiveRoot: archiveRoot)
            }
        }
    }

    private func finishArchiveMigration(result: ArchiveLayoutMigrator.ExecutionResult, problems: [String], archiveRoot: URL) {
        defer { archiveMaintenanceIsRunning = false }
        var problems = problems
        if result.failures.isEmpty && problems.isEmpty {
            do { try reconcileSavedArchivePaths(syncChangedLogs: true) }
            catch { problems.append("Photo Log path reconciliation failed: \(error.localizedDescription)") }
        }
        var lines = [
            "Archive layout v2 migration — \(DateFormatting.iso8601.string(from: Date()))",
            "Migrated walks: \(result.migratedWalks)",
            "Renamed files: \(result.renamedFiles)",
            "Rewritten text files: \(result.rewrittenTextFiles)",
            "Removed legacy month folders: \(result.removedLegacyMonthFolders)",
        ]
        if !result.failures.isEmpty {
            lines.append("Failures:")
            lines.append(contentsOf: result.failures.map { "  \($0)" })
        }
        if !problems.isEmpty {
            lines.append("Verification problems:")
            lines.append(contentsOf: problems.map { "  \($0)" })
        }
        let reportURL = archiveRoot.appendingPathComponent("_layout-migration-report.txt")
        try? lines.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)

        archiveMediaCache.removeAll()
        browserViewModel.invalidateArchiveTreeCache()
        rebuildBrowserCaches()

        let alert = NSAlert()
        if result.failures.isEmpty && problems.isEmpty {
            alert.messageText = "Archive migrated to layout v2"
            alert.informativeText = "\(result.migratedWalks) walk(s) migrated, \(result.renamedFiles) file(s) renamed, \(result.rewrittenTextFiles) manifest(s) rewritten. Report: \(reportURL.lastPathComponent)."
            rebuildArchiveIndexAfterSuccessfulMigration(archiveRoot: archiveRoot)
        } else {
            alert.messageText = "Archive migration finished with issues"
            alert.informativeText = "\(result.failures.count) failure(s), \(problems.count) verification problem(s). See \(reportURL.lastPathComponent) in the archive root."
        }
        alert.runModal()
        statusMessage = "Archive layout migration finished; report saved to \(reportURL.lastPathComponent)."
    }

    func setOneDrivePicturesRoot(_ root: URL) {
        guard root.standardizedFileURL != settings.oneDrivePicturesRoot.standardizedFileURL else { return }
        settings.oneDrivePicturesRoot = root
        if var session = currentSession {
            session.oneDrivePicturesRoot = root
            save(session)
        }
        persistSettings()
        reloadArchiveCatalogue()
        statusMessage = "OneDrive Pictures root set to \(root.path)."
    }

    func setArchiveMachineRole(_ role: ArchiveMachineRole) {
        guard role != settings.archiveMachineRole else { return }
        settings.archiveMachineRole = role
        if var session = currentSession {
            session.archiveMachineRole = role
            save(session)
        }
        persistSettings()
        reloadArchiveCatalogue()
        statusMessage = "Machine role set to \(role.title)."
    }

    func setDefaultSourceRoot(_ sourceRoot: URL) {
        settings.defaultSourceRoot = sourceRoot
        persistSettings()
        loadSourceWorkspace(folder: sourceRoot, origin: .settingsDefaultRoot)
    }

    func setReviewPresentationMode(_ mode: ReviewPresentationMode) {
        settings.reviewPresentationMode = mode
        updateReviewGridMetrics(availableWidth: nil)
        persistSettings()
    }

    func setReviewFilter(_ filter: ReviewFilter) {
        reviewFilter = filter
        if filter == .all {
            statusMessage = "Showing all visible photos."
        } else if filter == .cropped {
            statusMessage = "Showing crop-linked photos."
        } else {
            statusMessage = "Showing \(filter.title.lowercased()) photos."
        }
    }

    func setReviewGridColumnCount(_ count: Int) {
        let clamped = min(max(count, 1), ReviewGridMetrics.maxSuggestedColumns)
        guard settings.reviewGridColumnCount != clamped else { return }
        settings.reviewGridColumnCount = clamped
        updateReviewGridMetrics(availableWidth: nil)
        persistSettings()
    }

    func increaseReviewGridColumnCount() {
        setReviewGridColumnCount(settings.reviewGridColumnCount + 1)
    }

    func decreaseReviewGridColumnCount() {
        setReviewGridColumnCount(settings.reviewGridColumnCount - 1)
    }

    func resetReviewGridColumnCount() {
        setReviewGridColumnCount(ReviewGridMetrics.defaultRequestedColumnCount())
    }

    func setCompareGridColumnCount(_ count: Int) {
        let upperBound = max(comparingMediaItemIDs.count, 1)
        compareGridColumnCount = min(max(count, 1), upperBound)
    }

    func increaseCompareGridColumnCount() {
        setCompareGridColumnCount(compareGridColumnCount + 1)
    }

    func decreaseCompareGridColumnCount() {
        setCompareGridColumnCount(compareGridColumnCount - 1)
    }

    func resetCompareGridColumnCount() {
        compareGridColumnCount = CompareGridMetrics.defaultColumnCount(for: comparingMediaItemIDs.count)
    }

    func setBurstThresholdSeconds(_ threshold: TimeInterval) {
        let clamped = min(max(threshold, 0.5), 10)
        guard settings.burstThresholdSeconds != clamped else { return }
        settings.burstThresholdSeconds = clamped
        persistSettings()
        regroupCurrentSession(statusPrefix: "Updated burst grouping")
    }

    func setProximityThresholdSeconds(_ threshold: TimeInterval) {
        let clamped = min(max(threshold, 60), 7_200)
        guard settings.proximityThresholdSeconds != clamped else { return }
        settings.proximityThresholdSeconds = clamped
        persistSettings()
        regroupCurrentSession(statusPrefix: "Updated time-cluster grouping")
    }

    func setWeekdayTokenStyle(_ style: WeekdayTokenStyle) {
        settings.weekdayTokenStyle = style
        if var session = currentSession {
            session.weekdayTokenStyle = style
            save(session)
        }
        persistSettings()
        statusMessage = "Weekday token style set to \(style.title)."
    }

    func setWalkDisplayLabel(_ label: String) {
        settings.walkDisplayLabel = label
        persistSettings()
        refreshAllUIState()
    }

    func setTripDisplayLabel(_ label: String) {
        settings.tripDisplayLabel = label
        persistSettings()
        refreshAllUIState()
    }

    func setDayOrganizationMode(_ mode: DayOrganizationMode) {
        dayOrganizationMode = mode
        resetInlineExpansionState()
        ensureFocusedInlineSection()
    }

    func setDayDetailDisplayMode(_ mode: DayDetailDisplayMode) {
        latencyRecorder.begin("review.mode")
        if mode == .sections, !canUseGroupedReviewMode {
            dayDetailDisplayMode = .review
            statusMessage = "Grouped review is available when browsing a day or a folder with day sections."
            activateReviewGridFocus()
            latencyRecorder.end("review.mode")
            return
        }
        dayDetailDisplayMode = mode
        if mode == .sections {
            expandInlineSectionsForGroupedReviewIfNeeded()
            ensureFocusedInlineSection()
        } else {
            pendingInlineSectionScrollTargetID = nil
            reviewKeyboardTarget = .items
        }
        activateReviewGridFocus()
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("review.mode")
        }
    }

    func updateReviewGridMetrics(availableWidth: CGFloat?, availableHeight: CGFloat? = nil) {
        if let availableWidth, availableWidth > 0 {
            lastMeasuredReviewPaneWidth = Double(availableWidth)
        }
        if let availableHeight, availableHeight > 0 {
            lastMeasuredReviewPaneHeight = Double(availableHeight)
        }

        let width = max(lastMeasuredReviewPaneWidth, 0)
        let metrics = ReviewGridMetrics(availableWidth: width, requestedColumnCount: settings.reviewGridColumnCount)
        reviewGridColumnCount = reviewPresentationMode == .grid ? metrics.columnCount : 1
        updateEstimatedVisibleReviewRange(around: focusedReviewItemID)
    }

    func toggleDetailsInspector() {
        latencyRecorder.begin("inspector.toggle")
        isDetailsInspectorVisible.toggle()
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("inspector.toggle")
        }
    }

    func toggleSidebarVisibility() {
        latencyRecorder.begin("sidebar.toggle")
        isSidebarVisible.toggle()
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("sidebar.toggle")
        }
    }

    func focusSidebarNavigation() {
        if !isSidebarVisible {
            isSidebarVisible = true
        }
        activePane = .sidebar
        reviewGridHasFocus = false
        reviewKeyboardTarget = .items
        commandCoordinator.requestFocus(scope: workspaceMode == .archiveView ? .archiveSidebar : .sourceSidebar)
    }

    func focusReviewSurface() {
        guard canFocusReviewSurface else { return }
        if workspaceMode == .archiveView {
            switch archiveNavigationLevel {
            case .archive, .trip:
                activePane = .media
                reviewGridHasFocus = false
                archiveBrowseFocusRevision &+= 1
                refreshArchiveBrowserState()
                commandCoordinator.requestFocus(scope: .archiveCards)
                return
            case .photos: break
            }
        }
        if dayDetailDisplayMode == .sections {
            ensureFocusedInlineSection()
        }
        reviewKeyboardTarget = .items
        activateReviewGridFocus()
        commandCoordinator.requestFocus(scope: .review)
    }

    func showFlatReview() {
        setDayDetailDisplayMode(.review)
    }

    func showGroupedReview() {
        setDayDetailDisplayMode(.sections)
    }

    func selectSidebarNode(_ nodeID: String?) {
        selectedSidebarNodeID = nodeID
        activePane = .sidebar
        dayDetailDisplayMode = .review
        reviewKeyboardTarget = .items
        drilledInlineSectionID = nil
        drilledInlineSectionMediaItemIDs = []
        clearDetailSelections()
        loadArchiveMediaIfNeeded(for: nodeID)
        resetInlineExpansionState()
        requestVisibleThumbnails()
    }

    func toggleInlineSectionExpansion(_ sectionID: String) {
        focusInlineSection(sectionID, scrollIntoView: false)
        if expandedInlineSectionIDs.contains(sectionID) {
            expandedInlineSectionIDs.remove(sectionID)
        } else {
            expandedInlineSectionIDs.insert(sectionID)
        }
        reconcileReviewSelectionWithVisibleItems()
    }

    func isInlineSectionExpanded(_ sectionID: String) -> Bool {
        expandedInlineSectionIDs.contains(sectionID)
    }

    func expandAllInlineSections() {
        expandedInlineSectionIDs = Set(inlineSectionOrganizer.flattenSectionIDs(from: organizedInlineSections))
        ensureFocusedInlineSection()
        reconcileReviewSelectionWithVisibleItems()
    }

    func collapseAllInlineSections() {
        expandedInlineSectionIDs.removeAll()
        ensureFocusedInlineSection()
        reconcileReviewSelectionWithVisibleItems()
    }

    func focusInlineSection(_ sectionID: String, scrollIntoView: Bool = true, asKeyboardTarget: Bool = true) {
        guard canUseGroupedSectionNavigation else { return }
        focusedInlineSectionID = sectionID
        activePane = .media
        reviewGridHasFocus = true
        reviewKeyboardTarget = asKeyboardTarget ? .sections : .items
        if scrollIntoView {
            requestInlineSectionScroll(to: sectionID)
        }
    }

    func focusNextInlineSection() {
        moveInlineSectionFocus(by: 1)
    }

    func focusPreviousInlineSection() {
        moveInlineSectionFocus(by: -1)
    }

    func expandFocusedInlineSection() {
        guard let section = focusedInlineSection, !section.mediaItemIDs.isEmpty else { return }
        expandedInlineSectionIDs.insert(section.id)
        focusInlineSection(section.id)
        reconcileReviewSelectionWithVisibleItems()
    }

    func collapseFocusedInlineSection() {
        guard let section = focusedInlineSection, !section.mediaItemIDs.isEmpty else { return }
        expandedInlineSectionIDs.remove(section.id)
        focusInlineSection(section.id)
        reconcileReviewSelectionWithVisibleItems()
    }

    func revealInlineMediaItem(_ itemID: UUID, sectionPath: [String]) {
        withCoalescedRefreshes {
            expandedInlineSectionIDs.formUnion(sectionPath)
            selectInlineMediaItem(itemID)
            focusedInlineSectionID = sectionPath.last
            focusedReviewItemID = itemID
            activePane = .media
            reviewKeyboardTarget = .items
        }
        DispatchQueue.main.async { [weak self] in
            self?.pendingInlineScrollTargetID = itemID
        }
    }

    func selectInlineMediaItem(_ itemID: UUID) {
        withCoalescedRefreshes {
            previewingMediaItemID = nil
            selectMediaItems([itemID])
            syncFocusedInlineSectionToFocusedItem()
            focusedReviewItemID = itemID
            activePane = .media
            reviewGridHasFocus = true
            reviewKeyboardTarget = .items
        }
    }

    func previewItems(for section: InlineSection, limit: Int = 18) -> [MediaItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: mediaItems(for: section.mediaItemIDs).map { ($0.id, $0) })
        let orderedIDs = inlineSectionOrganizer.previewItemIDs(for: section, availableItems: itemsByID, limit: limit)
        return orderedIDs.compactMap { itemsByID[$0] }
    }

    func selectFolderNodes(_ nodeIDs: Set<String>) {
        withCoalescedRefreshes {
            selectedFolderNodeIDs = nodeIDs
            activePane = .folders
            selectedMediaItemIDs.removeAll()
        }
    }

    func selectMediaItems(_ itemIDs: Set<UUID>) {
        var state = reviewSelectionState()
        selectionManager.selectMediaItems(itemIDs, state: &state)
        applyReviewSelectionState(state)
        selectedFolderNodeIDs.removeAll()
    }

    func activateReviewGridFocus() {
        var state = reviewSelectionState()
        selectionManager.activateReviewGridFocus(visibleItems: reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
        reviewKeyboardTarget = .items
    }

    func deactivateReviewGridFocus() {
        reviewGridHasFocus = false
    }

    func activateCurrentReviewTarget() {
        if isGroupedSectionKeyboardTargetActive {
            enterFocusedInlineSection()
        } else {
            openFocusedReviewItem()
        }
    }

    func handleReviewEscape() {
        latencyRecorder.begin("review.escape")
        if let drilledInlineSectionID {
            drilledInlineSectionMediaItemIDs = []
            self.drilledInlineSectionID = nil
            setDayDetailDisplayMode(.sections)
            pendingInlineScrollTargetID = nil
            pendingReviewScrollTargetID = nil
            focusInlineSection(drilledInlineSectionID, scrollIntoView: false)
            requestInlineSectionScroll(to: drilledInlineSectionID)
            requestVisibleThumbnails()
            statusMessage = "Returned to grouped section selection."
            DispatchQueue.main.async { [weak self] in
                self?.latencyRecorder.end("review.escape")
            }
            return
        }

        if dayDetailDisplayMode == .sections, reviewKeyboardTarget == .items {
            let sectionID = focusedInlineSectionID ?? focusedReviewItemID.flatMap { inlineSectionID(containing: $0, in: organizedInlineSections) }
            if let sectionID {
                focusInlineSection(sectionID)
                statusMessage = "Returned to grouped section selection."
                DispatchQueue.main.async { [weak self] in
                    self?.latencyRecorder.end("review.escape")
                }
                return
            }
        }

        deactivateReviewGridFocus()
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("review.escape")
        }
    }

    func handleReviewArrowKey(dx: Int, dy: Int, extending: Bool) {
        guard reviewGridHasFocus else { return }
        latencyRecorder.begin("review.arrow")

        if isGroupedSectionKeyboardTargetActive {
            if dy < 0 {
                focusPreviousInlineSection()
            } else if dy > 0 {
                focusNextInlineSection()
            } else if dx < 0 {
                collapseFocusedInlineSection()
            } else if dx > 0 {
                expandFocusedInlineSection()
            }
            latencyRecorder.end("review.arrow")
            return
        }

        let columns = max(1, reviewPresentationMode == .grid ? reviewGridColumnCount : 1)
        if dx != 0 {
            moveGridSelection(by: dx, extending: extending)
        } else if dy != 0 {
            moveGridSelection(by: dy * columns, extending: extending)
        }
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("review.arrow")
        }
    }

    func handleGroupedSectionArrowKey(dx: Int, dy: Int) {
        guard canUseGroupedSectionNavigation else { return }
        reviewKeyboardTarget = .sections
        if dy < 0 {
            focusPreviousInlineSection()
        } else if dy > 0 {
            focusNextInlineSection()
        } else if dx < 0 {
            collapseFocusedInlineSection()
        } else if dx > 0 {
            expandFocusedInlineSection()
        }
    }

    func handleGroupedSectionExpandCollapse(expand: Bool) {
        guard canUseGroupedSectionNavigation else { return }
        reviewKeyboardTarget = .sections
        if expand {
            expandFocusedInlineSection()
        } else {
            collapseFocusedInlineSection()
        }
    }

    func handleGridSelection(for itemID: UUID, modifiers: NSEvent.ModifierFlags) {
        handleGridSelection(for: itemID, click: ReviewGridClickContext(modifiers: modifiers, clickCount: 1))
    }

    func handleGridSelection(for itemID: UUID, click: ReviewGridClickContext) {
        guard let _ = currentSession else { return }
        if !comparingMediaItemIDs.isEmpty, comparingMediaItemIDs.contains(itemID) {
            handleComparisonSelection(for: itemID, click: click)
            return
        }
        var state = reviewSelectionState()
        selectionManager.handleGridSelection(
            for: itemID,
            visibleItems: reviewInteractionItems,
            isShiftPressed: click.isShiftPressed,
            isCommandPressed: click.isCommandPressed,
            state: &state
        )
        applyReviewSelectionState(state)
        reviewKeyboardTarget = .items
        syncFocusedInlineSectionToFocusedItem()
        if click.isDoubleClick {
            openFocusedReviewItem()
        }
    }

    func moveGridSelection(by offset: Int, extending: Bool) {
        var state = reviewSelectionState()
        selectionManager.moveSelection(by: offset, visibleItems: reviewInteractionItems, extending: extending, state: &state)
        applyReviewSelectionState(state)
        reviewKeyboardTarget = .items
        syncFocusedInlineSectionToFocusedItem()
    }

    func performReviewShortcut(_ key: String) {
        guard reviewGridHasFocus else { return }
        let uppercased = key.uppercased()

        switch uppercased {
        case "S":
            markCurrentSelectionForImport()
        case "C":
            markCurrentSelectionAsCandidate()
        case "X":
            excludeCurrentSelectionFromImport()
        case "D":
            unmarkCurrentSelectionForImport()
        case "R":
            toggleRawForCurrentMediaSelection()
        case "A":
            selectAllVisibleMedia()
        default:
            break
        }
    }

    func selectAllVisibleMedia() {
        if !comparingMediaItemIDs.isEmpty {
            selectAllComparisonItems()
            return
        }
        var state = reviewSelectionState()
        selectionManager.selectAllVisibleMedia(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func deselectAllVisibleMedia() {
        if !comparingMediaItemIDs.isEmpty {
            deselectComparisonItems()
            return
        }
        var state = reviewSelectionState()
        selectionManager.deselectAllVisibleMedia(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func toggleFocusedReviewItemSelection() {
        if !comparingMediaItemIDs.isEmpty,
           let focusedID = focusedReviewItemID ?? comparingMediaItemIDs.first {
            toggleSelectionForComparisonItem(focusedID)
            return
        }
        var state = reviewSelectionState()
        selectionManager.toggleFocusedReviewItemSelection(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func selectFocusedReviewItemOnly() {
        if !comparingMediaItemIDs.isEmpty {
            guard let focusedID = focusedReviewItemID ?? comparingMediaItemIDs.first,
                  comparingMediaItemIDs.contains(focusedID) else { return }
            focusComparisonItem(focusedID)
            return
        }
        var state = reviewSelectionState()
        selectionManager.selectFocusedReviewItemOnly(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func openFocusedReviewItem() {
        guard let focusedID = focusedReviewItemID ?? selectedMediaItemIDs.first else { return }
        preheatDisplayImages(around: focusedID, in: reviewInteractionItems, radius: 2)
        previewingMediaItemID = focusedID
    }

    func drillIntoFocusedInlineSection() {
        guard let section = focusedInlineSection else { return }
        let scopedItemIDs = resolvedMediaItemIDs(in: section)
        guard !scopedItemIDs.isEmpty else { return }
        withCoalescedRefreshes {
            drilledInlineSectionID = section.id
            drilledInlineSectionMediaItemIDs = scopedItemIDs
            dayDetailDisplayMode = .review
            reviewKeyboardTarget = .items
            activePane = .media
            reviewGridHasFocus = true
            if let firstID = scopedItemIDs.first {
                selectedMediaItemIDs = [firstID]
                focusedReviewItemID = firstID
                reviewSelectionAnchorID = firstID
                pendingReviewScrollTargetID = firstID
            }
            statusMessage = "Opened \(section.title)."
        }
    }

    func navigatePreview(by offset: Int) {
        guard let targetID = previewNavigationOffset(offset) else { return }
        withCoalescedRefreshes {
            preheatDisplayImages(around: targetID, in: reviewInteractionItems, radius: 2)
            previewingMediaItemID = targetID
            focusedReviewItemID = targetID
            selectedMediaItemIDs = [targetID]
            reviewSelectionAnchorID = targetID
            activePane = .media
        }
    }

    func isCropInProgress(for item: MediaItem) -> Bool {
        cropOperationItemIDs.contains(item.id)
    }

    func cropMediaItem(_ item: MediaItem, normalizedRect: CropNormalizedRect, trigger: CropTrigger) {
        if let currentSession, currentSession.mediaItems.contains(where: { $0.id == item.id }) {
            guard allowEditingCopyInputs(currentSession) else { return }
        }
        guard normalizedRect.isUsableCrop else {
            statusMessage = "Crop area is too small."
            return
        }
        if trigger == .visibleZoom && normalizedRect.isEffectivelyFullFrame {
            statusMessage = "Zoom in or use Drag Crop before saving a crop."
            return
        }
        guard !cropOperationItemIDs.contains(item.id) else {
            statusMessage = "Crop is already saving for \(item.fileName)."
            return
        }

        let release = AppRelease.current
        cropOperationItemIDs.insert(item.id)
        statusMessage = "Saving crop from \(item.fileName)..."

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try CropService().crop(
                        item: item,
                        normalizedRect: normalizedRect,
                        trigger: trigger,
                        appRelease: release
                    )
                }.value

                if let cropItem = recordCropRelationship(for: item, cropURL: result.outputURL, manifestURL: result.manifestURL) {
                    focusCropOutput(cropItem, replacing: item)
                    statusMessage = "Saved crop \(result.outputURL.lastPathComponent) and showing cropped version."
                } else {
                    statusMessage = "Saved crop \(result.outputURL.lastPathComponent). Reload the folder if it is not visible."
                }
                refreshArchiveIndexAfterCrop(at: item.sourceURL)
            } catch {
                statusMessage = "Crop failed: \(error.localizedDescription)"
            }
            cropOperationItemIDs.remove(item.id)
        }
    }

    func openCropLinkedPreview(for itemID: UUID) {
        guard let item = mediaItem(for: itemID),
              let targetRelativePath = item.cropRelationship?.linkedPreviewRelativePath else {
            statusMessage = "No linked crop/original preview is available."
            return
        }
        guard let target = mediaItem(relativePath: targetRelativePath) else {
            statusMessage = "Linked crop/original is not loaded in the current browser view."
            return
        }

        focusMediaItem(target)
        statusMessage = "Opened linked \(target.cropRelationship?.role == .crop ? "crop" : "original") \(target.fileName)."
    }

    func openComparisonForCurrentSelection() {
        let ids = reviewInteractionItems
            .map(\.id)
            .filter { currentSelectionMediaIDs().contains($0) }
        openComparison(for: ids, title: "Compare Selection")
    }

    func openComparison(for itemIDs: [UUID], title: String) {
        let deduplicatedIDs = itemIDs.reduce(into: [UUID]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
        guard deduplicatedIDs.count >= 2 else { return }
        latencyRecorder.begin("compare.open")
        if compareSelectionBackup == nil {
            compareSelectionBackup = CompareSelectionBackup(
                selectionState: reviewSelectionState(),
                keyboardTarget: reviewKeyboardTarget
            )
        }
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        activePane = .media
        if let firstID = deduplicatedIDs.first {
            selectedMediaItemIDs = [firstID]
            focusedReviewItemID = firstID
            reviewSelectionAnchorID = firstID
        }
        compareGridColumnCount = CompareGridMetrics.defaultColumnCount(for: deduplicatedIDs.count)
        compareSheetTitle = title
        preheatDisplayImages(for: deduplicatedIDs, limit: 12)
        comparingMediaItemIDs = deduplicatedIDs
        statusMessage = "Opened compare view for \(deduplicatedIDs.count) item(s)."
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("compare.open")
        }
    }

    func closeComparison() {
        latencyRecorder.begin("compare.close")
        comparingMediaItemIDs.removeAll()
        compareGridColumnCount = CompareGridMetrics.defaultColumnCount(for: 0)
        if let backup = compareSelectionBackup {
            selectedMediaItemIDs = backup.selectionState.selectedMediaItemIDs
            focusedReviewItemID = backup.selectionState.focusedReviewItemID
            reviewSelectionAnchorID = backup.selectionState.reviewSelectionAnchorID
            reviewGridHasFocus = backup.selectionState.reviewGridHasFocus
            reviewKeyboardTarget = backup.keyboardTarget
            activePane = backup.selectionState.activePane
            compareSelectionBackup = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.latencyRecorder.end("compare.close")
        }
    }

    func removeItemFromComparison(_ itemID: UUID) {
        let originalIDs = comparingMediaItemIDs
        let focusedID = focusedReviewItemID
        comparingMediaItemIDs.removeAll { $0 == itemID }
        if comparingMediaItemIDs.isEmpty {
            closeComparison()
            statusMessage = "Removed the last compare item and closed compare."
            return
        }

        let replacementID = comparisonReplacementID(afterRemoving: [itemID], from: originalIDs, preferredCurrentID: focusedID)
            ?? comparingMediaItemIDs.first(where: { selectedMediaItemIDs.contains($0) })
            ?? comparingMediaItemIDs.first
        let selectionStillReferencesCompareItems = selectedMediaItemIDs.contains { comparingMediaItemIDs.contains($0) }
        if focusedReviewItemID == itemID || !selectionStillReferencesCompareItems {
            if let replacementID {
                focusComparisonItem(replacementID)
            }
        } else if selectedMediaItemIDs.contains(itemID) {
            selectedMediaItemIDs.remove(itemID)
        }
        compareGridColumnCount = min(compareGridColumnCount, max(comparingMediaItemIDs.count, 1))

        statusMessage = "Removed item from compare. \(comparingMediaItemIDs.count) item(s) remain."
    }

    func focusComparisonItem(_ itemID: UUID, extendingSelection _: Bool = false) {
        guard comparingMediaItemIDs.contains(itemID) else { return }
        preheatDisplayImages(around: itemID, in: comparingMediaItemIDs, radius: 3)
        selectedMediaItemIDs = [itemID]
        focusedReviewItemID = itemID
        reviewSelectionAnchorID = itemID
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        activePane = .media
    }

    func moveComparisonFocus(dx: Int, dy: Int) {
        guard !comparingMediaItemIDs.isEmpty else { return }
        let currentID = focusedReviewItemID ?? selectedMediaItemIDs.first ?? comparingMediaItemIDs.first
        guard let currentID else { return }
        let currentIndex = comparingMediaItemIDs.firstIndex(of: currentID) ?? 0
        let columns = max(compareGridColumnCount, 1)
        let offset = dx != 0 ? dx : dy * columns
        let targetIndex = min(max(currentIndex + offset, 0), comparingMediaItemIDs.count - 1)
        focusComparisonItem(comparingMediaItemIDs[targetIndex])
    }

    func selectAllComparisonItems() {
        guard !comparingMediaItemIDs.isEmpty else { return }
        let compareIDSet = Set(comparingMediaItemIDs)
        selectedMediaItemIDs = compareIDSet
        if let focusedReviewItemID, compareIDSet.contains(focusedReviewItemID) {
            reviewSelectionAnchorID = focusedReviewItemID
        } else if let firstID = comparingMediaItemIDs.first {
            focusedReviewItemID = firstID
            reviewSelectionAnchorID = firstID
        }
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        activePane = .media
        statusMessage = "Selected \(comparingMediaItemIDs.count) compare item(s)."
    }

    func deselectComparisonItems() {
        guard !comparingMediaItemIDs.isEmpty else { return }
        selectedMediaItemIDs.removeAll()
        reviewSelectionAnchorID = nil
        if let focusedReviewItemID, comparingMediaItemIDs.contains(focusedReviewItemID) {
            // Keep compare keyboard focus on the current image even when selection is empty.
        } else {
            focusedReviewItemID = comparingMediaItemIDs.first
        }
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        activePane = .media
        statusMessage = "Deselected compare item(s)."
    }

    func toggleSelectionForComparisonItem(_ itemID: UUID) {
        guard comparingMediaItemIDs.contains(itemID) else { return }
        var selectedCompareIDs = selectedMediaItemIDs.intersection(Set(comparingMediaItemIDs))
        if selectedCompareIDs.contains(itemID) {
            selectedCompareIDs.remove(itemID)
        } else {
            selectedCompareIDs.insert(itemID)
        }
        selectedMediaItemIDs = selectedCompareIDs
        focusedReviewItemID = itemID
        reviewSelectionAnchorID = itemID
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        activePane = .media
    }

    private func handleComparisonSelection(for itemID: UUID, click: ReviewGridClickContext) {
        guard comparingMediaItemIDs.contains(itemID) else { return }
        let compareIDSet = Set(comparingMediaItemIDs)

        if click.isShiftPressed {
            let anchorID = [reviewSelectionAnchorID, focusedReviewItemID]
                .compactMap { $0 }
                .first(where: { compareIDSet.contains($0) }) ?? itemID
            if let anchorIndex = comparingMediaItemIDs.firstIndex(of: anchorID),
               let targetIndex = comparingMediaItemIDs.firstIndex(of: itemID) {
                let lower = min(anchorIndex, targetIndex)
                let upper = max(anchorIndex, targetIndex)
                selectedMediaItemIDs = Set(comparingMediaItemIDs[lower...upper])
                reviewSelectionAnchorID = anchorID
            } else {
                selectedMediaItemIDs = [itemID]
                reviewSelectionAnchorID = itemID
            }
        } else if click.isCommandPressed {
            var selectedCompareIDs = selectedMediaItemIDs.intersection(compareIDSet)
            if selectedCompareIDs.contains(itemID) {
                selectedCompareIDs.remove(itemID)
            } else {
                selectedCompareIDs.insert(itemID)
            }
            selectedMediaItemIDs = selectedCompareIDs
            reviewSelectionAnchorID = itemID
        } else {
            selectedMediaItemIDs = [itemID]
            reviewSelectionAnchorID = itemID
        }

        focusedReviewItemID = itemID
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        activePane = .media
        if click.isDoubleClick {
            openFocusedReviewItem()
        }
    }

    func performCompareShortcut(_ key: String) {
        guard !comparingMediaItemIDs.isEmpty else { return }
        let uppercased = key.uppercased()

        switch uppercased {
        case "S":
            markCurrentComparisonSelectionForImport()
        case "C":
            markCurrentComparisonSelectionAsCandidate()
        case "X":
            excludeCurrentComparisonSelectionFromImport()
        case "D":
            unmarkCurrentComparisonSelectionForImport()
        case "R":
            toggleRawForCurrentMediaSelection()
        case "Q":
            removeFocusedComparisonItem()
        default:
            break
        }
    }

    func openCurrentSelection() {
        if workspaceMode == .archiveView {
            openSelectedArchiveItem()
            return
        }
        switch activePane {
        case .folders:
            guard selectedFolderNodeIDs.count == 1, let nodeID = selectedFolderNodeIDs.first else { return }
            selectSidebarNode(nodeID)
        case .sidebar:
            focusReviewSurface()
        case .media:
            if isGroupedSectionKeyboardTargetActive {
                drillIntoFocusedInlineSection()
            } else {
                openFocusedReviewItem()
            }
        }
    }

    func navigateToParent() {
        if workspaceMode == .archiveView {
            switch archiveNavigationLevel {
            case .archive:
                return
            case .trip:
                archiveNavigationLevel = .archive
                activeArchiveContentNode = nil
                selectedSidebarNodeID = preferredSidebarNodeID(for: .archiveView)
            case .photos(let path, let parentTripPath):
                let returnPhotoID = archiveSearchReturnPhotoID
                cancelArchiveMediaLoad()
                archiveSearchReturnPhotoID = nil
                activeArchiveContentNode = nil
                archiveMediaCache.removeAll()
                if let returnPhotoID, hasArchiveSearchQuery {
                    archiveNavigationLevel = .archive
                    selectedArchiveSearchTarget = .photo(returnPhotoID)
                    selectedArchiveSearchResultID = returnPhotoID
                    reconcileArchiveSelection()
                } else if let parentTripPath {
                    archiveNavigationLevel = .trip(path: parentTripPath)
                    selectedArchiveEntryID = archiveBrowseContent.tripsByPath[parentTripPath]?.id
                    selectedArchiveWalkID = archiveCatalogue.walksByTripPath[parentTripPath]?.first(where: { $0.archiveRelativePath == path })?.id
                        ?? archiveCatalogue.walksByTripPath[parentTripPath]?.first?.id
                } else {
                    archiveNavigationLevel = .archive
                    selectedArchiveEntryID = filteredArchiveEntries.filter {
                        path == $0.archiveRelativePath || path.hasPrefix($0.archiveRelativePath + "/")
                    }.max { $0.archiveRelativePath.count < $1.archiveRelativePath.count }?.id ?? selectedArchiveEntryID
                }
                selectedSidebarNodeID = preferredSidebarNodeID(for: .archiveView)
                clearDetailSelections()
            }
            archiveGridNavigator.reset()
            activePane = .media
            archiveBrowseFocusRevision &+= 1
            refreshArchiveBrowserState()
            refreshAllUIState()
            return
        }
        guard let parentID = selectedBrowserNode?.parentID else { return }
        selectSidebarNode(parentID)
    }

    func clearCurrentSelection() {
        if !comparingMediaItemIDs.isEmpty {
            deselectComparisonItems()
            return
        }
        switch activePane {
        case .sidebar:
            break
        case .folders:
            selectedFolderNodeIDs.removeAll()
        case .media:
            selectedMediaItemIDs.removeAll()
            reviewSelectionAnchorID = nil
        }
    }

    func markCurrentSelectionForImport() {
        if !comparingMediaItemIDs.isEmpty {
            markCurrentComparisonSelectionForImport()
            return
        }
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        let editableIDs = editableTriageMediaIDs(from: selectedIDs)
        guard !editableIDs.isEmpty else {
            statusMessage = "Selected item(s) are already copied; S/C/X is locked for them."
            return
        }
        updateTriageState(for: editableIDs, selectionState: .included)
        statusMessage = triageStatusMessage(action: "Selected", editableCount: editableIDs.count, totalCount: selectedIDs.count, suffix: "for import.")
        advanceAfterTriageAction(for: editableIDs)
    }

    func excludeCurrentSelectionFromImport() {
        if !comparingMediaItemIDs.isEmpty {
            excludeCurrentComparisonSelectionFromImport()
            return
        }
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        let editableIDs = editableTriageMediaIDs(from: selectedIDs)
        guard !editableIDs.isEmpty else {
            statusMessage = "Selected item(s) are already copied; S/C/X is locked for them."
            return
        }
        updateTriageState(for: editableIDs, selectionState: .excluded)
        statusMessage = triageStatusMessage(action: "Excluded", editableCount: editableIDs.count, totalCount: selectedIDs.count, suffix: "from import.")
        advanceAfterTriageAction(for: editableIDs)
    }

    func markCurrentSelectionAsCandidate() {
        if !comparingMediaItemIDs.isEmpty {
            markCurrentComparisonSelectionAsCandidate()
            return
        }
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        let editableIDs = editableTriageMediaIDs(from: selectedIDs)
        guard !editableIDs.isEmpty else {
            statusMessage = "Selected item(s) are already copied; S/C/X is locked for them."
            return
        }
        updateTriageState(for: editableIDs, selectionState: .candidate)
        statusMessage = triageStatusMessage(action: "Marked", editableCount: editableIDs.count, totalCount: selectedIDs.count, suffix: "as candidates.")
        advanceAfterTriageAction(for: editableIDs)
    }

    func unmarkCurrentSelectionForImport() {
        if !comparingMediaItemIDs.isEmpty {
            unmarkCurrentComparisonSelectionForImport()
            return
        }
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        let editableIDs = editableTriageMediaIDs(from: selectedIDs)
        guard !editableIDs.isEmpty else {
            statusMessage = "Selected item(s) are already copied; S/C/X is locked for them."
            return
        }
        updateTriageState(for: editableIDs, selectionState: .undecided)
        statusMessage = triageStatusMessage(action: "Cleared", editableCount: editableIDs.count, totalCount: selectedIDs.count, suffix: "back to undecided.")
    }

    func toggleRawForCurrentMediaSelection() {
        guard canMutateImportSelection else { return }
        guard let currentSession else { return }
        var updated = sessionMutationCoordinator.sessionByTogglingRawCompanions(currentSession, selectedIDs: currentSelectionMediaIDs())
        updated.proposedWalks = []
        save(updated)
    }

    func markComparisonItemForImport(_ itemID: UUID) {
        focusComparisonItem(itemID)
        markCurrentComparisonSelectionForImport()
    }

    func markComparisonItemAsCandidate(_ itemID: UUID) {
        focusComparisonItem(itemID)
        markCurrentComparisonSelectionAsCandidate()
    }

    func excludeComparisonItemFromImport(_ itemID: UUID) {
        focusComparisonItem(itemID)
        excludeCurrentComparisonSelectionFromImport()
    }

    func clearComparisonItemTriageState(_ itemID: UUID) {
        focusComparisonItem(itemID)
        unmarkCurrentComparisonSelectionForImport()
    }

    func markPreviewItemForImport(_ itemID: UUID) {
        updatePreviewItemTriageState(itemID, selectionState: .included, action: "Selected", suffix: "for import.")
    }

    func markPreviewItemAsCandidate(_ itemID: UUID) {
        updatePreviewItemTriageState(itemID, selectionState: .candidate, action: "Marked", suffix: "as candidate.")
    }

    func excludePreviewItemFromImport(_ itemID: UUID) {
        updatePreviewItemTriageState(itemID, selectionState: .excluded, action: "Excluded", suffix: "from import.")
    }

    func clearPreviewItemTriageState(_ itemID: UUID) {
        updatePreviewItemTriageState(itemID, selectionState: .undecided, action: "Cleared", suffix: "back to undecided.")
    }

    func toggleRawForPreviewItem(_ itemID: UUID) {
        guard canMutateImportSelection else { return }
        guard let item = currentSession?.mediaItems.first(where: { $0.id == itemID }) else { return }
        guard !item.companionFiles.isEmpty else { return }
        guard !item.lifecycleState.isImportedOrBeyond else {
            statusMessage = "This photo is already copied; RAW changes are locked."
            return
        }
        setImportRawCompanions(for: item, enabled: !item.importRawCompanions)
        selectedMediaItemIDs = [itemID]
        focusedReviewItemID = itemID
        reviewSelectionAnchorID = itemID
        activePane = .media
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        statusMessage = item.importRawCompanions ? "RAW companion import cleared for this photo." : "RAW companion import enabled for this photo."
    }

    private func showBackupRecoveryFailure(_ error: Error) {
        backupPersistenceGate.block(error.localizedDescription)
        startupAlert = AppStartupAlert(title: "App Backup Recovery Required",
            message: "Saved state is protected until recovery succeeds. The recovery record has been retained. Retry after resolving the storage problem.\n\n" + error.localizedDescription,
            recoveryAction: .retryBackupRecovery)
        statusMessage = "Backup recovery required: " + error.localizedDescription
    }

    private func checkBackupIdle() throws {
        try backupPersistenceGate.check()
        guard hasDurableSessionPersistence else {
            throw BackupRecoveryError.invalid("Persistent session storage is unavailable. Recover local storage before exporting or restoring an app backup.")
        }
        guard !importOperation.isRunning, !isDescribing, !isDeliveringGooglePhotos, !isConnectingGooglePhotos,
              !isSavingLocation, !isSavingTripLocation, !sourceCleanupIsRunning, !archiveBackfillIsRunning, !archiveMaintenanceIsRunning, cropOperationItemIDs.isEmpty else {
            throw BackupRecoveryError.invalid("Finish the active Copy, description, delivery or Archive operation before using an app backup.")
        }
    }

    func exportBackup(to url: URL) throws {
        try checkBackupIdle()
        try flushPendingSessionPersistenceOrThrow()
        let sessions = try sessionStore.loadBackupSnapshot()
        _ = try settingsStore.loadBackupSnapshot(defaults: settings)
        try backupStore.exportBackup(settings: settings, sessions: sessions, to: url)
        statusMessage = "Exported app backup to \(url.path)."
    }

    func restoreBackup(from url: URL) throws {
        try checkBackupIdle()
        let backup = try backupStore.importBackup(from: url)
        try flushPendingSessionPersistenceOrThrow()
        guard !(currentSession.map(hasRecordedCopy) ?? false),
              !(try sessionStore.loadBackupSnapshot()).contains(where: { hasRecordedCopy($0.0) }) else {
            throw BackupRecoveryError.invalid("Finish recorded Copies before restoring a backup.")
        }
        let rawSessions = (sessionStore as? BackupGuardedSessionStore)?.base ?? sessionStore
        let rawSettings = (settingsStore as? BackupGuardedSettingsStore)?.base ?? settingsStore
        if backupRestoreCoordinator.hasRecoveryRecord {
            try backupRestoreCoordinator.recover(sessions: rawSessions, settings: rawSettings)
        }
        let warning: String?
        do {
            warning = try backupRestoreCoordinator.restore(backup, currentSettings: settings, sessions: rawSessions, settings: rawSettings)
        } catch {
            if backupPersistenceGate.blockedReason != nil { showBackupRecoveryFailure(error) }
            throw error
        }
        publishRestoredBackup(backup)
        statusMessage = "Imported app backup from \(url.lastPathComponent)." + (warning.map { " " + $0 } ?? "")
    }

    private func publishRestoredBackup(_ backup: AppBackupDocument) {
        pendingSessionPersistence.forEach { $0.workItem.cancel() }; pendingSessionPersistence = []
        restoredStateGeneration &+= 1
        invalidateInFlightSourceLoad()
        invalidateArchiveContext()
        archiveCatalogueLoadTask?.cancel(); archiveCatalogueLoadTask = nil; archiveCatalogueLoadGeneration &+= 1
        archiveSearchTask?.cancel(); archiveSearchTask = nil
        googleContext.invalidate(); cancelGoogleDelivery(); cancelGoogleSignIn(); googleDeliveryReview = nil
        googleAccount = nil; googleDeliveryJobs = []; googleQueue = nil
        cancelDescriptions(); descriptionQueue = nil; descriptionJobs = []
        originalViewingTasks.values.forEach { $0.cancel() }; originalViewingTasks.removeAll(); originalViewingOperationIDs.removeAll()
        originalViewingRevision &+= 1
        thumbnailDecodeTasks.values.forEach { $0.cancel() }; thumbnailDecodeTasks.removeAll()
        thumbnailTasks.values.forEach { $0.cancel() }; thumbnailTasks.removeAll()
        archiveMediaCache.removeAll(); archiveCatalogue = .empty; archiveSearchMatchingPaths = []
        activeArchiveContentNode = nil; selectedArchiveEntryID = nil; selectedArchiveWalkID = nil; selectedArchiveSearchResultID = nil
        clearDetailSelections(); selectedSidebarNodeID = nil
        previewingMediaItemID = nil; comparingMediaItemIDs = []
        activePhotoLogMembershipEditID = nil; compareSelectionBackup = nil
        activePhotoLogEditor = nil; activeWalkCommitEditor = nil
        currentSession = nil; burstGroups = []; timeClusters = []
        sourceWorkspaceState = .idle
        settings = backup.settings
        ArchiveByteReadPolicyContext.shared.update(settings: settings)
        persistedSessions = backup.records.sorted { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }
        persistedSessionsGeneration &+= 1; invalidateSourceLogOwnershipCache()
        previewStore = (try? PreviewStore(cacheRoot: settings.cacheRoot)) ?? NoCachePreviewStore(cacheRoot: settings.cacheRoot)
        archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
        browserViewModel.invalidateArchiveTreeCache()
        if let latest = persistedSessions.first { openPersistedSessionRecord(latest, status: "Restored saved session.") }
        refreshAllUIState()
        reloadArchiveCatalogue()
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "photo-diary-triage-backup.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try exportBackup(to: url)
        } catch {
            statusMessage = "Backup export failed: \(error.localizedDescription)"
        }
    }

    func importBackup() {
        do { try checkBackupIdle() }
        catch { statusMessage = "Backup import failed: " + error.localizedDescription; return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.urls.first else { return }
        do { try restoreBackup(from: url) }
        catch { statusMessage = "Backup import failed: " + error.localizedDescription }
    }

    func importOneDrivePhotoLogState() {
        do {
            let records = try photoLogSyncStore.importRecords(
                from: settings.oneDrivePicturesRoot,
                localArchiveRoot: settings.archiveRoot,
                localOneDrivePicturesRoot: settings.oneDrivePicturesRoot,
                localMachineRole: settings.archiveMachineRole
            )
            guard !records.isEmpty else {
                statusMessage = "No synced photo-log state files found in \(settings.oneDrivePicturesRoot.path)."
                return
            }

            try flushPendingSessionPersistenceOrThrow()
            let existing = try sessionStore.loadSessions()
            var existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.0.id, $0) })
            var importedCount = 0
            for record in records {
                let incoming = record.document.session
                if let current = existingByID[incoming.id], hasRecordedCopy(current.0) { continue }
                if let current = existingByID[incoming.id],
                   current.0.lastUpdatedAt > incoming.lastUpdatedAt {
                    continue
                }
                let replacement = (incoming, record.document.bursts, record.document.timeClusters)
                existingByID[incoming.id] = replacement
                try flushPendingSessionPersistenceOrThrow()
                try sessionManager.save(incoming, bursts: record.document.bursts, clusters: record.document.timeClusters, to: sessionStore)
                importedCount += 1
            }

            try reloadPersistedSessionsFromStore()
            browserViewModel.invalidateArchiveTreeCache()
            loadMostRecentSession(statusPrefix: "Imported \(importedCount) synced photo-log state file(s) from OneDrive.")
        } catch {
            statusMessage = "OneDrive photo-log state import failed: \(error.localizedDescription)"
        }
    }

    private func updateTriageState(for mediaIDs: Set<UUID>, selectionState: SelectionState) {
        guard let currentSession else { return }
        var updated = sessionMutationCoordinator.sessionByUpdatingTriageState(currentSession, mediaIDs: mediaIDs, selectionState: selectionState)
        updated.proposedWalks = []
        save(updated)
    }

    private func updatePreviewItemTriageState(_ itemID: UUID, selectionState: SelectionState, action: String, suffix: String) {
        guard canMutateImportSelection else { return }
        guard currentSession?.mediaItems.contains(where: { $0.id == itemID }) == true else { return }
        let editableIDs = editableTriageMediaIDs(from: [itemID])
        guard !editableIDs.isEmpty else {
            statusMessage = "This photo is already copied; S/C/X is locked for it."
            return
        }
        updateTriageState(for: editableIDs, selectionState: selectionState)
        selectedMediaItemIDs = [itemID]
        focusedReviewItemID = itemID
        reviewSelectionAnchorID = itemID
        previewingMediaItemID = itemID
        activePane = .media
        reviewKeyboardTarget = .items
        reviewGridHasFocus = true
        statusMessage = "\(action) previewed photo \(suffix)"
    }

    private func editableTriageMediaIDs(from mediaIDs: Set<UUID>) -> Set<UUID> {
        Set(mediaIDs.filter { mediaID in
            guard let item = mediaItem(for: mediaID) else { return false }
            return !item.lifecycleState.isImportedOrBeyond
        })
    }

    private func triageStatusMessage(action: String, editableCount: Int, totalCount: Int, suffix: String) -> String {
        let lockedCount = totalCount - editableCount
        if lockedCount > 0 {
            return "\(action) \(editableCount) item(s) \(suffix) \(lockedCount) copied item(s) were left unchanged."
        }
        return "\(action) \(editableCount) item(s) \(suffix)"
    }

    private func currentComparisonSelectionIDs() -> Set<UUID> {
        let compareIDSet = Set(comparingMediaItemIDs)
        let selectedCompareIDs = selectedMediaItemIDs.intersection(compareIDSet)
        if !selectedCompareIDs.isEmpty {
            return selectedCompareIDs
        }
        if let focusedReviewItemID, compareIDSet.contains(focusedReviewItemID) {
            return [focusedReviewItemID]
        }
        return []
    }

    func proposedPhotoLogCreationPlan(mode: PhotoLogCreationMode) -> PhotoLogCreationPlan? {
        photoLogCreationResolver.resolve(
            currentSession: currentSession,
            activePane: activePane,
            selectedFolderNodeIDs: selectedFolderNodeIDs,
            selectedBrowserNode: selectedBrowserNode,
            browserNodeMap: browserNodeMap,
            visibleItems: visibleMediaItems,
            selectedMediaItemIDs: selectedMediaItemIDs,
            existingPhotoLogs: activePhotoLogSessions(),
            mode: mode
        )
    }

    private func activePhotoLogSessions() -> [ImportSession] {
        persistedSessions
            .map(\.0)
            .filter {
                $0.sessionKind == .walkDraft &&
                $0.sessionKindWasExplicit &&
                $0.status != "imported" &&
                $0.status != "source_cleaned"
            }
    }

    private func defaultPhotoLogScope(for session: ImportSession) -> PhotoLogScopeDescriptor {
        if let scope = session.photoLogScope {
            return scope
        }

        let dates = session.mediaItems.map(\.capturedAt).compactMap { $0 }
        return PhotoLogScopeDescriptor(
            kind: .folder,
            label: session.walkMetadata.title.nonEmpty ?? session.workspaceSourceFolder.lastPathComponent,
            sourceFolderPaths: [session.workspaceSourceFolder.path],
            startDate: dates.min(),
            endDate: dates.max()
        )
    }

    private func photoLogScope(from editor: PhotoLogEditorState, fallback: PhotoLogScopeDescriptor) -> PhotoLogScopeDescriptor {
        let label = editor.scopeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return PhotoLogScopeDescriptor(
            kind: editor.scopeKind,
            label: label.isEmpty ? fallback.label : label,
            sourceFolderPaths: editor.sourceFolderPaths.isEmpty ? fallback.sourceFolderPaths : editor.sourceFolderPaths,
            startDate: editor.scopeKind == .dateRange ? editor.startDate : fallback.startDate,
            endDate: editor.scopeKind == .dateRange ? editor.endDate : fallback.endDate
        )
    }

    private func photoLogHiddenSummary() -> String? {
        guard let currentSession, currentSession.sessionKind == .inbox else { return nil }
        let logs = activePhotoLogSessions().filter {
            $0.workspaceSourceFolder.standardizedFileURL.path == currentSession.workspaceSourceFolder.standardizedFileURL.path
        }
        guard !logs.isEmpty else { return nil }
        let hiddenCount = logs.reduce(0) { $0 + $1.mediaItems.count }
        return "\(hiddenCount) photo(s) in this source already belong to \(logs.count) photo log(s)."
    }

    private func rebuildInboxAfterDeletingPhotoLog(
        _ deletedLog: ImportSession,
        returning itemsToReturn: [MediaItem]
    ) -> (ImportSession, [BurstGroup], [TimeCluster]) {
        let existingInbox = persistedSessions.first {
            $0.0.id != deletedLog.id &&
            $0.0.sessionKind == .inbox &&
            $0.0.workspaceSourceFolder.standardizedFileURL.path == deletedLog.workspaceSourceFolder.standardizedFileURL.path
        }?.0

        var mergedItems = existingInbox?.mediaItems ?? []
        let existingPaths = Set(mergedItems.map(\.relativePath))
        mergedItems.append(contentsOf: itemsToReturn.filter { !existingPaths.contains($0.relativePath) })
        mergedItems = MediaItemSort.sorted(mergedItems)
        let grouped = groupingService.group(items: mergedItems, settings: settings)

        var inbox = existingInbox ?? ImportSession(
            sourceFolder: deletedLog.sourceFolder,
            workspaceSourceFolder: deletedLog.workspaceSourceFolder,
            archiveRoot: deletedLog.archiveRoot,
            oneDrivePicturesRoot: deletedLog.oneDrivePicturesRoot,
            archiveMachineRole: deletedLog.archiveMachineRole,
            sessionKind: .inbox,
            status: "draft"
        )
        inbox.mediaItems = grouped.items
        inbox.lastUpdatedAt = Date()
        inbox.walkMetadata = .empty
        inbox.photoLogScope = nil
        inbox.sessionKind = .inbox
        inbox.sessionKindWasExplicit = true
        inbox.status = grouped.items.isEmpty ? "inbox_empty" : "draft"
        return (inbox, grouped.burstGroups, grouped.timeClusters)
    }

    private func currentSelectionMediaIDs() -> Set<UUID> {
        if !comparingMediaItemIDs.isEmpty {
            let compareIDSet = Set(comparingMediaItemIDs)
            let selectedCompareIDs = selectedMediaItemIDs.intersection(compareIDSet)
            if !selectedCompareIDs.isEmpty {
                return selectedCompareIDs
            }
            if let focusedReviewItemID, compareIDSet.contains(focusedReviewItemID) {
                return [focusedReviewItemID]
            }
            return []
        }

        switch activePane {
        case .media:
            if !selectedMediaItemIDs.isEmpty {
                return selectedMediaItemIDs
            }
            if let focusedReviewItemID {
                return [focusedReviewItemID]
            }
            return []
        case .folders:
            let ids = selectedFolderNodeIDs.compactMap { browserNodeMap[$0]?.mediaItemIDs }
            return Set(ids.flatMap { $0 })
        case .sidebar:
            return Set(visibleMediaItems.map(\.id))
        }
    }

    private func clearDetailSelections() {
        selectedFolderNodeIDs.removeAll()
        selectedMediaItemIDs.removeAll()
        focusedReviewItemID = nil
        reviewSelectionAnchorID = nil
        reviewGridHasFocus = false
        reviewKeyboardTarget = .items
        drilledInlineSectionID = nil
        drilledInlineSectionMediaItemIDs = []
        focusedInlineSectionID = nil
        pendingInlineSectionScrollTargetID = nil
    }

    private func reviewSelectionState() -> ReviewSelectionState {
        ReviewSelectionState(
            selectedMediaItemIDs: selectedMediaItemIDs,
            focusedReviewItemID: focusedReviewItemID,
            reviewSelectionAnchorID: reviewSelectionAnchorID,
            activePane: activePane,
            reviewGridHasFocus: reviewGridHasFocus
        )
    }

    private func applyReviewSelectionState(_ state: ReviewSelectionState) {
        withCoalescedRefreshes {
            let previousFocusedReviewItemID = focusedReviewItemID
            selectedMediaItemIDs = state.selectedMediaItemIDs
            focusedReviewItemID = state.focusedReviewItemID
            reviewSelectionAnchorID = state.reviewSelectionAnchorID
            activePane = state.activePane
            reviewGridHasFocus = state.reviewGridHasFocus
            if state.activePane == .media, state.reviewGridHasFocus {
                reviewKeyboardTarget = .items
            }
            if state.activePane == .media,
               state.reviewGridHasFocus,
               focusedReviewItemID != previousFocusedReviewItemID {
                requestReviewScrollIfNeeded(to: focusedReviewItemID)
            }
        }
    }

    private func resetInlineExpansionState() {
        if dayDetailDisplayMode == .sections {
            expandedInlineSectionIDs = Set(inlineSectionOrganizer.flattenSectionIDs(from: organizedInlineSections))
        } else {
            expandedInlineSectionIDs.removeAll()
        }
        pendingInlineSectionScrollTargetID = nil
        estimatedVisibleReviewIndexRange = nil

        if dayDetailDisplayMode == .sections {
            ensureFocusedInlineSection()
        } else {
            focusedInlineSectionID = nil
        }
        reconcileReviewSelectionWithVisibleItems()
    }

    private func expandInlineSectionsForGroupedReviewIfNeeded() {
        guard dayDetailDisplayMode == .sections, expandedInlineSectionIDs.isEmpty else { return }
        expandedInlineSectionIDs = Set(inlineSectionOrganizer.flattenSectionIDs(from: organizedInlineSections))
    }

    private var inlineSectionOrganizer: InlineSectionOrganizer {
        InlineSectionOrganizer(burstGroups: burstGroups)
    }

    private func regroupCurrentSession(statusPrefix: String) {
        guard var session = currentSession else {
            statusMessage = "\(statusPrefix); new sessions will use the saved thresholds."
            return
        }

        let previousSidebarNodeID = selectedSidebarNodeID
        let previousFolderNodeIDs = selectedFolderNodeIDs
        let previousMediaItemIDs = selectedMediaItemIDs
        let previousFocusedReviewItemID = focusedReviewItemID
        let previousSelectionAnchorID = reviewSelectionAnchorID
        let previousActivePane = activePane
        let previousReviewFocus = reviewGridHasFocus

        let grouped = groupingService.group(items: session.mediaItems, settings: settings)
        session.mediaItems = grouped.items
        burstGroups = grouped.burstGroups
        timeClusters = grouped.timeClusters
        setCurrentSession(session, updateKind: .sessionOnly)

        let fallbackSidebarNodeID = preferredSidebarNodeID(for: workspaceMode)
        selectedSidebarNodeID = previousSidebarNodeID.flatMap { browserNodeMap[$0] == nil ? nil : $0 } ?? fallbackSidebarNodeID
        archiveMediaCache.removeAll()
        restoreGroupingDependentUIState(
            previousFolderNodeIDs: previousFolderNodeIDs,
            previousMediaItemIDs: previousMediaItemIDs,
            previousFocusedReviewItemID: previousFocusedReviewItemID,
            previousSelectionAnchorID: previousSelectionAnchorID,
            previousActivePane: previousActivePane,
            previousReviewFocus: previousReviewFocus
        )
        save(session)

        statusMessage = "\(statusPrefix) to bursts <= \(Self.formatSeconds(settings.burstThresholdSeconds)) and clusters <= \(Self.formatSeconds(settings.proximityThresholdSeconds)); regrouped current session."
    }

    private func restoreGroupingDependentUIState(
        previousFolderNodeIDs: Set<String>,
        previousMediaItemIDs: Set<UUID>,
        previousFocusedReviewItemID: UUID?,
        previousSelectionAnchorID: UUID?,
        previousActivePane: ActivePane,
        previousReviewFocus: Bool
    ) {
        resetInlineExpansionState()

        selectedFolderNodeIDs = Set(previousFolderNodeIDs.filter { browserNodeMap[$0] != nil })

        let visibleIDSet = Set(visibleMediaItems.map(\.id))
        selectedMediaItemIDs = previousMediaItemIDs.intersection(visibleIDSet)

        if let previousFocusedReviewItemID, visibleIDSet.contains(previousFocusedReviewItemID) {
            focusedReviewItemID = previousFocusedReviewItemID
        } else if let retainedSelection = selectedMediaItemIDs.first {
            focusedReviewItemID = retainedSelection
        } else {
            focusedReviewItemID = nil
        }

        if let previousSelectionAnchorID, visibleIDSet.contains(previousSelectionAnchorID) {
            reviewSelectionAnchorID = previousSelectionAnchorID
        } else {
            reviewSelectionAnchorID = selectedMediaItemIDs.first
        }

        switch previousActivePane {
        case .folders where !selectedFolderNodeIDs.isEmpty:
            activePane = .folders
        case .media where !visibleIDSet.isEmpty:
            activePane = .media
        default:
            activePane = .sidebar
        }

        reviewGridHasFocus = previousReviewFocus && activePane == .media && !visibleIDSet.isEmpty
        reviewKeyboardTarget = .items
    }

    private func enterFocusedInlineSection() {
        guard let section = focusedInlineSection else { return }
        if !expandedInlineSectionIDs.contains(section.id) {
            expandedInlineSectionIDs.insert(section.id)
            reconcileReviewSelectionWithVisibleItems()
        }
        guard let targetID = resolvedMediaItemIDs(in: section).first else { return }
        selectInlineMediaItem(targetID)
        focusedInlineSectionID = section.id
        statusMessage = "Entered \(section.title)."
    }

    private func resolvedMediaItemIDs(in section: InlineSection) -> [UUID] {
        if !section.photoItemIDs.isEmpty {
            return section.photoItemIDs
        }

        if !section.mediaItemIDs.isEmpty {
            return section.mediaItemIDs
        }

        return section.children.flatMap { resolvedMediaItemIDs(in: $0) }
    }

    private func loadMostRecentSession(statusPrefix: String = "Recovered most recent session from local SQLite store.") {
        do {
            try reloadPersistedSessionsFromStore()
            guard let latest = mostRecentRecoverableSession() ?? persistedSessions.first else {
                sourceWorkspaceState = .idle
                return
            }
            invalidateInFlightSourceLoad()
            sourceWorkspaceState = .idle
            openPersistedSessionRecord(latest, status: sourceLoadStatusMessage(base: statusPrefix, sourcePath: latest.0.workspaceSourceFolder.path))
        } catch {
            logger.error("Failed to recover recent session: \(error.localizedDescription, privacy: .public)")
            sourceWorkspaceState = .failed(sourcePath: settings.defaultSourceRoot.path, message: error.localizedDescription)
            statusMessage = "Failed to recover the most recent session: \(error.localizedDescription)"
            return
        }
    }

    private func primePersistedSessionCache() {
        do {
            try reloadPersistedSessionsFromStore()
        } catch {
            logger.error("Failed to prime persisted session cache: \(error.localizedDescription, privacy: .public)")
            sourceWorkspaceState = .failed(sourcePath: settings.defaultSourceRoot.path, message: error.localizedDescription)
            statusMessage = "Failed to read saved sessions: \(error.localizedDescription)"
        }
    }

    private func persistCurrentSession(immediately: Bool = false) {
        guard backupPersistenceGate.blockedReason == nil, let currentSession else { return }
        if activePhotoLogMembershipEditID == currentSession.id {
            persistPhotoLogMembershipEdit(currentSession, immediately: immediately)
            return
        }
        let session = currentSession
        let bursts = burstGroups
        let clusters = timeClusters
        let sessionManager = self.sessionManager
        let sessionStore = self.sessionStore
        let logger = self.logger
        storePersistedSession(session, bursts: bursts, clusters: clusters)

        supersedePendingSessionPersistence(owners: [session.id])
        let outcome = SessionPersistenceOutcome()
        let workItem = DispatchWorkItem { [weak self] in
            do {
                try outcome.perform {
                    try sessionManager.save(session, bursts: bursts, clusters: clusters, to: sessionStore)
                }
            } catch {
                logger.error("Failed to persist current session: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self?.statusMessage = "Session save failed: \(error.localizedDescription)"
                }
            }
        }
        pendingSessionPersistence.append(.init(owners: [session.id], workItem: workItem, outcome: outcome))

        let deadline: DispatchTime = immediately ? .now() : .now() + .milliseconds(160)
        sessionPersistenceQueue.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func mergedSourceProvenances(_ first: [SourceProvenance], _ second: [SourceProvenance]) -> [SourceProvenance] {
        var seen = Set<UUID>()
        return (first + second).filter { seen.insert($0.id).inserted }
    }

    private func persistPhotoLogMembershipEdit(_ editingSession: ImportSession, immediately: Bool = false) {
        let sessionID = editingSession.id
        let memberItems = editingSession.mediaItems.filter {
            !$0.selectionState.isUndecided || $0.lifecycleState.isImportedOrBeyond
        }
        let returnedItems = editingSession.mediaItems.filter {
            $0.selectionState.isUndecided && !$0.lifecycleState.isImportedOrBeyond
        }
        let memberPaths = Set(memberItems.map(\.relativePath))
        let workspacePath = editingSession.workspaceSourceFolder.standardizedFileURL.path
        let existingInbox = persistedSessions.first {
            $0.0.id != sessionID &&
            $0.0.sessionKind == .inbox &&
            $0.0.workspaceSourceFolder.standardizedFileURL.path == workspacePath
        }?.0

        let returnedPaths = Set(returnedItems.map(\.relativePath))
        var inboxItems = (existingInbox?.mediaItems ?? []).filter {
            !memberPaths.contains($0.relativePath) && !returnedPaths.contains($0.relativePath)
        }
        inboxItems.append(contentsOf: returnedItems)
        inboxItems = MediaItemSort.sorted(inboxItems)

        let memberGrouped = groupingService.group(items: MediaItemSort.sorted(memberItems), settings: settings)
        let inboxGrouped = groupingService.group(items: inboxItems, settings: settings)

        var updatedLog = editingSession
        updatedLog.mediaItems = memberGrouped.items
        updatedLog.lastUpdatedAt = Date()
        updatedLog.status = memberGrouped.items.isEmpty ? "draft_empty" : "draft"

        var updatedInbox = existingInbox ?? ImportSession(
            sourceFolder: editingSession.sourceFolder,
            workspaceSourceFolder: editingSession.workspaceSourceFolder,
            archiveRoot: editingSession.archiveRoot,
            oneDrivePicturesRoot: editingSession.oneDrivePicturesRoot,
            archiveMachineRole: editingSession.archiveMachineRole,
            sessionKind: .inbox,
            status: "draft",
            sourceProvenances: editingSession.sourceProvenances
        )
        updatedInbox.sourceProvenances = mergedSourceProvenances(updatedInbox.sourceProvenances, editingSession.sourceProvenances)
        updatedInbox.mediaItems = inboxGrouped.items
        updatedInbox.lastUpdatedAt = Date()
        updatedInbox.walkMetadata = .empty
        updatedInbox.photoLogScope = nil
        updatedInbox.sessionKind = .inbox
        updatedInbox.sessionKindWasExplicit = true
        updatedInbox.status = inboxGrouped.items.isEmpty ? "inbox_empty" : "draft"

        storePersistedSession(updatedLog, bursts: memberGrouped.burstGroups, clusters: memberGrouped.timeClusters)
        storePersistedSession(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters)

        supersedePendingSessionPersistence(owners: [updatedLog.id, updatedInbox.id])
        let sessionStore = self.sessionStore
        let logger = self.logger
        let outcome = SessionPersistenceOutcome()
        let workItem = DispatchWorkItem { [weak self] in
            do {
                try outcome.perform {
                    try sessionStore.saveSessions([(updatedLog, memberGrouped.burstGroups, memberGrouped.timeClusters),
                                                   (updatedInbox, inboxGrouped.burstGroups, inboxGrouped.timeClusters)])
                }
            } catch {
                logger.error("Failed to persist photo log membership edit: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self?.statusMessage = "Photo log membership save failed: \(error.localizedDescription)"
                }
            }
        }
        pendingSessionPersistence.append(.init(owners: [updatedLog.id, updatedInbox.id], workItem: workItem, outcome: outcome))

        let deadline: DispatchTime = immediately ? .now() : .now() + .milliseconds(160)
        sessionPersistenceQueue.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func supersedePendingSessionPersistence(owners: Set<UUID>) {
        // A fresh snapshot may replace only the same complete set of owners.
        // Editing B must never cancel or conceal a failed save for A.
        pendingSessionPersistence.filter { $0.owners == owners }.forEach { $0.workItem.cancel() }
        pendingSessionPersistence.removeAll { $0.owners == owners }
    }

    private func flushPendingSessionPersistence() {
        let jobs = pendingSessionPersistence
        sessionPersistenceQueue.sync { jobs.forEach { $0.workItem.perform() } }
        pendingSessionPersistence.removeAll { job in
            do { try job.outcome.check(); job.workItem.cancel(); return true }
            catch { return false }
        }
    }

    private func flushPendingSessionPersistenceOrThrow() throws {
        try backupPersistenceGate.check()
        let jobs = pendingSessionPersistence
        sessionPersistenceQueue.sync { jobs.forEach { $0.workItem.perform() } }
        for job in jobs { try job.outcome.check() }
        jobs.forEach { $0.workItem.cancel() }
        pendingSessionPersistence = []
    }

    private func persistSettings() {
        do {
            try sessionLifecycleCoordinator.persistSettings(settings, to: settingsStore)
        } catch {
            logger.error("Failed to persist settings: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Settings save failed: \(error.localizedDescription)"
        }
    }

    private func reconcileSavedArchivePaths(syncChangedLogs: Bool) throws {
        try flushPendingSessionPersistenceOrThrow()
        let records = try sessionStore.loadSessions()
        let changed = try records.map { (try ArchiveSessionPathReconciler().reconcile($0.0), $0.1, $0.2) }
        try sessionStore.replaceAllSessions(with: changed)
        if syncChangedLogs {
            for (index, record) in changed.enumerated() where record.0 != records[index].0 {
                _ = try photoLogSyncStore.export(session: record.0, bursts: record.1, timeClusters: record.2,
                    to: settings.oneDrivePicturesRoot)
            }
        }
        if let currentSession {
            setCurrentSession(try ArchiveSessionPathReconciler().reconcile(currentSession), updateKind: .sessionOnly)
        }
        try reloadPersistedSessionsFromStore()
    }

    private func reloadPersistedSessionsFromStore() throws {
        try flushPendingSessionPersistenceOrThrow()
        let rawSessions = try sessionStore.loadSessions()
        let loadedSessions = try rawSessions.map { (try ArchiveSessionPathReconciler().reconcile($0.0), $0.1, $0.2) }
        if loadedSessions.map({ $0.0 }) != rawSessions.map({ $0.0 }) { try sessionStore.replaceAllSessions(with: loadedSessions) }
        let normalized = persistedSessionNormalizer.normalize(loadedSessions)
        if normalized.deduplicatedInboxCount > 0 {
            logger.log("Deduplicated \(normalized.deduplicatedInboxCount, privacy: .public) inbox session(s) while loading persisted sessions")
            try sessionStore.replaceAllSessions(with: normalized.records)
        }
        if normalized.legacyRecoveredSessionCount > 0 {
            logger.log("Reclassified \(normalized.legacyRecoveredSessionCount, privacy: .public) legacy session(s) as inbox recoveries")
            pendingLegacyMigrationNoticeCount = normalized.legacyRecoveredSessionCount
        }
        persistedSessions = normalized.records
        persistedSessionsGeneration &+= 1
        invalidateSourceLogOwnershipCache()
        refreshSidebarState()
    }

    private func storePersistedSession(_ session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) {
        persistedSessions.removeAll { $0.0.id == session.id }
        persistedSessions.append((session, bursts, clusters))
        persistedSessions.sort { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }
        persistedSessionsGeneration &+= 1
        invalidateSourceLogOwnershipCache()
        refreshSidebarState()
    }

    private func openPersistedSessionRecord(
        _ record: (ImportSession, [BurstGroup], [TimeCluster]),
        status: String,
        sourceArchiveCopiesByRelativePath: [String: SourceArchiveCopySnapshot] = [:]
    ) {
        let previousSidebarNodeID = selectedSidebarNodeID
        activePhotoLogMembershipEditID = nil
        self.sourceArchiveCopiesByRelativePath = sourceArchiveCopiesByRelativePath
        setCurrentSession(record.0, updateKind: .full)
        burstGroups = record.1
        timeClusters = record.2
        if workspaceMode == .cameraTriage {
            selectedSidebarNodeID = preferredSidebarNodeID(for: workspaceMode)
        } else {
            selectedSidebarNodeID = previousSidebarNodeID.flatMap { browserNodeMap[$0] == nil ? nil : $0 } ?? preferredSidebarNodeID(for: workspaceMode)
        }
        clearDetailSelections()
        if workspaceMode == .cameraTriage {
            archiveMediaCache.removeAll()
        }
        resetInlineExpansionState()
        statusMessage = status
    }

    @discardableResult
    private func invalidateInFlightSourceLoad() -> Int {
        sourceLoadTask?.cancel()
        sourceLoadTask = nil
        sourceLoadGeneration &+= 1
        return sourceLoadGeneration
    }

    private func sourceLoadStatusMessage(base: String, sourcePath: String) -> String {
        let notice: String
        if let migrationNotice = consumeLegacyMigrationNotice() {
            notice = " \(migrationNotice)"
        } else {
            notice = ""
        }
        return "\(base)\(notice)"
    }

    private func consumeLegacyMigrationNotice() -> String? {
        guard pendingLegacyMigrationNoticeCount > 0, hasShownLegacyMigrationNotice == false else { return nil }
        hasShownLegacyMigrationNotice = true
        let count = pendingLegacyMigrationNoticeCount
        pendingLegacyMigrationNoticeCount = 0
        return "Reclassified \(count) legacy session(s) as source inbox recoveries."
    }

    private func mostRecentRecoverableSession() -> (ImportSession, [BurstGroup], [TimeCluster])? {
        persistedSessions.first {
            $0.0.status != "imported" && $0.0.status != "source_cleaned"
        }
    }

    private func sourceLogOwnershipByRelativePath(
        for workspaceSourceFolder: URL,
        excludingSessionIDs: Set<UUID> = []
    ) -> [String: SourceLogOwnershipSnapshot] {
        let standardizedFolderPath = workspaceSourceFolder.standardizedFileURL.path
        var ownershipByPath: [String: SourceLogOwnershipSnapshot] = [:]

        for record in persistedSessions where
            record.0.sessionKind == .walkDraft &&
            record.0.sessionKindWasExplicit &&
            !excludingSessionIDs.contains(record.0.id) &&
            record.0.workspaceSourceFolder.standardizedFileURL.path == standardizedFolderPath {
            let title = record.0.walkMetadata.title.nonEmpty ?? "Untitled Photo Log"
            for item in record.0.mediaItems where ownershipByPath[item.relativePath] == nil {
                ownershipByPath[item.relativePath] = SourceLogOwnershipSnapshot(
                    title: title,
                    statusLabel: item.lifecycleState.isImportedOrBeyond ? "Copied" : "In Log",
                    selectionState: item.selectionState,
                    isCopied: item.lifecycleState.isImportedOrBeyond
                )
            }
        }

        return ownershipByPath
    }

    private func currentSourceLogOwnershipByRelativePath() -> [String: SourceLogOwnershipSnapshot] {
        guard let currentSession, currentSession.sessionKind == .inbox else { return [:] }
        let workspacePath = currentSession.workspaceSourceFolder.standardizedFileURL.path
        if cachedSourceLogOwnershipWorkspacePath == workspacePath,
           cachedSourceLogOwnershipExcludedSessionID == currentSession.id,
           cachedSourceLogOwnershipPersistedGeneration == persistedSessionsGeneration {
            return cachedSourceLogOwnershipByRelativePath
        }

        let ownership = sourceLogOwnershipByRelativePath(
            for: currentSession.workspaceSourceFolder,
            excludingSessionIDs: [currentSession.id]
        )
        cachedSourceLogOwnershipWorkspacePath = workspacePath
        cachedSourceLogOwnershipExcludedSessionID = currentSession.id
        cachedSourceLogOwnershipPersistedGeneration = persistedSessionsGeneration
        cachedSourceLogOwnershipByRelativePath = ownership
        return ownership
    }

    private func invalidateSourceLogOwnershipCache() {
        cachedSourceLogOwnershipWorkspacePath = nil
        cachedSourceLogOwnershipExcludedSessionID = nil
        cachedSourceLogOwnershipPersistedGeneration = -1
        cachedSourceLogOwnershipByRelativePath = [:]
    }

    private func rebuildInboxSession(
        from scanned: SessionOpenResult,
        workspaceSourceFolder: URL,
        existingInbox: ImportSession?,
        historical: HistoricalSourceContext? = nil
    ) -> ImportSession {
        let existing = existingInbox
        var provenance = existing?.sourceProvenances.first(where: {
            $0.folder.standardizedFileURL.path == workspaceSourceFolder.standardizedFileURL.path
        }) ?? SourceProvenance(folder: workspaceSourceFolder)
        if let historical { provenance.historical = historical }
        var mediaItems = scanned.session.mediaItems
        let previousByPath = Dictionary((existing?.mediaItems ?? []).map { ($0.sourceURL.standardizedFileURL.path, $0) }, uniquingKeysWith: { first, _ in first })
        for index in mediaItems.indices {
            let item = mediaItems[index]
            if let previous = previousByPath[item.sourceURL.standardizedFileURL.path],
               previous.fileSizeBytes == item.fileSizeBytes, previous.sourceModificationTime == item.sourceModificationTime {
                // Retain user decisions and stable IDs only for the same scanned file revision.
                var retained = previous
                retained.metadata = item.metadata
                retained.companionFiles = item.companionFiles.map { companion in
                    previous.companionFiles.first { $0.sourceURL.standardizedFileURL == companion.sourceURL.standardizedFileURL && $0.fileSizeBytes == companion.fileSizeBytes } ?? companion
                }
                retained.cropRelationship = item.cropRelationship
                retained.sourceModificationTime = item.sourceModificationTime
                if let historical { retained = HistoricalSourceHints.applying(to: retained, context: historical) }
                mediaItems[index] = retained
            } else if historical != nil {
                mediaItems[index].selectionState = .included
            }
        }
        for index in mediaItems.indices {
            mediaItems[index].sourceProvenanceID = provenance.id
        }
        return ImportSession(
            id: existing?.id ?? scanned.session.id,
            sourceFolder: scanned.session.sourceFolder,
            workspaceSourceFolder: workspaceSourceFolder,
            startedAt: existing?.startedAt ?? scanned.session.startedAt,
            lastUpdatedAt: Date(),
            walkMetadata: existing?.walkMetadata ?? scanned.session.walkMetadata,
            archiveRoot: scanned.session.archiveRoot,
            oneDrivePicturesRoot: scanned.session.oneDrivePicturesRoot,
            archiveMachineRole: scanned.session.archiveMachineRole,
            sessionKind: .inbox,
            status: "draft",
            mediaItems: mediaItems,
            sourceProvenances: [provenance],
            proposedWalks: [],
            weekdayTokenStyle: settings.weekdayTokenStyle
        )
    }

    private func applyArchiveCopySurvey(
        _ copiesByRelativePath: [String: SourceArchiveCopySnapshot],
        to inbox: ImportSession
    ) -> ImportSession {
        guard !copiesByRelativePath.isEmpty else { return inbox }

        var updatedInbox = inbox
        for index in updatedInbox.mediaItems.indices {
            let relativePath = updatedInbox.mediaItems[index].relativePath
            guard let archiveCopy = copiesByRelativePath[relativePath], archiveCopy.byteVerified else { continue }
            updatedInbox.mediaItems[index].recognisedArchiveCopy = true
            updatedInbox.mediaItems[index].lifecycleState = .verified
            updatedInbox.mediaItems[index].destinationURL = URL(fileURLWithPath: archiveCopy.archivePath)
            updatedInbox.mediaItems[index].archiveRelativePath = archiveCopy.archiveRelativePath
            updatedInbox.mediaItems[index].selectionState = .undecided
            updatedInbox.mediaItems[index].importRawCompanions = false
        }
        return updatedInbox
    }

    private func scanSourceFolder(for folder: URL, settings: AppSettings, historical: HistoricalSourceContext? = nil) async throws -> SessionOpenResult {
        if let testingSourceScanHandler {
            let result = try await testingSourceScanHandler(folder, settings)
            if let historical {
                try HistoricalSourceSafety.validate(root: historical.root, archiveRoot: settings.archiveRoot)
                let grouped = groupingService.group(items: result.session.mediaItems.map { item in
                    var item = HistoricalSourceHints.applying(to: item, context: historical); item.selectionState = .included; return item
                }, settings: settings)
                var session = result.session
                session.mediaItems = grouped.items
                session.walkMetadata.title = historical.proposedTripTitle ?? ""
                return SessionOpenResult(session: session, bursts: grouped.burstGroups, clusters: grouped.timeClusters)
            }
            return result
        }
        return try await Task.detached(priority: .userInitiated) {
            let sessionManager = SessionManager(scanner: FileScanner(), groupingService: GroupingService())
            return try sessionManager.openSession(for: folder, settings: settings, historical: historical)
        }.value
    }

    @discardableResult
    private func save(_ session: ImportSession, updateKind: CurrentSessionUpdateKind = .sessionOnly) -> Bool {
        guard backupPersistenceGate.blockedReason == nil else {
            statusMessage = "Recover the app backup before changing saved decisions."
            return false
        }
        if let previous = currentSession?.id == session.id ? currentSession : persistedSessions.first(where: { $0.0.id == session.id })?.0 {
            guard allowEditingCopyInputs(previous) else { return false }
        }
        if let previous = currentSession, previous.id == session.id,
           (previous.walkMetadata.title != session.walkMetadata.title
            || previous.walkMetadata.location != session.walkMetadata.location
            || previous.walkMetadata.notes != session.walkMetadata.notes
            || previous.walkMetadata.latitude != session.walkMetadata.latitude
            || previous.walkMetadata.longitude != session.walkMetadata.longitude) {
            do { try ArchiveManifestEditor().saveMetadata(for: session, previousMetadata: previous.walkMetadata) }
            catch { statusMessage = "Could not save Archive metadata: \(error.localizedDescription)"; return false }
        }
        var mutableSession = session
        mutableSession.lastUpdatedAt = Date()
        setCurrentSession(mutableSession, updateKind: updateKind)
        persistCurrentSession()
        return true
    }

    private func requestThumbnails(for items: [MediaItem]) {
        enqueueThumbnailRequests(items, priority: .background)
    }

    private func requestVisibleThumbnails(prefetching items: [MediaItem] = []) {
        let visible = visibleMediaItems
        let visibleIDs = Set(visible.map(\.id))

        if !visible.isEmpty {
            enqueueThumbnailRequests(visible, priority: .visible)
        }

        let backgroundItems = thumbnailPrefetchCandidates(from: items, excluding: visibleIDs)
        if !backgroundItems.isEmpty {
            enqueueThumbnailRequests(backgroundItems, priority: .background)
        }
    }

    private func requestInitialArchiveThumbnails(for items: [MediaItem]) {
        guard !items.isEmpty else { return }
        let limit = max(12, estimatedVisibleReviewPageCapacity() * 2)
        enqueueThumbnailRequests(Array(items.prefix(limit)), priority: .visible)
    }

    private func enqueueThumbnailRequests(_ items: [MediaItem], priority: ThumbnailPriority) {
        Task { [weak self] in
            guard let self else { return }
            let scheduled = await self.thumbnailScheduler.enqueue(items, priority: priority)
            self.startThumbnailTasks(for: scheduled)
        }
    }

    private func startThumbnailTasks(for items: [MediaItem]) {
        for item in items where thumbnailTasks[item.id] == nil {
            thumbnailTasks[item.id] = Task { [weak self] in
                guard let self else { return }
                let success = await self.previewStore.generateThumbnail(for: item)
                await self.finishThumbnail(itemID: item.id, success: success)
            }
        }
    }

    private func finishThumbnail(itemID: UUID, success: Bool) async {
        if success {
            thumbnailFailures.remove(itemID)
            if let item = mediaItem(for: itemID) {
                missingThumbnailPaths.remove(thumbnailURL(for: item).path)
                thumbnailImageCache.removeObject(forKey: thumbnailURL(for: item) as NSURL)
                await DecodedImagePipeline.shared.removeCachedImage(for: Self.thumbnailDecodeCacheKey(for: thumbnailURL(for: item)))
                decodeThumbnailIfNeeded(from: thumbnailURL(for: item), itemID: item.id)
            }
        } else {
            thumbnailFailures.insert(itemID)
            thumbnailRegistry.update(itemID: itemID, image: nil, isMissing: true)
            if previewStore.isPersistentCacheAvailable == false {
                statusMessage = "Preview cache unavailable; thumbnails are temporarily disabled."
            }
        }

        thumbnailTasks[itemID] = nil
        let scheduled = await thumbnailScheduler.complete(itemID)
        startThumbnailTasks(for: scheduled)
    }

    private func previewNavigationOffset(_ offset: Int) -> UUID? {
        let navigationItems = reviewInteractionItems.isEmpty ? (currentSession?.mediaItems ?? []) : reviewInteractionItems
        guard let currentID = previewingMediaItemID ?? focusedReviewItemID ?? selectedMediaItemIDs.first,
              let currentIndex = navigationItems.firstIndex(where: { $0.id == currentID }) else {
            return nil
        }
        let targetIndex = currentIndex + offset
        guard navigationItems.indices.contains(targetIndex) else { return nil }
        return navigationItems[targetIndex].id
    }

    private func rebuildSessionCaches(clearThumbnailCache: Bool) {
        sessionVisibleMediaCacheByNodeID.removeAll()
        invalidateReviewContentCaches()

        guard let currentSession else {
            sessionMediaByID = [:]
            archivePreviewByMediaItemID = [:]
            if clearThumbnailCache {
                thumbnailDecodeTasks.values.forEach { $0.cancel() }
                thumbnailDecodeTasks.removeAll()
                missingThumbnailPaths.removeAll()
                thumbnailImageCache.removeAllObjects()
                thumbnailRegistry.reset()
            }
            return
        }

        sessionMediaByID = Dictionary(uniqueKeysWithValues: currentSession.mediaItems.map { ($0.id, $0) })
        var previews: [UUID: [String]] = [:]
        for item in currentSession.mediaItems {
            if let destinationURL = item.destinationURL {
                previews[item.id, default: []].append(destinationURL.path)
            }
            for companion in item.companionFiles {
                if let destinationURL = companion.destinationURL {
                    previews[item.id, default: []].append(destinationURL.path)
                }
            }
        }
        archivePreviewByMediaItemID = previews.mapValues { $0.joined(separator: "\n") }
        if clearThumbnailCache {
            thumbnailDecodeTasks.values.forEach { $0.cancel() }
            thumbnailDecodeTasks.removeAll()
            missingThumbnailPaths.removeAll()
            thumbnailImageCache.removeAllObjects()
            thumbnailRegistry.reset()
        }
    }

    private func rebuildBrowserCaches() {
        cachedBrowserRoots = browserViewModel.browserRoots(
            currentSession: currentSession,
            bursts: burstGroups,
            clusters: timeClusters,
            archiveRoot: settings.archiveRoot,
            sourceWorkspaceState: sourceWorkspaceState,
            workspaceMode: workspaceMode
        )
        cachedBrowserNodeMap = browserViewModel.nodeMap(for: cachedBrowserRoots)
        if selectedSidebarNodeID.flatMap({ cachedBrowserNodeMap[$0] }) == nil {
            selectedSidebarNodeID = preferredSidebarNodeID(for: workspaceMode)
        }
        sessionVisibleMediaCacheByNodeID.removeAll()
        invalidateReviewContentCaches()
        invalidateInlineSectionCaches()
    }

    private func preferredSidebarNodeID(for mode: WorkspaceMode) -> String? {
        switch mode {
        case .archiveView, .archiveTriage:
            if browserNodeMap["archive-root"] != nil {
                return "archive-root"
            }
            if browserNodeMap["section-archive-library"] != nil {
                return "section-archive-library"
            }
            return browserRoots.first?.id
        case .cameraTriage, .photoLogs:
            let preferred = browserViewModel.preferredInitialSidebarNodeID(
                for: currentSession,
                bursts: burstGroups,
                clusters: timeClusters
            )
            return browserNodeMap[preferred] == nil ? browserRoots.first?.id : preferred
        }
    }

    private func statusMessage(for mode: WorkspaceMode) -> String {
        switch mode {
        case .archiveView:
            return "Archive View. Browse Trips and Unorganised Folders without changing their files."
        case .cameraTriage:
            if currentSession == nil {
                return "Camera Triage. Open a source folder to sort new photos into a photo log."
            }
            return "Camera Triage. Use S, C, and X to decide which source photos belong in the log."
        case .photoLogs:
            return "Photo Logs. Continue existing logs, add marked source decisions, or create a log from source triage."
        case .archiveTriage:
            return "Archive Triage. This mode is separated from source cleanup and is read-only in this build."
        }
    }

    private func shouldSwitchToCameraTriage(for origin: SourceLoadOrigin) -> Bool {
        switch origin {
        case .launchDefault, .mountedDefault:
            return false
        case .manualPicker, .historicalFolder, .savedWalkInbox, .openDefaultSource, .settingsDefaultRoot, .reloadCurrentSource, .addSource:
            return true
        }
    }

    /// Coalesces the snapshot refreshes triggered by a batch of related `@Published`
    /// mutations into a single refresh per domain. Each `refresh*State()` is a pure
    /// function of current state, so running it once at the end of the batch yields the
    /// same final snapshots as running it after every individual mutation — the
    /// intermediate publishes are wasted work. Runs synchronously: the batch flushes
    /// before the wrapped call returns, so callers and tests still observe up-to-date
    /// snapshots immediately afterward.
    @discardableResult
    private func withCoalescedRefreshes<T>(_ body: () -> T) -> T {
        refreshTransactionDepth += 1
        defer {
            refreshTransactionDepth -= 1
            if refreshTransactionDepth == 0 {
                flushPendingRefreshes()
            }
        }
        return body()
    }

    private func flushPendingRefreshes() {
        let kinds = pendingRefreshes
        pendingRefreshes = []
        if kinds.contains(.sidebar) { performRefreshSidebarState() }
        if kinds.contains(.review) { performRefreshReviewState() }
        if kinds.contains(.navigation) { performRefreshNavigationState() }
        if kinds.contains(.inspector) { performRefreshInspectorState() }
        if kinds.contains(.compare) { performRefreshCompareState() }
        if kinds.contains(.presentation) { performRefreshPresentationState() }
    }

    private func refreshAllUIState() {
        withCoalescedRefreshes {
            refreshSidebarState()
            refreshReviewState()
            refreshNavigationState()
            refreshInspectorState()
            refreshCompareState()
            refreshPresentationState()
        }
        refreshArchiveBrowserState()
    }

    private func invalidateArchiveBrowseContent() {
        archiveBrowseContentCache = nil
        archiveGridNavigator.reset()
    }

    private var archiveBrowseContent: ArchiveBrowseContent {
        if let cached = archiveBrowseContentCache { return cached }
        let content = ArchiveBrowseContent(catalogue: archiveCatalogue, year: archiveYearFilter,
            kind: archiveKindFilter, searchQuery: archiveSearchQuery,
            matchingPaths: archiveSearchMatchingPaths, sort: archiveSort)
        archiveBrowseContentCache = content
        archiveProjectionBuildCount &+= 1
        return content
    }

    private func refreshArchiveBrowserState() {
        let content = archiveBrowseContent
        let tripPath: String?
        switch archiveNavigationLevel {
        case .trip(let path): tripPath = path
        case .photos(_, let parent): tripPath = parent
        case .archive: tripPath = nil
        }
        if !content.mapNavigationIDs.contains(where: { $0 == selectedArchiveMapItemID }) {
            selectedArchiveMapItemID = content.mapNavigationIDs.first
        }
        let snapshot = ArchiveBrowserSnapshot(
            isLoading: archiveCatalogueIsLoading, errorMessage: archiveCatalogueError,
            viewMode: settings.archiveBrowseViewMode, sort: archiveSort, showPreviews: settings.showArchivePreviews,
            yearFilter: archiveYearFilter, kindFilter: archiveKindFilter, searchQuery: archiveSearchQuery,
            searchFocusRevision: archiveSearchFocusRevision, level: archiveNavigationLevel,
            entries: content.entries, totalEntryCount: archiveCatalogue.entries.count,
            tripCount: content.tripCount, unorganisedFolderCount: content.unorganisedFolderCount,
            yearFilters: content.yearFilters, selectedEntryID: selectedArchiveEntryID,
            selectedTrip: tripPath.flatMap { content.tripsByPath[$0] },
            walks: tripPath.flatMap { archiveCatalogue.walksByTripPath[$0] } ?? [],
            selectedWalkID: selectedArchiveWalkID, searchResults: content.searchResults,
            selectedSearchResultID: selectedArchiveSearchResultID, map: content.map,
            yearGroups: content.yearGroups, selectedMapItemID: selectedArchiveMapItemID,
            browseFocusRevision: archiveBrowseFocusRevision, isSearching: archiveSearchIsLoading,
            searchError: archiveSearchError, searchSelection: selectedArchiveSearchTarget,
            folderLoadState: archiveFolderLoadState, missingSearchHitMessage: archiveMissingSearchHitMessage,
            coverContext: ArchiveCoverContext(policyGeneration: ArchiveByteReadPolicyContext.shared.generation, catalogueRevision: archiveMediaCatalogueRevision))
        archiveBrowserState.update(snapshot)
    }

    private var filteredArchiveEntries: [ArchiveBrowseEntry] { archiveBrowseContent.entries }
    private var archiveSearchResults: [ArchivePhotoSummary] { archiveBrowseContent.searchResults }

    private var currentArchiveWalks: [ArchiveWalkSummary] {
        guard case .trip(let path) = archiveNavigationLevel else { return [] }
        return archiveCatalogue.walksByTripPath[path] ?? []
    }

    private var selectedArchiveMapWalk: ArchiveMapWalk? {
        guard case .walk(let path) = selectedArchiveMapItemID else { return nil }
        return archiveBrowseContent.map.walks.first { $0.archiveRelativePath == path }
    }

    private var hasArchiveSearchQuery: Bool {
        !archiveSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedArchiveSearchPhoto: ArchivePhotoSummary? {
        guard hasArchiveSearchQuery, archiveNavigationLevel == .archive, !archiveSearchIsLoading else { return nil }
        let id: String?
        if settings.archiveBrowseViewMode == .map, case .photo(let path) = selectedArchiveMapItemID { id = path }
        else if settings.archiveBrowseViewMode != .map, case .photo(let path) = selectedArchiveSearchTarget { id = path }
        else { id = nil }
        return id.flatMap { id in archiveSearchResults.first { $0.id == id } }
    }

    private var selectedArchiveEntry: ArchiveBrowseEntry? {
        if let photo = selectedArchiveSearchPhoto {
            return photo.tripPath.flatMap { archiveBrowseContent.tripsByPath[$0] }
        }
        if archiveNavigationLevel == .archive, settings.archiveBrowseViewMode == .map {
            switch selectedArchiveMapItemID {
            case .walk:
                return selectedArchiveMapWalk.flatMap { archiveBrowseContent.tripsByPath[$0.tripPath] }
            case .folder(let id): return archiveBrowseContent.allEntriesByID[id]
            case .photo: return nil
            case nil: return nil
            }
        }
        guard let selectedArchiveEntryID else { return nil }
        return archiveBrowseContent.allEntriesByID[selectedArchiveEntryID]
    }

    private func reconcileArchiveSelection() {
        let entries = filteredArchiveEntries
        selectedArchiveEntryID = ArchiveBrowseProjection.reconciledSelection(
            currentID: selectedArchiveEntryID,
            entries: entries
        )

        let walks = currentArchiveWalks
        if selectedArchiveWalkID.flatMap({ id in walks.first(where: { $0.id == id }) }) == nil {
            selectedArchiveWalkID = walks.first?.id
        }

        let results = archiveSearchResults
        if hasArchiveSearchQuery {
            switch selectedArchiveSearchTarget {
            case .photo(let id) where results.contains(where: { $0.id == id }): break
            case .entry(let id) where entries.contains(where: { $0.id == id }): break
            default:
                selectedArchiveSearchTarget = results.first.map { .photo($0.id) } ?? entries.first.map { .entry($0.id) }
            }
            if case .photo(let id) = selectedArchiveSearchTarget { selectedArchiveSearchResultID = id }
            else { selectedArchiveSearchResultID = nil }
        } else { selectedArchiveSearchTarget = nil; selectedArchiveSearchResultID = nil }
    }

    private func archiveURL(for relativePath: String) -> URL {
        if relativePath == "." || relativePath.isEmpty {
            return settings.archiveRoot
        }
        return settings.archiveRoot.appendingPathComponent(relativePath, isDirectory: true)
    }

    private func refreshSidebarState() {
        if refreshTransactionDepth > 0 { pendingRefreshes.insert(.sidebar); return }
        performRefreshSidebarState()
    }

    private func refreshReviewState() {
        if refreshTransactionDepth > 0 { pendingRefreshes.insert(.review); return }
        performRefreshReviewState()
    }

    private func refreshNavigationState() {
        if refreshTransactionDepth > 0 { pendingRefreshes.insert(.navigation); return }
        performRefreshNavigationState()
    }

    private func refreshInspectorState() {
        if refreshTransactionDepth > 0 { pendingRefreshes.insert(.inspector); return }
        performRefreshInspectorState()
    }

    private func refreshCompareState() {
        if refreshTransactionDepth > 0 { pendingRefreshes.insert(.compare); return }
        performRefreshCompareState()
    }

    private func refreshPresentationState() {
        if refreshTransactionDepth > 0 { pendingRefreshes.insert(.presentation); return }
        performRefreshPresentationState()
    }

    private func performRefreshSidebarState() {
        let summary: SessionSummary?
        if let currentSession {
            let counts = triageCounts(for: currentSession.mediaItems)
            summary = SessionSummary(
                sessionID: currentSession.id,
                sourceFolderPath: currentSession.sourceFolder.path,
                workspaceSourceFolderPath: currentSession.workspaceSourceFolder.path,
                itemCount: currentSession.mediaItems.count,
                includedCount: counts.included,
                candidateCount: counts.candidate,
                excludedCount: counts.excluded,
                sessionKind: currentSession.sessionKind,
                status: currentSession.status,
                walkMetadata: currentSession.walkMetadata,
                photoLogScope: currentSession.photoLogScope
            )
        } else {
            summary = nil
        }

        let explicitPhotoLogGroups = Dictionary(grouping: persistedSessions.filter {
            $0.0.sessionKind == .walkDraft && $0.0.sessionKindWasExplicit
        }) {
            ($0.0.photoLogScope?.label.nonEmpty ?? $0.0.walkMetadata.title.nonEmpty ?? $0.0.workspaceSourceFolder.lastPathComponent)
        }
        let photoLogGroups = explicitPhotoLogGroups
            .map { key, records in
                let logs = records
                    .map { record -> PhotoLogSummary in
                        let counts = triageCounts(for: record.0.mediaItems)
                        let title = record.0.walkMetadata.title.nonEmpty ?? "Untitled Photo Log"
                        let scope = record.0.photoLogScope ?? defaultPhotoLogScope(for: record.0)
                        return PhotoLogSummary(
                            sessionID: record.0.id,
                            title: title,
                            sourceFolderPath: record.0.sourceFolder.path,
                            workspaceSourceFolderPath: record.0.workspaceSourceFolder.path,
                            itemCount: record.0.mediaItems.count,
                            includedCount: counts.included,
                            candidateCount: counts.candidate,
                            excludedCount: counts.excluded,
                            sessionKind: record.0.sessionKind,
                            status: record.0.status,
                            sourceIsAvailable: fileManager.fileExists(atPath: record.0.workspaceSourceFolder.path),
                            lastUpdatedAt: record.0.lastUpdatedAt,
                            isCurrentSession: currentSession?.id == record.0.id,
                            scopeLabel: scope.label
                        )
                    }
                    .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }

                let isAvailable = records.contains { fileManager.fileExists(atPath: $0.0.workspaceSourceFolder.path) }
                return PhotoLogGroupSnapshot(
                    scopeLabel: key,
                    sourceIsAvailable: isAvailable,
                    logs: logs
                )
            }
            .sorted { (lhs: PhotoLogGroupSnapshot, rhs: PhotoLogGroupSnapshot) in
                lhs.scopeLabel.localizedCaseInsensitiveCompare(rhs.scopeLabel) == .orderedAscending
            }

        let canReloadSourceWorkspace = sourceWorkspaceState.sourcePath != nil || currentSession != nil
        let importReadiness = importReadinessSnapshot(for: currentSession)
        let photoLogCreationPlan = currentSession?.sessionKind == .inbox && !isBrowsingArchive
            ? proposedPhotoLogCreationPlan(mode: .decidedInScope)
            : nil
        let canPresentPhotoLogCreation = currentSession?.sessionKind == .inbox && photoLogCreationPlan?.canCreate == true
        let hiddenPhotoLogSummary = photoLogHiddenSummary()
        let workflowGuidance = workflowGuidanceResolver.resolve(
            sourceWorkspaceState: sourceWorkspaceState,
            sessionSummary: summary,
            creationPlan: photoLogCreationPlan,
            isBrowsingArchive: isBrowsingArchive,
            importReadiness: importReadiness,
            importOperation: importOperation
        )

        let snapshot = SidebarSnapshot(
            isVisible: isSidebarVisible,
            sourceWorkspaceState: sourceWorkspaceState,
            sessionSummary: summary,
            workflowGuidance: workflowGuidance,
            photoLogGroups: photoLogGroups,
            canMutateImportSelection: canMutateImportSelection,
            canPresentPhotoLogCreation: canPresentPhotoLogCreation,
            canOpenDefaultSourceWorkspace: true,
            canReloadSourceWorkspace: canReloadSourceWorkspace,
            isWalkDetailsExpanded: isWalkDetailsExpanded,
            archiveRootDisplayPath: settings.archiveRootDisplayPath,
            archiveYearFolders: archiveYearFolders,
            tree: SidebarTreeSnapshot(
                browserRoots: browserRoots,
                selectedSidebarNodeID: selectedSidebarNodeID
            ),
            hiddenPhotoLogSummary: hiddenPhotoLogSummary,
            statusMessage: statusMessage,
            importProgress: importProgress,
            importReadiness: importReadiness,
            importOperation: importOperation
        )
        sidebarState.update(snapshot)
    }

    private func importReadinessSnapshot(for session: ImportSession?) -> ImportReadinessSnapshot? {
        guard let session else { return nil }
        guard !isBrowsingArchive else { return nil }

        let copyableItems = session.mediaItems.filter {
            $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond
        }
        let rawCompanionFiles = copyableItems.reduce(0) { count, item in
            count + (item.importRawCompanions ? item.companionFiles.count : 0)
        }
        let totalFiles = copyableItems.count + rawCompanionFiles
        let destinationPath = archiveDestinationURL(for: session, includePlannedDestination: true)?.path
        let candidateItems = session.mediaItems.filter {
            $0.selectionState.isCandidate && !$0.lifecycleState.isImportedOrBeyond
        }.count
        let excludedItems = session.mediaItems.filter {
            $0.selectionState.isExcluded && !$0.lifecycleState.isImportedOrBeyond
        }.count
        let undecidedItems = session.mediaItems.filter {
            $0.selectionState.isUndecided && !$0.lifecycleState.isImportedOrBeyond
        }.count
        let verifiedAwaitingBackupItems = session.mediaItems.filter {
            $0.selectionState.isIncluded && ($0.lifecycleState == .verified || $0.lifecycleState == .imported)
        }.count
        let cleanupPendingItems = session.mediaItems.filter { $0.lifecycleState == .sourceCleanupPending }.count

        return ImportReadinessSnapshot(
            sessionKind: session.sessionKind,
            includedItems: copyableItems.count,
            candidateItems: candidateItems,
            excludedItems: excludedItems,
            undecidedItems: undecidedItems,
            rawCompanionFiles: rawCompanionFiles,
            totalFiles: totalFiles,
            destinationPath: destinationPath,
            verifiedAwaitingBackupItems: verifiedAwaitingBackupItems,
            cleanupPendingItems: cleanupPendingItems,
            backupConfirmed: session.walkMetadata.backupConfirmedAt != nil,
            cleanupRequiresBackupConfirmation: settings.cleanupRequiresBackupConfirmation
        )
    }

    private var currentCopiedArchiveDestinationURL: URL? {
        if importOperation.phase == .completed, let destinationPath = importOperation.destinationPath {
            return URL(fileURLWithPath: destinationPath, isDirectory: true).standardizedFileURL
        }

        guard let currentSession else { return nil }
        return archiveDestinationURL(for: currentSession, includePlannedDestination: false)
    }

    private func archiveDestinationURL(for session: ImportSession, includePlannedDestination: Bool) -> URL? {
        let copiedDestination = session.mediaItems
            .filter { $0.selectionState.isIncluded && $0.lifecycleState.isImportedOrBeyond }
            .compactMap(\.destinationURL)
            .sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
            .first

        if let copiedDestination {
            return copiedDestination.deletingLastPathComponent().standardizedFileURL
        }

        guard includePlannedDestination else { return nil }
        guard session.mediaItems.contains(where: { $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond }) else {
            return nil
        }
        return ArchivePlanner(fileManager: fileManager).plan(for: session).archiveFolder.standardizedFileURL
    }

    private func refreshSidebarVisibilityState() {
        var snapshot = sidebarState.snapshot
        snapshot.isVisible = isSidebarVisible
        sidebarState.update(snapshot)
    }

    private func handleSidebarVisibilityChanged() {
        refreshSidebarVisibilityState()

        guard !isSidebarVisible, activePane == .sidebar else { return }
        if canFocusReviewSurface {
            focusReviewSurface()
        } else if !selectedFolderNodeIDs.isEmpty || !detailFolderNodes.isEmpty {
            activePane = .folders
        }
    }

    private func triageCounts(for items: [MediaItem]) -> (included: Int, candidate: Int, excluded: Int) {
        items.reduce(into: (included: 0, candidate: 0, excluded: 0)) { counts, item in
            switch item.selectionState {
            case .included:
                counts.included += 1
            case .candidate:
                counts.candidate += 1
            case .excluded:
                counts.excluded += 1
            case .undecided:
                break
            }
        }
    }

    private func performRefreshReviewState() {
        let ownershipByPath = currentSourceLogOwnershipByRelativePath()
        let archiveCopiesByPath = currentSession?.sessionKind == .inbox ? sourceArchiveCopiesByRelativePath : [:]
        let snapshots = visibleMediaItems.map {
            makeReviewItemSnapshot(
                $0,
                sourceLogOwnership: ownershipByPath[$0.relativePath],
                sourceArchiveCopy: archiveCopiesByPath[$0.relativePath]
            )
        }
        let itemSnapshotsByID = ReviewItemSnapshotIndex(Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) }))
        let canUseGroupedReviewModeValue = canUseGroupedReviewMode
        let isGroupedReviewActive = canUseGroupedReviewModeValue && dayDetailDisplayMode == .sections
        let organizedSections = isGroupedReviewActive ? organizedInlineSections : []
        // `groupedReviewSections` is memoized by `inlineSectionCacheGeneration` + mode, so this
        // no longer re-runs the organizer transform on every selection-driven review refresh.
        let groupedSections = isGroupedReviewActive ? groupedReviewSections : []
        let canUseGroupedSectionNavigation = isGroupedReviewActive && !groupedSections.isEmpty

        var snapshot = ReviewSnapshot(
            breadcrumbTitles: breadcrumbTitles,
            contextMediaItemCount: contextMediaItems.count,
            detailFolderNodes: detailFolderNodes,
            visibleItems: snapshots,
            itemSnapshotsByID: itemSnapshotsByID,
            organizedInlineSections: organizedSections,
            groupedReviewSections: groupedSections,
            canUseGroupedReviewMode: canUseGroupedReviewModeValue,
            availableDayDetailDisplayModes: availableDayDetailDisplayModes,
            dayOrganizationMode: dayOrganizationMode,
            dayDetailDisplayMode: dayDetailDisplayMode,
            reviewFilter: reviewFilter,
            reviewPresentationMode: reviewPresentationMode,
            reviewGridPreferredColumnCount: reviewGridPreferredColumnCount,
            reviewGridColumnCount: reviewGridColumnCount,
            reviewGridCardWidth: reviewGridCardWidth,
            selectedMediaItemIDs: selectedMediaItemIDs,
            focusedReviewItemID: focusedReviewItemID,
            focusedInlineSectionID: focusedInlineSectionID,
            expandedInlineSectionIDs: expandedInlineSectionIDs,
            canMutateImportSelection: canMutateImportSelection,
            canFocusReviewSurface: canFocusReviewSurface,
            canUseGroupedSectionNavigation: canUseGroupedSectionNavigation,
            canExpandAllGroupedSections: canUseGroupedSectionNavigation && !organizedSections.isEmpty,
            canCollapseAllGroupedSections: canUseGroupedSectionNavigation && !expandedInlineSectionIDs.isEmpty,
            canOpenComparison: canOpenComparison,
            canMarkSelectionForImport: canMarkSelectionForImport,
            canMarkSelectionAsCandidate: canMarkSelectionAsCandidate,
            canExcludeSelectionFromImport: canExcludeSelectionFromImport,
            canUnmarkSelectionForImport: canUnmarkSelectionForImport,
            canToggleRawForSelection: canToggleRawForSelection
        )
        snapshot.findQuery = reviewSearchQuery
        reviewState.update(snapshot)
    }

    private func performRefreshNavigationState() {
        let snapshot = ReviewNavigationSnapshot(
            activePane: activePane,
            reviewGridHasFocus: reviewGridHasFocus,
            isGroupedSectionKeyboardTargetActive: isGroupedSectionKeyboardTargetActive,
            pendingInlineScrollTargetID: pendingInlineScrollTargetID,
            pendingReviewScrollTargetID: pendingReviewScrollTargetID,
            pendingInlineSectionScrollTargetID: pendingInlineSectionScrollTargetID,
            pendingInlineSectionScrollRevision: pendingInlineSectionScrollRevision
        )
        reviewNavigationState.update(snapshot)
    }

    private func performRefreshInspectorState() {
        guard isDetailsInspectorVisible else {
            inspectorState.update(
                InspectorSnapshot(
                    isVisible: false,
                    browserNode: nil,
                    fallbackFolderPath: nil,
                    walkTitle: nil,
                    walkLocation: nil,
                    mediaItem: nil,
                    cropHistory: nil
                )
            )
            return
        }

        let mediaItem = inspectorMediaItem
        let snapshot = InspectorSnapshot(
            isVisible: isDetailsInspectorVisible,
            browserNode: inspectorBrowserNode,
            fallbackFolderPath: currentSession?.sourceFolder.path,
            walkTitle: currentSession?.walkMetadata.title.nonEmpty,
            walkLocation: currentSession?.walkMetadata.location.nonEmpty,
            mediaItem: mediaItem,
            cropHistory: mediaItem.flatMap { cropHistory(for: $0) }
        )
        inspectorState.update(snapshot)
    }

    private func performRefreshCompareState() {
        let ownershipByPath = currentSourceLogOwnershipByRelativePath()
        let archiveCopiesByPath = currentSession?.sessionKind == .inbox ? sourceArchiveCopiesByRelativePath : [:]
        let snapshots = comparingMediaItems.map {
            makeReviewItemSnapshot(
                $0,
                sourceLogOwnership: ownershipByPath[$0.relativePath],
                sourceArchiveCopy: archiveCopiesByPath[$0.relativePath]
            )
        }
        let snapshot = CompareSnapshot(
            title: compareSheetTitle,
            itemIDs: comparingMediaItemIDs,
            items: snapshots,
            gridColumnCount: compareGridColumnCount
        )
        compareState.update(snapshot)
    }

    private func performRefreshPresentationState() {
        let snapshot = PresentationSnapshot(
            showKeyboardHelp: showKeyboardHelp,
            startupAlert: startupAlert,
            previewingMediaItem: previewingMediaItem,
            activePhotoLogEditor: activePhotoLogEditor,
            activeWalkCommitEditor: activeWalkCommitEditor,
            revealedPhotoLog: revealedPhotoLog
        )
        presentationState.update(snapshot)
    }

    private func makeReviewItemSnapshot(
        _ item: MediaItem,
        sourceLogOwnership: SourceLogOwnershipSnapshot? = nil,
        sourceArchiveCopy: SourceArchiveCopySnapshot? = nil
    ) -> ReviewItemSnapshot {
        ReviewItemSnapshot(
            item: item,
            archivePreview: archivePreview(for: item),
            sourceLogOwnership: sourceLogOwnership,
            sourceArchiveCopy: sourceArchiveCopy,
            isSelected: selectedMediaItemIDs.contains(item.id),
            isFocused: focusedReviewItemID == item.id,
            thumbnailFailed: thumbnailFailures.contains(item.id)
        )
    }

    private func invalidateInlineSectionCaches() {
        inlineSectionCacheGeneration &+= 1
        cachedInlineDaySectionsGeneration = -1
        cachedInlineDaySectionsNodeID = nil
        cachedInlineDaySections = []
        cachedGroupableInlineDaySectionsGeneration = -1
        cachedGroupableInlineDaySectionsNodeID = nil
        cachedGroupableInlineDaySections = []
        invalidateOrganizedInlineSectionCache()
        focusedInlineSectionID = nil
        pendingInlineSectionScrollTargetID = nil
        pendingInlineSectionScrollRevision = 0
        pendingReviewScrollTargetID = nil
        estimatedVisibleReviewIndexRange = nil
        invalidateReviewContentCaches()
    }

    private func invalidateOrganizedInlineSectionCache() {
        cachedOrganizedInlineSectionsGeneration = -1
        cachedOrganizedInlineSectionsMode = dayOrganizationMode
        cachedOrganizedInlineSections = []
        invalidateReviewContentCaches()
    }

    private func invalidateReviewContentCaches() {
        reviewContentCacheGeneration &+= 1
        cachedContextMediaGeneration = -1
        cachedContextMediaItems = []
        cachedVisibleMediaGeneration = -1
        cachedVisibleMediaItems = []
        cachedReviewInteractionGeneration = -1
        cachedReviewInteractionItems = []
    }

    private var focusedInlineSection: InlineSection? {
        guard let focusedInlineSectionID else { return nil }
        return inlineSection(matching: focusedInlineSectionID, in: organizedInlineSections)
    }

    private func moveInlineSectionFocus(by offset: Int) {
        guard canUseGroupedSectionNavigation else { return }
        let sections = groupedReviewSections
        guard !sections.isEmpty else { return }

        let currentID = focusedInlineSectionID ?? defaultInlineSectionFocusID(in: sections)
        let currentIndex = currentID.flatMap { id in
            sections.firstIndex(where: { $0.id == id })
        } ?? 0
        let targetIndex = min(max(currentIndex + offset, 0), sections.count - 1)
        focusInlineSection(sections[targetIndex].id)
    }

    private func defaultInlineSectionFocusID(in sections: [GroupedReviewSection]) -> String? {
        if let focusedReviewItemID,
           let containingSectionID = inlineSectionID(containing: focusedReviewItemID, in: organizedInlineSections) {
            return containingSectionID
        }
        return sections.first?.id
    }

    private func ensureFocusedInlineSection() {
        guard canUseGroupedSectionNavigation else {
            focusedInlineSectionID = nil
            return
        }

        let sections = groupedReviewSections
        guard !sections.isEmpty else {
            focusedInlineSectionID = nil
            return
        }

        if let focusedInlineSectionID,
           sections.contains(where: { $0.id == focusedInlineSectionID }) {
            return
        }

        focusedInlineSectionID = defaultInlineSectionFocusID(in: sections)
    }

    private func requestInlineSectionScroll(to sectionID: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingInlineSectionScrollTargetID = sectionID
            self.pendingInlineSectionScrollRevision &+= 1
        }
    }

    private func requestReviewScrollIfNeeded(to itemID: UUID?) {
        guard let itemID,
              let targetIndex = reviewInteractionItems.firstIndex(where: { $0.id == itemID }) else {
            pendingReviewScrollTargetID = nil
            estimatedVisibleReviewIndexRange = nil
            return
        }

        if reviewPresentationMode != .grid {
            pendingReviewScrollTargetID = itemID
            updateEstimatedVisibleReviewRange(around: itemID)
            return
        }

        if estimatedVisibleReviewIndexRange == nil {
            updateEstimatedVisibleReviewRange(around: itemID)
            pendingReviewScrollTargetID = nil
            return
        }

        if let estimatedVisibleReviewIndexRange,
           estimatedVisibleReviewIndexRange.contains(targetIndex) {
            pendingReviewScrollTargetID = nil
            return
        }

        latencyRecorder.begin("review.scroll")
        pendingReviewScrollTargetID = itemID
        updateEstimatedVisibleReviewRange(around: itemID)
    }

    private func updateEstimatedVisibleReviewRange(around itemID: UUID?) {
        guard let itemID,
              let targetIndex = reviewInteractionItems.firstIndex(where: { $0.id == itemID }),
              !reviewInteractionItems.isEmpty else {
            estimatedVisibleReviewIndexRange = nil
            return
        }

        let pageCapacity = estimatedVisibleReviewPageCapacity()
        let centeredOffset = max(pageCapacity / 2, 0)
        var lowerBound = max(0, targetIndex - centeredOffset)
        let upperBound = min(reviewInteractionItems.count - 1, lowerBound + pageCapacity - 1)

        if upperBound - lowerBound + 1 < pageCapacity {
            lowerBound = max(0, upperBound - pageCapacity + 1)
        }

        estimatedVisibleReviewIndexRange = lowerBound...upperBound
    }

    private func estimatedVisibleReviewPageCapacity() -> Int {
        let columns = max(reviewGridColumnCount, 1)
        if reviewPresentationMode != .grid {
            return max(1, columns)
        }

        let cardHeight = ReviewGridMetrics.estimatedCardHeight(for: reviewGridCardWidth)
        let usableHeight = max(lastMeasuredReviewPaneHeight - (ReviewGridMetrics.gridPadding * 2), cardHeight)
        let rowStride = max(cardHeight + ReviewGridMetrics.gridSpacing, 1)
        let rows = max(1, Int(floor((usableHeight + ReviewGridMetrics.gridSpacing) / rowStride)))
        return max(1, rows * columns)
    }

    private func syncFocusedInlineSectionToFocusedItem() {
        guard dayDetailDisplayMode == .sections,
              let focusedReviewItemID,
              let containingSectionID = inlineSectionID(containing: focusedReviewItemID, in: organizedInlineSections) else {
            return
        }
        focusedInlineSectionID = containingSectionID
    }

    private func reconcileReviewSelectionWithVisibleItems() {
        let visibleIDs = Set(reviewInteractionItems.map(\.id))
        if visibleIDs.isEmpty {
            selectedMediaItemIDs.removeAll()
            focusedReviewItemID = nil
            reviewSelectionAnchorID = nil
            return
        }

        selectedMediaItemIDs = selectedMediaItemIDs.intersection(visibleIDs)
        if let currentFocusedReviewItemID = focusedReviewItemID, !visibleIDs.contains(currentFocusedReviewItemID) {
            focusedReviewItemID = selectedMediaItemIDs.first ?? reviewInteractionItems.first?.id
        }
        if let currentReviewSelectionAnchorID = reviewSelectionAnchorID, !visibleIDs.contains(currentReviewSelectionAnchorID) {
            reviewSelectionAnchorID = selectedMediaItemIDs.first
        }
    }

    private func advanceAfterTriageAction(for selectedIDs: Set<UUID>) {
        guard activePane == .media,
              reviewKeyboardTarget == .items,
              selectedIDs.count == 1,
              let currentID = selectedIDs.first,
              let currentIndex = reviewInteractionItems.firstIndex(where: { $0.id == currentID }),
              !reviewInteractionItems.isEmpty else {
            return
        }

        let targetIndex = min(currentIndex + 1, reviewInteractionItems.count - 1)
        let targetID = reviewInteractionItems[targetIndex].id
        selectedMediaItemIDs = [targetID]
        focusedReviewItemID = targetID
        reviewSelectionAnchorID = targetID
        requestReviewScrollIfNeeded(to: targetID)
    }

    private func markCurrentComparisonSelectionForImport() {
        guard canMutateImportSelection else { return }
        let selectedIDs = currentComparisonSelectionIDs()
        guard !selectedIDs.isEmpty else { return }
        updateTriageState(for: selectedIDs, selectionState: .included)
        statusMessage = "Selected \(selectedIDs.count) compare item(s) for import."
        advanceAfterCompareTriageAction(for: selectedIDs)
    }

    private func markCurrentComparisonSelectionAsCandidate() {
        guard canMutateImportSelection else { return }
        let selectedIDs = currentComparisonSelectionIDs()
        guard !selectedIDs.isEmpty else { return }
        updateTriageState(for: selectedIDs, selectionState: .candidate)
        statusMessage = "Marked \(selectedIDs.count) compare item(s) as candidates."
        advanceAfterCompareTriageAction(for: selectedIDs)
    }

    private func excludeCurrentComparisonSelectionFromImport() {
        guard canMutateImportSelection else { return }
        let selectedIDs = currentComparisonSelectionIDs()
        guard !selectedIDs.isEmpty else { return }

        let originalIDs = comparingMediaItemIDs
        let focusedID = focusedReviewItemID
        updateTriageState(for: selectedIDs, selectionState: .excluded)
        comparingMediaItemIDs.removeAll { selectedIDs.contains($0) }

        if comparingMediaItemIDs.isEmpty {
            closeComparison()
            statusMessage = "Excluded the last compare item and closed compare."
            return
        }

        compareGridColumnCount = min(compareGridColumnCount, max(comparingMediaItemIDs.count, 1))
        if let replacementID = comparisonReplacementID(afterRemoving: selectedIDs, from: originalIDs, preferredCurrentID: focusedID) {
            focusComparisonItem(replacementID)
        }
        statusMessage = "Excluded \(selectedIDs.count) compare item(s) and removed them from compare."
    }

    private func unmarkCurrentComparisonSelectionForImport() {
        guard canMutateImportSelection else { return }
        let selectedIDs = currentComparisonSelectionIDs()
        guard !selectedIDs.isEmpty else { return }
        updateTriageState(for: selectedIDs, selectionState: .undecided)
        statusMessage = "Cleared \(selectedIDs.count) compare item(s) back to undecided."
        advanceAfterCompareTriageAction(for: selectedIDs)
    }

    private func removeFocusedComparisonItem() {
        guard let focusedID = focusedReviewItemID, comparingMediaItemIDs.contains(focusedID) else { return }
        removeItemFromComparison(focusedID)
    }

    private func advanceAfterCompareTriageAction(for selectedIDs: Set<UUID>) {
        guard selectedIDs.count == 1,
              let currentID = selectedIDs.first,
              let currentIndex = comparingMediaItemIDs.firstIndex(of: currentID),
              !comparingMediaItemIDs.isEmpty else {
            return
        }

        let targetIndex = min(currentIndex + 1, comparingMediaItemIDs.count - 1)
        focusComparisonItem(comparingMediaItemIDs[targetIndex])
    }

    private func comparisonReplacementID(
        afterRemoving removedIDs: Set<UUID>,
        from originalIDs: [UUID],
        preferredCurrentID: UUID?
    ) -> UUID? {
        let remainingIDs = originalIDs.filter { !removedIDs.contains($0) }
        guard !remainingIDs.isEmpty else { return nil }

        let focusAnchorID = preferredCurrentID ?? removedIDs.first
        let originalIndex = focusAnchorID.flatMap { originalIDs.firstIndex(of: $0) } ?? 0
        let replacementIndex = min(originalIndex, remainingIDs.count - 1)
        return remainingIDs[replacementIndex]
    }

    private func inlineSection(matching sectionID: String, in sections: [InlineSection]) -> InlineSection? {
        for section in sections {
            if section.id == sectionID {
                return section
            }
            if let match = inlineSection(matching: sectionID, in: section.children) {
                return match
            }
        }
        return nil
    }

    private func inlineSectionID(containing itemID: UUID, in sections: [InlineSection]) -> String? {
        for section in sections {
            if section.photoItemIDs.contains(itemID) || (section.children.isEmpty && section.mediaItemIDs.contains(itemID)) {
                return section.id
            }
            if let child = inlineSectionID(containing: itemID, in: section.children) {
                return child
            }
        }
        return nil
    }

    private var groupableInlineDaySections: [InlineDaySection] {
        let nodeID = selectedBrowserNode?.id
        if cachedGroupableInlineDaySectionsGeneration == inlineSectionCacheGeneration,
           cachedGroupableInlineDaySectionsNodeID == nodeID {
            return cachedGroupableInlineDaySections
        }

        let sections = inlineSectionOrganizer.inlineDaySections(from: selectedBrowserNode, visibleItems: contextMediaItems)
        cachedGroupableInlineDaySectionsGeneration = inlineSectionCacheGeneration
        cachedGroupableInlineDaySectionsNodeID = nodeID
        cachedGroupableInlineDaySections = sections
        return sections
    }

    private func filterReviewItems(_ items: [MediaItem]) -> [MediaItem] {
        let words = reviewSearchQuery.split(whereSeparator: \.isWhitespace)
        let items = words.isEmpty ? items : items.filter { item in
            let text = item.fileName + " " + item.relativePath
            return words.allSatisfy { text.localizedStandardContains(String($0)) }
        }
        switch reviewFilter {
        case .all:
            return items
        case .included:
            return items.filter { $0.selectionState.isIncluded }
        case .candidate:
            return items.filter { $0.selectionState.isCandidate }
        case .excluded:
            return items.filter { $0.selectionState.isExcluded }
        case .undecided:
            return items.filter { $0.selectionState.isUndecided }
        case .cropped:
            return items.filter { $0.cropRelationship != nil }
        }
    }

    private func baseVisibleMediaItems(for node: BrowserNode) -> [MediaItem] {
        if let cachedArchiveItems = archiveMediaCache[node.id] {
            return cachedArchiveItems
        }

        if let cachedSessionItems = sessionVisibleMediaCacheByNodeID[node.id] {
            return cachedSessionItems
        }

        let items = MediaItemSort.sorted(node.mediaItemIDs.compactMap { sessionMediaByID[$0] })
        sessionVisibleMediaCacheByNodeID[node.id] = items
        return items
    }

    private func mediaItem(for id: UUID) -> MediaItem? {
        if workspaceMode == .archiveView || isBrowsingArchive {
            guard let nodeID = selectedBrowserNode?.id else { return nil }
            return archiveMediaCache[nodeID]?.first { $0.id == id }
        }
        return sessionMediaByID[id]
    }

    private func mediaItem(relativePath: String) -> MediaItem? {
        if workspaceMode == .archiveView || isBrowsingArchive {
            guard let nodeID = selectedBrowserNode?.id else { return nil }
            return archiveMediaCache[nodeID]?.first { $0.relativePath == relativePath }
        }
        return sessionMediaByID.values.first { $0.relativePath == relativePath }
    }

    @discardableResult
    private func recordCropRelationship(for original: MediaItem, cropURL: URL, manifestURL: URL) -> MediaItem? {
        let cropRelativePath = siblingRelativePath(for: cropURL, original: original)
        let manifestRelativePath = siblingRelativePath(for: manifestURL, original: original)

        func updatedOriginal(_ item: MediaItem) -> MediaItem {
            var updated = item
            var relationship = updated.cropRelationship ?? CropRelationship(
                role: .original,
                originalRelativePath: updated.relativePath,
                originalFileName: updated.fileName,
                cropRelativePaths: [],
                cropFileNames: [],
                manifestRelativePath: manifestRelativePath,
                latestCropRelativePath: nil,
                latestCropFileName: nil
            )
            relationship.role = .original
            relationship.originalRelativePath = updated.relativePath
            relationship.originalFileName = updated.fileName
            relationship.manifestRelativePath = manifestRelativePath
            if !relationship.cropRelativePaths.contains(cropRelativePath) {
                relationship.cropRelativePaths.append(cropRelativePath)
            }
            if !relationship.cropFileNames.contains(cropURL.lastPathComponent) {
                relationship.cropFileNames.append(cropURL.lastPathComponent)
            }
            relationship.latestCropRelativePath = cropRelativePath
            relationship.latestCropFileName = cropURL.lastPathComponent
            updated.cropRelationship = relationship
            return updated
        }

        func cropRelationship(from originalRelationship: CropRelationship, original: MediaItem) -> CropRelationship {
            CropRelationship(
                role: .crop,
                originalRelativePath: original.relativePath,
                originalFileName: original.fileName,
                cropRelativePaths: originalRelationship.cropRelativePaths,
                cropFileNames: originalRelationship.cropFileNames,
                manifestRelativePath: manifestRelativePath,
                latestCropRelativePath: cropRelativePath,
                latestCropFileName: cropURL.lastPathComponent
            )
        }

        if var session = currentSession,
           let index = session.mediaItems.firstIndex(where: { $0.id == original.id && canonicalPath($0.sourceURL) == canonicalPath(original.sourceURL) }) {
            let updatedOriginalItem = updatedOriginal(session.mediaItems[index])
            session.mediaItems[index] = updatedOriginalItem
            guard let originalRelationship = updatedOriginalItem.cropRelationship else { return nil }
            let cropRelationship = cropRelationship(from: originalRelationship, original: updatedOriginalItem)
            let cropItem = makeCropMediaItem(
                from: updatedOriginalItem,
                cropURL: cropURL,
                cropRelativePath: cropRelativePath,
                cropRelationship: cropRelationship
            )

            if let cropIndex = session.mediaItems.firstIndex(where: { $0.relativePath == cropRelativePath || canonicalPath($0.sourceURL) == canonicalPath(cropURL) }) {
                var existingCrop = session.mediaItems[cropIndex]
                existingCrop.sourceURL = cropURL
                existingCrop.relativePath = cropRelativePath
                existingCrop.fileName = cropURL.lastPathComponent
                existingCrop.baseName = cropURL.deletingPathExtension().lastPathComponent
                existingCrop.fileSizeBytes = cropItem.fileSizeBytes
                existingCrop.capturedAt = cropItem.capturedAt
                existingCrop.metadata = cropItem.metadata
                existingCrop.thumbnailCacheKey = cropItem.thumbnailCacheKey
                existingCrop.cropRelationship = cropRelationship
                session.mediaItems[cropIndex] = existingCrop
                save(session, updateKind: .full)
                return existingCrop
            }

            session.mediaItems.append(cropItem)
            save(session, updateKind: .full)
            return cropItem
        }

        var updatedArchiveCache = archiveMediaCache
        var didUpdate = false
        var outputCropItem: MediaItem?
        for key in Array(updatedArchiveCache.keys) {
            if key != selectedBrowserNode?.id {
                if updatedArchiveCache[key]?.contains(where: { canonicalPath($0.sourceURL) == canonicalPath(original.sourceURL) }) == true {
                    updatedArchiveCache.removeValue(forKey: key)
                }
                continue
            }
            guard var items = updatedArchiveCache[key],
                  let index = items.firstIndex(where: { $0.id == original.id && canonicalPath($0.sourceURL) == canonicalPath(original.sourceURL) }) else { continue }
            let updatedOriginalItem = updatedOriginal(items[index])
            items[index] = updatedOriginalItem
            guard let originalRelationship = updatedOriginalItem.cropRelationship else { continue }
            let cropRelationship = cropRelationship(from: originalRelationship, original: updatedOriginalItem)
            let cropItem = makeCropMediaItem(
                from: updatedOriginalItem,
                cropURL: cropURL,
                cropRelativePath: cropRelativePath,
                cropRelationship: cropRelationship
            )

            if let cropIndex = items.firstIndex(where: { $0.relativePath == cropRelativePath || canonicalPath($0.sourceURL) == canonicalPath(cropURL) }) {
                var existingCrop = items[cropIndex]
                existingCrop.sourceURL = cropURL
                existingCrop.relativePath = cropRelativePath
                existingCrop.fileName = cropURL.lastPathComponent
                existingCrop.baseName = cropURL.deletingPathExtension().lastPathComponent
                existingCrop.fileSizeBytes = cropItem.fileSizeBytes
                existingCrop.capturedAt = cropItem.capturedAt
                existingCrop.metadata = cropItem.metadata
                existingCrop.thumbnailCacheKey = cropItem.thumbnailCacheKey
                existingCrop.cropRelationship = cropRelationship
                items[cropIndex] = existingCrop
                outputCropItem = existingCrop
            } else {
                items.append(cropItem)
                outputCropItem = cropItem
            }
            items = MediaItemSort.sorted(items)
            updatedArchiveCache[key] = items
            didUpdate = true
        }
        if didUpdate {
            archiveMediaCache = updatedArchiveCache
            refreshAllUIState()
        }
        return outputCropItem
    }

    private func makeCropMediaItem(
        from original: MediaItem,
        cropURL: URL,
        cropRelativePath: String,
        cropRelationship: CropRelationship
    ) -> MediaItem {
        let attributes = try? fileManager.attributesOfItem(atPath: cropURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        var metadata = MetadataExtractor().extract(from: cropURL)
        let capturedAt = metadata.capturedAt ?? original.capturedAt
        metadata.capturedAt = capturedAt

        return MediaItem(
            sourceURL: cropURL,
            relativePath: cropRelativePath,
            fileName: cropURL.lastPathComponent,
            baseName: cropURL.deletingPathExtension().lastPathComponent,
            mediaKind: mediaKind(for: cropURL),
            fileSizeBytes: fileSize,
            capturedAt: capturedAt,
            metadata: metadata,
            thumbnailCacheKey: CacheKeyBuilder.key(for: cropURL),
            cropRelationship: cropRelationship
        )
    }

    private func focusCropOutput(_ cropItem: MediaItem, replacing original: MediaItem) {
        if let compareIndex = comparingMediaItemIDs.firstIndex(of: original.id) {
            comparingMediaItemIDs[compareIndex] = cropItem.id
        }
        let shouldMovePreview = previewingMediaItemID == original.id
        focusMediaItem(cropItem, openPreview: shouldMovePreview)
    }

    private func focusMediaItem(_ item: MediaItem, openPreview: Bool = true) {
        selectedMediaItemIDs = [item.id]
        focusedReviewItemID = item.id
        reviewSelectionAnchorID = item.id
        pendingReviewScrollTargetID = item.id
        if openPreview {
            previewingMediaItemID = item.id
        }
        activePane = .media
        preheatDisplayImages(for: [item.id], limit: 1)
    }

    private func mediaKind(for url: URL) -> MediaKind {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return .jpeg
        case "cr2", "cr3", "dng", "raf", "nef":
            return .raw
        default:
            return .other
        }
    }

    private func canonicalPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func cropHistory(for item: MediaItem) -> CropHistorySnapshot? {
        guard let relationship = item.cropRelationship else { return nil }
        let originalRelativePath = relationship.originalRelativePath
        let originalItem = mediaItem(relativePath: originalRelativePath)
        var seen: Set<String> = []
        var versions: [CropVersionSnapshot] = []

        func appendVersion(relativePath: String, fileName: String, role: CropRelationshipRole) {
            guard seen.insert(relativePath).inserted else { return }
            let linkedItem = mediaItem(relativePath: relativePath)
            versions.append(
                CropVersionSnapshot(
                    id: relativePath,
                    relativePath: relativePath,
                    fileName: linkedItem?.fileName ?? fileName,
                    role: role,
                    mediaItemID: linkedItem?.id,
                    isCurrent: item.relativePath == relativePath
                )
            )
        }

        appendVersion(
            relativePath: originalRelativePath,
            fileName: originalItem?.fileName ?? relationship.originalFileName,
            role: .original
        )

        for (index, cropRelativePath) in relationship.cropRelativePaths.enumerated() {
            let fallbackFileName: String
            if relationship.cropFileNames.indices.contains(index) {
                fallbackFileName = relationship.cropFileNames[index]
            } else {
                fallbackFileName = URL(fileURLWithPath: cropRelativePath).lastPathComponent
            }
            appendVersion(relativePath: cropRelativePath, fileName: fallbackFileName, role: .crop)
        }

        guard versions.count > 1 else { return nil }
        return CropHistorySnapshot(versions: versions)
    }

    private func siblingRelativePath(for url: URL, original: MediaItem) -> String {
        let relativeDirectory = (original.relativePath as NSString).deletingLastPathComponent
        if relativeDirectory.isEmpty || relativeDirectory == "." || relativeDirectory == "/" {
            return url.lastPathComponent
        }
        return "\(relativeDirectory)/\(url.lastPathComponent)"
    }

    private var selectedBrowserFolderURL: URL? {
        if workspaceMode == .archiveView {
            switch archiveNavigationLevel {
            case .archive:
                return selectedArchiveEntry.map { archiveURL(for: $0.archiveRelativePath) }
            case .trip(let path):
                return archiveURL(for: path)
            case .photos(let path, _):
                return archiveURL(for: path)
            }
        }
        if activePane == .folders,
           selectedFolderNodeIDs.count == 1,
           let nodeID = selectedFolderNodeIDs.first,
           let folderURL = browserNodeMap[nodeID]?.folderURL {
            return folderURL
        }

        if let folderURL = selectedBrowserNode?.folderURL {
            return folderURL
        }

        if selectedBrowserNode?.kind == .sessionRoot {
            return currentSession?.sourceFolder
        }

        return nil
    }

    private func thumbnailPrefetchCandidates(from items: [MediaItem], excluding visibleIDs: Set<UUID>) -> [MediaItem] {
        guard !items.isEmpty else { return [] }
        let limit = max(96, visibleIDs.count * 4)
        return Array(items.lazy.filter { !visibleIDs.contains($0.id) }.prefix(limit))
    }

    private func preheatDisplayImages(around itemID: UUID, in items: [MediaItem], radius: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            preheatDisplayImages(for: [itemID], limit: 1)
            return
        }

        let lowerBound = max(items.startIndex, index - radius)
        let upperBound = min(items.index(before: items.endIndex), index + radius)
        preheatDisplayImages(for: items[lowerBound...upperBound].map(\.id), limit: (radius * 2) + 1)
    }

    private func preheatDisplayImages(around itemID: UUID, in itemIDs: [UUID], radius: Int) {
        guard let index = itemIDs.firstIndex(of: itemID) else {
            preheatDisplayImages(for: [itemID], limit: 1)
            return
        }

        let lowerBound = max(itemIDs.startIndex, index - radius)
        let upperBound = min(itemIDs.index(before: itemIDs.endIndex), index + radius)
        preheatDisplayImages(for: Array(itemIDs[lowerBound...upperBound]), limit: (radius * 2) + 1)
    }

    private func preheatDisplayImages(for itemIDs: [UUID], limit: Int) {
        let requests = itemIDs
            .prefix(max(limit, 0))
            .compactMap { mediaItem(for: $0) }
            .filter { ArchiveByteReadPolicyContext.shared.canPreheatOriginal(at: $0.sourceURL) }
            .filter { fileManager.fileExists(atPath: $0.sourceURL.path) }
            .map { DecodedImageRequest.interactiveDisplay($0.sourceURL, priority: .userInitiated) }

        guard !requests.isEmpty else { return }
        Task {
            await DecodedImagePipeline.shared.preheat(requests)
        }
    }

    private func refreshArchiveIndexAfterCrop(at url: URL) {
        guard canWriteArchiveIndex,
              ArchiveIndexStore.archiveRelativePath(for: url, archiveRoot: settings.archiveRoot) != nil else { return }
        let folder = url.deletingLastPathComponent()
        let archiveRoot = settings.archiveRoot
        let policy = archiveIndexWritePolicy
        Task {
            do {
                if try ArchiveIndexStore().loadWalkManifest(folder: folder, archiveRoot: archiveRoot) != nil {
                    try await ArchiveIndexMutationQueue.shared.replaceWalkFolders([folder], archiveRoot: archiveRoot, policy: policy)
                } else {
                    _ = try await ArchiveIndexMutationQueue.shared.rebuildIndex(archiveRoot: archiveRoot, policy: policy)
                }
                reloadArchiveCatalogue()
            } catch {
                statusMessage = "Crop saved, but Archive Index refresh failed: \(error.localizedDescription)"
            }
        }
    }

    private func refreshArchiveIndexAfterMetadataEditIfNeeded() {
        guard canWriteArchiveIndex,
              let currentSession,
              currentSession.mediaItems.contains(where: { $0.destinationURL != nil }) else { return }
        let walkFolders = Array(Set(currentSession.mediaItems.compactMap { $0.destinationURL?.deletingLastPathComponent() }))
        guard !walkFolders.isEmpty else { return }
        refreshArchiveIndexAfterWalkFolders(walkFolders, statusPrefix: "Archive Index refreshed for updated metadata")
    }

    private func refreshArchiveIndexAfterWalkMove(destinationWalkFolder: URL, removingWalkPath: String?, tripFolders: [URL]) {
        guard canWriteArchiveIndex else { return }
        let archiveRoot = settings.archiveRoot
        let policy = archiveIndexWritePolicy
        Task {
            do {
                try await ArchiveIndexMutationQueue.shared.replaceWalkFolders(
                    [destinationWalkFolder],
                    archiveRoot: archiveRoot,
                    policy: policy,
                    removingWalkPaths: Set([removingWalkPath].compactMap { $0 }),
                    tripFolders: Array(Set(tripFolders))
                )
                reloadArchiveCatalogue()
            } catch {
                logger.error("Archive Index refresh after Walk move failed: \(error.localizedDescription, privacy: .public)")
                statusMessage = "Moved Walk, but Archive Index refresh failed: \(error.localizedDescription)"
            }
        }
    }

    private func refreshArchiveIndexAfterWalkFolders(_ walkFolders: [URL], statusPrefix: String) {
        guard canWriteArchiveIndex else { return }
        let archiveRoot = settings.archiveRoot
        let policy = archiveIndexWritePolicy
        Task {
            do {
                try await ArchiveIndexMutationQueue.shared.replaceWalkFolders(
                    walkFolders,
                    archiveRoot: archiveRoot,
                    policy: policy
                )
                statusMessage = "\(statusPrefix)."
                reloadArchiveCatalogue()
            } catch {
                logger.error("Archive Index targeted refresh failed: \(error.localizedDescription, privacy: .public)")
                statusMessage = "\(statusPrefix) failed: \(error.localizedDescription)"
            }
        }
    }

    private func scheduleArchiveIndexUpdate(after result: ImportResult) {
        let policy = ArchiveIndexWritePolicy(machineRole: result.session.archiveMachineRole)
        guard policy.canWriteIndex else { return }
        Task {
            statusMessage = "Copy complete; updating Archive Index in the background..."
            do {
                try await ArchiveIndexMutationQueue.shared.updateAfterImport(result: result, policy: policy)
                statusMessage = "Archive Index updated for \(result.fileManifests.count) imported photo(s)."
                reloadArchiveCatalogue()
            } catch {
                logger.error("Archive Index update after import failed: \(error.localizedDescription, privacy: .public)")
                statusMessage = "Copy complete; Archive Index update failed: \(error.localizedDescription)"
            }
        }
    }

    private func rebuildArchiveIndexAfterSuccessfulMigration(archiveRoot: URL) {
        guard canWriteArchiveIndex else { return }
        let policy = archiveIndexWritePolicy
        Task {
            do {
                _ = try await ArchiveIndexMutationQueue.shared.rebuildIndex(archiveRoot: archiveRoot, policy: policy)
                reloadArchiveCatalogue()
            } catch {
                logger.error("Archive Index rebuild after migration failed: \(error.localizedDescription, privacy: .public)")
                statusMessage = "Archive migration finished, but Archive Index rebuild failed: \(error.localizedDescription)"
            }
        }
    }

    private func configurePersistence(reusing recoveredStore: SessionPersisting? = nil) {
        ArchiveByteReadPolicyContext.shared.update(settings: settings)
        let configuration = sessionLifecycleCoordinator.configurePersistence(settings: settings, existingSessionStore: recoveredStore)
        hasDurableSessionPersistence = !(configuration.sessionStore is InMemorySessionStore)
        sessionStore = BackupGuardedSessionStore(configuration.sessionStore, gate: backupPersistenceGate)
        previewStore = configuration.previewStore
        sessionManager = configuration.sessionManager
        importWorkflow = configuration.importWorkflow
        browserViewModel = configuration.browserViewModel
        startupAlert = configuration.startupAlert
        importProgress = importWorkflow.importProgress
        refreshAllUIState()
    }

    private func invalidateArchiveContext() {
        cancelArchiveMediaLoad()
        archiveCatalogueLoadTask?.cancel(); archiveCatalogueLoadTask = nil
        archiveCatalogueLoadGeneration &+= 1
        archiveSearchTask?.cancel(); archiveSearchTask = nil
        archiveSearchRequestID = UUID()
        archiveSearchDatabaseSnapshot = nil
        archiveSavedTripLocationOverlays.removeAll()
        archiveSearchIsLoading = false; archiveSearchError = nil
        archiveSearchMatchingPaths = []
        selectedArchiveSearchTarget = nil; selectedArchiveSearchResultID = nil
        archiveSearchReturnPhotoID = nil
        archiveNavigationLevel = .archive
        activeArchiveContentNode = nil
        archiveMediaCache.removeAll(); archiveMediaCacheRevisions.removeAll()
        archiveCatalogue = .empty
        archiveCatalogueIsLoading = false; archiveCatalogueError = nil
        selectedArchiveEntryID = nil; selectedArchiveWalkID = nil; selectedArchiveMapItemID = nil
        if workspaceMode == .archiveView {
            selectedSidebarNodeID = preferredSidebarNodeID(for: .archiveView)
            clearDetailSelections()
        }
        refreshArchiveBrowserState()
    }

    func retryArchiveFolderLoad() {
        guard case .photos = archiveNavigationLevel, let nodeID = activeArchiveContentNode?.id else { return }
        archiveMediaCacheRevisions.removeValue(forKey: nodeID)
        loadArchiveMediaIfNeeded(for: nodeID)
    }

    private func loadArchiveMediaIfNeeded(for nodeID: String?) {
        guard let nodeID, let node = browserNodeMap[nodeID],
              (node.children?.isEmpty ?? true), node.folderURL != nil, node.kind == .archiveWalkFolder else {
            cancelArchiveMediaLoad(); refreshArchiveBrowserState(); return
        }
        latencyRecorder.begin("archive.load")
        if archiveRequestedSearchPhotoPath == nil {
            archiveFolderSelectionToRestore = archiveFolderSelectionToRestore ?? captureArchiveFolderSelection()
        }
        cancelArchiveMediaLoad(clearPendingHit: false)
        let capturedSettings = settings
        let contextGeneration = ArchiveByteReadPolicyContext.shared.generation
        let requestedPath = archiveRequestedSearchPhotoPath
        let generation = archiveMediaLoadGeneration
        if let cached = archiveMediaCache[nodeID], archiveMediaCacheRevisions[nodeID] == archiveMediaCatalogueRevision {
            applyArchiveFolderResult(ArchiveLoadResult(nodeID: nodeID, items: cached, statusMessage: "Loaded \(cached.count) archived photo(s)."),
                requestedPath: requestedPath, capturedSettings: capturedSettings)
            return
        }
        archiveFolderLoadState = .loading
        statusMessage = "Loading archive photos from \(node.title)…"
        refreshArchiveBrowserState()
        let handler = testingArchiveLoadHandler
        archiveMediaLoadTask = Task.detached(priority: .userInitiated) {
            let result: Result<ArchiveLoadResult?, Error>
            do {
                let value: ArchiveLoadResult?
                if let handler { value = try await handler(node, capturedSettings) }
                else { value = try BrowserViewModel(scanner: FileScanner()).loadArchiveMedia(for: node, settings: capturedSettings) }
                result = .success(value)
            } catch { result = .failure(error) }
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled, generation == self.archiveMediaLoadGeneration,
                      contextGeneration == ArchiveByteReadPolicyContext.shared.generation,
                      self.settings.archiveRoot.standardizedFileURL == capturedSettings.archiveRoot.standardizedFileURL,
                      self.settings.archiveMachineRole == capturedSettings.archiveMachineRole,
                      self.settings.oneDrivePicturesRoot.standardizedFileURL == capturedSettings.oneDrivePicturesRoot.standardizedFileURL,
                      self.selectedBrowserNode?.id == nodeID else { return }
                self.archiveMediaLoadTask = nil
                switch result {
                case .success(let value):
                    guard let value, value.nodeID == nodeID else {
                        self.archiveFolderLoadState = .failed("This folder could not be loaded.")
                        break
                    }
                    self.applyArchiveFolderResult(value, requestedPath: requestedPath, capturedSettings: capturedSettings)
                case .failure(let error):
                    self.archiveFolderLoadState = .failed(error.localizedDescription)
                    self.statusMessage = "Failed to load archive folder: \(error.localizedDescription)"
                }
                self.latencyRecorder.end("archive.load")
                self.refreshArchiveBrowserState()
            }
        }
    }

    private func applyArchiveFolderResult(_ result: ArchiveLoadResult, requestedPath: String?, capturedSettings: AppSettings) {
        let folderPath = selectedBrowserNode?.folderURL.flatMap {
            ArchiveIndexStore.archiveRelativePath(for: $0, archiveRoot: capturedSettings.archiveRoot)
        } ?? "."
        guard result.items.allSatisfy({ item in
            guard let path = ArchiveIndexStore.archiveRelativePath(for: item.sourceURL, archiveRoot: capturedSettings.archiveRoot) else { return false }
            return folderPath == "." || path.hasPrefix(folderPath + "/")
        }) else {
            archiveFolderLoadState = .failed("The folder returned a photo outside its Archive destination.")
            statusMessage = "Archive folder load rejected an inconsistent photo path."
            refreshArchiveBrowserState()
            return
        }
        let items = MediaItemSort.sorted(result.items.map { item -> MediaItem in
            var item = item
            if let path = ArchiveIndexStore.archiveRelativePath(for: item.sourceURL, archiveRoot: capturedSettings.archiveRoot) {
                item.archiveRelativePath = path
                if let photo = archiveLocationPhotosByPath[path] {
                    item.metadata.latitude = photo.latitude; item.metadata.longitude = photo.longitude
                }
            }
            return googleProjectedItem(item)
        })
        // Capture the current UI state now: closing Preview/Compare during a suspended
        // refresh must win over the earlier refresh snapshot.
        let selectionToRestore = requestedPath == nil ? (captureArchiveFolderSelection() ?? archiveFolderSelectionToRestore) : nil
        if let oldItems = archiveMediaCache[result.nodeID], let backup = compareSelectionBackup {
            let oldPaths = Dictionary(oldItems.compactMap { item in item.archiveRelativePath.map { (item.id, $0) } },
                uniquingKeysWith: { first, _ in first })
            let newIDs = Dictionary(items.compactMap { item in item.archiveRelativePath.map { ($0, item.id) } },
                uniquingKeysWith: { first, _ in first })
            var state = backup.selectionState
            state.selectedMediaItemIDs = Set(state.selectedMediaItemIDs.compactMap { oldPaths[$0].flatMap { newIDs[$0] } })
            state.focusedReviewItemID = state.focusedReviewItemID.flatMap { oldPaths[$0] }.flatMap { newIDs[$0] }
            state.reviewSelectionAnchorID = state.reviewSelectionAnchorID.flatMap { oldPaths[$0] }.flatMap { newIDs[$0] }
            compareSelectionBackup = CompareSelectionBackup(selectionState: state, keyboardTarget: backup.keyboardTarget)
        }
        archiveMediaCacheRevisions[result.nodeID] = archiveMediaCatalogueRevision
        archiveMediaCache[result.nodeID] = items
        archiveFolderLoadState = .loaded
        archiveMissingSearchHitMessage = nil
        statusMessage = result.statusMessage
        if let requestedPath {
            archiveRequestedSearchPhotoPath = nil
            archiveFolderSelectionToRestore = nil
            reviewFilter = .all
            dayDetailDisplayMode = .review
            if let hit = items.first(where: { $0.archiveRelativePath == requestedPath }) {
                focusMediaItem(hit, openPreview: false)
                activateReviewGridFocus()
            } else {
                clearDetailSelections()
                archiveMissingSearchHitMessage = "The matching photo is no longer in this folder. Return to search and refresh the Archive."
                statusMessage = archiveMissingSearchHitMessage!
            }
        }
        if let selection = selectionToRestore {
            archiveFolderSelectionToRestore = nil
            let byPath = Dictionary(items.compactMap { item in item.archiveRelativePath.map { ($0, item.id) } },
                uniquingKeysWith: { first, _ in first })
            selectedMediaItemIDs = Set(selection.selectedPaths.compactMap { byPath[$0] })
            focusedReviewItemID = selection.focusedPath.flatMap { byPath[$0] }
            reviewSelectionAnchorID = selection.anchorPath.flatMap { byPath[$0] }
            previewingMediaItemID = selection.previewPath.flatMap { byPath[$0] }
            comparingMediaItemIDs = selection.comparePaths.compactMap { byPath[$0] }
            pendingReviewScrollTargetID = focusedReviewItemID
        }
        requestInitialArchiveThumbnails(for: items)
        if capturedSettings.archiveMachineRole != .travel {
            let urls = items.map(\.sourceURL)
            Task.detached(priority: .utility) { ArchiveByteReadPolicyContext.shared.warmOnlineOnlyVerdicts(for: urls) }
        }
        preheatDisplayImages(for: items.map(\.id), limit: 6)
        latencyRecorder.end("archive.load")
        refreshArchiveBrowserState()
    }

    private func captureArchiveFolderSelection() -> ArchiveFolderSelection? {
        guard let nodeID = activeArchiveContentNode?.id, let items = archiveMediaCache[nodeID] else { return nil }
        let paths = Dictionary(items.compactMap { item in
            ArchiveIndexStore.archiveRelativePath(for: item.sourceURL, archiveRoot: settings.archiveRoot).map { (item.id, $0) }
        }, uniquingKeysWith: { first, _ in first })
        return ArchiveFolderSelection(selectedPaths: Set(selectedMediaItemIDs.compactMap { paths[$0] }),
            focusedPath: focusedReviewItemID.flatMap { paths[$0] }, anchorPath: reviewSelectionAnchorID.flatMap { paths[$0] },
            previewPath: previewingMediaItemID.flatMap { paths[$0] }, comparePaths: comparingMediaItemIDs.compactMap { paths[$0] })
    }

    private func cancelArchiveMediaLoad(clearPendingHit: Bool = true) {
        archiveMediaLoadTask?.cancel(); archiveMediaLoadTask = nil
        archiveMediaLoadGeneration &+= 1
        archiveFolderLoadState = .idle
        archiveMissingSearchHitMessage = nil
        if clearPendingHit {
            archiveRequestedSearchPhotoPath = nil
            archiveFolderSelectionToRestore = nil
        }
    }

    private static func formatSeconds(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }

        let minutes = seconds / 60
        if minutes.rounded(.towardZero) == minutes {
            return String(format: "%.0fm", minutes)
        }
        return String(format: "%.1fm", minutes)
    }

    private func setCurrentSession(_ session: ImportSession?, updateKind: CurrentSessionUpdateKind) {
        currentSessionUpdateKind = updateKind
        currentSession = session
    }

    private static func thumbnailDecodeCacheKey(for imageURL: URL) -> String {
        "thumbnail:\(imageURL.path)"
    }

    private static func thumbnailCacheCost(for image: NSImage) -> Int {
        let representation = image.representations.first
        let width = representation?.pixelsWide ?? Int(image.size.width)
        let height = representation?.pixelsHigh ?? Int(image.size.height)
        return max(width, 1) * max(height, 1) * 4
    }

    private func decodeThumbnailIfNeeded(from imageURL: URL, itemID: UUID) {
        let path = imageURL.path
        guard thumbnailDecodeTasks[path] == nil else { return }

        thumbnailDecodeTasks[path] = Task { [weak self] in
            guard let self else { return }
            let decoded = await DecodedImagePipeline.shared.image(
                at: imageURL,
                cacheKey: Self.thumbnailDecodeCacheKey(for: imageURL),
                priority: .utility
            )
            guard !Task.isCancelled else { return }
            self.finishThumbnailDecode(image: decoded, imageURL: imageURL, itemID: itemID)
        }
    }

    private func finishThumbnailDecode(image: NSImage?, imageURL: URL, itemID: UUID) {
        thumbnailDecodeTasks[imageURL.path] = nil
        if let image {
            missingThumbnailPaths.remove(imageURL.path)
            thumbnailImageCache.setObject(image, forKey: imageURL as NSURL, cost: Self.thumbnailCacheCost(for: image))
            thumbnailRegistry.update(itemID: itemID, image: image, isMissing: false)
        } else {
            missingThumbnailPaths.insert(imageURL.path)
            thumbnailRegistry.update(itemID: itemID, image: nil, isMissing: true)
        }
    }

    private func startVolumeMonitoring() {
        volumeMountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let mountedURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            Task { @MainActor in
                await self.handleVolumeMounted(mountedURL)
            }
        }
    }

    private func handleVolumeMounted(_ mountedURL: URL?) async {
        guard sessionLifecycleCoordinator.matchesDefaultSourceMount(mountedURL, defaultSourceRoot: settings.defaultSourceRoot) else { return }
        guard let folder = sessionLifecycleCoordinator.resolvedDefaultSourceFolder(settings: settings) else { return }
        logger.log("Default source volume mounted; loading live source inbox from \(folder.path, privacy: .public)")
        loadSourceWorkspace(folder: folder, origin: .mountedDefault)
    }

    private func selectInitialWorkspace() async {
        logger.log("Selecting initial workspace using policy \(self.startupSelectionPolicy.rawValue, privacy: .public)")

        switch self.startupSelectionPolicy {
        case .sourceInboxFirst:
            if let folder = sessionLifecycleCoordinator.resolvedDefaultSourceFolder(settings: settings) {
                logger.log("Resolved default source folder to \(folder.path, privacy: .public)")
                loadSourceWorkspace(folder: folder, origin: .launchDefault)
            } else if persistedSessions.isEmpty == false {
                logger.log("Default source unavailable; falling back to most recent recoverable session")
                loadMostRecentSession(statusPrefix: "Default source SSD is unavailable; recovered the most recent saved session.")
            } else {
                sourceWorkspaceState = .idle
                statusMessage = "Waiting for default SSD at \(settings.defaultSourceRoot.path)."
            }
        }
    }
}
