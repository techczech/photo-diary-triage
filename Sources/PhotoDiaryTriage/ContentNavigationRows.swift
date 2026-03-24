import SwiftUI

struct SidebarNodeRow: View {
    let node: BrowserNode

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: iconName)
        }
    }

    private var iconName: String {
        switch node.kind {
        case .sessionSection:
            return "square.stack"
        case .archiveSection:
            return "books.vertical"
        case .sessionRoot:
            return "externaldrive"
        case .archiveRoot:
            return "archivebox"
        case .archiveWalkFolder:
            return "photo.on.rectangle"
        case .year, .month, .day, .unknownDate, .photosFolder, .burstsFolder, .timeClustersFolder:
            return "folder"
        case .burstGroup, .timeCluster:
            return "folder.badge.person.crop"
        }
    }
}

struct FolderNodeRow: View {
    let node: BrowserNode

    var body: some View {
        HStack {
            Image(systemName: "folder")
            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                if let subtitle = node.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}
