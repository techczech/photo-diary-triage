import AppKit
import SwiftUI

@MainActor
struct ThumbnailImageSurface: View {
    let appState: AppState
    let item: MediaItem
    let thumbnailFailed: Bool
    let commandContextKey: String
    let owner: ReviewPhotoCommandOwner
    let contentMode: ContentMode
    let compactRetry: Bool

    @ObservedObject private var slot: ThumbnailSlot

    init(appState: AppState, item: MediaItem, thumbnailFailed: Bool, commandContextKey: String,
         owner: ReviewPhotoCommandOwner = .row, contentMode: ContentMode = .fill, compactRetry: Bool = false) {
        self.appState = appState; self.item = item; self.thumbnailFailed = thumbnailFailed
        self.commandContextKey = commandContextKey; self.owner = owner
        self.contentMode = contentMode; self.compactRetry = compactRetry
        _slot = ObservedObject(wrappedValue: appState.thumbnailSlot(for: item))
    }

    var body: some View {
        let target = ReviewPhotoCommandTarget(appState, item: item, owner: owner, context: commandContextKey)
        Group {
            if let image = slot.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else if thumbnailFailed {
                Rectangle().fill(.quaternary).overlay {
                    VStack(spacing: compactRetry ? 4 : 8) {
                        Image(systemName: "exclamationmark.triangle")
                        ReviewPhotoCommandSurface(appState: appState, item: item, contextKey: commandContextKey, owner: owner) { commands in
                            Button("Retry") { commands.run(.retryDisplayedThumbnail) }
                                .buttonStyle(.bordered)
                                .controlSize(compactRetry ? .mini : .small)
                                .disabled(!commands.isEnabled(.retryDisplayedThumbnail))
                                .commandShortcutHint(.retryDisplayedThumbnail, appState: appState,
                                    scope: owner == .row ? .reviewItem : .inspectorPhoto, help: "Retry this photo's thumbnail")
                        }
                    }
                }
            } else {
                Rectangle().fill(.quaternary).overlay(ProgressView())
            }
        }
        .task(id: target.key) {
            guard target.isCurrent(appState) else { return }
            appState.requestThumbnail(for: item)
            _ = appState.thumbnailImage(for: item)
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
    let commandContextKey: String

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
                commandContextKey: commandContextKey
            )
            .frame(height: CGFloat(ReviewGridMetrics.thumbnailHeight(for: cardWidth)))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if snapshot.thumbnailFailed == false {
                    ReviewGridClickTarget(onClick: onClick)
                }
            }

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
            .contentShape(Rectangle())
            .overlay {
                ReviewGridClickTarget(onClick: onClick)
            }

            if let ownership = snapshot.sourceLogOwnership {
                SourceLogOwnershipBadge(ownership: ownership)
            } else if let archiveCopy = snapshot.sourceArchiveCopy {
                SourceArchiveCopyBadge(archiveCopy: archiveCopy)
            } else if let copyStatus = snapshot.directCopyStatus {
                ReviewCopyStatusBadge(copyStatus: copyStatus)
            }

            if let badge = item.googlePhotos?.badge { Label(badge, systemImage: "cloud").font(.caption2).foregroundStyle(.secondary) }

            if let cropRelationship = item.cropRelationship {
                ReviewPhotoCommandSurface(appState: appState, item: item, contextKey: commandContextKey) { commands in
                    CropRelationshipBadge(relationship: cropRelationship) { commands.run(.openLinkedPhoto) }
                        .disabled(!commands.isEnabled(.openLinkedPhoto))
                        .commandShortcutHint(.openLinkedPhoto, appState: appState, scope: .reviewItem, help: cropRelationship.helpText)
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
        .literalGestureHint("Shift-click / Cmd-click / Double-click", help: "Click to select. Shift-click extends the selection, Command-click toggles selection, and double-click opens preview.")
    }

    private var actionRow: some View {
        ReviewPhotoCommandSurface(appState: appState, item: item, contextKey: commandContextKey) { commands in
            HStack(spacing: 6) {
                triageButton("S", .includeDisplayedPhoto, commands, help: "Select this item for import")
                triageButton("C", .candidateDisplayedPhoto, commands, help: "Mark this item as a candidate")
                triageButton("X", .excludeDisplayedPhoto, commands, help: "Exclude this item from import")
                if !item.selectionState.isUndecided {
                    triageButton("D", .clearDisplayedPhotoTriage, commands, help: "Clear this item back to undecided")
                }
                if !item.companionFiles.isEmpty {
                    if item.importRawCompanions {
                        Button("R") { commands.run(.excludeDisplayedRAW) }
                            .buttonStyle(.borderedProminent).controlSize(.mini)
                            .disabled(!commands.isEnabled(.excludeDisplayedRAW))
                            .commandShortcutHint(.excludeDisplayedRAW, appState: appState, scope: .reviewItem, help: "Exclude RAW companions for this item")
                    } else {
                        triageButton("R", .includeDisplayedRAW, commands, help: "Include RAW companions for this item")
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func triageButton(_ label: String, _ id: AppCommandID, _ commands: LocalCommandHandle, help: String) -> some View {
        Button(label) { commands.run(id) }.buttonStyle(.bordered).controlSize(.mini)
            .disabled(!commands.isEnabled(id))
            .commandShortcutHint(id, appState: appState, scope: .reviewItem, help: help)
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

@MainActor
struct MediaItemRow: View {
    let appState: AppState
    let snapshot: ReviewItemSnapshot
    let canMutateImportSelection: Bool
    let commandContextKey: String

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
                    commandContextKey: commandContextKey,
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

                    if let badge = item.googlePhotos?.badge { Label(badge, systemImage: "cloud").font(.caption2).foregroundStyle(.secondary) }

            if let cropRelationship = item.cropRelationship {
                        ReviewPhotoCommandSurface(appState: appState, item: item, contextKey: commandContextKey) { commands in
                            CropRelationshipBadge(relationship: cropRelationship) { commands.run(.openLinkedPhoto) }
                                .disabled(!commands.isEnabled(.openLinkedPhoto))
                                .commandShortcutHint(.openLinkedPhoto, appState: appState, scope: .reviewItem, help: cropRelationship.helpText)
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
            ReviewPhotoCommandSurface(appState: appState, item: item, contextKey: commandContextKey) { commands in
                HStack(spacing: 6) {
                    triageButton("S", .includeDisplayedPhoto, commands, help: "Select this item for import")
                    triageButton("C", .candidateDisplayedPhoto, commands, help: "Mark this item as a candidate")
                    triageButton("X", .excludeDisplayedPhoto, commands, help: "Exclude this item from import")
                    if !item.selectionState.isUndecided {
                        triageButton("D", .clearDisplayedPhotoTriage, commands, help: "Clear this item back to undecided")
                    }
                    if !item.companionFiles.isEmpty {
                        Toggle("RAW", isOn: Binding(get: { item.importRawCompanions },
                            set: { commands.run($0 ? .includeDisplayedRAW : .excludeDisplayedRAW) }))
                            .toggleStyle(.switch).controlSize(.small)
                            .disabled(!commands.isEnabled(item.importRawCompanions ? .excludeDisplayedRAW : .includeDisplayedRAW))
                            .commandShortcutHint(.toggleDisplayedPhotoRAW, appState: appState, scope: .reviewItem, help: "Include RAW companions for this item")
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func triageButton(_ label: String, _ id: AppCommandID, _ commands: LocalCommandHandle, help: String) -> some View {
        Button(label) { commands.run(id) }.buttonStyle(.bordered).controlSize(.small)
            .disabled(!commands.isEnabled(id))
            .commandShortcutHint(id, appState: appState, scope: .reviewItem, help: help)
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
