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
            Button("Mark Selection For Import") {
                appState.markCurrentSelectionForImport()
            }
            .keyboardShortcut("i", modifiers: [.command])
            .disabled(!appState.canMarkSelectionForImport)

            Button("Remove Selection From Import") {
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
            .keyboardShortcut(.return, modifiers: [])
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

            Button("Grid Review") {
                appState.setReviewPresentationMode(.grid)
            }

            Button("List Review") {
                appState.setReviewPresentationMode(.list)
            }
        }

        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") {
                appState.showKeyboardHelp = true
            }
            .keyboardShortcut("?", modifiers: [.command, .shift])
        }
    }
}
