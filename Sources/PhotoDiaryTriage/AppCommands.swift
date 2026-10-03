import AppKit
import SwiftUI

struct PhotoDiaryCommands: Commands {
    let appState: AppState
    static let nativeCommandParentTitles: [AppCommandID: String] = [
        .backfillThumbnails: "File",
        .cancelBackfill: "Archive",
        .cancelDescriptions: "Descriptions",
        .chooseArchiveRoot: "File",
        .chooseDefaultSourceRoot: "File",
        .chooseHistoricalSource: "File",
        .chooseSource: "File",
        .cleanupSource: "Copy",
        .clearArchiveFilters: "Archive",
        .clearPreviousUpload: "Google Photos",
        .clearTriage: "Triage",
        .collapseAll: "Grouping",
        .collapseGroup: "Grouping",
        .compare: "Triage",
        .confirmBackup: "Copy",
        .contactSheet: "Archive",
        .contextActions: "Commands",
        .copyIncluded: "Copy",
        .createPhotoLog: "Triage",
        .deliverPhotoLog: "Google Photos",
        .deliverTrip: "Google Photos",
        .describeSelection: "Descriptions",
        .describeTrip: "Descriptions",
        .describeYear: "Descriptions",
        .descriptionQueue: "Descriptions",
        .deselectAll: "Triage",
        .deselectReviewPhotos: "Triage",
        .discardDescriptions: "Descriptions",
        .expandAll: "Grouping",
        .expandGroup: "Grouping",
        .exportBackup: "File",
        .filterAll: "Review",
        .filterCandidate: "Review",
        .filterCropped: "Review",
        .filterExcluded: "Review",
        .filterIncluded: "Review",
        .filterUndecided: "Review",
        .find: "Commands",
        .flatReview: "Review",
        .focusReview: "Review",
        .focusSidebar: "Review",
        .goUp: "Triage",
        .googleQueue: "Google Photos",
        .gridLayout: "Review",
        .groupDays: "Grouping",
        .groupDaysBursts: "Grouping",
        .groupDaysClusters: "Grouping",
        .groupDaysClustersBursts: "Grouping",
        .groupedReview: "Review",
        .importBackup: "File",
        .keyboardHelp: "Help",
        .listLayout: "Review",
        .markCandidate: "Triage",
        .markExcluded: "Triage",
        .markIncluded: "Triage",
        .markPreviousUpload: "Google Photos",
        .migrateLayout: "File",
        .moveWalk: "Copy",
        .newPhotoLog: "Triage",
        .nextGroup: "Grouping",
        .open: "Triage",
        .openArchive: "Archive",
        .openDefaultSource: "File",
        .openDestination: "Copy",
        .openFocusedPhoto: "Triage",
        .organiseFolder: "Archive",
        .palette: "Commands",
        .prepareThumbnails: "Archive",
        .previousGroup: "Grouping",
        .rebuildIndex: "File",
        .refreshArchive: "Archive",
        .regenerateDescriptions: "Descriptions",
        .reloadSource: "File",
        .resumeDescriptions: "Descriptions",
        .searchArchive: "Archive",
        .selectAll: "Triage",
        .settings: "@application",
        .showArchive: "Commands",
        .showArchiveMap: "Archive",
        .showCamera: "Commands",
        .showPhotoLogs: "Commands",
        .timeline: "Archive",
        .toggleCovers: "Archive",
        .toggleInspector: "Review",
        .toggleRAW: "Triage",
        .toggleSidebar: "Review",
        .viewOriginal: "Triage",
    ]
    static let nativeCommandIDs = Set(nativeCommandParentTitles.keys)
    var body: some Commands {
        CommandGroup(after: .newItem) {
            commands([.chooseSource, .chooseDefaultSourceRoot, .chooseHistoricalSource, .openDefaultSource, .reloadSource, .chooseArchiveRoot, .migrateLayout, .backfillThumbnails, .rebuildIndex, .exportBackup, .importBackup])
        }
        CommandGroup(replacing: .appSettings) { RegisteredCommandButton(id: .settings, appState: appState) }
        CommandMenu("Archive") {
            commands([.timeline, .contactSheet, .showArchiveMap, .searchArchive, .openArchive, .organiseFolder, .prepareThumbnails, .toggleCovers, .refreshArchive, .cancelBackfill, .clearArchiveFilters])
        }
        CommandMenu("Review") {
            commands([.focusSidebar, .focusReview, .toggleSidebar, .toggleInspector, .flatReview, .groupedReview, .gridLayout, .listLayout,
                      .filterAll, .filterIncluded, .filterCandidate, .filterExcluded, .filterUndecided, .filterCropped])
        }
        CommandMenu("Grouping") {
            commands([.groupDays, .groupDaysBursts, .groupDaysClusters, .groupDaysClustersBursts, .expandAll, .collapseAll, .previousGroup, .nextGroup, .expandGroup, .collapseGroup])
        }
        CommandMenu("Triage") {
            commands([.markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW, .createPhotoLog, .newPhotoLog, .compare, .open, .openFocusedPhoto, .viewOriginal, .goUp, .selectAll, .deselectAll, .deselectReviewPhotos])
        }
        CommandMenu("Copy") { commands([.copyIncluded, .openDestination, .moveWalk, .confirmBackup, .cleanupSource]) }
        CommandMenu("Descriptions") {
            commands([.describeSelection, .regenerateDescriptions, .describeTrip, .describeYear, .descriptionQueue, .resumeDescriptions, .cancelDescriptions, .discardDescriptions])
        }
        CommandMenu("Google Photos") { commands([.deliverTrip, .deliverPhotoLog, .markPreviousUpload, .clearPreviousUpload, .googleQueue]) }
        CommandMenu("Commands") { commands([.palette, .contextActions, .find, .showCamera, .showPhotoLogs, .showArchive]) }
        CommandGroup(after: .help) { RegisteredCommandButton(id: .keyboardHelp, appState: appState) }
    }
    @ViewBuilder private func commands(_ ids: [AppCommandID]) -> some View {
        ForEach(ids, id: \.self) { RegisteredCommandButton(id: $0, appState: appState) }
    }
}

/// Static construction preserves SwiftUI's standard menu tree. AppKit owns the
/// live validation and key equivalents after the generated item is attached.
struct RegisteredCommandButton: View {
    let id: AppCommandID
    let appState: AppState
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button(AppCommandRegistry.definition(id).title) {
            let coordinator = appState.commandCoordinator
            coordinator.nativeMenus.perform(id, settingsOpener: { openSettings() })
        }
    }
}

struct RegisteredWindowControl: View {
    let id: AppCommandID
    let title: String
    @ObservedObject var appState: AppState
    var body: some View {
        Button(title) { appState.commandCoordinator.executeWindowControl(id) }
            .disabled(!AppCommandRegistry.definition(id).enabled(appState))
    }
}
