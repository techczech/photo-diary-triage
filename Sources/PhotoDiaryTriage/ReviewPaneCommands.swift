import AppKit
import SwiftUI

extension DayDetailDisplayMode {
    var reviewCommandID: AppCommandID { self == .review ? .flatReview : .groupedReview }
}
extension ReviewPresentationMode {
    var reviewCommandID: AppCommandID { self == .grid ? .gridLayout : .listLayout }
}
extension ReviewFilter {
    var reviewCommandID: AppCommandID {
        switch self {
        case .all: .filterAll
        case .included: .filterIncluded
        case .candidate: .filterCandidate
        case .excluded: .filterExcluded
        case .undecided: .filterUndecided
        case .cropped: .filterCropped
        }
    }
}
extension DayOrganizationMode {
    var reviewCommandID: AppCommandID {
        switch self {
        case .days: .groupDays
        case .daysAndBursts: .groupDaysBursts
        case .daysAndClusters: .groupDaysClusters
        case .daysClustersAndBursts: .groupDaysClustersBursts
        }
    }
}

@MainActor
func reviewPaneCommandContextKey(_ state: AppState) -> String {
    localCommandContextKey([String(state.reviewPaneRevision), state.currentSession?.id.uuidString ?? "no Log",
        state.currentSession?.sourceFolder.standardizedFileURL.path ?? "",
        state.currentSession?.workspaceSourceFolder.standardizedFileURL.path ?? "",
        state.selectedSidebarNodeID ?? "", state.workspaceMode.rawValue,
        state.settings.archiveRoot.standardizedFileURL.path, state.settings.oneDrivePicturesRoot.standardizedFileURL.path,
        state.settings.archiveMachineRole.rawValue, String(ArchiveByteReadPolicyContext.shared.generation)])
}

@MainActor
private func reviewPaneCommandIsEnabled(_ id: AppCommandID, _ state: AppState) -> Bool {
    switch id {
    case .toggleReviewMap, .flatReview, .filterAll, .filterIncluded, .filterCandidate,
         .filterExcluded, .filterUndecided, .filterCropped, .gridLayout, .listLayout:
        // Empty filtered results still need a route back to the photos in this pane.
        return !state.contextMediaItems.isEmpty
    case .zoomIn: return state.settings.reviewGridColumnCount < ReviewGridMetrics.maxSuggestedColumns
    case .zoomOut: return state.settings.reviewGridColumnCount > 1
    case .zoomReset: return state.settings.reviewGridColumnCount != ReviewGridMetrics.defaultRequestedColumnCount()
    case .markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW:
        let ids = state.selectedMediaItemIDs.isEmpty ? Set(state.focusedReviewItemID.map { [$0] } ?? []) : state.selectedMediaItemIDs
        let photos = state.orderedMediaItems(for: Array(ids))
        return state.canMutateImportSelection && !photos.isEmpty && (id != .toggleRAW || photos.contains { !$0.companionFiles.isEmpty })
    default: return AppCommandRegistry.definition(id).enabled(state)
    }
}

@MainActor
func reviewPaneCommandActions(_ state: AppState, showMap: Binding<Bool>) -> [AppCommandID: SheetCommandAction] {
    let context = reviewPaneCommandContextKey(state)
    let ids: [AppCommandID] = [.toggleReviewMap, .flatReview, .groupedReview, .gridLayout, .listLayout,
        .filterAll, .filterIncluded, .filterCandidate, .filterExcluded, .filterUndecided, .filterCropped,
        .groupDays, .groupDaysBursts, .groupDaysClusters, .groupDaysClustersBursts,
        .zoomIn, .zoomOut, .zoomReset, .selectAll, .deselectReviewPhotos,
        .markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW, .expandAll, .collapseAll]
    return Dictionary(uniqueKeysWithValues: ids.map { id in
        (id, .init(enabled: reviewPaneCommandIsEnabled(id, state), run: {
            guard context == reviewPaneCommandContextKey(state), reviewPaneCommandIsEnabled(id, state) else { return }
            switch id {
            case .toggleReviewMap: showMap.wrappedValue.toggle(); return
            case .zoomIn: state.increaseReviewGridColumnCount()
            case .zoomOut: state.decreaseReviewGridColumnCount()
            case .zoomReset: state.resetReviewGridColumnCount()
            default: AppCommandRegistry.definition(id).run(state)
            }
            state.activateReviewGridFocus()
            // During execution this resolves the exact clicked/keyboard-owned window.
            state.commandCoordinator.requestFocus(scope: .review)
        }))
    })
}

@MainActor
func reviewPaneKeyboardTarget(in surface: CommandLocalSurfaceView) -> NSView? {
    func find(in view: NSView) -> [ReviewKeyResponderView] {
        if let keyboard = view as? ReviewKeyResponderView {
            return keyboard.commandScope == .review && !keyboard.isHiddenOrHasHiddenAncestor ? [keyboard] : []
        }
        return view.subviews.flatMap { find(in: $0) }
    }
    let targets = find(in: surface.host)
    return targets.count == 1 ? targets[0] : nil
}

struct ReviewPaneCommandSurface<Content: View>: View {
    @ObservedObject var appState: AppState
    @Binding var showMap: Bool
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .review,
            contextKey: reviewPaneCommandContextKey(appState), actions: reviewPaneCommandActions(appState, showMap: $showMap),
            fillsAvailableHeight: true, focusTarget: reviewPaneKeyboardTarget, content: content)
    }
}
