import AppKit
import SwiftUI

struct ContentView: View {
    let appState: AppState
    @ObservedObject private var sidebarState: SidebarState
    @ObservedObject private var reviewState: ReviewState
    @ObservedObject private var reviewNavigationState: ReviewNavigationState
    @ObservedObject private var inspectorState: InspectorState
    @ObservedObject private var compareState: CompareState
    @ObservedObject private var presentationState: PresentationState

    @State private var walkTitle: String = ""
    @State private var walkLocation: String = ""
    @State private var walkNotes: String = ""

    private let appRelease = AppRelease.current

    init(appState: AppState) {
        self.appState = appState
        _sidebarState = ObservedObject(wrappedValue: appState.sidebarState)
        _reviewState = ObservedObject(wrappedValue: appState.reviewState)
        _reviewNavigationState = ObservedObject(wrappedValue: appState.reviewNavigationState)
        _inspectorState = ObservedObject(wrappedValue: appState.inspectorState)
        _compareState = ObservedObject(wrappedValue: appState.compareState)
        _presentationState = ObservedObject(wrappedValue: appState.presentationState)
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarPaneView(
                appState: appState,
                state: sidebarState,
                walkTitle: $walkTitle,
                walkLocation: $walkLocation,
                walkNotes: $walkNotes,
                summary: walkDetailsSummary,
                appRelease: appRelease
            )
            .frame(width: sidebarState.snapshot.isVisible ? 320 : 0, alignment: .leading)
            .opacity(sidebarState.snapshot.isVisible ? 1 : 0)
            .allowsHitTesting(sidebarState.snapshot.isVisible)
            .clipped()

            Divider()
                .frame(width: sidebarState.snapshot.isVisible ? 1 : 0)
                .opacity(sidebarState.snapshot.isVisible ? 1 : 0)

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if !compareState.snapshot.itemIDs.isEmpty {
                CompareSheet(
                    appState: appState,
                    state: compareState,
                    onClose: {
                        appState.closeComparison()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .zIndex(1)
            }
        }
    }

    private var detailPane: some View {
        HStack(alignment: .top, spacing: 12) {
            BrowserOrReviewPaneView(
                appState: appState,
                state: reviewState,
                navigationState: reviewNavigationState
            )
                .frame(minWidth: 720, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            DetailsInspectorView(appState: appState, state: inspectorState)
                .frame(width: inspectorState.snapshot.isVisible ? 340 : 0, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .opacity(inspectorState.snapshot.isVisible ? 1 : 0)
                .allowsHitTesting(inspectorState.snapshot.isVisible)
                .clipped()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .sheet(isPresented: Binding(
            get: { presentationState.snapshot.showKeyboardHelp },
            set: { appState.showKeyboardHelp = $0 }
        )) {
            KeyboardHelpSheet()
        }
        .alert(item: Binding(
            get: { presentationState.snapshot.startupAlert },
            set: { _ in appState.dismissStartupAlert() }
        )) { alert in
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
            get: { presentationState.snapshot.previewingMediaItem },
            set: { _ in appState.previewingMediaItemID = nil }
        )) { item in
            FullPhotoSheet(appState: appState, item: item)
        }
        .onAppear(perform: hydrateForm)
        .onChange(of: sidebarState.snapshot.sessionSummary?.sessionID) { _, _ in
            hydrateForm()
        }
        .onExitCommand {
            if reviewNavigationState.snapshot.reviewGridHasFocus {
                appState.deactivateReviewGridFocus()
            } else {
                appState.navigateToParent()
            }
        }
    }

    private func hydrateForm() {
        walkTitle = sidebarState.snapshot.sessionSummary?.walkMetadata.title ?? ""
        walkLocation = sidebarState.snapshot.sessionSummary?.walkMetadata.location ?? ""
        walkNotes = sidebarState.snapshot.sessionSummary?.walkMetadata.notes ?? ""
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
