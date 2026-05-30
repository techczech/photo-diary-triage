import AppKit
import SwiftUI

struct InspectorCollapsedRail: View {
    let appState: AppState

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

struct DetailsInspectorView: View {
    let appState: AppState
    @ObservedObject var state: InspectorState
    @ObservedObject var sidebarState: SidebarState
    @Binding var walkTitle: String
    @Binding var walkLocation: String
    @Binding var walkNotes: String
    let summary: String
    @State private var isStorageDetailsExpanded = false

    var body: some View {
        Group {
            if state.snapshot.isVisible {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Inspector")
                                .font(.title3.weight(.semibold))
                            Spacer()
                            Button {
                                appState.toggleDetailsInspector()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("Hide inspector")
                        }

                        workflowSection
                        sessionSection
                        photoSection
                        walkDetailsSection
                        storageDetailsSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Color.clear
            }
        }
    }

    private var workflowSection: some View {
        InspectorSectionPanel(title: "Workflow") {
            InspectorWorkflowPanel(
                appState: appState,
                guidance: sidebarState.snapshot.workflowGuidance,
                readiness: sidebarState.snapshot.importReadiness,
                operation: sidebarState.snapshot.importOperation
            )
        }
    }

    @ViewBuilder
    private var sessionSection: some View {
        if let session = sidebarState.snapshot.sessionSummary {
            InspectorSectionPanel(title: "Current Log") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(logTitle(for: session))
                            .font(.headline)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let location = session.walkMetadata.location.nonEmpty {
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            InspectorMetricBadge(label: "Selected", value: "\(session.includedCount)")
                            InspectorMetricBadge(label: "Candidate", value: "\(session.candidateCount)")
                        }

                        HStack(spacing: 8) {
                            InspectorMetricBadge(label: "Excluded", value: "\(session.excludedCount)")
                            InspectorMetricBadge(label: "Visible", value: "\(session.itemCount)")
                        }
                    }

                    InspectorPathRow(label: "Source", path: session.sourceFolderPath)

                    if let scopeLabel = session.photoLogScope?.label.nonEmpty, session.sessionKind == .walkDraft {
                        InspectorMetadataLine(label: "Primary scope", value: scopeLabel)
                    }

                    InspectorMetadataLine(label: "State", value: "\(session.sessionKind.title) · \(session.status)")

                    if let hiddenSummary = sidebarState.snapshot.hiddenPhotoLogSummary {
                        Text(hiddenSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if session.sessionKind == .walkDraft || session.sessionKind == .inbox {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Photo log title", text: $walkTitle)
                            TextField("Location", text: $walkLocation)
                            TextField("Notes", text: $walkNotes, axis: .vertical)
                                .lineLimit(2...4)

                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    appState.updateWalkMetadata(title: walkTitle, location: walkLocation, notes: walkNotes)
                                } label: {
                                    Label("Save Details", systemImage: "checkmark")
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .help("Save the current log title, location, and notes.")

                                Button {
                                    appState.openPhotoLogLibrary()
                                } label: {
                                    Label("Open Logs", systemImage: "books.vertical")
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .help("Open the photo log list.")

                                Button {
                                    appState.saveCurrentLogDetailsAndStartNext(
                                        title: walkTitle,
                                        location: walkLocation,
                                        notes: walkNotes
                                    )
                                } label: {
                                    Label(appState.photoLogSessionStartActionTitle, systemImage: "plus.square.on.square")
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .disabled(!appState.canStartNewPhotoLogSession)
                                .help(appState.photoLogSessionStartActionHelp)
                            }
                            .controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var walkDetailsSection: some View {
        if sidebarState.snapshot.canMutateImportSelection,
           sidebarState.snapshot.sessionSummary?.sessionKind == .walkDraft {
            InspectorSectionPanel(title: "Log Details") {
                WalkDetailsPaneView(
                    appState: appState,
                    isExpanded: Binding(
                        get: { sidebarState.snapshot.isWalkDetailsExpanded },
                        set: { appState.isWalkDetailsExpanded = $0 }
                    ),
                    isEnabled: sidebarState.snapshot.canMutateImportSelection,
                    walkTitle: $walkTitle,
                    walkLocation: $walkLocation,
                    walkNotes: $walkNotes,
                    summary: summary,
                    compact: true
                )
            }
        }
    }

    private var storageDetailsSection: some View {
        InspectorSectionPanel {
            DisclosureGroup(isExpanded: $isStorageDetailsExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    SourceWorkspaceStatusPane(
                        summary: sidebarState.snapshot.sourceWorkspaceState.summary,
                        canOpenDefaultSourceWorkspace: sidebarState.snapshot.canOpenDefaultSourceWorkspace,
                        canReloadSourceWorkspace: sidebarState.snapshot.canReloadSourceWorkspace,
                        appState: appState
                    )

                    Divider()

                    InspectorPathRow(label: "Archive root", path: sidebarState.snapshot.archiveRootDisplayPath)
                    if !sidebarState.snapshot.archiveYearFolders.isEmpty {
                        InspectorMetadataLine(label: "Years", value: sidebarState.snapshot.archiveYearFolders.joined(separator: ", "))
                    }

                    currentFolderDetails
                }
                .padding(.top, 8)
            } label: {
                Label("Storage Details", systemImage: "externaldrive")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    @ViewBuilder
    private var currentFolderDetails: some View {
        if let node = state.snapshot.browserNode {
            Divider()
            InspectorMetadataLine(label: "Folder", value: node.title)
            InspectorMetadataLine(label: "Kind", value: kindLabel(node.kind))
            InspectorMetadataLine(label: "Photos", value: "\(node.mediaItemIDs.count)")
            if let folderURL = node.folderURL {
                InspectorPathRow(label: "Path", path: folderURL.path)
            } else if node.kind == .sessionRoot, let fallbackPath = state.snapshot.fallbackFolderPath {
                InspectorPathRow(label: "Path", path: fallbackPath)
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        InspectorSectionPanel(title: "Selected Photo") {
            VStack(alignment: .leading, spacing: 8) {
                if let item = state.snapshot.mediaItem {
                    ThumbnailImageSurface(
                        appState: appState,
                        item: item,
                        thumbnailFailed: false,
                        thumbnailCloudOnly: appState.isThumbnailCloudOnly(for: item),
                        retryThumbnail: {
                            appState.requestThumbnail(for: item)
                        },
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    inspectorRow("File", item.fileName)
                    inspectorRow("Relative Path", item.relativePath)
                    inspectorRow("Size", ByteCountFormatter.string(fromByteCount: item.fileSizeBytes, countStyle: .file))
                    inspectorRow("Locality", appState.isFileOnlineOnly(for: item) ? FileLocality.onlineOnly.displayLabel : item.resolvedFileLocality.displayLabel)
                    inspectorRow("State", item.selectionState.statusLabel)
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
                    if let cropHistory = state.snapshot.cropHistory {
                        Divider()
                        cropHistorySection(cropHistory)
                    }
                } else {
                    Text("Select a photo to inspect its metadata.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: state.snapshot.mediaItem?.id) {
                if let item = state.snapshot.mediaItem {
                    appState.requestThumbnail(for: item)
                }
            }
        }
    }

    private func cropHistorySection(_ history: CropHistorySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Crop Versions", systemImage: "crop")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(history.cropCount)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(history.versions) { version in
                cropVersionRow(version)
            }
        }
    }

    private func cropVersionRow(_ version: CropVersionSnapshot) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: version.role == .crop ? "crop" : "photo")
                .foregroundStyle(version.role == .crop ? Color.purple.opacity(0.95) : Color.teal.opacity(0.95))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(version.roleLabel)
                        .font(.caption.weight(.semibold))
                    if version.isCurrent {
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    } else if !version.isLoaded {
                        Text("Not loaded")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(version.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            Button {
                appState.openCropVersion(relativePath: version.relativePath)
            } label: {
                Image(systemName: "arrow.right.square")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(version.isCurrent || !version.isLoaded)
            .help(version.isLoaded ? "Show this crop version in the app" : "This crop version is not loaded in the current view")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(version.isCurrent ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
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

    private func logTitle(for session: SessionSummary) -> String {
        session.walkMetadata.title.nonEmpty ?? summary
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

private struct InspectorSectionPanel<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}
