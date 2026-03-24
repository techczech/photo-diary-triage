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
            sidebarPane
        } detail: {
            detailPane
        }
    }

    private var sidebarPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Choose SSD Source Folder") {
                    appState.pickSourceFolder()
                }
                Spacer()
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }

            if let session = appState.currentSession {
                GroupBox("Session") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.sourceFolder.path)
                            .font(.caption)
                            .textSelection(.enabled)
                        Text("\(session.mediaItems.count) visible items")
                        Text("\(session.mediaItems.filter { $0.selectionState == .selected }.count) marked for import")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox("Archive Root") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.settings.archiveRootDisplayPath)
                        .font(.caption)
                        .textSelection(.enabled)
                    if appState.archiveYearFolders.isEmpty {
                        Text("No `202x` folders detected yet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Years: \(appState.archiveYearFolders.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            List(appState.browserRoots, children: \.children, selection: Binding(
                get: { appState.selectedSidebarNodeID },
                set: { appState.selectSidebarNode($0) }
            )) { node in
                SidebarNodeRow(node: node)
            }
            .listStyle(.sidebar)
        }
        .padding()
        .frame(minWidth: 300)
    }

    private var detailPane: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                headerPane
                walkDetailsPane
                browserOrReviewPane
                actionButtonsPane
                footerPane
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

    @ViewBuilder
    private var walkDetailsPane: some View {
        if appState.canMutateImportSelection {
            DisclosureGroup(isExpanded: $appState.isWalkDetailsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Walk title", text: $walkTitle)
                    TextField("Location", text: $walkLocation)
                    TextField("Notes", text: $walkNotes, axis: .vertical)
                        .lineLimit(4...8)
                    Button("Save Walk Metadata") {
                        appState.updateWalkMetadata(title: walkTitle, location: walkLocation, notes: walkNotes)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Walk Details")
                        .font(.headline)
                    Text(walkDetailsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var actionButtonsPane: some View {
        Group {
            if appState.canMutateImportSelection {
                HStack {
                    Button("Copy Marked Files Into Archive") {
                        appState.commitImport()
                    }
                    .disabled(appState.currentSession?.mediaItems.allSatisfy { $0.selectionState == .skipped } ?? true)

                    Button("Confirm Backup And Enable Cleanup") {
                        appState.markBackupConfirmed()
                    }
                    .disabled(appState.currentSession?.walkMetadata.backupConfirmedAt != nil)

                    Button("Clean Imported Files From Source SSD") {
                        appState.cleanupImportedSources()
                    }
                    .disabled(!(appState.currentSession?.mediaItems.contains { $0.lifecycleState == .sourceCleanupPending } ?? false))
                }
            }
        }
    }

    private var footerPane: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(appRelease.displayString)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(.primary)
                .background(Color.accentColor.opacity(0.18), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                }

            Text(appState.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let progress = appState.importProgress {
                Text("\(progress.current)/\(progress.total)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

private struct InspectorCollapsedRail: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            Button {
                appState.toggleDetailsInspector()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.headline)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .help("Show Inspector")

            Text("Inspector")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(90))
                .frame(height: 80)

            Spacer()
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct DetailsInspectorView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Inspector")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Close") {
                        appState.toggleDetailsInspector()
                    }
                }

                folderSection
                photoSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var folderSection: some View {
        GroupBox("Current Folder") {
            VStack(alignment: .leading, spacing: 8) {
                if let node = appState.inspectorBrowserNode {
                    inspectorRow("Name", node.title)
                    inspectorRow("Kind", kindLabel(node.kind))
                    inspectorRow("Photos", "\(node.mediaItemIDs.count)")
                    inspectorRow("Children", "\(node.children?.count ?? 0)")
                    if let subtitle = node.subtitle?.nonEmpty {
                        inspectorRow("Summary", subtitle)
                    }
                    if let folderURL = node.folderURL {
                        inspectorRow("Path", folderURL.path)
                    } else if node.kind == .sessionRoot, let session = appState.currentSession {
                        inspectorRow("Path", session.sourceFolder.path)
                    }
                    if let session = appState.currentSession {
                        if let title = session.walkMetadata.title.nonEmpty {
                            inspectorRow("Walk Title", title)
                        }
                        if let location = session.walkMetadata.location.nonEmpty {
                            inspectorRow("Location", location)
                        }
                    }
                } else {
                    Text("No folder selected.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        GroupBox("Selected Photo") {
            VStack(alignment: .leading, spacing: 8) {
                if let item = appState.inspectorMediaItem {
                    if let image = NSImage(contentsOf: appState.thumbnailURL(for: item)) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    inspectorRow("File", item.fileName)
                    inspectorRow("Relative Path", item.relativePath)
                    inspectorRow("Size", ByteCountFormatter.string(fromByteCount: item.fileSizeBytes, countStyle: .file))
                    inspectorRow("State", item.selectionState.rawValue)
                    inspectorRow("Lifecycle", item.lifecycleState.rawValue)

                    if let capturedAt = item.capturedAt {
                        inspectorRow("Captured", DateFormatting.iso8601.string(from: capturedAt))
                    }
                    if let width = item.metadata.pixelWidth, let height = item.metadata.pixelHeight {
                        inspectorRow("Dimensions", "\(width) × \(height)")
                    }
                    if let camera = item.metadata.cameraModel?.nonEmpty {
                        inspectorRow("Camera", camera)
                    }
                    if let lens = item.metadata.lensModel?.nonEmpty {
                        inspectorRow("Lens", lens)
                    }
                    if let latitude = item.metadata.latitude, let longitude = item.metadata.longitude {
                        inspectorRow("Coordinates", String(format: "%.5f, %.5f", latitude, longitude))
                    }
                    if !item.companionFiles.isEmpty {
                        inspectorRow("RAW Companions", "\(item.companionFiles.count)")
                    }
                } else {
                    Text("Select a photo to inspect its metadata.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private func kindLabel(_ kind: BrowserNodeKind) -> String {
        switch kind {
        case .sessionSection:
            return "Session Section"
        case .archiveSection:
            return "Archive Section"
        case .sessionRoot:
            return "Session Root"
        case .archiveRoot:
            return "Archive Root"
        case .year:
            return "Year"
        case .month:
            return "Month"
        case .day:
            return "Day"
        case .unknownDate:
            return "Unknown Date"
        case .photosFolder:
            return "Photos"
        case .burstsFolder:
            return "Bursts"
        case .timeClustersFolder:
            return "Time Clusters"
        case .burstGroup:
            return "Burst"
        case .timeCluster:
            return "Time Cluster"
        case .archiveWalkFolder:
            return "Archive Walk Folder"
        }
    }
}

private struct SidebarNodeRow: View {
    let node: BrowserNode

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: iconName)
        }
    }

    private var iconName: String {
        switch node.kind {
        case .sessionSection:
            return "square.stack"
        case .archiveSection:
            return "books.vertical"
        case .sessionRoot:
            return "externaldrive"
        case .archiveRoot:
            return "archivebox"
        case .archiveWalkFolder:
            return "photo.on.rectangle"
        case .year, .month, .day, .unknownDate, .photosFolder, .burstsFolder, .timeClustersFolder:
            return "folder"
        case .burstGroup, .timeCluster:
            return "folder.badge.person.crop"
        }
    }
}

private struct FolderNodeRow: View {
    let node: BrowserNode

    var body: some View {
        HStack {
            Image(systemName: "folder")
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ReviewGridCard: View {
    let item: MediaItem
    let thumbnailURL: URL
    let archivePreview: String
    let canMutateImportSelection: Bool
    let isSelected: Bool
    let isFocused: Bool
    let thumbnailFailed: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let retryThumbnail: () -> Void
    let setIncludeRaw: (Bool) -> Void
    let toggleImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            thumbnail
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(item.selectionState == .selected ? "Marked" : "Not Marked")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.selectionState == .selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(item.relativePath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let capturedAt = item.capturedAt {
                Text(DateFormatting.iso8601.string(from: capturedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if canMutateImportSelection && !item.companionFiles.isEmpty {
                Toggle("Import RAW sidecar\(item.companionFiles.count == 1 ? "" : "s") too", isOn: Binding(
                    get: { item.importRawCompanions },
                    set: setIncludeRaw
                ))
                .toggleStyle(.checkbox)
            }

            HStack {
                if canMutateImportSelection {
                    Button(item.selectionState == .selected ? "Unmark (D)" : "Mark (I)", action: toggleImport)
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }

            if item.selectionState == .selected, !archivePreview.isEmpty {
                Text(archivePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectionStrokeColor, lineWidth: selectionStrokeWidth)
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .padding(6)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: onTap)
        .onTapGesture(count: 2, perform: onDoubleTap)
    }

    private var selectionStrokeColor: Color {
        if isSelected || isFocused {
            return Color.accentColor
        }
        return Color.clear
    }

    private var selectionStrokeWidth: CGFloat {
        isSelected ? 4 : (isFocused ? 3 : 0)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = NSImage(contentsOf: thumbnailURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else if thumbnailFailed {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Button("Retry", action: retryThumbnail)
                    }
                }
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
        }
    }
}

private struct MediaItemRow: View {
    let item: MediaItem
    let thumbnailURL: URL
    let archivePreview: String
    let canMutateImportSelection: Bool
    let isSelected: Bool
    let isFocused: Bool
    let thumbnailFailed: Bool
    let toggleImport: () -> Void
    let retryThumbnail: () -> Void
    let setIncludeRaw: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.fileName)
                            .font(.headline)
                        Spacer()
                        Text(item.selectionState == .selected ? "Marked" : "Not Marked")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(item.selectionState == .selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(item.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let capturedAt = item.capturedAt {
                        Text(DateFormatting.iso8601.string(from: capturedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if canMutateImportSelection && !item.companionFiles.isEmpty {
                        Toggle("Import RAW sidecar\(item.companionFiles.count == 1 ? "" : "s") too", isOn: Binding(
                            get: { item.importRawCompanions },
                            set: setIncludeRaw
                        ))
                        .toggleStyle(.checkbox)
                    }
                }
            }

            HStack {
                if canMutateImportSelection {
                    Button(item.selectionState == .selected ? "Unmark (D)" : "Mark (I)", action: toggleImport)
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }

            if item.selectionState == .selected, !archivePreview.isEmpty {
                Text(archivePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected || isFocused ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3 : (isFocused ? 2 : 0))
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.08)
        }
        if isFocused {
            return Color.accentColor.opacity(0.04)
        }
        return Color.clear
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = NSImage(contentsOf: thumbnailURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else if thumbnailFailed {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                        Button("Retry", action: retryThumbnail)
                            .buttonStyle(.borderless)
                    }
                }
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
        }
    }
}

private struct InlineSectionNodeView: View {
    @ObservedObject var appState: AppState
    let section: InlineSection
    let sectionPath: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                appState.toggleInlineSectionExpansion(section.id)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: appState.isInlineSectionExpanded(section.id) ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                    Text(section.title)
                        .font(headerFont)
                    Text("\(section.mediaItemIDs.count) photo(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TinyPreviewStrip(
                items: appState.previewItems(for: section),
                appState: appState,
                onSelectItem: { itemID in
                    appState.revealInlineMediaItem(itemID, sectionPath: sectionPath)
                }
            )

            if appState.isInlineSectionExpanded(section.id) {
                if !section.children.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(section.children) { child in
                            InlineSectionNodeView(
                                appState: appState,
                                section: child,
                                sectionPath: sectionPath + [child.id]
                            )
                        }
                    }
                }

                if !section.photoItemIDs.isEmpty {
                    InlinePhotoGrid(items: appState.mediaItems(for: section.photoItemIDs), appState: appState)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var headerFont: Font {
        switch section.kind {
        case .day:
            return .headline
        case .cluster, .burst, .remainder:
            return .subheadline.weight(.semibold)
        }
    }
}

private struct TinyPreviewStrip: View {
    let items: [MediaItem]
    @ObservedObject var appState: AppState
    let onSelectItem: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.prefix(18))) { item in
                    Button {
                        onSelectItem(item.id)
                    } label: {
                        tinyThumb(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func tinyThumb(for item: MediaItem) -> some View {
        if let image = NSImage(contentsOf: appState.thumbnailURL(for: item)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 70, height: 48)
        }
    }
}

private struct InlinePhotoGrid: View {
    let items: [MediaItem]
    @ObservedObject var appState: AppState

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    if let image = NSImage(contentsOf: appState.thumbnailURL(for: item)) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .frame(height: 76)
                    }
                    Text(item.fileName)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(appState.selectedMediaItemIDs.contains(item.id) ? Color.accentColor.opacity(0.10) : Color.clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(appState.selectedMediaItemIDs.contains(item.id) ? Color.accentColor : Color.clear, lineWidth: 2)
                }
                .overlay(
                    InlineGridClickTarget(
                        onSingleClick: {
                            appState.selectInlineMediaItem(item.id)
                        },
                        onDoubleClick: {
                            appState.selectInlineMediaItem(item.id)
                            appState.openFocusedReviewItem()
                        }
                    )
                )
                .id(item.id)
            }
        }
    }
}

private struct InlineGridClickTarget: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> InlineGridClickView {
        let view = InlineGridClickView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: InlineGridClickView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

private final class InlineGridClickView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            onSingleClick?()
        }
    }
}

private struct KeyboardHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            shortcut("I", "Mark selected photos for import when the review grid is focused")
            shortcut("D", "Unmark selected photos when the review grid is focused")
            shortcut("R", "Toggle RAW companion import when the review grid is focused")
            shortcut("S", "Select only the focused photo when the review grid is focused")
            shortcut("A", "Select all visible photos when the review grid is focused")
            shortcut("Space", "Toggle focused photo selection")
            shortcut("Arrow Keys", "Move grid focus; hold Shift to extend selection")
            shortcut("Return", "Open focused photo preview")
            shortcut("C", "Open side-by-side compare for the current photo selection")
            shortcut("+ / - / 0", "Zoom in, zoom out, or reset zoom inside full-photo and compare views")
            shortcut("Cmd-O", "Choose source folder")
            shortcut("Cmd-I", "Mark current selection for import")
            shortcut("Cmd-Shift-I", "Remove current selection from import")
            shortcut("Cmd-Option-R", "Toggle RAW companion import for selected photos")
            shortcut("Cmd-Shift-C", "Open compare from the menu command path")
            shortcut("Cmd-Shift-/", "Show this shortcuts panel")

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 320)
    }

    private func shortcut(_ key: String, _ description: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .frame(width: 150, alignment: .leading)
            Text(description)
            Spacer()
        }
    }
}

private struct ReviewKeyInputView: NSViewRepresentable {
    let isFocused: Bool
    let onArrow: (_ dx: Int, _ dy: Int, _ extending: Bool) -> Void
    let onSingleKey: (_ key: String) -> Void
    let onSpace: () -> Void
    let onOpen: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    func makeNSView(context: Context) -> ReviewKeyResponderView {
        let view = ReviewKeyResponderView()
        view.onArrow = onArrow
        view.onSingleKey = onSingleKey
        view.onSpace = onSpace
        view.onOpen = onOpen
        view.onSelectAll = onSelectAll
        view.onDeselectAll = onDeselectAll
        return view
    }

    func updateNSView(_ nsView: ReviewKeyResponderView, context: Context) {
        nsView.onArrow = onArrow
        nsView.onSingleKey = onSingleKey
        nsView.onSpace = onSpace
        nsView.onOpen = onOpen
        nsView.onSelectAll = onSelectAll
        nsView.onDeselectAll = onDeselectAll
        if isFocused, nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ReviewKeyResponderView: NSView {
    var onArrow: ((_ dx: Int, _ dy: Int, _ extending: Bool) -> Void)?
    var onSingleKey: ((_ key: String) -> Void)?
    var onSpace: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let extending = event.modifierFlags.contains(.shift)
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.uppercased() {
            if chars == "A" {
                onSelectAll?()
                return
            }
            if chars == "\u{1B}" {
                onDeselectAll?()
                return
            }
        }

        switch event.keyCode {
        case 123:
            onArrow?(-1, 0, extending)
        case 124:
            onArrow?(1, 0, extending)
        case 125:
            onArrow?(0, 1, extending)
        case 126:
            onArrow?(0, -1, extending)
        case 49:
            onSpace?()
        case 36:
            onOpen?()
        case 53:
            onDeselectAll?()
        default:
            if let text = event.charactersIgnoringModifiers?.uppercased(), ["I", "D", "R", "A", "S", "C"].contains(text) {
                onSingleKey?(text)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

private struct FullPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: MediaItem
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.title3.weight(.semibold))
                    Text(item.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZoomToolbar(zoom: $zoom)
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ZoomableImageCanvas(imageURL: item.sourceURL, zoom: zoom)
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 650)
    }
}

private struct CompareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let items: [MediaItem]
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Selection")
                        .font(.title3.weight(.semibold))
                    Text("\(items.count) selected image(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZoomToolbar(zoom: $zoom)
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if items.isEmpty {
                ContentUnavailableView("No Images Selected", systemImage: "rectangle.on.rectangle", description: Text("Select at least two images in the grid and use Compare."))
            } else {
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.fileName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(item.relativePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                ZoomableImageCanvas(imageURL: item.sourceURL, zoom: zoom)
                                    .frame(width: 420, height: 520)
                                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(width: 440, alignment: .topLeading)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 680)
    }
}

private struct ZoomToolbar: View {
    @Binding var zoom: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Button("−") {
                zoom = max(0.25, zoom - 0.25)
            }
            .keyboardShortcut("-", modifiers: [])

            Button("100%") {
                zoom = 1
            }
            .keyboardShortcut("0", modifiers: [])

            Button("+") {
                zoom = min(4, zoom + 0.25)
            }
            .keyboardShortcut("+", modifiers: [])

            Text("\(Int(zoom * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct ZoomableImageCanvas: View {
    let imageURL: URL
    let zoom: CGFloat

    var body: some View {
        GeometryReader { proxy in
            if let image = NSImage(contentsOf: imageURL) {
                let imageSize = image.size
                let fitScale = min(
                    proxy.size.width / max(imageSize.width, 1),
                    proxy.size.height / max(imageSize.height, 1)
                )
                let displayScale = max(fitScale, 0.01) * zoom

                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(
                            width: max(1, imageSize.width * displayScale),
                            height: max(1, imageSize.height * displayScale)
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(Text("Unable to load full photo"))
            }
        }
    }
}
