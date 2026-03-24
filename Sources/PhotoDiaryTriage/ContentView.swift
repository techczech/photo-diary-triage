import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    @State private var walkTitle: String = ""
    @State private var walkLocation: String = ""
    @State private var walkNotes: String = ""

    private let appRelease = AppRelease.current

    var body: some View {
        NavigationSplitView {
            SidebarPaneView(appState: appState)
        } detail: {
            detailPane
        }
    }

    private var detailPane: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HeaderPaneView(appState: appState)
                WalkDetailsPaneView(
                    appState: appState,
                    walkTitle: $walkTitle,
                    walkLocation: $walkLocation,
                    walkNotes: $walkNotes,
                    summary: walkDetailsSummary
                )
                BrowserOrReviewPaneView(appState: appState)
                ActionButtonsPaneView(appState: appState)
                FooterStatusBarView(appState: appState, appRelease: appRelease)
            }
            .frame(minWidth: 720, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if appState.isDetailsInspectorVisible {
                DetailsInspectorView(appState: appState)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 380, maxHeight: .infinity, alignment: .top)
            } else {
                InspectorCollapsedRail(appState: appState)
                    .frame(minWidth: 44, idealWidth: 44, maxWidth: 44, maxHeight: .infinity, alignment: .top)
            }
        }
        .padding()
        .sheet(isPresented: $appState.showKeyboardHelp) {
            KeyboardHelpSheet()
        }
        .alert(item: $appState.startupAlert) { alert in
            if alert.recoveryAction == .resetSupportData {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .destructive(Text("Reset Local Data")) {
                        appState.performStartupRecovery()
                    },
                    secondaryButton: .cancel {
                        appState.dismissStartupAlert()
                    }
                )
            }

            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    appState.dismissStartupAlert()
                }
            )
        }
        .sheet(item: Binding(
            get: { appState.previewingMediaItem },
            set: { _ in appState.previewingMediaItemID = nil }
        )) { item in
            FullPhotoSheet(appState: appState, item: item)
        }
        .sheet(isPresented: Binding(
            get: { !appState.comparingMediaItemIDs.isEmpty },
            set: { isPresented in
                if !isPresented {
                    appState.comparingMediaItemIDs.removeAll()
                }
            }
        )) {
            CompareSheet(appState: appState, title: appState.compareSheetTitle, items: appState.comparingMediaItems)
        }
        .onAppear(perform: hydrateForm)
        .onChange(of: appState.currentSession?.id) { _, _ in
            hydrateForm()
        }
        .onExitCommand {
            if appState.reviewGridHasFocus {
                appState.deactivateReviewGridFocus()
            } else {
                appState.navigateToParent()
            }
        }
    }

    private func hydrateForm() {
        walkTitle = appState.currentSession?.walkMetadata.title ?? ""
        walkLocation = appState.currentSession?.walkMetadata.location ?? ""
        walkNotes = appState.currentSession?.walkMetadata.notes ?? ""
        appState.updateWalkDetailsExpansion(for: appState.currentSession)
    }

    private var walkDetailsSummary: String {
        let title = walkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = walkLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = walkNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        let titlePart = title.isEmpty ? "Untitled walk" : title
        let locationPart = location.isEmpty ? "No location" : location
        let notesPart = notes.isEmpty ? "No notes" : "Notes saved"
        return "\(titlePart) • \(locationPart) • \(notesPart)"
    }
}
