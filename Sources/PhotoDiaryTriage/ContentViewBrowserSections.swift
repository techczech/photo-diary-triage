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
                .shortcutHint("Cmd-Option-I", help: "\(appState.isDetailsInspectorVisible ? "Hide" : "Show") inspector (Cmd-Option-I)")
                Button("Keyboard Shortcuts") {
                    appState.showKeyboardHelp = true
                }
                .shortcutHint("Cmd-Shift-/", help: "Show keyboard shortcuts (Cmd-Shift-/)")
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
    let appState: AppState
    @ObservedObject var state: ReviewState
    @ObservedObject var navigationState: ReviewNavigationState

    var body: some View {
        if state.snapshot.contextMediaItemCount > 0 {
            DayContextPaneView(appState: appState, state: state, navigationState: navigationState)
        } else if !state.snapshot.detailFolderNodes.isEmpty {
            FolderBrowserPaneView(appState: appState, state: state)
        } else {
            ContentUnavailableView("No Content", systemImage: "folder", description: Text("Choose a source folder and browse by year, month, day, or grouping folders."))
        }
    }
}

struct DayContextPaneView: View {
    let appState: AppState
    @ObservedObject var state: ReviewState
    @ObservedObject var navigationState: ReviewNavigationState

    var body: some View {
        ReviewPaneView(appState: appState, state: state, navigationState: navigationState)
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
                .shortcutHint("Cmd-Ctrl-1..4", help: "Change grouped review organization (Cmd-Control-1 through Cmd-Control-4)")

                Spacer()

                Button("Expand All") {
                    appState.expandAllInlineSections()
                }
                .shortcutHint("Cmd-Option-]", help: "Expand all grouped sections (Cmd-Option-])")

                Button("Collapse All") {
                    appState.collapseAllInlineSections()
                }
                .shortcutHint("Cmd-Option-[", help: "Collapse all grouped sections (Cmd-Option-[)")
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
                        proxy.scrollTo(targetID, anchor: .center)
                        appState.pendingInlineScrollTargetID = nil
                    }
                }
            }
        }
    }
}

struct FolderBrowserPaneView: View {
    let appState: AppState
    @ObservedObject var state: ReviewState

    var body: some View {
        List(selection: Binding(
            get: { appState.selectedFolderNodeIDs },
            set: { appState.selectFolderNodes($0) }
        )) {
            ForEach(state.snapshot.detailFolderNodes) { node in
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
    let appState: AppState
    @ObservedObject var state: ReviewState
    @ObservedObject var navigationState: ReviewNavigationState

    var body: some View {
        let snapshot = state.snapshot
        let navigation = navigationState.snapshot

        VStack(alignment: .leading, spacing: 6) {
            compactReviewTopBar

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ReviewKeyInputView(
                        isFocused: navigation.reviewGridHasFocus,
                        onArrow: { dx, dy, extending in
                            appState.handleReviewArrowKey(dx: dx, dy: dy, extending: extending)
                        },
                        onSectionArrow: { dx, dy in
                            appState.handleGroupedSectionArrowKey(dx: dx, dy: dy)
                        },
                        onSectionExpandCollapse: { expand in
                            appState.handleGroupedSectionExpandCollapse(expand: expand)
                        },
                        onSingleKey: { key in
                            appState.performReviewShortcut(key)
                        },
                        onPan: nil,
                        onSpace: {
                            appState.toggleFocusedReviewItemSelection()
                        },
                        onOpen: {
                            appState.activateCurrentReviewTarget()
                        },
                        onCommandOpen: {
                            appState.openCurrentSelection()
                        },
                        onEscape: {
                            appState.handleReviewEscape()
                        },
                        onSelectAll: {
                            appState.selectAllVisibleMedia()
                        },
                        onDeselectAll: {
                            appState.deselectAllVisibleMedia()
                        },
                        onZoomIn: {
                            appState.increaseReviewGridColumnCount()
                        },
                        onZoomOut: {
                            appState.decreaseReviewGridColumnCount()
                        },
                        onZoomReset: {
                            appState.resetReviewGridColumnCount()
                        },
                        onToggleSidebar: {
                            appState.toggleSidebarVisibility()
                        },
                        onToggleInspector: {
                            appState.toggleDetailsInspector()
                        }
                    )
                    .frame(width: 1, height: 1)

                    if snapshot.visibleItems.isEmpty {
                        reviewFilterEmptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if snapshot.reviewPresentationMode == .grid {
                        if isGroupedReviewMode {
                            groupedReviewGrid(availableWidth: proxy.size.width)
                        } else {
                            reviewGrid(availableWidth: proxy.size.width)
                        }
                    } else {
                        if isGroupedReviewMode {
                            groupedReviewList
                        } else {
                            reviewList
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .onAppear {
                    appState.updateReviewGridMetrics(
                        availableWidth: proxy.size.width,
                        availableHeight: proxy.size.height
                    )
                }
                .onChange(of: proxy.size) { _, size in
                    appState.updateReviewGridMetrics(
                        availableWidth: size.width,
                        availableHeight: size.height
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.activateReviewGridFocus()
            }
        }
    }

    private var isGroupedReviewMode: Bool {
        state.snapshot.canUseGroupedReviewMode && state.snapshot.dayDetailDisplayMode == .sections
    }

    private var reviewFilterEmptyState: some View {
        ContentUnavailableView(
            "No \(state.snapshot.reviewFilter.title.lowercased()) photos",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("Change the review filter or update triage states to see items in this view.")
        )
    }

    @ViewBuilder
    private var compactReviewTopBar: some View {
        if state.snapshot.contextMediaItemCount > 0 {
            HStack(alignment: .center, spacing: 8) {
                Text(state.snapshot.breadcrumbTitles.joined(separator: " / "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 140, maxWidth: 240, alignment: .leading)

                if navigationState.snapshot.reviewGridHasFocus {
                    Text("Review Focus")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                }

                Spacer(minLength: 6)

                detailDisplayMenu

                if state.snapshot.canUseGroupedReviewMode && state.snapshot.dayDetailDisplayMode == .sections {
                    groupedOrganizationMenu
                }

                reviewFilterMenu
                reviewPresentationMenu
                sizeControls
                reviewActionsMenu

                if state.snapshot.canUseGroupedReviewMode && state.snapshot.dayDetailDisplayMode == .sections {
                    groupedSectionButtons
                }

                if !state.snapshot.selectedMediaItemIDs.isEmpty {
                    Text("\(state.snapshot.selectedMediaItemIDs.count) selected")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailDisplayMenu: some View {
        Menu {
            ForEach(state.snapshot.availableDayDetailDisplayModes, id: \.self) { mode in
                Button(mode.title) {
                    appState.setDayDetailDisplayMode(mode)
                    returnToReviewFocus()
                }
            }
        } label: {
            Label(state.snapshot.dayDetailDisplayMode == .sections ? "Grouped" : "Flat", systemImage: "rectangle.grid.2x2")
        }
        .shortcutHint("Cmd-3 / Cmd-4", help: "Switch between flat review and grouped review (Cmd-3 / Cmd-4)")
    }

    private var groupedOrganizationMenu: some View {
        Menu {
            ForEach(DayOrganizationMode.allCases, id: \.self) { mode in
                Button(mode.title) {
                    appState.setDayOrganizationMode(mode)
                    returnToReviewFocus()
                }
            }
        } label: {
            Label(compactOrganizationTitle(state.snapshot.dayOrganizationMode), systemImage: "calendar")
        }
        .shortcutHint("Cmd-Ctrl-1..4", help: "Change grouped review organization (Cmd-Control-1 through Cmd-Control-4)")
    }

    private var reviewFilterMenu: some View {
        Menu {
            ForEach(ReviewFilter.allCases, id: \.self) { filter in
                Button(filter.title) {
                    appState.setReviewFilter(filter)
                    returnToReviewFocus()
                }
            }
        } label: {
            Label("Filter: \(state.snapshot.reviewFilter.title)", systemImage: "line.3.horizontal.decrease.circle")
        }
        .shortcutHint("Cmd-Ctrl-A / I / C / X / U", help: "Filter review items to all, included, candidate, excluded, or undecided photos.")
    }

    private var reviewPresentationMenu: some View {
        Menu {
            ForEach(ReviewPresentationMode.allCases, id: \.self) { mode in
                Button(mode.rawValue.capitalized) {
                    appState.setReviewPresentationMode(mode)
                    returnToReviewFocus()
                }
            }
        } label: {
            Label(state.snapshot.reviewPresentationMode.rawValue.capitalized, systemImage: state.snapshot.reviewPresentationMode == .grid ? "square.grid.3x3" : "list.bullet")
        }
        .shortcutHint("Cmd-Option-G / L", help: "Switch between grid and list layout (Cmd-Option-G / Cmd-Option-L)")
    }

    private var sizeControls: some View {
        HStack(spacing: 6) {
            Button {
                appState.decreaseReviewGridColumnCount()
                returnToReviewFocus()
            } label: {
                Image(systemName: "minus")
            }
            .shortcutHint("-", help: "Show fewer review columns (-)")
            .disabled(state.snapshot.reviewGridPreferredColumnCount <= 1)

            Text("\(state.snapshot.reviewGridPreferredColumnCount)")
                .font(.caption.monospacedDigit())
                .frame(width: 28)

            Button {
                appState.increaseReviewGridColumnCount()
                returnToReviewFocus()
            } label: {
                Image(systemName: "plus")
            }
            .shortcutHint("+", help: "Show more review columns (+)")
            .disabled(state.snapshot.reviewGridPreferredColumnCount >= ReviewGridMetrics.maxSuggestedColumns)

            Button {
                appState.resetReviewGridColumnCount()
                returnToReviewFocus()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .shortcutHint("0", help: "Reset review columns (0)")
            .disabled(state.snapshot.reviewGridPreferredColumnCount == ReviewGridMetrics.defaultRequestedColumnCount())
        }
        .buttonStyle(.bordered)
    }

    private var reviewActionsMenu: some View {
        Menu("Actions") {
            Button("Select All") {
                appState.selectAllVisibleMedia()
                returnToReviewFocus()
            }

            Button("Deselect") {
                appState.deselectAllVisibleMedia()
                returnToReviewFocus()
            }
            .disabled(state.snapshot.selectedMediaItemIDs.isEmpty)

            if state.snapshot.canMutateImportSelection {
                Divider()

                Button("Select For Import") {
                    appState.markCurrentSelectionForImport()
                    returnToReviewFocus()
                }
                .disabled(!state.snapshot.canMarkSelectionForImport)

                Button("Mark As Candidate") {
                    appState.markCurrentSelectionAsCandidate()
                    returnToReviewFocus()
                }
                .disabled(!state.snapshot.canMarkSelectionAsCandidate)

                Button("Exclude From Import") {
                    appState.excludeCurrentSelectionFromImport()
                    returnToReviewFocus()
                }
                .disabled(!state.snapshot.canExcludeSelectionFromImport)

                Button("Clear To Undecided") {
                    appState.unmarkCurrentSelectionForImport()
                    returnToReviewFocus()
                }
                .disabled(!state.snapshot.canUnmarkSelectionForImport)

                Button("Toggle RAW") {
                    appState.toggleRawForCurrentMediaSelection()
                    returnToReviewFocus()
                }
                .disabled(!state.snapshot.canToggleRawForSelection)
            }
        }
        .help("Selection and import actions")
    }

    private var groupedSectionButtons: some View {
        HStack(spacing: 6) {
            Button {
                appState.expandAllInlineSections()
                returnToReviewFocus()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Expand all groups")
            .shortcutHint("Cmd-Option-]", help: "Expand all grouped sections (Cmd-Option-])")

            Button {
                appState.collapseAllInlineSections()
                returnToReviewFocus()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Collapse all groups")
            .shortcutHint("Cmd-Option-[", help: "Collapse all grouped sections (Cmd-Option-[)")
        }
        .buttonStyle(.bordered)
    }

    private func returnToReviewFocus() {
        guard state.snapshot.canFocusReviewSurface else { return }
        DispatchQueue.main.async {
            appState.activateReviewGridFocus()
        }
    }

    private func compactOrganizationTitle(_ mode: DayOrganizationMode) -> String {
        switch mode {
        case .days:
            return "Days"
        case .daysAndBursts:
            return "Days/Bursts"
        case .daysAndClusters:
            return "Days/Clusters"
        case .daysClustersAndBursts:
            return "Days/Clusters/Bursts"
        }
    }

    private func reviewGrid(availableWidth: CGFloat) -> some View {
        let visibleItems = state.snapshot.visibleItems
        let cardWidth = CGFloat(state.snapshot.reviewGridCardWidth)
        let spacing = CGFloat(ReviewGridMetrics.gridSpacing)
        let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing, alignment: .top), count: max(1, state.snapshot.reviewGridColumnCount))

        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(visibleItems) { snapshot in
                        let item = snapshot.item
                        ReviewGridCard(
                            appState: appState,
                            snapshot: snapshot,
                            cardWidth: cardWidth,
                            canMutateImportSelection: state.snapshot.canMutateImportSelection,
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
                            includeForImport: {
                                guard appState.canMutateImportSelection else { return }
                                appState.selectMediaItems([item.id])
                                appState.markCurrentSelectionForImport()
                            },
                            markAsCandidate: {
                                guard appState.canMutateImportSelection else { return }
                                appState.selectMediaItems([item.id])
                                appState.markCurrentSelectionAsCandidate()
                            },
                            excludeFromImport: {
                                guard appState.canMutateImportSelection else { return }
                                appState.selectMediaItems([item.id])
                                appState.excludeCurrentSelectionFromImport()
                            },
                            clearTriageState: {
                                guard appState.canMutateImportSelection else { return }
                                appState.selectMediaItems([item.id])
                                appState.unmarkCurrentSelectionForImport()
                            }
                        )
                        .id(item.id)
                        .onAppear {
                            appState.requestThumbnail(for: item)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CGFloat(ReviewGridMetrics.gridPadding))
            }
            .clipped()
            .onChange(of: navigationState.snapshot.pendingReviewScrollTargetID) { _, targetID in
                guard let targetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .center)
                    appState.pendingReviewScrollTargetID = nil
                    appState.endLatencyMeasurement("review.scroll")
                }
            }
        }
        .onAppear {
            appState.updateReviewGridMetrics(availableWidth: availableWidth)
        }
    }

    private func groupedReviewGrid(availableWidth: CGFloat) -> some View {
        let cardWidth = CGFloat(state.snapshot.reviewGridCardWidth)
        let spacing = CGFloat(ReviewGridMetrics.gridSpacing)
        let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing, alignment: .top), count: max(1, state.snapshot.reviewGridColumnCount))

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(state.snapshot.organizedInlineSections) { section in
                        GroupedReviewSectionNodeView(
                            appState: appState,
                            state: state,
                            section: section,
                            columns: columns,
                            cardWidth: cardWidth,
                            presentationMode: .grid
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: navigationState.snapshot.pendingInlineScrollTargetID) { _, targetID in
                guard let targetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .center)
                    appState.pendingInlineScrollTargetID = nil
                }
            }
            .onChange(of: navigationState.snapshot.pendingReviewScrollTargetID) { _, targetID in
                guard let targetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .center)
                    appState.pendingReviewScrollTargetID = nil
                    appState.endLatencyMeasurement("review.scroll")
                }
            }
            .onAppear {
                guard let targetID = navigationState.snapshot.pendingInlineSectionScrollTargetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .top)
                    appState.pendingInlineSectionScrollTargetID = nil
                }
            }
            .onChange(of: navigationState.snapshot.pendingInlineSectionScrollRevision) { _, _ in
                guard let targetID = navigationState.snapshot.pendingInlineSectionScrollTargetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .top)
                    appState.pendingInlineSectionScrollTargetID = nil
                }
            }
        }
        .onAppear {
            appState.updateReviewGridMetrics(availableWidth: availableWidth)
        }
    }

    private var reviewList: some View {
        let visibleItems = state.snapshot.visibleItems
        return List(selection: Binding(
            get: { state.snapshot.selectedMediaItemIDs },
            set: { appState.selectMediaItems($0) }
        )) {
            ForEach(visibleItems) { snapshot in
                let item = snapshot.item
                MediaItemRow(
                    appState: appState,
                    snapshot: snapshot,
                    canMutateImportSelection: state.snapshot.canMutateImportSelection,
                    includeForImport: {
                        guard state.snapshot.canMutateImportSelection else { return }
                        appState.selectMediaItems([item.id])
                        appState.markCurrentSelectionForImport()
                    },
                    markAsCandidate: {
                        guard state.snapshot.canMutateImportSelection else { return }
                        appState.selectMediaItems([item.id])
                        appState.markCurrentSelectionAsCandidate()
                    },
                    excludeFromImport: {
                        guard state.snapshot.canMutateImportSelection else { return }
                        appState.selectMediaItems([item.id])
                        appState.excludeCurrentSelectionFromImport()
                    },
                    clearTriageState: {
                        guard state.snapshot.canMutateImportSelection else { return }
                        appState.selectMediaItems([item.id])
                        appState.unmarkCurrentSelectionForImport()
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
                .onAppear {
                    appState.requestThumbnail(for: item)
                }
                .tag(item.id)
            }
        }
        .onTapGesture {
            appState.activateReviewGridFocus()
        }
    }

    private var groupedReviewList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(state.snapshot.organizedInlineSections) { section in
                        GroupedReviewSectionNodeView(
                            appState: appState,
                            state: state,
                            section: section,
                            columns: [],
                            cardWidth: CGFloat(state.snapshot.reviewGridCardWidth),
                            presentationMode: .list
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: navigationState.snapshot.pendingInlineScrollTargetID) { _, targetID in
                guard let targetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .center)
                    appState.pendingInlineScrollTargetID = nil
                }
            }
            .onChange(of: navigationState.snapshot.pendingReviewScrollTargetID) { _, targetID in
                guard let targetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .center)
                    appState.pendingReviewScrollTargetID = nil
                    appState.endLatencyMeasurement("review.scroll")
                }
            }
            .onAppear {
                guard let targetID = navigationState.snapshot.pendingInlineSectionScrollTargetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .top)
                    appState.pendingInlineSectionScrollTargetID = nil
                }
            }
            .onChange(of: navigationState.snapshot.pendingInlineSectionScrollRevision) { _, _ in
                guard let targetID = navigationState.snapshot.pendingInlineSectionScrollTargetID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(targetID, anchor: .top)
                    appState.pendingInlineSectionScrollTargetID = nil
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            appState.activateReviewGridFocus()
        }
    }
}

private struct GroupedReviewSectionNodeView: View {
    let appState: AppState
    @ObservedObject var state: ReviewState
    let section: InlineSection
    let columns: [GridItem]
    let cardWidth: CGFloat
    let presentationMode: ReviewPresentationMode

    private var isCollapsible: Bool {
        !section.mediaItemIDs.isEmpty
    }

    private var isExpanded: Bool {
        appState.isInlineSectionExpanded(section.id)
    }

    private var directItemIDs: [UUID] {
        section.photoItemIDs.isEmpty && section.children.isEmpty ? section.mediaItemIDs : section.photoItemIDs
    }

    private var directItems: [ReviewItemSnapshot] {
        directItemIDs.compactMap { state.snapshot.itemSnapshotsByID[$0] }
    }

    private var compareItemIDs: [UUID] {
        section.mediaItemIDs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                if presentationMode == .grid, !directItems.isEmpty {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: CGFloat(ReviewGridMetrics.gridSpacing)) {
                        ForEach(directItems) { snapshot in
                            reviewGridCard(for: snapshot)
                                .id(snapshot.id)
                        }
                    }
                    .padding(.leading, !section.children.isEmpty ? 24 : 0)
                } else if !directItems.isEmpty {
                    ForEach(directItems) { snapshot in
                        reviewListRow(for: snapshot)
                            .id(snapshot.id)
                    }
                    .padding(.leading, !section.children.isEmpty ? 12 : 0)
                }

                ForEach(section.children) { child in
                    GroupedReviewSectionNodeView(
                        appState: appState,
                        state: state,
                        section: child,
                        columns: columns,
                        cardWidth: cardWidth,
                        presentationMode: presentationMode
                    )
                    .padding(.leading, 16)
                }
            }
        }
        .id(section.id)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(state.snapshot.focusedInlineSectionID == section.id ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if isCollapsible {
                Button {
                    appState.focusInlineSection(section.id, scrollIntoView: false)
                    appState.toggleInlineSectionExpansion(section.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                        Text(section.title)
                            .font(headerFont)
                        Text(sectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .shortcutHint("Up / Down / Left / Right", help: isExpanded ? "Collapse this group. When the group header is focused, use Left Arrow to collapse and Up or Down to move between groups." : "Expand this group. When the group header is focused, use Right Arrow to expand and Up or Down to move between groups.")
            } else {
                HStack(spacing: 8) {
                    Text(section.title)
                        .font(headerFont)
                    Text(sectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.focusInlineSection(section.id, scrollIntoView: false)
                }
                .shortcutHint("Up / Down / Left / Right", help: "Focus this group for keyboard navigation. Use Up or Down to move between groups and Left or Right to collapse or expand.")
            }

            Spacer()

            if canCompareSection {
                Button("Compare") {
                    appState.openComparison(for: compareItemIDs, title: "Compare \(section.title)")
                }
                .buttonStyle(.bordered)
                .help("Compare all photos in this group")
            }
        }
    }

    private var headerFont: Font {
        switch section.kind {
        case .day:
            return .headline
        case .cluster, .burst, .remainder:
            return .subheadline.weight(.semibold)
        }
    }

    private var sectionSummary: String {
        if directItemIDs.isEmpty && !section.children.isEmpty {
            return "\(section.mediaItemIDs.count) grouped photo(s)"
        }
        return "\(directItemIDs.count) photo(s)"
    }

    private var canCompareSection: Bool {
        section.kind != .day && compareItemIDs.count >= 2
    }

    private func reviewGridCard(for snapshot: ReviewItemSnapshot) -> some View {
        let item = snapshot.item
        return ReviewGridCard(
            appState: appState,
            snapshot: snapshot,
            cardWidth: cardWidth,
            canMutateImportSelection: state.snapshot.canMutateImportSelection,
            onClick: { click in
                appState.handleGridSelection(for: item.id, click: click)
            },
            retryThumbnail: {
                appState.requestThumbnail(for: item)
            },
            setIncludeRaw: { enabled in
                if state.snapshot.canMutateImportSelection {
                    appState.setImportRawCompanions(for: item, enabled: enabled)
                }
            },
            includeForImport: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.markCurrentSelectionForImport()
            },
            markAsCandidate: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.markCurrentSelectionAsCandidate()
            },
            excludeFromImport: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.excludeCurrentSelectionFromImport()
            },
            clearTriageState: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.unmarkCurrentSelectionForImport()
            }
        )
    }

    private func reviewListRow(for snapshot: ReviewItemSnapshot) -> some View {
        let item = snapshot.item
        return MediaItemRow(
            appState: appState,
            snapshot: snapshot,
            canMutateImportSelection: state.snapshot.canMutateImportSelection,
            includeForImport: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.markCurrentSelectionForImport()
            },
            markAsCandidate: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.markCurrentSelectionAsCandidate()
            },
            excludeFromImport: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.excludeCurrentSelectionFromImport()
            },
            clearTriageState: {
                guard state.snapshot.canMutateImportSelection else { return }
                appState.selectMediaItems([item.id])
                appState.unmarkCurrentSelectionForImport()
            },
            retryThumbnail: {
                appState.requestThumbnail(for: item)
            },
            setIncludeRaw: { enabled in
                if state.snapshot.canMutateImportSelection {
                    appState.setImportRawCompanions(for: item, enabled: enabled)
                }
            }
        )
        .tag(item.id)
    }
}
