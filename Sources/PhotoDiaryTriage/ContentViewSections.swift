import AppKit
import SwiftUI

struct SidebarPaneView: View {
    @Environment(\.openSettings) private var openSettings
    let appState: AppState
    @ObservedObject var state: SidebarState
    @Binding var walkTitle: String
    @Binding var walkLocation: String
    @Binding var walkNotes: String
    let summary: String
    let appRelease: AppRelease

    var body: some View {
        let snapshot = state.snapshot

        VStack(alignment: .leading, spacing: 10) {
            if let session = snapshot.sessionSummary {
                GroupBox("Current Session") {
                    VStack(alignment: .leading, spacing: 6) {
                        utilityButtons

                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(session.sourceFolderPath)
                            .font(.caption)
                            .textSelection(.enabled)
                        Text("\(session.itemCount) visible items")
                            .font(.caption)
                        Text("\(session.sessionKind.title) • \(session.status)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(session.includedCount) selected • \(session.candidateCount) candidate • \(session.excludedCount) excluded")
                            .font(.caption)

                        if snapshot.canCreateWalkDraftFromSelection {
                            Button("Create Walk Draft") {
                                appState.createWalkDraftFromCurrentSelection()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .shortcutHint("Cmd-Shift-W", help: "Create a saved walk draft from the current selection (Cmd-Shift-W)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                utilityButtons
            }

            GroupBox("Saved Walks") {
                SavedWalkLibraryPane(
                    appState: appState,
                    groups: snapshot.savedWalkGroups,
                    canCreateWalkDraftFromSelection: snapshot.canCreateWalkDraftFromSelection
                )
            }

            if snapshot.canMutateImportSelection {
                GroupBox("Walk Details") {
                    WalkDetailsPaneView(
                        appState: appState,
                        isExpanded: Binding(
                            get: { state.snapshot.isWalkDetailsExpanded },
                            set: { appState.isWalkDetailsExpanded = $0 }
                        ),
                        isEnabled: snapshot.canMutateImportSelection,
                        walkTitle: $walkTitle,
                        walkLocation: $walkLocation,
                        walkNotes: $walkNotes,
                        summary: summary,
                        compact: true
                    )
                }
            }

            if snapshot.canMutateImportSelection {
                GroupBox("Import Actions") {
                    ActionButtonsPaneView(appState: appState, compact: true)
                }
            }

            GroupBox("Archive Root") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.archiveRootDisplayPath)
                        .font(.caption)
                        .textSelection(.enabled)
                    if snapshot.archiveYearFolders.isEmpty {
                        Text("No `202x` folders detected yet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Years: \(snapshot.archiveYearFolders.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            List(snapshot.tree.browserRoots, children: \.children, selection: Binding(
                get: { state.snapshot.tree.selectedSidebarNodeID },
                set: { appState.selectSidebarNode($0) }
            )) { node in
                SidebarNodeRow(node: node)
            }
            .listStyle(.sidebar)

            SidebarStatusView(state: state, appRelease: appRelease)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var utilityButtons: some View {
        HStack(spacing: 6) {
            Button("Source") {
                appState.pickSourceFolder()
            }

            Button("Settings") {
                openSettings()
            }

            Button("Shortcuts") {
                appState.showKeyboardHelp = true
            }
            .shortcutHint("Cmd-Shift-/", help: "Show keyboard shortcuts (Cmd-Shift-/)")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct SavedWalkLibraryPane: View {
    let appState: AppState
    let groups: [SavedWalkGroupSnapshot]
    let canCreateWalkDraftFromSelection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if canCreateWalkDraftFromSelection {
                Button("Create Walk Draft From Selection") {
                    appState.createWalkDraftFromCurrentSelection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .shortcutHint("Cmd-Shift-W", help: "Create a saved walk draft from the current selection (Cmd-Shift-W)")
            }

            if groups.isEmpty {
                Text("No saved walk drafts yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(group.workspaceSourceFolderPath)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .textSelection(.enabled)
                                    if !group.sourceIsAvailable {
                                        Text("Missing Source")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.orange.opacity(0.16), in: Capsule())
                                    }
                                    Spacer()
                                    Button("Open Inbox") {
                                        appState.openSourceInbox(for: URL(fileURLWithPath: group.workspaceSourceFolderPath, isDirectory: true))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .disabled(!group.sourceIsAvailable)
                                }

                                ForEach(group.drafts) { draft in
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(draft.title)
                                                .font(.caption.weight(.semibold))
                                            Text("\(draft.itemCount) items • \(draft.includedCount) S • \(draft.candidateCount) C • \(draft.excludedCount) X • \(draft.status)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if draft.isCurrentSession {
                                            Text("Open")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Button("Resume") {
                                                appState.openSavedWalk(draft.sessionID)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxHeight: 180)
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
