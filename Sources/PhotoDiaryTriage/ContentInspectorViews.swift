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

                        sourceSection
                        workflowSection
                        sessionSection
                        photoLogsSection
                        walkDetailsSection
                        importActionsSection
                        archiveSection
                        folderSection
                        photoSection
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
        GroupBox("Workflow") {
            VStack(alignment: .leading, spacing: 10) {
                WorkflowGuidanceView(guidance: sidebarState.snapshot.workflowGuidance, compact: false)

                if sidebarState.snapshot.importReadiness?.needsArchiveReviewBeforeBackupConfirmation == true {
                    copiedLogWorkflowActions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var copiedLogWorkflowActions: some View {
        HStack(spacing: 8) {
            Button("Open Archive Folder") {
                appState.openArchiveDestinationForCurrentSession()
            }
            .disabled(!appState.canOpenArchiveDestination)
            .help("Open the folder containing copied photos before confirming backup.")

            Button("Confirm Backup") {
                appState.markBackupConfirmed()
            }
            .disabled(!appState.canConfirmBackup)
            .help(sidebarState.snapshot.importReadiness?.confirmBackupButtonHelp ?? "Confirm backup after copy verification.")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var sourceSection: some View {
        GroupBox("Source Workspace") {
            SourceWorkspaceStatusPane(
                summary: sidebarState.snapshot.sourceWorkspaceState.summary,
                canOpenDefaultSourceWorkspace: sidebarState.snapshot.canOpenDefaultSourceWorkspace,
                canReloadSourceWorkspace: sidebarState.snapshot.canReloadSourceWorkspace,
                appState: appState
            )
        }
    }

    @ViewBuilder
    private var sessionSection: some View {
        if let session = sidebarState.snapshot.sessionSummary {
            GroupBox("Current Session") {
                VStack(alignment: .leading, spacing: 8) {
                    inspectorRow("Summary", summary)
                    inspectorRow("Source", session.sourceFolderPath)
                    inspectorRow("Visible Items", "\(session.itemCount)")
                    inspectorRow("State", "\(session.sessionKind.title) • \(session.status)")
                    inspectorRow("Triage", "\(session.includedCount) selected • \(session.candidateCount) candidate • \(session.excludedCount) excluded")

                    if let scopeLabel = session.photoLogScope?.label.nonEmpty, session.sessionKind == .walkDraft {
                        inspectorRow("Primary Scope", scopeLabel)
                    }

                    if let hiddenSummary = sidebarState.snapshot.hiddenPhotoLogSummary {
                        Text(hiddenSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var photoLogsSection: some View {
        GroupBox("Photo Logs") {
            PhotoLogLibraryPane(
                appState: appState,
                groups: sidebarState.snapshot.photoLogGroups,
                canPresentPhotoLogCreation: sidebarState.snapshot.canPresentPhotoLogCreation
            )
        }
    }

    @ViewBuilder
    private var walkDetailsSection: some View {
        if sidebarState.snapshot.canMutateImportSelection,
           sidebarState.snapshot.sessionSummary?.sessionKind == .walkDraft {
            GroupBox("Log Details") {
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

    @ViewBuilder
    private var importActionsSection: some View {
        if sidebarState.snapshot.canMutateImportSelection {
            GroupBox("Import Actions") {
                ActionButtonsPaneView(appState: appState, compact: true)
            }
        }
    }

    private var archiveSection: some View {
        GroupBox("Archive Root") {
            VStack(alignment: .leading, spacing: 8) {
                inspectorRow("Path", sidebarState.snapshot.archiveRootDisplayPath)

                if sidebarState.snapshot.archiveYearFolders.isEmpty {
                    Text("No `202x` folders detected yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    inspectorRow("Years", sidebarState.snapshot.archiveYearFolders.joined(separator: ", "))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var folderSection: some View {
        GroupBox("Current Folder") {
            VStack(alignment: .leading, spacing: 8) {
                if let node = state.snapshot.browserNode {
                    inspectorRow("Name", node.title)
                    inspectorRow("Kind", kindLabel(node.kind))
                    inspectorRow("Photos", "\(node.mediaItemIDs.count)")
                    inspectorRow("Children", "\(node.children?.count ?? 0)")
                    if let subtitle = node.subtitle?.nonEmpty {
                        inspectorRow("Summary", subtitle)
                    }
                    if let folderURL = node.folderURL {
                        inspectorRow("Path", folderURL.path)
                    } else if node.kind == .sessionRoot, let fallbackPath = state.snapshot.fallbackFolderPath {
                        inspectorRow("Path", fallbackPath)
                    }
                    if let title = state.snapshot.walkTitle {
                        inspectorRow("Walk Title", title)
                    }
                    if let location = state.snapshot.walkLocation {
                        inspectorRow("Location", location)
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
                if let item = state.snapshot.mediaItem {
                    ThumbnailImageSurface(
                        appState: appState,
                        item: item,
                        thumbnailFailed: false,
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
