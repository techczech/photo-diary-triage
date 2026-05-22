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

private struct CompareSelectionBackup {
    let selectionState: ReviewSelectionState
    let keyboardTarget: ReviewKeyboardTarget
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            refreshSidebarState()
            refreshReviewState()
            refreshInspectorState()
        }
    }
    @Published var currentSession: ImportSession? {
        didSet {
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

    let sidebarState = SidebarState()
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
    private var previewStore: PreviewCaching
    private let settingsStore: SettingsPersisting
    private var sessionManager: SessionManager
    private var importWorkflow: ImportWorkflow
    private var browserViewModel: BrowserViewModel
    private let selectionManager = SelectionManager()
    private let backupStore = BackupStore()
    private let persistedSessionNormalizer = PersistedSessionNormalizer()
    private let photoLogCreationResolver = PhotoLogCreationResolver()
    private let fileManager: FileManager
    private let sourceWorkspaceFolderResolver: SourceWorkspaceFolderResolver
    private let supportRoot: URL
    private let logger = AppLogger.appState
    private let latencyRecorder = LatencyRecorder()
    private var compareSelectionBackup: CompareSelectionBackup?
    var testingSourceScanHandler: ((URL, AppSettings) async throws -> SessionOpenResult)?
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
    private var currentSessionUpdateKind: CurrentSessionUpdateKind = .full
    private var pendingSessionPersistenceWorkItem: DispatchWorkItem?
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
    private var persistedSessions: [(ImportSession, [BurstGroup], [TimeCluster])] = []
    private var activePhotoLogMembershipEditID: UUID?

    init(testing: Bool = false) {
        self.fileManager = .default
        self.sourceWorkspaceFolderResolver = SourceWorkspaceFolderResolver(fileManager: self.fileManager)
        self.supportRoot = AppPaths.supportRoot()
        let settingsStore = SettingsStore(fileURL: self.supportRoot.appendingPathComponent("settings.json"))
        let settings = settingsStore.load(defaults: AppSettings.default())
        self.settings = settings
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
        self.sessionStore = InMemorySessionStore()
        self.previewStore = NoCachePreviewStore(cacheRoot: settings.cacheRoot)
        self.sessionManager = SessionManager(scanner: self.scanner, groupingService: self.groupingService)
        self.importWorkflow = ImportWorkflow(coordinator: self.importCoordinator)
        self.browserViewModel = BrowserViewModel(scanner: self.scanner)
        self.archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
        rebuildBrowserCaches()
        refreshAllUIState()

        if testing {
            return
        }

        configurePersistence()
        primePersistedSessionCache()
        startVolumeMonitoring()
        refreshAllUIState()
    }

    deinit {
        if let volumeMountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(volumeMountObserver)
        }
    }

    func performStartupRecovery() {
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
        cachedBrowserNodeMap
    }

    var selectedBrowserNode: BrowserNode? {
        guard let selectedSidebarNodeID else { return browserRoots.first }
        return browserNodeMap[selectedSidebarNodeID] ?? browserRoots.first
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
        inlineSectionOrganizer.groupedReviewSections(from: organizedInlineSections)
    }

    var canFocusReviewSurface: Bool {
        !visibleMediaItems.isEmpty
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
        return ids.compactMap { sessionMediaByID[$0] }.sorted(by: Self.mediaSort)
    }

    func orderedMediaItems(for ids: [UUID]) -> [MediaItem] {
        ids.compactMap { sessionMediaByID[$0] }
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
        if activePane == .folders { return selectedFolderNodeIDs.count == 1 }
        if activePane == .sidebar { return canFocusReviewSurface }
        if activePane == .media { return focusedReviewItem != nil }
        return false
    }

    var canNavigateToParent: Bool {
        selectedBrowserNode?.parentID != nil
    }

    var canClearCurrentSelection: Bool {
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
        canMutateImportSelection && selectedMediaItems.contains { !$0.companionFiles.isEmpty }
    }

    var canPresentPhotoLogCreation: Bool {
        currentSession?.sessionKind == .inbox && proposedPhotoLogCreationPlan(mode: .decidedInScope) != nil
    }

    var canCreateWalkDraftFromSelection: Bool {
        canPresentPhotoLogCreation
    }

    var selectedMediaItems: [MediaItem] {
        selectedMediaItemIDs.compactMap { sessionMediaByID[$0] }.sorted(by: Self.mediaSort)
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
        return sessionMediaByID[previewingMediaItemID]
    }

    var comparingMediaItems: [MediaItem] {
        let selectedIDs = Set(comparingMediaItemIDs)
        let orderedVisible = reviewInteractionItems.filter { selectedIDs.contains($0.id) }
        if orderedVisible.count == comparingMediaItemIDs.count {
            return orderedVisible
        }
        return comparingMediaItemIDs.compactMap { sessionMediaByID[$0] }
    }

    var canOpenSettings: Bool { true }

    var canOpenComparison: Bool {
        currentSelectionMediaIDs().count >= 2
    }

    var canCommitImport: Bool {
        guard importOperation.isRunning == false else { return false }
        return currentSession?.mediaItems.contains {
            $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond
        } ?? false
    }

    var canConfirmBackup: Bool {
        guard importOperation.isRunning == false else { return false }
        guard let currentSession else { return false }
        guard currentSession.walkMetadata.backupConfirmedAt == nil else { return false }
        return currentSession.mediaItems.contains {
            $0.selectionState.isIncluded && ($0.lifecycleState == .verified || $0.lifecycleState == .imported)
        }
    }

    var canCleanupImportedSources: Bool {
        guard importOperation.isRunning == false else { return false }
        guard let currentSession else { return false }
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
        !isBrowsingArchive && !importOperation.isRunning
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

    func pickSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.defaultSourceRoot

        if panel.runModal() == .OK, let folder = panel.urls.first {
            loadSourceWorkspace(folder: folder, origin: .manualPicker)
        }
    }

    func openSourceInbox(for workspaceSourceFolder: URL) {
        loadSourceWorkspace(folder: workspaceSourceFolder, origin: .savedWalkInbox)
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
        let standardizedFolder = folder.standardizedFileURL
        let resolvedFolder = sourceWorkspaceFolderResolver.resolve(selectedFolder: standardizedFolder)
        do {
            flushPendingSessionPersistence()
            let resolvedFolderPath = resolvedFolder.path
            try reloadPersistedSessionsFromStore()
            logger.log("Starting source workspace load from \(standardizedFolder.path, privacy: .public) resolved to \(resolvedFolder.path, privacy: .public) via \(origin.rawValue, privacy: .public)")
            sourceWorkspaceState = .loading(sourcePath: resolvedFolder.path)
            statusMessage = "Scanning source folder \(resolvedFolder.lastPathComponent)..."

            let scanned = try await scanSourceFolder(for: resolvedFolder, settings: settings)
            guard !Task.isCancelled, generation == sourceLoadGeneration else {
                logger.log("Discarded stale source load for \(resolvedFolder.path, privacy: .public)")
                return
            }

            let existingInbox = persistedSessions.first(where: {
                $0.0.sessionKind == .inbox && $0.0.workspaceSourceFolder.standardizedFileURL.path == resolvedFolderPath
            })
            let rebuiltInbox = rebuildInboxSession(
                from: scanned,
                workspaceSourceFolder: resolvedFolder,
                existingInbox: existingInbox?.0
            )
            let normalizedInbox = normalizeInboxRecord((rebuiltInbox, scanned.bursts, scanned.clusters))
            try sessionManager.save(normalizedInbox.0, bursts: normalizedInbox.1, clusters: normalizedInbox.2, to: sessionStore)
            storePersistedSession(normalizedInbox.0, bursts: normalizedInbox.1, clusters: normalizedInbox.2)

            let message: String
            if normalizedInbox.0.mediaItems.isEmpty {
                sourceWorkspaceState = .empty(sourcePath: resolvedFolder.path)
                message = sourceLoadStatusMessage(
                    base: "Loaded inbox for \(resolvedFolder.lastPathComponent); no unassigned supported media are currently visible.",
                    sourcePath: resolvedFolder.path
                )
            } else {
                sourceWorkspaceState = .loaded(itemCount: normalizedInbox.0.mediaItems.count, sourcePath: resolvedFolder.path)
                message = sourceLoadStatusMessage(
                    base: "Loaded inbox with \(normalizedInbox.0.mediaItems.count) unassigned items from \(resolvedFolder.lastPathComponent).",
                    sourcePath: resolvedFolder.path
                )
            }
            openPersistedSessionRecord(
                normalizedInbox,
                status: message
            )
            requestVisibleThumbnails(prefetching: normalizedInbox.0.mediaItems)
        } catch {
            guard generation == sourceLoadGeneration else { return }
            logger.error("Failed to open session for \(folder.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            sourceWorkspaceState = .failed(sourcePath: resolvedFolder.path, message: error.localizedDescription)
            statusMessage = "Failed to load source folder: \(error.localizedDescription)"
        }
    }

    func openSavedWalk(_ sessionID: UUID) {
        guard let record = persistedSessions.first(where: { $0.0.id == sessionID }) else {
            statusMessage = "Photo log could not be found in the local library."
            return
        }

        invalidateInFlightSourceLoad()
        sourceWorkspaceState = .idle
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
        let editableItems = editableItemsByPath.values.sorted(by: Self.mediaSort)
        let grouped = groupingService.group(items: editableItems, settings: settings)

        var editableSession = logRecord.0
        editableSession.mediaItems = grouped.items
        editableSession.lastUpdatedAt = Date()
        editableSession.status = "draft"

        activePhotoLogMembershipEditID = sessionID
        invalidateInFlightSourceLoad()
        sourceWorkspaceState = .idle
        openPersistedSessionRecord(
            (editableSession, grouped.burstGroups, grouped.timeClusters),
            status: "Editing items for \(editableSession.walkMetadata.title.nonEmpty ?? "Untitled Photo Log"). S/C/X keeps a photo in the log; clearing it to undecided returns it to the source inbox."
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
            sessionKind: .walkDraft,
            status: "draft",
            mediaItems: draftGrouped.items
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
            try sessionManager.save(draftSession, bursts: draftGrouped.burstGroups, clusters: draftGrouped.timeClusters, to: sessionStore)
            try sessionManager.save(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters, to: sessionStore)
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

    func saveActivePhotoLogEdits() {
        guard let editor = activePhotoLogEditor else { return }
        guard case .edit(let sessionID) = editor.mode else { return }
        guard let record = persistedSessions.first(where: { $0.0.id == sessionID }) else {
            statusMessage = "Photo log could not be found in the local library."
            activePhotoLogEditor = nil
            return
        }

        var updatedSession = record.0
        updatedSession.lastUpdatedAt = Date()
        updatedSession.walkMetadata.title = editor.title
        updatedSession.walkMetadata.location = editor.location
        updatedSession.walkMetadata.notes = editor.notes
        updatedSession.photoLogScope = photoLogScope(from: editor, fallback: defaultPhotoLogScope(for: updatedSession))

        do {
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

        let returnableItems = logRecord.0.mediaItems.filter { !$0.lifecycleState.isImportedOrBeyond }
        let updatedInboxRecord = rebuildInboxAfterDeletingPhotoLog(logRecord.0, returning: returnableItems)
        var updatedRecords = persistedSessions.filter { $0.0.id != sessionID && $0.0.id != updatedInboxRecord.0.id }
        updatedRecords.append(updatedInboxRecord)
        updatedRecords.sort { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }

        do {
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

    func updateWalkMetadata(title: String, location: String, notes: String) {
        guard let currentSession else { return }
        save(sessionMutationCoordinator.sessionByUpdatingWalkMetadata(currentSession, title: title, location: location, notes: notes))
    }

    func updateWalkDetailsExpansion(for session: ImportSession?) {
        isWalkDetailsExpanded = sessionMutationCoordinator.walkDetailsShouldExpand(for: session)
    }

    func setImportRawCompanions(for item: MediaItem, enabled: Bool) {
        guard let currentSession else { return }
        save(sessionMutationCoordinator.sessionBySettingImportRawCompanions(currentSession, for: item.id, enabled: enabled))
    }

    func markBackupConfirmed() {
        guard let currentSession else { return }
        save(sessionMutationCoordinator.sessionByMarkingBackupConfirmed(currentSession))
    }

    func commitImport() {
        guard let session = currentSession else { return }
        guard canCommitImport else { return }
        let readiness = importReadinessSnapshot(for: session)
        let destinationPath = readiness?.destinationPath

        Task {
            do {
                let initialProgress = ImportProgress(current: 0, total: readiness?.totalFiles ?? ImportProgress.expectedTotalEntries(for: session))
                importProgress = initialProgress
                importOperation = ImportOperationSnapshot(
                    phase: .copying,
                    title: "Copying to archive",
                    detail: "Copied 0 of \(initialProgress.total) file(s).",
                    progress: initialProgress,
                    destinationPath: destinationPath
                )
                statusMessage = "Copying marked files into archive..."
                let result = try await importWorkflow.commit(session: session) { [weak self] progress in
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
                importProgress = nil
                importOperation = ImportOperationSnapshot(
                    phase: .completed,
                    title: "Copy complete",
                    detail: "Copied and verified \(result.fileManifests.count) photo(s). Manifests were written.",
                    progress: nil,
                    destinationPath: result.walkManifest.archiveFolder.path
                )
                statusMessage = "Imported \(result.fileManifests.count) marked items and wrote manifests."
            } catch {
                importProgress = nil
                importOperation = ImportOperationSnapshot(
                    phase: .failed,
                    title: "Copy failed",
                    detail: error.localizedDescription,
                    progress: nil,
                    destinationPath: destinationPath
                )
                statusMessage = error.localizedDescription
            }
        }
    }

    func cleanupImportedSources() {
        guard let session = currentSession else { return }

        Task {
            do {
                statusMessage = "Cleaning imported source files from SSD..."
                let cleaned = try await importWorkflow.cleanupImportedSources(in: session)
                setCurrentSession(cleaned, updateKind: .sessionOnly)
                persistCurrentSession(immediately: true)
                statusMessage = "Removed verified imported files from the source SSD."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
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

    func setArchiveRoot(_ archiveRoot: URL) {
        settings.archiveRoot = archiveRoot
        archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: archiveRoot)
        archiveMediaCache.removeAll()
        rebuildBrowserCaches()

        if var session = currentSession {
            session.archiveRoot = archiveRoot
            save(session)
        }

        persistSettings()
        let existingYears = archiveYearFolders.isEmpty ? "no existing 202x folders detected yet" : "found year folders: \(archiveYearFolders.joined(separator: ", "))"
        statusMessage = "Archive root set to \(archiveRoot.path); \(existingYears)."
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.isSidebarVisible, self.activePane == .sidebar else { return }
            self.focusSidebarFirstResponder()
        }
    }

    func focusReviewSurface() {
        guard canFocusReviewSurface else { return }
        if dayDetailDisplayMode == .sections {
            ensureFocusedInlineSection()
        }
        reviewKeyboardTarget = .items
        activateReviewGridFocus()
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
        expandedInlineSectionIDs.formUnion(sectionPath)
        selectInlineMediaItem(itemID)
        focusedInlineSectionID = sectionPath.last
        focusedReviewItemID = itemID
        activePane = .media
        reviewKeyboardTarget = .items
        DispatchQueue.main.async { [weak self] in
            self?.pendingInlineScrollTargetID = itemID
        }
    }

    func selectInlineMediaItem(_ itemID: UUID) {
        previewingMediaItemID = nil
        selectMediaItems([itemID])
        syncFocusedInlineSectionToFocusedItem()
        focusedReviewItemID = itemID
        activePane = .media
        reviewGridHasFocus = true
        reviewKeyboardTarget = .items
    }

    func previewItems(for section: InlineSection, limit: Int = 18) -> [MediaItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: mediaItems(for: section.mediaItemIDs).map { ($0.id, $0) })
        let orderedIDs = inlineSectionOrganizer.previewItemIDs(for: section, availableItems: itemsByID, limit: limit)
        return orderedIDs.compactMap { itemsByID[$0] }
    }

    func selectFolderNodes(_ nodeIDs: Set<String>) {
        selectedFolderNodeIDs = nodeIDs
        activePane = .folders
        selectedMediaItemIDs.removeAll()
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
        var state = reviewSelectionState()
        selectionManager.selectAllVisibleMedia(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func deselectAllVisibleMedia() {
        var state = reviewSelectionState()
        selectionManager.deselectAllVisibleMedia(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func toggleFocusedReviewItemSelection() {
        var state = reviewSelectionState()
        selectionManager.toggleFocusedReviewItemSelection(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func selectFocusedReviewItemOnly() {
        var state = reviewSelectionState()
        selectionManager.selectFocusedReviewItemOnly(reviewInteractionItems, state: &state)
        applyReviewSelectionState(state)
    }

    func openFocusedReviewItem() {
        guard let focusedID = focusedReviewItemID ?? selectedMediaItemIDs.first else { return }
        previewingMediaItemID = focusedID
    }

    func drillIntoFocusedInlineSection() {
        guard let section = focusedInlineSection else { return }
        let scopedItemIDs = resolvedMediaItemIDs(in: section)
        guard !scopedItemIDs.isEmpty else { return }
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

    func navigatePreview(by offset: Int) {
        guard let targetID = previewNavigationOffset(offset) else { return }
        previewingMediaItemID = targetID
        focusedReviewItemID = targetID
        selectedMediaItemIDs = [targetID]
        reviewSelectionAnchorID = targetID
        activePane = .media
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

    func toggleSelectionForComparisonItem(_ itemID: UUID) {
        handleGridSelection(for: itemID, modifiers: [.command])
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
        guard let parentID = selectedBrowserNode?.parentID else { return }
        selectSidebarNode(parentID)
    }

    func clearCurrentSelection() {
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
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        updateTriageState(for: selectedIDs, selectionState: .included)
        statusMessage = "Selected \(selectedIDs.count) item(s) for import."
        advanceAfterTriageAction(for: selectedIDs)
    }

    func excludeCurrentSelectionFromImport() {
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        updateTriageState(for: selectedIDs, selectionState: .excluded)
        statusMessage = "Excluded \(selectedIDs.count) item(s) from import."
        advanceAfterTriageAction(for: selectedIDs)
    }

    func markCurrentSelectionAsCandidate() {
        guard canMutateImportSelection else { return }
        let selectedIDs = currentSelectionMediaIDs()
        updateTriageState(for: selectedIDs, selectionState: .candidate)
        statusMessage = "Marked \(selectedIDs.count) item(s) as candidates."
        advanceAfterTriageAction(for: selectedIDs)
    }

    func unmarkCurrentSelectionForImport() {
        guard canMutateImportSelection else { return }
        updateTriageState(for: currentSelectionMediaIDs(), selectionState: .undecided)
        statusMessage = "Cleared \(currentSelectionMediaIDs().count) item(s) back to undecided."
    }

    func toggleRawForCurrentMediaSelection() {
        guard canMutateImportSelection else { return }
        guard let currentSession else { return }
        save(sessionMutationCoordinator.sessionByTogglingRawCompanions(currentSession, selectedIDs: selectedMediaItemIDs))
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

    func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "photo-diary-triage-backup.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let sessions = try sessionStore.loadSessions()
            try backupStore.exportBackup(settings: settings, sessions: sessions, to: url)
            statusMessage = "Exported app backup to \(url.path)."
        } catch {
            statusMessage = "Backup export failed: \(error.localizedDescription)"
        }
    }

    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.urls.first else { return }

        do {
            let backup = try backupStore.importBackup(from: url)
            settings = backup.settings
            try sessionStore.replaceAllSessions(with: backup.sessions.map { ($0.session, $0.bursts, $0.timeClusters) })
            try reloadPersistedSessionsFromStore()
            persistSettings()
            archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
            loadMostRecentSession()
            statusMessage = "Imported app backup from \(url.lastPathComponent)."
        } catch {
            statusMessage = "Backup import failed: \(error.localizedDescription)"
        }
    }

    private func updateTriageState(for mediaIDs: Set<UUID>, selectionState: SelectionState) {
        guard let currentSession else { return }
        save(sessionMutationCoordinator.sessionByUpdatingTriageState(currentSession, mediaIDs: mediaIDs, selectionState: selectionState))
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
        mergedItems.sort(by: Self.mediaSort)
        let grouped = groupingService.group(items: mergedItems, settings: settings)

        var inbox = existingInbox ?? ImportSession(
            sourceFolder: deletedLog.sourceFolder,
            workspaceSourceFolder: deletedLog.workspaceSourceFolder,
            archiveRoot: deletedLog.archiveRoot,
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

    private func resetInlineExpansionState() {
        expandedInlineSectionIDs = Set(inlineSectionOrganizer.flattenSectionIDs(from: organizedInlineSections))
        pendingInlineSectionScrollTargetID = nil
        estimatedVisibleReviewIndexRange = nil

        if dayDetailDisplayMode == .sections {
            ensureFocusedInlineSection()
        } else {
            focusedInlineSectionID = nil
        }
        reconcileReviewSelectionWithVisibleItems()
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

        let fallbackSidebarNodeID = browserViewModel.preferredInitialSidebarNodeID(for: session, bursts: grouped.burstGroups, clusters: grouped.timeClusters)
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
        guard let currentSession else { return }
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

        pendingSessionPersistenceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            do {
                try sessionManager.save(session, bursts: bursts, clusters: clusters, to: sessionStore)
            } catch {
                logger.error("Failed to persist current session: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self?.statusMessage = "Session save failed: \(error.localizedDescription)"
                }
            }
        }
        pendingSessionPersistenceWorkItem = workItem

        let deadline: DispatchTime = immediately ? .now() : .now() + .milliseconds(160)
        sessionPersistenceQueue.asyncAfter(deadline: deadline, execute: workItem)
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
        inboxItems.sort(by: Self.mediaSort)

        let memberGrouped = groupingService.group(items: memberItems.sorted(by: Self.mediaSort), settings: settings)
        let inboxGrouped = groupingService.group(items: inboxItems, settings: settings)

        var updatedLog = editingSession
        updatedLog.mediaItems = memberGrouped.items
        updatedLog.lastUpdatedAt = Date()
        updatedLog.status = memberGrouped.items.isEmpty ? "draft_empty" : "draft"

        var updatedInbox = existingInbox ?? ImportSession(
            sourceFolder: editingSession.sourceFolder,
            workspaceSourceFolder: editingSession.workspaceSourceFolder,
            archiveRoot: editingSession.archiveRoot,
            sessionKind: .inbox,
            status: "draft"
        )
        updatedInbox.mediaItems = inboxGrouped.items
        updatedInbox.lastUpdatedAt = Date()
        updatedInbox.walkMetadata = .empty
        updatedInbox.photoLogScope = nil
        updatedInbox.sessionKind = .inbox
        updatedInbox.sessionKindWasExplicit = true
        updatedInbox.status = inboxGrouped.items.isEmpty ? "inbox_empty" : "draft"

        storePersistedSession(updatedLog, bursts: memberGrouped.burstGroups, clusters: memberGrouped.timeClusters)
        storePersistedSession(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters)

        pendingSessionPersistenceWorkItem?.cancel()
        let sessionManager = self.sessionManager
        let sessionStore = self.sessionStore
        let logger = self.logger
        let workItem = DispatchWorkItem { [weak self] in
            do {
                try sessionManager.save(updatedLog, bursts: memberGrouped.burstGroups, clusters: memberGrouped.timeClusters, to: sessionStore)
                try sessionManager.save(updatedInbox, bursts: inboxGrouped.burstGroups, clusters: inboxGrouped.timeClusters, to: sessionStore)
            } catch {
                logger.error("Failed to persist photo log membership edit: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async {
                    self?.statusMessage = "Photo log membership save failed: \(error.localizedDescription)"
                }
            }
        }
        pendingSessionPersistenceWorkItem = workItem

        let deadline: DispatchTime = immediately ? .now() : .now() + .milliseconds(160)
        sessionPersistenceQueue.asyncAfter(deadline: deadline, execute: workItem)
    }

    private func flushPendingSessionPersistence() {
        guard let workItem = pendingSessionPersistenceWorkItem else { return }
        pendingSessionPersistenceWorkItem = nil
        sessionPersistenceQueue.sync {
            workItem.perform()
        }
        workItem.cancel()
    }

    private func persistSettings() {
        do {
            try sessionLifecycleCoordinator.persistSettings(settings, to: settingsStore)
        } catch {
            logger.error("Failed to persist settings: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Settings save failed: \(error.localizedDescription)"
        }
    }

    private func reloadPersistedSessionsFromStore() throws {
        let loadedSessions = try sessionStore.loadSessions()
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
        refreshSidebarState()
    }

    private func storePersistedSession(_ session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) {
        persistedSessions.removeAll { $0.0.id == session.id }
        persistedSessions.append((session, bursts, clusters))
        persistedSessions.sort { $0.0.lastUpdatedAt > $1.0.lastUpdatedAt }
        refreshSidebarState()
    }

    private func openPersistedSessionRecord(
        _ record: (ImportSession, [BurstGroup], [TimeCluster]),
        status: String
    ) {
        activePhotoLogMembershipEditID = nil
        setCurrentSession(record.0, updateKind: .full)
        burstGroups = record.1
        timeClusters = record.2
        selectedSidebarNodeID = browserViewModel.preferredInitialSidebarNodeID(for: record.0, bursts: record.1, clusters: record.2)
        clearDetailSelections()
        archiveMediaCache.removeAll()
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

    private func ownedRelativePaths(
        for workspaceSourceFolder: URL,
        excludingSessionIDs: Set<UUID> = []
    ) -> Set<String> {
        let standardizedFolderPath = workspaceSourceFolder.standardizedFileURL.path
        return Set(
            persistedSessions
                .filter {
                    $0.0.sessionKind == .walkDraft &&
                    $0.0.sessionKindWasExplicit &&
                    !excludingSessionIDs.contains($0.0.id) &&
                    $0.0.workspaceSourceFolder.standardizedFileURL.path == standardizedFolderPath
                }
                .flatMap { $0.0.mediaItems.map(\.relativePath) }
        )
    }

    private func normalizeInboxRecord(
        _ record: (ImportSession, [BurstGroup], [TimeCluster])
    ) -> (ImportSession, [BurstGroup], [TimeCluster]) {
        var session = record.0
        let assignedPaths = ownedRelativePaths(
            for: session.workspaceSourceFolder,
            excludingSessionIDs: [session.id]
        )
        guard !assignedPaths.isEmpty else { return record }

        let filteredItems = session.mediaItems.filter { !assignedPaths.contains($0.relativePath) }
        guard filteredItems.count != session.mediaItems.count else { return record }

        let regrouped = groupingService.group(items: filteredItems, settings: settings)
        session.mediaItems = regrouped.items
        session.lastUpdatedAt = Date()
        return (session, regrouped.burstGroups, regrouped.timeClusters)
    }

    private func rebuildInboxSession(
        from scanned: SessionOpenResult,
        workspaceSourceFolder: URL,
        existingInbox: ImportSession?
    ) -> ImportSession {
        let existing = existingInbox
        return ImportSession(
            id: existing?.id ?? scanned.session.id,
            sourceFolder: scanned.session.sourceFolder,
            workspaceSourceFolder: workspaceSourceFolder,
            startedAt: existing?.startedAt ?? scanned.session.startedAt,
            lastUpdatedAt: Date(),
            walkMetadata: existing?.walkMetadata ?? scanned.session.walkMetadata,
            archiveRoot: scanned.session.archiveRoot,
            sessionKind: .inbox,
            status: "draft",
            mediaItems: scanned.session.mediaItems
        )
    }

    private func scanSourceFolder(for folder: URL, settings: AppSettings) async throws -> SessionOpenResult {
        if let testingSourceScanHandler {
            return try await testingSourceScanHandler(folder, settings)
        }
        return try await Task.detached(priority: .userInitiated) {
            let sessionManager = SessionManager(scanner: FileScanner(), groupingService: GroupingService())
            return try sessionManager.openSession(for: folder, settings: settings)
        }.value
    }

    private func save(_ session: ImportSession) {
        var mutableSession = session
        mutableSession.lastUpdatedAt = Date()
        setCurrentSession(mutableSession, updateKind: .sessionOnly)
        persistCurrentSession()
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
            if let item = sessionMediaByID[itemID] {
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
            sourceWorkspaceState: sourceWorkspaceState
        )
        cachedBrowserNodeMap = browserViewModel.nodeMap(for: cachedBrowserRoots)
        sessionVisibleMediaCacheByNodeID.removeAll()
        invalidateReviewContentCaches()
        invalidateInlineSectionCaches()
    }

    private func refreshAllUIState() {
        refreshSidebarState()
        refreshReviewState()
        refreshNavigationState()
        refreshInspectorState()
        refreshCompareState()
        refreshPresentationState()
    }

    private func refreshSidebarState() {
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

        let snapshot = SidebarSnapshot(
            isVisible: isSidebarVisible,
            sourceWorkspaceState: sourceWorkspaceState,
            sessionSummary: summary,
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
            hiddenPhotoLogSummary: photoLogHiddenSummary(),
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
        let destinationPath = totalFiles > 0 ? ArchivePlanner(fileManager: fileManager).plan(for: session).archiveFolder.path : nil
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

    private func refreshReviewState() {
        let snapshots = visibleMediaItems.map(makeReviewItemSnapshot)
        let itemSnapshotsByID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })

        let snapshot = ReviewSnapshot(
            breadcrumbTitles: breadcrumbTitles,
            contextMediaItemCount: contextMediaItems.count,
            detailFolderNodes: detailFolderNodes,
            visibleItems: snapshots,
            itemSnapshotsByID: itemSnapshotsByID,
            organizedInlineSections: organizedInlineSections,
            groupedReviewSections: groupedReviewSections,
            canUseGroupedReviewMode: canUseGroupedReviewMode,
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
            canExpandAllGroupedSections: canExpandAllGroupedSections,
            canCollapseAllGroupedSections: canCollapseAllGroupedSections,
            canOpenComparison: canOpenComparison,
            canMarkSelectionForImport: canMarkSelectionForImport,
            canMarkSelectionAsCandidate: canMarkSelectionAsCandidate,
            canExcludeSelectionFromImport: canExcludeSelectionFromImport,
            canUnmarkSelectionForImport: canUnmarkSelectionForImport,
            canToggleRawForSelection: canToggleRawForSelection
        )
        reviewState.update(snapshot)
    }

    private func refreshNavigationState() {
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

    private func refreshInspectorState() {
        guard isDetailsInspectorVisible else {
            inspectorState.update(
                InspectorSnapshot(
                    isVisible: false,
                    browserNode: nil,
                    fallbackFolderPath: nil,
                    walkTitle: nil,
                    walkLocation: nil,
                    mediaItem: nil
                )
            )
            return
        }

        let snapshot = InspectorSnapshot(
            isVisible: isDetailsInspectorVisible,
            browserNode: inspectorBrowserNode,
            fallbackFolderPath: currentSession?.sourceFolder.path,
            walkTitle: currentSession?.walkMetadata.title.nonEmpty,
            walkLocation: currentSession?.walkMetadata.location.nonEmpty,
            mediaItem: inspectorMediaItem
        )
        inspectorState.update(snapshot)
    }

    private func refreshCompareState() {
        let snapshots = comparingMediaItems.map(makeReviewItemSnapshot)
        let snapshot = CompareSnapshot(
            title: compareSheetTitle,
            itemIDs: comparingMediaItemIDs,
            items: snapshots,
            gridColumnCount: compareGridColumnCount
        )
        compareState.update(snapshot)
    }

    private func refreshPresentationState() {
        let snapshot = PresentationSnapshot(
            showKeyboardHelp: showKeyboardHelp,
            startupAlert: startupAlert,
            previewingMediaItem: previewingMediaItem,
            activePhotoLogEditor: activePhotoLogEditor,
            revealedPhotoLog: revealedPhotoLog
        )
        presentationState.update(snapshot)
    }

    private func makeReviewItemSnapshot(_ item: MediaItem) -> ReviewItemSnapshot {
        ReviewItemSnapshot(
            item: item,
            archivePreview: archivePreview(for: item),
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

    private func focusSidebarFirstResponder() {
        guard let window = NSApp.keyWindow else { return }
        guard let contentView = window.contentViewController?.view
            ?? (window.value(forKey: "contentView") as? NSView) else { return }

        if let outlineView = firstSubview(in: contentView, matching: { $0 is NSOutlineView }) as? NSOutlineView {
            window.makeFirstResponder(outlineView)
            return
        }

        if let tableView = firstSubview(in: contentView, matching: { $0 is NSTableView }) as? NSTableView {
            window.makeFirstResponder(tableView)
        }
    }

    private func firstSubview(in root: NSView, matching predicate: (NSView) -> Bool) -> NSView? {
        if predicate(root) {
            return root
        }

        for subview in root.subviews {
            if let match = firstSubview(in: subview, matching: predicate) {
                return match
            }
        }

        return nil
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
        inlineSectionOrganizer.inlineDaySections(from: selectedBrowserNode, visibleItems: contextMediaItems)
    }

    private func filterReviewItems(_ items: [MediaItem]) -> [MediaItem] {
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
        }
    }

    private func baseVisibleMediaItems(for node: BrowserNode) -> [MediaItem] {
        if let cachedArchiveItems = archiveMediaCache[node.id] {
            return cachedArchiveItems
        }

        if let cachedSessionItems = sessionVisibleMediaCacheByNodeID[node.id] {
            return cachedSessionItems
        }

        let items = node.mediaItemIDs.compactMap { sessionMediaByID[$0] }.sorted(by: Self.mediaSort)
        sessionVisibleMediaCacheByNodeID[node.id] = items
        return items
    }

    private func thumbnailPrefetchCandidates(from items: [MediaItem], excluding visibleIDs: Set<UUID>) -> [MediaItem] {
        guard !items.isEmpty else { return [] }
        let limit = max(96, visibleIDs.count * 4)
        return Array(items.lazy.filter { !visibleIDs.contains($0.id) }.prefix(limit))
    }

    private func configurePersistence() {
        let configuration = sessionLifecycleCoordinator.configurePersistence(settings: settings)
        sessionStore = configuration.sessionStore
        previewStore = configuration.previewStore
        sessionManager = configuration.sessionManager
        importWorkflow = configuration.importWorkflow
        browserViewModel = configuration.browserViewModel
        startupAlert = configuration.startupAlert
        importProgress = importWorkflow.importProgress
        refreshAllUIState()
    }

    private func loadArchiveMediaIfNeeded(for nodeID: String?) {
        do {
            guard let loadResult = try browserViewModel.loadArchiveMediaIfNeeded(
                for: nodeID,
                browserNodeMap: browserNodeMap,
                archiveMediaCache: archiveMediaCache,
                settings: settings
            ) else { return }
        let sortedItems = loadResult.items.sorted(by: Self.mediaSort)
        archiveMediaCache[loadResult.nodeID] = sortedItems
        requestVisibleThumbnails(prefetching: sortedItems)
        statusMessage = loadResult.statusMessage
        } catch {
            statusMessage = "Failed to load archive folder: \(error.localizedDescription)"
        }
    }

    private static func mediaSort(lhs: MediaItem, rhs: MediaItem) -> Bool {
        let lhsDate = lhs.capturedAt ?? .distantPast
        let rhsDate = rhs.capturedAt ?? .distantPast
        if lhsDate == rhsDate {
            return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }
        return lhsDate < rhsDate
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
            thumbnailImageCache.setObject(image, forKey: imageURL as NSURL)
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
