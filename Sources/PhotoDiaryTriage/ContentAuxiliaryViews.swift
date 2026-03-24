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
            shortcut("+ / - / 0", "Zoom in, zoom out, or reset zoom inside full-photo and compare views")
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
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    func makeNSView(context: Context) -> ReviewKeyResponderView {
        let view = ReviewKeyResponderView()
        view.onArrow = onArrow
        view.onSingleKey = onSingleKey
        view.onSpace = onSpace
        view.onOpen = onOpen
        view.onSelectAll = onSelectAll
        view.onDeselectAll = onDeselectAll
        return view
    }

    func updateNSView(_ nsView: ReviewKeyResponderView, context: Context) {
        nsView.onArrow = onArrow
        nsView.onSingleKey = onSingleKey
        nsView.onSpace = onSpace
        nsView.onOpen = onOpen
        nsView.onSelectAll = onSelectAll
        nsView.onDeselectAll = onDeselectAll
        if isFocused, nsView.window?.firstResponder !== nsView {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class ReviewKeyResponderView: NSView {
    var onArrow: ((_ dx: Int, _ dy: Int, _ extending: Bool) -> Void)?
    var onSingleKey: ((_ key: String) -> Void)?
    var onSpace: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSelectAll: (() -> Void)?
    var onDeselectAll: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let extending = event.modifierFlags.contains(.shift)
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.uppercased() {
            if chars == "A" {
                onSelectAll?()
                return
            }
            if chars == "\u{1B}" {
                onDeselectAll?()
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
            onDeselectAll?()
        default:
            if let text = event.charactersIgnoringModifiers?.uppercased(), ["I", "D", "R", "A", "S", "C"].contains(text) {
                onSingleKey?(text)
            } else {
                super.keyDown(with: event)
            }
        }
    }
}

struct FullPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
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
    @Environment(\.dismiss) private var dismiss
    let items: [MediaItem]
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare Selection")
                        .font(.title3.weight(.semibold))
                    Text("\(items.count) selected image(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZoomToolbar(zoom: $zoom)
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            if items.isEmpty {
                ContentUnavailableView("No Images Selected", systemImage: "rectangle.on.rectangle", description: Text("Select at least two images in the grid and use Compare."))
            } else {
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.fileName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(item.relativePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                ZoomableImageCanvas(imageURL: item.sourceURL, zoom: zoom)
                                    .frame(width: 420, height: 520)
                                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .frame(width: 440, alignment: .topLeading)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 680)
    }
}

struct ZoomToolbar: View {
    @Binding var zoom: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Button("−") {
                zoom = max(0.25, zoom - 0.25)
            }
            .keyboardShortcut("-", modifiers: [])

            Button("100%") {
                zoom = 1
            }
            .keyboardShortcut("0", modifiers: [])

            Button("+") {
                zoom = min(4, zoom + 0.25)
            }
            .keyboardShortcut("+", modifiers: [])

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
