import SwiftUI

@MainActor
func imagePhotoCommandActions(appState: AppState, item: MediaItem, compareCard: Bool = false) -> [AppCommandID: SheetCommandAction] {
    let editable = appState.canMutateImportSelection && !item.lifecycleState.isImportedOrBeyond
    let include: AppCommandID = compareCard ? .includeDisplayedPhoto : .markIncluded
    let candidate: AppCommandID = compareCard ? .candidateDisplayedPhoto : .markCandidate
    let exclude: AppCommandID = compareCard ? .excludeDisplayedPhoto : .markExcluded
    let clear: AppCommandID = compareCard ? .clearDisplayedPhotoTriage : .clearTriage
    let raw: AppCommandID = compareCard ? .toggleDisplayedPhotoRAW : .toggleRAW
    var actions: [AppCommandID: SheetCommandAction] = [
        include: .init(enabled: editable && !item.selectionState.isIncluded, run: {
            if compareCard { appState.markComparisonItemForImport(item.id) } else { appState.markPreviewItemForImport(item.id) }
        }),
        candidate: .init(enabled: editable && !item.selectionState.isCandidate, run: {
            if compareCard { appState.markComparisonItemAsCandidate(item.id) } else { appState.markPreviewItemAsCandidate(item.id) }
        }),
        exclude: .init(enabled: editable && !item.selectionState.isExcluded, run: {
            if compareCard { appState.excludeComparisonItemFromImport(item.id) } else { appState.excludePreviewItemFromImport(item.id) }
        }),
        clear: .init(enabled: editable && !item.selectionState.isUndecided, run: {
            if compareCard { appState.clearComparisonItemTriageState(item.id) } else { appState.clearPreviewItemTriageState(item.id) }
        }),
        raw: .init(enabled: editable && !item.companionFiles.isEmpty, run: {
            if compareCard { appState.setImportRawCompanions(for: item, enabled: !item.importRawCompanions) }
            else { appState.toggleRawForPreviewItem(item.id) }
        }),
        .openLinkedPhoto: .init(enabled: item.cropRelationship?.linkedPreviewRelativePath != nil, run: { appState.openCropLinkedPreview(for: item.id) }),
        .downloadDisplayedOriginal: .init(enabled: appState.isArchiveByteReadBlocked(for: item), run: { appState.downloadArchiveItemForViewing(item) })
    ]
    if compareCard {
        actions[.removeDisplayedComparePhoto] = .init(enabled: appState.comparingMediaItemIDs.contains(item.id), run: { appState.removeItemFromComparison(item.id) })
    } else { actions[.viewOriginal] = actions[.downloadDisplayedOriginal] }
    return imageOwnedCommandActions(appState: appState, actions: actions)
}

@MainActor
func imageCropCommandActions(appState: AppState, item: MediaItem?, visibleRect: CropNormalizedRect,
                             manualRect: CropNormalizedRect?, compareCard: Bool = false,
                             onManualSaved: @escaping () -> Void = {}, onCancel: @escaping () -> Void = {}) -> [AppCommandID: SheetCommandAction] {
    let ready = item.map { appState.canCropMediaItem($0) } == true
    var actions: [AppCommandID: SheetCommandAction] = [
        (compareCard ? .cropDisplayedPhoto : .cropVisible): .init(enabled: ready && visibleRect.isUsableCrop && !visibleRect.isEffectivelyFullFrame,
            run: { if let item { appState.cropMediaItem(item, normalizedRect: visibleRect, trigger: .visibleZoom) } })
    ]
    if !compareCard {
        actions[.saveManualCrop] = .init(enabled: ready && manualRect?.isUsableCrop == true, run: {
            guard let item, let rect = manualRect else { return }
            if appState.cropMediaItem(item, normalizedRect: rect, trigger: .manualDrag) { onManualSaved() }
        })
        actions[.cancelManualCrop] = .init(enabled: manualRect != nil, run: onCancel)
    }
    return imageOwnedCommandActions(appState: appState, actions: actions)
}

@MainActor
func imageCommandContextKey(appState: AppState, item: MediaItem?, visibleRect: CropNormalizedRect,
                            manualRect: CropNormalizedRect?, extras: [String] = []) -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    func rectKey(_ rect: CropNormalizedRect?) -> String {
        rect.flatMap { try? encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? "no-crop"
    }
    return localCommandContextKey([appState.commandImagePresentationContextKey, item?.id.uuidString ?? "no-photo",
        item?.sourceURL.standardizedFileURL.path ?? "", String(describing: item?.selectionState),
        String(describing: item?.importRawCompanions), String(describing: item?.lifecycleState),
        String(item.map { appState.isCropInProgress(for: $0) } ?? false), rectKey(visibleRect), rectKey(manualRect)] + extras)
}

@MainActor
func imageOwnedCommandActions(appState: AppState, actions: [AppCommandID: SheetCommandAction],
                              isCurrent: @escaping () -> Bool = { true }) -> [AppCommandID: SheetCommandAction] {
    let origin = ImageOperationContext(appState)
    return actions.mapValues { action in
        .init(enabled: action.enabled, run: {
            guard origin.hasCurrentPresentation(appState), isCurrent() else { return }
            action.run()
        })
    }
}

// Reference lifetime closes the interval between a binding/action and SwiftUI redraw.
// Geometry updates revoke captured commands; explicit actions also revoke queued canvas input.
@MainActor
final class ImageInteractionContext {
    private(set) var commandRevision = 0
    private(set) var canvasRevision = 0

    func geometryChanged() { commandRevision &+= 1 }
    func supersedeCanvas() { canvasRevision &+= 1; geometryChanged() }

    func commandOwnership() -> () -> Bool {
        let revision = commandRevision
        return { self.commandRevision == revision }
    }

    func canvasOwnership(appState: AppState) -> () -> Bool {
        let revision = canvasRevision, origin = ImageOperationContext(appState)
        return { self.canvasRevision == revision && origin.hasCurrentPresentation(appState) }
    }
}

@MainActor
func imageTrackedBinding<Value: Equatable>(_ binding: Binding<Value>, interaction: ImageInteractionContext) -> Binding<Value> {
    Binding(get: { binding.wrappedValue }, set: { value in
        guard binding.wrappedValue != value else { return }
        interaction.geometryChanged()
        binding.wrappedValue = value
    })
}

@MainActor
func imageManualCropBinding(_ binding: Binding<CropNormalizedRect?>, appState: AppState, item: MediaItem,
                            interaction: ImageInteractionContext) -> Binding<CropNormalizedRect?> {
    let tracked = imageTrackedBinding(binding, interaction: interaction)
    return Binding(get: { tracked.wrappedValue }, set: { value in
        guard appState.canCropMediaItem(item) else { return }
        tracked.wrappedValue = value
    })
}
