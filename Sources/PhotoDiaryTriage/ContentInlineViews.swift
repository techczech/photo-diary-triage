import AppKit
import SwiftUI

struct InlineSectionNodeView: View {
    @ObservedObject var appState: AppState
    let section: InlineSection
    let sectionPath: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    appState.toggleInlineSectionExpansion(section.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: appState.isInlineSectionExpanded(section.id) ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                        Text(section.title)
                            .font(headerFont)
                        Text("\(section.mediaItemIDs.count) photo(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if canCompareSection {
                    Button("Compare") {
                        appState.openComparison(for: section.mediaItemIDs, title: "Compare \(section.title)")
                    }
                    .buttonStyle(.bordered)
                }
            }

            TinyPreviewStrip(
                items: appState.previewItems(for: section),
                appState: appState,
                onSelectItem: { itemID in
                    appState.revealInlineMediaItem(itemID, sectionPath: sectionPath)
                }
            )

            if appState.isInlineSectionExpanded(section.id) {
                if !section.children.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(section.children) { child in
                            InlineSectionNodeView(
                                appState: appState,
                                section: child,
                                sectionPath: sectionPath + [child.id]
                            )
                        }
                    }
                }

                if !section.photoItemIDs.isEmpty {
                    InlinePhotoGrid(items: appState.mediaItems(for: section.photoItemIDs), appState: appState)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var headerFont: Font {
        switch section.kind {
        case .day:
            return .headline
        case .cluster, .burst, .remainder:
            return .subheadline.weight(.semibold)
        }
    }

    private var canCompareSection: Bool {
        switch section.kind {
        case .cluster, .burst:
            return section.mediaItemIDs.count >= 2
        case .day, .remainder:
            return false
        }
    }
}

struct TinyPreviewStrip: View {
    let items: [MediaItem]
    @ObservedObject var appState: AppState
    let onSelectItem: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.prefix(18))) { item in
                    Button {
                        onSelectItem(item.id)
                    } label: {
                        tinyThumb(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func tinyThumb(for item: MediaItem) -> some View {
        if let image = NSImage(contentsOf: appState.thumbnailURL(for: item)) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 70, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 70, height: 48)
        }
    }
}

struct InlinePhotoGrid: View {
    let items: [MediaItem]
    @ObservedObject var appState: AppState

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    if let image = NSImage(contentsOf: appState.thumbnailURL(for: item)) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .frame(height: 76)
                    }
                    Text(item.fileName)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(appState.selectedMediaItemIDs.contains(item.id) ? Color.accentColor.opacity(0.10) : Color.clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(appState.selectedMediaItemIDs.contains(item.id) ? Color.accentColor : Color.clear, lineWidth: 2)
                }
                .overlay(
                    InlineGridClickTarget(
                        onSingleClick: {
                            appState.selectInlineMediaItem(item.id)
                        },
                        onDoubleClick: {
                            appState.selectInlineMediaItem(item.id)
                            appState.openFocusedReviewItem()
                        }
                    )
                )
                .id(item.id)
            }
        }
    }
}

struct InlineGridClickTarget: NSViewRepresentable {
    let onSingleClick: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> InlineGridClickView {
        let view = InlineGridClickView()
        view.onSingleClick = onSingleClick
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: InlineGridClickView, context: Context) {
        nsView.onSingleClick = onSingleClick
        nsView.onDoubleClick = onDoubleClick
    }
}

final class InlineGridClickView: NSView {
    var onSingleClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        } else {
            onSingleClick?()
        }
    }
}
