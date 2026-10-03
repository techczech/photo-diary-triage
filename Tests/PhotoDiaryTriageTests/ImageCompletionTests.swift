import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PhotoDiaryTriage

private actor ImageCompletionGate {
    private var continuation: CheckedContinuation<Void, Never>?
    var started = false
    func suspend() async { started = true; await withCheckedContinuation { continuation = $0 } }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor
private func waitForImageCondition(_ condition: () -> Bool) async throws {
    for _ in 0..<200 { if condition() { return }; try await Task.sleep(for: .milliseconds(5)) }
    Issue.record("The fixture operation did not reach its expected state")
}

private func waitForImageGate(_ gate: ImageCompletionGate) async throws {
    for _ in 0..<200 { if await gate.started { return }; try await Task.sleep(for: .milliseconds(5)) }
    Issue.record("The delayed fixture operation did not start")
}

@MainActor
private final class ImageCompletionFixture {
    let root: URL, archive: URL, state: AppState, a: MediaItem, b: MediaItem
    init(travel: Bool = false, insideArchive: Bool = false) throws {
        root = try makeTemporaryDirectory(); archive = root.appendingPathComponent("archive")
        try AppDirectories.ensureExists(archive)
        let source = insideArchive ? archive : root.appendingPathComponent("source")
        try AppDirectories.ensureExists(source)
        if !travel { try writeTestJPEGImage(source.appendingPathComponent("a.jpg")); try writeTestJPEGImage(source.appendingPathComponent("b.jpg")) }
        a = makeTestMediaItem(sourceRoot: source, fileName: "a.jpg", capturedAt: .init(timeIntervalSince1970: 0))
        b = makeTestMediaItem(sourceRoot: source, fileName: "b.jpg", capturedAt: .init(timeIntervalSince1970: 1))
        var settings = makeTestSettings(root: root)
        settings.archiveRoot = archive; settings.oneDrivePicturesRoot = archive
        settings.archiveMachineRole = travel ? .travel : .mainArchive
        state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
        state.currentSession = makeTestSession(sourceRoot: source, archiveRoot: archive, items: [a, b])
        state.setWorkspaceMode(.cameraTriage)
        state.selectedSidebarNodeID = state.browserNodeMap.values.first { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.contains(a.id) }?.id
        state.focusedReviewItemID = a.id; state.selectedMediaItemIDs = [a.id]; state.previewingMediaItemID = a.id
    }
    func close() { try? FileManager.default.removeItem(at: root) }
    func delayedCrop(_ gate: ImageCompletionGate) {
        state.testingCropOperation = { item, rect, trigger, release in
            let result = try CropService().crop(item: item, normalizedRect: rect, trigger: trigger, appRelease: release)
            await gate.suspend()
            return result
        }
    }
    func crop() { state.cropMediaItem(a, normalizedRect: .init(x: 0.2, y: 0.2, width: 0.5, height: 0.5), trigger: .manualDrag) }
}

enum ImageNavigation: CaseIterable { case nextPhoto, closePreview, reopenPreview, reopenCompare }

@MainActor
@Test(arguments: ImageNavigation.allCases)
func delayedCropPreservesSavedOutputWithoutStealingCurrentPresentation(_ navigation: ImageNavigation) async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let gate = ImageCompletionGate(); f.delayedCrop(gate)
    if navigation == .reopenCompare { f.state.previewingMediaItemID = nil; f.state.openComparison(for: [f.a.id, f.b.id], title: "Original comparison") }
    f.crop(); try await waitForImageGate(gate)
    switch navigation {
    case .nextPhoto: f.state.navigatePreview(by: 1)
    case .closePreview: f.state.previewingMediaItemID = nil
    case .reopenPreview: f.state.previewingMediaItemID = nil; f.state.previewingMediaItemID = f.a.id
    case .reopenCompare:
        f.state.closeComparison(); f.state.openComparison(for: [f.a.id, f.b.id], title: "Fresh comparison")
    }
    let preview = f.state.previewingMediaItemID, focus = f.state.focusedReviewItemID
    let selection = f.state.selectedMediaItemIDs, compare = f.state.comparingMediaItemIDs
    f.state.statusMessage = "Current photo decision"
    await gate.release(); try await waitForImageCondition { !f.state.isCropInProgress(for: f.a) }
    #expect(FileManager.default.fileExists(atPath: f.a.sourceURL.deletingLastPathComponent().appendingPathComponent("a-cropped.jpg").path))
    #expect(f.state.currentSession?.mediaItems.first { $0.id == f.a.id }?.cropRelationship?.latestCropFileName == "a-cropped.jpg")
    #expect(f.state.currentSession?.mediaItems.contains { $0.fileName == "a-cropped.jpg" } == true)
    #expect(f.state.previewingMediaItemID == preview)
    #expect(f.state.focusedReviewItemID == focus)
    #expect(f.state.selectedMediaItemIDs == selection)
    #expect(f.state.comparingMediaItemIDs == compare)
    #expect(f.state.statusMessage == "Current photo decision")
}

@MainActor
@Test(arguments: [false, true])
func cropMustRetainIssueTimeArchiveAuthorityBeforeWorkerStarts(_ roleRoundTrip: Bool) async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    f.crop()
    if roleRoundTrip { f.state.settings.archiveMachineRole = .travel; f.state.settings.archiveMachineRole = .mainArchive }
    else { f.state.settings.archiveRoot = f.root.appendingPathComponent("other"); f.state.settings.archiveRoot = f.archive }
    f.state.statusMessage = "New archive context"
    try await waitForImageCondition { !f.state.isCropInProgress(for: f.a) }
    #expect(!FileManager.default.fileExists(atPath: f.a.sourceURL.deletingLastPathComponent().appendingPathComponent("a-cropped.jpg").path))
    #expect(f.state.currentSession?.mediaItems.count == 2)
    #expect(f.state.previewingMediaItemID == f.a.id)
    // The disabled testing thumbnail cache may report its own status independently.
    #expect(!f.state.statusMessage.lowercased().contains("crop"))
}

@MainActor
@Test func cropIndexErrorCannotPublishAfterArchiveRoundTrip() async throws {
    let f = try ImageCompletionFixture(insideArchive: true); defer { f.close() }
    let gate = ImageCompletionGate()
    let expectedArchive = f.archive
    f.state.testingCropIndexRefresh = { _, root, _ in
        #expect(root == expectedArchive)
        await gate.suspend(); throw CocoaError(.fileReadNoPermission)
    }
    f.crop(); try await waitForImageGate(gate)
    f.state.settings.archiveRoot = f.root.appendingPathComponent("other"); f.state.settings.archiveRoot = f.archive
    f.state.statusMessage = "Current archive status"
    await gate.release()
    try await Task.sleep(for: .milliseconds(25))
    #expect(f.state.statusMessage == "Current archive status")
}

@MainActor
@Test(arguments: ImageNavigation.allCases)
func delayedOriginalDownloadRetainsCurrentPreviewAndCompare(_ navigation: ImageNavigation) async throws {
    let f = try ImageCompletionFixture(travel: true, insideArchive: true); defer { f.close() }
    let gate = ImageCompletionGate()
    f.state.testingOriginalViewingService = ArchiveOriginalViewingService(requestDownload: { url in
        await gate.suspend(); try writeTestJPEGImage(url)
    }, wait: {}, maximumReadinessChecks: 1)
    if navigation == .reopenCompare { f.state.previewingMediaItemID = nil; f.state.openComparison(for: [f.a.id, f.b.id], title: "Compare originals") }
    f.state.downloadArchiveItemForViewing(f.a); try await waitForImageGate(gate)
    switch navigation {
    case .nextPhoto: f.state.navigatePreview(by: 1)
    case .closePreview: f.state.previewingMediaItemID = nil
    case .reopenPreview: f.state.previewingMediaItemID = nil; f.state.previewingMediaItemID = f.a.id
    case .reopenCompare: f.state.closeComparison(); f.state.openComparison(for: [f.a.id, f.b.id], title: "Fresh comparison")
    }
    let preview = f.state.previewingMediaItemID, focus = f.state.focusedReviewItemID
    let selection = f.state.selectedMediaItemIDs, compare = f.state.comparingMediaItemIDs
    f.state.statusMessage = "Current image status"
    await gate.release(); try await waitForImageCondition { !f.state.isArchiveByteReadBlocked(for: f.a) }
    try await Task.sleep(for: .milliseconds(10))
    #expect(f.state.originalViewingRevision > 0)
    #expect(f.state.previewingMediaItemID == preview)
    #expect(f.state.focusedReviewItemID == focus)
    #expect(f.state.selectedMediaItemIDs == selection)
    #expect(f.state.comparingMediaItemIDs == compare)
    #expect(f.state.statusMessage == "Current image status")
}

@MainActor
@Test func compareOriginalDownloadPreparesCardWithoutOpeningPreview() async throws {
    let f = try ImageCompletionFixture(travel: true, insideArchive: true); defer { f.close() }
    f.state.previewingMediaItemID = nil; f.state.openComparison(for: [f.a.id, f.b.id], title: "Compare originals")
    f.state.testingOriginalViewingService = ArchiveOriginalViewingService(requestDownload: { url in try writeTestJPEGImage(url) }, wait: {}, maximumReadinessChecks: 1)
    f.state.downloadArchiveItemForViewing(f.b)
    try await waitForImageCondition { !f.state.isArchiveByteReadBlocked(for: f.b) }
    #expect(f.state.previewingMediaItemID == nil)
    #expect(f.state.comparingMediaItemIDs == [f.a.id, f.b.id])
}

@MainActor
@Test func queuedCanvasCropAndZoomCannotWriteIntoReplacementOrReturnedPhoto() async throws {
    var aZoom: CGFloat = 1, bZoom: CGFloat = 1
    var aCrop = CropNormalizedRect.fullFrame, bCrop = CropNormalizedRect.fullFrame
    var aManual: CropNormalizedRect?, bManual: CropNormalizedRect?
    var aCalls = 0, bCalls = 0
    let aID = UUID(), bID = UUID(), image = NSImage(size: NSSize(width: 100, height: 80))
    func canvas(_ isA: Bool) -> LockedCompareImageCanvas {
        LockedCompareImageCanvas(itemID: isA ? aID : bID, image: image,
            zoom: Binding(get: { isA ? aZoom : bZoom }, set: { if isA { aZoom = $0 } else { bZoom = $0 } }),
            synchronizedViewport: .constant(.zero),
            visibleCropRect: Binding(get: { isA ? aCrop : bCrop }, set: { if isA { aCrop = $0 } else { bCrop = $0 } }),
            panCommand: .idle, isPanLocked: false, isCropSelectionEnabled: true,
            manualCropRect: Binding(get: { isA ? aManual : bManual }, set: { if isA { aManual = $0 } else { bManual = $0 } }),
            onManualCropSelectionChanged: { _ in if isA { aCalls += 1 } else { bCalls += 1 } }, onManualCropRejected: {})
    }
    let coordinator = canvas(true).makeCoordinator()
    let rect = CropNormalizedRect(x: 0.1, y: 0.1, width: 0.4, height: 0.4)
    coordinator.updateVisibleCrop(rect); coordinator.updateManualCropSelection(rect); coordinator.updateZoom(2)
    coordinator.parent = canvas(false)
    try await Task.sleep(for: .milliseconds(10))
    #expect(bCrop == .fullFrame); #expect(bManual == nil); #expect(bZoom == 1); #expect(bCalls == 0)
    coordinator.updateVisibleCrop(rect); coordinator.updateManualCropSelection(rect); coordinator.updateZoom(3)
    coordinator.parent = canvas(true)
    try await Task.sleep(for: .milliseconds(10))
    #expect(aCrop == .fullFrame); #expect(aManual == nil); #expect(aZoom == 1); #expect(aCalls == 0)
    // New A callbacks must work even if their geometry equals the discarded A/B callback.
    coordinator.updateVisibleCrop(rect); coordinator.updateManualCropSelection(rect); coordinator.updateZoom(2)
    try await Task.sleep(for: .milliseconds(10))
    #expect(aCrop == rect); #expect(aManual == rect); #expect(aZoom == 2); #expect(aCalls == 1)
}

@MainActor
@Test func cropIndexErrorCannotReplaceStatusAfterSameArchiveNavigation() async throws {
    let f = try ImageCompletionFixture(insideArchive: true); defer { f.close() }
    let gate = ImageCompletionGate()
    f.state.testingCropIndexRefresh = { _, _, _ in await gate.suspend(); throw CocoaError(.fileReadNoPermission) }
    f.crop(); try await waitForImageGate(gate)
    f.state.previewingMediaItemID = f.b.id; f.state.focusedReviewItemID = f.b.id
    f.state.statusMessage = "Decision about B"
    await gate.release(); try await Task.sleep(for: .milliseconds(25))
    #expect(f.state.statusMessage == "Decision about B")
}

@MainActor
@Test func callbackInvalidationCannotReplayConsumedPanCommand() throws {
    _ = NSApplication.shared
    let itemID = UUID(), image = NSImage(size: NSSize(width: 100, height: 80))
    var parent = LockedCompareImageCanvas(itemID: itemID, contextKey: "first", image: image,
        zoom: .constant(2), synchronizedViewport: .constant(.zero), visibleCropRect: .constant(.fullFrame),
        panCommand: .init(targetItemID: itemID, dx: 1, dy: 0, revision: 1), isPanLocked: false,
        isCropSelectionEnabled: false, manualCropRect: .constant(nil), onManualCropSelectionChanged: { _ in }, onManualCropRejected: {})
    let view = LockedCompareCanvasView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))
    view.updateImage(image: image, zoom: 2)
    let coordinator = parent.makeCoordinator(); coordinator.attach(to: view)
    defer { coordinator.detach() }
    coordinator.applyPanCommandIfNeeded()
    let first = view.contentView.bounds.origin
    #expect(first.x > 0)
    parent.contextKey = "focus moved"; coordinator.parent = parent
    coordinator.applyPanCommandIfNeeded()
    #expect(view.contentView.bounds.origin == first)
}

@MainActor
@Test func disposedCanvasCannotRestorePendingCrop() async throws {
    var crop: CropNormalizedRect?, callbacks = 0
    let parent = LockedCompareImageCanvas(itemID: UUID(), image: NSImage(size: .init(width: 100, height: 80)),
        zoom: .constant(1), synchronizedViewport: .constant(.zero), visibleCropRect: .constant(.fullFrame),
        panCommand: .idle, isPanLocked: false, isCropSelectionEnabled: true,
        manualCropRect: Binding(get: { crop }, set: { crop = $0 }), onManualCropSelectionChanged: { _ in callbacks += 1 }, onManualCropRejected: {})
    let coordinator = parent.makeCoordinator()
    coordinator.updateManualCropSelection(.init(x: 0.1, y: 0.1, width: 0.5, height: 0.5))
    coordinator.detach()
    try await Task.sleep(for: .milliseconds(10))
    #expect(crop == nil); #expect(callbacks == 0)
}

private final class CropContextProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let revokeAt: Int
    init(revokeAt: Int) { self.revokeAt = revokeAt }
    func isCurrent() -> Bool { lock.lock(); defer { lock.unlock() }; calls += 1; return calls < revokeAt }
}

@Test(arguments: [1, 4, 5])
func cropServiceContextRevocationLeavesOriginalAndNoPartialOutput(_ revokeAt: Int) throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appendingPathComponent("a.jpg"); try writeTestJPEGImage(original)
    let originalBytes = try Data(contentsOf: original)
    let item = makeTestMediaItem(sourceRoot: root, fileName: "a.jpg", capturedAt: .init(timeIntervalSince1970: 0))
    let probe = CropContextProbe(revokeAt: revokeAt)
    #expect(throws: (any Error).self) {
        try CropService().crop(item: item, normalizedRect: .init(x: 0.1, y: 0.1, width: 0.5, height: 0.5),
            trigger: .manualDrag, contextIsCurrent: { probe.isCurrent() })
    }
    #expect(try Data(contentsOf: original) == originalBytes)
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["a.jpg"])
}

@MainActor
private func imageSurfaces(_ view: NSView) -> [CommandLocalSurfaceView] {
    ((view as? CommandLocalSurfaceView).map { [$0] } ?? []) + view.subviews.flatMap(imageSurfaces)
}

@MainActor
private func focusedImageSurface(_ scope: AppCommandScope, state: AppState, window: NSWindow) throws -> CommandLocalSurfaceView {
    for surface in imageSurfaces(window.contentView!) {
        window.makeFirstResponder(surface)
        if state.commandCoordinator.invocation(in: window)?.scope == scope { return surface }
    }
    throw CocoaError(.coderValueNotFound)
}

@MainActor
@Test func actualPreviewContainerDownloadsDisplayedPhotoAndRejectsPanelRoundTrip() async throws {
    _ = NSApplication.shared
    let f = try ImageCompletionFixture(travel: true, insideArchive: true); defer { f.close() }
    f.state.previewingMediaItemID = f.b.id // Underlying selection deliberately remains A.
    f.state.commandCoordinator.presentsPanels = false
    f.state.testingOriginalViewingService = .init(requestDownload: { url in try writeTestJPEGImage(url) }, wait: {}, maximumReadinessChecks: 1)
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { window.contentView = nil; window.close() }
    window.contentView = NSHostingView(rootView: FullPhotoSheet(appState: f.state, item: f.b))
    window.contentView?.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(20))
    let surface = try focusedImageSurface(.preview, state: f.state, window: window)
    let old = try #require(f.state.commandCoordinator.invocation(in: window))
    #expect(f.state.commandCoordinator.unavailableReason(.viewOriginal, invocation: old) == nil)
    #expect(f.state.commandCoordinator.unavailableReason(.cropVisible, invocation: old) != nil)
    f.state.previewingMediaItemID = nil; f.state.previewingMediaItemID = f.b.id
    #expect(!f.state.commandCoordinator.execute(.viewOriginal, invocation: old))
    try await Task.sleep(for: .milliseconds(20))
    let freshSurface = try focusedImageSurface(.preview, state: f.state, window: window)
    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 1,
        windowNumber: window.windowNumber, context: nil, characters: "D", charactersIgnoringModifiers: "d", isARepeat: false, keyCode: 2)!
    #expect(freshSurface.performKeyEquivalent(with: event))
    try await waitForImageCondition { !f.state.isArchiveByteReadBlocked(for: f.b) }
    #expect(f.state.isArchiveByteReadBlocked(for: f.a))
    #expect(f.state.previewingMediaItemID == f.b.id)
    #expect(!window.isVisible)
    _ = surface
}

@MainActor
@Test func actualCompareContainerKeepsCancelDistinctFromCloseAndOwnsColumns() async throws {
    _ = NSApplication.shared
    let f = try ImageCompletionFixture(); defer { f.close() }
    f.state.previewingMediaItemID = nil; f.state.openComparison(for: [f.a.id, f.b.id], title: "Fixture comparison")
    f.state.commandCoordinator.presentsPanels = false
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let token = UUID(); f.state.commandCoordinator.register(window: window, token: token, scope: .main)
    defer { window.contentView = nil; f.state.commandCoordinator.unregisterWindow(token); window.close() }
    window.contentView = NSHostingView(rootView: CompareSheet(appState: f.state, state: f.state.compareState, onClose: { f.state.closeComparison() }))
    window.contentView?.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20))
    _ = try focusedImageSurface(.compare, state: f.state, window: window)
    #expect(f.state.commandCoordinator.execute(.fewerCompareColumns, in: window))
    #expect(f.state.compareGridColumnCount == 1)
    try await Task.sleep(for: .milliseconds(20))
    _ = try focusedImageSurface(.compare, state: f.state, window: window)
    #expect(f.state.commandCoordinator.execute(.moreCompareColumns, in: window))
    #expect(f.state.compareGridColumnCount == 2)
    try await Task.sleep(for: .milliseconds(20))
    _ = try focusedImageSurface(.compare, state: f.state, window: window)
    #expect(f.state.commandCoordinator.execute(.toggleManualCrop, in: window))
    try await Task.sleep(for: .milliseconds(20))
    _ = try focusedImageSurface(.compare, state: f.state, window: window)
    let cropOrigin = try #require(f.state.commandCoordinator.invocation(in: window))
    #expect(f.state.commandCoordinator.unavailableReason(.cancelManualCrop, invocation: cropOrigin) == nil)
    #expect(f.state.commandCoordinator.execute(.closeSurface, invocation: cropOrigin))
    #expect(f.state.comparingMediaItemIDs == [f.a.id, f.b.id])
    try await Task.sleep(for: .milliseconds(20))
    _ = try focusedImageSurface(.compare, state: f.state, window: window)
    #expect(f.state.commandCoordinator.execute(.toggleManualCrop, in: window))
    try await Task.sleep(for: .milliseconds(20))
    _ = try focusedImageSurface(.compare, state: f.state, window: window)
    #expect(f.state.commandCoordinator.execute(.closeImageSurface, in: window))
    #expect(f.state.comparingMediaItemIDs.isEmpty)
    #expect(!window.isVisible)
}

@MainActor
@Test func capturedManualCropRejectsNavigationBeforeRedrawAndReplacedRectangle() async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let native = try LocalSurfaceFixture(); defer { native.close() }
    let surface = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
    native.window.contentView!.addSubview(surface)
    let token = UUID(); f.state.commandCoordinator.register(window: native.window, token: token, scope: .main)
    defer { f.state.commandCoordinator.unregisterWindow(token) }
    let firstRect = CropNormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    let secondRect = CropNormalizedRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
    let old = surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "A",
        actions: imageCropCommandActions(appState: f.state, item: f.a, visibleRect: .fullFrame, manualRect: firstRect))
    #expect(!old.isEnabled(.cropVisible)); #expect(old.isEnabled(.saveManualCrop))
    f.state.previewingMediaItemID = f.b.id
    old.run(.saveManualCrop) // Native tree has deliberately not redrawn yet.
    #expect(!f.state.isCropInProgress(for: f.a)); #expect(!f.state.isCropInProgress(for: f.b))
    let oldB = surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "B first draft",
        actions: imageCropCommandActions(appState: f.state, item: f.b, visibleRect: .fullFrame, manualRect: firstRect))
    let current = surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "B second draft",
        actions: imageCropCommandActions(appState: f.state, item: f.b, visibleRect: .fullFrame, manualRect: secondRect))
    oldB.run(.saveManualCrop); #expect(!f.state.isCropInProgress(for: f.b))
    current.run(.saveManualCrop)
    try await waitForImageCondition { !f.state.isCropInProgress(for: f.b) }
    let manifestURL = f.b.sourceURL.deletingPathExtension().appendingPathExtension("crops.json")
    let manifest = try JSONDecoder().decode(CropManifest.self, from: Data(contentsOf: manifestURL))
    #expect(manifest.sourceMediaItemID == f.b.id)
    #expect(manifest.crops.map(\.normalizedRect) == [secondRect])
    #expect(!FileManager.default.fileExists(atPath: f.a.sourceURL.deletingPathExtension().appendingPathExtension("crops.json").path))
}

@MainActor
@Test func compareCardCapturesItsRowAndInheritsParentCropAndMultiSelectionCommands() throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    f.state.previewingMediaItemID = nil; f.state.openComparison(for: [f.a.id, f.b.id], title: "Compare")
    let native = try LocalSurfaceFixture(); defer { native.close() }
    let token = UUID(); f.state.commandCoordinator.register(window: native.window, token: token, scope: .main)
    defer { f.state.commandCoordinator.unregisterWindow(token) }
    let parent = CommandLocalSurfaceView(frame: native.window.contentView!.bounds), child = CommandLocalSurfaceView(frame: .init(x: 0, y: 0, width: 200, height: 100))
    native.window.contentView!.addSubview(parent); parent.addSubview(child)
    var saved = 0
    parent.configure(coordinator: f.state.commandCoordinator, scope: .compare, contextKey: "Compare",
        actions: [.saveManualCrop: .init(run: { saved += 1 }), .markIncluded: .init(run: { f.state.performCompareShortcut("S") })])
    let rowActions = imagePhotoCommandActions(appState: f.state, item: f.b, compareCard: true)
        .merging(imageCropCommandActions(appState: f.state, item: f.b, visibleRect: .fullFrame, manualRect: nil, compareCard: true)) { _, new in new }
    let row = child.configure(coordinator: f.state.commandCoordinator, scope: .compareItem, contextKey: "B", actions: rowActions)
    native.window.makeFirstResponder(child)
    let origin = try #require(f.state.commandCoordinator.invocation(in: native.window))
    #expect(f.state.commandCoordinator.execute(.saveManualCrop, invocation: origin)); #expect(saved == 1)
    row.run(.includeDisplayedPhoto)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == f.b.id }?.selectionState == .included)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == f.a.id }?.selectionState == .undecided)
    f.state.selectAllComparisonItems()
    let fresh = try #require(f.state.commandCoordinator.invocation(in: native.window))
    #expect(f.state.commandCoordinator.execute(.markIncluded, invocation: fresh))
    #expect(f.state.currentSession?.mediaItems.allSatisfy { $0.selectionState.isIncluded } == true)
    #expect(AppCommandRegistry().validate(.init(shortcut: .init(key: "s")), for: .includeDisplayedPhoto) != nil)
}

@MainActor
@Test func containingImageFocusHappensOnAttachmentAndNeverOnDraftRedraw() async throws {
    let f = try LocalSurfaceFixture(); defer { f.close() }
    let surface = CommandLocalSurfaceView(frame: NSRect(x: 0, y: 0, width: 240, height: 120))
    f.window.contentView!.addSubview(surface)
    surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "first", actions: [:], focusesOnAttachment: true)
    try await Task.sleep(for: .milliseconds(10))
    #expect(f.window.firstResponder === surface)
    let deliberateFocus = NSButton(title: "Other control", target: nil, action: nil)
    f.window.contentView!.addSubview(deliberateFocus); f.window.makeFirstResponder(deliberateFocus)
    surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "new crop", actions: [:], focusesOnAttachment: true)
    try await Task.sleep(for: .milliseconds(10))
    #expect(f.window.firstResponder === deliberateFocus)
    #expect(!f.window.isVisible)
}

@MainActor
@Test(arguments: [false, true])
func refusedManualCropKeepsDraftWhenCopyLockAppears(_ lockBeforeActions: Bool) throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    var saved = 0
    if lockBeforeActions { f.state.currentSession?.confirmedCopyPending = true }
    let actions = imageCropCommandActions(appState: f.state, item: f.a, visibleRect: .fullFrame,
        manualRect: .init(x: 0.1, y: 0.1, width: 0.5, height: 0.5), onManualSaved: { saved += 1 })
    if lockBeforeActions { #expect(actions[.saveManualCrop]?.enabled == false) }
    else { f.state.currentSession?.confirmedCopyPending = true }
    actions[.saveManualCrop]?.run()
    #expect(saved == 0)
    #expect(!f.state.isCropInProgress(for: f.a))
}

@MainActor
@Test func compareExcludeLeavesLockedImportedMembersVisibleAndUnchanged() throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    f.state.currentSession?.mediaItems[0].lifecycleState = .sourceCleanupPending
    f.state.currentSession?.mediaItems[0].selectionState = .included
    f.state.previewingMediaItemID = nil; f.state.openComparison(for: [f.a.id, f.b.id], title: "Locked and editable")
    f.state.focusComparisonItem(f.a.id)
    for id in [AppCommandID.markIncluded, .markCandidate, .markExcluded, .clearTriage, .toggleRAW] {
        #expect(!f.state.canPerformCompareCommand(id))
    }
    f.state.performCompareShortcut("X")
    #expect(f.state.comparingMediaItemIDs == [f.a.id, f.b.id])
    #expect(f.state.currentSession?.mediaItems[0].selectionState == .included)
    f.state.selectAllComparisonItems()
    #expect(f.state.canPerformCompareCommand(.markExcluded))
    #expect(!f.state.canPerformCompareCommand(.toggleRAW))
    f.state.performCompareShortcut("X")
    #expect(f.state.comparingMediaItemIDs == [f.a.id])
    #expect(f.state.currentSession?.mediaItems[0].selectionState == .included)
    #expect(f.state.currentSession?.mediaItems[1].selectionState == .excluded)
    #expect(f.state.statusMessage.contains("1 copied item"))
}

@MainActor
@Test func samePhotoCancelAndFitWinBeforeCanvasRedraw() async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let interaction = ImageInteractionContext()
    var zoom: CGFloat = 1, manual: CropNormalizedRect?, calls = 0
    let id = UUID(), image = NSImage(size: .init(width: 100, height: 80))
    func canvas() -> LockedCompareImageCanvas {
        return LockedCompareImageCanvas(itemID: id, contextKey: String(interaction.canvasRevision),
            contextIsCurrent: interaction.canvasOwnership(appState: f.state), image: image,
            zoom: Binding(get: { zoom }, set: { zoom = $0 }), synchronizedViewport: .constant(.zero),
            visibleCropRect: .constant(.fullFrame), panCommand: .idle, isPanLocked: false, isCropSelectionEnabled: true,
            manualCropRect: Binding(get: { manual }, set: { manual = $0 }),
            onManualCropSelectionChanged: { _ in calls += 1 }, onManualCropRejected: {})
    }
    let rect = CropNormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    let coordinator = canvas().makeCoordinator()
    coordinator.updateManualCropSelection(rect); coordinator.updateZoom(3)
    // Cancel and Fit act synchronously. The representable has not updated its parent yet.
    interaction.supersedeCanvas(); manual = nil; zoom = 1
    try await Task.sleep(for: .milliseconds(10))
    #expect(manual == nil); #expect(zoom == 1); #expect(calls == 0)
    coordinator.parent = canvas()
    coordinator.updateManualCropSelection(rect); coordinator.updateZoom(2)
    try await Task.sleep(for: .milliseconds(10))
    #expect(manual == rect); #expect(zoom == 2); #expect(calls == 1)
}

@MainActor
@Test func heldCropCommandCannotSaveOlderGeometryBeforeSurfaceRedraw() async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let interaction = ImageInteractionContext()
    var draft = CropNormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    let binding = imageTrackedBinding(Binding(get: { draft }, set: { draft = $0 }), interaction: interaction)
    let first = CropNormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    let second = CropNormalizedRect(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
    func actions(_ rect: CropNormalizedRect) -> [AppCommandID: SheetCommandAction] {
        return imageOwnedCommandActions(appState: f.state,
            actions: imageCropCommandActions(appState: f.state, item: f.a, visibleRect: .fullFrame, manualRect: rect),
            isCurrent: interaction.commandOwnership())
    }
    let old = actions(first)
    binding.wrappedValue = second // The binding changed, but native surface registration has not redrawn.
    old[.saveManualCrop]?.run()
    #expect(!f.state.isCropInProgress(for: f.a))
    actions(draft)[.saveManualCrop]?.run()
    try await waitForImageCondition { !f.state.isCropInProgress(for: f.a) }
    let url = f.a.sourceURL.deletingPathExtension().appendingPathExtension("crops.json")
    let manifest = try JSONDecoder().decode(CropManifest.self, from: Data(contentsOf: url))
    #expect(manifest.crops.map(\.normalizedRect) == [second])
}

@MainActor
@Test func oneCanvasDragPublishesGeometryTogetherAndInvalidatesHeldCommands() async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let interaction = ImageInteractionContext()
    var visible = CropNormalizedRect.fullFrame, manual: CropNormalizedRect?, zoom: CGFloat = 1, runs = 0
    let ownership = interaction.commandOwnership()
    let actions = imageOwnedCommandActions(appState: f.state, actions: [.saveManualCrop: .init(run: { runs += 1 })], isCurrent: ownership)
    let parent = LockedCompareImageCanvas(itemID: f.a.id,
        contextIsCurrent: interaction.canvasOwnership(appState: f.state), image: NSImage(size: .init(width: 100, height: 80)),
        zoom: imageTrackedBinding(Binding(get: { zoom }, set: { zoom = $0 }), interaction: interaction), synchronizedViewport: .constant(.zero),
        visibleCropRect: imageTrackedBinding(Binding(get: { visible }, set: { visible = $0 }), interaction: interaction),
        panCommand: .idle, isPanLocked: false, isCropSelectionEnabled: true,
        manualCropRect: imageTrackedBinding(Binding(get: { manual }, set: { manual = $0 }), interaction: interaction),
        onManualCropSelectionChanged: { _ in }, onManualCropRejected: {})
    let coordinator = parent.makeCoordinator(), rect = CropNormalizedRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    coordinator.updateVisibleCrop(rect); coordinator.updateManualCropSelection(rect); coordinator.updateZoom(2)
    try await Task.sleep(for: .milliseconds(10))
    #expect(visible == rect); #expect(manual == rect); #expect(zoom == 2)
    actions[.saveManualCrop]?.run(); #expect(runs == 0)
    imageOwnedCommandActions(appState: f.state, actions: [.saveManualCrop: .init(run: { runs += 1 })],
        isCurrent: interaction.commandOwnership())[.saveManualCrop]?.run()
    #expect(runs == 1)
}

@MainActor
@Test func previewInspectorIsAvailableOnlyWithItsExplicitOwnedHandler() throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let native = try LocalSurfaceFixture(); defer { native.close() }
    let surface = CommandLocalSurfaceView(frame: native.window.contentView!.bounds)
    native.window.contentView!.addSubview(surface)
    var toggles = 0
    let handle = surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "Preview",
        actions: [.toggleInspector: .init(run: { toggles += 1 })], ownsWindow: true)
    #expect(handle.isEnabled(.toggleInspector)); handle.run(.toggleInspector); #expect(toggles == 1)
    let emptyPreview = surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "Preview without handler", actions: [:], ownsWindow: true)
    #expect(!emptyPreview.isEnabled(.toggleInspector))
    let settings = surface.configure(coordinator: f.state.commandCoordinator, scope: .settings, contextKey: "Settings",
        actions: [.toggleInspector: .init(run: { toggles += 1 })], ownsWindow: true)
    #expect(!settings.isEnabled(.toggleInspector)); settings.run(.toggleInspector); #expect(toggles == 1)
    let borrowed = surface.configure(coordinator: f.state.commandCoordinator, scope: .preview, contextKey: "Preview inside Settings",
        actions: [.toggleInspector: .init(run: { toggles += 1 })], ownsWindow: false)
    #expect(!borrowed.isEnabled(.toggleInspector)); borrowed.run(.toggleInspector); #expect(toggles == 1)
}

@MainActor
@Test(arguments: [false, true])
func lateCopyLockKeepsCropOnDiskWithoutInventingSessionIntegration(_ navigated: Bool) async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let gate = ImageCompletionGate(); f.delayedCrop(gate)
    f.crop(); try await waitForImageGate(gate)
    f.state.currentSession?.confirmedCopyPending = true
    if navigated { f.state.previewingMediaItemID = f.b.id; f.state.focusedReviewItemID = f.b.id; f.state.selectedMediaItemIDs = [f.b.id]; f.state.statusMessage = "Current B decision" }
    await gate.release(); try await waitForImageCondition { !f.state.isCropInProgress(for: f.a) }
    #expect(f.state.currentSession?.mediaItems.count == 2)
    #expect(f.state.currentSession?.mediaItems.first { $0.id == f.a.id }?.cropRelationship == nil)
    #expect(f.state.previewingMediaItemID == (navigated ? f.b.id : f.a.id))
    #expect(f.state.focusedReviewItemID == (navigated ? f.b.id : f.a.id))
    #expect(f.state.selectedMediaItemIDs == [navigated ? f.b.id : f.a.id])
    #expect(navigated ? f.state.statusMessage == "Current B decision" : f.state.statusMessage.contains("Reload"))
    #expect(FileManager.default.fileExists(atPath: f.a.sourceURL.deletingLastPathComponent().appendingPathComponent("a-cropped.jpg").path))
}

@MainActor
@Test func cropSavingDefersNewAndAlreadyReviewedCopyConfirmation() async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    f.state.currentSession?.mediaItems[0].selectionState = .included
    let walk = Walk(title: "Fixture Walk", date: try #require(f.a.capturedAt), mediaItemIDs: [f.a.id], tripTarget: .defaultMonth)
    let editor = WalkCommitEditorState(id: UUID(), walks: [walk], existingTrips: [], tripDisplayLabel: "Trip", walkDisplayLabel: "Walk")
    f.state.updateWalkCommitEditor(editor)
    #expect(f.state.canCommitImport)
    let gate = ImageCompletionGate(); f.delayedCrop(gate)
    f.crop(); try await waitForImageGate(gate)
    #expect(!f.state.canCommitImport)
    f.state.confirmWalkCommit()
    #expect(f.state.activeWalkCommitEditor?.id == editor.id)
    #expect(f.state.currentSession?.confirmedCopyPending != true)
    #expect(!f.state.importOperation.isRunning)
    await gate.release(); try await waitForImageCondition { !f.state.isCropInProgress(for: f.a) && !f.state.importOperation.isRunning }
    #expect(f.state.canCommitImport)
}

@MainActor
@Test func savingCropRejectsAnotherSamePhotoManualDraftBeforeRedraw() async throws {
    let f = try ImageCompletionFixture(); defer { f.close() }
    let interaction = ImageInteractionContext()
    var draft: CropNormalizedRect?
    let binding = imageManualCropBinding(Binding(get: { draft }, set: { draft = $0 }), appState: f.state, item: f.a, interaction: interaction)
    let gate = ImageCompletionGate(); f.delayedCrop(gate)
    f.crop(); try await waitForImageGate(gate)
    binding.wrappedValue = .init(x: 0.2, y: 0.2, width: 0.4, height: 0.4)
    #expect(draft == nil)
    await gate.release(); try await waitForImageCondition { !f.state.isCropInProgress(for: f.a) }
    binding.wrappedValue = .init(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
    #expect(draft?.width == 0.5)
}
