import Foundation

struct WorkflowGuidanceResolver {
    func resolve(
        sourceWorkspaceState: SourceWorkspaceState,
        sessionSummary: SessionSummary?,
        creationPlan: PhotoLogCreationPlan?,
        isBrowsingArchive: Bool,
        importReadiness: ImportReadinessSnapshot?,
        importOperation: ImportOperationSnapshot
    ) -> WorkflowGuidanceSnapshot {
        if isBrowsingArchive {
            return WorkflowGuidanceSnapshot(
                title: "Archive Browsing",
                state: "Read-only archive view",
                detail: "Archive items can be inspected here. Copying starts from a source inbox or photo log.",
                nextAction: "Open a source inbox or continue a photo log.",
                systemImage: "archivebox"
            )
        }

        switch importOperation.phase {
        case .copying:
            return WorkflowGuidanceSnapshot(
                title: "Copying To Archive",
                state: progressState(importOperation.progress),
                detail: importOperation.detail,
                nextAction: "Wait for copy and verification to finish.",
                systemImage: "arrow.down.doc"
            )
        case .failed:
            return WorkflowGuidanceSnapshot(
                title: "Copy Failed",
                state: "Needs attention",
                detail: importOperation.detail,
                nextAction: importReadiness?.hasFilesToCopy == true
                    ? "Fix the problem, then run Copy To Archive again."
                    : "Return to a photo log with S photos before copying.",
                systemImage: "exclamationmark.triangle"
            )
        case .completed:
            if importReadiness?.hasFilesToCopy != true {
                return completedCopyGuidance(importOperation: importOperation, readiness: importReadiness)
            }
        case .idle:
            break
        }

        switch sourceWorkspaceState {
        case .loading:
            return WorkflowGuidanceSnapshot(
                title: "Loading Source",
                state: "Scanning",
                detail: sourceWorkspaceState.summary,
                nextAction: "Wait for the source scan to finish.",
                systemImage: "arrow.clockwise"
            )
        case .failed:
            return WorkflowGuidanceSnapshot(
                title: "Source Load Failed",
                state: "Needs source access",
                detail: sourceWorkspaceState.summary,
                nextAction: "Reload the source or choose another folder.",
                systemImage: "exclamationmark.triangle"
            )
        case .empty:
            return WorkflowGuidanceSnapshot(
                title: "Source Empty",
                state: "No media found",
                detail: sourceWorkspaceState.summary,
                nextAction: "Choose another source folder or check the SSD.",
                systemImage: "tray"
            )
        case .idle, .loaded:
            break
        }

        guard let sessionSummary else {
            return WorkflowGuidanceSnapshot.empty
        }

        switch sessionSummary.sessionKind {
        case .inbox:
            return sourceInboxGuidance(sessionSummary: sessionSummary, creationPlan: creationPlan)
        case .walkDraft:
            return photoLogGuidance(sessionSummary: sessionSummary, readiness: importReadiness)
        }
    }

    private func sourceInboxGuidance(
        sessionSummary: SessionSummary,
        creationPlan: PhotoLogCreationPlan?
    ) -> WorkflowGuidanceSnapshot {
        let decidedCount = sessionSummary.includedCount + sessionSummary.candidateCount + sessionSummary.excludedCount

        if let creationPlan {
            if creationPlan.canCreate {
                return WorkflowGuidanceSnapshot(
                    title: "Source Inbox Ready",
                    state: "Photo log can be created",
                    detail: "\(creationPlan.candidateCount) decided photo(s) in \(creationPlan.scope.label). Undecided photos stay in the source inbox.",
                    nextAction: "Use Create Photo Log, then continue that log to copy S photos.",
                    systemImage: "square.and.pencil"
                )
            }

            return WorkflowGuidanceSnapshot(
                title: "Source Inbox",
                state: "Photo log not ready",
                detail: creationPlan.disabledReason ?? "This scope is not ready for a photo log.",
                nextAction: decidedCount == 0
                    ? "Mark photos with S, C, or X in the review grid."
                    : "Resolve the message above, then create the photo log.",
                systemImage: "tray.full"
            )
        }

        if decidedCount > 0 {
            return WorkflowGuidanceSnapshot(
                title: "Source Inbox",
                state: "Decisions saved here",
                detail: "\(decidedCount) decided photo(s) are still in the source inbox.",
                nextAction: "Focus the review grid or one folder, then create a photo log.",
                systemImage: "tray.full"
            )
        }

        return WorkflowGuidanceSnapshot(
            title: "Source Inbox",
            state: "Triage in progress",
            detail: "\(sessionSummary.itemCount) visible photo(s). No photo log has been created from this scope yet.",
            nextAction: "Mark keepers with S, candidates with C, rejects with X.",
            systemImage: "tray.full"
        )
    }

    private func photoLogGuidance(
        sessionSummary: SessionSummary,
        readiness: ImportReadinessSnapshot?
    ) -> WorkflowGuidanceSnapshot {
        guard let readiness else {
            return WorkflowGuidanceSnapshot(
                title: "Photo Log",
                state: sessionSummary.status,
                detail: "\(sessionSummary.itemCount) photo(s) in this log.",
                nextAction: "Review the log in the grid.",
                systemImage: "doc.text"
            )
        }

        if readiness.cleanupPendingItems > 0 {
            let needsBackup = readiness.cleanupRequiresBackupConfirmation && !readiness.backupConfirmed
            return WorkflowGuidanceSnapshot(
                title: "Photo Log Copied",
                state: needsBackup ? "Waiting for backup confirmation" : "Ready for source cleanup",
                detail: "\(readiness.cleanupPendingItems) copied source photo(s) can be cleaned after backup is confirmed.",
                nextAction: needsBackup ? "Use Confirm Backup." : "Use Clean Source SSD.",
                systemImage: needsBackup ? "checkmark.shield" : "externaldrive.badge.minus"
            )
        }

        if readiness.verifiedAwaitingBackupItems > 0 {
            return WorkflowGuidanceSnapshot(
                title: "Photo Log Copied",
                state: "Files verified in archive",
                detail: "\(readiness.verifiedAwaitingBackupItems) copied photo(s) are verified. Source cleanup is still locked.",
                nextAction: "Confirm the backup before cleaning the SSD.",
                systemImage: "checkmark.seal"
            )
        }

        if readiness.hasFilesToCopy {
            return WorkflowGuidanceSnapshot(
                title: "Photo Log Ready To Copy",
                state: "\(readiness.includedItems) S photo(s) ready",
                detail: readiness.idleDetail,
                nextAction: "Use Copy To Archive.",
                systemImage: "externaldrive.badge.plus"
            )
        }

        if readiness.candidateItems > 0 || readiness.excludedItems > 0 || readiness.undecidedItems > 0 {
            return WorkflowGuidanceSnapshot(
                title: "Photo Log In Progress",
                state: "No uncopied S photos",
                detail: readiness.idleDetail,
                nextAction: "Mark keepers with S. C and X choices are not copied.",
                systemImage: "doc.text.magnifyingglass"
            )
        }

        return WorkflowGuidanceSnapshot(
            title: "Photo Log",
            state: sessionSummary.status,
            detail: "No uncopied photos are ready in this log.",
            nextAction: "Continue another log or return to the source inbox.",
            systemImage: "doc.text"
        )
    }

    private func completedCopyGuidance(
        importOperation: ImportOperationSnapshot,
        readiness: ImportReadinessSnapshot?
    ) -> WorkflowGuidanceSnapshot {
        let nextAction: String
        if let readiness, readiness.cleanupPendingItems > 0 {
            nextAction = readiness.cleanupRequiresBackupConfirmation && !readiness.backupConfirmed
                ? "Confirm the backup before cleaning the SSD."
                : "Clean source files from the SSD when ready."
        } else if let readiness, readiness.verifiedAwaitingBackupItems > 0 {
            nextAction = "Confirm the backup before cleaning the SSD."
        } else {
            nextAction = "Review the archive result or continue another log."
        }

        return WorkflowGuidanceSnapshot(
            title: "Copy Complete",
            state: "Archive write finished",
            detail: importOperation.detail,
            nextAction: nextAction,
            systemImage: "checkmark.seal"
        )
    }

    private func progressState(_ progress: ImportProgress?) -> String {
        guard let progress else { return "Copy in progress" }
        return "\(progress.current)/\(progress.total) files"
    }
}
