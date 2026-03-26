import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func slugifierCollapsesPunctuation() {
    #expect(Slugifier.makeSlug(from: "Bristol Harbour Walk!") == "bristol-harbour-walk")
}

@Test func selectionStateDecodesLegacyAndCurrentValues() throws {
    let decoder = JSONDecoder()

    let legacySelected = try decoder.decode(SelectionState.self, from: Data(#""selected""#.utf8))
    let legacySkipped = try decoder.decode(SelectionState.self, from: Data(#""skipped""#.utf8))
    let currentExcluded = try decoder.decode(SelectionState.self, from: Data(#""excluded""#.utf8))

    #expect(legacySelected == .included)
    #expect(legacySkipped == .undecided)
    #expect(currentExcluded == .excluded)
}

@Test func archivePlannerBuildsDateBasedFolderAndHandlesCollisions() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true, attributes: nil)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let capturedAt = ISO8601DateFormatter().date(from: "2026-03-21T08:15:00Z")!
    let metadata = MediaMetadata(capturedAt: capturedAt, pixelWidth: 100, pixelHeight: 100, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:])

    var session = ImportSession(sourceFolder: tempRoot, archiveRoot: tempRoot)
    session.walkMetadata.title = "Morning Canal Walk"
    session.mediaItems = [
        MediaItem(sourceURL: tempRoot.appendingPathComponent("a.jpg"), relativePath: "a.jpg", fileName: "a.jpg", baseName: "a", mediaKind: .jpeg, fileSizeBytes: 10, capturedAt: capturedAt, metadata: metadata, thumbnailCacheKey: "1", selectionState: .included, lifecycleState: .selectedForImport),
        MediaItem(sourceURL: tempRoot.appendingPathComponent("a-duplicate.jpg"), relativePath: "a-duplicate.jpg", fileName: "a.jpg", baseName: "a", mediaKind: .jpeg, fileSizeBytes: 10, capturedAt: capturedAt, metadata: metadata, thumbnailCacheKey: "2", selectionState: .included, lifecycleState: .selectedForImport)
    ]

    let plan = ArchivePlanner(fileManager: .default).plan(for: session)

    #expect(plan.selectedCount == 2)
    #expect(plan.archiveFolder.path.contains("2026/03/2026-03-21"))
    #expect(Set(plan.entries.map(\.destinationURL.lastPathComponent)).count == 2)
}

@Test func archivePlannerIncludesRawCompanionOnlyWhenEnabled() {
    let root = URL(fileURLWithPath: "/tmp/archive-test")
    let capturedAt = Date(timeIntervalSince1970: 1000)
    let metadata = MediaMetadata(capturedAt: capturedAt, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:])

    var session = ImportSession(sourceFolder: root, archiveRoot: root)
    session.walkMetadata.title = "Sidecar Test"
    session.mediaItems = [
        MediaItem(
            sourceURL: root.appendingPathComponent("IMG_0001.jpg"),
            relativePath: "IMG_0001.jpg",
            fileName: "IMG_0001.jpg",
            baseName: "IMG_0001",
            mediaKind: .jpeg,
            fileSizeBytes: 10,
            capturedAt: capturedAt,
            metadata: metadata,
            thumbnailCacheKey: "a",
            selectionState: .included,
            importRawCompanions: true,
            companionFiles: [
                CompanionFile(
                    sourceURL: root.appendingPathComponent("IMG_0001.cr2"),
                    relativePath: "IMG_0001.cr2",
                    fileName: "IMG_0001.cr2",
                    fileSizeBytes: 20,
                    kind: .raw
                )
            ],
            lifecycleState: .selectedForImport
        )
    ]

    let plan = ArchivePlanner(fileManager: .default).plan(for: session)
    #expect(plan.entries.count == 2)
    #expect(plan.entries.contains(where: { $0.isCompanion }))
}

@Test func groupingSeparatesBurstAndTimeClusters() {
    let base = Date(timeIntervalSince1970: 1000)
    let metadata = MediaMetadata(capturedAt: base, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:])
    let settings = AppSettings(
        defaultSourceRoot: URL(fileURLWithPath: "/Volumes/EOS_DIGITAL"),
        archiveRoot: URL(fileURLWithPath: "/tmp/archive"),
        cacheRoot: URL(fileURLWithPath: "/tmp/cache"),
        supportedExtensions: ["jpg"],
        burstThresholdSeconds: 2,
        proximityThresholdSeconds: 600,
        cleanupRequiresBackupConfirmation: true,
        reviewPresentationMode: .grid,
        reviewGridCardWidth: ReviewGridMetrics.defaultCardWidth
    )

    let items = [
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/1.jpg"), relativePath: "1.jpg", fileName: "1.jpg", baseName: "1", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base, metadata: metadata, thumbnailCacheKey: "1"),
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/2.jpg"), relativePath: "2.jpg", fileName: "2.jpg", baseName: "2", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base.addingTimeInterval(1), metadata: metadata, thumbnailCacheKey: "2"),
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/3.jpg"), relativePath: "3.jpg", fileName: "3.jpg", baseName: "3", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base.addingTimeInterval(300), metadata: metadata, thumbnailCacheKey: "3"),
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/4.jpg"), relativePath: "4.jpg", fileName: "4.jpg", baseName: "4", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base.addingTimeInterval(1200), metadata: metadata, thumbnailCacheKey: "4")
    ]

    let result = GroupingService().group(items: items, settings: settings)

    #expect(result.burstGroups.count == 1)
    #expect(result.timeClusters.count == 1)
    #expect(result.items.filter { $0.timeClusterID != nil }.count == 3)
}

@Test func groupingThresholdsChangeBurstAndClusterOutput() {
    let base = Date(timeIntervalSince1970: 1_000)
    let metadata = MediaMetadata(capturedAt: base, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:])
    let items = [
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/a.jpg"), relativePath: "a.jpg", fileName: "a.jpg", baseName: "a", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base, metadata: metadata, thumbnailCacheKey: "a"),
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/b.jpg"), relativePath: "b.jpg", fileName: "b.jpg", baseName: "b", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base.addingTimeInterval(3), metadata: metadata, thumbnailCacheKey: "b"),
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/c.jpg"), relativePath: "c.jpg", fileName: "c.jpg", baseName: "c", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base.addingTimeInterval(500), metadata: metadata, thumbnailCacheKey: "c")
    ]

    let tightSettings = AppSettings(
        defaultSourceRoot: URL(fileURLWithPath: "/Volumes/EOS_DIGITAL"),
        archiveRoot: URL(fileURLWithPath: "/tmp/archive"),
        cacheRoot: URL(fileURLWithPath: "/tmp/cache"),
        supportedExtensions: ["jpg"],
        burstThresholdSeconds: 2,
        proximityThresholdSeconds: 300,
        cleanupRequiresBackupConfirmation: true,
        reviewPresentationMode: .grid,
        reviewGridCardWidth: ReviewGridMetrics.defaultCardWidth
    )

    let looseSettings = AppSettings(
        defaultSourceRoot: tightSettings.defaultSourceRoot,
        archiveRoot: tightSettings.archiveRoot,
        cacheRoot: tightSettings.cacheRoot,
        supportedExtensions: tightSettings.supportedExtensions,
        burstThresholdSeconds: 5,
        proximityThresholdSeconds: 600,
        cleanupRequiresBackupConfirmation: true,
        reviewPresentationMode: .grid,
        reviewGridCardWidth: ReviewGridMetrics.defaultCardWidth
    )

    let tightResult = GroupingService().group(items: items, settings: tightSettings)
    let looseResult = GroupingService().group(items: items, settings: looseSettings)

    #expect(tightResult.burstGroups.isEmpty)
    #expect(looseResult.burstGroups.count == 1)
    #expect(tightResult.timeClusters.count == 1)
    #expect(looseResult.timeClusters.count == 1)
    #expect(tightResult.timeClusters.first?.mediaItemIDs.count == 2)
    #expect(looseResult.timeClusters.first?.mediaItemIDs.count == 3)
}

@Test func regroupingClearsStaleGroupAssignments() {
    let base = Date(timeIntervalSince1970: 1_000)
    let metadata = MediaMetadata(capturedAt: base, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:])
    let items = [
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/1.jpg"), relativePath: "1.jpg", fileName: "1.jpg", baseName: "1", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base, metadata: metadata, thumbnailCacheKey: "1"),
        MediaItem(sourceURL: URL(fileURLWithPath: "/tmp/2.jpg"), relativePath: "2.jpg", fileName: "2.jpg", baseName: "2", mediaKind: .jpeg, fileSizeBytes: 1, capturedAt: base.addingTimeInterval(1), metadata: metadata, thumbnailCacheKey: "2")
    ]

    let groupedSettings = AppSettings(
        defaultSourceRoot: URL(fileURLWithPath: "/Volumes/EOS_DIGITAL"),
        archiveRoot: URL(fileURLWithPath: "/tmp/archive"),
        cacheRoot: URL(fileURLWithPath: "/tmp/cache"),
        supportedExtensions: ["jpg"],
        burstThresholdSeconds: 2,
        proximityThresholdSeconds: 2,
        cleanupRequiresBackupConfirmation: true,
        reviewPresentationMode: .grid,
        reviewGridCardWidth: ReviewGridMetrics.defaultCardWidth
    )

    let ungroupedSettings = AppSettings(
        defaultSourceRoot: groupedSettings.defaultSourceRoot,
        archiveRoot: groupedSettings.archiveRoot,
        cacheRoot: groupedSettings.cacheRoot,
        supportedExtensions: groupedSettings.supportedExtensions,
        burstThresholdSeconds: 0.5,
        proximityThresholdSeconds: 0.5,
        cleanupRequiresBackupConfirmation: true,
        reviewPresentationMode: .grid,
        reviewGridCardWidth: ReviewGridMetrics.defaultCardWidth
    )

    let grouped = GroupingService().group(items: items, settings: groupedSettings)
    let ungrouped = GroupingService().group(items: grouped.items, settings: ungroupedSettings)

    #expect(grouped.items.contains(where: { $0.burstGroupID != nil }))
    #expect(grouped.items.contains(where: { $0.timeClusterID != nil }))
    #expect(ungrouped.burstGroups.isEmpty)
    #expect(ungrouped.timeClusters.isEmpty)
    #expect(ungrouped.items.allSatisfy { $0.burstGroupID == nil && $0.timeClusterID == nil })
}

@Test func manifestRendererIncludesSourceReport() {
    let manifest = WalkManifest(
        sessionID: UUID(),
        walkDate: Date(timeIntervalSince1970: 0),
        sourceFolder: URL(fileURLWithPath: "/Volumes/SSD/Walk"),
        archiveFolder: URL(fileURLWithPath: "/Archive/2026/03/walk"),
        title: "Harbour",
        location: "Bristol",
        notes: "Foggy morning",
        summary: .init(totalSourceFiles: 20, visibleItems: 15, importedFiles: 5, skippedFiles: 15, cleanupPendingFiles: 5, cleanedSourceFiles: 0),
        importedFiles: []
    )

    let markdown = ManifestRenderer().renderWalkManifest(manifest)

    #expect(markdown.contains("Files left on source SSD: 15"))
    #expect(markdown.contains("Cleanup pending: 5"))
    #expect(markdown.contains("Visible review items: 15"))
}
