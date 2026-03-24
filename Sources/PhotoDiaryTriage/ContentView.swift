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
                headerPane
                WalkDetailsPaneView(
                    appState: appState,
                    walkTitle: $walkTitle,
                    walkLocation: $walkLocation,
                    walkNotes: $walkNotes,
                    summary: walkDetailsSummary
                )
                browserOrReviewPane
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
            FullPhotoSheet(item: item)
        }
        .sheet(isPresented: Binding(
            get: { !appState.comparingMediaItemIDs.isEmpty },
            set: { isPresented in
                if !isPresented {
                    appState.comparingMediaItemIDs.removeAll()
                }
            }
        )) {
            CompareSheet(items: appState.comparingMediaItems)
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

    private var headerPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(appState.breadcrumbTitles.joined(separator: " / "))
                    .font(.headline)
                Spacer()
                Button(appState.isDetailsInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                    appState.toggleDetailsInspector()
                }
                .buttonStyle(.bordered)
                Button("Keyboard Shortcuts") {
                    appState.showKeyboardHelp = true
                }
            }

            if let node = appState.selectedBrowserNode {
                Text(node.subtitle ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var browserOrReviewPane: some View {
        if appState.shouldShowInlineDaySections {
            inlineDaySectionsPane
        } else if !appState.detailFolderNodes.isEmpty {
            folderBrowserPane
        } else if !appState.visibleMediaItems.isEmpty {
            reviewPane
        } else {
            ContentUnavailableView("No Content", systemImage: "folder", description: Text("Choose a source folder and browse by year, month, day, or grouping folders."))
        }
    }

    private var inlineDaySectionsPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Show By", selection: Binding(
                    get: { appState.dayOrganizationMode },
                    set: { appState.setDayOrganizationMode($0) }
                )) {
                    ForEach(DayOrganizationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 520)

                Spacer()

                Button("Expand All") {
                    appState.expandAllInlineSections()
                }

                Button("Collapse All") {
                    appState.collapseAllInlineSections()
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(appState.organizedInlineSections) { section in
                            InlineSectionNodeView(appState: appState, section: section, sectionPath: [section.id])
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: appState.pendingInlineScrollTargetID) { _, targetID in
                    guard let targetID else { return }
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                        appState.pendingInlineScrollTargetID = nil
                    }
                }
            }
        }
    }

    private var folderBrowserPane: some View {
        List(selection: Binding(
            get: { appState.selectedFolderNodeIDs },
            set: { appState.selectFolderNodes($0) }
        )) {
            ForEach(appState.detailFolderNodes) { node in
                FolderNodeRow(node: node)
                    .tag(node.id)
                    .onTapGesture(count: 2) {
                        appState.selectFolderNodes([node.id])
                        appState.openCurrentSelection()
                    }
            }
        }
        .onTapGesture {
            appState.activePane = .folders
            appState.deactivateReviewGridFocus()
        }
    }

    private var reviewPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            reviewToolbar

            ZStack(alignment: .topLeading) {
                ReviewKeyInputView(
                    isFocused: appState.reviewGridHasFocus,
                    onArrow: { dx, dy, extending in
                        let columns = reviewColumnCount
                        if dx != 0 {
                            appState.moveGridSelection(by: dx, extending: extending)
                        } else if dy != 0 {
                            appState.moveGridSelection(by: dy * columns, extending: extending)
                        }
                    },
                    onSingleKey: { key in
                        appState.performReviewShortcut(key)
                    },
                    onSpace: {
                        appState.toggleFocusedReviewItemSelection()
                    },
                    onOpen: {
                        appState.openFocusedReviewItem()
                    },
                    onSelectAll: {
                        appState.selectAllVisibleMedia()
                    },
                    onDeselectAll: {
                        appState.deselectAllVisibleMedia()
                    }
                )
                .frame(width: 1, height: 1)

                if appState.reviewPresentationMode == .grid {
                    reviewGrid
                } else {
                    reviewList
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.activateReviewGridFocus()
            }
        }
    }

    private var reviewToolbar: some View {
        HStack {
            Picker("View", selection: Binding(
                get: { appState.reviewPresentationMode },
                set: { appState.setReviewPresentationMode($0) }
            )) {
                Text("Grid").tag(ReviewPresentationMode.grid)
                Text("List").tag(ReviewPresentationMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            Button("Select All") {
                appState.selectAllVisibleMedia()
            }

            Button("Deselect") {
                appState.deselectAllVisibleMedia()
            }
            .disabled(appState.selectedMediaItemIDs.isEmpty)

            Button("Open") {
                appState.openFocusedReviewItem()
            }
            .disabled(appState.focusedReviewItem == nil)

            Button("Compare (C)") {
                appState.openComparisonForCurrentSelection()
            }
            .disabled(!appState.canOpenComparison)

            if appState.canMutateImportSelection {
                Button("Mark For Import (I)") {
                    appState.markCurrentSelectionForImport()
                }
                .disabled(!appState.canMarkSelectionForImport)

                Button("Unmark (D)") {
                    appState.unmarkCurrentSelectionForImport()
                }
                .disabled(!appState.canUnmarkSelectionForImport)

                Button("Toggle RAW (R)") {
                    appState.toggleRawForCurrentMediaSelection()
                }
                .disabled(!appState.canToggleRawForSelection)
            }
        }
    }

    private var reviewGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(appState.visibleMediaItems) { item in
                    ReviewGridCard(
                        item: item,
                        thumbnailURL: appState.thumbnailURL(for: item),
                        archivePreview: appState.archivePreview(for: item),
                        canMutateImportSelection: appState.canMutateImportSelection,
                        isSelected: appState.selectedMediaItemIDs.contains(item.id),
                        isFocused: appState.focusedReviewItemID == item.id,
                        thumbnailFailed: appState.thumbnailFailures.contains(item.id),
                        onTap: {
                            appState.handleGridSelection(for: item.id, modifiers: NSEvent.modifierFlags)
                        },
                        onDoubleTap: {
                            appState.handleGridSelection(for: item.id, modifiers: [])
                            appState.openFocusedReviewItem()
                        },
                        retryThumbnail: {
                            appState.requestThumbnail(for: item)
                        },
                        setIncludeRaw: { enabled in
                            if appState.canMutateImportSelection {
                                appState.setImportRawCompanions(for: item, enabled: enabled)
                            }
                        },
                        toggleImport: {
                            guard appState.canMutateImportSelection else { return }
                            appState.selectMediaItems([item.id])
                            if item.selectionState == .selected {
                                appState.unmarkCurrentSelectionForImport()
                            } else {
                                appState.markCurrentSelectionForImport()
                            }
                        }
                    )
                }
            }
            .padding(6)
        }
    }

    private var reviewColumnCount: Int {
        let width = NSScreen.main?.visibleFrame.width ?? 1200
        return max(1, Int((width - 380) / 236))
    }

    private var reviewList: some View {
        List(selection: Binding(
            get: { appState.selectedMediaItemIDs },
            set: { appState.selectMediaItems($0) }
        )) {
            ForEach(appState.visibleMediaItems) { item in
                MediaItemRow(
                    item: item,
                    thumbnailURL: appState.thumbnailURL(for: item),
                    archivePreview: appState.archivePreview(for: item),
                    canMutateImportSelection: appState.canMutateImportSelection,
                    isSelected: appState.selectedMediaItemIDs.contains(item.id),
                    isFocused: appState.focusedReviewItemID == item.id,
                    thumbnailFailed: appState.thumbnailFailures.contains(item.id),
                    toggleImport: {
                        guard appState.canMutateImportSelection else { return }
                        appState.selectMediaItems([item.id])
                        if item.selectionState == .selected {
                            appState.unmarkCurrentSelectionForImport()
                        } else {
                            appState.markCurrentSelectionForImport()
                        }
                    },
                    retryThumbnail: {
                        appState.requestThumbnail(for: item)
                    },
                    setIncludeRaw: { enabled in
                        if appState.canMutateImportSelection {
                            appState.setImportRawCompanions(for: item, enabled: enabled)
                        }
                    }
                )
                .tag(item.id)
            }
        }
        .onTapGesture {
            appState.activateReviewGridFocus()
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
