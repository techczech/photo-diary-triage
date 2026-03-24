import AppKit
import SwiftUI

struct KeyboardHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            shortcut("I", "Mark selected photos for import when the review grid is focused")
            shortcut("D", "Unmark selected photos when the review grid is focused")
            shortcut("R", "Toggle RAW companion import when the review grid is focused")
            shortcut("S", "Select only the focused photo when the review grid is focused")
            shortcut("A", "Select all visible photos when the review grid is focused")
            shortcut("Space", "Toggle focused photo selection")
            shortcut("Arrow Keys", "Move grid focus; hold Shift to extend selection")
            shortcut("Return", "Open focused photo preview")
            shortcut("C", "Open side-by-side compare for the current photo selection")
            shortcut("Escape", "Exit review-grid keyboard focus before using parent navigation")
            shortcut("+ / - / 0", "Resize review cards when the grid is focused, or change compare layout density when compare is open")
            shortcut("Option + / - / 0", "Zoom images inside compare without changing the compare card layout")
            shortcut("Cmd-O", "Choose source folder")
            shortcut("Cmd-I", "Mark current selection for import")
            shortcut("Cmd-Shift-I", "Remove current selection from import")
            shortcut("Cmd-Option-R", "Toggle RAW companion import for selected photos")
            shortcut("Cmd-Shift-C", "Open compare from the menu command path")
            shortcut("Cmd-Shift-/", "Show this shortcuts panel")

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 320)
    }

    private func shortcut(_ key: String, _ description: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .frame(width: 150, alignment: .leading)
            Text(description)
            Spacer()
        }
    }
}

struct ReviewKeyInputView: NSViewRepresentable {
    let isFocused: Bool
    let onArrow: (_ dx: Int, _ dy: Int, _ extending: Bool) -> Void
    let onSingleKey: (_ key: String) -> Void
    let onSpace: () -> Void
    let onOpen: () -> Void
    let onEscape: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void

    func makeNSView(context: Context) -> ReviewKeyResponderView {
        let view = ReviewKeyResponderView()
        view.onArrow = onArrow
        view.onSingleKey = onSingleKey
        view.onSpace = onSpace
        view.onOpen = onOpen
        view.onEscape = onEscape
        view.onSelectAll = onSelectAll
        view.onDeselectAll = onDeselectAll
        view.onZoomIn = onZoomIn
        view.onZoomOut = onZoomOut
        view.onZoomReset = onZoomReset
        return view
    }

    func updateNSView(_ nsView: ReviewKeyResponderView, context: Context) {
        nsView.onArrow = onArrow
        nsView.onSingleKey = onSingleKey
        nsView.onSpace = onSpace
        nsView.onOpen = onOpen
        nsView.onEscape = onEscape
        nsView.onSelectAll = onSelectAll
        nsView.onDeselectAll = onDeselectAll
        nsView.onZoomIn = onZoomIn
        nsView.onZoomOut = onZoomOut
        nsView.onZoomReset = onZoomReset

        if isFocused != nsView.isHandlingKeys {
            nsView.isHandlingKeys = isFocused
            if isFocused, nsView.window?.firstResponder !== nsView {
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }
}

final class ReviewKeyResponderView: NSView {
    var isHandlingKeys = false
    var onArrow: ((_ dx: Int, _ dy: Int, _ extending: Bool) -> Void)?
    var onSingleKey: ((_ key: String) -> Void)?
    var onSpace: (() -> Void)?
    var onOpen: (() -> Void)?
    var onEscape: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    var onZoomReset: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isHandlingKeys else {
            super.keyDown(with: event)
            return
        }

        let extending = event.modifierFlags.contains(.shift)
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.uppercased() {
            if chars == "A" {
                if event.modifierFlags.contains(.shift) {
                    onDeselectAll?()
                } else {
                    onSelectAll?()
                }
                return
            }
        }

        switch event.keyCode {
        case 123:
            onArrow?(-1, 0, extending)
        case 124:
            onArrow?(1, 0, extending)
        case 125:
            onArrow?(0, 1, extending)
        case 126:
            onArrow?(0, -1, extending)
        case 49:
            onSpace?()
        case 36:
            onOpen?()
        case 53:
            onEscape?()
        default:
            guard let rawText = event.charactersIgnoringModifiers else {
                super.keyDown(with: event)
                return
            }

            let text = rawText.uppercased()
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                super.keyDown(with: event)
            } else if rawText == "=" || rawText == "+" {
                onZoomIn?()
            } else if rawText == "-" || rawText == "_" {
                onZoomOut?()
            } else if rawText == "0" {
                onZoomReset?()
            } else if ["I", "D", "R", "A", "S", "C"].contains(text) {
                onSingleKey?(text)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

struct FullPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    let item: MediaItem
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.title3.weight(.semibold))
                    Text(item.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Previous") {
                    appState.navigatePreview(by: -1)
                }
                .disabled(!appState.canNavigatePreviewBackward)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Next") {
                    appState.navigatePreview(by: 1)
                }
                .disabled(!appState.canNavigatePreviewForward)
                .keyboardShortcut(.rightArrow, modifiers: [])

                ZoomToolbar(zoom: $zoom)
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ZoomableImageCanvas(imageURL: item.sourceURL, zoom: zoom)
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 650)
    }
}

struct CompareSheet: View {
    @ObservedObject var appState: AppState
    let title: String
    let items: [MediaItem]
    let onClose: () -> Void
    @State private var zoom: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2.weight(.semibold))
                        Text("\(items.count) selected image(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    compareLayoutControls
                    ZoomToolbar(zoom: $zoom, keyboardModifiers: [.option])
                    Button("Close") {
                        onClose()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                if items.isEmpty {
                    ContentUnavailableView("No Images Selected", systemImage: "rectangle.on.rectangle", description: Text("Select at least two images in the grid and use Compare."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let metrics = CompareGridMetrics(
                        availableWidth: proxy.size.width,
                        targetCardWidth: appState.compareGridCardWidth,
                        itemCount: items.count
                    )
                    let columns = Array(
                        repeating: GridItem(
                            .fixed(CGFloat(metrics.cardWidth)),
                            spacing: CGFloat(CompareGridMetrics.gridSpacing),
                            alignment: .top
                        ),
                        count: max(metrics.columnCount, 1)
                    )

                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: CGFloat(CompareGridMetrics.gridSpacing)) {
                            ForEach(items) { item in
                                CompareItemCard(
                                    appState: appState,
                                    item: item,
                                    zoom: zoom,
                                    cardWidth: CGFloat(metrics.cardWidth),
                                    imageHeight: CGFloat(metrics.imageHeight)
                                )
                                .frame(width: CGFloat(metrics.cardWidth), alignment: .topLeading)
                            }
                        }
                        .padding(CGFloat(CompareGridMetrics.gridPadding))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compareLayoutControls: some View {
        HStack(spacing: 6) {
            Button {
                appState.decreaseCompareGridCardWidth()
            } label: {
                Image(systemName: "minus.rectangle.on.rectangle")
            }
            .help("Fit more compare items on screen")
            .disabled(appState.compareGridCardWidth <= CompareGridMetrics.minCardWidth)

            Text("\(Int(appState.compareGridCardWidth))")
                .font(.caption.monospacedDigit())
                .frame(width: 40)

            Button {
                appState.increaseCompareGridCardWidth()
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
            .help("Make compare items larger")
            .disabled(appState.compareGridCardWidth >= CompareGridMetrics.maxCardWidth)

            Button {
                appState.resetCompareGridCardWidth()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset compare layout size")
            .disabled(appState.compareGridCardWidth == CompareGridMetrics.defaultCardWidth)
        }
        .buttonStyle(.bordered)
    }
}

struct CompareItemCard: View {
    @ObservedObject var appState: AppState
    let item: MediaItem
    let zoom: CGFloat
    let cardWidth: CGFloat
    let imageHeight: CGFloat

    private var isSelected: Bool {
        appState.selectedMediaItemIDs.contains(item.id)
    }

    private var isFocused: Bool {
        appState.focusedReviewItemID == item.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(item.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(item.selectionState == .selected ? "Marked" : "Not Marked")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.selectionState == .selected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            ZoomableImageCanvas(imageURL: item.sourceURL, zoom: zoom)
                .frame(width: cardWidth - 22, height: imageHeight)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    ReviewGridClickTarget { click in
                        appState.handleGridSelection(for: item.id, click: click)
                    }
                }

            HStack {
                Button("Select Only") {
                    appState.selectMediaItems([item.id])
                }

                Button("Toggle Selection") {
                    appState.toggleSelectionForComparisonItem(item.id)
                }

                Button("Preview") {
                    appState.selectMediaItems([item.id])
                    appState.openFocusedReviewItem()
                }
            }
            .buttonStyle(.bordered)

            if appState.canMutateImportSelection {
                HStack {
                    Button(item.selectionState == .selected ? "Unmark" : "Mark") {
                        appState.selectMediaItems([item.id])
                        if item.selectionState == .selected {
                            appState.unmarkCurrentSelectionForImport()
                        } else {
                            appState.markCurrentSelectionForImport()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if !item.companionFiles.isEmpty {
                        Toggle("RAW", isOn: Binding(
                            get: { item.importRawCompanions },
                            set: { appState.setImportRawCompanions(for: item, enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                    }

                    Spacer()
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.07))
            }
        }
        .overlay {
            if isSelected || isFocused {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 2)
            }
        }
    }
}

struct ZoomToolbar: View {
    @Binding var zoom: CGFloat
    var keyboardModifiers: EventModifiers = []

    var body: some View {
        HStack(spacing: 8) {
            Button("−") {
                zoom = max(0.25, zoom - 0.25)
            }
            .keyboardShortcut("-", modifiers: keyboardModifiers)

            Button("100%") {
                zoom = 1
            }
            .keyboardShortcut("0", modifiers: keyboardModifiers)

            Button("+") {
                zoom = min(4, zoom + 0.25)
            }
            .keyboardShortcut("+", modifiers: keyboardModifiers)

            Text("\(Int(zoom * 100))%")
                .font(.caption.monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct ZoomableImageCanvas: View {
    let imageURL: URL
    let zoom: CGFloat

    var body: some View {
        GeometryReader { proxy in
            if let image = NSImage(contentsOf: imageURL) {
                let imageSize = image.size
                let fitScale = min(
                    proxy.size.width / max(imageSize.width, 1),
                    proxy.size.height / max(imageSize.height, 1)
                )
                let displayScale = max(fitScale, 0.01) * zoom

                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(
                            width: max(1, imageSize.width * displayScale),
                            height: max(1, imageSize.height * displayScale)
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(Text("Unable to load full photo"))
            }
        }
    }
}

struct ReviewGridClickTarget: NSViewRepresentable {
    let onClick: (ReviewGridClickContext) -> Void

    func makeNSView(context: Context) -> ReviewGridClickView {
        let view = ReviewGridClickView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: ReviewGridClickView, context: Context) {
        nsView.onClick = onClick
    }
}

final class ReviewGridClickView: NSView {
    var onClick: ((ReviewGridClickContext) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(ReviewGridClickContext(modifiers: event.modifierFlags, clickCount: event.clickCount))
    }
}
