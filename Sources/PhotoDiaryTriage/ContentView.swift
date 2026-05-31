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
        NavigationSplitView(columnVisibility: sidebarColumnVisibility) {
            SidebarPaneView(
                appState: appState,
                state: sidebarState,
                appRelease: appRelease
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
        } detail: {
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: inspectorVisibility) {
            DetailsInspectorView(
                appState: appState,
                state: inspectorState,
                sidebarState: sidebarState,
                walkTitle: $walkTitle,
                walkLocation: $walkLocation,
                walkNotes: $walkNotes,
                summary: photoLogDetailsSummary
            )
            .inspectorColumnWidth(min: 260, ideal: 320, max: 420)
        }
        .toolbar {
            mainToolbar
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
        BrowserOrReviewPaneView(
            appState: appState,
            state: reviewState,
            navigationState: reviewNavigationState,
            sidebarState: sidebarState,
            thumbnailLoadingState: appState.thumbnailLoadingState
        )
        .frame(minWidth: 560, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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
        .sheet(item: Binding(
            get: { presentationState.snapshot.activePhotoLogEditor },
            set: { _ in appState.dismissPhotoLogEditor() }
        )) { editor in
            PhotoLogEditorSheet(appState: appState, editor: editor)
        }
        .sheet(item: Binding(
            get: { presentationState.snapshot.revealedPhotoLog },
            set: { _ in appState.dismissRevealedPhotoLog() }
        )) { revealed in
            PhotoLogContentsSheet(appState: appState, revealed: revealed)
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

    private var sidebarColumnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { sidebarState.snapshot.isVisible ? .all : .detailOnly },
            set: { visibility in
                appState.isSidebarVisible = visibility != .detailOnly
            }
        )
    }

    private var inspectorVisibility: Binding<Bool> {
        Binding(
            get: { inspectorState.snapshot.isVisible },
            set: { isVisible in
                if appState.isDetailsInspectorVisible != isVisible {
                    appState.toggleDetailsInspector()
                }
            }
        )
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                appState.pickSourceFolder()
            } label: {
                Label("Source", systemImage: "externaldrive.badge.plus")
            }
            .help("Choose source folder")

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Open settings")
        }

        ToolbarItem(placement: .principal) {
            workspaceModePicker
        }

        ToolbarItemGroup {
            Button {
                appState.openFocusedReviewItem()
            } label: {
                Label("Open", systemImage: "arrow.up.forward.square")
            }
            .disabled(reviewState.snapshot.focusedReviewItemID == nil)
            .help("Open focused photo preview")

            Button {
                appState.openComparisonForCurrentSelection()
            } label: {
                Label("Compare", systemImage: "rectangle.split.2x1")
            }
            .disabled(!reviewState.snapshot.canOpenComparison)
            .help("Compare the current selection")

            Button {
                appState.toggleDetailsInspector()
            } label: {
                Label("Inspector", systemImage: inspectorState.snapshot.isVisible ? "sidebar.right" : "sidebar.right")
            }
            .help("\(inspectorState.snapshot.isVisible ? "Hide" : "Show") inspector")

            Button {
                appState.showKeyboardHelp = true
            } label: {
                Label("Shortcuts", systemImage: "keyboard")
            }
            .help("Show keyboard shortcuts")

            reviewActionsMenu
        }
    }

    private var workspaceModePicker: some View {
        Picker("Workspace", selection: Binding(
            get: { appState.workspaceMode },
            set: { appState.setWorkspaceMode($0) }
        )) {
            ForEach(WorkspaceMode.displayOrder, id: \.self) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.regular)
        .frame(minWidth: 360, idealWidth: 500, maxWidth: 560)
    }

    @ViewBuilder
    private var reviewActionsMenu: some View {
        if reviewState.snapshot.contextMediaItemCount > 0 {
            Menu {
                Button("Select All") {
                    appState.selectAllVisibleMedia()
                }

                Button("Deselect") {
                    appState.deselectAllVisibleMedia()
                }
                .disabled(reviewState.snapshot.selectedMediaItemIDs.isEmpty)

                if reviewState.snapshot.canMutateImportSelection {
                    Divider()

                    Button("Select For Import") {
                        appState.markCurrentSelectionForImport()
                    }
                    .disabled(!reviewState.snapshot.canMarkSelectionForImport)

                    Button("Mark As Candidate") {
                        appState.markCurrentSelectionAsCandidate()
                    }
                    .disabled(!reviewState.snapshot.canMarkSelectionAsCandidate)

                    Button("Exclude From Import") {
                        appState.excludeCurrentSelectionFromImport()
                    }
                    .disabled(!reviewState.snapshot.canExcludeSelectionFromImport)

                    Button("Clear To Undecided") {
                        appState.unmarkCurrentSelectionForImport()
                    }
                    .disabled(!reviewState.snapshot.canUnmarkSelectionForImport)

                    Button("Toggle RAW") {
                        appState.toggleRawForCurrentMediaSelection()
                    }
                    .disabled(!reviewState.snapshot.canToggleRawForSelection)
                }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
            .help("Selection and import actions")
        }
    }

    private func hydrateForm() {
        walkTitle = sidebarState.snapshot.sessionSummary?.walkMetadata.title ?? ""
        walkLocation = sidebarState.snapshot.sessionSummary?.walkMetadata.location ?? ""
        walkNotes = sidebarState.snapshot.sessionSummary?.walkMetadata.notes ?? ""
        appState.updateWalkDetailsExpansion(for: appState.currentSession)
    }

    private var photoLogDetailsSummary: String {
        let title = walkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = walkLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = walkNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        let titlePart = title.isEmpty ? "Untitled photo log" : title
        let locationPart = location.isEmpty ? "No location" : location
        let notesPart = notes.isEmpty ? "No notes" : "Notes saved"
        return "\(titlePart) • \(locationPart) • \(notesPart)"
    }
}
