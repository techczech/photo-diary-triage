import Foundation
import Testing
@testable import PhotoDiaryTriage

@MainActor
@Test func mediaLoadingBenchmarkReportsArchiveTimings() async throws {
    guard ProcessInfo.processInfo.environment["PDT_RUN_MEDIA_BENCHMARK"] == "1" else {
        return
    }

    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let itemCount = Int(ProcessInfo.processInfo.environment["PDT_MEDIA_BENCHMARK_ITEM_COUNT"] ?? "") ?? 24
    let visibleCount = min(12, itemCount)
    let walk = root
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05 - May", isDirectory: true)
        .appendingPathComponent("Measured Walk", isDirectory: true)
    try AppDirectories.ensureExists(walk)

    for index in 0..<itemCount {
        let imageURL = walk.appendingPathComponent(String(format: "Measured-Walk-%03d.jpg", index + 1))
        try writeTestJPEGImage(imageURL, width: 320, height: 240)
    }

    var settings = makeTestSettings(root: root)
    settings.cacheRoot = root.appendingPathComponent("cache", isDirectory: true)
    let node = BrowserNode(
        id: "archive-walk-\(walk.path)",
        title: "Measured Walk",
        subtitle: walk.path,
        kind: .archiveWalkFolder,
        parentID: nil,
        mediaItemIDs: [],
        children: nil,
        folderURL: walk
    )

    let scanStarted = Date()
    let maybeLoadResult = try BrowserViewModel(scanner: FileScanner()).loadArchiveMedia(for: node, settings: settings)
    let loadResult = try #require(maybeLoadResult)
    let scanMs = elapsedMilliseconds(since: scanStarted)
    let visibleItems = Array(loadResult.items.prefix(visibleCount))

    let state = AppState(testing: true)
    state.settings = settings
    state.replacePreviewStoreForTesting(BenchmarkPreviewStore(cacheRoot: settings.cacheRoot))
    state.archiveMediaCache[node.id] = loadResult.items

    let requestStarted = Date()
    for item in visibleItems {
        state.requestThumbnail(for: item)
        _ = state.thumbnailImage(for: item)
    }

    let firstCacheMs = await waitForMilliseconds(timeout: 2, started: requestStarted) {
        visibleItems.contains { FileManager.default.fileExists(atPath: state.thumbnailURL(for: $0).path) }
    }
    let allCacheMs = await waitForMilliseconds(timeout: 2, started: requestStarted) {
        visibleItems.allSatisfy { FileManager.default.fileExists(atPath: state.thumbnailURL(for: $0).path) }
    }
    let firstSlotMs = await waitForMilliseconds(timeout: 2, started: requestStarted) {
        visibleItems.contains { state.thumbnailSlot(for: $0).image != nil }
    }
    let allSlotMs = await waitForMilliseconds(timeout: 2, started: requestStarted) {
        visibleItems.allSatisfy { state.thumbnailSlot(for: $0).image != nil }
    }

    print("""
    PDT_MEDIA_BENCHMARK {"item_count":\(itemCount),"visible_count":\(visibleCount),"archive_scan_ms":\(scanMs),"first_cache_file_ms":\(jsonValue(firstCacheMs)),"all_cache_files_ms":\(jsonValue(allCacheMs)),"first_visible_slot_ms":\(jsonValue(firstSlotMs)),"all_visible_slots_ms":\(jsonValue(allSlotMs)),"slot_timeout_ms":2000}
    """)
}

@MainActor
@Test func archiveThumbnailGenerationUpdatesArchiveSlot() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let walk = root.appendingPathComponent("walk", isDirectory: true)
    try AppDirectories.ensureExists(walk)
    let imageURL = walk.appendingPathComponent("IMG_0001.jpg")
    try writeTestJPEGImage(imageURL, width: 320, height: 240)

    var settings = makeTestSettings(root: root)
    settings.cacheRoot = root.appendingPathComponent("cache", isDirectory: true)
    let item = makeTestMediaItem(
        sourceRoot: walk,
        fileName: "IMG_0001.jpg",
        capturedAt: Date(timeIntervalSince1970: 1_779_800_000),
        lifecycleState: .imported
    )
    let state = AppState(testing: true)
    state.settings = settings
    state.replacePreviewStoreForTesting(BenchmarkPreviewStore(cacheRoot: settings.cacheRoot))
    state.archiveMediaCache["archive-walk"] = [item]

    let started = Date()
    state.requestThumbnail(for: item)
    _ = state.thumbnailImage(for: item)

    let slotMs = await waitForMilliseconds(timeout: 1, started: started) {
        state.thumbnailSlot(for: item).image != nil
    }

    #expect(slotMs != nil)
}

@MainActor
@Test func onlineOnlyThumbnailRequestShowsCloudStateWithoutRetryFailure() {
    let root = URL(fileURLWithPath: "/tmp/online-only-thumbnail", isDirectory: true)
    var item = makeTestMediaItem(
        sourceRoot: root,
        fileName: "IMG_CLOUD.jpg",
        capturedAt: Date(timeIntervalSince1970: 1_779_900_000)
    )
    item.fileLocality = .onlineOnly

    let state = AppState(testing: true)
    state.requestThumbnail(for: item)
    _ = state.thumbnailImage(for: item)

    #expect(state.isThumbnailCloudOnly(for: item))
    #expect(!state.thumbnailFailures.contains(item.id))
    #expect(state.thumbnailLoadingState.snapshot.skippedCount == 1)
}

@Test func fileLocalityDetectorTreatsDatalessUbiquitousFilesAsOnlineOnly() {
    let locality = FileLocalityDetector.locality(
        isRegularFile: true,
        fileSize: 4_000_000,
        fileAllocatedSize: 0,
        totalFileAllocatedSize: 0,
        isUbiquitousItem: true,
        downloadingStatus: .notDownloaded
    )

    #expect(locality == .onlineOnly)
}

private final class BenchmarkPreviewStore: PreviewCaching {
    let cacheRoot: URL

    init(cacheRoot: URL) {
        self.cacheRoot = cacheRoot
    }

    var isPersistentCacheAvailable: Bool { true }

    func cachedThumbnailURL(for item: MediaItem) -> URL {
        cacheRoot.appendingPathComponent("\(item.thumbnailCacheKey).png")
    }

    func generateThumbnail(for item: MediaItem) async -> Bool {
        do {
            try AppDirectories.ensureExists(cacheRoot)
            try writeTestJPEGImage(cachedThumbnailURL(for: item), width: 80, height: 60)
            return true
        } catch {
            return false
        }
    }
}

private func elapsedMilliseconds(since started: Date) -> Int {
    Int(Date().timeIntervalSince(started) * 1000)
}

@MainActor
private func waitForMilliseconds(
    timeout: TimeInterval,
    started: Date,
    condition: @escaping @MainActor () -> Bool
) async -> Int? {
    while Date().timeIntervalSince(started) < timeout {
        if condition() {
            return elapsedMilliseconds(since: started)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
    return condition() ? elapsedMilliseconds(since: started) : nil
}

private func jsonValue(_ value: Int?) -> String {
    value.map(String.init) ?? "null"
}
