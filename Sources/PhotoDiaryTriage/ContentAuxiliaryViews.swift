import AppKit
import SwiftUI

private struct ShortcutHintBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 220, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .allowsHitTesting(false)
    }
}

private struct ShortcutHintModifier: ViewModifier {
    let helpText: String
    let alignment: Alignment
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .accessibilityHint(helpText)
            .onHover { hovering in
                isHovering = hovering
            }
            .overlay(alignment: alignment) {
                if isHovering {
                    ShortcutHintBubble(text: helpText)
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
        modifier(ShortcutHintModifier(helpText: help ?? shortcut, alignment: alignment))
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
                        ("V", "Crop the currently visible zoomed image area."),
                        ("Cmd-3 / Cmd-4", "Switch flat review or grouped review."),
                        ("Cmd-Control-A / I / C / X / U", "Filter review items to all, included, candidate, excluded, or undecided. Use the filter menu for Cropped."),
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

@MainActor
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
            return PhotoLogStatusPolicy.detailsSheetTitle
        }
    }

    private var sheetSubtitle: String {
        switch editor.mode {
        case .create:
            return "Create a log from decided photos in the current scope, leaving undecided photos in the source inbox."
        case .edit:
            return PhotoLogStatusPolicy.detailsSheetSubtitle
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
    let onCropVisible: () -> Void
    let onToggleSidebar: () -> Void
    let onToggleInspector: () -> Void

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
        view.onCropVisible = onCropVisible
        view.onToggleSidebar = onToggleSidebar
        view.onToggleInspector = onToggleInspector
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
        nsView.onCropVisible = onCropVisible
        nsView.onToggleSidebar = onToggleSidebar
        nsView.onToggleInspector = onToggleInspector

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
    var onCropVisible: (() -> Void)?
    var onToggleSidebar: (() -> Void)?
    var onToggleInspector: (() -> Void)?

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
        if let chromeShortcut = AppChromeKeyboardShortcut(
            key: event.charactersIgnoringModifiers,
            modifiers: event.modifierFlags
        ) {
            switch chromeShortcut {
            case .toggleSidebar:
                onToggleSidebar?()
            case .toggleInspector:
                onToggleInspector?()
            }
            return
        }

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
            } else if text == "V" {
                onCropVisible?()
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
    @ObservedObject var appState: AppState
    let item: MediaItem
    @State private var zoom: CGFloat = 1
    @State private var viewport = CompareViewport.zero
    @State private var visibleCropRect = CropNormalizedRect.fullFrame
    @State private var pendingManualCropRect: CropNormalizedRect?
    @State private var panCommand = ComparePanCommand.idle

    private var currentItem: MediaItem {
        appState.previewingMediaItem ?? item
    }

    var body: some View {
        let displayItem = currentItem

        ZStack {
            ReviewKeyInputView(
                isFocused: true,
                onArrow: { dx, dy, extending in
                    // While a crop is pending, arrows nudge the crop rect; Shift takes a larger step.
                    if let rect = pendingManualCropRect {
                        let step = extending ? 0.02 : 0.004
                        pendingManualCropRect = CropSelectionGeometry.nudgedNormalizedRect(rect, dx: dx, dy: dy, step: step)
                        return
                    }
                    if dx < 0 {
                        appState.navigatePreview(by: -1)
                    } else if dx > 0 {
                        appState.navigatePreview(by: 1)
                    }
                },
                onSectionArrow: { _, _ in },
                onSectionExpandCollapse: { _ in },
                onSingleKey: { key in
                    switch key.uppercased() {
                    case "S":
                        appState.markPreviewItemForImport(displayItem.id)
                    case "C":
                        appState.markPreviewItemAsCandidate(displayItem.id)
                    case "X":
                        appState.excludePreviewItemFromImport(displayItem.id)
                    case "D":
                        appState.clearPreviewItemTriageState(displayItem.id)
                    case "R":
                        appState.toggleRawForPreviewItem(displayItem.id)
                    default:
                        break
                    }
                },
                onPan: { dx, dy in
                    guard zoom > 1 else { return }
                    panCommand = ComparePanCommand(
                        targetItemID: displayItem.id,
                        dx: dx,
                        dy: dy,
                        revision: panCommand.revision &+ 1
                    )
                },
                onSpace: { },
                onOpen: {
                    // Return commits a usable pending crop.
                    if pendingManualCropRect?.isUsableCrop == true {
                        applyManualCrop(for: displayItem)
                    }
                },
                onCommandOpen: { },
                onEscape: {
                    if pendingManualCropRect != nil {
                        cancelManualCrop()
                    } else {
                        dismiss()
                    }
                },
                onSelectAll: {
                    appState.selectFocusedReviewItemOnly()
                },
                onDeselectAll: {
                    appState.deselectAllVisibleMedia()
                },
                onZoomIn: {
                    zoom = min(4, zoom + 0.25)
                },
                onZoomOut: {
                    zoom = max(0.25, zoom - 0.25)
                },
                onZoomReset: {
                    zoom = 1
                    viewport = .zero
                },
                onCropVisible: {
                    cropVisibleArea(for: displayItem)
                },
                onToggleSidebar: {
                    appState.toggleSidebarVisibility()
                },
                onToggleInspector: {
                    appState.toggleDetailsInspector()
                }
            )
            .frame(width: 1, height: 1)
            .onChange(of: displayItem.id) { _, _ in
                zoom = 1
                viewport = .zero
                panCommand = .idle
                visibleCropRect = .fullFrame
                pendingManualCropRect = nil
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayItem.fileName)
                            .font(.title3.weight(.semibold))
                        Text(displayItem.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    previewTriageControls(for: displayItem)
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
                    cropControls(for: displayItem)
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .shortcutHint("Escape", help: "Close preview (Escape)")
                }

                FullPhotoPreviewCanvas(
                    appState: appState,
                    item: displayItem,
                    zoom: $zoom,
                    viewport: $viewport,
                    visibleCropRect: $visibleCropRect,
                    panCommand: panCommand,
                    isCropSelectionEnabled: true,
                    manualCropRect: $pendingManualCropRect,
                    onManualCropSelectionChanged: { rect in
                        pendingManualCropRect = rect
                        if rect != nil {
                            appState.statusMessage = "Crop area selected — drag to adjust, then click Crop (or press Return)."
                        }
                    },
                    onManualCropRejected: { }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(14)
        .frame(width: preferredSheetSize.width, height: preferredSheetSize.height)
        .onChange(of: item.id) { _, _ in
            zoom = 1
            viewport = .zero
            panCommand = .idle
            visibleCropRect = .fullFrame
            pendingManualCropRect = nil
        }
    }

    @ViewBuilder
    private func cropControls(for item: MediaItem) -> some View {
        let isSavingCrop = appState.isCropInProgress(for: item)

        HStack(spacing: 6) {
            Button {
                cropVisibleArea(for: item)
            } label: {
                if isSavingCrop {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Saving Crop")
                    }
                } else {
                    Label("Crop Visible", systemImage: "crop")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isSavingCrop || visibleCropRect.isEffectivelyFullFrame)
            .shortcutHint("V", help: "Save a crop from the current zoomed view")

            if pendingManualCropRect != nil {
                Button {
                    applyManualCrop(for: item)
                } label: {
                    Label("Crop", systemImage: "crop")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSavingCrop || pendingManualCropRect?.isUsableCrop != true)
                .help("Crop to the selected rectangle (Return)")

                Button {
                    cancelManualCrop()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear the crop selection (Escape)")
            }
        }
    }

    private func cropVisibleArea(for item: MediaItem) {
        guard !appState.isCropInProgress(for: item) else { return }
        appState.cropMediaItem(item, normalizedRect: visibleCropRect, trigger: .visibleZoom)
    }

    private func applyManualCrop(for item: MediaItem) {
        guard let rect = pendingManualCropRect, rect.isUsableCrop else {
            appState.statusMessage = "Select a crop area before saving."
            return
        }
        guard !appState.isCropInProgress(for: item) else { return }
        appState.cropMediaItem(item, normalizedRect: rect, trigger: .manualDrag)
        pendingManualCropRect = nil
    }

    private func cancelManualCrop() {
        pendingManualCropRect = nil
        appState.statusMessage = "Cleared crop selection."
    }

    @ViewBuilder
    private func previewTriageControls(for item: MediaItem) -> some View {
        let canEdit = appState.canMutateImportSelection && !item.lifecycleState.isImportedOrBeyond

        HStack(spacing: 6) {
            Text(item.selectionState.statusLabel)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusBadgeColor(for: item.selectionState))
                .clipShape(Capsule())

            if let cropRelationship = item.cropRelationship {
                Button {
                    appState.openCropLinkedPreview(for: item.id)
                } label: {
                    Label(cropRelationship.badgeLabel, systemImage: cropRelationship.role == .crop ? "crop" : "photo.badge.plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(cropRelationship.role == .crop ? Color.purple.opacity(0.95) : Color.teal.opacity(0.95))
                .help(cropRelationship.helpText)
            }

            if appState.canMutateImportSelection {
                Button("S") {
                    appState.markPreviewItemForImport(item.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canEdit || item.selectionState.isIncluded)
                .shortcutHint(ReviewTooltipText.selectShortcut, help: ReviewTooltipText.selectForImport)

                Button("C") {
                    appState.markPreviewItemAsCandidate(item.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canEdit || item.selectionState.isCandidate)
                .shortcutHint(ReviewTooltipText.candidateShortcut, help: ReviewTooltipText.markAsCandidate)

                Button("X") {
                    appState.excludePreviewItemFromImport(item.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canEdit || item.selectionState.isExcluded)
                .shortcutHint(ReviewTooltipText.excludeShortcut, help: ReviewTooltipText.excludeFromImport)

                if !item.selectionState.isUndecided {
                    Button("D") {
                        appState.clearPreviewItemTriageState(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canEdit)
                    .shortcutHint(ReviewTooltipText.clearShortcut, help: ReviewTooltipText.clearTriageState)
                }

                if !item.companionFiles.isEmpty {
                    if item.importRawCompanions {
                        Button("R") {
                            appState.toggleRawForPreviewItem(item.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!canEdit)
                        .shortcutHint(ReviewTooltipText.rawShortcut, help: ReviewTooltipText.toggleRawCompanions)
                    } else {
                        Button("R") {
                            appState.toggleRawForPreviewItem(item.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!canEdit)
                        .shortcutHint(ReviewTooltipText.rawShortcut, help: ReviewTooltipText.toggleRawCompanions)
                    }
                }
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

    private var preferredSheetSize: CGSize {
        let visibleSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1_440, height: 900)
        return CGSize(
            width: max(1_100, visibleSize.width * 0.92),
            height: max(760, visibleSize.height * 0.9)
        )
    }
}

struct FullPhotoPreviewCanvas: View {
    let appState: AppState
    let item: MediaItem
    @Binding var zoom: CGFloat
    @Binding var viewport: CompareViewport
    @Binding var visibleCropRect: CropNormalizedRect
    let panCommand: ComparePanCommand
    let isCropSelectionEnabled: Bool
    @Binding var manualCropRect: CropNormalizedRect?
    let onManualCropSelectionChanged: (CropNormalizedRect?) -> Void
    let onManualCropRejected: () -> Void

    @ObservedObject private var thumbnailSlot: ThumbnailSlot

    init(
        appState: AppState,
        item: MediaItem,
        zoom: Binding<CGFloat>,
        viewport: Binding<CompareViewport>,
        visibleCropRect: Binding<CropNormalizedRect>,
        panCommand: ComparePanCommand,
        isCropSelectionEnabled: Bool,
        manualCropRect: Binding<CropNormalizedRect?>,
        onManualCropSelectionChanged: @escaping (CropNormalizedRect?) -> Void,
        onManualCropRejected: @escaping () -> Void
    ) {
        self.appState = appState
        self.item = item
        _zoom = zoom
        _viewport = viewport
        _visibleCropRect = visibleCropRect
        self.panCommand = panCommand
        self.isCropSelectionEnabled = isCropSelectionEnabled
        _manualCropRect = manualCropRect
        self.onManualCropSelectionChanged = onManualCropSelectionChanged
        self.onManualCropRejected = onManualCropRejected
        _thumbnailSlot = ObservedObject(wrappedValue: appState.thumbnailSlot(for: item))
    }

    var body: some View {
        ZoomableImageCanvas(
            imageURL: item.sourceURL,
            zoom: $zoom,
            itemID: item.id,
            viewport: $viewport,
            visibleCropRect: $visibleCropRect,
            panCommand: panCommand,
            isCropSelectionEnabled: isCropSelectionEnabled,
            manualCropRect: $manualCropRect,
            onManualCropSelectionChanged: onManualCropSelectionChanged,
            onManualCropRejected: onManualCropRejected,
            placeholderImage: thumbnailSlot.image,
            isOnlineOnly: appState.isFileOnlineOnly(for: item)
        )
        .task(id: item.id) {
            appState.requestThumbnail(for: item)
            _ = appState.thumbnailImage(for: item)
        }
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
    @State private var visibleCropRects: [UUID: CropNormalizedRect] = [:]
    @State private var pendingManualCropRects: [UUID: CropNormalizedRect] = [:]
    @State private var isManualCropEnabled = false

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
                    if isManualCropEnabled {
                        cancelCompareManualCrop()
                    } else {
                        onClose()
                    }
                },
                onSelectAll: {
                    appState.selectAllComparisonItems()
                },
                onDeselectAll: {
                    appState.deselectComparisonItems()
                },
                onZoomIn: {
                    zoom = min(4, zoom + 0.25)
                },
                onZoomOut: {
                    zoom = max(0.25, zoom - 0.25)
                },
                onZoomReset: {
                    zoom = 1
                },
                onCropVisible: {
                    cropFocusedVisibleArea(snapshot: snapshot)
                },
                onToggleSidebar: {
                    appState.toggleSidebarVisibility()
                },
                onToggleInspector: {
                    appState.toggleDetailsInspector()
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
                Button {
                    cropFocusedVisibleArea(snapshot: snapshot)
                } label: {
                    if focusedCropIsSaving(in: snapshot) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Saving Crop")
                        }
                    } else {
                        Label("Crop Focus", systemImage: "crop")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(focusedCropIsSaving(in: snapshot) || (focusedVisibleCrop(in: snapshot)?.isEffectivelyFullFrame ?? true))
                .shortcutHint("V", help: "Save a crop from the focused compare image")

                Toggle(isOn: $isManualCropEnabled) {
                    Label("Drag Crop", systemImage: "selection.pin.in.out")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .disabled(snapshot.items.contains { appState.isCropInProgress(for: $0.item) })
                .help("Drag over any compare image to define an adjustable crop")

                if isManualCropEnabled || !pendingManualCropRects.isEmpty {
                    Button {
                        applyFocusedManualCrop(snapshot: snapshot)
                    } label: {
                        Label("Save Crop", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(focusedPendingManualCrop(in: snapshot)?.isUsableCrop != true || focusedCropIsSaving(in: snapshot))
                    .help("Save the selected manual crop on the focused compare image")

                    Button {
                        cancelCompareManualCrop()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Cancel pending manual crop selection")
                }

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
                                        zoom: $zoom,
                                        synchronizedViewport: $synchronizedViewport,
                                        panCommand: panCommand,
                                        isPanLocked: isPanLocked,
                                        imageWidth: CGFloat(metrics.imageWidth),
                                        isCropSelectionEnabled: isManualCropEnabled,
                                        visibleCropRect: Binding(
                                            get: { visibleCropRects[itemSnapshot.id] ?? .fullFrame },
                                            set: { visibleCropRects[itemSnapshot.id] = $0 }
                                        ),
                                        manualCropRect: Binding(
                                            get: { pendingManualCropRects[itemSnapshot.id] },
                                            set: { pendingManualCropRects[itemSnapshot.id] = $0 }
                                        ),
                                        onManualCropSelectionChanged: { rect in
                                            pendingManualCropRects[itemSnapshot.id] = rect
                                            appState.focusComparisonItem(itemSnapshot.id)
                                            if rect != nil {
                                                appState.statusMessage = "Crop area selected on \(itemSnapshot.item.fileName). Adjust it, then Save Crop."
                                            }
                                        },
                                        onManualCropRejected: {
                                            appState.statusMessage = "Drag a larger crop area on \(itemSnapshot.item.fileName) before releasing."
                                        }
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
        .onChange(of: isManualCropEnabled) { _, enabled in
            if enabled {
                appState.statusMessage = "Drag Crop on. Drag over any compare image, adjust the rectangle, then Save Crop."
            } else if !pendingManualCropRects.isEmpty {
                pendingManualCropRects.removeAll()
                appState.statusMessage = "Cancelled drag crop."
            }
        }
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

    private func focusedVisibleCrop(in snapshot: CompareSnapshot) -> CropNormalizedRect? {
        guard let focusedID = snapshot.preferredScrollTargetID else { return nil }
        return visibleCropRects[focusedID] ?? .fullFrame
    }

    private func focusedPendingManualCrop(in snapshot: CompareSnapshot) -> CropNormalizedRect? {
        guard let focusedID = snapshot.preferredScrollTargetID else { return nil }
        return pendingManualCropRects[focusedID]
    }

    private func focusedCropIsSaving(in snapshot: CompareSnapshot) -> Bool {
        guard let focusedID = snapshot.preferredScrollTargetID,
              let item = snapshot.items.first(where: { $0.id == focusedID })?.item else { return false }
        return appState.isCropInProgress(for: item)
    }

    private func cropFocusedVisibleArea(snapshot: CompareSnapshot) {
        guard let focusedID = snapshot.preferredScrollTargetID,
              let item = snapshot.items.first(where: { $0.id == focusedID })?.item else { return }
        guard !appState.isCropInProgress(for: item) else { return }
        let rect = visibleCropRects[focusedID] ?? .fullFrame
        appState.cropMediaItem(item, normalizedRect: rect, trigger: .visibleZoom)
    }

    private func applyFocusedManualCrop(snapshot: CompareSnapshot) {
        guard let focusedID = snapshot.preferredScrollTargetID,
              let item = snapshot.items.first(where: { $0.id == focusedID })?.item,
              let rect = pendingManualCropRects[focusedID],
              rect.isUsableCrop else {
            appState.statusMessage = "Select a crop area before saving."
            return
        }
        guard !appState.isCropInProgress(for: item) else { return }
        appState.cropMediaItem(item, normalizedRect: rect, trigger: .manualDrag)
        pendingManualCropRects.removeValue(forKey: focusedID)
        isManualCropEnabled = false
    }

    private func cancelCompareManualCrop() {
        pendingManualCropRects.removeAll()
        isManualCropEnabled = false
        appState.statusMessage = "Cancelled drag crop."
    }
}

struct CompareItemCard: View {
    let appState: AppState
    let snapshot: ReviewItemSnapshot
    @Binding var zoom: CGFloat
    @Binding var synchronizedViewport: CompareViewport
    let panCommand: ComparePanCommand
    let isPanLocked: Bool
    let imageWidth: CGFloat
    let isCropSelectionEnabled: Bool
    @Binding var visibleCropRect: CropNormalizedRect
    @Binding var manualCropRect: CropNormalizedRect?
    let onManualCropSelectionChanged: (CropNormalizedRect?) -> Void
    let onManualCropRejected: () -> Void

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
        let isSavingCrop = appState.isCropInProgress(for: item)

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

                if let cropRelationship = item.cropRelationship {
                    Button {
                        appState.openCropLinkedPreview(for: item.id)
                    } label: {
                        Label(cropRelationship.badgeLabel, systemImage: cropRelationship.role == .crop ? "crop" : "photo.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(cropRelationship.role == .crop ? Color.purple.opacity(0.95) : Color.teal.opacity(0.95))
                    .help(cropRelationship.helpText)
                }

                if appState.canMutateImportSelection {
                    Button("S") {
                        appState.markComparisonItemForImport(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(item.selectionState.isIncluded)
                    .shortcutHint(ReviewTooltipText.selectShortcut, help: ReviewTooltipText.selectForImport)

                    Button("C") {
                        appState.markComparisonItemAsCandidate(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(item.selectionState.isCandidate)
                    .shortcutHint(ReviewTooltipText.candidateShortcut, help: ReviewTooltipText.markAsCandidate)

                    Button("X") {
                        appState.excludeComparisonItemFromImport(item.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(item.selectionState.isExcluded)
                    .shortcutHint(ReviewTooltipText.excludeShortcut, help: ReviewTooltipText.excludeFromImport)

                    if !item.selectionState.isUndecided {
                        Button("D") {
                            appState.clearComparisonItemTriageState(item.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .shortcutHint(ReviewTooltipText.clearShortcut, help: ReviewTooltipText.clearTriageState)
                    }

                    if !item.companionFiles.isEmpty {
                        if item.importRawCompanions {
                            Button("R") {
                                appState.setImportRawCompanions(for: item, enabled: false)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .shortcutHint(ReviewTooltipText.rawShortcut, help: ReviewTooltipText.toggleRawCompanions)
                        } else {
                            Button("R") {
                                appState.setImportRawCompanions(for: item, enabled: true)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .shortcutHint(ReviewTooltipText.rawShortcut, help: ReviewTooltipText.toggleRawCompanions)
                        }
                    }
                }

                Button {
                    appState.cropMediaItem(item, normalizedRect: visibleCropRect, trigger: .visibleZoom)
                } label: {
                    if isSavingCrop {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "crop")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(isSavingCrop || visibleCropRect.isEffectivelyFullFrame)
                .shortcutHint("V", help: "Crop the visible zoomed area when this item is focused")

                Button {
                    appState.removeItemFromComparison(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .shortcutHint("Q", help: "Remove this item from compare (Q)", alignment: .topLeading)
            }

            LoadedLockedCompareImageCanvas(
                appState: appState,
                item: item,
                zoom: $zoom,
                synchronizedViewport: $synchronizedViewport,
                panCommand: panCommand,
                isPanLocked: isPanLocked,
                visibleCropRect: $visibleCropRect,
                isCropSelectionEnabled: isCropSelectionEnabled,
                manualCropRect: $manualCropRect,
                onManualCropSelectionChanged: onManualCropSelectionChanged,
                onManualCropRejected: onManualCropRejected
            )
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    ReviewGridClickTarget { click in
                        appState.handleGridSelection(for: item.id, click: click)
                    }
                    .allowsHitTesting(zoom <= 1 && isCropSelectionEnabled == false)
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
    @Binding var zoom: CGFloat
    let itemID: UUID
    @Binding var viewport: CompareViewport
    @Binding var visibleCropRect: CropNormalizedRect
    let panCommand: ComparePanCommand
    let isCropSelectionEnabled: Bool
    @Binding var manualCropRect: CropNormalizedRect?
    let onManualCropSelectionChanged: (CropNormalizedRect?) -> Void
    let onManualCropRejected: () -> Void
    var placeholderImage: NSImage?
    var isOnlineOnly = false
    @StateObject private var imageModel = DecodedImageModel()

    var body: some View {
        Group {
            if isOnlineOnly {
                CloudOnlyImagePlaceholder(image: placeholderImage)
            } else if let image = imageModel.image {
                LockedCompareImageCanvas(
                    itemID: itemID,
                    image: image,
                    zoom: $zoom,
                    synchronizedViewport: $viewport,
                    visibleCropRect: $visibleCropRect,
                    panCommand: panCommand,
                    isPanLocked: false,
                    isCropSelectionEnabled: isCropSelectionEnabled,
                    manualCropRect: $manualCropRect,
                    onManualCropSelectionChanged: onManualCropSelectionChanged,
                    onManualCropRejected: onManualCropRejected
                )
            } else if let placeholderImage {
                Image(nsImage: placeholderImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        ProgressView()
                            .controlSize(.small)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(12)
                    }
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: imageURL) {
            guard !isOnlineOnly else { return }
            imageModel.load(.interactiveDisplay(imageURL))
        }
    }
}

struct LoadedLockedCompareImageCanvas: View {
    let appState: AppState
    let item: MediaItem
    @Binding var zoom: CGFloat
    @Binding var synchronizedViewport: CompareViewport
    let panCommand: ComparePanCommand
    let isPanLocked: Bool
    @Binding var visibleCropRect: CropNormalizedRect
    let isCropSelectionEnabled: Bool
    @Binding var manualCropRect: CropNormalizedRect?
    let onManualCropSelectionChanged: (CropNormalizedRect?) -> Void
    let onManualCropRejected: () -> Void
    @StateObject private var imageModel = DecodedImageModel()
    @ObservedObject private var thumbnailSlot: ThumbnailSlot

    init(
        appState: AppState,
        item: MediaItem,
        zoom: Binding<CGFloat>,
        synchronizedViewport: Binding<CompareViewport>,
        panCommand: ComparePanCommand,
        isPanLocked: Bool,
        visibleCropRect: Binding<CropNormalizedRect>,
        isCropSelectionEnabled: Bool,
        manualCropRect: Binding<CropNormalizedRect?>,
        onManualCropSelectionChanged: @escaping (CropNormalizedRect?) -> Void,
        onManualCropRejected: @escaping () -> Void
    ) {
        self.appState = appState
        self.item = item
        _zoom = zoom
        _synchronizedViewport = synchronizedViewport
        self.panCommand = panCommand
        self.isPanLocked = isPanLocked
        _visibleCropRect = visibleCropRect
        self.isCropSelectionEnabled = isCropSelectionEnabled
        _manualCropRect = manualCropRect
        self.onManualCropSelectionChanged = onManualCropSelectionChanged
        self.onManualCropRejected = onManualCropRejected
        _thumbnailSlot = ObservedObject(wrappedValue: appState.thumbnailSlot(for: item))
    }

    var body: some View {
        Group {
            if let image = imageModel.image {
                LockedCompareImageCanvas(
                    itemID: item.id,
                    image: image,
                    zoom: $zoom,
                    synchronizedViewport: $synchronizedViewport,
                    visibleCropRect: $visibleCropRect,
                    panCommand: panCommand,
                    isPanLocked: isPanLocked,
                    isCropSelectionEnabled: isCropSelectionEnabled,
                    manualCropRect: $manualCropRect,
                    onManualCropSelectionChanged: onManualCropSelectionChanged,
                    onManualCropRejected: onManualCropRejected
                )
            } else {
                CompareImagePlaceholder(image: thumbnailSlot.image, isOnlineOnly: appState.isFileOnlineOnly(for: item))
            }
        }
        .task(id: item.id) {
            appState.requestThumbnail(for: item)
            _ = appState.thumbnailImage(for: item)
            guard !appState.isFileOnlineOnly(for: item) else { return }
            imageModel.load(.interactiveDisplay(item.sourceURL))
        }
    }
}

struct CompareImagePlaceholder: View {
    let image: NSImage?
    var isOnlineOnly = false

    var body: some View {
        if isOnlineOnly {
            CloudOnlyImagePlaceholder(image: image)
        } else {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                }
            }
            .overlay(ProgressView())
        }
    }
}

struct LockedCompareImageCanvas: NSViewRepresentable {
    let itemID: UUID
    let image: NSImage
    @Binding var zoom: CGFloat
    @Binding var synchronizedViewport: CompareViewport
    @Binding var visibleCropRect: CropNormalizedRect
    let panCommand: ComparePanCommand
    let isPanLocked: Bool
    let isCropSelectionEnabled: Bool
    @Binding var manualCropRect: CropNormalizedRect?
    let onManualCropSelectionChanged: (CropNormalizedRect?) -> Void
    let onManualCropRejected: () -> Void

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
        nsView.isCropSelectionEnabled = isCropSelectionEnabled
        nsView.updateManualCropRect(manualCropRect)
        nsView.onVisibleCropChanged = { rect in
            context.coordinator.updateVisibleCrop(rect)
        }
        nsView.onManualCropSelectionChanged = { rect in
            context.coordinator.updateManualCropSelection(rect)
        }
        nsView.onManualCropRejected = onManualCropRejected
        nsView.onZoomChanged = { nextZoom in
            context.coordinator.updateZoom(nextZoom)
        }
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
        private var lastVisibleCropRect = CropNormalizedRect.fullFrame
        private var lastManualCropRect: CropNormalizedRect?

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

        func updateVisibleCrop(_ rect: CropNormalizedRect) {
            guard rect != lastVisibleCropRect else { return }
            lastVisibleCropRect = rect
            DispatchQueue.main.async {
                self.parent.visibleCropRect = rect
            }
        }

        func updateZoom(_ nextZoom: CGFloat) {
            guard abs(parent.zoom - nextZoom) > 0.0001 else { return }
            DispatchQueue.main.async {
                self.parent.zoom = nextZoom
            }
        }

        func updateManualCropSelection(_ rect: CropNormalizedRect?) {
            guard rect != lastManualCropRect else { return }
            lastManualCropRect = rect
            DispatchQueue.main.async {
                self.parent.manualCropRect = rect
                self.parent.onManualCropSelectionChanged(rect)
            }
        }

        private func boundsDidChange() {
            guard let scrollView else { return }
            scrollView.publishVisibleCrop()
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

private struct CloudOnlyImagePlaceholder: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
            }
        }
        .overlay {
            VStack(spacing: 8) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.title2)
                Text("Online-only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// The document view inside `LockedCompareCanvasView`. A plain `NSImageView` (an `NSControl`)
/// swallows mouse-down via cell tracking, so the enclosing scroll view never sees the drag.
/// This subclass forwards mouse events to the canvas so crop-drag and pointer-pan actually work.
final class CropCanvasImageView: NSImageView {
    weak var eventHandler: LockedCompareCanvasView?

    override func mouseDown(with event: NSEvent) {
        eventHandler?.handleCanvasMouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        eventHandler?.handleCanvasMouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        eventHandler?.handleCanvasMouseUp(with: event)
    }
}

final class LockedCompareCanvasView: NSScrollView {
    private let imageView = CropCanvasImageView()
    private weak var currentImage: NSImage?
    private var currentImageSize: CGSize = .zero
    private var currentZoom: CGFloat = 1
    private let visibleCropLayer = CAShapeLayer()
    private let cropMaskLayer = CAShapeLayer()
    private let cropSelectionLayer = CAShapeLayer()
    private let cropGridLayer = CAShapeLayer()
    private let cropHandleLayer = CAShapeLayer()
    private var cropDragStart: CGPoint?
    private var cropDragCurrent: CGPoint?
    private var cropDragMode: CropSelectionDragMode?
    private var cropDragStartRect: CGRect?
    private var manualCropDocumentRect: CGRect?
    private var panDragStartInWindow: CGPoint?
    private var panDragStartOrigin: CGPoint?
    private var isPointerPanning = false
    var isCropSelectionEnabled = false {
        didSet {
            if isCropSelectionEnabled == false {
                clearCropSelection()
            }
            window?.invalidateCursorRects(for: self)
            updateVisibleCropLayer()
        }
    }
    var onVisibleCropChanged: ((CropNormalizedRect) -> Void)?
    var onManualCropSelectionChanged: ((CropNormalizedRect?) -> Void)?
    var onManualCropRejected: (() -> Void)?
    var onZoomChanged: ((CGFloat) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        autohidesScrollers = false
        borderType = .noBorder
        wantsLayer = true
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        visibleCropLayer.fillColor = NSColor.clear.cgColor
        visibleCropLayer.strokeColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
        visibleCropLayer.lineWidth = 2
        visibleCropLayer.lineDashPattern = [6, 4]
        visibleCropLayer.isHidden = true
        cropMaskLayer.fillColor = NSColor.black.withAlphaComponent(0.52).cgColor
        cropMaskLayer.fillRule = .evenOdd
        cropMaskLayer.strokeColor = NSColor.clear.cgColor
        cropMaskLayer.isHidden = true
        cropSelectionLayer.fillColor = NSColor.clear.cgColor
        cropSelectionLayer.strokeColor = NSColor.controlAccentColor.cgColor
        cropSelectionLayer.lineWidth = 2
        cropSelectionLayer.isHidden = true
        cropGridLayer.fillColor = NSColor.clear.cgColor
        cropGridLayer.strokeColor = NSColor.white.withAlphaComponent(0.5).cgColor
        cropGridLayer.lineWidth = 1
        cropGridLayer.isHidden = true
        cropHandleLayer.fillColor = NSColor.windowBackgroundColor.cgColor
        cropHandleLayer.strokeColor = NSColor.controlAccentColor.cgColor
        cropHandleLayer.lineWidth = 1.5
        cropHandleLayer.isHidden = true
        documentView = imageView
        imageView.eventHandler = self
        ensureCropLayersAttached()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateImageLayout()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isCropSelectionEnabled {
            addValidatedCursorRect(bounds, cursor: .crosshair)
            if let manualCropDocumentRect, manualCropDocumentRect.width > 1, manualCropDocumentRect.height > 1 {
                addValidatedCursorRect(imageView.convert(manualCropDocumentRect, to: self), cursor: .openHand)
                // Edge bands first, then corner squares on top, matching the hit-test order.
                for (handle, band) in CropSelectionGeometry.edgeHitBands(in: manualCropDocumentRect, tolerance: cropHandleTolerance) {
                    addValidatedCursorRect(imageView.convert(band, to: self), cursor: cropCursor(for: handle))
                }
                for handle in [CropSelectionHandle.topLeft, .topRight, .bottomRight, .bottomLeft] {
                    addValidatedCursorRect(
                        imageView.convert(
                            CropSelectionGeometry.handleRect(for: handle, in: manualCropDocumentRect, tolerance: cropHandleTolerance),
                            to: self
                        ),
                        cursor: cropCursor(for: handle)
                    )
                }
            }
        } else if canPointerPan {
            addValidatedCursorRect(bounds, cursor: .openHand)
        }
    }

    /// `addCursorRect` raises an exception on empty or non-finite rects; skip those.
    private func addValidatedCursorRect(_ rect: NSRect, cursor: NSCursor) {
        let standardized = rect.standardized
        guard standardized.width > 0, standardized.height > 0,
              standardized.origin.x.isFinite, standardized.origin.y.isFinite,
              standardized.size.width.isFinite, standardized.size.height.isFinite else { return }
        addCursorRect(standardized, cursor: cursor)
    }

    override func mouseDown(with event: NSEvent) {
        handleCanvasMouseDown(with: event)
    }

    func handleCanvasMouseDown(with event: NSEvent) {
        guard isCropSelectionEnabled else {
            if canPointerPan {
                beginPointerPan(with: event)
                return
            }
            super.mouseDown(with: event)
            return
        }
        let point = imageView.convert(event.locationInWindow, from: nil)
        let mode = manualCropDocumentRect
            .flatMap { CropSelectionGeometry.dragMode(at: point, in: $0, tolerance: cropHandleTolerance) }
            ?? .create
        cropDragMode = mode
        cropDragStartRect = manualCropDocumentRect
        cropDragStart = point
        cropDragCurrent = cropDragStart
        updateManualCropDocumentRect(to: CropSelectionGeometry.updatedRect(
            mode: mode,
            startRect: cropDragStartRect,
            startPoint: point,
            currentPoint: point,
            documentSize: imageView.bounds.size
        ))
    }

    override func mouseDragged(with event: NSEvent) {
        handleCanvasMouseDragged(with: event)
    }

    func handleCanvasMouseDragged(with event: NSEvent) {
        if isPointerPanning {
            continuePointerPan(with: event)
            return
        }
        guard isCropSelectionEnabled, cropDragStart != nil else {
            super.mouseDragged(with: event)
            return
        }
        updateCropSelection(with: imageView.convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        handleCanvasMouseUp(with: event)
    }

    func handleCanvasMouseUp(with event: NSEvent) {
        if isPointerPanning {
            finishPointerPan()
            return
        }
        guard isCropSelectionEnabled, cropDragStart != nil else {
            super.mouseUp(with: event)
            return
        }
        updateCropSelection(with: imageView.convert(event.locationInWindow, from: nil))

        guard let rect = manualCropDocumentRect,
              let normalized = normalizedCropRect(forDocumentRect: rect),
              normalized.isUsableCrop else {
            // A click or too-small drag is not an error: restore a prior valid selection,
            // or clear silently. No beep, no rejection message.
            restoreOrClearRejectedCropSelection()
            return
        }
        finishCropDrag()
        onManualCropSelectionChanged?(normalized)
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) else {
            super.scrollWheel(with: event)
            publishVisibleCrop()
            return
        }
        let delta = event.scrollingDeltaY
        guard abs(delta) > 0.01 else { return }
        let sensitivity: CGFloat = event.hasPreciseScrollingDeltas ? 0.01 : 0.08
        applyPointerZoom(multiplier: CGFloat(exp(Double(delta * sensitivity))), windowLocation: event.locationInWindow)
    }

    override func magnify(with event: NSEvent) {
        let multiplier = max(0.01, 1 + event.magnification)
        applyPointerZoom(multiplier: multiplier, windowLocation: event.locationInWindow)
    }

    func updateImage(image: NSImage, zoom: CGFloat) {
        let nextZoom = CanvasZoomPanMath.clampedZoom(zoom)
        let imageChanged = currentImage !== image
        let zoomChanged = abs(currentZoom - nextZoom) > 0.0001
        guard imageChanged || zoomChanged else { return }

        if imageChanged {
            currentImage = image
            imageView.image = image
            currentImageSize = image.size
        }
        currentZoom = nextZoom
        updateImageLayout()
        window?.invalidateCursorRects(for: self)
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
        publishVisibleCrop()
    }

    func panBy(dx: Int, dy: Int, step: Double = 0.12) {
        let viewport = currentSynchronizedViewport().nudged(dx: dx, dy: dy, step: step)
        applySynchronizedViewport(viewport)
    }

    func updateManualCropRect(_ normalizedRect: CropNormalizedRect?) {
        let nextRect = normalizedRect.flatMap {
            CropGeometryMapper.documentRect(normalizedRect: $0, documentSize: imageView.bounds.size)
        }
        guard manualCropDocumentRect != nextRect else { return }
        manualCropDocumentRect = nextRect
        updateCropSelectionLayer()
        window?.invalidateCursorRects(for: self)
    }

    private var canPointerPan: Bool {
        currentZoom > 1.0001 && (
            imageView.bounds.width > contentView.bounds.width + 1 ||
            imageView.bounds.height > contentView.bounds.height + 1
        )
    }

    private var cropHandleTolerance: CGFloat {
        max(11, min(20, min(imageView.bounds.width, imageView.bounds.height) * 0.02))
    }

    private func cropCursor(for handle: CropSelectionHandle) -> NSCursor {
        switch handle {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return .crosshair
        }
    }

    private func updateCropSelection(with currentPoint: CGPoint) {
        guard let cropDragMode, let cropDragStart else { return }
        cropDragCurrent = currentPoint
        updateManualCropDocumentRect(to: CropSelectionGeometry.updatedRect(
            mode: cropDragMode,
            startRect: cropDragStartRect,
            startPoint: cropDragStart,
            currentPoint: currentPoint,
            documentSize: imageView.bounds.size
        ))
    }

    private func updateManualCropDocumentRect(to rect: CGRect) {
        manualCropDocumentRect = rect
        updateCropSelectionLayer()
        window?.invalidateCursorRects(for: self)
        guard let normalized = normalizedCropRect(forDocumentRect: rect), normalized.isUsableCrop else { return }
        onManualCropSelectionChanged?(normalized)
    }

    private func restoreOrClearRejectedCropSelection() {
        switch cropDragMode {
        case .move, .resize:
            manualCropDocumentRect = cropDragStartRect
            if let rect = manualCropDocumentRect,
               let normalized = normalizedCropRect(forDocumentRect: rect),
               normalized.isUsableCrop {
                onManualCropSelectionChanged?(normalized)
            }
        default:
            manualCropDocumentRect = nil
            onManualCropSelectionChanged?(nil)
        }
        finishCropDrag()
        updateCropSelectionLayer()
        window?.invalidateCursorRects(for: self)
    }

    private func finishCropDrag() {
        cropDragStart = nil
        cropDragCurrent = nil
        cropDragMode = nil
        cropDragStartRect = nil
    }

    private func beginPointerPan(with event: NSEvent) {
        panDragStartInWindow = event.locationInWindow
        panDragStartOrigin = contentView.bounds.origin
        isPointerPanning = true
        NSCursor.closedHand.set()
    }

    private func continuePointerPan(with event: NSEvent) {
        guard let panDragStartInWindow, let panDragStartOrigin else { return }
        let currentLocation = event.locationInWindow
        let translation = CGSize(
            width: currentLocation.x - panDragStartInWindow.x,
            height: currentLocation.y - panDragStartInWindow.y
        )
        let origin = CanvasZoomPanMath.draggedOrigin(
            startOrigin: panDragStartOrigin,
            translation: translation,
            contentSize: imageView.bounds.size,
            viewportSize: contentView.bounds.size
        )
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
        publishVisibleCrop()
        NSCursor.closedHand.set()
    }

    private func finishPointerPan() {
        panDragStartInWindow = nil
        panDragStartOrigin = nil
        isPointerPanning = false
        window?.invalidateCursorRects(for: self)
        if canPointerPan {
            NSCursor.openHand.set()
        }
    }

    private func applyPointerZoom(multiplier: CGFloat, windowLocation: CGPoint) {
        let nextZoom = CanvasZoomPanMath.zoom(from: currentZoom, multiplier: multiplier)
        guard abs(nextZoom - currentZoom) > 0.0001 else { return }

        let oldContentSize = imageView.bounds.size
        let oldBoundsOrigin = contentView.bounds.origin
        let viewportSize = contentView.bounds.size
        let anchorDocumentPoint = imageView.convert(windowLocation, from: nil)

        currentZoom = nextZoom
        updateImageLayout()
        let origin = CanvasZoomPanMath.pointerAnchoredOrigin(
            oldContentSize: oldContentSize,
            newContentSize: imageView.bounds.size,
            viewportSize: viewportSize,
            oldBoundsOrigin: oldBoundsOrigin,
            anchorDocumentPoint: anchorDocumentPoint
        )
        contentView.scroll(to: origin)
        reflectScrolledClipView(contentView)
        publishVisibleCrop()
        window?.invalidateCursorRects(for: self)
        onZoomChanged?(nextZoom)
    }

    private func updateImageLayout() {
        guard currentImageSize.width > 0, currentImageSize.height > 0 else { return }

        let previousDocumentSize = imageView.bounds.size
        let previousManualCrop = manualCropDocumentRect.flatMap {
            CropGeometryMapper.normalizedCropRect(
                documentRect: $0,
                imageSize: currentImageSize,
                documentSize: previousDocumentSize
            )
        }
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
        ensureCropLayersAttached()
        if let previousManualCrop {
            manualCropDocumentRect = CropGeometryMapper.documentRect(
                normalizedRect: previousManualCrop,
                documentSize: imageView.bounds.size
            )
        } else if let manualCropDocumentRect {
            self.manualCropDocumentRect = manualCropDocumentRect.intersection(imageView.bounds)
        }
        updateVisibleCropLayer()
        updateCropSelectionLayer()
        publishVisibleCrop()
    }

    func publishVisibleCrop() {
        guard let rect = normalizedCropRect(forDocumentRect: contentView.bounds) else { return }
        updateVisibleCropLayer()
        onVisibleCropChanged?(rect)
    }

    private func normalizedCropRect(forDocumentRect rect: CGRect) -> CropNormalizedRect? {
        CropGeometryMapper.normalizedCropRect(
            documentRect: rect,
            imageSize: currentImageSize,
            documentSize: imageView.bounds.size
        )
    }

    private func standardizedDocumentRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CropGeometryMapper.standardizedDocumentRect(
            start: start,
            end: end,
            documentSize: imageView.bounds.size
        )
    }

    private func updateVisibleCropLayer() {
        let visibleRect = contentView.bounds.intersection(imageView.bounds)
        let isFullImage = visibleRect.width >= imageView.bounds.width - 1 && visibleRect.height >= imageView.bounds.height - 1
        visibleCropLayer.isHidden = (!isCropSelectionEnabled && isFullImage) || visibleRect.width <= 1 || visibleRect.height <= 1
        visibleCropLayer.path = CGPath(rect: visibleRect, transform: nil)
    }

    /// Keeps the crop overlay layers attached to the image view's current backing layer and on top.
    /// `NSImageView` can rebuild its layer when the image/contents change, orphaning sublayers; this
    /// re-adds them defensively and reasserts z-order and frame so the overlay always renders.
    private func ensureCropLayersAttached() {
        guard let host = imageView.layer else { return }
        let layered: [(CALayer, CGFloat)] = [
            (visibleCropLayer, 40),
            (cropMaskLayer, 50),
            (cropSelectionLayer, 51),
            (cropGridLayer, 52),
            (cropHandleLayer, 53)
        ]
        for (layer, z) in layered {
            if layer.superlayer !== host {
                host.addSublayer(layer)
            }
            layer.zPosition = z
            layer.frame = imageView.bounds
        }
    }

    private func updateCropSelectionLayer() {
        ensureCropLayersAttached()
        guard let rect = manualCropDocumentRect else {
            cropMaskLayer.isHidden = true
            cropMaskLayer.path = nil
            cropSelectionLayer.isHidden = true
            cropSelectionLayer.path = nil
            cropGridLayer.isHidden = true
            cropGridLayer.path = nil
            cropHandleLayer.isHidden = true
            cropHandleLayer.path = nil
            return
        }

        let tooSmall = rect.width <= 1 || rect.height <= 1

        // Dim the discarded area: fill the whole image minus the selection (even-odd rule),
        // leaving the kept area at true brightness.
        let maskPath = CGMutablePath()
        maskPath.addRect(imageView.bounds)
        maskPath.addRect(rect)
        cropMaskLayer.isHidden = tooSmall
        cropMaskLayer.path = maskPath

        cropSelectionLayer.isHidden = tooSmall
        cropSelectionLayer.path = CGPath(rect: rect, transform: nil)

        // Rule-of-thirds guides inside the selection.
        cropGridLayer.isHidden = tooSmall
        let gridPath = CGMutablePath()
        let thirdWidth = rect.width / 3
        let thirdHeight = rect.height / 3
        for index in 1...2 {
            let x = rect.minX + thirdWidth * CGFloat(index)
            gridPath.move(to: CGPoint(x: x, y: rect.minY))
            gridPath.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + thirdHeight * CGFloat(index)
            gridPath.move(to: CGPoint(x: rect.minX, y: y))
            gridPath.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        cropGridLayer.path = gridPath

        cropHandleLayer.isHidden = tooSmall
        let handlePath = CGMutablePath()
        for handleRect in CropSelectionGeometry.handleRects(in: rect, tolerance: cropHandleTolerance) {
            handlePath.addRect(handleRect)
        }
        cropHandleLayer.path = handlePath
    }

    private func clearCropSelection() {
        finishCropDrag()
        manualCropDocumentRect = nil
        updateCropSelectionLayer()
        window?.invalidateCursorRects(for: self)
    }
}

struct ReviewGridClickTarget: NSViewRepresentable {
    let helpText: String
    let onClick: (ReviewGridClickContext) -> Void

    init(helpText: String = ReviewTooltipText.gridSelection, onClick: @escaping (ReviewGridClickContext) -> Void) {
        self.helpText = helpText
        self.onClick = onClick
    }

    func makeNSView(context: Context) -> ReviewGridClickView {
        let view = ReviewGridClickView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: ReviewGridClickView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: ReviewGridClickView) {
        view.onClick = onClick
        view.toolTip = helpText
        view.setAccessibilityLabel(helpText)
        view.setAccessibilityHelp(helpText)
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
