import CoreGraphics
import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func gpsSignedCoordinateAppliesHemisphereRef() {
    // West longitude / South latitude must be negative so UK (west) coordinates plot correctly.
    #expect(MetadataExtractor.signedCoordinate(magnitude: 1.35, ref: "W", negativeRef: "W") == -1.35)
    #expect(MetadataExtractor.signedCoordinate(magnitude: 51.85, ref: "N", negativeRef: "S") == 51.85)
    #expect(MetadataExtractor.signedCoordinate(magnitude: 33.9, ref: "S", negativeRef: "S") == -33.9)
    #expect(MetadataExtractor.signedCoordinate(magnitude: 2.3, ref: "E", negativeRef: "W") == 2.3)
    #expect(MetadataExtractor.signedCoordinate(magnitude: nil, ref: "W", negativeRef: "W") == nil)
    #expect(MetadataExtractor.signedCoordinate(magnitude: 1.35, ref: nil, negativeRef: "W") == 1.35)
}

@Test func cropDragModeUsesEdgeBandsAndCorners() {
    // Slice A (#3): whole edges resize, not just tiny squares; corners win at overlaps.
    let selection = CGRect(x: 100, y: 100, width: 200, height: 200)
    let tolerance: CGFloat = 12
    #expect(CropSelectionGeometry.dragMode(at: CGPoint(x: 300, y: 200), in: selection, tolerance: tolerance) == .resize(.right))
    #expect(CropSelectionGeometry.dragMode(at: CGPoint(x: 200, y: 300), in: selection, tolerance: tolerance) == .resize(.top))
    #expect(CropSelectionGeometry.dragMode(at: CGPoint(x: 300, y: 300), in: selection, tolerance: tolerance) == .resize(.topRight))
    #expect(CropSelectionGeometry.dragMode(at: CGPoint(x: 200, y: 200), in: selection, tolerance: tolerance) == .move)
    #expect(CropSelectionGeometry.dragMode(at: CGPoint(x: 500, y: 500), in: selection, tolerance: tolerance) == nil)
}

@Test func cropNudgeClampsWithinImage() {
    // Slice A (#5): arrow-key nudge keeps the crop rect inside the unit square.
    let rect = CropNormalizedRect(x: 0.6, y: 0.6, width: 0.3, height: 0.3)
    let pushed = CropSelectionGeometry.nudgedNormalizedRect(rect, dx: 1, dy: 1, step: 0.5)
    #expect(abs(pushed.x - 0.7) < 0.0001)
    #expect(abs(pushed.y - 0.7) < 0.0001)
    #expect(abs(pushed.width - 0.3) < 0.0001)
    let pulled = CropSelectionGeometry.nudgedNormalizedRect(rect, dx: -1, dy: -1, step: 0.5)
    #expect(abs(pulled.x - 0.1) < 0.0001)
    #expect(abs(pulled.y - 0.1) < 0.0001)
}

@Test func reviewGridMetricsUseRequestedColumnsForCardWidth() {
    let compact = ReviewGridMetrics(availableWidth: 540, requestedColumnCount: 2)
    let wide = ReviewGridMetrics(availableWidth: 1_100, requestedColumnCount: 4)
    let singleColumn = ReviewGridMetrics(availableWidth: 1_100, requestedColumnCount: 1)

    #expect(compact.columnCount == 2)
    #expect(wide.columnCount == 4)
    #expect(compact.cardWidth >= ReviewGridMetrics.minCardWidth)
    #expect(wide.cardWidth >= ReviewGridMetrics.minCardWidth)
    #expect(singleColumn.cardWidth > wide.cardWidth)
    #expect(singleColumn.cardWidth > ReviewGridMetrics.maxCardWidth)
}

@Test func compareGridDefaultColumnCountMatchesCompareExpectations() {
    #expect(CompareGridMetrics.defaultColumnCount(for: 1) == 1)
    #expect(CompareGridMetrics.defaultColumnCount(for: 2) == 2)
    #expect(CompareGridMetrics.defaultColumnCount(for: 3) == 2)
    #expect(CompareGridMetrics.defaultColumnCount(for: 4) == 2)
    #expect(CompareGridMetrics.defaultColumnCount(for: 8) == 2)
}

@Test func compareGridMetricsUseRequestedColumnsAndClampToItemCount() {
    let fourColumns = CompareGridMetrics(
        availableWidth: 1_600,
        requestedColumnCount: 4,
        itemCount: 8
    )
    let clampedColumns = CompareGridMetrics(
        availableWidth: 1_600,
        requestedColumnCount: 8,
        itemCount: 3
    )

    #expect(fourColumns.columnCount == 4)
    #expect(fourColumns.rowCount == 2)
    #expect(fourColumns.cardWidth > 300)
    #expect(clampedColumns.columnCount == 3)
    #expect(clampedColumns.rowCount == 1)
}

@Test func mediaItemDisplayAspectRatioUsesMetadataOrFallback() {
    let withMetadata = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/a.jpg"),
        relativePath: "a.jpg",
        fileName: "a.jpg",
        baseName: "a",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: 6_000, pixelHeight: 4_000, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "a"
    )
    let fallback = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/b.jpg"),
        relativePath: "b.jpg",
        fileName: "b.jpg",
        baseName: "b",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "b"
    )

    #expect(abs(withMetadata.displayAspectRatio - 1.5) < 0.0001)
    #expect(abs(fallback.displayAspectRatio - (4.0 / 3.0)) < 0.0001)
}

@Test func mediaItemCompactDisplayNameUsesTrailingDigitsWhenPresent() {
    let numbered = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/IMG_0042.JPG"),
        relativePath: "100CANON/IMG_0042.JPG",
        fileName: "IMG_0042.JPG",
        baseName: "IMG_0042",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "img42"
    )
    let fallback = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/BRIDGE.JPG"),
        relativePath: "BRIDGE.JPG",
        fileName: "BRIDGE.JPG",
        baseName: "BRIDGE",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "bridge"
    )

    #expect(numbered.compactDisplayName == "0042")
    #expect(fallback.compactDisplayName == "BRIDGE")
}

@Test func mediaItemCompactCapturedAtLabelUsesShortReviewTimestamp() {
    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 26
    components.hour = 8
    components.minute = 4
    components.timeZone = TimeZone(secondsFromGMT: 0)
    let date = Calendar(identifier: .gregorian).date(from: components)!

    let item = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/a.jpg"),
        relativePath: "a.jpg",
        fileName: "a.jpg",
        baseName: "a",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: date,
        metadata: MediaMetadata(capturedAt: date, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "a"
    )

    #expect(item.compactCapturedAtLabel == "26 Mar 08:04")
}

@Test func compareViewportRoundTripsNormalizedAndContentOrigins() {
    let contentSize = CGSize(width: 2_000, height: 1_500)
    let viewportSize = CGSize(width: 800, height: 600)
    let origin = CGPoint(x: 300, y: 225)

    let normalized = CompareViewport.normalizedOrigin(
        contentSize: contentSize,
        viewportSize: viewportSize,
        boundsOrigin: origin
    )
    let roundTrip = normalized.contentOrigin(contentSize: contentSize, viewportSize: viewportSize)

    #expect(abs(roundTrip.x - origin.x) < 0.001)
    #expect(abs(roundTrip.y - origin.y) < 0.001)
}

@Test func compareViewportNudgeClampsWithinBounds() {
    let viewport = CompareViewport(x: 0.95, y: 0.08)
    let nudged = viewport.nudged(dx: 1, dy: -1, step: 0.12)

    #expect(nudged.x == 1)
    #expect(nudged.y == 0)
}

@Test func canvasZoomMathAnchorsZoomAroundPointer() {
    let origin = CanvasZoomPanMath.pointerAnchoredOrigin(
        oldContentSize: CGSize(width: 1_000, height: 800),
        newContentSize: CGSize(width: 2_000, height: 1_600),
        viewportSize: CGSize(width: 500, height: 400),
        oldBoundsOrigin: CGPoint(x: 100, y: 80),
        anchorDocumentPoint: CGPoint(x: 350, y: 280)
    )

    #expect(origin == CGPoint(x: 450, y: 360))
}

@Test func canvasZoomMathClampsDraggedPanWithinImageBounds() {
    let origin = CanvasZoomPanMath.draggedOrigin(
        startOrigin: CGPoint(x: 450, y: 380),
        translation: CGSize(width: -200, height: -120),
        contentSize: CGSize(width: 1_000, height: 800),
        viewportSize: CGSize(width: 500, height: 400)
    )

    #expect(origin == CGPoint(x: 500, y: 400))
}

@Test func canvasZoomMathClampsWheelZoomRange() {
    #expect(CanvasZoomPanMath.zoom(from: 3.8, multiplier: 2) == 4)
    #expect(CanvasZoomPanMath.zoom(from: 0.3, multiplier: 0.2) == 0.25)
}

@Test func cropGeometryMapperConvertsNormalizedRectBackToDocumentRect() throws {
    let documentRect = try #require(CropGeometryMapper.documentRect(
        normalizedRect: CropNormalizedRect(x: 0.25, y: 0.2, width: 0.5, height: 0.4),
        documentSize: CGSize(width: 800, height: 600)
    ))

    #expect(documentRect == CGRect(x: 200, y: 240, width: 400, height: 240))
}

@Test func cropSelectionGeometryCreatesMovesAndResizesWithinBounds() {
    let documentSize = CGSize(width: 300, height: 220)
    let startRect = CGRect(x: 80, y: 60, width: 120, height: 80)

    let created = CropSelectionGeometry.updatedRect(
        mode: .create,
        startRect: nil,
        startPoint: CGPoint(x: 260, y: 190),
        currentPoint: CGPoint(x: 100, y: 70),
        documentSize: documentSize
    )
    let moved = CropSelectionGeometry.updatedRect(
        mode: .move,
        startRect: startRect,
        startPoint: CGPoint(x: 100, y: 100),
        currentPoint: CGPoint(x: 500, y: 500),
        documentSize: documentSize
    )
    let resized = CropSelectionGeometry.updatedRect(
        mode: .resize(.topLeft),
        startRect: startRect,
        startPoint: CGPoint(x: 80, y: 140),
        currentPoint: CGPoint(x: 40, y: 180),
        documentSize: documentSize
    )

    #expect(created == CGRect(x: 100, y: 70, width: 160, height: 120))
    #expect(moved == CGRect(x: 180, y: 140, width: 120, height: 80))
    #expect(resized == CGRect(x: 40, y: 60, width: 160, height: 120))
}

@Test func cropSelectionGeometryChoosesHandlesBeforeMove() {
    let selection = CGRect(x: 80, y: 60, width: 120, height: 80)

    #expect(CropSelectionGeometry.dragMode(
        at: CGPoint(x: 80, y: 140),
        in: selection,
        tolerance: 10
    ) == .resize(.topLeft))
    #expect(CropSelectionGeometry.dragMode(
        at: CGPoint(x: 140, y: 100),
        in: selection,
        tolerance: 10
    ) == .move)
    #expect(CropSelectionGeometry.dragMode(
        at: CGPoint(x: 40, y: 40),
        in: selection,
        tolerance: 10
    ) == nil)
}

@Test func compareKeyboardPanDirectionMapsVimKeys() {
    #expect(CompareKeyboardPanDirection(key: "h") == .left)
    #expect(CompareKeyboardPanDirection(key: "j") == .down)
    #expect(CompareKeyboardPanDirection(key: "k") == .up)
    #expect(CompareKeyboardPanDirection(key: "l") == .right)
    #expect(CompareKeyboardPanDirection(key: "q") == nil)
}

@Test func sidebarTreeExpansionDefaultsExposeMonthsWithoutOpeningMonthChildren() {
    let walk = BrowserNode(
        id: "archive-walk",
        title: "Morning Walk",
        subtitle: nil,
        kind: .archiveWalkFolder,
        parentID: "archive-month-2026-05",
        mediaItemIDs: [],
        children: nil
    )
    let month = BrowserNode(
        id: "archive-month-2026-05",
        title: "05 - May",
        subtitle: nil,
        kind: .month,
        parentID: "archive-year-2026",
        mediaItemIDs: [],
        children: [walk]
    )
    let year = BrowserNode(
        id: "archive-year-2026",
        title: "2026",
        subtitle: nil,
        kind: .year,
        parentID: "archive-root",
        mediaItemIDs: [],
        children: [month]
    )
    let root = BrowserNode(
        id: "archive-root",
        title: "Archive",
        subtitle: nil,
        kind: .archiveRoot,
        parentID: "section-archive-library",
        mediaItemIDs: [],
        children: [year]
    )
    let section = BrowserNode(
        id: "section-archive-library",
        title: "Archive Library",
        subtitle: nil,
        kind: .archiveSection,
        parentID: nil,
        mediaItemIDs: [],
        children: [root]
    )

    let expandedIDs = SidebarTreeExpansion.defaultExpandedNodeIDs(for: [section])

    #expect(expandedIDs.contains("section-archive-library"))
    #expect(expandedIDs.contains("archive-root"))
    #expect(expandedIDs.contains("archive-year-2026"))
    #expect(!expandedIDs.contains("archive-month-2026-05"))
    #expect(!expandedIDs.contains("archive-walk"))
}

@Test func appChromeKeyboardShortcutsRequireCommandOption() {
    #expect(AppChromeKeyboardShortcut(key: "s", modifiers: [.command, .option]) == .toggleSidebar)
    #expect(AppChromeKeyboardShortcut(key: "I", modifiers: [.command, .option]) == .toggleInspector)
    #expect(AppChromeKeyboardShortcut(key: "s", modifiers: [.command]) == nil)
    #expect(AppChromeKeyboardShortcut(key: "i", modifiers: [.command, .option, .shift]) == nil)
}

@Test func reviewGridClickContextTracksModifiersAndDoubleClick() {
    let shiftDoubleClick = ReviewGridClickContext(modifiers: [.shift], clickCount: 2)
    let commandClick = ReviewGridClickContext(modifiers: [.command], clickCount: 1)

    #expect(shiftDoubleClick.isShiftPressed)
    #expect(!shiftDoubleClick.isCommandPressed)
    #expect(shiftDoubleClick.isDoubleClick)

    #expect(!commandClick.isShiftPressed)
    #expect(commandClick.isCommandPressed)
    #expect(!commandClick.isDoubleClick)
}

@MainActor
@Test func doubleClickSelectionOpensPreviewForFocusedItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.handleGridSelection(
        for: items[1].id,
        click: ReviewGridClickContext(modifiers: [], clickCount: 2)
    )

    #expect(state.selectedMediaItemIDs == [items[1].id])
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.previewingMediaItemID == items[1].id)
}

@MainActor
@Test func selectShortcutMarksFocusedItemAndAdvancesToNextItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()

    state.performReviewShortcut("S")

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .included)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@MainActor
@Test func excludeShortcutMarksFocusedItemAndAdvancesToNextItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()

    state.performReviewShortcut("X")

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .excluded)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@MainActor
@Test func candidateShortcutMarksFocusedItemAndAdvancesToNextItem() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()

    state.performReviewShortcut("C")

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .candidate)
    #expect(updatedItem?.importRawCompanions == false)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@MainActor
@Test func compareRequestDeduplicatesIDsAndStoresTitle() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[0].id, items[1].id, items[0].id], title: "Compare Burst")

    #expect(state.compareSheetTitle == "Compare Burst")
    #expect(state.comparingMediaItemIDs == [items[0].id, items[1].id])
    #expect(state.compareGridColumnCount == 2)
    #expect(state.selectedMediaItemIDs == [items[0].id])
    #expect(state.focusedReviewItemID == items[0].id)
}

@MainActor
@Test func removingCompareItemKeepsRemainingItemsOpen() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.setCompareGridColumnCount(3)
    state.removeItemFromComparison(items[1].id)

    #expect(state.comparingMediaItemIDs == [items[0].id, items[2].id])
    #expect(state.compareGridColumnCount == 2)

    state.removeItemFromComparison(items[0].id)
    #expect(state.comparingMediaItemIDs == [items[2].id])
    #expect(state.compareGridColumnCount == 1)

    state.removeItemFromComparison(items[2].id)
    #expect(state.comparingMediaItemIDs.isEmpty)
    #expect(state.compareGridColumnCount == 1)
}

@MainActor
@Test func compareResetColumnsReturnsToTwoColumnDefault() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.setCompareGridColumnCount(4)
    state.resetCompareGridColumnCount()

    #expect(state.compareGridColumnCount == 2)
}

@MainActor
@Test func compareArrowNavigationMovesFocusedItemWithinCompareSet() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.moveComparisonFocus(dx: 1, dy: 0)

    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
    #expect(state.compareState.snapshot.preferredScrollTargetID == items[1].id)

    state.moveComparisonFocus(dx: 0, dy: 1)

    #expect(state.focusedReviewItemID == items[3].id)
    #expect(state.selectedMediaItemIDs == [items[3].id])
    #expect(state.compareState.snapshot.preferredScrollTargetID == items[3].id)
}

@MainActor
@Test func compareCloseRestoresPreviousReviewSelection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[2].id])

    state.openComparison(for: [items[0].id, items[1].id], title: "Compare Burst")
    state.closeComparison()

    #expect(state.selectedMediaItemIDs == [items[2].id])
    #expect(state.focusedReviewItemID == items[2].id)
    #expect(!state.reviewGridHasFocus)
}

@MainActor
@Test func compareSelectAllAndDeselectStayScopedToCompareItems() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[0].id, items[2].id], title: "Compare Pair")
    state.selectAllVisibleMedia()
    #expect(state.selectedMediaItemIDs == [items[0].id, items[2].id])

    state.selectedMediaItemIDs = Set(items.map(\.id))
    state.selectAllComparisonItems()

    #expect(state.selectedMediaItemIDs == [items[0].id, items[2].id])
    #expect(state.focusedReviewItemID == items[0].id)

    state.selectedMediaItemIDs.insert(items[3].id)
    state.deselectComparisonItems()

    #expect(state.selectedMediaItemIDs.isEmpty)
    #expect(state.focusedReviewItemID == items[0].id)
}

@MainActor
@Test func compareClickSelectionNeverExtendsThroughFolderItems() {
    let items = makeSelectionItems(count: 5)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[0].id, items[2].id, items[4].id], title: "Compare Alternates")
    state.handleGridSelection(for: items[0].id, click: ReviewGridClickContext(modifiers: [], clickCount: 1))
    state.handleGridSelection(for: items[4].id, click: ReviewGridClickContext(modifiers: [.shift], clickCount: 1))

    #expect(state.selectedMediaItemIDs == [items[0].id, items[2].id, items[4].id])

    state.selectedMediaItemIDs = Set(items.map(\.id))
    state.handleGridSelection(for: items[2].id, click: ReviewGridClickContext(modifiers: [.command], clickCount: 1))

    #expect(state.selectedMediaItemIDs == [items[0].id, items[4].id])
    #expect(state.focusedReviewItemID == items[2].id)
}

@MainActor
@Test func compareSpaceToggleDropsStaleOutsideSelection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[1].id, items[3].id], title: "Compare Pair")
    state.selectedMediaItemIDs = Set(items.map(\.id))
    state.focusedReviewItemID = items[1].id

    state.toggleFocusedReviewItemSelection()

    #expect(state.selectedMediaItemIDs == [items[3].id])
    #expect(state.focusedReviewItemID == items[1].id)
}

@MainActor
@Test func compareGenericExcludeWithStaleFolderSelectionMutatesOnlyCompareItems() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-compare-stale-exclude", isDirectory: true)
    let base = Date(timeIntervalSince1970: 31_000)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "outside-0.jpg", capturedAt: base, selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "outside-1.jpg", capturedAt: base.addingTimeInterval(1), selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare-0.jpg", capturedAt: base.addingTimeInterval(2), selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare-1.jpg", capturedAt: base.addingTimeInterval(3), selectionState: .included, lifecycleState: .selectedForImport)
    ]
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[2].id, items[3].id], title: "Compare Pair")
    state.selectedMediaItemIDs = Set(items.map(\.id))
    state.excludeCurrentSelectionFromImport()

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .included)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .included)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[2].id })?.selectionState == .excluded)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[3].id })?.selectionState == .excluded)
    #expect(state.comparingMediaItemIDs.isEmpty)
}

@MainActor
@Test func compareGenericTriageActionsIgnoreStaleOutsideSelection() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-compare-stale-actions", isDirectory: true)
    let base = Date(timeIntervalSince1970: 32_000)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "outside.jpg", capturedAt: base, selectionState: .excluded),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare-0.jpg", capturedAt: base.addingTimeInterval(1)),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare-1.jpg", capturedAt: base.addingTimeInterval(2)),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare-2.jpg", capturedAt: base.addingTimeInterval(3), selectionState: .included, lifecycleState: .selectedForImport)
    ]
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[1].id, items[2].id, items[3].id], title: "Compare Trio")
    state.selectedMediaItemIDs = [items[0].id]
    state.focusedReviewItemID = items[1].id
    state.markCurrentSelectionForImport()

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .excluded)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .included)
    #expect(state.focusedReviewItemID == items[2].id)

    state.selectedMediaItemIDs = [items[0].id, items[2].id]
    state.markCurrentSelectionAsCandidate()

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .excluded)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[2].id })?.selectionState == .candidate)

    state.selectedMediaItemIDs = [items[0].id, items[3].id]
    state.unmarkCurrentSelectionForImport()

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .excluded)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[3].id })?.selectionState == .undecided)
}

@MainActor
@Test func compareRawToggleWithStaleFolderSelectionMutatesOnlyCompareItems() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-compare-stale-raw", isDirectory: true)
    let base = Date(timeIntervalSince1970: 33_000)
    let outsideCompanion = CompanionFile(
        sourceURL: sourceRoot.appendingPathComponent("outside.cr3"),
        relativePath: "outside.cr3",
        fileName: "outside.cr3",
        fileSizeBytes: 1,
        kind: .raw
    )
    let compareCompanion = CompanionFile(
        sourceURL: sourceRoot.appendingPathComponent("compare.cr3"),
        relativePath: "compare.cr3",
        fileName: "compare.cr3",
        fileSizeBytes: 1,
        kind: .raw
    )
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "outside.jpg", capturedAt: base, companionFiles: [outsideCompanion]),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare.jpg", capturedAt: base.addingTimeInterval(1), companionFiles: [compareCompanion]),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "compare-peer.jpg", capturedAt: base.addingTimeInterval(2))
    ]
    let state = makeReviewAppState(items: items)

    state.openComparison(for: [items[1].id, items[2].id], title: "Compare Pair")
    state.selectedMediaItemIDs = Set(items.map(\.id))
    state.toggleRawForCurrentMediaSelection()

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.importRawCompanions == false)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.importRawCompanions == true)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .included)
}

@MainActor
@Test func compareShortcutQRemovesFocusedItemAndKeepsNextFocused() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.performCompareShortcut("Q")

    #expect(state.comparingMediaItemIDs == [items[1].id, items[2].id])
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
    #expect(state.compareState.snapshot.preferredScrollTargetID == items[1].id)
}

@MainActor
@Test func compareExcludeRemovesItemFromCompareAndAdvancesFocus() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.performCompareShortcut("X")

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .excluded)
    #expect(state.comparingMediaItemIDs == [items[1].id, items[2].id])
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
    #expect(state.compareState.snapshot.preferredScrollTargetID == items[1].id)
}

@MainActor
@Test func compareIncludeAndCandidateKeepItemsInCompareAndAdvanceFocus() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)

    state.openComparison(for: items.map(\.id), title: "Compare Burst")
    state.performCompareShortcut("S")

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .included)
    #expect(state.comparingMediaItemIDs == items.map(\.id))
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.compareState.snapshot.preferredScrollTargetID == items[1].id)

    state.performCompareShortcut("C")

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .candidate)
    #expect(state.comparingMediaItemIDs == items.map(\.id))
    #expect(state.focusedReviewItemID == items[2].id)
    #expect(state.compareState.snapshot.preferredScrollTargetID == items[2].id)
}

@MainActor
@Test func reviewGridColumnPreferenceUsesLastMeasuredWidthForReflow() {
    let items = makeSelectionItems(count: 6)
    let state = makeReviewAppState(items: items)

    state.setReviewGridColumnCount(3)
    state.updateReviewGridMetrics(availableWidth: 1_100)
    #expect(state.reviewGridColumnCount == 3)

    state.setReviewGridColumnCount(4)
    #expect(state.reviewGridColumnCount == 4)

    state.resetReviewGridColumnCount()
    #expect(state.reviewGridColumnCount == ReviewGridMetrics.defaultRequestedColumnCount())
}

@MainActor
@Test func previewNavigationMovesThroughVisibleOrder() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.previewingMediaItemID = items[1].id
    state.focusedReviewItemID = items[1].id
    state.selectedMediaItemIDs = [items[1].id]

    state.navigatePreview(by: 1)

    #expect(state.previewingMediaItemID == items[2].id)
    #expect(state.focusedReviewItemID == items[2].id)
    #expect(state.selectedMediaItemIDs == [items[2].id])
}

@MainActor
@Test func previewTriageActionsMutatePreviewedItemOnly() {
    let items = makeSelectionItems(count: 3)
    let state = makeReviewAppState(items: items)
    state.previewingMediaItemID = items[1].id
    state.focusedReviewItemID = items[0].id
    state.selectedMediaItemIDs = [items[0].id]

    state.excludePreviewItemFromImport(items[1].id)

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.selectionState == .undecided)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .excluded)
    #expect(state.previewingMediaItemID == items[1].id)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])

    state.markPreviewItemForImport(items[1].id)

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .included)
}

@MainActor
@Test func previewRawToggleTargetsPreviewedItem() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-preview-raw", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 30_000)
    let companion = CompanionFile(
        sourceURL: sourceRoot.appendingPathComponent("second.cr3"),
        relativePath: "second.cr3",
        fileName: "second.cr3",
        fileSizeBytes: 1,
        kind: .raw
    )
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "first.jpg", capturedAt: capturedAt),
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "second.jpg",
            capturedAt: capturedAt.addingTimeInterval(1),
            companionFiles: [companion]
        )
    ]
    let state = makeReviewAppState(items: items)
    state.previewingMediaItemID = items[1].id

    state.toggleRawForPreviewItem(items[1].id)

    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })?.importRawCompanions == false)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.importRawCompanions == true)
    #expect(state.currentSession?.mediaItems.first(where: { $0.id == items[1].id })?.selectionState == .included)
    #expect(state.focusedReviewItemID == items[1].id)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@MainActor
@Test func dayContainerStillExposesMediaForReviewGrid() {
    let items = makeSelectionItems(count: 3)
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/review-container-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []
    state.setWorkspaceMode(.cameraTriage)

    let containerNode = state.browserNodeMap.values.first {
        !($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count
    }

    #expect(containerNode != nil)
    state.selectedSidebarNodeID = containerNode?.id
    #expect(state.visibleMediaItems.count == items.count)
}

@MainActor
@Test func groupedReviewInteractionItemsFollowExpandedSections() {
    let items = makeSelectionItems(count: 4)
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/grouped-review-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []
    state.setWorkspaceMode(.cameraTriage)

    let containerNode = state.browserNodeMap.values.first {
        !($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count
    }

    #expect(containerNode != nil)
    state.selectedSidebarNodeID = containerNode?.id
    state.setDayOrganizationMode(.daysAndBursts)
    state.setDayDetailDisplayMode(.sections)
    state.expandAllInlineSections()

    #expect(state.reviewInteractionItems.count == items.count)
    #expect(Set(state.reviewInteractionItems.map(\.id)) == Set(items.map(\.id)))
}

@MainActor
@Test func groupedReviewCanBeRequestedForDayContainerContexts() {
    let items = makeSelectionItems(count: 4)
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/grouped-review-shell", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []
    state.setWorkspaceMode(.cameraTriage)

    let containerNode = state.browserNodeMap.values.first(where: { node in
        state.selectedSidebarNodeID = node.id
        return state.canUseGroupedReviewMode
    })

    #expect(containerNode != nil)
    state.selectedSidebarNodeID = containerNode?.id
    #expect(state.canUseGroupedReviewMode)
    #expect(state.availableDayDetailDisplayModes == DayDetailDisplayMode.allCases)

    state.setDayDetailDisplayMode(.sections)

    #expect(state.dayDetailDisplayMode == .sections)
}

@MainActor
@Test func groupedReviewFallsBackCleanlyWhenCurrentNodeCannotBeGrouped() {
    let state = AppState(testing: true)

    #expect(!state.canUseGroupedReviewMode)
    #expect(state.availableDayDetailDisplayModes == [.review])

    state.setDayDetailDisplayMode(.sections)

    #expect(state.dayDetailDisplayMode == .review)
    #expect(state.statusMessage.contains("Grouped review is available"))
}

@MainActor
@Test func leafReviewContextNowExposesGroupedReviewFromVisibleItems() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.visibleMediaItems.count == items.count)
    #expect(state.canUseGroupedReviewMode)
    #expect(state.availableDayDetailDisplayModes == DayDetailDisplayMode.allCases)
    #expect(!state.inlineDaySections.isEmpty)

    state.setDayDetailDisplayMode(.sections)

    #expect(state.dayDetailDisplayMode == .sections)
}

@MainActor
@Test func flatReviewSnapshotDefersGroupedSectionPayloadUntilGroupedReviewOpens() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.dayDetailDisplayMode == .review)
    #expect(state.canUseGroupedReviewMode)
    #expect(state.reviewState.snapshot.canUseGroupedReviewMode)
    #expect(state.reviewState.snapshot.organizedInlineSections.isEmpty)
    #expect(state.reviewState.snapshot.groupedReviewSections.isEmpty)

    state.showGroupedReview()

    #expect(state.dayDetailDisplayMode == .sections)
    #expect(!state.reviewState.snapshot.organizedInlineSections.isEmpty)
    #expect(!state.reviewState.snapshot.groupedReviewSections.isEmpty)
    #expect(!state.expandedInlineSectionIDs.isEmpty)
}

@MainActor
@Test func openCurrentSelectionJumpsFromSidebarIntoReviewGrid() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.activePane == .sidebar)

    state.openCurrentSelection()

    #expect(state.activePane == .media)
    #expect(state.reviewGridHasFocus)
    #expect(state.focusedReviewItemID != nil)
    #expect(state.pendingReviewScrollTargetID == nil)
}

@MainActor
@Test func groupedSectionKeyboardNavigationTracksFocusedSection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(sections.count >= 2)
    #expect(state.focusedInlineSectionID == sections.first?.id)

    state.focusNextInlineSection()

    #expect(state.focusedInlineSectionID == sections[1].id)
    #expect(state.expandedInlineSectionIDs.contains(sections[1].id))

    state.collapseFocusedInlineSection()

    #expect(!state.expandedInlineSectionIDs.contains(sections[1].id))

    state.focusPreviousInlineSection()

    #expect(state.focusedInlineSectionID == sections[0].id)

    state.collapseFocusedInlineSection()
    #expect(!state.expandedInlineSectionIDs.contains(sections[0].id))

    state.expandFocusedInlineSection()
    #expect(state.expandedInlineSectionIDs.contains(sections[0].id))
}

@MainActor
@Test func plainArrowKeysOperateOnGroupedSectionsWhenSectionTargetIsActive() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(sections.count >= 2)
    state.focusInlineSection(sections[0].id)
    #expect(state.isGroupedSectionKeyboardTargetActive)

    state.handleReviewArrowKey(dx: 0, dy: 1, extending: false)

    #expect(state.focusedInlineSectionID == sections[1].id)

    state.handleReviewArrowKey(dx: -1, dy: 0, extending: false)
    #expect(!state.expandedInlineSectionIDs.contains(sections[1].id))

    state.handleReviewArrowKey(dx: 1, dy: 0, extending: false)
    #expect(state.expandedInlineSectionIDs.contains(sections[1].id))
}

@MainActor
@Test func plainArrowKeysStillMoveBetweenItemsWhenItemTargetIsActive() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    let firstFocusedID = state.focusedReviewItemID

    state.handleReviewArrowKey(dx: 1, dy: 0, extending: false)

    #expect(!state.isGroupedSectionKeyboardTargetActive)
    #expect(state.focusedReviewItemID != firstFocusedID)
    #expect(state.pendingReviewScrollTargetID == nil)
}

@MainActor
@Test func groupedSectionReturnEntersItemsAndEscapeReturnsToSectionSelection() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(!sections.isEmpty)
    state.focusInlineSection(sections[0].id)

    state.activateCurrentReviewTarget()

    #expect(!state.isGroupedSectionKeyboardTargetActive)
    #expect(state.focusedReviewItemID != nil)
    #expect(state.focusedInlineSectionID == sections[0].id)

    state.handleReviewEscape()

    #expect(state.isGroupedSectionKeyboardTargetActive)
    #expect(state.focusedInlineSectionID == sections[0].id)
}

@MainActor
@Test func groupedSectionCommandOpenDrillsIntoScopedReview() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.setDayOrganizationMode(.daysAndBursts)
    state.showGroupedReview()
    let sections = state.groupedReviewSections

    #expect(!sections.isEmpty)
    state.focusInlineSection(sections[0].id)

    state.openCurrentSelection()

    #expect(state.drilledInlineSectionID == sections[0].id)
    #expect(state.dayDetailDisplayMode == .review)
    #expect(state.visibleMediaItems.count == state.drilledInlineSectionMediaItemIDs.count)

    state.handleReviewEscape()

    #expect(state.drilledInlineSectionID == nil)
    #expect(state.dayDetailDisplayMode == .sections)
    #expect(state.focusedInlineSectionID == sections[0].id)
    #expect(state.visibleMediaItems.count == items.count)
}

@MainActor
@Test func keyboardSelectionMovementRequestsScrollToFocusedItem() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    let firstFocusedID = state.focusedReviewItemID

    state.moveGridSelection(by: 1, extending: false)

    #expect(state.focusedReviewItemID != firstFocusedID)
    #expect(state.pendingReviewScrollTargetID == nil)
}

@MainActor
@Test func focusOnlyReviewMovesDoNotRefreshSidebarSnapshot() {
    let items = makeSelectionItems(count: 6)
    let state = makeReviewAppState(items: items)

    let initialSidebarGeneration = state.sidebarSnapshotGeneration
    state.focusReviewSurface()
    let sidebarGenerationAfterFocus = state.sidebarSnapshotGeneration

    state.moveGridSelection(by: 1, extending: false)

    #expect(initialSidebarGeneration == sidebarGenerationAfterFocus)
    #expect(state.sidebarSnapshotGeneration == sidebarGenerationAfterFocus)
    #expect(state.reviewSnapshotGeneration > 0)
    #expect(state.navigationSnapshotGeneration > 0)
}

@MainActor
@Test func triageUpdatesDoNotRebuildBrowserTree() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)
    let initialRootIDs = state.browserRoots.map(\.id)

    state.focusReviewSurface()
    state.performReviewShortcut("S")

    #expect(state.browserRoots.map(\.id) == initialRootIDs)
}

@MainActor
@Test func toggleSidebarVisibilityUsesAppManagedState() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)

    #expect(state.sidebarState.snapshot.isVisible)

    state.toggleSidebarVisibility()
    #expect(!state.sidebarState.snapshot.isVisible)

    state.focusSidebarNavigation()
    #expect(state.sidebarState.snapshot.isVisible)
    #expect(state.activePane == .sidebar)
}

@MainActor
@Test func nativeSidebarVisibilityChangePreservesReviewFocusAndSidebarContent() {
    let items = makeSelectionItems(count: 4)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()

    let browserRootIDs = state.sidebarState.snapshot.tree.browserRoots.map(\.id)
    let reviewGeneration = state.reviewSnapshotGeneration

    state.isSidebarVisible = false

    #expect(!state.sidebarState.snapshot.isVisible)
    #expect(state.activePane == .media)
    #expect(state.reviewNavigationState.snapshot.reviewGridHasFocus)
    #expect(state.sidebarState.snapshot.tree.browserRoots.map(\.id) == browserRootIDs)
    #expect(state.reviewSnapshotGeneration == reviewGeneration)
}

@MainActor
@Test func hiddenInspectorDoesNotRefreshOnFocusMoves() {
    let items = makeSelectionItems(count: 5)
    let state = makeReviewAppState(items: items)
    state.focusReviewSurface()
    state.toggleDetailsInspector()

    let hiddenGeneration = state.inspectorSnapshotGeneration
    state.moveGridSelection(by: 1, extending: false)

    #expect(!state.inspectorState.snapshot.isVisible)
    #expect(state.inspectorSnapshotGeneration == hiddenGeneration)
}

@MainActor
@Test func keyboardSelectionRequestsScrollWhenFocusLeavesEstimatedVisiblePage() {
    let items = makeSelectionItems(count: 20)
    let state = makeReviewAppState(items: items)

    state.focusReviewSurface()
    state.pendingReviewScrollTargetID = nil

    for _ in 0..<12 {
        state.moveGridSelection(by: 1, extending: false)
    }

    #expect(state.focusedReviewItemID == items[12].id)
    #expect(state.pendingReviewScrollTargetID == items[12].id)
}

@MainActor
@Test func reviewFilterLimitsVisibleMediaByTriageState() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-filter-state", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "included.jpg", capturedAt: base, selectionState: .included),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "candidate.jpg", capturedAt: base.addingTimeInterval(1), selectionState: .candidate),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "excluded.jpg", capturedAt: base.addingTimeInterval(2), selectionState: .excluded),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "undecided.jpg", capturedAt: base.addingTimeInterval(3), selectionState: .undecided)
    ]
    let state = makeReviewAppState(items: items)

    state.setReviewFilter(.included)
    #expect(state.visibleMediaItems.map(\.id) == [items[0].id])

    state.setReviewFilter(.candidate)
    #expect(state.visibleMediaItems.map(\.id) == [items[1].id])

    state.setReviewFilter(.excluded)
    #expect(state.visibleMediaItems.map(\.id) == [items[2].id])

    state.setReviewFilter(.undecided)
    #expect(state.visibleMediaItems.map(\.id) == [items[3].id])

    state.setReviewFilter(.all)
    #expect(state.visibleMediaItems.count == 4)
}

@MainActor
@Test func croppedReviewFilterShowsOriginalAndCrop() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-crop-filter", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    var original = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001.jpg", capturedAt: base)
    var crop = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001-cropped.jpg", capturedAt: base)
    let other = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0002.jpg", capturedAt: base.addingTimeInterval(1))
    original.cropRelationship = CropRelationship(
        role: .original,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: ["IMG_0001-cropped.jpg"],
        cropFileNames: ["IMG_0001-cropped.jpg"],
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped.jpg",
        latestCropFileName: "IMG_0001-cropped.jpg"
    )
    crop.cropRelationship = CropRelationship(
        role: .crop,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: ["IMG_0001-cropped.jpg"],
        cropFileNames: ["IMG_0001-cropped.jpg"],
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped.jpg",
        latestCropFileName: "IMG_0001-cropped.jpg"
    )
    let state = makeReviewAppState(items: [crop, original, other])

    state.setReviewFilter(.cropped)

    #expect(state.visibleMediaItems.map(\.fileName) == ["IMG_0001.jpg", "IMG_0001-cropped.jpg"])
}

@Test func cropFamilySortsOriginalBeforeCropsUsingOriginalDate() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-crop-family-sort", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    var original = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001.jpg", capturedAt: base)
    var firstCrop = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001-cropped.jpg", capturedAt: base.addingTimeInterval(86_400))
    var secondCrop = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001-cropped-2.jpg", capturedAt: base.addingTimeInterval(-86_400))
    let other = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0002.jpg", capturedAt: base.addingTimeInterval(1))
    let cropPaths = ["IMG_0001-cropped.jpg", "IMG_0001-cropped-2.jpg"]
    let cropFileNames = ["IMG_0001-cropped.jpg", "IMG_0001-cropped-2.jpg"]
    original.cropRelationship = CropRelationship(
        role: .original,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: cropPaths,
        cropFileNames: cropFileNames,
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped-2.jpg",
        latestCropFileName: "IMG_0001-cropped-2.jpg"
    )
    firstCrop.cropRelationship = CropRelationship(
        role: .crop,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: cropPaths,
        cropFileNames: cropFileNames,
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped.jpg",
        latestCropFileName: "IMG_0001-cropped.jpg"
    )
    secondCrop.cropRelationship = CropRelationship(
        role: .crop,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: cropPaths,
        cropFileNames: cropFileNames,
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped-2.jpg",
        latestCropFileName: "IMG_0001-cropped-2.jpg"
    )

    let sorted = MediaItemSort.sorted([other, firstCrop, secondCrop, original])

    #expect(sorted.map(\.fileName) == ["IMG_0001.jpg", "IMG_0001-cropped.jpg", "IMG_0001-cropped-2.jpg", "IMG_0002.jpg"])
}

@MainActor
@Test func inspectorCropHistoryShowsVersionsAndSwitchesInApp() throws {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-crop-history", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    var original = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001.jpg", capturedAt: base)
    var firstCrop = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001-cropped.jpg", capturedAt: base)
    var secondCrop = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001-cropped-2.jpg", capturedAt: base)
    let cropPaths = ["IMG_0001-cropped.jpg", "IMG_0001-cropped-2.jpg"]
    let cropFileNames = ["IMG_0001-cropped.jpg", "IMG_0001-cropped-2.jpg"]
    original.cropRelationship = CropRelationship(
        role: .original,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: cropPaths,
        cropFileNames: cropFileNames,
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped-2.jpg",
        latestCropFileName: "IMG_0001-cropped-2.jpg"
    )
    firstCrop.cropRelationship = CropRelationship(
        role: .crop,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: cropPaths,
        cropFileNames: cropFileNames,
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped.jpg",
        latestCropFileName: "IMG_0001-cropped.jpg"
    )
    secondCrop.cropRelationship = CropRelationship(
        role: .crop,
        originalRelativePath: "IMG_0001.jpg",
        originalFileName: "IMG_0001.jpg",
        cropRelativePaths: cropPaths,
        cropFileNames: cropFileNames,
        manifestRelativePath: "IMG_0001.crops.json",
        latestCropRelativePath: "IMG_0001-cropped-2.jpg",
        latestCropFileName: "IMG_0001-cropped-2.jpg"
    )
    let state = makeReviewAppState(items: [firstCrop, original, secondCrop])
    state.selectedMediaItemIDs = [original.id]
    state.focusedReviewItemID = original.id

    let history = try #require(state.inspectorState.snapshot.cropHistory)
    #expect(history.versions.map(\.fileName) == ["IMG_0001.jpg", "IMG_0001-cropped.jpg", "IMG_0001-cropped-2.jpg"])
    #expect(history.versions.map(\.isCurrent) == [true, false, false])

    state.openCropVersion(relativePath: "IMG_0001-cropped-2.jpg")

    #expect(state.previewingMediaItemID == secondCrop.id)
    #expect(state.focusedReviewItemID == secondCrop.id)
    #expect(state.selectedMediaItemIDs == Set([secondCrop.id]))
    let updatedHistory = try #require(state.inspectorState.snapshot.cropHistory)
    #expect(updatedHistory.versions.map(\.isCurrent) == [false, false, true])
}

@MainActor
@Test func excludeCurrentSelectionUpdatesTriageStateAndClearsRawImportFlag() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-exclude-state", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 20_000)
    let companion = CompanionFile(
        sourceURL: sourceRoot.appendingPathComponent("first.cr3"),
        relativePath: "first.cr3",
        fileName: "first.cr3",
        fileSizeBytes: 1,
        kind: .raw
    )
    let items = [
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "first.jpg",
            capturedAt: capturedAt,
            selectionState: .included,
            importRawCompanions: true,
            companionFiles: [companion],
            lifecycleState: .selectedForImport
        ),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "second.jpg", capturedAt: capturedAt.addingTimeInterval(1))
    ]
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[0].id])

    state.excludeCurrentSelectionFromImport()

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .excluded)
    #expect(updatedItem?.lifecycleState == .discovered)
    #expect(updatedItem?.importRawCompanions == false)
}

@MainActor
@Test func rawTogglePromotesSelectedItemToIncluded() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-raw-promotion", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 20_000)
    let companion = CompanionFile(
        sourceURL: sourceRoot.appendingPathComponent("first.cr3"),
        relativePath: "first.cr3",
        fileName: "first.cr3",
        fileSizeBytes: 1,
        kind: .raw
    )
    let items = [
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "first.jpg",
            capturedAt: capturedAt,
            selectionState: .undecided,
            importRawCompanions: false,
            companionFiles: [companion],
            lifecycleState: .discovered
        )
    ]
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[0].id])

    state.toggleRawForCurrentMediaSelection()

    let updatedItem = state.currentSession?.mediaItems.first(where: { $0.id == items[0].id })
    #expect(updatedItem?.selectionState == .included)
    #expect(updatedItem?.lifecycleState == .selectedForImport)
    #expect(updatedItem?.importRawCompanions == true)
}

@MainActor
@Test func createWalkDraftFromSelectionPersistsDraftAndMarksOwnedItemsInInbox() async {
    let state = AppState(testing: true)
    let root = try! makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let base = Date(timeIntervalSince1970: 20_000)
    let fileNames = ["0.jpg", "1.jpg", "2.jpg", "3.jpg"]
    for fileName in fileNames {
        _ = try? writeTestFile(root.appendingPathComponent(fileName), contents: fileName)
    }
    let items = fileNames.enumerated().map { index, fileName in
        makeTestMediaItem(
            sourceRoot: root,
            fileName: fileName,
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: index < 2 ? .included : .undecided
        )
    }
    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: items,
        title: "Holiday Day One",
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.presentPhotoLogCreation()
    state.createPhotoLog(openAfterCreate: true)

    #expect(state.currentSession?.sessionKind == .walkDraft)
    #expect(state.currentSession?.mediaItems.map(\.id) == [items[0].id, items[1].id])
    #expect(state.sidebarState.snapshot.photoLogGroups.count == 1)
    #expect(state.sidebarState.snapshot.photoLogGroups.first?.logs.count == 1)

    await state.openSession(for: root)

    #expect(state.currentSession?.sessionKind == .inbox)
    #expect(state.currentSession?.mediaItems.map(\.relativePath) == ["0.jpg", "1.jpg", "2.jpg", "3.jpg"])
    let ownedSnapshot = state.reviewState.snapshot.visibleItems.first { $0.item.relativePath == "0.jpg" }
    let unownedSnapshot = state.reviewState.snapshot.visibleItems.first { $0.item.relativePath == "2.jpg" }
    #expect(ownedSnapshot?.sourceLogOwnership?.title == "Holiday Day One")
    #expect(ownedSnapshot?.sourceLogOwnership?.statusLabel == "In Log")
    #expect(ownedSnapshot?.sourceLogOwnership?.selectionState == .included)
    #expect(ownedSnapshot?.displaySelectionState == .included)
    #expect(ownedSnapshot?.item.selectionState == .undecided)
    #expect(unownedSnapshot?.sourceLogOwnership == nil)
}

@MainActor
@Test func openSavedWalkRestoresDraftAfterReturningToInbox() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let base = Date(timeIntervalSince1970: 30_000)
    let fileNames = ["0.jpg", "1.jpg", "2.jpg"]
    for fileName in fileNames {
        try writeTestFile(root.appendingPathComponent(fileName), contents: fileName)
    }
    let items = fileNames.enumerated().map { index, fileName in
        makeTestMediaItem(
            sourceRoot: root,
            fileName: fileName,
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: index < 2 ? .included : .undecided
        )
    }
    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: items,
        title: "Holiday Day Two",
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.presentPhotoLogCreation()
    state.createPhotoLog(openAfterCreate: true)
    let draftID = try #require(state.currentSession?.id)

    await state.openSession(for: root)
    #expect(state.currentSession?.sessionKind == .inbox)

    state.openSavedWalk(draftID)

    #expect(state.currentSession?.id == draftID)
    #expect(state.currentSession?.sessionKind == .walkDraft)
    #expect(state.currentSession?.walkMetadata.title == "Holiday Day Two")
    #expect(state.currentSession?.mediaItems.map(\.id) == [items[0].id, items[1].id])
}

@MainActor
@Test func editPhotoLogMembershipMovesItemsBetweenLogAndInbox() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let base = Date(timeIntervalSince1970: 35_000)
    let fileNames = ["0.jpg", "1.jpg", "2.jpg"]
    for fileName in fileNames {
        try writeTestFile(root.appendingPathComponent(fileName), contents: fileName)
    }
    let items = fileNames.enumerated().map { index, fileName in
        makeTestMediaItem(
            sourceRoot: root,
            fileName: fileName,
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: index == 0 ? .included : .undecided
        )
    }
    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: items,
        title: "Editable Log",
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.presentPhotoLogCreation()
    state.createPhotoLog(openAfterCreate: true)
    let logID = try #require(state.currentSession?.id)

    state.editPhotoLogMembership(logID)
    #expect(state.currentSession?.mediaItems.map(\.relativePath) == ["0.jpg", "1.jpg", "2.jpg"])
    #expect(state.statusMessage.contains("Editing log Editable Log"))
    #expect(state.statusMessage.contains("Change S/C/X status"))
    #expect(state.statusMessage.contains("mark more source-inbox photos"))

    state.selectMediaItems([items[2].id])
    state.markCurrentSelectionForImport()
    state.selectMediaItems([items[0].id])
    state.unmarkCurrentSelectionForImport()

    state.openSavedWalk(logID)
    #expect(state.currentSession?.mediaItems.map(\.relativePath) == ["2.jpg"])

    await state.openSession(for: root)
    #expect(state.currentSession?.sessionKind == .inbox)
    #expect(state.currentSession?.mediaItems.map(\.relativePath) == ["0.jpg", "1.jpg", "2.jpg"])
    let returnedOwnedSnapshot = state.reviewState.snapshot.visibleItems.first { $0.item.relativePath == "2.jpg" }
    let returnedUnownedSnapshot = state.reviewState.snapshot.visibleItems.first { $0.item.relativePath == "0.jpg" }
    #expect(returnedOwnedSnapshot?.sourceLogOwnership?.title == "Editable Log")
    #expect(returnedOwnedSnapshot?.sourceLogOwnership?.statusLabel == "In Log")
    #expect(returnedOwnedSnapshot?.sourceLogOwnership?.selectionState == .included)
    #expect(returnedOwnedSnapshot?.displaySelectionState == .included)
    #expect(returnedOwnedSnapshot?.item.selectionState == .undecided)
    #expect(returnedUnownedSnapshot?.sourceLogOwnership == nil)
}

@MainActor
@Test func openedPhotoLogKeepsCopiedStatusVisibleOnImportedItems() {
    let root = URL(fileURLWithPath: "/tmp/review-copied-log", isDirectory: true)
    let item = makeTestMediaItem(
        sourceRoot: root,
        fileName: "copied.jpg",
        capturedAt: Date(timeIntervalSince1970: 40_000),
        selectionState: .included,
        lifecycleState: .verified
    )
    let state = makeReviewAppState(items: [item])

    let snapshot = state.reviewState.snapshot.visibleItems.first
    #expect(snapshot?.displaySelectionState == .included)
    #expect(snapshot?.directCopyStatus?.label == "Copied")
    #expect(snapshot?.sourceLogOwnership == nil)
}

@MainActor
@Test func sourceInboxMarksArchiveDiskCopiesOutsidePhotoLogs() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let archiveWalk = archiveRoot
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05 - May", isDirectory: true)
        .appendingPathComponent("23-Saturday-Test-walk", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.jpg"), contents: "already copied")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0002.jpg"), contents: "still source only")
    let archiveCopy = archiveWalk.appendingPathComponent("23-Saturday-Test-walk-001.jpg")
    try writeTestFile(archiveCopy, contents: "already copied")

    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 23
    components.hour = 9
    components.minute = 30
    components.timeZone = TimeZone(secondsFromGMT: 0)
    let capturedAt = Calendar(identifier: .gregorian).date(from: components)!
    let manifest = """
    ---
    media_item_id: \(UUID().uuidString)
    archive_path: \(archiveCopy.path)
    source_file_name: IMG_0001.jpg
    captured_at: \(DateFormatting.iso8601.string(from: capturedAt))
    walk_title: "Test walk"
    walk_location: ""
    ---

    Test manifest.
    """
    try AppDirectories.ensureExists(archiveWalk)
    try manifest.write(
        to: archiveCopy.deletingPathExtension().appendingPathExtension("md"),
        atomically: true,
        encoding: .utf8
    )

    let copiedItem = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0001.jpg",
        capturedAt: capturedAt
    )
    let sourceOnlyItem = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0002.jpg",
        capturedAt: capturedAt.addingTimeInterval(1)
    )
    var settings = state.settings
    settings.archiveRoot = archiveRoot
    state.settings = settings
    state.testingSourceScanHandler = { _, _ in
        SessionOpenResult(
            session: makeTestSession(
                sourceRoot: sourceRoot,
                archiveRoot: archiveRoot,
                items: [copiedItem, sourceOnlyItem],
                workspaceSourceFolder: sourceRoot,
                sessionKind: .inbox
            ),
            bursts: [],
            clusters: []
        )
    }

    await state.openSession(for: sourceRoot)

    let copiedSnapshot = state.reviewState.snapshot.visibleItems.first { $0.item.relativePath == "IMG_0001.jpg" }
    let sourceOnlySnapshot = state.reviewState.snapshot.visibleItems.first { $0.item.relativePath == "IMG_0002.jpg" }
    #expect(copiedSnapshot?.sourceArchiveCopy?.archivePath == archiveCopy.path)
    #expect(copiedSnapshot?.sourceLogOwnership == nil)
    #expect(copiedSnapshot?.item.lifecycleState == .verified)
    #expect(copiedSnapshot?.item.destinationURL?.path == archiveCopy.path)
    #expect(copiedSnapshot?.item.selectionState == .undecided)
    #expect(copiedSnapshot?.displayStatusLabel == "Copied")
    #expect(copiedSnapshot?.isTriageActionLocked == true)
    #expect(sourceOnlySnapshot?.sourceArchiveCopy == nil)
    #expect(sourceOnlySnapshot?.isTriageActionLocked == false)
}

@MainActor
@Test func sourceInboxKeepsOnDiskCopiesOutOfNewPhotoLogDecisions() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let archiveWalk = archiveRoot
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05 - May", isDirectory: true)
        .appendingPathComponent("23-Saturday-Test-walk", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.jpg"), contents: "already copied")
    let archiveCopy = archiveWalk.appendingPathComponent("23-Saturday-Test-walk-001.jpg")
    try writeTestFile(archiveCopy, contents: "already copied")

    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 23
    components.hour = 9
    components.minute = 30
    components.timeZone = TimeZone(secondsFromGMT: 0)
    let capturedAt = Calendar(identifier: .gregorian).date(from: components)!
    let manifest = """
    ---
    media_item_id: \(UUID().uuidString)
    archive_path: \(archiveCopy.path)
    source_file_name: IMG_0001.jpg
    captured_at: \(DateFormatting.iso8601.string(from: capturedAt))
    walk_title: "Test walk"
    walk_location: ""
    ---

    Test manifest.
    """
    try AppDirectories.ensureExists(archiveWalk)
    try manifest.write(
        to: archiveCopy.deletingPathExtension().appendingPathExtension("md"),
        atomically: true,
        encoding: .utf8
    )

    let copiedItem = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0001.jpg",
        capturedAt: capturedAt,
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    var settings = state.settings
    settings.archiveRoot = archiveRoot
    state.settings = settings
    state.testingSourceScanHandler = { _, _ in
        SessionOpenResult(
            session: makeTestSession(
                sourceRoot: sourceRoot,
                archiveRoot: archiveRoot,
                items: [copiedItem],
                workspaceSourceFolder: sourceRoot,
                sessionKind: .inbox
            ),
            bursts: [],
            clusters: []
        )
    }

    await state.openSession(for: sourceRoot)

    let copied = try #require(state.currentSession?.mediaItems.first)
    #expect(copied.lifecycleState == .verified)
    #expect(copied.selectionState == .undecided)
    #expect(!state.canCommitImport)
    #expect(!state.canPresentPhotoLogCreation)

    state.selectMediaItems([copied.id])
    state.markCurrentSelectionForImport()

    let afterMark = try #require(state.currentSession?.mediaItems.first)
    #expect(afterMark.lifecycleState == .verified)
    #expect(afterMark.selectionState == .undecided)
    #expect(state.statusMessage.contains("already copied"))
}

@MainActor
@Test func copyReadinessReportsDestinationAndImportedState() throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.jpg"), contents: "jpg")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.cr3"), contents: "raw")
    let companion = makeTestCompanionFile(sourceRoot: sourceRoot, fileName: "IMG_0001.cr3")
    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0001.jpg",
        capturedAt: Date(timeIntervalSince1970: 70_000),
        selectionState: .included,
        importRawCompanions: true,
        companionFiles: [companion],
        lifecycleState: .selectedForImport
    )

    state.currentSession = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item], title: "Copy Confidence")
    state.setWorkspaceMode(.cameraTriage)

    let ready = try #require(state.sidebarState.snapshot.importReadiness)
    #expect(ready.includedItems == 1)
    #expect(ready.rawCompanionFiles == 1)
    #expect(ready.totalFiles == 2)
    #expect(ready.destinationPath?.contains("Copy-confidence") == true)
    #expect(ready.archiveDestinationLabel == "Planned archive folder")
    #expect(state.canCommitImport)
    #expect(!state.canOpenArchiveDestination)
    #expect(!state.canConfirmBackup)

    try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
    var verifiedItem = item
    verifiedItem.lifecycleState = .verified
    verifiedItem.destinationURL = archiveRoot.appendingPathComponent("IMG_0001.jpg")
    state.currentSession = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [verifiedItem], title: "Copy Confidence")
    state.setWorkspaceMode(.cameraTriage)

    let verified = try #require(state.sidebarState.snapshot.importReadiness)
    #expect(verified.totalFiles == 0)
    #expect(verified.destinationPath == archiveRoot.path)
    #expect(verified.archiveDestinationLabel == "Copied archive folder")
    #expect(verified.verifiedAwaitingBackupItems == 1)
    #expect(!state.canCommitImport)
    #expect(state.canOpenArchiveDestination)
    #expect(state.canConfirmBackup)
}

@MainActor
@Test func copyFromSourceInboxCreatesAutomaticDatedPhotoLog() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.jpg"), contents: "keeper")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0002.jpg"), contents: "excluded")
    let capturedAt = Date(timeIntervalSince1970: 1_779_532_200)
    let items = [
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "IMG_0001.jpg",
            capturedAt: capturedAt,
            selectionState: .included,
            lifecycleState: .selectedForImport
        ),
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "IMG_0002.jpg",
            capturedAt: capturedAt.addingTimeInterval(60),
            selectionState: .excluded
        )
    ]
    state.currentSession = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: items,
        title: "",
        location: "",
        notes: "",
        workspaceSourceFolder: sourceRoot,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.commitImport()
    #expect(state.presentationState.snapshot.activeWalkCommitEditor != nil)
    state.confirmWalkCommit()
    for _ in 0..<60 {
        if state.currentSession?.status == "imported" || state.importOperation.phase == .failed {
            break
        }
        try await Task.sleep(for: .milliseconds(50))
    }

    #expect(state.currentSession?.sessionKind == .walkDraft)
    #expect(state.currentSession?.walkMetadata.title == "2026-05-23 Saturday")
    #expect(state.currentSession?.status == "imported")
    #expect(state.currentSession?.mediaItems.count == 2)
    #expect(state.currentSession?.mediaItems.first { $0.fileName == "IMG_0001.jpg" }?.lifecycleState == .verified)
    #expect(state.currentSession?.mediaItems.first { $0.fileName == "IMG_0002.jpg" }?.selectionState == .excluded)
    #expect(state.importOperation.phase == .completed)
    #expect(state.importOperation.detail.contains("Copied and verified 1 photo"))
}

@MainActor
@Test func cancelWalkCommitEditorThenMarkMoreRecomputesWalkProposals() throws {
    let capturedAt = Date(timeIntervalSince1970: 1_779_532_200)
    let items = [
        makeTestMediaItem(sourceRoot: URL(fileURLWithPath: "/tmp/review-state"), fileName: "IMG_0001.jpg", capturedAt: capturedAt, selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: URL(fileURLWithPath: "/tmp/review-state"), fileName: "IMG_0002.jpg", capturedAt: capturedAt.addingTimeInterval(60))
    ]
    let state = makeReviewAppState(items: items)

    state.commitImport()
    let firstEditor = try #require(state.presentationState.snapshot.activeWalkCommitEditor)
    #expect(Set(firstEditor.walks.flatMap(\.mediaItemIDs)) == [items[0].id])

    state.dismissWalkCommitEditor()
    #expect(state.currentSession?.proposedWalks.isEmpty == true)

    state.selectMediaItems([items[1].id])
    state.markCurrentSelectionForImport()
    state.commitImport()

    let secondEditor = try #require(state.presentationState.snapshot.activeWalkCommitEditor)
    #expect(Set(secondEditor.walks.flatMap(\.mediaItemIDs)) == Set(items.map(\.id)))
}

@MainActor
@Test func sourceInboxCanAddMarkedPhotosToExistingCopiedLog() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    for fileName in ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.jpg"] {
        try writeTestFile(sourceRoot.appendingPathComponent(fileName), contents: fileName)
    }
    let capturedAt = Date(timeIntervalSince1970: 1_779_532_200)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001.jpg", capturedAt: capturedAt, selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0002.jpg", capturedAt: capturedAt.addingTimeInterval(60)),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0003.jpg", capturedAt: capturedAt.addingTimeInterval(120))
    ]
    state.currentSession = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: items,
        title: "",
        location: "",
        notes: "",
        workspaceSourceFolder: sourceRoot,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.commitImport()
    #expect(state.presentationState.snapshot.activeWalkCommitEditor != nil)
    state.confirmWalkCommit()
    for _ in 0..<60 {
        if state.currentSession?.status == "imported" || state.importOperation.phase == .failed {
            break
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    let copiedLogID = try #require(state.currentSession?.id)

    #expect(state.canStartNewPhotoLogFromCurrentLog)
    state.startNewPhotoLogFromCurrentLog()
    #expect(state.currentSession?.sessionKind == .inbox)
    #expect(state.currentSession?.workspaceSourceFolder.standardizedFileURL == sourceRoot.standardizedFileURL)
    #expect(state.currentSession?.mediaItems.map(\.relativePath).sorted() == ["IMG_0002.jpg", "IMG_0003.jpg"])
    #expect(state.importOperation.phase == .idle)
    #expect(state.statusMessage.contains("Opened the source inbox"))

    let second = try #require(state.currentSession?.mediaItems.first { $0.relativePath == "IMG_0002.jpg" })
    let third = try #require(state.currentSession?.mediaItems.first { $0.relativePath == "IMG_0003.jpg" })
    state.selectMediaItems([second.id])
    state.markCurrentSelectionForImport()
    state.selectMediaItems([third.id])
    state.excludeCurrentSelectionFromImport()

    #expect(state.canAddCurrentSourceDecisions(to: copiedLogID))
    state.addCurrentSourceDecisions(to: copiedLogID)

    #expect(state.currentSession?.id == copiedLogID)
    #expect(state.currentSession?.status == "imported")
    #expect(state.currentSession?.mediaItems.map(\.relativePath).sorted() == ["IMG_0001.jpg", "IMG_0002.jpg", "IMG_0003.jpg"])
    #expect(state.currentSession?.mediaItems.first { $0.relativePath == "IMG_0001.jpg" }?.lifecycleState == .verified)
    #expect(state.currentSession?.mediaItems.first { $0.relativePath == "IMG_0002.jpg" }?.lifecycleState == .selectedForImport)
    #expect(state.currentSession?.mediaItems.first { $0.relativePath == "IMG_0003.jpg" }?.selectionState == .excluded)
    #expect(state.canCommitImport)
}

@MainActor
@Test func activePhotoLogControlsSaveRenameAndReturnToSourceInboxFromPhotoLogsMode() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let base = Date(timeIntervalSince1970: 1_779_533_000)
    let fileNames = ["IMG_0101.jpg", "IMG_0102.jpg", "IMG_0103.jpg"]
    for fileName in fileNames {
        try writeTestFile(root.appendingPathComponent(fileName), contents: fileName)
    }
    let items = fileNames.enumerated().map { index, fileName in
        makeTestMediaItem(
            sourceRoot: root,
            fileName: fileName,
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: index == 0 ? .included : .undecided
        )
    }

    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: items,
        title: "Original Log",
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.presentPhotoLogCreation()
    state.createPhotoLog(openAfterCreate: true)
    let draftID = try #require(state.currentSession?.id)
    #expect(state.currentSession?.sessionKind == .walkDraft)

    state.setWorkspaceMode(.photoLogs)
    #expect(state.canStartNewPhotoLogSession)

    state.saveCurrentLogDetailsAndStartNext(
        title: "Renamed Log",
        location: "Woodstock",
        notes: "Ready for the next selection"
    )

    #expect(state.workspaceMode == .cameraTriage)
    #expect(state.currentSession?.sessionKind == .inbox)
    #expect(state.currentSession?.mediaItems.map(\.relativePath).sorted() == ["IMG_0102.jpg", "IMG_0103.jpg"])
    #expect(state.canMutateImportSelection)
    #expect(state.statusMessage.contains("Opened the source inbox"))

    state.openSavedWalk(draftID)
    #expect(state.currentSession?.walkMetadata.title == "Renamed Log")
    #expect(state.currentSession?.walkMetadata.location == "Woodstock")
    #expect(state.currentSession?.walkMetadata.notes == "Ready for the next selection")
}

@MainActor
@Test func sourceInboxStartNewPhotoLogSessionPresentsCreationEditor() throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let fileNames = ["IMG_0201.jpg", "IMG_0202.jpg"]
    for fileName in fileNames {
        try writeTestFile(root.appendingPathComponent(fileName), contents: fileName)
    }
    let items = fileNames.enumerated().map { index, fileName in
        makeTestMediaItem(
            sourceRoot: root,
            fileName: fileName,
            capturedAt: Date(timeIntervalSince1970: 1_779_534_000 + Double(index)),
            selectionState: index == 0 ? .included : .undecided
        )
    }

    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: items,
        title: "Inbox Log",
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    #expect(state.canStartNewPhotoLogSession)
    state.startNewPhotoLogSession()

    let editor = try #require(state.activePhotoLogEditor)
    if case .create = editor.mode {
        #expect(editor.title == "Inbox Log")
    } else {
        Issue.record("Expected photo log creation editor.")
    }
}

@MainActor
@Test func filterChangeReconcilesSelectionWhenHiddenItemsDropOut() {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-filter-reconcile", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "included.jpg", capturedAt: base, selectionState: .included),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "excluded.jpg", capturedAt: base.addingTimeInterval(1), selectionState: .excluded)
    ]
    let state = makeReviewAppState(items: items)
    state.selectMediaItems([items[1].id])

    state.setReviewFilter(.included)

    #expect(state.selectedMediaItemIDs.isEmpty)
    #expect(state.focusedReviewItemID == items[0].id)
}

@MainActor
@Test func staleSourceLoadDoesNotOverrideSavedWalkResume() async throws {
    let state = AppState(testing: true)
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let base = Date(timeIntervalSince1970: 40_000)
    let fileNames = ["0.jpg", "1.jpg", "2.jpg"]
    for fileName in fileNames {
        try writeTestFile(root.appendingPathComponent(fileName), contents: fileName)
    }

    let items = fileNames.enumerated().map { index, fileName in
        makeTestMediaItem(
            sourceRoot: root,
            fileName: fileName,
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: index < 2 ? .included : .undecided
        )
    }

    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: items,
        title: "Delayed Scan Walk",
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.activePane = .media

    state.presentPhotoLogCreation()
    state.createPhotoLog(openAfterCreate: true)
    let draftID = try #require(state.currentSession?.id)

    let blockedResult = SessionOpenResult(
        session: makeTestSession(
            sourceRoot: root,
            archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
            items: items,
            workspaceSourceFolder: root,
            sessionKind: .inbox
        ),
        bursts: [],
        clusters: []
    )

    let gate = SourceScanGate()
    state.testingSourceScanHandler = { _, _ in
        await gate.markStarted()
        await gate.waitUntilReleased()
        return blockedResult
    }

    state.loadSourceWorkspace(folder: root, origin: .savedWalkInbox)
    await gate.waitUntilStarted()

    state.openSavedWalk(draftID)
    await gate.release()
    try await Task.sleep(for: .milliseconds(50))

    #expect(state.currentSession?.id == draftID)
    #expect(state.currentSession?.sessionKind == .walkDraft)
    #expect(state.currentSession?.walkMetadata.title == "Delayed Scan Walk")
}

private actor SourceScanGate {
    private var started = false
    private var released = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func markStarted() {
        started = true
        startedContinuation?.resume()
        startedContinuation = nil
    }

    func waitUntilStarted() async {
        guard started == false else { return }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func release() {
        released = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func waitUntilReleased() async {
        guard released == false else { return }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }
}

@MainActor
@Test func singleGridSelectionPublishesReviewStateOnce() {
    // Regression guard for the refresh-coalescing optimization (PDT-2026-05-29-088).
    // A single click sets both focus and selection; before coalescing this produced two
    // distinct review-state publishes (an intermediate focus-only snapshot, then the
    // focus+selection snapshot). After coalescing it must produce exactly one.
    let items = makeSelectionItems(count: 6)
    let state = makeReviewAppState(items: items)
    state.activateReviewGridFocus()

    let before = state.reviewState.generation
    state.handleGridSelection(
        for: items[3].id,
        click: ReviewGridClickContext(modifiers: [], clickCount: 1)
    )
    let after = state.reviewState.generation

    #expect(after - before == 1)
    #expect(state.selectedMediaItemIDs == [items[3].id])
    #expect(state.focusedReviewItemID == items[3].id)
    #expect(state.reviewState.snapshot.selectedMediaItemIDs == [items[3].id])
    #expect(state.reviewState.snapshot.focusedReviewItemID == items[3].id)
    #expect(state.reviewState.snapshot.visibleItems.first { $0.id == items[3].id }?.isSelected == true)
}

@MainActor
@Test func selectMediaItemsPublishesReviewStateOnce() {
    // selectMediaItems routes through applyReviewSelectionState; verify a programmatic
    // selection of a single item yields exactly one review-state publish.
    let items = makeSelectionItems(count: 5)
    let state = makeReviewAppState(items: items)
    state.activateReviewGridFocus()

    let before = state.reviewState.generation
    state.selectMediaItems([items[1].id])
    let after = state.reviewState.generation

    #expect(after - before == 1)
    #expect(state.selectedMediaItemIDs == [items[1].id])
}

@Test func reviewItemSnapshotIndexEqualityIsDerivedAndLookupWorks() {
    // The index is derived purely from `visibleItems`, so its `==` is a no-op `true`
    // (equality of the owning snapshot is decided by `visibleItems`). The subscript must
    // still resolve ids for grouped-review lookups.
    let item = MediaItem(
        sourceURL: URL(fileURLWithPath: "/tmp/idx.jpg"),
        relativePath: "idx.jpg",
        fileName: "idx.jpg",
        baseName: "idx",
        mediaKind: .jpeg,
        fileSizeBytes: 1,
        capturedAt: nil,
        metadata: MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:]),
        thumbnailCacheKey: "idx"
    )
    let snapshot = ReviewItemSnapshot(
        item: item,
        archivePreview: "",
        sourceLogOwnership: nil,
        sourceArchiveCopy: nil,
        isSelected: false,
        isFocused: false,
        thumbnailFailed: false
    )
    let populated = ReviewItemSnapshotIndex([item.id: snapshot])
    let empty = ReviewItemSnapshotIndex([:])

    #expect(populated[item.id]?.id == item.id)
    #expect(empty[item.id] == nil)
    #expect(populated == empty)
}

@MainActor
private func makeReviewAppState(items: [MediaItem]) -> AppState {
    let state = AppState(testing: true)
    let root = URL(fileURLWithPath: "/tmp/review-state", isDirectory: true)
    state.currentSession = makeTestSession(sourceRoot: root, archiveRoot: root.appendingPathComponent("archive", isDirectory: true), items: items)
    state.burstGroups = []
    state.timeClusters = []
    state.setWorkspaceMode(.cameraTriage)
    state.archiveMediaCache = [:]
    var settings = state.settings
    settings.reviewGridColumnCount = ReviewGridMetrics.defaultRequestedColumnCount()
    settings.reviewPresentationMode = .grid
    state.settings = settings
    state.updateReviewGridMetrics(availableWidth: 1_100, availableHeight: 900)

    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == items.count })?.id {
        state.selectedSidebarNodeID = leafID
    }

    #expect(state.visibleMediaItems.count == items.count)
    return state
}

private func makeSelectionItems(count: Int) -> [MediaItem] {
    let sourceRoot = URL(fileURLWithPath: "/tmp/review-selection-fixtures", isDirectory: true)
    let base = Date(timeIntervalSince1970: 20_000)
    return (0..<count).map { index in
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "\(index).jpg",
            capturedAt: base.addingTimeInterval(Double(index))
        )
    }
}
