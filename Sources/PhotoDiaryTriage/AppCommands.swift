import SwiftUI

struct PhotoDiaryCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        SidebarCommands()

        CommandGroup(after: .newItem) {
            Button("Choose Source Folder…") {
                appState.pickSourceFolder()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Set Archive Root…") {
                appState.pickArchiveRoot()
            }

            Button("Export Backup…") {
                appState.exportBackup()
            }

            Button("Import Backup…") {
                appState.importBackup()
            }
        }

        CommandMenu("Triage") {
            Button("Toggle Sidebar") {
                appState.toggleSidebarVisibility()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])

            Button("Focus Sidebar Navigation") {
                appState.focusSidebarNavigation()
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Focus Review Grid") {
                appState.focusReviewSurface()
            }
            .keyboardShortcut("2", modifiers: [.command])
            .disabled(!appState.canFocusReviewSurface)

            Button(appState.isDetailsInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                appState.toggleDetailsInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])

            Divider()

            Button("Flat Review") {
                appState.showFlatReview()
            }
            .keyboardShortcut("3", modifiers: [.command])
            .disabled(!appState.canFocusReviewSurface)

            Button("Grouped Review") {
                appState.showGroupedReview()
            }
            .keyboardShortcut("4", modifiers: [.command])
            .disabled(!appState.canUseGroupedReviewMode)

            Button("Grid Layout") {
                appState.setReviewPresentationMode(.grid)
            }
            .keyboardShortcut("g", modifiers: [.command, .option])

            Button("List Layout") {
                appState.setReviewPresentationMode(.list)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Divider()

            Button("Show All Photos") {
                appState.setReviewFilter(.all)
            }
            .keyboardShortcut("a", modifiers: [.command, .control])

            Button("Show Included Photos") {
                appState.setReviewFilter(.included)
            }
            .keyboardShortcut("i", modifiers: [.command, .control])

            Button("Show Excluded Photos") {
                appState.setReviewFilter(.excluded)
            }
            .keyboardShortcut("x", modifiers: [.command, .control])

            Button("Show Undecided Photos") {
                appState.setReviewFilter(.undecided)
            }
            .keyboardShortcut("u", modifiers: [.command, .control])

            Divider()

            Button("Days Grouping") {
                appState.setDayOrganizationMode(.days)
            }
            .keyboardShortcut("1", modifiers: [.command, .control])
            .disabled(!appState.canUseGroupedReviewMode)

            Button("Days + Bursts Grouping") {
                appState.setDayOrganizationMode(.daysAndBursts)
            }
            .keyboardShortcut("2", modifiers: [.command, .control])
            .disabled(!appState.canUseGroupedReviewMode)

            Button("Days + Clusters Grouping") {
                appState.setDayOrganizationMode(.daysAndClusters)
            }
            .keyboardShortcut("3", modifiers: [.command, .control])
            .disabled(!appState.canUseGroupedReviewMode)

            Button("Days + Clusters + Bursts Grouping") {
                appState.setDayOrganizationMode(.daysClustersAndBursts)
            }
            .keyboardShortcut("4", modifiers: [.command, .control])
            .disabled(!appState.canUseGroupedReviewMode)

            Button("Expand All Groups") {
                appState.expandAllInlineSections()
            }
            .keyboardShortcut("]", modifiers: [.command, .option])
            .disabled(!appState.canExpandAllGroupedSections)

            Button("Collapse All Groups") {
                appState.collapseAllInlineSections()
            }
            .keyboardShortcut("[", modifiers: [.command, .option])
            .disabled(!appState.canCollapseAllGroupedSections)

            Button("Previous Group") {
                appState.focusPreviousInlineSection()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            .disabled(!appState.canUseGroupedSectionNavigation)

            Button("Next Group") {
                appState.focusNextInlineSection()
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            .disabled(!appState.canUseGroupedSectionNavigation)

            Button("Expand Focused Group") {
                appState.expandFocusedInlineSection()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            .disabled(!appState.canUseGroupedSectionNavigation)

            Button("Collapse Focused Group") {
                appState.collapseFocusedInlineSection()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            .disabled(!appState.canUseGroupedSectionNavigation)

            Divider()

            Button("Select Selection For Import") {
                appState.markCurrentSelectionForImport()
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(!appState.canMarkSelectionForImport)

            Button("Exclude Selection From Import") {
                appState.excludeCurrentSelectionFromImport()
            }
            .keyboardShortcut("x", modifiers: [.command, .shift])
            .disabled(!appState.canExcludeSelectionFromImport)

            Button("Clear Selection To Undecided") {
                appState.unmarkCurrentSelectionForImport()
            }
            .keyboardShortcut("I", modifiers: [.command, .shift])
            .disabled(!appState.canUnmarkSelectionForImport)

            Button("Toggle RAW Companion Import") {
                appState.toggleRawForCurrentMediaSelection()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(!appState.canToggleRawForSelection)

            Button("Compare Selection") {
                appState.openComparisonForCurrentSelection()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!appState.canOpenComparison)

            Divider()

            Button("Open") {
                appState.openCurrentSelection()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(!appState.canOpenCurrentSelection)

            Button("Go Up") {
                appState.navigateToParent()
            }
            .keyboardShortcut(.upArrow, modifiers: [.command])
            .disabled(!appState.canNavigateToParent)

            Button("Deselect All") {
                appState.clearCurrentSelection()
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .disabled(!appState.canClearCurrentSelection)

            Divider()

            Button("Copy Included Files Into Archive") {
                appState.commitImport()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(!appState.canCommitImport)

            Button("Confirm Backup And Enable Cleanup") {
                appState.markBackupConfirmed()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            .disabled(!appState.canConfirmBackup)

            Button("Clean Imported Files From Source SSD") {
                appState.cleanupImportedSources()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .disabled(!appState.canCleanupImportedSources)
        }

        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") {
                appState.showKeyboardHelp = true
            }
            .keyboardShortcut("?", modifiers: [.command, .shift])
        }
    }
}
