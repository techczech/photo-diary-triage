import AppKit
import SwiftUI

struct SidebarPaneView: View {
    let appState: AppState
    @ObservedObject var state: SidebarState
    let appRelease: AppRelease

    var body: some View {
        let snapshot = state.snapshot

        VStack(alignment: .leading, spacing: 8) {
            List(snapshot.tree.browserRoots, children: \.children, selection: Binding(
                get: { state.snapshot.tree.selectedSidebarNodeID },
                set: { appState.selectSidebarNode($0) }
            )) { node in
                SidebarNodeRow(node: node)
            }
            .listStyle(.sidebar)

            SidebarStatusView(state: state, appRelease: appRelease)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

struct PhotoLogLibraryPane: View {
    let appState: AppState
    let groups: [PhotoLogGroupSnapshot]
    let canPresentPhotoLogCreation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Create Photo Log…") {
                appState.presentPhotoLogCreation()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .shortcutHint("Cmd-Shift-W", help: "Create a photo log from the current scope (Cmd-Shift-W)")
            .disabled(!canPresentPhotoLogCreation)

            if groups.isEmpty {
                Text("No photo logs yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(group.scopeLabel)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    if !group.sourceIsAvailable {
                                        Text("Missing Source")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.orange.opacity(0.16), in: Capsule())
                                    }
                                }

                                ForEach(group.logs) { log in
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(log.title)
                                                .font(.caption.weight(.semibold))
                                            Text("\(log.itemCount) items • \(log.includedCount) S • \(log.candidateCount) C • \(log.excludedCount) X • \(log.status)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(log.workspaceSourceFolderPath)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if log.isCurrentSession {
                                            Text("Open")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Button("Open") {
                                                appState.openPhotoLog(log.sessionID)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }
                                        Button("Reveal") {
                                            appState.showPhotoLogContents(log.sessionID)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        Button("Edit Items") {
                                            appState.editPhotoLogMembership(log.sessionID)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .disabled(log.status == "imported" || log.status == "source_cleaned")
                                        Button("Edit Details") {
                                            appState.presentPhotoLogEditor(log.sessionID)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        Button("Delete") {
                                            appState.deletePhotoLog(log.sessionID)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .disabled(log.status == "imported" || log.status == "source_cleaned")
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
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
                    Button("Save Photo Log Details") {
                        appState.updateWalkMetadata(title: walkTitle, location: walkLocation, notes: walkNotes)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Photo Log Details")
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
            Button("Copy To Archive") {
                appState.commitImport()
            }
            .disabled(!appState.canCommitImport)

            Button("Confirm Backup") {
                appState.markBackupConfirmed()
            }
            .disabled(!appState.canConfirmBackup)

            Button("Clean Source SSD") {
                appState.cleanupImportedSources()
            }
            .disabled(!appState.canCleanupImportedSources)
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
            if readiness.hasFilesToCopy {
                let rawDetail = readiness.rawCompanionFiles == 0 ? "" : " plus \(readiness.rawCompanionFiles) RAW companion file(s)"
                return "\(readiness.includedItems) selected photo(s)\(rawDetail) will be copied and verified before cleanup is offered."
            }
            if readiness.verifiedAwaitingBackupItems > 0 {
                return "\(readiness.verifiedAwaitingBackupItems) copied photo(s) are verified. Confirm the backup before source cleanup."
            }
            if readiness.cleanupPendingItems > 0 {
                return "\(readiness.cleanupPendingItems) copied photo(s) are ready for source cleanup."
            }
            return "Select photos with S to make a copy plan visible here before writing to the archive."
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
            return "Cleanup is locked until backup confirmation."
        }
        return ""
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

            Text(snapshot.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

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

            Text(state.snapshot.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)

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
