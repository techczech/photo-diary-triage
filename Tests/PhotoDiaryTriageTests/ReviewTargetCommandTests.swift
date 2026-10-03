import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

@MainActor
private func targetPhotos(_ f: LocalSurfaceFixture, raw: Bool = false) throws -> [MediaItem] {
    var items = (0..<3).map { makeTestMediaItem(sourceRoot: f.root, fileName: "Target-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    if raw { items[0].companionFiles = [.init(sourceURL: f.root.appendingPathComponent("Target-0.dng"), relativePath: "Target-0.dng", fileName: "Target-0.dng", fileSizeBytes: 10, kind: .raw)] }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    f.state.selectedSidebarNodeID = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == 3 }).id
    f.state.selectedMediaItemIDs = [items[2].id]; f.state.focusedReviewItemID = items[2].id
    return items
}

@MainActor @Test func exactRowActionsDoNotFollowReusedPhotoIDsIntoAnotherLogOrABARoundTrip() throws {
    for roundTrip in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
        let original = try #require(f.state.currentSession)
        let old = reviewPhotoCommandActions(f.state, item: items[0])
        f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, sessionKind: .inbox)
        if roundTrip { f.state.currentSession = original }
        old[.includeDisplayedPhoto]?.run()
        #expect(f.state.currentSession?.mediaItems.first { $0.id == items[0].id }?.selectionState == .undecided)
        #expect(f.state.selectedMediaItemIDs == [items[2].id])
    }
}

@MainActor @Test func exactRowActionsRejectFilterRemovalBeforeNativeRowDetaches() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let old = reviewPhotoCommandActions(f.state, item: items[0])
    f.state.setReviewFilter(.included); #expect(f.state.visibleMediaItems.isEmpty)
    old[.includeDisplayedPhoto]?.run()
    #expect(f.state.currentSession?.mediaItems.first { $0.id == items[0].id }?.selectionState == .undecided)
}

@MainActor @Test func exactRowRAWAndTriageRecheckCopyBusyAndLifecycleBeforeChangingSelection() throws {
    for copied in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f, raw: true)
        let old = reviewPhotoCommandActions(f.state, item: items[0])
        if copied {
            var session = try #require(f.state.currentSession); session.mediaItems[0].lifecycleState = .verified
            session.mediaItems[0].destinationURL = f.root.appendingPathComponent("copied.jpg"); f.state.currentSession = session
        } else { f.state.importOperation = .init(phase: .copying, title: "Copy", detail: "Busy fixture", progress: nil, destinationPath: nil) }
        old[.includeDisplayedPhoto]?.run(); old[.includeDisplayedRAW]?.run()
        #expect(f.state.selectedMediaItemIDs == [items[2].id])
        #expect(f.state.currentSession?.mediaItems.first { $0.id == items[0].id }?.importRawCompanions == false)
    }
}

@MainActor
private func targetBurst(_ f: LocalSurfaceFixture, items: [MediaItem]) throws -> InlineSection {
    let groupID = UUID()
    var session = try #require(f.state.currentSession)
    for index in 0..<2 { session.mediaItems[index].burstGroupID = groupID }
    f.state.currentSession = session
    f.state.burstGroups = [.init(id: groupID, mediaItemIDs: Array(items.prefix(2).map(\.id)), startedAt: .init(timeIntervalSince1970: 1), endedAt: .init(timeIntervalSince1970: 1))]
    f.state.setDayOrganizationMode(.daysAndBursts); f.state.showGroupedReview(); f.state.expandAllInlineSections()
    func burst(_ sections: [InlineSection]) -> InlineSection? { for section in sections { if section.kind == .burst { return section }; if let child = burst(section.children) { return child } }; return nil }
    return try #require(burst(f.state.organizedInlineSections))
}

@MainActor @Test func exactGroupCompareRejectsChangedMembershipWithTheSameSectionID() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let section = try targetBurst(f, items: items)
    let old = reviewGroupCommandActions(f.state, section: section)
    var group = try #require(f.state.burstGroups.first); group.mediaItemIDs.append(items[2].id)
    var session = try #require(f.state.currentSession); session.mediaItems[2].burstGroupID = group.id; f.state.currentSession = session
    f.state.burstGroups = [group]
    old[.compareDisplayedGroup]?.run()
    #expect(f.state.comparingMediaItemIDs.isEmpty)
}

@MainActor
private func targetCrop(_ f: LocalSurfaceFixture) throws -> (MediaItem, CropVersionSnapshot) {
    var items = try targetPhotos(f)
    let originalPath = items[0].relativePath, cropPath = items[1].relativePath
    let relationship = CropRelationship(role: .original, originalRelativePath: originalPath, originalFileName: items[0].fileName,
        cropRelativePaths: [cropPath], cropFileNames: [items[1].fileName], manifestRelativePath: nil, latestCropRelativePath: cropPath, latestCropFileName: items[1].fileName)
    items[0].cropRelationship = relationship
    var cropRelationship = relationship; cropRelationship.role = .crop; items[1].cropRelationship = cropRelationship
    var session = try #require(f.state.currentSession); session.mediaItems = items; f.state.currentSession = session
    f.state.selectedMediaItemIDs = [items[0].id]; f.state.focusedReviewItemID = items[0].id
    let history = try #require(f.state.inspectorState.snapshot.cropHistory)
    return (items[0], try #require(history.versions.first { $0.role == .crop }))
}

@MainActor @Test func exactInspectorCropVersionCannotOpenTheSameFilenameInAnotherLog() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let (source, version) = try targetCrop(f)
    let old = cropVersionCommandActions(f.state, source: source, version: version)
    let session = try #require(f.state.currentSession)
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: session.mediaItems, sessionKind: .inbox)
    old[.showCropVersion]?.run()
    #expect(f.state.previewingMediaItemID == nil); #expect(f.state.focusedReviewItemID == source.id)
}

@MainActor @Test func exactInspectorCropVersionRejectsAnInspectorSelectionRoundTrip() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let (source, version) = try targetCrop(f)
    let old = cropVersionCommandActions(f.state, source: source, version: version)
    let other = try #require(f.state.currentSession?.mediaItems.last)
    f.state.focusedReviewItemID = other.id; f.state.focusedReviewItemID = source.id
    old[.showCropVersion]?.run()
    #expect(f.state.previewingMediaItemID == nil); #expect(f.state.focusedReviewItemID == source.id)
}

@MainActor @Test func reviewRowReplacementDoesNotCancelAnOwnedContainingFocusRequest() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try targetPhotos(f)
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(parent)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: "parent", actions: [:], focusTarget: reviewPaneKeyboardTarget)
    let child = ReviewKeyResponderView(frame: .zero); parent.host.addSubview(child); child.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    try await Task.sleep(for: .milliseconds(30))
    let row = CommandLocalSurfaceView(frame: .zero); parent.host.addSubview(row)
    row.configure(coordinator: f.state.commandCoordinator, scope: .reviewItem, contextKey: "old row", actions: [:])
    let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior); f.window.makeFirstResponder(prior)
    f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
    row.configure(coordinator: f.state.commandCoordinator, scope: .reviewItem, contextKey: "new row", actions: [:])
    try await Task.sleep(for: .milliseconds(30))
    #expect(f.window.firstResponder === child)
}


@MainActor @Test func exactRowTriageUsesItsDisplayedPhotoAfterUnrelatedSelectionChanges() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let actions = reviewPhotoCommandActions(f.state, item: items[0])
    f.state.selectMediaItems([items[1].id])
    actions[.includeDisplayedPhoto]?.run()
    #expect(f.state.currentSession?.mediaItems[0].selectionState == .included)
    #expect(f.state.currentSession?.mediaItems[1].selectionState == .undecided)
    #expect(f.state.focusedReviewItemID == items[1].id)
}

@MainActor @Test func exactRowRAWPreservesRequestedStateAndRefusesAnOldSetter() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f, raw: true)
    let old = reviewPhotoCommandActions(f.state, item: items[0])
    #expect(old[.includeDisplayedRAW]?.enabled == true); #expect(old[.excludeDisplayedRAW]?.enabled == false)
    old[.includeDisplayedRAW]?.run()
    #expect(f.state.currentSession?.mediaItems[0].importRawCompanions == true)
    old[.includeDisplayedRAW]?.run(); old[.excludeDisplayedRAW]?.run()
    #expect(f.state.currentSession?.mediaItems[0].importRawCompanions == true)
    let updated = try #require(f.state.currentSession?.mediaItems.first)
    let fresh = reviewPhotoCommandActions(f.state, item: updated)
    #expect(fresh[.excludeDisplayedRAW]?.enabled == true)
    fresh[.excludeDisplayedRAW]?.run()
    #expect(f.state.currentSession?.mediaItems[0].importRawCompanions == false)
    #expect(f.state.selectedMediaItemIDs == [items[2].id])
}

@MainActor @Test func exactRowRejectsChangedSourceBytesIdentityWithTheSamePhotoID() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let old = reviewPhotoCommandActions(f.state, item: items[0])
    var session = try #require(f.state.currentSession)
    session.mediaItems[0].sourceURL = f.root.appendingPathComponent("Replacement.jpg")
    f.state.currentSession = session
    old[.includeDisplayedPhoto]?.run()
    #expect(f.state.currentSession?.mediaItems[0].selectionState == .undecided)
    #expect(f.state.selectedMediaItemIDs == [items[2].id])
}

@MainActor @Test func collapsedGroupRejectsItsStillAttachedPhotoAndChildHeader() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let section = try targetBurst(f, items: items)
    let item = try #require(f.state.commandDisplayedReviewPhoto(items[0].id))
    let row = reviewPhotoCommandActions(f.state, item: item)
    let header = reviewGroupCommandActions(f.state, section: section)
    let day = try #require(f.state.organizedInlineSections.first)
    f.state.toggleInlineSectionExpansion(day.id)
    #expect(f.state.commandDisplayedReviewPhoto(item.id) == nil)
    #expect(f.state.commandDisplayedReviewSection(section.id) == nil)
    row[.includeDisplayedPhoto]?.run(); header[.compareDisplayedGroup]?.run()
    #expect(f.state.currentSession?.mediaItems[0].selectionState == .undecided)
    #expect(f.state.comparingMediaItemIDs.isEmpty)
}

@MainActor @Test func currentGroupControlsPreserveSectionNavigationAndOpenExactOrderedMembers() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let section = try targetBurst(f, items: items)
    let actions = reviewGroupCommandActions(f.state, section: section)
    #expect(actions[.compareDisplayedGroup]?.enabled == true)
    actions[.focusDisplayedGroup]?.run()
    #expect(f.state.focusedInlineSectionID == section.id); #expect(f.state.isGroupedSectionKeyboardTargetActive)
    actions[.toggleDisplayedGroup]?.run(); #expect(!f.state.isInlineSectionExpanded(section.id))
    actions[.toggleDisplayedGroup]?.run(); #expect(f.state.isInlineSectionExpanded(section.id))
    actions[.compareDisplayedGroup]?.run()
    #expect(f.state.comparingMediaItemIDs == section.mediaItemIDs)
    #expect(f.state.compareState.snapshot.title == "Compare \(section.title)")
}

@MainActor @Test func currentCropHistoryAndRowBadgeOpenTheExactLoadedVersion() throws {
    for badge in [false, true] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let (source, version) = try targetCrop(f)
        if badge {
            let actions = reviewPhotoCommandActions(f.state, item: source)
            #expect(actions[.openLinkedPhoto]?.enabled == true); actions[.openLinkedPhoto]?.run()
        } else {
            let actions = cropVersionCommandActions(f.state, source: source, version: version)
            #expect(actions[.showCropVersion]?.enabled == true); actions[.showCropVersion]?.run()
        }
        #expect(f.state.previewingMediaItemID == version.mediaItemID)
        #expect(f.state.focusedReviewItemID == version.mediaItemID)
    }
}

@MainActor @Test func cropHistoryRejectsCurrentUnloadedAndReplacedTargets() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let (source, version) = try targetCrop(f)
    let history = try #require(f.state.inspectorState.snapshot.cropHistory)
    let current = try #require(history.versions.first { $0.isCurrent })
    #expect(cropVersionCommandActions(f.state, source: source, version: current)[.showCropVersion]?.enabled == false)
    let old = cropVersionCommandActions(f.state, source: source, version: version)
    var session = try #require(f.state.currentSession); session.mediaItems.removeAll { $0.id == version.mediaItemID }; f.state.currentSession = session
    let unloaded = try #require(f.state.inspectorState.snapshot.cropHistory?.versions.first { $0.role == .crop })
    #expect(!unloaded.isLoaded)
    #expect(cropVersionCommandActions(f.state, source: source, version: unloaded)[.showCropVersion]?.enabled == false)
    old[.showCropVersion]?.run(); #expect(f.state.previewingMediaItemID == nil)
}

@MainActor @Test func inspectorThumbnailFailureIsReflectedAndStaleRetryIsUnavailable() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    f.state.thumbnailFailures = [items[2].id]
    #expect(f.state.inspectorState.snapshot.thumbnailFailed)
    let retry = reviewPhotoCommandActions(f.state, item: items[2], owner: .inspector)
    #expect(retry[.retryDisplayedThumbnail]?.enabled == true)
    f.state.focusedReviewItemID = items[0].id
    #expect(!f.state.inspectorState.snapshot.thumbnailFailed)
    retry[.retryDisplayedThumbnail]?.run()
    #expect(f.state.focusedReviewItemID == items[0].id)
}

@MainActor
private func mountTargetReview(_ f: LocalSurfaceFixture, in container: NSView? = nil) -> (CommandLocalSurfaceView, ReviewKeyResponderView) {
    let parent = CommandLocalSurfaceView(frame: f.window.contentView!.bounds)
    (container ?? f.window.contentView!).addSubview(parent)
    parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: "target review", actions: [:], focusTarget: reviewPaneKeyboardTarget)
    let child = ReviewKeyResponderView(frame: .zero); parent.host.addSubview(child)
    child.configureCommands(coordinator: f.state.commandCoordinator, scope: .review, focused: true)
    return (parent, child)
}

@MainActor @Test func clickedPhotoReturnsFocusToItsCapturedReviewAncestorBesideANewerReviewRoot() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
    let (parent, child) = mountTargetReview(f)
    let row = CommandLocalSurfaceView(frame: .zero); parent.host.addSubview(row)
    let commands = row.configure(coordinator: f.state.commandCoordinator, scope: .reviewItem, contextKey: "exact row",
        actions: reviewPhotoCommandActions(f.state, item: items[0]))
    let (_, otherChild) = mountTargetReview(f)
    try await Task.sleep(for: .milliseconds(30)); f.window.makeFirstResponder(otherChild)
    commands.run(.includeDisplayedPhoto)
    row.configure(coordinator: f.state.commandCoordinator, scope: .reviewItem, contextKey: "replacement row", actions: [:])
    try await Task.sleep(for: .milliseconds(30))
    #expect(f.state.currentSession?.mediaItems[0].selectionState == .included)
    #expect(f.window.firstResponder === child)
}

@MainActor @Test func clickedPhotoCannotBorrowAReplacementAncestorForItsQueuedReviewFocus() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }; _ = try targetPhotos(f)
    let outer = CommandLocalSurfaceView(frame: f.window.contentView!.bounds); f.window.contentView!.addSubview(outer)
    outer.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "old ancestor", actions: [:])
    let (parent, _) = mountTargetReview(f, in: outer.host)
    let row = CommandLocalSurfaceView(frame: .zero); parent.host.addSubview(row)
    let commands = row.configure(coordinator: f.state.commandCoordinator, scope: .reviewItem, contextKey: "row",
        actions: [.includeDisplayedPhoto: .init(run: {
            outer.configure(coordinator: f.state.commandCoordinator, scope: .logDetails, contextKey: "replacement ancestor", actions: [:])
            f.state.commandCoordinator.requestFocus(scope: .review, in: f.window)
        })])
    try await Task.sleep(for: .milliseconds(30))
    let prior = NSTextView(frame: NSRect(x: 10, y: 10, width: 100, height: 60)); f.window.contentView!.addSubview(prior); f.window.makeFirstResponder(prior)
    commands.run(.includeDisplayedPhoto)
    try await Task.sleep(for: .milliseconds(30))
    #expect(f.window.firstResponder === prior)
}

@MainActor @Test func actualGridAndListPhotoControlsOwnTheirDisplayedPhotoAndKeepTheirDimensions() async throws {
    for grid in [true, false] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f, raw: true)
        let snapshot = try #require(f.state.reviewState.snapshot.itemSnapshotsByID[items[0].id])
        let (parent, _) = mountTargetReview(f)
        let view: AnyView
        if grid {
            view = AnyView(ReviewGridCard(appState: f.state, snapshot: snapshot, cardWidth: 240,
                canMutateImportSelection: true, onClick: { _ in }, commandContextKey: f.state.reviewState.snapshot.commandContextKey))
        } else {
            view = AnyView(MediaItemRow(appState: f.state, snapshot: snapshot, canMutateImportSelection: true,
                commandContextKey: f.state.reviewState.snapshot.commandContextKey))
        }
        let host = NSHostingView(rootView: view); host.frame = NSRect(x: 0, y: 0, width: grid ? 260 : 600, height: 400); parent.host.addSubview(host)
        for _ in 0..<3 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
        func surfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
            (view as? CommandLocalSurfaceView).map { [$0] } ?? view.subviews.flatMap { surfaces($0) }
        }
        var action: LocalCommandHandle?
        for surface in surfaces(host) {
            f.window.makeFirstResponder(surface)
            if let origin = f.state.commandCoordinator.invocation(in: f.window), origin.scope == .reviewItem {
                let handle = LocalCommandHandle(coordinator: f.state.commandCoordinator, lease: origin.lease)
                if handle.isEnabled(.includeDisplayedPhoto) { action = handle; break }
            }
        }
        let commands = try #require(action)
        #expect(host.fittingSize.height > (grid ? 180 : 75))
        #expect(host.fittingSize.width >= (grid ? 240 : 100))
        f.state.selectMediaItems([items[1].id]); commands.run(.includeDisplayedPhoto)
        #expect(f.state.currentSession?.mediaItems[0].selectionState == .included)
        #expect(f.state.currentSession?.mediaItems[1].selectionState == .undecided)
        #expect(!f.window.isVisible)
    }
}


@MainActor @Test func inheritedReviewKeyboardTriageFromARowUsesPhotosDespitePriorFolderFocus() async throws {
    for scope: AppCommandScope in [.reviewItem, .reviewGroup] {
        for pane: ActivePane in [.folders, .sidebar] {
            for exclude in [false, true] {
                let f = try LocalSurfaceFixture(); defer { f.close() }; let items = try targetPhotos(f)
                let (parent, _) = mountTargetReview(f)
                parent.configure(coordinator: f.state.commandCoordinator, scope: .review, contextKey: reviewPaneCommandContextKey(f.state),
                    actions: reviewPaneCommandActions(f.state, showMap: .constant(false)), focusTarget: reviewPaneKeyboardTarget)
                let row = CommandLocalSurfaceView(frame: .zero); parent.host.addSubview(row)
                row.configure(coordinator: f.state.commandCoordinator, scope: scope, contextKey: "row/group keyboard",
                    actions: scope == .reviewItem ? reviewPhotoCommandActions(f.state, item: items[0]) : [:])
                try await Task.sleep(for: .milliseconds(30))
                f.state.selectedFolderNodeIDs = [try #require(f.state.selectedSidebarNodeID)]; f.state.activePane = pane
                f.window.makeFirstResponder(row)
                #expect(f.window.performKeyEquivalent(with: f.event(exclude ? "x" : "i", modifiers: exclude ? [.command, .shift] : [.command])))
                #expect(f.state.currentSession?.mediaItems[2].selectionState == (exclude ? .excluded : .included))
                #expect(f.state.currentSession?.mediaItems[0].selectionState == .undecided)
                #expect(f.state.currentSession?.mediaItems[1].selectionState == .undecided)
            }
        }
    }
}

@MainActor @Test func rowAndGroupShortcutAssignmentsCannotShadowInheritedReviewBindings() {
    let registry = AppCommandRegistry(overrides: [:])
    #expect(registry.validate(.init(shortcut: .init(key: "r", modifiers: [])), for: .includeDisplayedRAW) != nil)
    #expect(registry.validate(.init(shortcut: .init(key: "s", modifiers: [])), for: .compareDisplayedGroup) != nil)
}

@MainActor @Test func largeLogDisplayedTargetChecksShareTheMembershipIndex() throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let items = (0..<30_000).map { makeTestMediaItem(sourceRoot: f.root, fileName: "Index-\($0).jpg", capturedAt: Date(timeIntervalSince1970: 1)) }
    f.state.currentSession = makeTestSession(sourceRoot: f.root, archiveRoot: f.root, items: items, sessionKind: .inbox)
    f.state.setWorkspaceMode(.cameraTriage)
    f.state.selectedSidebarNodeID = try #require(f.state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count }).id
    #expect(f.state.commandDisplayedReviewPhoto(items[0].id) == items[0])
    let target = ReviewPhotoCommandTarget(f.state, item: items[15_000])
    let start = ContinuousClock.now
    for _ in 0..<500 { #expect(target.isCurrent(f.state)) }
    let duration = start.duration(to: .now)
    #expect(duration < .seconds(3))
    print("Shared 30,000-photo target index: 500 checks in \(duration).")
    f.state.setReviewFilter(.included)
    #expect(f.state.commandDisplayedReviewPhoto(items[15_000].id) == nil)
}


@MainActor @Test func freshInspectorControlsRecoverAfterOverlayAndPaneChangesWithoutPhotoChanges() throws {
    for transition in ["preview", "compare", "pane", "layout"] {
        let f = try LocalSurfaceFixture(); defer { f.close() }; let (source, version) = try targetCrop(f)
        let old = cropVersionCommandActions(f.state, source: source, version: version, context: f.state.inspectorState.snapshot.commandContextKey)
        #expect(old[.showCropVersion]?.enabled == true)
        switch transition {
        case "preview": f.state.previewingMediaItemID = source.id; f.state.previewingMediaItemID = nil
        case "compare": f.state.comparingMediaItemIDs = Array(try #require(f.state.currentSession).mediaItems.prefix(2).map(\.id)); f.state.comparingMediaItemIDs = []
        case "pane": f.state.activePane = .sidebar; f.state.activePane = .media
        default: f.state.setReviewPresentationMode(.list)
        }
        #expect(f.state.inspectorState.snapshot.mediaItem == source)
        let fresh = cropVersionCommandActions(f.state, source: source, version: version, context: f.state.inspectorState.snapshot.commandContextKey)
        #expect(fresh[.showCropVersion]?.enabled == true)
        if transition != "layout" { old[.showCropVersion]?.run(); #expect(f.state.previewingMediaItemID == nil) }
        fresh[.showCropVersion]?.run(); #expect(f.state.previewingMediaItemID == version.mediaItemID)
    }
}
