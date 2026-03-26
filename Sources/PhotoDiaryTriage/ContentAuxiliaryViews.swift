import AppKit
import SwiftUI

private struct ShortcutHintBubble: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThickMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .allowsHitTesting(false)
    }
}

private struct ShortcutHintModifier: ViewModifier {
    let shortcut: String
    let helpText: String
    let alignment: Alignment
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .help(helpText)
            .onHover { hovering in
                isHovering = hovering
            }
            .overlay(alignment: alignment) {
                if isHovering {
                    ShortcutHintBubble(shortcut: shortcut)
                        .scaleEffect(0.82)
                        .padding(6)
                }
            }
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}

extension View {
    func shortcutHint(_ shortcut: String, help: String? = nil, alignment: Alignment = .topTrailing) -> some View {
        modifier(ShortcutHintModifier(shortcut: shortcut, helpText: help ?? shortcut, alignment: alignment))
    }
}

struct KeyboardHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.title2.weight(.bold))
                    Text("Review, grouped navigation, compare, and global commands.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    shortcutSection("Review Selection", rows: [
                        ("Arrow Keys", "Move grid focus; hold Shift to extend selection."),
                        ("Space", "Toggle the focused photo selection."),
                        ("I", "Include the current selection for import."),
                        ("X", "Exclude the current selection from import."),
                        ("D", "Clear the current selection back to undecided."),
                        ("R", "Toggle RAW companion import for the current selection."),
                        ("S", "Keep only the focused photo selected."),
                        ("A", "Select all visible photos."),
                        ("C", "Open compare for the current selection."),
                        ("Return", "Open the focused photo preview, or enter the focused grouped section for item navigation."),
                        ("Escape", "Return to grouped-section selection, or exit review-grid keyboard focus.")
                    ])

                    shortcutSection("Grouped Review", rows: [
                        ("Up / Down", "When a group header is focused, move between grouped sections."),
                        ("Left / Right", "When a group header is focused, collapse or expand that section."),
                        ("Option + Up / Down", "Jump into grouped-section navigation from item focus."),
                        ("Option + Left / Right", "Collapse or expand the focused grouped section from item focus."),
                        ("Cmd-Option-[ / ]", "Collapse or expand all grouped sections."),
                        ("Cmd-Control-1...4", "Switch grouped review organization mode.")
                    ])

                    shortcutSection("View And Compare", rows: [
                        ("+ / - / 0", "Resize review cards, or change compare layout density when compare is open."),
                        ("Option + + / - / 0", "Zoom compare images without changing the compare layout density."),
                        ("Cmd-3 / Cmd-4", "Switch flat review or grouped review."),
                        ("Cmd-Control-A / I / X / U", "Filter review items to all, included, excluded, or undecided."),
                        ("Cmd-Option-G / Cmd-Option-L", "Switch grid or list layout."),
                        ("Cmd-Shift-C", "Open compare from the command menu path.")
                    ])

                    shortcutSection("Focus And Global Commands", rows: [
                        ("Cmd-O", "Choose a source folder."),
                        ("Cmd-1 / Cmd-2", "Focus sidebar navigation or jump into the review grid."),
                        ("Cmd-Return", "Open the current item, jump from sidebar into review, or drill into the focused grouped section."),
                        ("Cmd-Option-I", "Toggle the right-side inspector."),
                        ("Cmd-Option-S", "Toggle the left sidebar."),
                        ("Cmd-I", "Mark the current selection for import."),
                        ("Cmd-Shift-X", "Exclude the current selection from import."),
                        ("Cmd-Shift-I", "Remove the current selection from import."),
                        ("Cmd-Shift-M", "Copy marked files into the archive."),
                        ("Cmd-Shift-B", "Confirm backup and enable cleanup."),
                        ("Cmd-Shift-K", "Clean imported files from the SSD."),
                        ("Cmd-Shift-/", "Open this shortcuts panel.")
                    ])
                }
                .padding(.trailing, 8)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 620)
    }

    private func shortcutSection(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                shortcutRow(row.0, row.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
    }

    private func shortcutRow(_ key: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(key)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .frame(width: 190, alignment: .leading)
            Text(description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct ReviewKeyInputView: NSViewRepresentable {
    let isFocused: Bool
    let onArrow: (_ dx: Int, _ dy: Int, _ extending: Bool) -> Void
    let onSectionArrow: (_ dx: Int, _ dy: Int) -> Void
    let onSectionExpandCollapse: (_ expand: Bool) -> Void
    let onSingleKey: (_ key: String) -> Void
    let onSpace: () -> Void
    let onOpen: () -> Void
    let onCommandOpen: () -> Void
    let onEscape: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void

    func makeNSView(context: Context) -> ReviewKeyResponderView {
        let view = ReviewKeyResponderView()
        view.onArrow = onArrow
        view.onSectionArrow = onSectionArrow
        view.onSectionExpandCollapse = onSectionExpandCollapse
        view.onSingleKey = onSingleKey
        view.onSpace = onSpace
        view.onOpen = onOpen
        view.onCommandOpen = onCommandOpen
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
        nsView.onSectionArrow = onSectionArrow
        nsView.onSectionExpandCollapse = onSectionExpandCollapse
        nsView.onSingleKey = onSingleKey
        nsView.onSpace = onSpace
        nsView.onOpen = onOpen
        nsView.onCommandOpen = onCommandOpen
        nsView.onEscape = onEscape
        nsView.onSelectAll = onSelectAll
        nsView.onDeselectAll = onDeselectAll
        nsView.onZoomIn = onZoomIn
        nsView.onZoomOut = onZoomOut
        nsView.onZoomReset = onZoomReset

        nsView.isHandlingKeys = isFocused
        if isFocused, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

final class ReviewKeyResponderView: NSView {
    var isHandlingKeys = false
    var onArrow: ((_ dx: Int, _ dy: Int, _ extending: Bool) -> Void)?
    var onSectionArrow: ((_ dx: Int, _ dy: Int) -> Void)?
    var onSectionExpandCollapse: ((_ expand: Bool) -> Void)?
    var onSingleKey: ((_ key: String) -> Void)?
    var onSpace: (() -> Void)?
    var onOpen: (() -> Void)?
    var onCommandOpen: (() -> Void)?
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
        let hasOptionModifier = event.modifierFlags.contains(.option)
        let hasCommandModifier = event.modifierFlags.contains(.command)
        let hasControlModifier = event.modifierFlags.contains(.control)
        if hasCommandModifier,
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
            if hasOptionModifier {
                onSectionExpandCollapse?(false)
            } else {
                onArrow?(-1, 0, extending)
            }
        case 124:
            if hasOptionModifier {
                onSectionExpandCollapse?(true)
            } else {
                onArrow?(1, 0, extending)
            }
        case 125:
            if hasOptionModifier {
                onSectionArrow?(0, 1)
            } else {
                onArrow?(0, 1, extending)
            }
        case 126:
            if hasOptionModifier {
                onSectionArrow?(0, -1)
            } else {
                onArrow?(0, -1, extending)
            }
        case 49:
            onSpace?()
        case 36:
            if hasCommandModifier || hasControlModifier {
                onCommandOpen?()
            } else {
                onOpen?()
            }
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
                .shortcutHint("Left", help: "Show the previous visible photo (Left Arrow)")

                Button("Next") {
                    appState.navigatePreview(by: 1)
                }
                .disabled(!appState.canNavigatePreviewForward)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .shortcutHint("Right", help: "Show the next visible photo (Right Arrow)")

                ZoomToolbar(zoom: $zoom)
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .shortcutHint("Escape", help: "Close preview (Escape)")
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
                    .shortcutHint("Escape", help: "Close compare (Escape)")
                }

                if items.isEmpty {
                    ContentUnavailableView("No Images Selected", systemImage: "rectangle.on.rectangle", description: Text("Select at least two images in the grid and use Compare."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let metrics = CompareGridMetrics(
                        availableWidth: proxy.size.width,
                        targetCardWidth: appState.compareGridCardWidth,
                        itemCount: items.count,
                        zoomScale: zoom
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
            .shortcutHint("-", help: "Fit more compare items on screen (-)")
            .disabled(appState.compareGridCardWidth <= CompareGridMetrics.minCardWidth)

            Text("\(Int(appState.compareGridCardWidth))")
                .font(.caption.monospacedDigit())
                .frame(width: 40)

            Button {
                appState.increaseCompareGridCardWidth()
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
            }
            .shortcutHint("+", help: "Make compare items larger (+)")
            .disabled(appState.compareGridCardWidth >= CompareGridMetrics.maxCardWidth)

            Button {
                appState.resetCompareGridCardWidth()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .shortcutHint("0", help: "Reset compare layout size (0)")
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
                Text(item.selectionState.statusLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBadgeColor(for: item.selectionState))
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
                .help("Select only this item")

                Button("Toggle Selection") {
                    appState.toggleSelectionForComparisonItem(item.id)
                }
                .help("Toggle this item in the current selection")

                Button("Preview") {
                    appState.selectMediaItems([item.id])
                    appState.openFocusedReviewItem()
                }
                .help("Open this item in preview")
            }
            .buttonStyle(.bordered)

            if appState.canMutateImportSelection {
                HStack {
                    Button("Include") {
                        appState.selectMediaItems([item.id])
                        appState.markCurrentSelectionForImport()
                    }
                    .buttonStyle(.bordered)
                    .disabled(item.selectionState.isIncluded)
                    .shortcutHint("I / Cmd-I", help: "Include this item for import")

                    Button("Exclude") {
                        appState.selectMediaItems([item.id])
                        appState.excludeCurrentSelectionFromImport()
                    }
                    .buttonStyle(.bordered)
                    .disabled(item.selectionState.isExcluded)
                    .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import")

                    if !item.selectionState.isUndecided {
                        Button("Clear") {
                            appState.selectMediaItems([item.id])
                            appState.unmarkCurrentSelectionForImport()
                        }
                        .buttonStyle(.bordered)
                        .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided")
                    }

                    if !item.companionFiles.isEmpty {
                        Toggle("RAW", isOn: Binding(
                            get: { item.importRawCompanions },
                            set: { appState.setImportRawCompanions(for: item, enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .shortcutHint("R / Cmd-Option-R", help: "Include RAW companions for this compare item")
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
            if isSelected || isFocused {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 2)
            }
        }
    }

    private func statusBadgeColor(for selectionState: SelectionState) -> Color {
        switch selectionState {
        case .included:
            return Color.accentColor.opacity(0.15)
        case .excluded:
            return Color.red.opacity(0.14)
        case .undecided:
            return Color.secondary.opacity(0.12)
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
            .shortcutHint(keyboardModifiers.isEmpty ? "-" : "Option--", help: keyboardModifiers.isEmpty ? "Zoom out (-)" : "Zoom out (Option--)")

            Button("100%") {
                zoom = 1
            }
            .keyboardShortcut("0", modifiers: keyboardModifiers)
            .shortcutHint(keyboardModifiers.isEmpty ? "0" : "Option-0", help: keyboardModifiers.isEmpty ? "Reset zoom (0)" : "Reset compare zoom (Option-0)")

            Button("+") {
                zoom = min(4, zoom + 0.25)
            }
            .keyboardShortcut("+", modifiers: keyboardModifiers)
            .shortcutHint(keyboardModifiers.isEmpty ? "+" : "Option-+", help: keyboardModifiers.isEmpty ? "Zoom in (+)" : "Zoom in (Option-+)")

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
