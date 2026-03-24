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
        if !appState.visibleMediaItems.isEmpty {
            DayContextPaneView(appState: appState)
        } else if !appState.detailFolderNodes.isEmpty {
            FolderBrowserPaneView(appState: appState)
        } else {
            ContentUnavailableView("No Content", systemImage: "folder", description: Text("Choose a source folder and browse by year, month, day, or grouping folders."))
        }
    }
}

struct DayContextPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Display", selection: Binding(
                    get: { appState.dayDetailDisplayMode },
                    set: { appState.setDayDetailDisplayMode($0) }
                )) {
                    ForEach(appState.availableDayDetailDisplayModes, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: appState.canUseGroupedReviewMode ? 260 : 130)

                Spacer()
            }

            if !appState.canUseGroupedReviewMode {
                Text("Grouped review is available when browsing a day or a folder with day sections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.canUseGroupedReviewMode && appState.dayDetailDisplayMode == .sections {
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
            }

            ReviewPaneView(appState: appState)
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

    private var isGroupedReviewMode: Bool {
        appState.shouldShowInlineDaySections && appState.dayDetailDisplayMode == .sections
    }

    private var reviewToolbar: some View {
        ViewThatFits(in: .horizontal) {
            fullReviewToolbar
            compactReviewToolbar
        }
    }

    private func reviewGrid(availableWidth: CGFloat) -> some View {
        let visibleItems = appState.visibleMediaItems
        let cardWidth = CGFloat(appState.reviewGridCardWidth)
        let spacing = CGFloat(ReviewGridMetrics.gridSpacing)
        let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing, alignment: .top), count: max(1, appState.reviewGridColumnCount))

        return ScrollView([.vertical, .horizontal]) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                ForEach(visibleItems) { item in
                    ReviewGridCard(
                        item: item,
                        thumbnailImage: appState.thumbnailImage(for: item),
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
                    .onAppear {
                        appState.requestThumbnail(for: item)
                    }
                }
            }
            .padding(CGFloat(ReviewGridMetrics.gridPadding))
        }
        .onAppear {
            appState.updateReviewGridMetrics(availableWidth: availableWidth)
        }
    }

    private func groupedReviewGrid(availableWidth: CGFloat) -> some View {
        let cardWidth = CGFloat(appState.reviewGridCardWidth)
        let spacing = CGFloat(ReviewGridMetrics.gridSpacing)
        let columns = Array(repeating: GridItem(.fixed(cardWidth), spacing: spacing, alignment: .top), count: max(1, appState.reviewGridColumnCount))

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(appState.organizedInlineSections) { section in
                        GroupedReviewSectionNodeView(
                            appState: appState,
                            section: section,
                            columns: columns,
                            cardWidth: cardWidth,
                            presentationMode: .grid
                        )
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
        .onAppear {
            appState.updateReviewGridMetrics(availableWidth: availableWidth)
        }
    }

    private var fullReviewToolbar: some View {
        HStack(spacing: 10) {
            reviewPresentationPicker
            sizeControls
            Spacer()
            primaryReviewButtons
            reviewActionsMenu
        }
    }

    private var compactReviewToolbar: some View {
        HStack(spacing: 8) {
            reviewPresentationPicker
            sizeControls
            Spacer()
            Button("Open") {
                appState.openFocusedReviewItem()
            }
            .disabled(appState.focusedReviewItem == nil)

            Button("Compare") {
                appState.openComparisonForCurrentSelection()
            }
            .disabled(!appState.canOpenComparison)

            reviewActionsMenu
        }
    }

    private var reviewPresentationPicker: some View {
        Picker("View", selection: Binding(
            get: { appState.reviewPresentationMode },
            set: { appState.setReviewPresentationMode($0) }
        )) {
            Text("Grid").tag(ReviewPresentationMode.grid)
            Text("List").tag(ReviewPresentationMode.list)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }

    private var sizeControls: some View {
        HStack(spacing: 6) {
            Button {
                appState.decreaseReviewGridCardWidth()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Make review cards smaller")
            .disabled(appState.reviewGridCardWidth <= ReviewGridMetrics.minCardWidth)

            Text("\(Int(appState.reviewGridCardWidth))")
                .font(.caption.monospacedDigit())
                .frame(width: 36)

            Button {
                appState.increaseReviewGridCardWidth()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Make review cards larger")
            .disabled(appState.reviewGridCardWidth >= ReviewGridMetrics.maxCardWidth)

            Button {
                appState.resetReviewGridCardWidth()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset review card size")
            .disabled(appState.reviewGridCardWidth == ReviewGridMetrics.defaultCardWidth)
        }
        .buttonStyle(.bordered)
    }

    private var primaryReviewButtons: some View {
        HStack(spacing: 8) {
            Button("Open") {
                appState.openFocusedReviewItem()
            }
            .disabled(appState.focusedReviewItem == nil)

            Button("Compare") {
                appState.openComparisonForCurrentSelection()
            }
            .disabled(!appState.canOpenComparison)
        }
    }

    private var reviewActionsMenu: some View {
        Menu("Actions") {
            Button("Select All") {
                appState.selectAllVisibleMedia()
            }

            Button("Deselect") {
                appState.deselectAllVisibleMedia()
            }
            .disabled(appState.selectedMediaItemIDs.isEmpty)

            if appState.canMutateImportSelection {
                Button("Mark For Import") {
                    appState.markCurrentSelectionForImport()
                }
                .disabled(!appState.canMarkSelectionForImport)

                Button("Unmark") {
                    appState.unmarkCurrentSelectionForImport()
                }
                .disabled(!appState.canUnmarkSelectionForImport)

                Button("Toggle RAW") {
                    appState.toggleRawForCurrentMediaSelection()
                }
                .disabled(!appState.canToggleRawForSelection)
            }
        }
    }

    private var reviewList: some View {
        let visibleItems = appState.visibleMediaItems
        return List(selection: Binding(
            get: { appState.selectedMediaItemIDs },
            set: { appState.selectMediaItems($0) }
        )) {
            ForEach(visibleItems) { item in
                MediaItemRow(
                    item: item,
                    thumbnailImage: appState.thumbnailImage(for: item),
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
                    ForEach(appState.organizedInlineSections) { section in
                        GroupedReviewSectionNodeView(
                            appState: appState,
                            section: section,
                            columns: [],
                            cardWidth: CGFloat(appState.reviewGridCardWidth),
                            presentationMode: .list
                        )
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
        .contentShape(Rectangle())
        .onTapGesture {
            appState.activateReviewGridFocus()
        }
    }
}

private struct GroupedReviewSectionNodeView: View {
    @ObservedObject var appState: AppState
    let section: InlineSection
    let columns: [GridItem]
    let cardWidth: CGFloat
    let presentationMode: ReviewPresentationMode

    private var hasChildren: Bool {
        !section.children.isEmpty
    }

    private var isExpanded: Bool {
        hasChildren ? appState.isInlineSectionExpanded(section.id) : true
    }

    private var directItemIDs: [UUID] {
        section.photoItemIDs.isEmpty && section.children.isEmpty ? section.mediaItemIDs : section.photoItemIDs
    }

    private var directItems: [MediaItem] {
        appState.orderedMediaItems(for: directItemIDs)
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
                        ForEach(directItems) { item in
                            reviewGridCard(for: item)
                                .id(item.id)
                        }
                    }
                    .padding(.leading, hasChildren ? 24 : 0)
                } else if !directItems.isEmpty {
                    ForEach(directItems) { item in
                        reviewListRow(for: item)
                            .id(item.id)
                    }
                    .padding(.leading, hasChildren ? 12 : 0)
                }

                ForEach(section.children) { child in
                    GroupedReviewSectionNodeView(
                        appState: appState,
                        section: child,
                        columns: columns,
                        cardWidth: cardWidth,
                        presentationMode: presentationMode
                    )
                    .padding(.leading, 16)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private var header: some View {
        HStack(spacing: 10) {
            if hasChildren {
                Button {
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
            } else {
                HStack(spacing: 8) {
                    Text(section.title)
                        .font(headerFont)
                    Text(sectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if canCompareSection {
                Button("Compare") {
                    appState.openComparison(for: compareItemIDs, title: "Compare \(section.title)")
                }
                .buttonStyle(.bordered)
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
        if directItemIDs.isEmpty && hasChildren {
            return "\(section.mediaItemIDs.count) grouped photo(s)"
        }
        return "\(directItemIDs.count) photo(s)"
    }

    private var canCompareSection: Bool {
        section.kind != .day && compareItemIDs.count >= 2
    }

    private func reviewGridCard(for item: MediaItem) -> some View {
        ReviewGridCard(
            item: item,
            thumbnailImage: appState.thumbnailImage(for: item),
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
        .onAppear {
            appState.requestThumbnail(for: item)
        }
    }

    private func reviewListRow(for item: MediaItem) -> some View {
        MediaItemRow(
            item: item,
            thumbnailImage: appState.thumbnailImage(for: item),
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
        .onAppear {
            appState.requestThumbnail(for: item)
        }
        .tag(item.id)
    }
}
