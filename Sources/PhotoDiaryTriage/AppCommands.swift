import AppKit
import SwiftUI

struct PhotoDiaryCommands: Commands {
    @ObservedObject var appState: AppState
    var body: some Commands {
        CommandGroup(after: .newItem) {
            commands([.chooseSource, .chooseArchiveRoot, .migrateLayout, .backfillThumbnails, .rebuildIndex, .exportBackup, .importBackup])
        }
        CommandGroup(replacing: .appSettings) { RegisteredCommandButton(id: .settings, appState: appState) }
        CommandMenu("Archive") {
            commands([.timeline, .contactSheet, .searchArchive, .openArchive, .organiseFolder, .prepareThumbnails, .toggleCovers, .refreshArchive, .cancelBackfill])
        }
        CommandMenu("Review") {
            commands([.focusSidebar, .focusReview, .toggleSidebar, .toggleInspector, .flatReview, .groupedReview, .gridLayout, .listLayout,
                      .filterAll, .filterIncluded, .filterCandidate, .filterExcluded, .filterUndecided, .filterCropped])
        }
        CommandMenu("Grouping") {
            commands([.groupDays, .groupDaysBursts, .groupDaysClusters, .groupDaysClustersBursts, .expandAll, .collapseAll, .previousGroup, .nextGroup, .expandGroup, .collapseGroup])
        }
        CommandMenu("Triage") {
            commands([.markIncluded, .markExcluded, .markCandidate, .clearTriage, .toggleRAW, .createPhotoLog, .newPhotoLog, .compare, .open, .viewOriginal, .goUp, .selectAll, .deselectAll])
        }
        CommandMenu("Copy") { commands([.copyIncluded, .openDestination, .moveWalk, .confirmBackup, .cleanupSource]) }
        CommandMenu("Descriptions") {
            commands([.describeSelection, .regenerateDescriptions, .describeTrip, .describeYear, .descriptionQueue, .resumeDescriptions, .cancelDescriptions, .discardDescriptions])
        }
        CommandMenu("Google Photos") { commands([.deliverTrip, .deliverPhotoLog, .markPreviousUpload, .clearPreviousUpload, .googleQueue]) }
        CommandMenu("Commands") { commands([.palette, .contextActions, .find]) }
        CommandGroup(after: .help) { RegisteredCommandButton(id: .keyboardHelp, appState: appState) }
    }
    @ViewBuilder private func commands(_ ids: [AppCommandID]) -> some View {
        ForEach(ids, id: \.self) { RegisteredCommandButton(id: $0, appState: appState) }
    }
}

struct RegisteredCommandButton: View {
    let id: AppCommandID
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        let coordinator = appState.commandCoordinator
        let origin = NSApp?.keyWindow.flatMap { coordinator.invocation(in: $0) }
        let binding = coordinator.registry.bindings(id).first { binding in origin.map { binding.scopes.contains($0.scope) } ?? true }
        let button = Button(AppCommandRegistry.definition(id).title) {
            coordinator.execute(id, invocation: NSApp?.keyWindow.flatMap { coordinator.invocation(in: $0) }, settingsOpener: { openSettings() })
        }
        .disabled(id != .settings && coordinator.unavailableReason(id, invocation: origin) != nil)
        if let binding { button.keyboardShortcut(binding.shortcut.menuKey, modifiers: binding.shortcut.modifiers.swiftUI) }
        else { button }
    }
}
