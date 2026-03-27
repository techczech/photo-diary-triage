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
                        ("S", "Select the current selection for import."),
                        ("C", "Mark the current selection as candidate."),
                        ("X", "Exclude the current selection from import."),
                        ("D", "Clear the current selection back to undecided."),
                        ("R", "Toggle RAW companion import for the current selection."),
                        ("A", "Select all visible photos."),
                        ("Cmd-Shift-C", "Open compare for the current selection."),
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
                        ("+ / - / 0", "Change review grid columns, or zoom compare images when compare is open. Reset returns compare to Fit."),
                        ("Q", "When compare is open, remove the focused compare item."),
                        ("H / J / K / L", "When compare is zoomed, pan the focused image. With Lock Pan on, all compare images pan together."),
                        ("Cmd-3 / Cmd-4", "Switch flat review or grouped review."),
                        ("Cmd-Control-A / I / C / X / U", "Filter review items to all, included, candidate, excluded, or undecided."),
                        ("Cmd-Option-G / Cmd-Option-L", "Switch grid or list layout."),
                        ("Cmd-Shift-C", "Open compare from the command menu path.")
                    ])

                    shortcutSection("Focus And Global Commands", rows: [
                        ("Cmd-O", "Choose a source folder."),
                        ("Cmd-1 / Cmd-2", "Focus sidebar navigation or jump into the review grid."),
                        ("Cmd-Return", "Open the current item, jump from sidebar into review, or drill into the focused grouped section."),
                        ("Cmd-Option-I", "Toggle the right-side inspector."),
                        ("Cmd-Option-S", "Toggle the left sidebar."),
                        ("Cmd-I", "Select the current selection for import."),
                        ("Cmd-Shift-X", "Exclude the current selection from import."),
                        ("Cmd-Shift-I", "Remove the current selection from import."),
                        ("Cmd-Shift-M", "Copy marked files into the archive."),
                        ("Cmd-Shift-B", "Confirm backup and enable cleanup."),
                        ("Cmd-Shift-K", "Clean imported files from the SSD."),
                        ("Cmd-Shift-W", "Create a photo log from the current scope."),
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

struct PhotoLogEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let appState: AppState
    @State private var editor: PhotoLogEditorState

    init(appState: AppState, editor: PhotoLogEditorState) {
        self.appState = appState
        _editor = State(initialValue: editor)
    }

    private var creationPlan: PhotoLogCreationPlan? {
        guard case .create = editor.mode else { return nil }
        return appState.proposedPhotoLogCreationPlan(mode: editor.creationMode)
    }

    private var sourceScopeSummary: String {
        creationPlan.map { "\($0.scope.kind.title) • \($0.scope.label)" } ?? "No creation scope available."
    }

    private var createDisabled: Bool {
        creationPlan?.canCreate != true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sheetTitle)
                        .font(.title2.weight(.bold))
                    Text(sheetSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    appState.dismissPhotoLogEditor()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metadataSection

                    if case .create = editor.mode {
                        creationSection
                    }

                    scopeSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
            }

            HStack(spacing: 8) {
                Spacer()
                switch editor.mode {
                case .create:
                    Button("Create Log") {
                        appState.updateActivePhotoLogEditor(editor)
                        appState.createPhotoLog(openAfterCreate: false)
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(createDisabled)

                    Button("Create And Open") {
                        appState.updateActivePhotoLogEditor(editor)
                        appState.createPhotoLog(openAfterCreate: true)
                    }
                    .disabled(createDisabled)
                case .edit:
                    Button("Save Changes") {
                        appState.updateActivePhotoLogEditor(editor)
                        appState.saveActivePhotoLogEdits()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 700, minHeight: 620)
        .onDisappear {
            if appState.presentationState.snapshot.activePhotoLogEditor != nil {
                appState.updateActivePhotoLogEditor(editor)
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Details")

            TextField("Photo Log Title", text: $editor.title)
            TextField("Location", text: $editor.location)
            TextField("Notes", text: $editor.notes, axis: .vertical)
                .lineLimit(4...8)
        }
        .sheetSectionStyle()
    }

    private var creationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Creation Plan")

            Picker("Membership", selection: $editor.creationMode) {
                ForEach(PhotoLogCreationMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            keyValueRow("Primary Scope", sourceScopeSummary)

            if let plan = creationPlan {
                keyValueRow("Included", "\(plan.counts.included)")
                keyValueRow("Candidate", "\(plan.counts.candidate)")
                keyValueRow("Excluded", "\(plan.counts.excluded)")
                keyValueRow("Undecided", "\(plan.counts.undecided)")
                keyValueRow("Final Member Count", "\(plan.candidateCount)")

                if let disabledReason = plan.disabledReason {
                    Text(disabledReason)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !plan.collisions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Owned By Another Photo Log")
                            .font(.caption.weight(.semibold))
                        ForEach(plan.collisions, id: \.relativePath) { collision in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(collision.owningTitle)
                                        .font(.caption.weight(.semibold))
                                    Text(collision.relativePath)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Open Existing Log") {
                                    appState.dismissPhotoLogEditor()
                                    appState.openPhotoLog(collision.owningSessionID)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("Focus the review grid or select one folder before creating a photo log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheetSectionStyle()
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Primary Scope")

            Picker("Scope Type", selection: $editor.scopeKind) {
                ForEach(PhotoLogScopeKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            TextField(scopeLabelPrompt, text: $editor.scopeLabel)

            if editor.scopeKind == .dateRange {
                DatePicker(
                    "Start",
                    selection: Binding(
                        get: { editor.startDate ?? Date() },
                        set: { editor.startDate = $0 }
                    ),
                    displayedComponents: [.date]
                )

                DatePicker(
                    "End",
                    selection: Binding(
                        get: { editor.endDate ?? editor.startDate ?? Date() },
                        set: { editor.endDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source Folders")
                        .font(.caption.weight(.semibold))
                    if editor.sourceFolderPaths.isEmpty {
                        Text("No source folders recorded.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(editor.sourceFolderPaths, id: \.self) { path in
                            Text(path)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .sheetSectionStyle()
    }

    private var sheetTitle: String {
        switch editor.mode {
        case .create:
            return "Create Photo Log"
        case .edit:
            return "Edit Photo Log"
        }
    }

    private var sheetSubtitle: String {
        switch editor.mode {
        case .create:
            return "Review the source scope, membership counts, and ownership collisions before moving photos."
        case .edit:
            return "Update the title, notes, and primary scope without changing membership."
        }
    }

    private var scopeLabelPrompt: String {
        switch editor.scopeKind {
        case .folder:
            return "Folder Label"
        case .dateRange:
            return "Date Range Label"
        case .custom:
            return "Custom Scope Label"
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func keyValueRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.caption)
            Spacer(minLength: 0)
        }
    }
}

struct PhotoLogContentsSheet: View {
    let appState: AppState
    let revealed: PhotoLogRevealState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(revealed.title)
                        .font(.title2.weight(.bold))
                    Text("\(revealed.relativePaths.count) owned photo(s)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") {
                    appState.dismissRevealedPhotoLog()
                }
                .keyboardShortcut(.cancelAction)
            }

            if revealed.relativePaths.isEmpty {
                Text("This photo log does not currently own any photos.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                List(revealed.relativePaths, id: \.self) { relativePath in
                    Text(relativePath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                .listStyle(.inset)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
    }
}

private extension View {
    func sheetSectionStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
            }
    }
}

struct ReviewKeyInputView: NSViewRepresentable {
    let isFocused: Bool
    let onArrow: (_ dx: Int, _ dy: Int, _ extending: Bool) -> Void
    let onSectionArrow: (_ dx: Int, _ dy: Int) -> Void
    let onSectionExpandCollapse: (_ expand: Bool) -> Void
    let onSingleKey: (_ key: String) -> Void
    let onPan: ((_ dx: Int, _ dy: Int) -> Void)?
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
        view.onPan = onPan
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
        nsView.onPan = onPan
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
    var onPan: ((_ dx: Int, _ dy: Int) -> Void)?
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
            } else if let direction = CompareKeyboardPanDirection(key: text), let onPan {
                onPan(direction.dx, direction.dy)
            } else if ["S", "X", "D", "R", "A", "C"].contains(text) || (text == "Q" && onPan != nil) {
                onSingleKey?(text)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

struct ComparePanCommand: Equatable {
    let targetItemID: UUID?
    let dx: Int
    let dy: Int
    let revision: Int

    static let idle = ComparePanCommand(targetItemID: nil, dx: 0, dy: 0, revision: 0)
}

struct FullPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let appState: AppState
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
    let appState: AppState
    @ObservedObject var state: CompareState
    let onClose: () -> Void
    @State private var zoom: CGFloat = 1
    @State private var isPanLocked = true
    @State private var synchronizedViewport = CompareViewport.zero
    @State private var panCommand = ComparePanCommand.idle

    var body: some View {
        let snapshot = state.snapshot
        let scrollTargetID = snapshot.preferredScrollTargetID

        VStack(alignment: .leading, spacing: 18) {
            ReviewKeyInputView(
                isFocused: !snapshot.items.isEmpty,
                onArrow: { dx, dy, _ in
                    appState.moveComparisonFocus(dx: dx, dy: dy)
                },
                onSectionArrow: { _, _ in },
                onSectionExpandCollapse: { _ in },
                onSingleKey: { key in
                    appState.performCompareShortcut(key)
                },
                onPan: { dx, dy in
                    if isPanLocked {
                        synchronizedViewport = synchronizedViewport.nudged(dx: dx, dy: dy)
                    } else if let targetItemID = scrollTargetID {
                        panCommand = ComparePanCommand(
                            targetItemID: targetItemID,
                            dx: dx,
                            dy: dy,
                            revision: panCommand.revision &+ 1
                        )
                    }
                },
                onSpace: {
                    appState.toggleFocusedReviewItemSelection()
                },
                onOpen: {
                    appState.openFocusedReviewItem()
                },
                onCommandOpen: {
                    appState.openFocusedReviewItem()
                },
                onEscape: {
                    onClose()
                },
                onSelectAll: { },
                onDeselectAll: { },
                onZoomIn: {
                    zoom = min(4, zoom + 0.25)
                },
                onZoomOut: {
                    zoom = max(0.25, zoom - 0.25)
                },
                onZoomReset: {
                    zoom = 1
                }
            )
            .frame(width: 1, height: 1)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.title)
                        .font(.title2.weight(.semibold))
                    Text("\(snapshot.items.count) compare image(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                compareColumnControls
                Toggle("Lock Pan", isOn: $isPanLocked)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Keep compare items panned to the same relative detail area")
                ZoomToolbar(zoom: $zoom)
                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                .shortcutHint("Escape", help: "Close compare (Escape)")
            }

            if snapshot.items.isEmpty {
                ContentUnavailableView("No Images Selected", systemImage: "rectangle.on.rectangle", description: Text("Select at least two images in the grid and use Compare."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { gridProxy in
                    let metrics = CompareGridMetrics(
                        availableWidth: gridProxy.size.width,
                        requestedColumnCount: snapshot.gridColumnCount,
                        itemCount: snapshot.items.count
                    )
                    let columns = Array(
                        repeating: GridItem(
                            .fixed(CGFloat(metrics.cardWidth)),
                            spacing: CGFloat(CompareGridMetrics.gridSpacing),
                            alignment: .top
                        ),
                        count: max(metrics.columnCount, 1)
                    )

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: CGFloat(CompareGridMetrics.gridSpacing)) {
                                ForEach(snapshot.items) { itemSnapshot in
                                    CompareItemCard(
                                        appState: appState,
                                        snapshot: itemSnapshot,
                                        zoom: zoom,
                                        synchronizedViewport: $synchronizedViewport,
                                        panCommand: panCommand,
                                        isPanLocked: isPanLocked,
                                        imageWidth: CGFloat(metrics.imageWidth)
                                    )
                                    .frame(width: CGFloat(metrics.cardWidth), alignment: .topLeading)
                                    .id(itemSnapshot.id)
                                }
                            }
                            .padding(CGFloat(CompareGridMetrics.gridPadding))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .onAppear {
                            if let targetID = scrollTargetID {
                                proxy.scrollTo(targetID, anchor: .center)
                            }
                        }
                        .onChange(of: scrollTargetID) { _, targetID in
                            guard let targetID else { return }
                            proxy.scrollTo(targetID, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compareColumnControls: some View {
        HStack(spacing: 6) {
            Text("Columns")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                appState.decreaseCompareGridColumnCount()
            } label: {
                Image(systemName: "minus")
            }
            .disabled(state.snapshot.gridColumnCount <= 1)

            Text("\(min(state.snapshot.gridColumnCount, max(state.snapshot.items.count, 1)))")
                .font(.caption.monospacedDigit())
                .frame(width: 22)

            Button {
                appState.increaseCompareGridColumnCount()
            } label: {
                Image(systemName: "plus")
            }
            .disabled(state.snapshot.gridColumnCount >= max(state.snapshot.items.count, 1))

            Button {
                appState.resetCompareGridColumnCount()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(state.snapshot.gridColumnCount == CompareGridMetrics.defaultColumnCount(for: state.snapshot.items.count))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct CompareItemCard: View {
    let appState: AppState
    let snapshot: ReviewItemSnapshot
    let zoom: CGFloat
    @Binding var synchronizedViewport: CompareViewport
    let panCommand: ComparePanCommand
    let isPanLocked: Bool
    let imageWidth: CGFloat

    private var item: MediaItem {
        snapshot.item
    }

    private var imageHeight: CGFloat {
        max(imageWidth / CGFloat(item.displayAspectRatio), 1)
    }

    private var metadataSummary: String {
        var parts = [item.compactDisplayName]
        if let captured = item.compactCapturedAtLabel {
            parts.append(captured)
        }
        if item.importRawCompanions, !item.companionFiles.isEmpty {
            parts.append("RAW")
        }
        return parts.joined(separator: "  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Text(metadataSummary)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                Text(item.selectionState.statusLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBadgeColor(for: item.selectionState))
                    .clipShape(Capsule())

                if appState.canMutateImportSelection {
                    Button("S") {
                        appState.markComparisonItemForImport(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(item.selectionState.isIncluded)
                    .shortcutHint("S / Cmd-I", help: "Select this item for import")

                    Button("C") {
                        appState.markComparisonItemAsCandidate(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(item.selectionState.isCandidate)
                    .shortcutHint("C", help: "Mark this item as candidate")

                    Button("X") {
                        appState.excludeComparisonItemFromImport(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(item.selectionState.isExcluded)
                    .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import")

                    if !item.selectionState.isUndecided {
                        Button("D") {
                            appState.clearComparisonItemTriageState(item.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided")
                    }

                    if !item.companionFiles.isEmpty {
                        if item.importRawCompanions {
                            Button("R") {
                                appState.setImportRawCompanions(for: item, enabled: false)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .shortcutHint("R / Cmd-Option-R", help: "Toggle RAW companions for this compare item")
                        } else {
                            Button("R") {
                                appState.setImportRawCompanions(for: item, enabled: true)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .shortcutHint("R / Cmd-Option-R", help: "Toggle RAW companions for this compare item")
                        }
                    }
                }

                Button {
                    appState.removeItemFromComparison(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove this item from compare")
                .shortcutHint("Q", help: "Remove this item from compare (Q)", alignment: .topLeading)
            }

            LoadedLockedCompareImageCanvas(
                itemID: item.id,
                imageURL: item.sourceURL,
                zoom: zoom,
                synchronizedViewport: $synchronizedViewport,
                panCommand: panCommand,
                isPanLocked: isPanLocked
            )
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    ReviewGridClickTarget { click in
                        appState.handleGridSelection(for: item.id, click: click)
                    }
                }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .overlay {
            if snapshot.isSelected || snapshot.isFocused {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: snapshot.isSelected ? 3 : 2)
            }
        }
    }

    private func statusBadgeColor(for selectionState: SelectionState) -> Color {
        switch selectionState {
        case .included:
            return Color.accentColor.opacity(0.15)
        case .candidate:
            return Color.orange.opacity(0.18)
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

            Button("Fit") {
                zoom = 1
            }
            .keyboardShortcut("0", modifiers: keyboardModifiers)
            .shortcutHint(keyboardModifiers.isEmpty ? "0" : "Option-0", help: keyboardModifiers.isEmpty ? "Fit image to container (0)" : "Fit compare image to container (Option-0)")

            Button("+") {
                zoom = min(4, zoom + 0.25)
            }
            .keyboardShortcut("+", modifiers: keyboardModifiers)
            .shortcutHint(keyboardModifiers.isEmpty ? "+" : "Option-+", help: keyboardModifiers.isEmpty ? "Zoom in (+)" : "Zoom in (Option-+)")

            Text("\(Int((zoom * 100).rounded()))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}

struct ZoomableImageCanvas: View {
    let imageURL: URL
    let zoom: CGFloat
    @StateObject private var imageModel = DecodedImageModel()

    var body: some View {
        GeometryReader { proxy in
            if let image = imageModel.image {
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
                    .overlay(ProgressView())
            }
        }
        .task(id: imageURL) {
            imageModel.load(.fullSize(imageURL))
        }
    }
}

struct LoadedLockedCompareImageCanvas: View {
    let itemID: UUID
    let imageURL: URL
    let zoom: CGFloat
    @Binding var synchronizedViewport: CompareViewport
    let panCommand: ComparePanCommand
    let isPanLocked: Bool
    @StateObject private var imageModel = DecodedImageModel()

    var body: some View {
        Group {
            if let image = imageModel.image {
                LockedCompareImageCanvas(
                    itemID: itemID,
                    image: image,
                    zoom: zoom,
                    synchronizedViewport: $synchronizedViewport,
                    panCommand: panCommand,
                    isPanLocked: isPanLocked
                )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .overlay(ProgressView())
            }
        }
        .task(id: imageURL) {
            imageModel.load(.fullSize(imageURL))
        }
    }
}

struct LockedCompareImageCanvas: NSViewRepresentable {
    let itemID: UUID
    let image: NSImage
    let zoom: CGFloat
    @Binding var synchronizedViewport: CompareViewport
    let panCommand: ComparePanCommand
    let isPanLocked: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> LockedCompareCanvasView {
        let view = LockedCompareCanvasView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: LockedCompareCanvasView, context: Context) {
        context.coordinator.parent = self
        nsView.updateImage(image: image, zoom: zoom)
        context.coordinator.applySynchronizedViewportIfNeeded()
        context.coordinator.applyPanCommandIfNeeded()
    }

    final class Coordinator: NSObject {
        var parent: LockedCompareImageCanvas
        weak var scrollView: LockedCompareCanvasView?
        private var boundsObserver: NSObjectProtocol?
        private var isApplyingSynchronizedViewport = false
        private var lastAppliedViewport = CompareViewport.zero
        private var lastAppliedDocumentSize: CGSize = .zero
        private var lastAppliedPanRevision: Int = 0

        init(_ parent: LockedCompareImageCanvas) {
            self.parent = parent
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func attach(to scrollView: LockedCompareCanvasView) {
            self.scrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                self?.boundsDidChange()
            }
        }

        func applySynchronizedViewportIfNeeded() {
            guard let scrollView else { return }
            guard parent.isPanLocked else { return }
            let documentSize = scrollView.documentView?.frame.size ?? .zero
            guard lastAppliedViewport != parent.synchronizedViewport || lastAppliedDocumentSize != documentSize else { return }
            isApplyingSynchronizedViewport = true
            scrollView.applySynchronizedViewport(parent.synchronizedViewport)
            lastAppliedViewport = parent.synchronizedViewport
            lastAppliedDocumentSize = documentSize
            isApplyingSynchronizedViewport = false
        }

        func applyPanCommandIfNeeded() {
            guard let scrollView else { return }
            guard parent.isPanLocked == false else {
                lastAppliedPanRevision = parent.panCommand.revision
                return
            }
            guard parent.panCommand.revision != lastAppliedPanRevision else { return }
            lastAppliedPanRevision = parent.panCommand.revision
            guard parent.panCommand.targetItemID == parent.itemID else { return }
            scrollView.panBy(dx: parent.panCommand.dx, dy: parent.panCommand.dy)
        }

        private func boundsDidChange() {
            guard let scrollView else { return }
            guard parent.isPanLocked else { return }
            guard isApplyingSynchronizedViewport == false else { return }
            let viewport = scrollView.currentSynchronizedViewport()
            guard viewport != parent.synchronizedViewport else { return }
            lastAppliedViewport = viewport
            DispatchQueue.main.async {
                self.parent.synchronizedViewport = viewport
            }
        }
    }
}

final class LockedCompareCanvasView: NSScrollView {
    private let imageView = NSImageView()
    private weak var currentImage: NSImage?
    private var currentImageSize: CGSize = .zero
    private var currentZoom: CGFloat = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = false
        borderType = .noBorder
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently
        documentView = imageView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateImageLayout()
    }

    func updateImage(image: NSImage, zoom: CGFloat) {
        if currentImage !== image {
            currentImage = image
            imageView.image = image
            currentImageSize = image.size
        }
        currentZoom = zoom
        updateImageLayout()
    }

    func currentSynchronizedViewport() -> CompareViewport {
        guard let documentView else { return .zero }
        return CompareViewport.normalizedOrigin(
            contentSize: documentView.frame.size,
            viewportSize: contentView.bounds.size,
            boundsOrigin: contentView.bounds.origin
        )
    }

    func applySynchronizedViewport(_ viewport: CompareViewport) {
        guard let documentView else { return }
        let origin = viewport.contentOrigin(
            contentSize: documentView.frame.size,
            viewportSize: contentView.bounds.size
        )
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
    }

    func panBy(dx: Int, dy: Int, step: Double = 0.12) {
        let viewport = currentSynchronizedViewport().nudged(dx: dx, dy: dy, step: step)
        applySynchronizedViewport(viewport)
    }

    private func updateImageLayout() {
        guard currentImageSize.width > 0, currentImageSize.height > 0 else { return }

        let viewportSize = contentSize
        let fitScale = min(
            max(viewportSize.width, 1) / max(currentImageSize.width, 1),
            max(viewportSize.height, 1) / max(currentImageSize.height, 1)
        )
        let displayScale = max(fitScale, 0.01) * currentZoom
        let scaledSize = CGSize(
            width: max(1, currentImageSize.width * displayScale),
            height: max(1, currentImageSize.height * displayScale)
        )
        imageView.frame = NSRect(origin: .zero, size: scaledSize)
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
