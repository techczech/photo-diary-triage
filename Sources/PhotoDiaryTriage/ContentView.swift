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
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 380)
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
            .inspectorColumnWidth(min: 300, ideal: 360, max: 460)
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
            navigationState: reviewNavigationState
        )
        .frame(minWidth: 720, maxWidth: .infinity, alignment: .leading)
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
                appState.toggleSidebarVisibility()
            } label: {
                Label("Sidebar", systemImage: sidebarState.snapshot.isVisible ? "sidebar.leading" : "sidebar.left")
            }
            .help("\(sidebarState.snapshot.isVisible ? "Hide" : "Show") sidebar")

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

        ToolbarItemGroup {
            reviewModePicker
            reviewGroupingPicker
            reviewFilterPicker
            reviewPresentationPicker
            reviewColumnControls
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

    @ViewBuilder
    private var reviewModePicker: some View {
        if reviewState.snapshot.contextMediaItemCount > 0 {
            Picker("Display", selection: Binding(
                get: { reviewState.snapshot.dayDetailDisplayMode },
                set: { appState.setDayDetailDisplayMode($0) }
            )) {
                ForEach(reviewState.snapshot.availableDayDetailDisplayModes, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: reviewState.snapshot.canUseGroupedReviewMode ? 230 : 122)
            .help("Switch between flat review and grouped review")
        }
    }

    @ViewBuilder
    private var reviewFilterPicker: some View {
        if reviewState.snapshot.contextMediaItemCount > 0 {
            Picker("Filter", selection: Binding(
                get: { reviewState.snapshot.reviewFilter },
                set: { appState.setReviewFilter($0) }
            )) {
                ForEach(ReviewFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            .help("Filter review items")
        }
    }

    @ViewBuilder
    private var reviewGroupingPicker: some View {
        if reviewState.snapshot.canUseGroupedReviewMode,
           reviewState.snapshot.dayDetailDisplayMode == .sections {
            Picker("Show By", selection: Binding(
                get: { reviewState.snapshot.dayOrganizationMode },
                set: { appState.setDayOrganizationMode($0) }
            )) {
                ForEach(DayOrganizationMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 360)
            .help("Change grouped review organization")
        }
    }

    @ViewBuilder
    private var reviewPresentationPicker: some View {
        if reviewState.snapshot.contextMediaItemCount > 0 {
            Picker("View", selection: Binding(
                get: { reviewState.snapshot.reviewPresentationMode },
                set: { appState.setReviewPresentationMode($0) }
            )) {
                Text("Grid").tag(ReviewPresentationMode.grid)
                Text("List").tag(ReviewPresentationMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 136)
            .help("Switch between grid and list layout")
        }
    }

    @ViewBuilder
    private var reviewColumnControls: some View {
        if reviewState.snapshot.contextMediaItemCount > 0 {
            HStack(spacing: 6) {
                Button {
                    appState.decreaseReviewGridColumnCount()
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(reviewState.snapshot.reviewGridPreferredColumnCount <= 1)
                .help("Show fewer review columns")

                Text("\(reviewState.snapshot.reviewGridPreferredColumnCount)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 24)

                Button {
                    appState.increaseReviewGridColumnCount()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(reviewState.snapshot.reviewGridPreferredColumnCount >= ReviewGridMetrics.maxSuggestedColumns)
                .help("Show more review columns")

                Button {
                    appState.resetReviewGridColumnCount()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .disabled(reviewState.snapshot.reviewGridPreferredColumnCount == ReviewGridMetrics.defaultRequestedColumnCount())
                .help("Reset review columns")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
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
