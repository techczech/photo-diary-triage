import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func reviewGridMetricsUseMeasuredWidthForColumnCount() {
    let compact = ReviewGridMetrics(availableWidth: 540, cardWidth: 240)
    let wide = ReviewGridMetrics(availableWidth: 1_100, cardWidth: 240)

    #expect(compact.columnCount == 2)
    #expect(wide.columnCount == 4)
}

@Test func compareGridMetricsReflowMoreItemsWhenTargetCardWidthShrinks() {
    let roomy = CompareGridMetrics(availableWidth: 1_600, targetCardWidth: 520, itemCount: 4)
    let dense = CompareGridMetrics(availableWidth: 1_600, targetCardWidth: 320, itemCount: 4)

    #expect(roomy.columnCount == 2)
    #expect(dense.columnCount == 4)
    #expect(dense.cardWidth < roomy.cardWidth)
}

@Test func compareGridMetricsZoomAlsoChangesCardWidth() {
    let defaultZoom = CompareGridMetrics(availableWidth: 1_600, targetCardWidth: 320, itemCount: 4, zoomScale: 1)
    let zoomedOut = CompareGridMetrics(availableWidth: 1_600, targetCardWidth: 320, itemCount: 4, zoomScale: 0.5)
    let zoomedIn = CompareGridMetrics(availableWidth: 1_600, targetCardWidth: 320, itemCount: 4, zoomScale: 1.5)

    #expect(zoomedOut.cardWidth < defaultZoom.cardWidth)
    #expect(zoomedIn.cardWidth > defaultZoom.cardWidth)
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
@Test func compareRequestDeduplicatesIDsAndStoresTitle() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[0].id, items[1].id, items[0].id], title: "Compare Burst")

    #expect(state.compareSheetTitle == "Compare Burst")
    #expect(state.comparingMediaItemIDs == [items[0].id, items[1].id])
}

@MainActor
@Test func reviewGridResizeUsesLastMeasuredWidthInsteadOfFallingBackToSingleStrip() {
    let items = makeSelectionItems(count: 6)
    let state = makeReviewAppState(items: items)

    state.updateReviewGridMetrics(availableWidth: 1_100)
    #expect(state.reviewGridColumnCount == 3)

    state.setReviewGridCardWidth(220)
    #expect(state.reviewGridColumnCount == 4)

    state.resetReviewGridCardWidth()
    #expect(state.reviewGridColumnCount == 3)
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
    let state = AppState()
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
    let state = AppState()
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
    let state = AppState()
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
    let state = AppState()

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
    #expect(state.pendingReviewScrollTargetID == state.focusedReviewItemID)
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
    #expect(state.pendingInlineSectionScrollTargetID == sections[1].id)
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
    #expect(state.pendingReviewScrollTargetID == state.focusedReviewItemID)
}

@MainActor
@Test func keyboardSelectionMovementRequestsScrollToFocusedItem() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    let firstFocusedID = state.focusedReviewItemID

    state.moveGridSelection(by: 1, extending: false)

    #expect(state.focusedReviewItemID != firstFocusedID)
    #expect(state.pendingReviewScrollTargetID == state.focusedReviewItemID)
}

@MainActor
private func makeReviewAppState(items: [MediaItem]) -> AppState {
    let state = AppState()
    let root = URL(fileURLWithPath: "/tmp/review-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []
    state.archiveMediaCache = [:]

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
