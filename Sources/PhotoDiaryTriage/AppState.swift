import AppKit
import Foundation

enum ReviewKeyboardTarget {
    case items
    case sections
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var currentSession: ImportSession? {
        didSet {
            rebuildDerivedStateCaches()
        }
    }
    @Published var burstGroups: [BurstGroup] = [] {
        didSet {
            rebuildBrowserCaches()
        }
    }
    @Published var timeClusters: [TimeCluster] = [] {
        didSet {
            rebuildBrowserCaches()
        }
    }
    @Published var selectedSidebarNodeID: String? {
        didSet {
            invalidateInlineSectionCaches()
        }
    }
    @Published var selectedFolderNodeIDs: Set<String> = []
    @Published var selectedMediaItemIDs: Set<UUID> = []
    @Published var focusedReviewItemID: UUID?
    @Published var reviewSelectionAnchorID: UUID?
    @Published var activePane: ActivePane = .sidebar
    @Published var archiveYearFolders: [String] = []
    @Published var showKeyboardHelp = false
    @Published var reviewGridHasFocus = false
    @Published var isDetailsInspectorVisible = true
    @Published var isWalkDetailsExpanded = true
    @Published var reviewFilter: ReviewFilter = .all {
        didSet {
            guard reviewFilter != oldValue else { return }
            invalidateInlineSectionCaches()
            if dayDetailDisplayMode == .sections {
                ensureFocusedInlineSection()
            }
            reconcileReviewSelectionWithVisibleItems()
        }
    }
    @Published var dayOrganizationMode: DayOrganizationMode = .days {
        didSet {
            invalidateOrganizedInlineSectionCache()
        }
    }
    @Published var dayDetailDisplayMode: DayDetailDisplayMode = .review
    @Published var expandedInlineSectionIDs: Set<String> = []
    @Published var pendingInlineScrollTargetID: UUID?
    @Published var pendingReviewScrollTargetID: UUID?
    @Published var focusedInlineSectionID: String?
    @Published var pendingInlineSectionScrollTargetID: String?
    @Published var pendingInlineSectionScrollRevision: Int = 0
    @Published var drilledInlineSectionID: String?
    @Published var drilledInlineSectionMediaItemIDs: [UUID] = []
    @Published var previewingMediaItemID: UUID?
    @Published var comparingMediaItemIDs: [UUID] = []
    @Published var compareSheetTitle: String = "Compare Selection"
    @Published var compareGridColumnCount: Int = CompareGridMetrics.defaultColumnCount(for: 0)
    @Published var reviewGridColumnCount: Int = 1
    @Published var statusMessage: String = "Choose a source folder on the SSD to begin."
    @Published var thumbnailFailures: Set<UUID> = []
    @Published var archiveMediaCache: [String: [MediaItem]] = [:] {
        didSet {
            invalidateInlineSectionCaches()
        }
    }
    @Published var startupAlert: AppStartupAlert?
    @Published var importProgress: ImportProgress?

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
    private let archivePlanner = ArchivePlanner()
    private let fileManager: FileManager
    private let supportRoot: URL
    private let logger = AppLogger.appState
    private let thumbnailScheduler = ThumbnailScheduler()
    private let thumbnailImageCache = NSCache<NSURL, NSImage>()
    private var cachedBrowserRoots: [BrowserNode] = []
    private var cachedBrowserNodeMap: [String: BrowserNode] = [:]
    private var sessionMediaByID: [UUID: MediaItem] = [:]
    private var sessionVisibleMediaCacheByNodeID: [String: [MediaItem]] = [:]
    private var archivePreviewByMediaItemID: [UUID: String] = [:]
    private var missingThumbnailPaths: Set<String> = []
    private var thumbnailTasks: [UUID: Task<Void, Never>] = [:]
    private var volumeMountObserver: NSObjectProtocol?
    private var hasAttemptedInitialAutoLoad = false
    private var lastMeasuredReviewPaneWidth: Double = 0
    private var reviewKeyboardTarget: ReviewKeyboardTarget = .items
    private var inlineSectionCacheGeneration: Int = 0
    private var cachedInlineDaySectionsGeneration: Int = -1
    private var cachedInlineDaySectionsNodeID: String?
    private var cachedInlineDaySections: [InlineDaySection] = []
    private var cachedOrganizedInlineSectionsGeneration: Int = -1
    private var cachedOrganizedInlineSectionsMode: DayOrganizationMode = .days
    private var cachedOrganizedInlineSections: [InlineSection] = []

    init(testing: Bool = false) {
        self.fileManager = .default
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

        if testing {
            return
        }

        configurePersistence()
        loadMostRecentSession()
        startVolumeMonitoring()
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
            try sessionLifecycleCoordinator.resetSupportData()
            settings = settingsStore.load(defaults: AppSettings.default())
            configurePersistence()
            archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)
            archiveMediaCache.removeAll()
            loadMostRecentSession()
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
        if !drilledInlineSectionMediaItemIDs.isEmpty {
            return orderedMediaItems(for: drilledInlineSectionMediaItemIDs)
        }
        guard let node = selectedBrowserNode else { return [] }
        return baseVisibleMediaItems(for: node)
    }

    var visibleMediaItems: [MediaItem] {
        filterReviewItems(contextMediaItems)
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
        guard shouldShowInlineDaySections, dayDetailDisplayMode == .sections else {
            return visibleMediaItems
        }

        var seen: Set<UUID> = []
        let orderedIDs = inlineSectionOrganizer
            .visibleMediaItemIDs(from: organizedInlineSections, expandedSectionIDs: expandedInlineSectionIDs)
            .filter { seen.insert($0).inserted }
        return orderedMediaItems(for: orderedIDs)
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

    var reviewGridCardWidth: Double {
        settings.reviewGridCardWidth
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

    var canUnmarkSelectionForImport: Bool {
        canMutateImportSelection && !currentSelectionMediaIDs().isEmpty
    }

    var canToggleRawForSelection: Bool {
        canMutateImportSelection && selectedMediaItems.contains { !$0.companionFiles.isEmpty }
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
        currentSession?.mediaItems.contains { $0.selectionState.isIncluded } ?? false
    }

    var canConfirmBackup: Bool {
        currentSession?.walkMetadata.backupConfirmedAt == nil
    }

    var canCleanupImportedSources: Bool {
        currentSession?.mediaItems.contains { $0.lifecycleState == .sourceCleanupPending } ?? false
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
        !isBrowsingArchive
    }

    func pickSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.defaultSourceRoot

        if panel.runModal() == .OK, let folder = panel.urls.first {
            Task {
                await openSession(for: folder)
            }
        }
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
        do {
            statusMessage = "Scanning source folder..."
            let opened = try sessionLifecycleCoordinator.openSession(
                for: folder,
                settings: settings,
                using: sessionManager,
                store: sessionStore
            )
            currentSession = opened.session
            burstGroups = opened.bursts
            timeClusters = opened.clusters
            selectedSidebarNodeID = browserViewModel.preferredInitialSidebarNodeID(for: opened.session, bursts: opened.bursts, clusters: opened.clusters)
            clearDetailSelections()
            archiveMediaCache.removeAll()
            resetInlineExpansionState()

            statusMessage = "Loaded \(opened.session.mediaItems.count) visible items from \(folder.lastPathComponent)."

            requestVisibleThumbnails(prefetching: opened.session.mediaItems)
        } catch {
            logger.error("Failed to open session for \(folder.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            statusMessage = error.localizedDescription
        }
    }

    func performInitialAutoLoadIfNeeded() {
        guard hasAttemptedInitialAutoLoad == false else { return }
        hasAttemptedInitialAutoLoad = true

        Task {
            await attemptAutoLoadFromDefaultSource(reason: .launch)
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

        Task {
            do {
                statusMessage = "Copying marked files into archive..."
                let result = try await importWorkflow.commit(session: session) { [weak self] progress in
                    guard let self else { return }
                    self.importProgress = progress
                    if let progress {
                        self.statusMessage = "Importing \(progress.current)/\(progress.total)..."
                    }
                }
                currentSession = result.session
                persistCurrentSession()
                importProgress = nil
                statusMessage = "Imported \(result.fileManifests.count) marked items and wrote manifests."
            } catch {
                importProgress = nil
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
                currentSession = cleaned
                persistCurrentSession()
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

    func thumbnailImage(for item: MediaItem) -> NSImage? {
        let imageURL = thumbnailURL(for: item)
        let url = imageURL as NSURL
        if let image = thumbnailImageCache.object(forKey: url) {
            return image
        }

        if missingThumbnailPaths.contains(imageURL.path) {
            return nil
        }

        guard fileManager.fileExists(atPath: imageURL.path),
              let image = NSImage(contentsOf: imageURL) else {
            missingThumbnailPaths.insert(imageURL.path)
            return nil
        }

        missingThumbnailPaths.remove(imageURL.path)
        thumbnailImageCache.setObject(image, forKey: url)
        return image
    }

    func requestThumbnail(for item: MediaItem) {
        let imageURL = thumbnailURL(for: item)
        if thumbnailImageCache.object(forKey: imageURL as NSURL) != nil || fileManager.fileExists(atPath: imageURL.path) {
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
        statusMessage = "Default SSD root set to \(sourceRoot.path)."
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

    func setReviewGridCardWidth(_ width: Double) {
        let clamped = min(max(width, ReviewGridMetrics.minCardWidth), ReviewGridMetrics.maxCardWidth)
        guard settings.reviewGridCardWidth != clamped else { return }
        settings.reviewGridCardWidth = clamped
        updateReviewGridMetrics(availableWidth: nil)
        persistSettings()
    }

    func increaseReviewGridCardWidth() {
        setReviewGridCardWidth(settings.reviewGridCardWidth + ReviewGridMetrics.cardWidthStep)
    }

    func decreaseReviewGridCardWidth() {
        setReviewGridCardWidth(settings.reviewGridCardWidth - ReviewGridMetrics.cardWidthStep)
    }

    func resetReviewGridCardWidth() {
        setReviewGridCardWidth(ReviewGridMetrics.defaultCardWidth)
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
        if mode == .sections, !canUseGroupedReviewMode {
            dayDetailDisplayMode = .review
            statusMessage = "Grouped review is available when browsing a day or a folder with day sections."
            activateReviewGridFocus()
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
    }

    func updateReviewGridMetrics(availableWidth: CGFloat?) {
        if let availableWidth, availableWidth > 0 {
            lastMeasuredReviewPaneWidth = Double(availableWidth)
        }

        let width = max(lastMeasuredReviewPaneWidth, 0)
        let metrics = ReviewGridMetrics(availableWidth: width, cardWidth: reviewGridCardWidth)
        reviewGridColumnCount = reviewPresentationMode == .grid ? metrics.columnCount : 1
    }

    func toggleDetailsInspector() {
        isDetailsInspectorVisible.toggle()
    }

    func toggleSidebarVisibility() {
        let selector = #selector(NSSplitViewController.toggleSidebar(_:))
        if NSApp.sendAction(selector, to: nil, from: nil) {
            return
        }

        if let window = NSApp.keyWindow, let firstResponder = window.firstResponder {
            _ = firstResponder.tryToPerform(selector, with: nil)
        }
    }

    func focusSidebarNavigation() {
        activePane = .sidebar
        reviewGridHasFocus = false
        reviewKeyboardTarget = .items
        DispatchQueue.main.async {
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
            return
        }

        if dayDetailDisplayMode == .sections, reviewKeyboardTarget == .items {
            let sectionID = focusedInlineSectionID ?? focusedReviewItemID.flatMap { inlineSectionID(containing: $0, in: organizedInlineSections) }
            if let sectionID {
                focusInlineSection(sectionID)
                statusMessage = "Returned to grouped section selection."
                return
            }
        }

        deactivateReviewGridFocus()
    }

    func handleReviewArrowKey(dx: Int, dy: Int, extending: Bool) {
        guard reviewGridHasFocus else { return }

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
            return
        }

        let columns = max(1, reviewPresentationMode == .grid ? reviewGridColumnCount : 1)
        if dx != 0 {
            moveGridSelection(by: dx, extending: extending)
        } else if dy != 0 {
            moveGridSelection(by: dy * columns, extending: extending)
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
        case "X":
            excludeCurrentSelectionFromImport()
        case "D":
            unmarkCurrentSelectionForImport()
        case "R":
            toggleRawForCurrentMediaSelection()
        case "A":
            selectAllVisibleMedia()
        case "C":
            openComparisonForCurrentSelection()
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
        reviewGridHasFocus = false
        compareGridColumnCount = CompareGridMetrics.defaultColumnCount(for: deduplicatedIDs.count)
        compareSheetTitle = title
        comparingMediaItemIDs = deduplicatedIDs
        statusMessage = "Opened compare view for \(deduplicatedIDs.count) item(s)."
    }

    func closeComparison() {
        comparingMediaItemIDs.removeAll()
        compareGridColumnCount = CompareGridMetrics.defaultColumnCount(for: 0)
    }

    func removeItemFromComparison(_ itemID: UUID) {
        comparingMediaItemIDs.removeAll { $0 == itemID }
        if comparingMediaItemIDs.isEmpty {
            closeComparison()
            statusMessage = "Removed the last compare item and closed compare."
            return
        }

        if selectedMediaItemIDs.contains(itemID) {
            selectedMediaItemIDs.remove(itemID)
        }
        if focusedReviewItemID == itemID {
            focusedReviewItemID = comparingMediaItemIDs.first
        }
        compareGridColumnCount = min(compareGridColumnCount, max(comparingMediaItemIDs.count, 1))

        statusMessage = "Removed item from compare. \(comparingMediaItemIDs.count) item(s) remain."
    }

    func focusComparisonItem(_ itemID: UUID, extendingSelection: Bool = false) {
        let modifiers: NSEvent.ModifierFlags = extendingSelection ? [.shift] : []
        handleGridSelection(for: itemID, modifiers: modifiers)
    }

    func toggleSelectionForComparisonItem(_ itemID: UUID) {
        handleGridSelection(for: itemID, modifiers: [.command])
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
            pendingReviewScrollTargetID = focusedReviewItemID
        }
    }

    private func resetInlineExpansionState() {
        expandedInlineSectionIDs = Set(inlineSectionOrganizer.flattenSectionIDs(from: organizedInlineSections))
        pendingInlineSectionScrollTargetID = nil

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
        currentSession = session

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

    private func loadMostRecentSession() {
        do {
            guard let latest = try sessionLifecycleCoordinator.loadMostRecentSession(
                from: sessionStore,
                using: sessionManager
            ) else { return }
            currentSession = latest.session
            burstGroups = latest.bursts
            timeClusters = latest.clusters
        } catch {
            logger.error("Failed to recover recent session: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Failed to recover the most recent session: \(error.localizedDescription)"
            return
        }

        selectedSidebarNodeID = currentSession == nil ? "section-current-session" : browserViewModel.preferredInitialSidebarNodeID(for: currentSession, bursts: burstGroups, clusters: timeClusters)
        clearDetailSelections()
        archiveMediaCache.removeAll()
        resetInlineExpansionState()
        statusMessage = "Recovered most recent session from local SQLite store."
    }

    private func persistCurrentSession() {
        guard let currentSession else { return }
        do {
            try sessionLifecycleCoordinator.persistCurrentSession(
                currentSession,
                bursts: burstGroups,
                clusters: timeClusters,
                using: sessionManager,
                to: sessionStore
            )
        } catch {
            logger.error("Failed to persist current session: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Session save failed: \(error.localizedDescription)"
        }
    }

    private func persistSettings() {
        do {
            try sessionLifecycleCoordinator.persistSettings(settings, to: settingsStore)
        } catch {
            logger.error("Failed to persist settings: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Settings save failed: \(error.localizedDescription)"
        }
    }

    private func save(_ session: ImportSession) {
        var mutableSession = session
        mutableSession.lastUpdatedAt = Date()
        currentSession = mutableSession
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
            }
        } else {
            thumbnailFailures.insert(itemID)
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

    private func rebuildDerivedStateCaches() {
        rebuildSessionCaches()
        rebuildBrowserCaches()
    }

    private func rebuildSessionCaches() {
        sessionVisibleMediaCacheByNodeID.removeAll()

        guard let currentSession else {
            sessionMediaByID = [:]
            archivePreviewByMediaItemID = [:]
            missingThumbnailPaths.removeAll()
            thumbnailImageCache.removeAllObjects()
            return
        }

        sessionMediaByID = Dictionary(uniqueKeysWithValues: currentSession.mediaItems.map { ($0.id, $0) })
        let plan = archivePlanner.plan(for: currentSession)
        var previews: [UUID: [String]] = [:]
        for entry in plan.entries {
            previews[entry.mediaItemID, default: []].append(entry.destinationURL.path)
        }
        archivePreviewByMediaItemID = previews.mapValues { $0.joined(separator: "\n") }
        missingThumbnailPaths.removeAll()
        thumbnailImageCache.removeAllObjects()
    }

    private func rebuildBrowserCaches() {
        cachedBrowserRoots = browserViewModel.browserRoots(
            currentSession: currentSession,
            bursts: burstGroups,
            clusters: timeClusters,
            archiveRoot: settings.archiveRoot
        )
        cachedBrowserNodeMap = browserViewModel.nodeMap(for: cachedBrowserRoots)
        sessionVisibleMediaCacheByNodeID.removeAll()
        invalidateInlineSectionCaches()
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
    }

    private func invalidateOrganizedInlineSectionCache() {
        cachedOrganizedInlineSectionsGeneration = -1
        cachedOrganizedInlineSectionsMode = dayOrganizationMode
        cachedOrganizedInlineSections = []
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
        pendingReviewScrollTargetID = targetID
    }

    private func focusSidebarFirstResponder() {
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else { return }

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

        await attemptAutoLoadFromDefaultSource(reason: .mounted)
    }

    private func attemptAutoLoadFromDefaultSource(reason: AutoLoadReason) async {
        switch sessionLifecycleCoordinator.autoLoadPlan(reason: reason, settings: settings, currentSession: currentSession) {
        case .waitForDefaultSource(let statusMessage):
            if let statusMessage {
                self.statusMessage = statusMessage
            }
        case .keepCurrentSession(let statusMessage, let refreshCurrentSelection):
            if refreshCurrentSelection {
                selectedSidebarNodeID = browserViewModel.preferredInitialSidebarNodeID(for: currentSession, bursts: burstGroups, clusters: timeClusters)
                clearDetailSelections()
                archiveMediaCache.removeAll()
                resetInlineExpansionState()
            }
            if let statusMessage {
                self.statusMessage = statusMessage
            }
        case .openSession(let folder, let statusMessage):
            await openSession(for: folder)
            if let statusMessage {
                self.statusMessage = statusMessage
            }
        }
    }
}
