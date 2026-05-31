import AppKit
import SwiftUI

@MainActor
struct ThumbnailImageSurface: View {
    let appState: AppState
    let item: MediaItem
    let thumbnailFailed: Bool
    let thumbnailCloudOnly: Bool
    let retryThumbnail: () -> Void
    let contentMode: ContentMode
    let compactRetry: Bool

    @ObservedObject private var slot: ThumbnailSlot

    init(
        appState: AppState,
        item: MediaItem,
        thumbnailFailed: Bool,
        thumbnailCloudOnly: Bool = false,
        retryThumbnail: @escaping () -> Void,
        contentMode: ContentMode = .fill,
        compactRetry: Bool = false
    ) {
        self.appState = appState
        self.item = item
        self.thumbnailFailed = thumbnailFailed
        self.thumbnailCloudOnly = thumbnailCloudOnly
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
                    _ = appState.thumbnailImage(for: item)
                }
        } else if thumbnailCloudOnly {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    VStack(spacing: compactRetry ? 4 : 8) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(compactRetry ? .caption : .title3)
                        Text(compactRetry ? "Cloud" : "Online-only")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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

@MainActor
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
        selectionSurface
        .frame(width: cardWidth, alignment: .topLeading)
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectionStrokeColor, lineWidth: selectionStrokeWidth)
        }
        .overlay {
            if snapshot.isFocused {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .padding(4)
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
        snapshot.isSelected ? 3 : (snapshot.isFocused ? 2 : 0)
    }

    private var selectionSurface: some View {
        VStack(alignment: .leading, spacing: 5) {
            photoSurface
            captionLine
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .shortcutHint("Shift-click / Cmd-click / Double-click", help: "Click to select. Shift-click extends the selection, Command-click toggles selection, and double-click opens preview.")
    }

    private var photoSurface: some View {
        ZStack(alignment: .topLeading) {
            ThumbnailImageSurface(
                appState: appState,
                item: item,
                thumbnailFailed: snapshot.thumbnailFailed,
                thumbnailCloudOnly: snapshot.thumbnailCloudOnly,
                retryThumbnail: retryThumbnail
            )

            if snapshot.thumbnailFailed == false {
                ReviewGridClickTarget(onClick: onClick)
            }

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    triageActionOverlay

                    Spacer(minLength: 0)

                    statusBadge
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 6) {
                    secondaryStatusOverlay
                    Spacer(minLength: 0)
                }
            }
            .padding(6)
        }
        .frame(height: CGFloat(ReviewGridMetrics.thumbnailHeight(for: cardWidth)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var captionLine: some View {
        HStack(spacing: 6) {
            Text(metadataSummary)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .frame(height: 18, alignment: .center)
        .contentShape(Rectangle())
        .overlay {
            ReviewGridClickTarget(onClick: onClick)
        }
    }

    @ViewBuilder
    private var triageActionOverlay: some View {
        if canMutateImportSelection && !snapshot.isTriageActionLocked {
            HStack(spacing: 4) {
                TriageChipButton(
                    title: "S",
                    isActive: item.selectionState.isIncluded,
                    activeColor: .accentColor,
                    action: includeForImport
                )
                .shortcutHint("S / Cmd-I", help: "Select this item for import (S / Cmd-I)")

                TriageChipButton(
                    title: "C",
                    isActive: item.selectionState.isCandidate,
                    activeColor: .orange,
                    action: markAsCandidate
                )
                .shortcutHint("C", help: "Mark this item as a candidate (C)")

                TriageChipButton(
                    title: "X",
                    isActive: item.selectionState.isExcluded,
                    activeColor: .red,
                    action: excludeFromImport
                )
                .shortcutHint("X / Cmd-Shift-X", help: "Exclude this item from import (X / Cmd-Shift-X)")

                if !item.selectionState.isUndecided {
                    TriageChipButton(
                        title: "D",
                        isActive: false,
                        activeColor: .secondary,
                        action: clearTriageState
                    )
                    .shortcutHint("D / Cmd-Shift-I", help: "Clear this item back to undecided (D / Cmd-Shift-I)")
                }

                if !item.companionFiles.isEmpty {
                    TriageChipButton(
                        title: "R",
                        isActive: item.importRawCompanions,
                        activeColor: .teal
                    ) {
                        setIncludeRaw(!item.importRawCompanions)
                    }
                    .shortcutHint("R / Cmd-Option-R", help: "Toggle RAW companions for this item (R / Cmd-Option-R)")
                }
            }
            .padding(4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var statusBadge: some View {
        Text(snapshot.displayStatusLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusTextColor(for: snapshot.displayStatusKind))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(statusBadgeColor(for: snapshot.displayStatusKind), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color(nsColor: .windowBackgroundColor).opacity(0.55), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    private var secondaryStatusOverlay: some View {
        HStack(spacing: 4) {
            if let ownership = snapshot.sourceLogOwnership {
                PhotoOverlayBadge(
                    systemImage: ownership.isCopied ? "checkmark.seal.fill" : "tray.full.fill",
                    label: ownership.isCopied ? "Copied" : "Log",
                    color: ownership.isCopied ? .green : .blue,
                    helpText: ownership.helpText
                )
            } else if let archiveCopy = snapshot.sourceArchiveCopy {
                PhotoOverlayBadge(
                    systemImage: "externaldrive.fill",
                    label: "Disk",
                    color: .teal,
                    helpText: archiveCopy.helpText
                )
            } else if let copyStatus = snapshot.directCopyStatus {
                PhotoOverlayBadge(
                    systemImage: "checkmark.seal.fill",
                    label: copyStatus.label,
                    color: .green,
                    helpText: copyStatus.helpText
                )
            }

            if let cropRelationship = item.cropRelationship {
                Button {
                    appState.openCropLinkedPreview(for: item.id)
                } label: {
                    Label(cropRelationship.role == .crop ? "Crop" : "Original", systemImage: cropRelationship.role == .crop ? "photo" : "crop")
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(cropRelationship.role == .crop ? Color.purple.opacity(0.95) : Color.teal.opacity(0.95))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.78), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
                .help(cropRelationship.helpText)
            }

            if let visibleLockNotice = snapshot.visibleLockNotice {
                PhotoOverlayBadge(
                    systemImage: "lock.fill",
                    label: "Locked",
                    color: .secondary,
                    helpText: visibleLockNotice
                )
            }
        }
    }

    private func statusBadgeColor(for statusKind: ReviewDisplayStatusKind) -> Color {
        switch statusKind {
        case .copied:
            return Color.green.opacity(0.78)
        case .selection(.included):
            return Color.accentColor.opacity(0.82)
        case .selection(.candidate):
            return Color.orange.opacity(0.82)
        case .selection(.excluded):
            return Color.red.opacity(0.78)
        case .selection(.undecided):
            return Color(nsColor: .windowBackgroundColor).opacity(0.78)
        }
    }

    private func statusTextColor(for statusKind: ReviewDisplayStatusKind) -> Color {
        switch statusKind {
        case .copied, .selection(.included), .selection(.candidate), .selection(.excluded):
            return .white
        case .selection(.undecided):
            return .primary
        }
    }
}

private struct TriageChipButton: View {
    let title: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.bold))
                .monospaced()
                .frame(width: 18, height: 16)
                .contentShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? Color.white : Color.primary)
        .background(isActive ? activeColor : Color(nsColor: .controlBackgroundColor).opacity(0.86), in: RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(isActive ? 0 : 0.18), lineWidth: 1)
        }
        .help(title)
    }
}

private struct PhotoOverlayBadge: View {
    let systemImage: String
    let label: String
    let color: Color
    let helpText: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.78), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
            .help(helpText)
    }
}

@MainActor
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
                    thumbnailCloudOnly: snapshot.thumbnailCloudOnly,
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
                        set: { enabled in setIncludeRaw(enabled) }
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
            Label(relationship.linkActionLabel, systemImage: relationship.role == .crop ? "photo" : "crop")
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .font(.caption2.weight(.medium))
        .foregroundStyle(relationship.role == .crop ? Color.purple.opacity(0.95) : Color.teal.opacity(0.95))
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
