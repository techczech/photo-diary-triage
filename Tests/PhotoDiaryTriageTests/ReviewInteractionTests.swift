import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func reviewGridMetricsUseMeasuredWidthForColumnCount() {
    let compact = ReviewGridMetrics(availableWidth: 540, cardWidth: 240)
    let wide = ReviewGridMetrics(availableWidth: 1_100, cardWidth: 240)

    #expect(compact.columnCount == 2)
    #expect(wide.columnCount == 4)
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
