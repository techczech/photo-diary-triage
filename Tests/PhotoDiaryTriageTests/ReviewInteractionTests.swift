import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func reviewGridMetricsUseRequestedColumnsForCardWidth() {
    let compact = ReviewGridMetrics(availableWidth: 540, requestedColumnCount: 2)
    let wide = ReviewGridMetrics(availableWidth: 1_100, requestedColumnCount: 4)
    let singleColumn = ReviewGridMetrics(availableWidth: 1_100, requestedColumnCount: 1)

    #expect(compact.columnCount == 2)
    #expect(wide.columnCount == 4)
    #expect(compact.cardWidth >= ReviewGridMetrics.minCardWidth)
    #expect(wide.cardWidth >= ReviewGridMetrics.minCardWidth)
    #expect(singleColumn.cardWidth > wide.cardWidth)
    #expect(singleColumn.cardWidth > ReviewGridMetrics.maxCardWidth)
}

@Test func compareGridDefaultColumnCountMatchesCompareExpectations() {
    #expect(CompareGridMetrics.defaultColumnCount(for: 2) == 2)
    #expect(CompareGridMetrics.defaultColumnCount(for: 3) == 3)
    #expect(CompareGridMetrics.defaultColumnCount(for: 4) == 4)
    #expect(CompareGridMetrics.defaultColumnCount(for: 8) == 4)
}

@Test func compareGridMetricsUseRequestedColumnsAndClampToItemCount() {
    let fourColumns = CompareGridMetrics(
        availableWidth: 1_600,
        requestedColumnCount: 4,
        itemCount: 8
    )
    let clampedColumns = CompareGridMetrics(
        availableWidth: 1_600,
        requestedColumnCount: 8,
        itemCount: 3
    )

    #expect(fourColumns.columnCount == 4)
    #expect(fourColumns.rowCount == 2)
    #expect(fourColumns.cardWidth > 300)
    #expect(clampedColumns.columnCount == 3)
    #expect(clampedColumns.rowCount == 1)
}

@Test func mediaItemDisplayAspectRatioUsesMetadataOrFallback() {
    let withMetadata = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/a.jpg"),
        relativePath: "a.jpg",
        fileName: "a.jpg",
        baseName: "a",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: 6_000, pixelHeight: 4_000, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "a"
    )
    let fallback = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/b.jpg"),
        relativePath: "b.jpg",
        fileName: "b.jpg",
        baseName: "b",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "b"
    )

    #expect(abs(withMetadata.displayAspectRatio - 1.5) < 0.0001)
    #expect(abs(fallback.displayAspectRatio - (4.0 / 3.0)) < 0.0001)
}

@Test func mediaItemCompactDisplayNameUsesTrailingDigitsWhenPresent() {
    let numbered = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/IMG_0042.JPG"),
        relativePath: "100CANON/IMG_0042.JPG",
        fileName: "IMG_0042.JPG",
        baseName: "IMG_0042",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "img42"
    )
    let fallback = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/BRIDGE.JPG"),
        relativePath: "BRIDGE.JPG",
        fileName: "BRIDGE.JPG",
        baseName: "BRIDGE",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "bridge"
    )

    #expect(numbered.compactDisplayName == "0042")
    #expect(fallback.compactDisplayName == "BRIDGE")
}

@Test func mediaItemCompactCapturedAtLabelUsesShortReviewTimestamp() {
    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 26
    components.hour = 8
    components.minute = 4
    components.timeZone = TimeZone(secondsFromGMT: 0)
    let date = Calendar(identifier: .gregorian).date(from: components)!

    let item = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/a.jpg"),
        relativePath: "a.jpg",
        fileName: "a.jpg",
        baseName: "a",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: date,
        metadata: MediaMetadata(capturedAt: date, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "a"
    )

    #expect(item.compactCapturedAtLabel == "26 Mar 08:04")
}

@Test func compareViewportRoundTripsNormalizedAndContentOrigins() {
    let contentSize = CGSize(width: 2_000, height: 1_500)
    let viewportSize = CGSize(width: 800, height: 600)
    let origin = CGPoint(x: 300, y: 225)

    let normalized = CompareViewport.normalizedOrigin(
        contentSize: contentSize,
        viewportSize: viewportSize,
        boundsOrigin: origin
    )
    let roundTrip = normalized.contentOrigin(contentSize: contentSize, viewportSize: viewportSize)

    #expect(abs(roundTrip.x - origin.x) < 0.001)
    #expect(abs(roundTrip.y - origin.y) < 0.001)
}

@Test func reviewGridClickContextTracksModifiersAndDoubleClick() {
    let shiftDoubleClick = ReviewGridClickContext(modifiers: [.shift], clickCount: 2)
    let commandClick = ReviewGridClickContext(modifiers: [.command], clickCount: 1)

    #expect(shiftDoubleClick.isShiftPressed)
    #expect(!shiftDoubleClick.isCommandPressed)
    #expect(shiftDoubleClick.isDoubleClick)

    #expect(!commandClick.isShiftPressed)
    #expect(commandClick.isCommandPressed)
    #expect(!commandClick.isDoubleClick)
}

@MainActor
@Test func doubleClickSelectionOpensPreviewForFocusedItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.handleGridSelection(
        for: items[1].id,
        click: ReviewGridClickContext(modifiers: [], clickCount: 2)
    )

    #expect(state.selectedMediaItemIDs == [items[1].id])
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.previewingMediaItemID == items[1].id)
}

@MainActor
@Test func selectShortcutMarksFocusedItemAndAdvancesToNextItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()

    state.performReviewShortcut("S")

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .included)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@MainActor
@Test func excludeShortcutMarksFocusedItemAndAdvancesToNextItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()

    state.performReviewShortcut("X")

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .excluded)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@MainActor
@Test func compareRequestDeduplicatesIDsAndStoresTitle() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[0].id, items[1].id, items[0].id], title: "Compare Burst")

    #expect(state.compareSheetTitle == "Compare Burst")
    #expect(state.comparingMediaItemIDs == [items[0].id, items[1].id])
    #expect(state.compareGridColumnCount == 2)
    #expect(state.selectedMediaItemIDs == [items[0].id])
    #expect(state.focusedReviewItemID == items[0].id)
}

@MainActor
@Test func removingCompareItemKeepsRemainingItemsOpen() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.setCompareGridColumnCount(3)
    state.removeItemFromComparison(items[1].id)

    #expect(state.comparingMediaItemIDs == [items[0].id, items[2].id])
    #expect(state.compareGridColumnCount == 2)

    state.removeItemFromComparison(items[0].id)
    #expect(state.comparingMediaItemIDs == [items[2].id])
    #expect(state.compareGridColumnCount == 1)

    state.removeItemFromComparison(items[2].id)
    #expect(state.comparingMediaItemIDs.isEmpty)
    #expect(state.compareGridColumnCount == 1)
}

@MainActor
@Test func compareArrowNavigationMovesFocusedItemWithinCompareSet() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.moveComparisonFocus(dx: 1, dy: 0)

    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])

    state.moveComparisonFocus(dx: 0, dy: 1)

    #expect(state.focusedReviewItemID == items[3].id)
    #expect(state.selectedMediaItemIDs == [items[3].id])
}

@MainActor
@Test func compareCloseRestoresPreviousReviewSelection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[2].id])

    state.openComparison(for: [items[0].id, items[1].id], title: "Compare Burst")
    state.closeComparison()

    #expect(state.selectedMediaItemIDs == [items[2].id])
    #expect(state.focusedReviewItemID == items[2].id)
    #expect(!state.reviewGridHasFocus)
}

@MainActor
@Test func reviewGridColumnPreferenceUsesLastMeasuredWidthForReflow() {
    let items = makeSelectionItems(count: 6)
    let state = makeReviewAppState(items: items)

    state.setReviewGridColumnCount(3)
    state.updateReviewGridMetrics(availableWidth: 1_100)
    #expect(state.reviewGridColumnCount == 3)

    state.setReviewGridColumnCount(4)
    #expect(state.reviewGridColumnCount == 4)

    state.resetReviewGridColumnCount()
    #expect(state.reviewGridColumnCount == ReviewGridMetrics.defaultRequestedColumnCount())
}

@MainActor
@Test func previewNavigationMovesThroughVisibleOrder() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.previewingMediaItemID = items[1].id
    state.focusedReviewItemID = items[1].id
    state.selectedMediaItemIDs = [items[1].id]

    state.navigatePreview(by: 1)

    #expect(state.previewingMediaItemID == items[2].id)
    #expect(state.focusedReviewItemID == items[2].id)
    #expect(state.selectedMediaItemIDs == [items[2].id])
}

@MainActor
@Test func dayContainerStillExposesMediaForReviewGrid() {
    let items = makeSelectionItems(count: 3)
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/review-container-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []

    let containerNode = state.browserNodeMap.values.first {
        !($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count
    }

    #expect(containerNode != nil)
    state.selectedSidebarNodeID = containerNode?.id
    #expect(state.visibleMediaItems.count == items.count)
}

@MainActor
@Test func groupedReviewInteractionItemsFollowExpandedSections() {
    let items = makeSelectionItems(count: 4)
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/grouped-review-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []

    let containerNode = state.browserNodeMap.values.first {
        !($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count
    }

    #expect(containerNode != nil)
    state.selectedSidebarNodeID = containerNode?.id
    state.setDayOrganizationMode(.daysAndBursts)
    state.setDayDetailDisplayMode(.sections)
    state.expandAllInlineSections()

    #expect(state.reviewInteractionItems.count == items.count)
    #expect(Set(state.reviewInteractionItems.map(\.id)) == Set(items.map(\.id)))
}

@MainActor
@Test func groupedReviewCanBeRequestedForDayContainerContexts() {
    let items = makeSelectionItems(count: 4)
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/grouped-review-shell", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []

    let containerNode = state.browserNodeMap.values.first(where: { node in
        state.selectedSidebarNodeID = node.id
        return state.canUseGroupedReviewMode
    })

    #expect(containerNode != nil)
    state.selectedSidebarNodeID = containerNode?.id
    #expect(state.canUseGroupedReviewMode)
    #expect(state.availableDayDetailDisplayModes == DayDetailDisplayMode.allCases)

    state.setDayDetailDisplayMode(.sections)

    #expect(state.dayDetailDisplayMode == .sections)
}

@MainActor
@Test func groupedReviewFallsBackCleanlyWhenCurrentNodeCannotBeGrouped() {
    let state = AppState(testing: true)

    #expect(!state.canUseGroupedReviewMode)
    #expect(state.availableDayDetailDisplayModes == [.review])

    state.setDayDetailDisplayMode(.sections)

    #expect(state.dayDetailDisplayMode == .review)
    #expect(state.statusMessage.contains("Grouped review is available"))
}

@MainActor
@Test func leafReviewContextNowExposesGroupedReviewFromVisibleItems() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.visibleMediaItems.count == items.count)
    #expect(state.canUseGroupedReviewMode)
    #expect(state.availableDayDetailDisplayModes == DayDetailDisplayMode.allCases)
    #expect(!state.inlineDaySections.isEmpty)

    state.setDayDetailDisplayMode(.sections)

    #expect(state.dayDetailDisplayMode == .sections)
}

@MainActor
@Test func openCurrentSelectionJumpsFromSidebarIntoReviewGrid() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.activePane == .sidebar)

    state.openCurrentSelection()

    #expect(state.activePane == .media)
    #expect(state.reviewGridHasFocus)
    #expect(state.focusedReviewItemID != nil)
    #expect(state.pendingReviewScrollTargetID == nil)
}

@MainActor
@Test func groupedSectionKeyboardNavigationTracksFocusedSection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(sections.count >= 2)
    #expect(state.focusedInlineSectionID == sections.first?.id)

    state.focusNextInlineSection()

    #expect(state.focusedInlineSectionID == sections[1].id)
    #expect(state.expandedInlineSectionIDs.contains(sections[1].id))

    state.collapseFocusedInlineSection()

    #expect(!state.expandedInlineSectionIDs.contains(sections[1].id))

    state.focusPreviousInlineSection()

    #expect(state.focusedInlineSectionID == sections[0].id)

    state.collapseFocusedInlineSection()
    #expect(!state.expandedInlineSectionIDs.contains(sections[0].id))

    state.expandFocusedInlineSection()
    #expect(state.expandedInlineSectionIDs.contains(sections[0].id))
}

@MainActor
@Test func plainArrowKeysOperateOnGroupedSectionsWhenSectionTargetIsActive() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(sections.count >= 2)
    state.focusInlineSection(sections[0].id)
    #expect(state.isGroupedSectionKeyboardTargetActive)

    state.handleReviewArrowKey(dx: 0, dy: 1, extending: false)

    #expect(state.focusedInlineSectionID == sections[1].id)

    state.handleReviewArrowKey(dx: -1, dy: 0, extending: false)
    #expect(!state.expandedInlineSectionIDs.contains(sections[1].id))

    state.handleReviewArrowKey(dx: 1, dy: 0, extending: false)
    #expect(state.expandedInlineSectionIDs.contains(sections[1].id))
}

@MainActor
@Test func plainArrowKeysStillMoveBetweenItemsWhenItemTargetIsActive() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    let firstFocusedID = state.focusedReviewItemID

    state.handleReviewArrowKey(dx: 1, dy: 0, extending: false)

    #expect(!state.isGroupedSectionKeyboardTargetActive)
    #expect(state.focusedReviewItemID != firstFocusedID)
    #expect(state.pendingReviewScrollTargetID == nil)
}

@MainActor
@Test func groupedSectionReturnEntersItemsAndEscapeReturnsToSectionSelection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(!sections.isEmpty)
    state.focusInlineSection(sections[0].id)

    state.activateCurrentReviewTarget()

    #expect(!state.isGroupedSectionKeyboardTargetActive)
    #expect(state.focusedReviewItemID != nil)
    #expect(state.focusedInlineSectionID == sections[0].id)

    state.handleReviewEscape()

    #expect(state.isGroupedSectionKeyboardTargetActive)
    #expect(state.focusedInlineSectionID == sections[0].id)
}

@MainActor
@Test func groupedSectionCommandOpenDrillsIntoScopedReview() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(!sections.isEmpty)
    state.focusInlineSection(sections[0].id)

    state.openCurrentSelection()

    #expect(state.drilledInlineSectionID == sections[0].id)
    #expect(state.dayDetailDisplayMode == .review)
    #expect(state.visibleMediaItems.count == state.drilledInlineSectionMediaItemIDs.count)

    state.handleReviewEscape()

    #expect(state.drilledInlineSectionID == nil)
    #expect(state.dayDetailDisplayMode == .sections)
    #expect(state.focusedInlineSectionID == sections[0].id)
    #expect(state.visibleMediaItems.count == items.count)
}

@MainActor
@Test func keyboardSelectionMovementRequestsScrollToFocusedItem() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    let firstFocusedID = state.focusedReviewItemID

    state.moveGridSelection(by: 1, extending: false)

    #expect(state.focusedReviewItemID != firstFocusedID)
    #expect(state.pendingReviewScrollTargetID == nil)
}

@MainActor
@Test func focusOnlyReviewMovesDoNotRefreshSidebarSnapshot() {
    let items = makeSelectionItems(count: 6)
    let state = makeReviewAppState(items: items)

    let initialSidebarGeneration = state.sidebarSnapshotGeneration
    state.focusReviewSurface()
    let sidebarGenerationAfterFocus = state.sidebarSnapshotGeneration

    state.moveGridSelection(by: 1, extending: false)

    #expect(initialSidebarGeneration == sidebarGenerationAfterFocus)
    #expect(state.sidebarSnapshotGeneration == sidebarGenerationAfterFocus)
    #expect(state.reviewSnapshotGeneration > 0)
    #expect(state.navigationSnapshotGeneration > 0)
}

@MainActor
@Test func triageUpdatesDoNotRebuildBrowserTree() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)
    let initialRootIDs = state.browserRoots.map(\.id)

    state.focusReviewSurface()
    state.performReviewShortcut("S")

    #expect(state.browserRoots.map(\.id) == initialRootIDs)
}

@MainActor
@Test func toggleSidebarVisibilityUsesAppManagedState() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.sidebarState.snapshot.isVisible)

    state.toggleSidebarVisibility()
    #expect(!state.sidebarState.snapshot.isVisible)

    state.focusSidebarNavigation()
    #expect(state.sidebarState.snapshot.isVisible)
    #expect(state.activePane == .sidebar)
}

@MainActor
@Test func hiddenInspectorDoesNotRefreshOnFocusMoves() {
    let items = makeSelectionItems(count: 5)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()
    state.toggleDetailsInspector()

    let hiddenGeneration = state.inspectorSnapshotGeneration
    state.moveGridSelection(by: 1, extending: false)

    #expect(!state.inspectorState.snapshot.isVisible)
    #expect(state.inspectorSnapshotGeneration == hiddenGeneration)
}

@MainActor
@Test func keyboardSelectionRequestsScrollWhenFocusLeavesEstimatedVisiblePage() {
    let items = makeSelectionItems(count: 20)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    state.pendingReviewScrollTargetID = nil

    for _ in 0..<12 {
        state.moveGridSelection(by: 1, extending: false)
    }

    #expect(state.focusedReviewItemID == items[12].id)
    #expect(state.pendingReviewScrollTargetID == items[12].id)
}

@MainActor
@Test func reviewFilterLimitsVisibleMediaByTriageState() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-filter-state", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "included.jpg", capturedAt: base, selectionState: .included),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "excluded.jpg", capturedAt: base.addingTimeInterval(1), selectionState: .excluded),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "undecided.jpg", capturedAt: base.addingTimeInterval(2), selectionState: .undecided)
    ]
    let state = makeReviewAppState(items: items)

    state.setReviewFilter(.included)
    #expect(state.visibleMediaItems.map(\.id) == [items[0].id])

    state.setReviewFilter(.excluded)
    #expect(state.visibleMediaItems.map(\.id) == [items[1].id])

    state.setReviewFilter(.undecided)
    #expect(state.visibleMediaItems.map(\.id) == [items[2].id])

    state.setReviewFilter(.all)
    #expect(state.visibleMediaItems.count == 3)
}

@MainActor
@Test func excludeCurrentSelectionUpdatesTriageStateAndClearsRawImportFlag() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-exclude-state", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 20_000)
    let companion = CompanionFile(
        sourceURL: sourceRoot.appendingPathComponent("first.cr3"),
        relativePath: "first.cr3",
        fileName: "first.cr3",
        fileSizeBytes: 1,
        kind: .raw
    )
    let items = [
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "first.jpg",
            capturedAt: capturedAt,
            selectionState: .included,
            importRawCompanions: true,
            companionFiles: [companion],
            lifecycleState: .selectedForImport
        ),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "second.jpg", capturedAt: capturedAt.addingTimeInterval(1))
    ]
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[0].id])

    state.excludeCurrentSelectionFromImport()

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .excluded)
    #expect(updatedItem?.lifecycleState == .discovered)
    #expect(updatedItem?.importRawCompanions == false)
}

@MainActor
@Test func filterChangeReconcilesSelectionWhenHiddenItemsDropOut() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-filter-reconcile", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "included.jpg", capturedAt: base, selectionState: .included),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "excluded.jpg", capturedAt: base.addingTimeInterval(1), selectionState: .excluded)
    ]
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[1].id])

    state.setReviewFilter(.included)

    #expect(state.selectedMediaItemIDs.isEmpty)
    #expect(state.focusedReviewItemID == items[0].id)
}

@MainActor
private func makeReviewAppState(items: [MediaItem]) -> AppState {
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/review-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []
    state.archiveMediaCache = [:]
    var settings = state.settings
    settings.reviewGridColumnCount = ReviewGridMetrics.defaultRequestedColumnCount()
    settings.reviewPresentationMode = .grid
    state.settings = settings
    state.updateReviewGridMetrics(availableWidth: 1_100, availableHeight: 900)

    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }

    #expect(state.visibleMediaItems.count == items.count)
    return state
}

private func makeSelectionItems(count: Int) -> [MediaItem] {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-selection-fixtures", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    return (0..<count).map { index in
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "\(index).jpg",
            capturedAt: base.addingTimeInterval(Double(index))
        )
    }
}
