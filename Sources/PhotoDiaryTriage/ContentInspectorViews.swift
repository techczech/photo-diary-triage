import AppKit
import SwiftUI

struct InspectorCollapsedRail: View {
    @ObservedObject var appState: AppState

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
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Inspector")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Close") {
                        appState.toggleDetailsInspector()
                    }
                }

                folderSection
                photoSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var folderSection: some View {
        GroupBox("Current Folder") {
            VStack(alignment: .leading, spacing: 8) {
                if let node = appState.inspectorBrowserNode {
                    inspectorRow("Name", node.title)
                    inspectorRow("Kind", kindLabel(node.kind))
                    inspectorRow("Photos", "\(node.mediaItemIDs.count)")
                    inspectorRow("Children", "\(node.children?.count ?? 0)")
                    if let subtitle = node.subtitle?.nonEmpty {
                        inspectorRow("Summary", subtitle)
                    }
                    if let folderURL = node.folderURL {
                        inspectorRow("Path", folderURL.path)
                    } else if node.kind == .sessionRoot, let session = appState.currentSession {
                        inspectorRow("Path", session.sourceFolder.path)
                    }
                    if let session = appState.currentSession {
                        if let title = session.walkMetadata.title.nonEmpty {
                            inspectorRow("Walk Title", title)
                        }
                        if let location = session.walkMetadata.location.nonEmpty {
                            inspectorRow("Location", location)
                        }
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
                if let item = appState.inspectorMediaItem {
                    if let image = appState.thumbnailImage(for: item) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.quaternary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .overlay(ProgressView())
                    }

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
            .task(id: appState.inspectorMediaItem?.id) {
                if let item = appState.inspectorMediaItem {
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
