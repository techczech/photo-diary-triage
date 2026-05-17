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
                                        Button("Edit") {
                                            appState.editPhotoLogMembership(log.sessionID)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .disabled(log.status == "imported" || log.status == "source_cleaned")
                                        Button("Details") {
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
            if appState.canMutateImportSelection {
                Group {
                    if compact {
                        VStack(alignment: .leading, spacing: 6) {
                            actionButtons
                        }
                    } else {
                        HStack {
                            actionButtons
                        }
                    }
                }
                .controlSize(compact ? .small : .regular)
            }
        }
    }

    private var actionButtons: some View {
        Group {
            Button("Copy Included Files Into Archive") {
                appState.commitImport()
            }
            .disabled(!appState.canCommitImport)

            Button("Confirm Backup And Enable Cleanup") {
                appState.markBackupConfirmed()
            }
            .disabled(!appState.canConfirmBackup)

            Button("Clean Imported Files From Source SSD") {
                appState.cleanupImportedSources()
            }
            .disabled(!appState.canCleanupImportedSources)
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

            Text(snapshot.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let progress = snapshot.importProgress {
                Text("\(progress.current)/\(progress.total)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
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

            if let progress = state.snapshot.importProgress {
                Text("\(progress.current)/\(progress.total)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
