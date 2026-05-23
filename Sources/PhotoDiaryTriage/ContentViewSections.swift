import AppKit
import SwiftUI

struct SidebarPaneView: View {
    let appState: AppState
    @ObservedObject var state: SidebarState
    let appRelease: AppRelease
    @State private var expandedNodeIDs: Set<String> = []
    @State private var expansionSignature = ""

    var body: some View {
        let snapshot = state.snapshot

        VStack(alignment: .leading, spacing: 8) {
            List(selection: Binding(
                get: { state.snapshot.tree.selectedSidebarNodeID },
                set: { appState.selectSidebarNode($0) }
            )) {
                ForEach(snapshot.tree.browserRoots) { node in
                    SidebarNodeTreeItem(
                        appState: appState,
                        node: node,
                        expandedNodeIDs: $expandedNodeIDs
                    )
                }
            }
            .listStyle(.sidebar)
            .onAppear {
                applyAutomaticExpansion(to: snapshot.tree.browserRoots)
            }
            .onChange(of: snapshot.tree.browserRoots) { _, roots in
                applyAutomaticExpansion(to: roots)
            }

            SidebarStatusView(state: state, appRelease: appRelease)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func applyAutomaticExpansion(to roots: [BrowserNode]) {
        let automaticNodeIDs = SidebarTreeExpansion.defaultExpandedNodeIDs(for: roots)
        let signature = SidebarTreeExpansion.signature(for: automaticNodeIDs)
        guard signature != expansionSignature else { return }
        expandedNodeIDs.formUnion(automaticNodeIDs)
        expansionSignature = signature
    }
}

struct SidebarNodeTreeItem: View {
    let appState: AppState
    let node: BrowserNode
    @Binding var expandedNodeIDs: Set<String>

    var body: some View {
        if let children = node.children, !children.isEmpty {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    SidebarNodeTreeItem(
                        appState: appState,
                        node: child,
                        expandedNodeIDs: $expandedNodeIDs
                    )
                }
            } label: {
                SidebarNodeRow(node: node)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectSidebarNode(node.id)
                    }
            }
            .tag(node.id)
        } else {
            SidebarNodeRow(node: node)
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.selectSidebarNode(node.id)
                }
                .tag(node.id)
        }
    }

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedNodeIDs.contains(node.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedNodeIDs.insert(node.id)
                } else {
                    expandedNodeIDs.remove(node.id)
                }
            }
        )
    }
}

enum SidebarTreeExpansion {
    static func defaultExpandedNodeIDs(for roots: [BrowserNode]) -> Set<String> {
        var ids = Set<String>()
        for root in roots {
            collectDefaultExpandedNodeIDs(from: root, into: &ids)
        }
        return ids
    }

    static func signature(for nodeIDs: Set<String>) -> String {
        nodeIDs.sorted().joined(separator: "|")
    }

    private static func collectDefaultExpandedNodeIDs(from node: BrowserNode, into ids: inout Set<String>) {
        if shouldAutoExpand(node) {
            ids.insert(node.id)
        }
        for child in node.children ?? [] {
            collectDefaultExpandedNodeIDs(from: child, into: &ids)
        }
    }

    private static func shouldAutoExpand(_ node: BrowserNode) -> Bool {
        switch node.kind {
        case .archiveSection, .archiveRoot, .sessionSection, .sessionRoot, .year:
            return !(node.children?.isEmpty ?? true)
        case .month, .day, .unknownDate, .photosFolder, .burstsFolder, .timeClustersFolder, .burstGroup, .timeCluster, .archiveWalkFolder:
            return false
        }
    }
}

struct SourceWorkspaceStatusPane: View {
    let summary: String
    let canOpenDefaultSourceWorkspace: Bool
    let canReloadSourceWorkspace: Bool
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source Workspace")
                .font(.caption.weight(.semibold))
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button("Open Default Source") {
                    appState.openDefaultSourceWorkspace()
                }
                .disabled(!canOpenDefaultSourceWorkspace)

                Button("Reload Source") {
                    appState.reloadCurrentSourceWorkspace()
                }
                .disabled(!canReloadSourceWorkspace)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WalkDetailsPaneView: View {
    let appState: AppState
    @Binding var isExpanded: Bool
    let isEnabled: Bool
    @Binding var walkTitle: String
    @Binding var walkLocation: String
    @Binding var walkNotes: String
    let summary: String
    var compact: Bool = false

    var body: some View {
        if isEnabled {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Photo log title", text: $walkTitle)
                    TextField("Location", text: $walkLocation)
                    TextField("Notes", text: $walkNotes, axis: .vertical)
                        .lineLimit(4...8)
                    Button("Save Log Details") {
                        appState.updateWalkMetadata(title: walkTitle, location: walkLocation, notes: walkNotes)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(PhotoLogStatusPolicy.detailsSheetTitle)
                        .font(.headline)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(compact ? 0 : 12)
            .background {
                if !compact {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                }
            }
            .controlSize(compact ? .small : .regular)
        }
    }
}

struct ActionButtonsPaneView: View {
    let appState: AppState
    var compact: Bool = false

    var body: some View {
        Group {
            if let readiness = appState.sidebarState.snapshot.importReadiness {
                Group {
                    if compact {
                        VStack(alignment: .leading, spacing: 6) {
                            CopyToArchiveStatusView(
                                readiness: readiness,
                                operation: appState.sidebarState.snapshot.importOperation,
                                compact: true
                            )
                            actionButtons
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            CopyToArchiveStatusView(
                                readiness: readiness,
                                operation: appState.sidebarState.snapshot.importOperation,
                                compact: false
                            )
                            HStack {
                                actionButtons
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .controlSize(compact ? .small : .regular)
            }
        }
    }

    private var actionButtons: some View {
        Group {
            if appState.canStartNewPhotoLogFromCurrentLog {
                Button {
                    appState.startNewPhotoLogFromCurrentLog()
                } label: {
                    Label("Start New Photo Log", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.borderedProminent)
                .help("Close the current photo log and return to the source inbox to mark the next set.")
            }

            Button("Copy To Archive") {
                appState.commitImport()
            }
            .disabled(!appState.canCommitImport)
            .help(appState.sidebarState.snapshot.importReadiness?.copyButtonHelp ?? "Copy included files into the archive.")

            Button("Open Archive Folder") {
                appState.openArchiveDestinationForCurrentSession()
            }
            .disabled(!appState.canOpenArchiveDestination)
            .help("Open the folder containing copied photos before confirming backup.")

            Button("Confirm Backup") {
                appState.markBackupConfirmed()
            }
            .disabled(!appState.canConfirmBackup)
            .help(appState.sidebarState.snapshot.importReadiness?.confirmBackupButtonHelp ?? "Confirm backup after copy verification.")

            Button("Clean Source SSD") {
                appState.cleanupImportedSources()
            }
            .disabled(!appState.canCleanupImportedSources)
            .help(appState.sidebarState.snapshot.importReadiness?.cleanupButtonHelp ?? "Clean copied source files from the SSD when allowed.")
        }
    }
}

struct CopyToArchiveStatusView: View {
    let readiness: ImportReadinessSnapshot
    let operation: ImportOperationSnapshot
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(titleStyle)

                Spacer(minLength: 8)

                if readiness.totalFiles > 0 || operation.isRunning {
                    Text(fileCountLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let progress = operation.progress {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 3 : 4)

            if let destinationPath = operation.destinationPath ?? readiness.destinationPath {
                LabeledContent("Destination") {
                    Text(destinationPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(destinationPath)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if cleanupDetail.isEmpty == false {
                Text(cleanupDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        switch operation.phase {
        case .idle:
            readiness.hasFilesToCopy ? "Copy Ready" : "Copy Waiting"
        case .copying, .completed, .failed:
            operation.title
        }
    }

    private var systemImage: String {
        switch operation.phase {
        case .idle:
            readiness.hasFilesToCopy ? "externaldrive.badge.plus" : "externaldrive"
        case .copying:
            "arrow.down.doc"
        case .completed:
            "checkmark.seal"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private var titleStyle: AnyShapeStyle {
        switch operation.phase {
        case .failed:
            return AnyShapeStyle(.red)
        case .completed:
            return AnyShapeStyle(.green)
        case .copying:
            return AnyShapeStyle(.primary)
        case .idle:
            return AnyShapeStyle(readiness.hasFilesToCopy ? .primary : .secondary)
        }
    }

    private var fileCountLabel: String {
        if let progress = operation.progress {
            return "\(progress.current)/\(progress.total) files"
        }
        return "\(readiness.totalFiles) files"
    }

    private var detail: String {
        switch operation.phase {
        case .idle:
            return readiness.idleDetail
        case .copying, .completed, .failed:
            return operation.detail
        }
    }

    private var cleanupDetail: String {
        if readiness.cleanupPendingItems > 0 {
            return readiness.backupConfirmed
                ? "\(readiness.cleanupPendingItems) source photo(s) can be cleaned from the SSD."
                : "\(readiness.cleanupPendingItems) source photo(s) are waiting for backup confirmation."
        }
        if readiness.verifiedAwaitingBackupItems > 0 && readiness.cleanupRequiresBackupConfirmation {
            return "Open the archive folder to inspect copied photos. Cleanup is locked until backup confirmation."
        }
        return ""
    }
}

struct WorkflowGuidanceView: View {
    let guidance: WorkflowGuidanceSnapshot
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            Label(guidance.title, systemImage: guidance.systemImage)
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            guidanceRow("State", guidance.state, lineLimit: compact ? 2 : 3)
            guidanceRow("Now", guidance.detail, lineLimit: compact ? 3 : 4)
            guidanceRow("Next", guidance.nextAction, lineLimit: compact ? 3 : 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guidanceRow(_ label: String, _ value: String, lineLimit: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: compact ? 32 : 40, alignment: .leading)

            Text(value)
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(label == "Next" ? .primary : .secondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SidebarStatusView: View {
    @ObservedObject var state: SidebarState
    let appRelease: AppRelease

    var body: some View {
        let snapshot = state.snapshot

        VStack(alignment: .leading, spacing: 6) {
            Text(appRelease.displayString)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            WorkflowGuidanceView(guidance: snapshot.workflowGuidance, compact: true)

            Text("Last update: \(snapshot.statusMessage)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let progress = snapshot.importOperation.progress {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
                Text("\(progress.current)/\(progress.total) files")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if snapshot.importOperation.phase == .completed || snapshot.importOperation.phase == .failed {
                Text(snapshot.importOperation.detail)
                    .font(.caption2)
                    .foregroundStyle(snapshot.importOperation.phase == .failed ? .red : .secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

struct FooterStatusBarView: View {
    @ObservedObject var state: SidebarState
    let appRelease: AppRelease

    var body: some View {
        let workflow = state.snapshot.workflowGuidance

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

            Text("\(workflow.title): \(workflow.nextAction)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let progress = state.snapshot.importOperation.progress {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
                Text("\(progress.current)/\(progress.total) files")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
