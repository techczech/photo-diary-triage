import SwiftUI

struct InspectorWorkflowPanel: View {
    let appState: AppState
    let guidance: WorkflowGuidanceSnapshot
    let readiness: ImportReadinessSnapshot?
    let operation: ImportOperationSnapshot

    private var destinationPath: String? {
        operation.destinationPath ?? readiness?.destinationPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(guidance.title, systemImage: guidance.systemImage)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(guidance.state)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Text(guidance.detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            WorkflowStageList(readiness: readiness, operation: operation)

            if let destinationPath {
                ArchiveFolderLinkRow(
                    label: readiness?.archiveDestinationLabel ?? "Archive folder",
                    path: destinationPath,
                    canOpen: appState.canOpenArchiveDestination,
                    open: {
                        appState.openArchiveDestinationForCurrentSession()
                    }
                )
            }

            InspectorWorkflowActions(appState: appState, readiness: readiness)

            Text(guidance.nextAction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkflowStageList: View {
    let readiness: ImportReadinessSnapshot?
    let operation: ImportOperationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WorkflowStageRow(
                title: "Copy",
                systemImage: copyImage,
                state: copyState,
                isComplete: copiedItemsExist,
                isActive: operation.phase == .copying || readiness?.hasFilesToCopy == true
            )
            WorkflowStageRow(
                title: "Review archive",
                systemImage: "folder",
                state: reviewState,
                isComplete: readiness?.backupConfirmed == true,
                isActive: readiness?.hasCopiedArchiveDestination == true && readiness?.backupConfirmed != true
            )
            WorkflowStageRow(
                title: "Confirm backup",
                systemImage: "checkmark.shield",
                state: backupState,
                isComplete: readiness?.backupConfirmed == true,
                isActive: readiness?.needsArchiveReviewBeforeBackupConfirmation == true
            )
            WorkflowStageRow(
                title: "Clean source",
                systemImage: "externaldrive.badge.minus",
                state: cleanupState,
                isComplete: false,
                isActive: cleanupIsReady
            )
        }
    }

    private var copiedItemsExist: Bool {
        readiness?.hasCopiedArchiveDestination == true || operation.phase == .completed
    }

    private var cleanupIsReady: Bool {
        guard let readiness else { return false }
        return readiness.cleanupPendingItems > 0 && (readiness.backupConfirmed || !readiness.cleanupRequiresBackupConfirmation)
    }

    private var copyImage: String {
        operation.phase == .copying ? "arrow.down.doc" : "externaldrive.badge.plus"
    }

    private var copyState: String {
        if operation.phase == .copying {
            return operation.progress.map { "\($0.current)/\($0.total)" } ?? "Copying"
        }
        if copiedItemsExist {
            return "Done"
        }
        if readiness?.hasFilesToCopy == true {
            return "Ready"
        }
        return "Waiting"
    }

    private var reviewState: String {
        guard readiness?.hasCopiedArchiveDestination == true else { return "After copy" }
        return readiness?.backupConfirmed == true ? "Checked" : "Open folder"
    }

    private var backupState: String {
        if readiness?.backupConfirmed == true {
            return "Confirmed"
        }
        if readiness?.needsArchiveReviewBeforeBackupConfirmation == true {
            return "Needed"
        }
        return "After review"
    }

    private var cleanupState: String {
        guard let readiness, readiness.cleanupPendingItems > 0 else { return "Later" }
        return cleanupIsReady ? "Ready" : "Locked"
    }
}

struct WorkflowStageRow: View {
    let title: String
    let systemImage: String
    let state: String
    let isComplete: Bool
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : systemImage)
                .foregroundStyle(iconStyle)
                .frame(width: 18)

            Text(title)
                .font(.caption)
                .foregroundStyle(isActive || isComplete ? .primary : .secondary)

            Spacer(minLength: 8)

            Text(state)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var iconStyle: AnyShapeStyle {
        if isComplete {
            return AnyShapeStyle(.green)
        }
        if isActive {
            return AnyShapeStyle(.tint)
        }
        return AnyShapeStyle(.secondary)
    }
}

struct ArchiveFolderLinkRow: View {
    let label: String
    let path: String
    let canOpen: Bool
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button(action: open) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "folder")
                    Text(path)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.link)
            .disabled(!canOpen)
            .help(path)

            Text(path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct InspectorWorkflowActions: View {
    let appState: AppState
    let readiness: ImportReadinessSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if readiness?.hasFilesToCopy == true || appState.canCommitImport {
                Button("Copy To Archive") {
                    appState.commitImport()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!appState.canCommitImport)
                .help(readiness?.copyButtonHelp ?? "Copy included files into the archive.")
            }

            if readiness?.destinationPath != nil {
                Button("Open Archive Folder") {
                    appState.openArchiveDestinationForCurrentSession()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!appState.canOpenArchiveDestination)
                .help("Open the copied archive folder in Finder.")
            }

            if appState.canConfirmBackup || readiness?.needsArchiveReviewBeforeBackupConfirmation == true {
                Button("Confirm Backup") {
                    appState.markBackupConfirmed()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!appState.canConfirmBackup)
                .help(readiness?.confirmBackupButtonHelp ?? "Confirm backup after copy verification.")
            }

            if appState.canCleanupImportedSources || (readiness?.cleanupPendingItems ?? 0) > 0 {
                Button("Clean Source SSD") {
                    appState.cleanupImportedSources()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!appState.canCleanupImportedSources)
                .help(readiness?.cleanupButtonHelp ?? "Clean copied source files from the SSD when allowed.")
            }
        }
        .controlSize(.small)
    }
}

struct InspectorMetricBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct InspectorPathRow: View {
    let label: String
    let path: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(path)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

struct InspectorMetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
