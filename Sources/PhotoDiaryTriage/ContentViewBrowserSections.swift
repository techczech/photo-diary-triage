import AppKit
import SwiftUI

struct HeaderPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
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
}

struct BrowserOrReviewPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if appState.shouldShowInlineDaySections {
            InlineDaySectionsPaneView(appState: appState)
        } else if !appState.detailFolderNodes.isEmpty {
            FolderBrowserPaneView(appState: appState)
        } else if !appState.visibleMediaItems.isEmpty {
            ReviewPaneView(appState: appState)
        } else {
            ContentUnavailableView("No Content", systemImage: "folder", description: Text("Choose a source folder and browse by year, month, day, or grouping folders."))
        }
    }
}

struct InlineDaySectionsPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
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
}

struct FolderBrowserPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
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
}

struct ReviewPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            reviewToolbar

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ReviewKeyInputView(
                        isFocused: appState.reviewGridHasFocus,
                        onArrow: { dx, dy, extending in
                            let columns = max(1, appState.reviewPresentationMode == .grid ? appState.reviewGridColumnCount : 1)
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
                        onEscape: {
                            appState.deactivateReviewGridFocus()
                        },
                        onSelectAll: {
                            appState.selectAllVisibleMedia()
                        },
                        onDeselectAll: {
                            appState.deselectAllVisibleMedia()
                        },
                        onZoomIn: {
                            appState.increaseReviewGridCardWidth()
                        },
                        onZoomOut: {
                            appState.decreaseReviewGridCardWidth()
                        },
                        onZoomReset: {
                            appState.resetReviewGridCardWidth()
                        }
                    )
                    .frame(width: 1, height: 1)

                    if appState.reviewPresentationMode == .grid {
                        reviewGrid(availableWidth: proxy.size.width)
                    } else {
                        reviewList
                    }
                }
                .onAppear {
                    appState.updateReviewGridMetrics(availableWidth: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, width in
                    appState.updateReviewGridMetrics(availableWidth: width)
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

            Divider()

            Button("Smaller") {
                appState.decreaseReviewGridCardWidth()
            }
            .disabled(appState.reviewGridCardWidth <= ReviewGridMetrics.minCardWidth)

            Text("\(Int(appState.reviewGridCardWidth)) pt")
                .font(.caption.monospacedDigit())
                .frame(width: 56, alignment: .center)

            Button("Larger") {
                appState.increaseReviewGridCardWidth()
            }
            .disabled(appState.reviewGridCardWidth >= ReviewGridMetrics.maxCardWidth)

            Button("Reset Size") {
                appState.resetReviewGridCardWidth()
            }
            .disabled(appState.reviewGridCardWidth == ReviewGridMetrics.defaultCardWidth)

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

    private func reviewGrid(availableWidth: CGFloat) -> some View {
        let cardWidth = CGFloat(appState.reviewGridCardWidth)
        let spacing = CGFloat(ReviewGridMetrics.gridSpacing)

        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth, maximum: cardWidth), spacing: spacing, alignment: .top)], alignment: .leading, spacing: spacing) {
                ForEach(appState.visibleMediaItems) { item in
                    ReviewGridCard(
                        item: item,
                        thumbnailURL: appState.thumbnailURL(for: item),
                        archivePreview: appState.archivePreview(for: item),
                        cardWidth: cardWidth,
                        canMutateImportSelection: appState.canMutateImportSelection,
                        isSelected: appState.selectedMediaItemIDs.contains(item.id),
                        isFocused: appState.focusedReviewItemID == item.id,
                        thumbnailFailed: appState.thumbnailFailures.contains(item.id),
                        onClick: { click in
                            appState.handleGridSelection(for: item.id, click: click)
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
            .padding(CGFloat(ReviewGridMetrics.gridPadding))
        }
        .onAppear {
            appState.updateReviewGridMetrics(availableWidth: availableWidth)
        }
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
}
