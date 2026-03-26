import AppKit
import SwiftUI

struct SidebarPaneView: View {
    @ObservedObject var appState: AppState
    @Binding var walkTitle: String
    @Binding var walkLocation: String
    @Binding var walkNotes: String
    let summary: String
    let appRelease: AppRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let session = appState.currentSession {
                GroupBox("Current Session") {
                    VStack(alignment: .leading, spacing: 6) {
                        utilityButtons

                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(session.sourceFolder.path)
                            .font(.caption)
                            .textSelection(.enabled)
                        Text("\(session.mediaItems.count) visible items")
                            .font(.caption)
                        Text("\(session.mediaItems.filter { $0.selectionState == .selected }.count) marked for import")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                utilityButtons
            }

            if appState.canMutateImportSelection {
                GroupBox("Walk Details") {
                    WalkDetailsPaneView(
                        appState: appState,
                        walkTitle: $walkTitle,
                        walkLocation: $walkLocation,
                        walkNotes: $walkNotes,
                        summary: summary,
                        compact: true
                    )
                }
            }

            if appState.canMutateImportSelection {
                GroupBox("Import Actions") {
                    ActionButtonsPaneView(appState: appState, compact: true)
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

            SidebarStatusView(appState: appState, appRelease: appRelease)
        }
        .padding()
        .frame(minWidth: 300)
    }

    private var utilityButtons: some View {
        HStack(spacing: 6) {
            Button("Source") {
                appState.pickSourceFolder()
            }

            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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

struct WalkDetailsPaneView: View {
    @ObservedObject var appState: AppState
    @Binding var walkTitle: String
    @Binding var walkLocation: String
    @Binding var walkNotes: String
    let summary: String
    var compact: Bool = false

    var body: some View {
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
    @ObservedObject var appState: AppState
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
            Button("Copy Marked Files Into Archive") {
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
    @ObservedObject var appState: AppState
    let appRelease: AppRelease

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appRelease.displayString)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if let progress = appState.importProgress {
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
    @ObservedObject var appState: AppState
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
}
