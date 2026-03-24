import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func selectionManagerSelectMediaItemsActivatesMediaPane() {
    let manager = SelectionManager()
    let items = makeSelectionItems(count: 3)
    var state = makeSelectionState()

    manager.selectMediaItems([items[1].id], state: &state)

    #expect(state.selectedMediaItemIDs == [items[1].id])
    #expect(state.reviewSelectionAnchorID == items[1].id)
    #expect(state.focusedReviewItemID == items[1].id)
    expectMediaPane(state)
}

@Test func selectionManagerCommandClickTogglesAdditionalSelection() {
    let manager = SelectionManager()
    let items = makeSelectionItems(count: 4)
    var state = makeSelectionState(selected: [items[0].id], focused: items[0].id, anchor: items[0].id)

    manager.handleGridSelection(
        for: items[2].id,
        visibleItems: items,
        isShiftPressed: false,
        isCommandPressed: true,
        state: &state
    )

    #expect(state.selectedMediaItemIDs == [items[0].id, items[2].id])
    #expect(state.reviewSelectionAnchorID == items[2].id)
    #expect(state.focusedReviewItemID == items[2].id)
    expectMediaPane(state)
    #expect(state.reviewGridHasFocus)
}

@Test func selectionManagerShiftClickExtendsSelectionFromAnchor() {
    let manager = SelectionManager()
    let items = makeSelectionItems(count: 5)
    var state = makeSelectionState(selected: [items[1].id], focused: items[1].id, anchor: items[1].id)

    manager.handleGridSelection(
        for: items[3].id,
        visibleItems: items,
        isShiftPressed: true,
        isCommandPressed: false,
        state: &state
    )

    #expect(state.selectedMediaItemIDs == [items[1].id, items[2].id, items[3].id])
    #expect(state.reviewSelectionAnchorID == items[1].id)
    #expect(state.focusedReviewItemID == items[3].id)
}

@Test func selectionManagerMoveSelectionExtendingUpdatesRange() {
    let manager = SelectionManager()
    let items = makeSelectionItems(count: 5)
    var state = makeSelectionState(selected: [items[1].id], focused: items[1].id, anchor: items[1].id)

    manager.moveSelection(by: 2, visibleItems: items, extending: true, state: &state)

    #expect(state.selectedMediaItemIDs == [items[1].id, items[2].id, items[3].id])
    #expect(state.reviewSelectionAnchorID == items[1].id)
    #expect(state.focusedReviewItemID == items[3].id)
}

@Test func selectionManagerToggleFocusedItemSelectionKeepsFocus() {
    let manager = SelectionManager()
    let items = makeSelectionItems(count: 3)
    var state = makeSelectionState(selected: [items[0].id], focused: items[0].id, anchor: items[0].id)

    manager.toggleFocusedReviewItemSelection(items, state: &state)
    #expect(state.selectedMediaItemIDs.isEmpty)
    #expect(state.focusedReviewItemID == items[0].id)

    manager.toggleFocusedReviewItemSelection(items, state: &state)
    #expect(state.selectedMediaItemIDs == [items[0].id])
    #expect(state.reviewSelectionAnchorID == items[0].id)
    #expect(state.focusedReviewItemID == items[0].id)
}

private func makeSelectionItems(count: Int) -> [MediaItem] {
    let sourceRoot = URL(fileURLWithPath: "/tmp/selection-fixtures", isDirectory: true)
    let base = Date(timeIntervalSince1970: 10_000)
    return (0..<count).map { index in
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "\(index).jpg",
            capturedAt: base.addingTimeInterval(Double(index))
        )
    }
}

private func makeSelectionState(
    selected: Set<UUID> = [],
    focused: UUID? = nil,
    anchor: UUID? = nil
) -> ReviewSelectionState {
    ReviewSelectionState(
        selectedMediaItemIDs: selected,
        focusedReviewItemID: focused,
        reviewSelectionAnchorID: anchor,
        activePane: .sidebar,
        reviewGridHasFocus: false
    )
}

private func expectMediaPane(_ state: ReviewSelectionState) {
    switch state.activePane {
    case .media:
        #expect(Bool(true))
    case .folders, .sidebar:
        #expect(Bool(false))
    }
}
