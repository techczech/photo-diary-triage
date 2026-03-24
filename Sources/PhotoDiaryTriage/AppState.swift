import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var currentSession: ImportSession?
    @Published var burstGroups: [BurstGroup] = []
    @Published var timeClusters: [TimeCluster] = []
    @Published var selectedSidebarNodeID: String?
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
    @Published var dayOrganizationMode: DayOrganizationMode = .days
    @Published var expandedInlineSectionIDs: Set<String> = []
    @Published var pendingInlineScrollTargetID: UUID?
    @Published var previewingMediaItemID: UUID?
    @Published var comparingMediaItemIDs: [UUID] = []
    @Published var statusMessage: String = "Choose a source folder on the SSD to begin."
    @Published var thumbnailFailures: Set<UUID> = []
    @Published var archiveMediaCache: [String: [MediaItem]] = [:]
    @Published var startupAlert: AppStartupAlert?
    @Published var importProgress: ImportProgress?

    private let scanner: FileScanner
    private let groupingService: GroupingService
    private let importCoordinator: ImportCoordinator
    private let sessionLifecycleCoordinator: SessionLifecycleCoordinator
    private var sessionStore: SessionPersisting
    private var previewStore: PreviewCaching
    private let settingsStore: SettingsPersisting
    private var sessionManager: SessionManager
    private var importWorkflow: ImportWorkflow
    private var browserViewModel: BrowserViewModel
    private let selectionManager = SelectionManager()
    private let backupStore = BackupStore()
    private let fileManager: FileManager
    private let supportRoot: URL
    private let logger = AppLogger.appState
    private var volumeMountObserver: NSObjectProtocol?
    private var hasAttemptedInitialAutoLoad = false

    init() {
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
        self.sessionStore = InMemorySessionStore()
        self.previewStore = NoCachePreviewStore(cacheRoot: settings.cacheRoot)
        self.sessionManager = SessionManager(scanner: self.scanner, groupingService: self.groupingService)
        self.importWorkflow = ImportWorkflow(coordinator: self.importCoordinator)
        self.browserViewModel = BrowserViewModel(scanner: self.scanner)
        self.archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: settings.archiveRoot)

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
        browserViewModel.browserRoots(
            currentSession: currentSession,
            bursts: burstGroups,
            clusters: timeClusters,
            archiveRoot: settings.archiveRoot
        )
    }

    var browserNodeMap: [String: BrowserNode] {
        browserViewModel.nodeMap(for: browserRoots)
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

    var visibleMediaItems: [MediaItem] {
        guard let node = selectedBrowserNode else { return [] }
        if let cached = archiveMediaCache[node.id] {
            return cached.sorted(by: Self.mediaSort)
        }
        guard node.children == nil || node.children?.isEmpty == true else { return [] }
        let mediaIDs = Set(node.mediaItemIDs)
        return (currentSession?.mediaItems ?? [])
            .filter { mediaIDs.contains($0.id) }
            .sorted(by: Self.mediaSort)
    }

    var inlineDaySections: [InlineDaySection] {
        inlineSectionOrganizer.inlineDaySections(from: selectedBrowserNode)
    }

    var shouldShowInlineDaySections: Bool {
        !inlineDaySections.isEmpty
    }

    var organizedInlineSections: [InlineSection] {
        inlineSectionOrganizer.organizedInlineSections(from: inlineDaySections, mode: dayOrganizationMode)
    }

    func mediaItems(for ids: [UUID]) -> [MediaItem] {
        let idSet = Set(ids)
        if let node = selectedBrowserNode, let cached = archiveMediaCache[node.id] {
            return cached.filter { idSet.contains($0.id) }.sorted(by: Self.mediaSort)
        }
        return (currentSession?.mediaItems ?? []).filter { idSet.contains($0.id) }.sorted(by: Self.mediaSort)
    }

    var reviewPresentationMode: ReviewPresentationMode {
        settings.reviewPresentationMode
    }

    var canOpenCurrentSelection: Bool {
        if activePane == .folders { return selectedFolderNodeIDs.count == 1 }
        if activePane == .sidebar { return selectedBrowserNode?.isContainer == true }
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

    var canUnmarkSelectionForImport: Bool {
        canMutateImportSelection && !currentSelectionMediaIDs().isEmpty
    }

    var canToggleRawForSelection: Bool {
        canMutateImportSelection && selectedMediaItems.contains { !$0.companionFiles.isEmpty }
    }

    var selectedMediaItems: [MediaItem] {
        guard let session = currentSession else { return [] }
        return session.mediaItems.filter { selectedMediaItemIDs.contains($0.id) }
    }

    var focusedReviewItem: MediaItem? {
        guard let focusedReviewItemID else { return visibleMediaItems.first }
        return visibleMediaItems.first(where: { $0.id == focusedReviewItemID }) ?? visibleMediaItems.first
    }

    var inspectorMediaItem: MediaItem? {
        if let focusedReviewItem {
            return focusedReviewItem
        }
        return selectedMediaItems.first
    }

    var previewingMediaItem: MediaItem? {
        guard let previewingMediaItemID else { return nil }
        return currentSession?.mediaItems.first(where: { $0.id == previewingMediaItemID })
    }

    var comparingMediaItems: [MediaItem] {
        guard let session = currentSession else { return [] }
        let selectedIDs = Set(comparingMediaItemIDs)
        let orderedVisible = visibleMediaItems.filter { selectedIDs.contains($0.id) }
        if orderedVisible.count == comparingMediaItemIDs.count {
            return orderedVisible
        }
        return session.mediaItems.filter { selectedIDs.contains($0.id) }.sorted(by: Self.mediaSort)
    }

    var canOpenSettings: Bool { true }

    var canOpenComparison: Bool {
        currentSelectionMediaIDs().count >= 2
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

            requestThumbnails(for: opened.session.mediaItems)
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
        guard var session = currentSession else { return }
        session.walkMetadata.title = title
        session.walkMetadata.location = location
        session.walkMetadata.notes = notes
        save(session)
    }

    func updateWalkDetailsExpansion(for session: ImportSession?) {
        guard let session else {
            isWalkDetailsExpanded = true
            return
        }

        let metadata = session.walkMetadata
        let hasMetadata = metadata.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || metadata.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || metadata.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        isWalkDetailsExpanded = !hasMetadata
    }

    func setImportRawCompanions(for item: MediaItem, enabled: Bool) {
        guard var session = currentSession, let index = session.mediaItems.firstIndex(where: { $0.id == item.id }) else { return }
        session.mediaItems[index].importRawCompanions = enabled
        save(session)
    }

    func markBackupConfirmed() {
        guard var session = currentSession else { return }
        session.walkMetadata.backupConfirmedAt = Date()
        for index in session.mediaItems.indices where session.mediaItems[index].lifecycleState == .verified {
            do {
                session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: .sourceCleanupPending)
            } catch {
                logger.error("Failed to mark cleanup pending for \(session.mediaItems[index].sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        save(session)
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
        guard let session = currentSession else { return "" }
        let matchingEntries = ArchivePlanner().plan(for: session).entries.filter { $0.mediaItemID == item.id }
        return matchingEntries.map(\.destinationURL.path).joined(separator: "\n")
    }

    func thumbnailURL(for item: MediaItem) -> URL {
        previewStore.cachedThumbnailURL(for: item)
    }

    func requestThumbnail(for item: MediaItem) {
        Task {
            let success = await previewStore.generateThumbnail(for: item)
            await MainActor.run {
                if success {
                    thumbnailFailures.remove(item.id)
                } else {
                    thumbnailFailures.insert(item.id)
                    if previewStore.isPersistentCacheAvailable == false {
                        statusMessage = "Preview cache unavailable; thumbnails are temporarily disabled."
                    }
                }
            }
        }
    }

    func setArchiveRoot(_ archiveRoot: URL) {
        settings.archiveRoot = archiveRoot
        archiveYearFolders = ArchiveLibraryInspector.existingYearFolders(in: archiveRoot)
        archiveMediaCache.removeAll()

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
        persistSettings()
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
    }

    func toggleDetailsInspector() {
        isDetailsInspectorVisible.toggle()
    }

    func selectSidebarNode(_ nodeID: String?) {
        selectedSidebarNodeID = nodeID
        activePane = .sidebar
        clearDetailSelections()
        loadArchiveMediaIfNeeded(for: nodeID)
        resetInlineExpansionState()
    }

    func toggleInlineSectionExpansion(_ sectionID: String) {
        if expandedInlineSectionIDs.contains(sectionID) {
            expandedInlineSectionIDs.remove(sectionID)
        } else {
            expandedInlineSectionIDs.insert(sectionID)
        }
    }

    func isInlineSectionExpanded(_ sectionID: String) -> Bool {
        expandedInlineSectionIDs.contains(sectionID)
    }

    func expandAllInlineSections() {
        expandedInlineSectionIDs = Set(inlineSectionOrganizer.flattenSectionIDs(from: organizedInlineSections))
    }

    func collapseAllInlineSections() {
        expandedInlineSectionIDs.removeAll()
    }

    func revealInlineMediaItem(_ itemID: UUID, sectionPath: [String]) {
        expandedInlineSectionIDs.formUnion(sectionPath)
        selectInlineMediaItem(itemID)
        focusedReviewItemID = itemID
        activePane = .media
        DispatchQueue.main.async { [weak self] in
            self?.pendingInlineScrollTargetID = itemID
        }
    }

    func selectInlineMediaItem(_ itemID: UUID) {
        previewingMediaItemID = nil
        selectMediaItems([itemID])
        focusedReviewItemID = itemID
        activePane = .media
        reviewGridHasFocus = true
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
        selectionManager.activateReviewGridFocus(visibleItems: visibleMediaItems, state: &state)
        applyReviewSelectionState(state)
    }

    func deactivateReviewGridFocus() {
        reviewGridHasFocus = false
    }

    func handleGridSelection(for itemID: UUID, modifiers: NSEvent.ModifierFlags) {
        guard let _ = currentSession else { return }
        var state = reviewSelectionState()
        selectionManager.handleGridSelection(
            for: itemID,
            visibleItems: visibleMediaItems,
            isShiftPressed: modifiers.contains(.shift),
            isCommandPressed: modifiers.contains(.command),
            state: &state
        )
        applyReviewSelectionState(state)
    }

    func moveGridSelection(by offset: Int, extending: Bool) {
        var state = reviewSelectionState()
        selectionManager.moveSelection(by: offset, visibleItems: visibleMediaItems, extending: extending, state: &state)
        applyReviewSelectionState(state)
    }

    func performReviewShortcut(_ key: String) {
        guard reviewGridHasFocus else { return }
        let uppercased = key.uppercased()

        switch uppercased {
        case "I":
            markCurrentSelectionForImport()
        case "D":
            unmarkCurrentSelectionForImport()
        case "R":
            toggleRawForCurrentMediaSelection()
        case "A":
            selectAllVisibleMedia()
        case "S":
            selectFocusedReviewItemOnly()
        case "C":
            openComparisonForCurrentSelection()
        default:
            break
        }
    }

    func selectAllVisibleMedia() {
        var state = reviewSelectionState()
        selectionManager.selectAllVisibleMedia(visibleMediaItems, state: &state)
        applyReviewSelectionState(state)
    }

    func deselectAllVisibleMedia() {
        var state = reviewSelectionState()
        selectionManager.deselectAllVisibleMedia(visibleMediaItems, state: &state)
        applyReviewSelectionState(state)
    }

    func toggleFocusedReviewItemSelection() {
        var state = reviewSelectionState()
        selectionManager.toggleFocusedReviewItemSelection(visibleMediaItems, state: &state)
        applyReviewSelectionState(state)
    }

    func selectFocusedReviewItemOnly() {
        var state = reviewSelectionState()
        selectionManager.selectFocusedReviewItemOnly(visibleMediaItems, state: &state)
        applyReviewSelectionState(state)
    }

    func openFocusedReviewItem() {
        guard let focusedID = focusedReviewItemID ?? selectedMediaItemIDs.first else { return }
        previewingMediaItemID = focusedID
    }

    func openComparisonForCurrentSelection() {
        let ids = visibleMediaItems
            .map(\.id)
            .filter { currentSelectionMediaIDs().contains($0) }
        guard ids.count >= 2 else { return }
        comparingMediaItemIDs = ids
        statusMessage = "Opened compare view for \(ids.count) selected item(s)."
    }

    func openCurrentSelection() {
        switch activePane {
        case .folders:
            guard selectedFolderNodeIDs.count == 1, let nodeID = selectedFolderNodeIDs.first else { return }
            selectSidebarNode(nodeID)
        case .sidebar:
            break
        case .media:
            break
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
        updateImportState(for: currentSelectionMediaIDs(), selected: true)
        statusMessage = "Marked \(currentSelectionMediaIDs().count) item(s) for import."
    }

    func unmarkCurrentSelectionForImport() {
        guard canMutateImportSelection else { return }
        updateImportState(for: currentSelectionMediaIDs(), selected: false)
        statusMessage = "Removed \(currentSelectionMediaIDs().count) item(s) from import."
    }

    func toggleRawForCurrentMediaSelection() {
        guard canMutateImportSelection else { return }
        guard var session = currentSession else { return }
        let selectedIDs = selectedMediaItemIDs

        for index in session.mediaItems.indices where selectedIDs.contains(session.mediaItems[index].id) && !session.mediaItems[index].companionFiles.isEmpty {
            session.mediaItems[index].importRawCompanions.toggle()
        }

        save(session)
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

    private func updateImportState(for mediaIDs: Set<UUID>, selected: Bool) {
        guard var session = currentSession else { return }

        for index in session.mediaItems.indices where mediaIDs.contains(session.mediaItems[index].id) {
            do {
                let targetState: LifecycleState = selected ? .selectedForImport : .discovered
                session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: targetState)
            } catch {
                logger.error("Failed to update import selection for \(session.mediaItems[index].sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }
            session.mediaItems[index].selectionState = selected ? .selected : .skipped
            if !selected {
                session.mediaItems[index].importRawCompanions = false
            }
        }

        save(session)
    }

    private func currentSelectionMediaIDs() -> Set<UUID> {
        switch activePane {
        case .media:
            return selectedMediaItemIDs
        case .folders:
            let ids = selectedFolderNodeIDs.compactMap { browserNodeMap[$0]?.mediaItemIDs }
            return Set(ids.flatMap { $0 })
        case .sidebar:
            return Set(selectedBrowserNode?.mediaItemIDs ?? [])
        }
    }

    private func clearDetailSelections() {
        selectedFolderNodeIDs.removeAll()
        selectedMediaItemIDs.removeAll()
        focusedReviewItemID = nil
        reviewSelectionAnchorID = nil
        reviewGridHasFocus = false
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
        selectedMediaItemIDs = state.selectedMediaItemIDs
        focusedReviewItemID = state.focusedReviewItemID
        reviewSelectionAnchorID = state.reviewSelectionAnchorID
        activePane = state.activePane
        reviewGridHasFocus = state.reviewGridHasFocus
    }

    private func resetInlineExpansionState() {
        expandedInlineSectionIDs.removeAll()

        let sections = organizedInlineSections
        if sections.count == 1, let only = sections.first {
            expandedInlineSectionIDs.insert(only.id)
        }
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
        for item in items {
            requestThumbnail(for: item)
        }
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
            archiveMediaCache[loadResult.nodeID] = loadResult.items
            requestThumbnails(for: loadResult.items)
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
