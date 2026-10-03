import SwiftUI

@MainActor
func reviewTargetCommandContextKey(_ state: AppState, inspector: Bool = false) -> String {
    localCommandContextKey([reviewPaneCommandContextKey(state), String(state.currentSessionRevision),
        inspector ? "inspector-photo" : state.commandReviewContextFingerprint, String(state.reviewOverlayRevision), String(describing: state.importOperation.phase),
        inspector ? String(state.imagePresentationRevision) : "row-selection-independent"])
}

private func reviewPhotoValueKey(_ item: MediaItem) -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(item)).flatMap { String(data: $0, encoding: .utf8) } ?? "invalid-photo"
}

enum ReviewPhotoCommandOwner { case row, inspector }

@MainActor
struct ReviewPhotoCommandTarget {
    let item: MediaItem, owner: ReviewPhotoCommandOwner
    let context: String
    init(_ state: AppState, item: MediaItem, owner: ReviewPhotoCommandOwner = .row, context: String? = nil) {
        self.item = item; self.owner = owner
        self.context = context ?? reviewTargetCommandContextKey(state, inspector: owner == .inspector)
    }
    var key: String { localCommandContextKey([context, owner == .row ? "row" : "inspector", reviewPhotoValueKey(item)]) }
    func isCurrent(_ state: AppState) -> Bool {
        guard context == reviewTargetCommandContextKey(state, inspector: owner == .inspector),
              state.previewingMediaItemID == nil, state.comparingMediaItemIDs.isEmpty,
              state.activeWalkCommitEditor == nil, state.activePhotoLogEditor == nil else { return false }
        if owner == .inspector { return state.isDetailsInspectorVisible && state.inspectorMediaItem == item }
        return state.commandDisplayedReviewPhoto(item.id) == item
    }
}

@MainActor
func reviewPhotoCommandActions(_ state: AppState, item: MediaItem, owner: ReviewPhotoCommandOwner = .row,
                               context: String? = nil) -> [AppCommandID: SheetCommandAction] {
    let target = ReviewPhotoCommandTarget(state, item: item, owner: owner, context: context)
    let linked = state.commandLoadedCropLinkedPhoto(for: item)
    func enabled(_ id: AppCommandID) -> Bool {
        guard target.isCurrent(state) else { return false }
        if id == .retryDisplayedThumbnail { return state.thumbnailFailures.contains(item.id) }
        if id == .openLinkedPhoto {
            return linked != nil && state.commandLoadedCropLinkedPhoto(for: item) == linked
        }
        guard owner == .row, state.canMutateImportSelection, !item.lifecycleState.isImportedOrBeyond else { return false }
        switch id {
        case .includeDisplayedPhoto: return !item.selectionState.isIncluded
        case .candidateDisplayedPhoto: return !item.selectionState.isCandidate
        case .excludeDisplayedPhoto: return !item.selectionState.isExcluded
        case .clearDisplayedPhotoTriage: return !item.selectionState.isUndecided
        case .includeDisplayedRAW: return !item.companionFiles.isEmpty && !item.importRawCompanions
        case .excludeDisplayedRAW: return !item.companionFiles.isEmpty && item.importRawCompanions
        case .toggleDisplayedPhotoRAW: return !item.companionFiles.isEmpty
        default: return false
        }
    }
    let ids: [AppCommandID] = owner == .inspector ? [.retryDisplayedThumbnail] :
        [.includeDisplayedPhoto, .candidateDisplayedPhoto, .excludeDisplayedPhoto, .clearDisplayedPhotoTriage,
         .includeDisplayedRAW, .excludeDisplayedRAW, .toggleDisplayedPhotoRAW, .retryDisplayedThumbnail, .openLinkedPhoto]
    return Dictionary(uniqueKeysWithValues: ids.map { id in
        (id, .init(enabled: enabled(id), run: {
            guard enabled(id) else { return }
            switch id {
            case .retryDisplayedThumbnail: state.requestThumbnail(for: item)
            case .openLinkedPhoto: if let linked { state.openCropVersion(target: linked) }
            case .includeDisplayedRAW: state.setImportRawCompanions(for: item, enabled: true)
            case .excludeDisplayedRAW: state.setImportRawCompanions(for: item, enabled: false)
            case .toggleDisplayedPhotoRAW: state.setImportRawCompanions(for: item, enabled: !item.importRawCompanions)
            default:
                state.selectMediaItems([item.id])
                switch id {
                case .includeDisplayedPhoto: state.markCurrentSelectionForImport()
                case .candidateDisplayedPhoto: state.markCurrentSelectionAsCandidate()
                case .excludeDisplayedPhoto: state.excludeCurrentSelectionFromImport()
                case .clearDisplayedPhotoTriage: state.unmarkCurrentSelectionForImport()
                default: break
                }
                state.commandCoordinator.requestFocus(scope: .review)
            }
        }))
    })
}

struct ReviewPhotoCommandSurface<Content: View>: View {
    let appState: AppState, item: MediaItem
    let contextKey: String
    var owner: ReviewPhotoCommandOwner = .row
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        let target = ReviewPhotoCommandTarget(appState, item: item, owner: owner, context: contextKey)
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: owner == .row ? .reviewItem : .inspectorPhoto,
            contextKey: target.key, actions: reviewPhotoCommandActions(appState, item: item, owner: owner, context: contextKey), content: content)
    }
}

@MainActor
func reviewGroupCommandContextKey(_ state: AppState, section: InlineSection, context: String? = nil) -> String {
    localCommandContextKey([context ?? reviewTargetCommandContextKey(state), section.id, section.title, section.kind.rawValue]
        + section.mediaItemIDs.map(\.uuidString) + section.photoItemIDs.map(\.uuidString) + section.children.map(\.id))
}

@MainActor
func reviewGroupCommandActions(_ state: AppState, section: InlineSection, context: String? = nil) -> [AppCommandID: SheetCommandAction] {
    let key = context ?? reviewTargetCommandContextKey(state)
    let members = section.kind == .day ? [] : state.orderedMediaItems(for: section.mediaItemIDs)
    func current() -> Bool {
        key == reviewTargetCommandContextKey(state) && state.previewingMediaItemID == nil && state.comparingMediaItemIDs.isEmpty
            && state.activeWalkCommitEditor == nil && state.activePhotoLogEditor == nil
            && state.commandDisplayedReviewSection(section.id) == section
    }
    func enabled(_ id: AppCommandID) -> Bool {
        guard current() else { return false }
        if id == .compareDisplayedGroup {
            return section.kind != .day && members.count >= 2 && members.count == section.mediaItemIDs.count
                && state.orderedMediaItems(for: section.mediaItemIDs) == members
        }
        return state.canUseGroupedSectionNavigation && !section.mediaItemIDs.isEmpty
    }
    return Dictionary(uniqueKeysWithValues: [.compareDisplayedGroup, .toggleDisplayedGroup, .focusDisplayedGroup].map { (id: AppCommandID) in
        (id, .init(enabled: enabled(id), run: {
            guard enabled(id) else { return }
            switch id {
            case .compareDisplayedGroup: state.openComparison(for: section.mediaItemIDs, title: "Compare \(section.title)")
            case .toggleDisplayedGroup: state.focusInlineSection(section.id, scrollIntoView: false); state.toggleInlineSectionExpansion(section.id); state.commandCoordinator.requestFocus(scope: .review)
            default: state.focusInlineSection(section.id, scrollIntoView: false); state.commandCoordinator.requestFocus(scope: .review)
            }
        }))
    })
}

struct ReviewGroupCommandSurface<Content: View>: View {
    let appState: AppState, section: InlineSection
    let contextKey: String
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .reviewGroup,
            contextKey: reviewGroupCommandContextKey(appState, section: section, context: contextKey),
            actions: reviewGroupCommandActions(appState, section: section, context: contextKey), content: content)
    }
}

@MainActor
func cropVersionCommandContextKey(_ state: AppState, source: MediaItem, version: CropVersionSnapshot, context: String? = nil) -> String {
    localCommandContextKey([context ?? reviewTargetCommandContextKey(state, inspector: true), reviewPhotoValueKey(source),
        version.id, version.relativePath, version.fileName, version.role.rawValue, version.mediaItemID?.uuidString ?? "not loaded", String(version.isCurrent)])
}

@MainActor
func cropVersionCommandActions(_ state: AppState, source: MediaItem, version: CropVersionSnapshot, context: String? = nil) -> [AppCommandID: SheetCommandAction] {
    let origin = ReviewPhotoCommandTarget(state, item: source, owner: .inspector, context: context)
    let target = version.mediaItemID.flatMap { state.orderedMediaItems(for: [$0]).first }
    func enabled() -> Bool {
        guard origin.isCurrent(state), !version.isCurrent, let target,
              target.id == version.mediaItemID, target.relativePath == version.relativePath,
              state.inspectorState.snapshot.cropHistory?.versions.contains(version) == true else { return false }
        return state.orderedMediaItems(for: [target.id]).first == target
    }
    return [.showCropVersion: .init(enabled: enabled(), run: {
        guard enabled(), let target else { return }; state.openCropVersion(target: target)
    })]
}

struct CropVersionCommandSurface<Content: View>: View {
    let appState: AppState, source: MediaItem
    let version: CropVersionSnapshot
    let contextKey: String
    @ViewBuilder let content: (LocalCommandHandle) -> Content
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .cropVersion,
            contextKey: cropVersionCommandContextKey(appState, source: source, version: version, context: contextKey),
            actions: cropVersionCommandActions(appState, source: source, version: version, context: contextKey), content: content)
    }
}
