import AppKit
import SwiftUI

struct ThumbnailImageSurface: View {
    let appState: AppState
    let item: MediaItem
    let thumbnailFailed: Bool
    let retryThumbnail: () -> Void
    let contentMode: ContentMode
    let compactRetry: Bool

    @ObservedObject private var slot: ThumbnailSlot

    init(
        appState: AppState,
        item: MediaItem,
        thumbnailFailed: Bool,
        retryThumbnail: @escaping () -> Void,
        contentMode: ContentMode = .fill,
        compactRetry: Bool = false
    ) {
        self.appState = appState
        self.item = item
        self.thumbnailFailed = thumbnailFailed
        self.retryThumbnail = retryThumbnail
        self.contentMode = contentMode
        self.compactRetry = compactRetry
        _slot = ObservedObject(wrappedValue: appState.thumbnailSlot(for: item))
    }

    @ViewBuilder
    var body: some View {
        if let image = slot.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .onAppear {
                    appState.requestThumbnail(for: item)
                    _ = appState.thumbnailImage(for: item)
                }
        } else if thumbnailFailed {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    VStack(spacing: compactRetry ? 4 : 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Button("Retry", action: retryThumbnail)
                            .buttonStyle(.bordered)
                            .controlSize(compactRetry ? .mini : .small)
                    }
                }
                .onAppear {
                    appState.requestThumbnail(for: item)
                    _ = appState.thumbnailImage(for: item)
                }
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay(ProgressView())
                .onAppear {
                    appState.requestThumbnail(for: item)
                    _ = appState.thumbnailImage(for: item)
                }
        }
    }
}

struct ReviewGridCard: View {
    let appState: AppState
    let snapshot: ReviewItemSnapshot
    let cardWidth: CGFloat
    let canMutateImportSelection: Bool
    let onClick: (ReviewGridClickContext) -> Void
    let retryThumbnail: () -> Void
    let setIncludeRaw: (Bool) -> Void
    let includeForImport: () -> Void
    let markAsCandidate: () -> Void
    let excludeFromImport: () -> Void
    let clearTriageState: () -> Void

    private var item: MediaItem {
        snapshot.item
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
            selectionSurface
        }
        .frame(width: cardWidth, alignment: .topLeading)
        .padding(10)
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
            if snapshot.isFocused {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .padding(6)
            }
        }
    }

    private var selectionStrokeColor: Color {
        if snapshot.isSelected || snapshot.isFocused {
            return Color.accentColor
        }
        return Color.clear
    }

    private var selectionStrokeWidth: CGFloat {
        snapshot.isSelected ? 4 : (snapshot.isFocused ? 3 : 0)
    }

    private var selectionSurface: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailImageSurface(
                appState: appState,
                item: item,
                thumbnailFailed: snapshot.thumbnailFailed,
                retryThumbnail: retryThumbnail
            )
            .frame(height: CGFloat(ReviewGridMetrics.thumbnailHeight(for: cardWidth)))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(alignment: .center, spacing: 6) {
                Text(metadataSummary)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Text(snapshot.displayStatusLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBadgeColor(for: snapshot.displayStatusKind))
                    .clipShape(Capsule())
            }

            if let ownership = snapshot.sourceLogOwnership {
                SourceLogOwnershipBadge(ownership: ownership)
            } else if let archiveCopy = snapshot.sourceArchiveCopy {
                SourceArchiveCopyBadge(archiveCopy: archiveCopy)
            } else if let copyStatus = snapshot.directCopyStatus {
                ReviewCopyStatusBadge(copyStatus: copyStatus)
            }

            if let cropRelationship = item.cropRelationship {
                CropRelationshipBadge(relationship: cropRelationship) {
                    appState.openCropLinkedPreview(for: item.id)
                }
            }

            if let visibleLockNotice = snapshot.visibleLockNotice {
                ReviewDecisionLockNotice(text: visibleLockNotice)
            }

            if canMutateImportSelection && !snapshot.isTriageActionLocked {
                actionRow
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .shortcutHint("Shift-click / Cmd-click / Double-click", help: "Click to select. Shift-click extends the selection, Command-click toggles selection, and double-click opens preview.")
        .overlay {
            ReviewGridClickTarget(onClick: onClick)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 6) {
            Button("S", action: includeForImport)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(item.selectionState.isIncluded)
                .shortcutHint("S / Cmd-I", help: "Select this item for import (S / Cmd-I)")

            Button("C", action: markAsCandidate)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(item.selectionState.isCandidate)
                .shortcutHint("C", help: "Mark this item as a candidate (C)")

            Button("X", action: excludeFromImport)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(item.selectionState.isExcluded)
                .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import (X / Cmd-Shift-X)")

            if !item.selectionState.isUndecided {
                Button("D", action: clearTriageState)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided (D / Cmd-Shift-I)")
            }

            if !item.companionFiles.isEmpty {
                if item.importRawCompanions {
                    Button("R") {
                        setIncludeRaw(false)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .shortcutHint("R / Cmd-Option-R", help: "Toggle RAW companions for this item (R / Cmd-Option-R)")
                } else {
                    Button("R") {
                        setIncludeRaw(true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .shortcutHint("R / Cmd-Option-R", help: "Toggle RAW companions for this item (R / Cmd-Option-R)")
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func statusBadgeColor(for statusKind: ReviewDisplayStatusKind) -> Color {
        switch statusKind {
        case .copied:
            return Color.green.opacity(0.14)
        case .selection(.included):
            return Color.accentColor.opacity(0.15)
        case .selection(.candidate):
            return Color.orange.opacity(0.18)
        case .selection(.excluded):
            return Color.red.opacity(0.14)
        case .selection(.undecided):
            return Color.secondary.opacity(0.12)
        }
    }
}

struct MediaItemRow: View {
    let appState: AppState
    let snapshot: ReviewItemSnapshot
    let canMutateImportSelection: Bool
    let includeForImport: () -> Void
    let markAsCandidate: () -> Void
    let excludeFromImport: () -> Void
    let clearTriageState: () -> Void
    let retryThumbnail: () -> Void
    let setIncludeRaw: (Bool) -> Void

    private var item: MediaItem {
        snapshot.item
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
            HStack(alignment: .top, spacing: 12) {
                ThumbnailImageSurface(
                    appState: appState,
                    item: item,
                    thumbnailFailed: snapshot.thumbnailFailed,
                    retryThumbnail: retryThumbnail,
                    compactRetry: true
                )
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(metadataSummary)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Spacer()
                        Text(snapshot.displayStatusLabel)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusBadgeColor(for: snapshot.displayStatusKind))
                            .clipShape(Capsule())
                    }

                    if let ownership = snapshot.sourceLogOwnership {
                        SourceLogOwnershipBadge(ownership: ownership)
                    } else if let archiveCopy = snapshot.sourceArchiveCopy {
                        SourceArchiveCopyBadge(archiveCopy: archiveCopy)
                    } else if let copyStatus = snapshot.directCopyStatus {
                        ReviewCopyStatusBadge(copyStatus: copyStatus)
                    }

                    if let cropRelationship = item.cropRelationship {
                        CropRelationshipBadge(relationship: cropRelationship) {
                            appState.openCropLinkedPreview(for: item.id)
                        }
                    }

                    if let visibleLockNotice = snapshot.visibleLockNotice {
                        ReviewDecisionLockNotice(text: visibleLockNotice)
                    }
                }
            }

            compactActionRow
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(snapshot.isSelected || snapshot.isFocused ? Color.accentColor : Color.clear, lineWidth: snapshot.isSelected ? 3 : (snapshot.isFocused ? 2 : 0))
        }
    }

    @ViewBuilder
    private var compactActionRow: some View {
        if canMutateImportSelection && !snapshot.isTriageActionLocked {
            HStack(spacing: 6) {
                Button("S", action: includeForImport)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(item.selectionState.isIncluded)
                    .shortcutHint("S / Cmd-I", help: "Select this item for import (S / Cmd-I)")

                Button("C", action: markAsCandidate)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(item.selectionState.isCandidate)
                    .shortcutHint("C", help: "Mark this item as a candidate (C)")

                Button("X", action: excludeFromImport)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(item.selectionState.isExcluded)
                    .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import (X / Cmd-Shift-X)")

                if !item.selectionState.isUndecided {
                    Button("D", action: clearTriageState)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided (D / Cmd-Shift-I)")
                }

                if !item.companionFiles.isEmpty {
                    Toggle("RAW", isOn: Binding(
                        get: { item.importRawCompanions },
                        set: setIncludeRaw
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .shortcutHint("R / Cmd-Option-R", help: "Include RAW companions for this item (R / Cmd-Option-R)")
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func statusBadgeColor(for statusKind: ReviewDisplayStatusKind) -> Color {
        switch statusKind {
        case .copied:
            return Color.green.opacity(0.14)
        case .selection(.included):
            return Color.accentColor.opacity(0.15)
        case .selection(.candidate):
            return Color.orange.opacity(0.18)
        case .selection(.excluded):
            return Color.red.opacity(0.14)
        case .selection(.undecided):
            return Color.secondary.opacity(0.12)
        }
    }
}

private struct ReviewDecisionLockNotice: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "lock")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SourceLogOwnershipBadge: View {
    let ownership: SourceLogOwnershipSnapshot

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: ownership.isCopied ? "checkmark.seal.fill" : "tray.full.fill")
                .imageScale(.small)
            Text(ownership.badgeLabel)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(ownership.isCopied ? Color.green.opacity(0.95) : Color.blue.opacity(0.95))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
        .help(ownership.helpText)
    }

    private var backgroundColor: Color {
        ownership.isCopied ? Color.green.opacity(0.12) : Color.blue.opacity(0.12)
    }
}

private struct CropRelationshipBadge: View {
    let relationship: CropRelationship
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(relationship.badgeLabel, systemImage: relationship.role == .crop ? "crop" : "photo.badge.plus")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .buttonStyle(.plain)
        .font(.caption2.weight(.medium))
        .foregroundStyle(relationship.role == .crop ? Color.purple.opacity(0.95) : Color.teal.opacity(0.95))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
        .help(relationship.helpText)
    }

    private var backgroundColor: Color {
        relationship.role == .crop ? Color.purple.opacity(0.10) : Color.teal.opacity(0.10)
    }
}

private struct ReviewCopyStatusBadge: View {
    let copyStatus: ReviewCopyStatusSnapshot

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .imageScale(.small)
            Text(copyStatus.label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(Color.green.opacity(0.95))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.12))
        .clipShape(Capsule())
        .help(copyStatus.helpText)
    }
}

private struct SourceArchiveCopyBadge: View {
    let archiveCopy: SourceArchiveCopySnapshot

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "externaldrive.fill")
                .imageScale(.small)
            Text("On Disk")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(Color.teal.opacity(0.95))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.teal.opacity(0.12))
        .clipShape(Capsule())
        .help(archiveCopy.helpText)
    }
}
