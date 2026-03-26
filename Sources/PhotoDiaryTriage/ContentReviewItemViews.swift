import AppKit
import SwiftUI

struct ReviewGridCard: View {
    let item: MediaItem
    let thumbnailImage: NSImage?
    let archivePreview: String
    let cardWidth: CGFloat
    let canMutateImportSelection: Bool
    let isSelected: Bool
    let isFocused: Bool
    let thumbnailFailed: Bool
    let onClick: (ReviewGridClickContext) -> Void
    let retryThumbnail: () -> Void
    let setIncludeRaw: (Bool) -> Void
    let includeForImport: () -> Void
    let excludeFromImport: () -> Void
    let clearTriageState: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            selectionSurface

            if canMutateImportSelection && !item.companionFiles.isEmpty {
                Toggle("Import RAW sidecar\(item.companionFiles.count == 1 ? "" : "s") too", isOn: Binding(
                    get: { item.importRawCompanions },
                    set: setIncludeRaw
                ))
                .toggleStyle(.checkbox)
                .shortcutHint("R / Cmd-Option-R", help: "Include RAW companions for this item (R / Cmd-Option-R)")
            }

            HStack {
                if canMutateImportSelection {
                    Button("Select (S)", action: includeForImport)
                        .buttonStyle(.bordered)
                        .disabled(item.selectionState.isIncluded)
                        .shortcutHint("S / Cmd-I", help: "Select this item for import (S / Cmd-I)")

                    Button("Exclude (X)", action: excludeFromImport)
                        .buttonStyle(.bordered)
                        .disabled(item.selectionState.isExcluded)
                        .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import (X / Cmd-Shift-X)")

                    if !item.selectionState.isUndecided {
                        Button("Clear (D)", action: clearTriageState)
                            .buttonStyle(.bordered)
                            .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided (D / Cmd-Shift-I)")
                    }
                }
                Spacer()
            }
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectionStrokeColor, lineWidth: selectionStrokeWidth)
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .padding(6)
            }
        }
    }

    private var selectionStrokeColor: Color {
        if isSelected || isFocused {
            return Color.accentColor
        }
        return Color.clear
    }

    private var selectionStrokeWidth: CGFloat {
        isSelected ? 4 : (isFocused ? 3 : 0)
    }

    private var selectionSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            thumbnail
                .frame(height: CGFloat(ReviewGridMetrics.thumbnailHeight(for: cardWidth)))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(item.selectionState.statusLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBadgeColor)
                    .clipShape(Capsule())
            }

            Text(item.relativePath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let capturedAt = item.capturedAt {
                Text(DateFormatting.iso8601.string(from: capturedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if item.selectionState.isIncluded, !archivePreview.isEmpty {
                Text(archivePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .shortcutHint("Shift-click / Cmd-click / Double-click", help: "Click to select. Shift-click extends the selection, Command-click toggles selection, and double-click opens preview.")
        .overlay {
            ReviewGridClickTarget(onClick: onClick)
        }
    }

    private var statusBadgeColor: Color {
        switch item.selectionState {
        case .included:
            return Color.accentColor.opacity(0.15)
        case .excluded:
            return Color.red.opacity(0.14)
        case .undecided:
            return Color.secondary.opacity(0.12)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailImage {
            Image(nsImage: thumbnailImage)
                .resizable()
                .scaledToFill()
        } else if thumbnailFailed {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Button("Retry", action: retryThumbnail)
                    }
                }
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
        }
    }
}

struct MediaItemRow: View {
    let item: MediaItem
    let thumbnailImage: NSImage?
    let archivePreview: String
    let canMutateImportSelection: Bool
    let isSelected: Bool
    let isFocused: Bool
    let thumbnailFailed: Bool
    let includeForImport: () -> Void
    let excludeFromImport: () -> Void
    let clearTriageState: () -> Void
    let retryThumbnail: () -> Void
    let setIncludeRaw: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.fileName)
                            .font(.headline)
                        Spacer()
                        Text(item.selectionState.statusLabel)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusBadgeColor)
                            .clipShape(Capsule())
                    }

                    Text(item.relativePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let capturedAt = item.capturedAt {
                        Text(DateFormatting.iso8601.string(from: capturedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if canMutateImportSelection && !item.companionFiles.isEmpty {
                        Toggle("Import RAW sidecar\(item.companionFiles.count == 1 ? "" : "s") too", isOn: Binding(
                            get: { item.importRawCompanions },
                            set: setIncludeRaw
                        ))
                        .toggleStyle(.checkbox)
                        .shortcutHint("R / Cmd-Option-R", help: "Include RAW companions for this item (R / Cmd-Option-R)")
                    }
                }
            }

            HStack {
                if canMutateImportSelection {
                    Button("Select (S)", action: includeForImport)
                        .buttonStyle(.bordered)
                        .disabled(item.selectionState.isIncluded)
                        .shortcutHint("S / Cmd-I", help: "Select this item for import (S / Cmd-I)")

                    Button("Exclude (X)", action: excludeFromImport)
                        .buttonStyle(.bordered)
                        .disabled(item.selectionState.isExcluded)
                        .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import (X / Cmd-Shift-X)")

                    if !item.selectionState.isUndecided {
                        Button("Clear (D)", action: clearTriageState)
                            .buttonStyle(.bordered)
                            .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided (D / Cmd-Shift-I)")
                    }
                }
                Spacer()
            }

            if item.selectionState.isIncluded, !archivePreview.isEmpty {
                Text(archivePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected || isFocused ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3 : (isFocused ? 2 : 0))
        }
    }

    private var statusBadgeColor: Color {
        switch item.selectionState {
        case .included:
            return Color.accentColor.opacity(0.15)
        case .excluded:
            return Color.red.opacity(0.14)
        case .undecided:
            return Color.secondary.opacity(0.12)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let thumbnailImage {
            Image(nsImage: thumbnailImage)
                .resizable()
                .scaledToFill()
        } else if thumbnailFailed {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                        Button("Retry", action: retryThumbnail)
                            .buttonStyle(.borderless)
                    }
                }
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
        }
    }
}
