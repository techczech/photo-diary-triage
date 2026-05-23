import SwiftUI

struct PhotoLogLibraryPane: View {
    let appState: AppState
    let groups: [PhotoLogGroupSnapshot]
    let canPresentPhotoLogCreation: Bool
    var maxListHeight: CGFloat? = 340

    private var logCount: Int {
        groups.reduce(0) { $0 + $1.logs.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    appState.presentPhotoLogCreation()
                } label: {
                    Label("Create Photo Log", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .shortcutHint("Cmd-Shift-W", help: "Create a photo log from the current scope (Cmd-Shift-W)")
                .disabled(!canPresentPhotoLogCreation)

                Spacer(minLength: 8)

                if logCount > 0 {
                    Text("\(logCount) log\(logCount == 1 ? "" : "s")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if groups.isEmpty {
                ContentUnavailableView(
                    "No Photo Logs",
                    systemImage: "books.vertical",
                    description: Text("Create a photo log from selected source photos.")
                )
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(groups) { group in
                            PhotoLogGroupSectionView(appState: appState, group: group)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: maxListHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PhotoLogLibraryMainPane: View {
    let appState: AppState
    @ObservedObject var state: SidebarState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotoLogLibraryPane(
                appState: appState,
                groups: state.snapshot.photoLogGroups,
                canPresentPhotoLogCreation: state.snapshot.canPresentPhotoLogCreation,
                maxListHeight: nil
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PhotoLogGroupSectionView: View {
    let appState: AppState
    let group: PhotoLogGroupSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(group.scopeLabel, systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if !group.sourceIsAvailable {
                    PhotoLogBadge("Missing Source", systemImage: "exclamationmark.triangle", tint: .orange)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(group.logs.enumerated()), id: \.element.id) { index, log in
                    PhotoLogRowView(appState: appState, log: log)
                        .padding(.vertical, 9)

                    if index < group.logs.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct PhotoLogRowView: View {
    let appState: AppState
    let log: PhotoLogSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: log.isMembershipLocked ? "lock" : "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(log.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        if log.isCurrentSession {
                            PhotoLogBadge("Current", systemImage: "checkmark.circle", tint: .green)
                        }
                        PhotoLogBadge(statusLabel, systemImage: statusImage, tint: .secondary)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], alignment: .leading, spacing: 6) {
                PhotoLogMetricBadge(label: "Items", value: "\(log.itemCount)")
                PhotoLogMetricBadge(label: "S", value: "\(log.includedCount)")
                PhotoLogMetricBadge(label: "C", value: "\(log.candidateCount)")
                PhotoLogMetricBadge(label: "X", value: "\(log.excludedCount)")
            }

            Label {
                Text(log.workspaceSourceFolderPath)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            } icon: {
                Image(systemName: "folder")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            PhotoLogActionGrid(appState: appState, log: log)

            if let lockMessage = log.membershipLockMessage {
                Label(lockMessage, systemImage: "lock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusLabel: String {
        log.status
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private var statusImage: String {
        switch log.status {
        case "imported", "source_cleanup_pending", "source_cleaned":
            return "checkmark.seal"
        default:
            return "doc.text"
        }
    }
}

private struct PhotoLogActionGrid: View {
    let appState: AppState
    let log: PhotoLogSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 6)], alignment: .leading, spacing: 6) {
            if !log.isCurrentSession {
                Button("Continue") {
                    appState.openPhotoLog(log.sessionID)
                }
                .buttonStyle(.borderedProminent)
                .help("Open this photo log to continue marking S/C/X and copy included files.")
            }

            Button("Contents") {
                appState.showPhotoLogContents(log.sessionID)
            }
            .buttonStyle(.bordered)
            .help("Show the files owned by this photo log.")

            Button(PhotoLogStatusPolicy.detailsActionTitle) {
                appState.presentPhotoLogEditor(log.sessionID)
            }
            .buttonStyle(.bordered)
            .help(PhotoLogStatusPolicy.detailsHelp)

            Button(PhotoLogStatusPolicy.editLogActionTitle) {
                appState.editPhotoLogMembership(log.sessionID)
            }
            .buttonStyle(.bordered)
            .disabled(log.isMembershipLocked)
            .help(log.membershipLockMessage ?? PhotoLogStatusPolicy.editLogHelp)

            if appState.canAddCurrentSourceDecisions(to: log.sessionID) {
                Button("Add Marked") {
                    appState.addCurrentSourceDecisions(to: log.sessionID)
                }
                .buttonStyle(.borderedProminent)
                .help("Add the current source-inbox S/C/X choices to this photo log.")
            }

            Button("Delete") {
                appState.deletePhotoLog(log.sessionID)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(log.isMembershipLocked)
            .help(log.isMembershipLocked ? "Copied or cleaned logs cannot be deleted from here." : "Delete this photo log and return uncopied photos to the source inbox.")
        }
        .controlSize(.small)
    }
}

private struct PhotoLogBadge: View {
    let title: String
    let systemImage: String
    let tint: AnyShapeStyle

    init(_ title: String, systemImage: String, tint: some ShapeStyle) {
        self.title = title
        self.systemImage = systemImage
        self.tint = AnyShapeStyle(tint)
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

private struct PhotoLogMetricBadge: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}
