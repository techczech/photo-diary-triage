import AppKit
import SwiftUI

struct SidebarPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
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
}

struct WalkDetailsPaneView: View {
    @ObservedObject var appState: AppState
    @Binding var walkTitle: String
    @Binding var walkLocation: String
    @Binding var walkNotes: String
    let summary: String

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
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ActionButtonsPaneView: View {
    @ObservedObject var appState: AppState

    var body: some View {
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
