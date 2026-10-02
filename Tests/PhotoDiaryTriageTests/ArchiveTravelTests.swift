import Foundation
import Testing
@testable import PhotoDiaryTriage

private final class IndexOnlyFileManager: FileManager, @unchecked Sendable {
    var indexPath = ""
    var archiveEnumerationAttempts = 0
    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?,
                                      options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        guard url.path == indexPath || url.path.hasPrefix(indexPath + "/") else {
            archiveEnumerationAttempts += 1
            throw CocoaError(.fileReadNoPermission)
        }
        return try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }

}

@Test func travelCatalogueGridAndSearchUseOnlyPinnedIndex() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let main = root.appendingPathComponent("main")
    let source = root.appendingPathComponent("source")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        selectionState: .included, lifecycleState: .selectedForImport)
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: main, items: [item]))
    let historical = main.appendingPathComponent("2013/Prague/Tuesday")
    try writeTestFile(historical.appendingPathComponent("OLD_0001.jpg"), contents: "old keeper")
    try writeTestFile(historical.appendingPathComponent("OLD_0001.cr3"), contents: "old RAW")
    try writeTestFile(historical.appendingPathComponent("OLD_0002.jpg"), contents: "second keeper")
    let thumb = ArchiveIndexStore.thumbnailURL(for: try #require(imported.session.mediaItems[0].destinationURL), archiveRoot: main)
    try AppDirectories.ensureExists(thumb.deletingLastPathComponent())
    try writeTestJPEGImage(thumb)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: main)
    let travel = root.appendingPathComponent("travel")
    try FileManager.default.createDirectory(at: travel, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: main), to: ArchiveIndexStore.indexRoot(for: travel))
    let manager = IndexOnlyFileManager()
    manager.indexPath = ArchiveIndexStore.indexRoot(for: travel).path
    let builder = ArchiveCatalogueBuilder(fileManager: manager)
    let catalogue = try builder.build(archiveRoot: travel, supportedExtensions: ["jpg", "cr3"], machineRole: .travel)
    #expect(catalogue.entries.contains { $0.kind == .trip })
    let old = try #require(catalogue.entries.first { $0.kind == .unorganisedFolder })
    #expect(old.archiveRelativePath == "2013/Prague")
    #expect(old.photoCount == 2)
    #expect(catalogue.photos.count == 3)
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = travel
    settings.oneDrivePicturesRoot = travel
    settings.archiveMachineRole = .travel
    let folder = try #require(imported.walkManifest.archiveFolderRelativePath)
    let node = BrowserNode(id: "travel-walk", title: "Walk", subtitle: folder, kind: .archiveWalkFolder,
        parentID: nil, mediaItemIDs: [], children: nil, folderURL: travel.appendingPathComponent(folder))
    let loader = BrowserViewModel(scanner: FileScanner(fileManager: manager), fileManager: manager)
    let loaded = try #require(try loader.loadArchiveMedia(for: node, settings: settings))
    #expect(loaded.items.count == 1)
    #expect(loaded.items[0].id == imported.session.mediaItems[0].id)
    #expect(loaded.items[0].metadata.pixelWidth == 4000)
    #expect(!FileManager.default.fileExists(atPath: loaded.items[0].sourceURL.path))
    #expect(!ArchiveByteReadPolicy(archiveRoot: travel, machineRole: .travel).canReadBytes(at: loaded.items[0].sourceURL))
    let oldNode = BrowserNode(id: "travel-old", title: "Prague", subtitle: old.archiveRelativePath, kind: .archiveWalkFolder,
        parentID: nil, mediaItemIDs: [], children: nil, folderURL: travel.appendingPathComponent(old.archiveRelativePath))
    let oldLoaded = try #require(try loader.loadArchiveMedia(for: oldNode, settings: settings))
    #expect(oldLoaded.items.count == 2)
    #expect(oldLoaded.items.first { $0.fileName == "OLD_0001.jpg" }?.companionFiles.count == 1)
    #expect(manager.archiveEnumerationAttempts == 0)
    let database = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    try database.rebuild(indexEntries: builder.readIndexEntries(archiveRoot: travel), browseEntries: catalogue.entries)
    #expect(try database.matchingPaths(query: "OLD_0001").contains { $0.contains("OLD_0001.jpg") })
}

@Test func indexGridRejectsTraversalAndSymlinkEscapes() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
    let outside = root.appendingPathComponent("outside")
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: archive.appendingPathComponent("linked"), withDestinationURL: outside)
    for path in ["../outside/private.jpg", "/absolute.jpg", "a//b.jpg", "linked/private.jpg"] {
        #expect(throws: (any Error).self) { try ArchiveIndexMediaLoader().indexedURL(path, archiveRoot: archive) }
    }
}

@Test func travelPreviewUsesPreparedThumbnailAndDoesNotGenerateFromResidentOriginal() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(archive)
    try writeTestJPEGImage(archive.appendingPathComponent("local.jpg"))
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive
    settings.archiveMachineRole = .travel
    let context = ArchiveByteReadPolicyContext()
    context.update(settings: settings)
    let item = makeTestMediaItem(sourceRoot: archive, fileName: "local.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000))
    let store = try PreviewStore(cacheRoot: root.appendingPathComponent("cache"), policyContext: context)
    #expect(await store.generateThumbnail(for: item) == false)
    let thumb = ArchiveIndexStore.thumbnailURL(for: item.sourceURL, archiveRoot: archive)
    try AppDirectories.ensureExists(thumb.deletingLastPathComponent())
    try writeTestJPEGImage(thumb)
    #expect(store.cachedThumbnailURL(for: item) == thumb)
    #expect(await store.generateThumbnail(for: item))
    #expect(context.canPreheatOriginal(at: item.sourceURL) == false)
    #expect(context.canReadBytes(at: item.sourceURL) == false)
}

@Test func historicalGroupingPreservesDirectoryCase() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let upper = root.appendingPathComponent("2013/Prague/Day/IMG.jpg")
    try writeTestFile(upper, contents: "one keeper")
    let lower = root.appendingPathComponent("2013/Prague/day/IMG.jpg")
    // Case-insensitive test volumes cannot create both physical folders. The projection must
    // still preserve the supplied case-sensitive archive paths when building grouping keys.
    let discovery = (entries: [ArchiveBrowseEntry(id: "folder|2013/Prague", kind: .unorganisedFolder,
        year: "2013", archiveRelativePath: "2013/Prague", title: "Prague", startDate: nil,
        endDate: nil, location: nil, photoCount: 2, walkCount: 0, coverThumbnailPath: nil)],
        photos: ["2013/Prague": [upper, lower]])
    let rows = try ArchiveIndexStore().historicalEntries(discovery, archiveRoot: root)
    #expect(rows.filter { $0.kind == .photo }.count == 2)
}

@Test func travelCropFamiliesSurviveWithoutCropSidecarsOrOriginals() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let main = root.appendingPathComponent("main")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        selectionState: .included, lifecycleState: .selectedForImport)
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: main, items: [item]))
    var original = imported.session.mediaItems[0]
    original.sourceURL = try #require(original.destinationURL)
    let crop = try CropService().crop(item: original, normalizedRect: CropNormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), trigger: .manualDrag)
    try await ArchiveIndexMutationQueue.shared.replaceWalkFolders([original.sourceURL.deletingLastPathComponent()], archiveRoot: main,
        policy: ArchiveIndexWritePolicy(machineRole: .mainArchive))
    let travel = root.appendingPathComponent("travel")
    try AppDirectories.ensureExists(travel)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: main), to: ArchiveIndexStore.indexRoot(for: travel))
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = travel
    settings.archiveMachineRole = .travel
    let folder = try #require(imported.walkManifest.archiveFolderRelativePath)
    let loaded = try ArchiveIndexMediaLoader().load(folder: travel.appendingPathComponent(folder), settings: settings)
    #expect(loaded.count == 2)
    let projectedOriginal = try #require(loaded.first { $0.cropRelationship?.role == .original })
    let projectedCrop = try #require(loaded.first { $0.cropRelationship?.role == .crop })
    #expect(projectedOriginal.id == original.id)
    #expect(projectedOriginal.cropRelationship?.linkedPreviewRelativePath == crop.outputURL.lastPathComponent)
    #expect(projectedCrop.cropRelationship?.linkedPreviewRelativePath == original.sourceURL.lastPathComponent)
    #expect(projectedCrop.metadata.pixelWidth == crop.outputWidth)
    #expect(loaded.first?.cropRelationship?.role == .original)
}

@MainActor
@Test func archiveIdentityPreviewCropAndRefreshUseArchiveCopyWithoutChangingLoadedLog() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let main = root.appendingPathComponent("main")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        selectionState: .included, lifecycleState: .selectedForImport)
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: main, items: [item]))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: main)
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = main
    settings.oneDrivePicturesRoot = main
    settings.archiveMachineRole = .mainArchive
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    state.currentSession = imported.session
    let folder = try #require(imported.walkManifest.archiveFolderRelativePath)
    let entry = ArchiveBrowseEntry(id: "walk-fixture", kind: .unorganisedFolder, year: "2023", archiveRelativePath: folder,
        title: "Test Walk", startDate: nil, endDate: nil, location: nil, photoCount: 1, walkCount: 0, coverThumbnailPath: nil)
    state.testingInstallArchiveCatalogue(ArchiveCatalogue(entries: [entry], walksByTripPath: [:], photos: []))
    state.selectArchiveEntry(entry.id)
    state.openSelectedArchiveItem()
    #expect(await waitForTravelCondition { state.visibleMediaItems.count == 1 })
    var projected = try #require(state.visibleMediaItems.first)
    // Main scans still generate IDs; force the canonical ID to reproduce travel's stable identity.
    projected = travelItem(projected, id: imported.session.mediaItems[0].id)
    let nodeID = try #require(state.selectedBrowserNode?.id)
    state.archiveMediaCache[nodeID] = [projected]
    state.previewingMediaItemID = projected.id
    let destination = try #require(imported.session.mediaItems[0].destinationURL)
    #expect(state.previewingMediaItem?.sourceURL.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath())
    var unrelated = projected
    unrelated = travelItem(unrelated, id: UUID())
    unrelated.sourceURL = root.appendingPathComponent("other/" + projected.fileName)
    state.archiveMediaCache["unrelated-folder"] = [unrelated]
    var ancestor = projected
    ancestor.relativePath = "Walk/" + projected.fileName
    state.archiveMediaCache["ancestor-folder"] = [ancestor]
    state.cropMediaItem(projected, normalizedRect: CropNormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), trigger: .manualDrag)
    #expect(await waitForTravelCondition { !state.isCropInProgress(for: projected) && state.archiveMediaCache[nodeID]?.count == 2 })
    #expect(state.currentSession?.mediaItems.count == 1)
    #expect(state.currentSession?.mediaItems[0].cropRelationship == nil)
    #expect(state.archiveMediaCache["unrelated-folder"]?.count == 1)
    #expect(state.archiveMediaCache["ancestor-folder"] == nil)
    let crop = try #require(state.archiveMediaCache[nodeID]?.first { $0.cropRelationship?.role == .crop })
    state.openCropLinkedPreview(for: crop.id)
    #expect(state.previewingMediaItem?.sourceURL.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath())
    #expect(await waitForTravelCondition {
        (try? ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: main).filter { $0.kind == .photo }.count) == 2
    })
    // Refresh creates only fixture-local SQLite/index state; never the installed app's support data.
}

@Test func duplicateCanonicalPhotoPathsFailWithoutReplacingPreviousIndex() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        selectionState: .included, lifecycleState: .selectedForImport)
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item]))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let pointer = ArchiveIndexStore.indexRoot(for: archive).appendingPathComponent("index-current.json")
    let before = try Data(contentsOf: pointer)
    let photo = try #require(imported.session.mediaItems[0].destinationURL)
    try FileManager.default.copyItem(at: photo.deletingPathExtension().appendingPathExtension("md"),
        to: photo.deletingLastPathComponent().appendingPathComponent("conflicted-photo.md"))
    #expect(throws: (any Error).self) { try ArchiveIndexStore().rebuildIndex(archiveRoot: archive) }
    #expect(try Data(contentsOf: pointer) == before)
}

private final class ProjectionLockProbe: FileManager, @unchecked Sendable {
    var archive: URL?
    var walk: URL?
    var observedLockedProjection = false
    override func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?,
                                      options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        if url == walk, let archive {
            do {
                let lock = try ArchiveMutationLock(archiveRoot: archive)
                withExtendedLifetime(lock) {}
            } catch { observedLockedProjection = true }
        }
        return try super.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    }
}

@Test func targetedProjectionHoldsArchiveLockWhileReadingCanonicalMetadata() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        selectionState: .included, lifecycleState: .selectedForImport)
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item]))
    let probe = ProjectionLockProbe()
    probe.archive = archive
    probe.walk = imported.walkManifest.archiveFolder
    try ArchiveIndexStore(fileManager: probe).replaceWalkFolders([imported.walkManifest.archiveFolder], archiveRoot: archive)
    #expect(probe.observedLockedProjection)
}

@MainActor
private func waitForTravelCondition(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(30))
    }
    return condition()
}

@Test func canonicalIndexIncludesCropsOfCrops() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source")
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        selectionState: .included, lifecycleState: .selectedForImport)
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item]))
    var original = imported.session.mediaItems[0]
    original.sourceURL = try #require(original.destinationURL)
    let crop = try CropService().crop(item: original, normalizedRect: CropNormalizedRect(x: 0, y: 0, width: 0.8, height: 0.8), trigger: .manualDrag)
    var child = original
    child.sourceURL = crop.outputURL
    child.fileName = crop.outputURL.lastPathComponent
    let second = try CropService().crop(item: child, normalizedRect: CropNormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), trigger: .manualDrag)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).filter { $0.kind == .photo }
    #expect(rows.count == 3)
    #expect(rows.contains { $0.archiveRelativePath.hasSuffix(second.outputURL.lastPathComponent) })
}

private func travelItem(_ item: MediaItem, id: UUID) -> MediaItem {
    MediaItem(id: id, sourceURL: item.sourceURL, relativePath: item.relativePath, fileName: item.fileName,
        baseName: item.baseName, mediaKind: item.mediaKind, fileSizeBytes: item.fileSizeBytes,
        capturedAt: item.capturedAt, metadata: item.metadata, thumbnailCacheKey: item.thumbnailCacheKey,
        selectionState: item.selectionState, companionFiles: item.companionFiles,
        lifecycleState: item.lifecycleState, destinationURL: item.destinationURL,
        archiveRelativePath: item.archiveRelativePath, cropRelationship: item.cropRelationship)
}

@Test func archiveBytePolicyDoesNotFollowChangedSymlinkOutsideArchive() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    let outside = root.appendingPathComponent("outside.jpg")
    try AppDirectories.ensureExists(archive)
    try writeTestFile(outside, contents: "outside original")
    let linked = archive.appendingPathComponent("photo.jpg")
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive
    settings.archiveMachineRole = .travel
    let context = ArchiveByteReadPolicyContext()
    context.update(settings: settings)
    #expect(context.canReadBytes(at: linked) == false)
    #expect(context.canReadBytes(at: linked, explicitDownload: true) == false)
    #expect(context.canPreheatOriginal(at: linked) == false)
    #expect(context.canGenerateImplicitThumbnail(at: linked) == false)
    #expect(context.canReadBytes(at: outside))
}
