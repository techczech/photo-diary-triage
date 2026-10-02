import Foundation
import Testing
@testable import PhotoDiaryTriage

private final class FailingImportFileManager: FileManager, @unchecked Sendable {
    var failCopyName: String?
    var failRemovalName: String?
    var corruptCopy = false

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if srcURL.lastPathComponent == failCopyName {
            throw CocoaError(.fileWriteOutOfSpace)
        }
        try super.copyItem(at: srcURL, to: dstURL)
        if corruptCopy {
            let count = try Data(contentsOf: dstURL).count
            try Data(repeating: 0, count: count).write(to: dstURL)
        }
    }

    override func removeItem(at URL: URL) throws {
        if URL.lastPathComponent == failRemovalName {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.removeItem(at: URL)
    }
}

private func reliabilitySession(root: URL, count: Int = 1) throws -> ImportSession {
    let source = root.appendingPathComponent("source")
    let archive = root.appendingPathComponent("archive")
    let items = try (1...count).map { number in
        let name = "IMG_000\(number).jpg"
        try writeTestFile(source.appendingPathComponent(name), contents: "photo-content-\(number)")
        return makeTestMediaItem(sourceRoot: source, fileName: name,
                                 capturedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(number)),
                                 selectionState: .included, lifecycleState: .selectedForImport)
    }
    return makeTestSession(sourceRoot: source, archiveRoot: archive, items: items, backupConfirmedAt: Date())
}

private func archivedPhotos(root: URL) -> [URL] {
    let urls = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
    return urls?.compactMap { $0 as? URL }.filter { $0.pathExtension == "jpg" } ?? []
}

@Test func importRejectsEqualSizeCorruption() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try reliabilitySession(root: root)
    let manager = FailingImportFileManager()
    manager.corruptCopy = true
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator(fileManager: manager).commit(session: session)
    }
    #expect(FileManager.default.fileExists(atPath: session.mediaItems[0].sourceURL.path))
}

@Test func cleanupRetainsAllSourcesWhenOneDestinationDisappears() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root, count: 2))
    try FileManager.default.removeItem(at: #require(imported.session.mediaItems.last?.destinationURL))
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator().cleanupImportedSources(in: imported.session)
    }
    #expect(imported.session.mediaItems.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@Test func cleanupRejectsSameSizeArchiveCorruption() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    let destination = try #require(imported.session.mediaItems[0].destinationURL)
    let data = try Data(contentsOf: destination)
    try Data(repeating: 0, count: data.count).write(to: destination)
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator().cleanupImportedSources(in: imported.session)
    }
    #expect(FileManager.default.fileExists(atPath: imported.session.mediaItems[0].sourceURL.path))
}

@Test func cleanupRejectsChangedSourceAndMissingBackupConfirmation() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root)).session
    imported.walkMetadata.backupConfirmedAt = nil
    let unchanged = try await ImportCoordinator().cleanupImportedSources(in: imported)
    #expect(unchanged == imported)
    #expect(FileManager.default.fileExists(atPath: imported.mediaItems[0].sourceURL.path))
    imported.walkMetadata.backupConfirmedAt = Date()
    try writeTestFile(imported.mediaItems[0].sourceURL, contents: "changed-after-verification")
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator().cleanupImportedSources(in: imported)
    }
    #expect(FileManager.default.fileExists(atPath: imported.mediaItems[0].sourceURL.path))
}

@Test func importRetryReusesCopiesAfterSecondCopyFails() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try reliabilitySession(root: root, count: 2)
    let manager = FailingImportFileManager()
    manager.failCopyName = "IMG_0002.jpg"
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator(fileManager: manager).commit(session: session)
    }
    let result = try await ImportCoordinator().commit(session: session)
    #expect(archivedPhotos(root: session.archiveRoot).count == 2)
    #expect(result.fileManifests.count == 2)
    #expect(result.session.mediaItems.allSatisfy { $0.lifecycleState == .sourceCleanupPending })
    #expect(session.mediaItems.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@Test func importRetryReusesCopiesAfterManifestWriteFails() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try reliabilitySession(root: root)
    let plan = ArchivePlanner().plan(for: session)
    let blocker = plan.archiveFolder.appendingPathComponent("\(plan.archiveFolder.lastPathComponent).md")
    try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: true)
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator().commit(session: session)
    }
    try FileManager.default.removeItem(at: blocker)
    let result = try await ImportCoordinator().commit(session: session)
    #expect(archivedPhotos(root: session.archiveRoot).count == 1)
    #expect(result.walkManifests.count == 1)
    #expect(FileManager.default.fileExists(atPath: blocker.path))
}

@Test func cleanupResumesAfterPrimaryDeletionAndCompanionFailure() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var session = try reliabilitySession(root: root)
    let rawURL = session.sourceFolder.appendingPathComponent("IMG_0001.cr3")
    try writeTestFile(rawURL, contents: "raw-content")
    session.mediaItems[0].importRawCompanions = true
    session.mediaItems[0].companionFiles = [makeTestCompanionFile(sourceRoot: session.sourceFolder, fileName: rawURL.lastPathComponent)]
    let imported = try await ImportCoordinator().commit(session: session)
    let manager = FailingImportFileManager()
    manager.failRemovalName = rawURL.lastPathComponent
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator(fileManager: manager).cleanupImportedSources(in: imported.session)
    }
    let cleaned = try await ImportCoordinator().cleanupImportedSources(in: imported.session)
    #expect(cleaned.mediaItems[0].lifecycleState == .sourceCleaned)
    #expect(cleaned.mediaItems[0].companionFiles[0].sourceCleanedAt != nil)
    #expect(!FileManager.default.fileExists(atPath: rawURL.path))
}

@Test func cleanupKeepsJPEGWhenRAWArchiveCopyIsMissing() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var session = try reliabilitySession(root: root)
    let rawURL = session.sourceFolder.appendingPathComponent("IMG_0001.cr3")
    try writeTestFile(rawURL, contents: "raw-content")
    session.mediaItems[0].importRawCompanions = true
    session.mediaItems[0].companionFiles = [makeTestCompanionFile(sourceRoot: session.sourceFolder, fileName: rawURL.lastPathComponent)]
    let imported = try await ImportCoordinator().commit(session: session)
    try FileManager.default.removeItem(at: #require(imported.session.mediaItems[0].companionFiles[0].destinationURL))
    await #expect(throws: (any Error).self) {
        try await ImportCoordinator().cleanupImportedSources(in: imported.session)
    }
    #expect(FileManager.default.fileExists(atPath: session.mediaItems[0].sourceURL.path))
    #expect(FileManager.default.fileExists(atPath: rawURL.path))
}

@Test func failedBackupRestorePreservesExistingSessions() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionStore(databaseURL: root.appendingPathComponent("sessions.sqlite"))
    let existing = try reliabilitySession(root: root)
    try store.save(session: existing, bursts: [], clusters: [])
    var invalid = existing
    invalid.walkMetadata.latitude = .infinity
    #expect(throws: (any Error).self) {
        try store.replaceAllSessions(with: [(invalid, [], [])])
    }
    #expect(try store.loadSessions().map { $0.0 } == [existing])
}


private final class FailingIndexFileManager: FileManager, @unchecked Sendable {
    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool,
                                  attributes: [FileAttributeKey: Any]? = nil) throws {
        if url.path.contains("/generations/") { throw CocoaError(.fileWriteOutOfSpace) }
        try super.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
}

@Test func failedIndexPublicationPreservesPreviousCompleteIndex() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let result = try await ImportCoordinator().commit(session: reliabilitySession(root: root, count: 2))
    let archive = result.session.archiveRoot
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let before = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
    #expect(throws: (any Error).self) {
        try ArchiveIndexStore(fileManager: FailingIndexFileManager()).rebuildIndex(archiveRoot: archive)
    }
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive) == before)
}

@Test func unreadableCanonicalRecordDoesNotDiscardIndexRows() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let result = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    let archive = result.session.archiveRoot
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let before = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
    let manifest = try #require(result.session.mediaItems[0].destinationURL).deletingPathExtension().appendingPathExtension("md")
    try Data([0xff, 0xfe, 0xff]).write(to: manifest)
    #expect(throws: (any Error).self) { try ArchiveIndexStore().rebuildIndex(archiveRoot: archive) }
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive) == before)
}

@Test func unknownArchiveAvailabilityCannotReadBytesImplicitly() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let missing = root.appendingPathComponent("missing.jpg")
    let policy = ArchiveByteReadPolicy(archiveRoot: root, machineRole: .travel)
    #expect(!policy.canReadBytes(at: missing))
    #expect(!policy.canGenerateImplicitThumbnail(at: missing))
    #expect(policy.canReadBytes(at: missing, explicitDownload: true))
}

private actor EvictionRecorder {
    var urls: [URL] = []
    func record(_ url: URL) { urls.append(url) }
}

@Test func failedOrCancelledThumbnailGenerationEvictsHydratedOriginal() async throws {
    for cancel in [false, true] {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let photo = root.appendingPathComponent("2020/sparse.jpg")
        try writeTestFile(photo, contents: "")
        let handle = try FileHandle(forWritingTo: photo)
        try handle.truncate(atOffset: 1_048_576)
        try handle.close()
        let recorder = EvictionRecorder()
        let store = ArchiveIndexStore(availableCapacityProvider: { _ in Int64.max },
            evictor: { await recorder.record($0) }, thumbnailGenerator: { _, _ in
                if cancel { throw CancellationError() }
                throw CocoaError(.fileReadCorruptFile)
            })
        let result = await store.backfillThumbnails(archiveRoot: root, supportedExtensions: ["jpg"],
                                                  photoURLs: [photo], throttleNanoseconds: 0)
        #expect(await recorder.urls == [photo])
        #expect(result.evictedFiles == 1)
        #expect(result.generatedThumbnails == 0)
        #expect(result.cancelled == cancel)
        #expect(cancel || !result.failures.isEmpty)
    }
}


@Test func canonicalMetadataSurvivesCacheDeletionAndArchiveRelocation() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root)).session
    let photo = try #require(imported.mediaItems[0].destinationURL)
    let fileManifest = photo.deletingPathExtension().appendingPathExtension("md")
    var text = try String(contentsOf: fileManifest, encoding: .utf8)
    text = text.replacingOccurrences(of: "---\nmedia_item_id:", with: "---\ncustom_key: preserve-this\nmedia_item_id:")
    try text.write(to: fileManifest, atomically: true, encoding: .utf8)
    imported.walkMetadata.title = "Česká cesta"
    imported.walkMetadata.location = "Padouchov"
    imported.walkMetadata.latitude = 50.7
    imported.walkMetadata.longitude = 15.0
    imported.walkMetadata.notes = "Dvě tety a synovec.\n\n## Vlastní vzpomínka\nCesta \\ lesem, \"večer\".\n---\nPokračování."
    try ArchiveManifestEditor().saveMetadata(for: imported)
    let saved = try String(contentsOf: fileManifest, encoding: .utf8)
    #expect(saved.contains("custom_key: preserve-this"))
    #expect(ArchiveManifestText.scalar("walk_title", in: saved) == "Česká cesta")
    #expect(ArchiveManifestText.body(in: saved) == "Test notes")
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.archiveRoot)
    try FileManager.default.removeItem(at: ArchiveIndexStore.indexRoot(for: imported.archiveRoot))
    let relocated = root.appendingPathComponent("travel-archive")
    try FileManager.default.copyItem(at: imported.archiveRoot, to: relocated)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: relocated)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: relocated)
    let walk = try #require(rows.first { $0.kind == .walk })
    #expect(walk.title == "Česká cesta")
    #expect(walk.location == "Padouchov")
    #expect(walk.latitude == 50.7)
    #expect(walk.longitude == 15.0)
    #expect(walk.notes == imported.walkMetadata.notes)
    #expect(rows.first { $0.kind == .photo }?.archiveRelativePath == imported.mediaItems[0].archiveRelativePath)
    #expect(rows.allSatisfy { !$0.archiveRelativePath.contains(imported.archiveRoot.path) })
}

@Test func distinctWalkMetadataDoesNotUseSessionWideTitleAndLocation() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var session = try reliabilitySession(root: root, count: 2)
    session.proposedWalks = [
        Walk(title: "Morning", date: session.mediaItems[0].capturedAt!, mediaItemIDs: [session.mediaItems[0].id],
             location: "Oxford", latitude: 51.75, longitude: -1.25),
        Walk(title: "Evening", date: session.mediaItems[1].capturedAt!, mediaItemIDs: [session.mediaItems[1].id],
             location: "Woodstock", latitude: 51.85, longitude: -1.35)
    ]
    let imported = try await ImportCoordinator().commit(session: session)
    #expect(imported.walkManifests.map(\.location) == ["Oxford", "Woodstock"])
    #expect(imported.walkManifests.map(\.latitude) == [51.75, 51.85])
    #expect(imported.fileManifests.map(\.walkTitle) == ["Morning", "Evening"])
    #expect(imported.fileManifests.map(\.walkLocation) == ["Oxford", "Woodstock"])
    try ArchiveIndexStore().rebuildIndex(archiveRoot: session.archiveRoot)
    let walks = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: session.archiveRoot).filter { $0.kind == .walk }
    #expect(Set(walks.compactMap(\.latitude)) == [51.75, 51.85])
}

@Test func yamlSignificantTextRoundTripsWithoutChangingNotes() {
    let values = ["České jméno: # večer", "back\\slash and \"quotes\"", "one\ntwo", "path---with-dashes"]
    for value in values {
        let text = "---\nsource_file_name: \(ArchiveManifestText.quotedScalar(value))\n---\n\nHuman note---continues\nwalk_title: This is prose."
        #expect(ArchiveManifestText.scalar("source_file_name", in: text) == value)
        #expect(ArchiveManifestText.scalar("walk_title", in: text) == nil)
        #expect(ArchiveManifestText.body(in: text) == "Human note---continues\nwalk_title: This is prose.")
    }
}

@Test func metadataRefreshRetainsTripAndDistinctWalkDetails() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var session = try reliabilitySession(root: root, count: 2)
    session.proposedWalks = [
        Walk(title: "Morning", date: session.mediaItems[0].capturedAt!, mediaItemIDs: [session.mediaItems[0].id], location: "Oxford", latitude: 51.75, longitude: -1.25),
        Walk(title: "Evening", date: session.mediaItems[1].capturedAt!, mediaItemIDs: [session.mediaItems[1].id], location: "Woodstock", latitude: 51.85, longitude: -1.35)
    ]
    let result = try await ImportCoordinator().commit(session: session)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: session.archiveRoot)
    let before = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: session.archiveRoot)
    var edited = result.session
    edited.walkMetadata.notes = "Shared outing notes"
    try ArchiveManifestEditor().saveMetadata(for: edited, previousMetadata: result.session.walkMetadata)
    try await ArchiveIndexMutationQueue().replaceWalkFolders(result.walkManifests.map(\.archiveFolder),
        archiveRoot: session.archiveRoot, policy: ArchiveIndexWritePolicy(machineRole: .mainArchive))
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: session.archiveRoot)
    #expect(rows.filter { $0.kind == .trip } == before.filter { $0.kind == .trip })
    #expect(Set(rows.filter { $0.kind == .walk }.map(\.title)) == ["Morning", "Evening"])
    #expect(Set(rows.filter { $0.kind == .photo }.compactMap(\.location)) == ["Oxford", "Woodstock"])
    #expect(Set(rows.filter { $0.kind == .walk }.compactMap(\.latitude)) == [51.75, 51.85])
    #expect(rows.filter { $0.kind == .walk }.allSatisfy { $0.notes == "Shared outing notes" })
}

@Test func retryRejectsChangedSelectionsAndBackupConsent() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = try reliabilitySession(root: root, count: 2)
    let manager = FailingImportFileManager()
    manager.failCopyName = session.mediaItems[1].fileName
    await #expect(throws: (any Error).self) { try await ImportCoordinator(fileManager: manager).commit(session: session) }
    var changed = session
    changed.mediaItems[1].selectionState = .excluded
    changed.walkMetadata.backupConfirmedAt = nil
    await #expect(throws: (any Error).self) { try await ImportCoordinator().commit(session: changed) }
    #expect(archivedPhotos(root: session.archiveRoot).count == 1)
    let result = try await ImportCoordinator().commit(session: session)
    #expect(result.session.mediaItems.count == 2)
    #expect(archivedPhotos(root: session.archiveRoot).count == 2)
}

@Test func mixedExtensionAppendPreservesPriorManifestsMembershipAndNotes() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    let folder = first.walkManifest.archiveFolder
    let structural = folder.appendingPathComponent("\(folder.lastPathComponent).md")
    let oldText = try String(contentsOf: structural, encoding: .utf8)
    try (oldText + "\n\n## Custom section\nPreserve Czech words: příběh").write(to: structural, atomically: true, encoding: .utf8)
    let log = folder.appendingPathComponent("\(folder.lastPathComponent)-session-log.jsonl")
    let oldLog = try String(contentsOf: log, encoding: .utf8)
    var second = makeTestSession(sourceRoot: first.session.sourceFolder, archiveRoot: first.session.archiveRoot, items: [], backupConfirmedAt: first.session.walkMetadata.backupConfirmedAt)
    second.proposedWalks = []
    let png = second.sourceFolder.appendingPathComponent("another.png")
    try writeTestFile(png, contents: "another photo")
    second.mediaItems = [makeTestMediaItem(sourceRoot: second.sourceFolder, fileName: png.lastPathComponent,
        capturedAt: first.session.mediaItems[0].capturedAt!, selectionState: .included, lifecycleState: .selectedForImport)]
    let appended = try await ImportCoordinator().commit(session: second)
    #expect(appended.walkManifest.archiveFolder == folder)
    #expect(appended.walkManifest.importedFiles.count == 2)
    #expect(appended.fileManifests[0].archivePath != first.fileManifests[0].archivePath)
    #expect(URL(fileURLWithPath: appended.fileManifests[0].archivePath).deletingPathExtension()
        != URL(fileURLWithPath: first.fileManifests[0].archivePath).deletingPathExtension())
    #expect(try String(contentsOf: structural, encoding: .utf8).contains("Preserve Czech words: příběh"))
    #expect(try String(contentsOf: log, encoding: .utf8).hasPrefix(oldLog))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: second.archiveRoot)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: second.archiveRoot)
    #expect(rows.filter { $0.kind == .photo }.count == 2)
    #expect(first.fileManifests[0].sha256 != nil)
}

@Test func fullRebuildRepairsBrokenGenerationPointer() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    let archive = imported.session.archiveRoot
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let pointer = ArchiveIndexStore.indexRoot(for: archive).appendingPathComponent("index-current.json")
    for data in [Data("invalid".utf8), try JSONEncoder().encode(UUID().uuidString)] {
        try data.write(to: pointer)
        try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
        #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).filter { $0.kind == .photo }.count == 1)
    }
}

@Test func partiallySyncedIndexGenerationIsRejected() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let entry = ArchiveIndexEntry(kind: .photo, year: "2020", archiveRelativePath: "2020/photo.jpg",
        date: nil, title: "One", location: nil, exifSummary: nil, aiDescription: "", notes: nil,
        thumbnailPath: nil, walkPath: nil, tripPath: nil)
    var second = entry
    second.year = "2021"
    second.archiveRelativePath = "2021/photo.jpg"
    try ArchiveIndexStore().updateIndex(with: [entry, second], archiveRoot: root)
    let generation = try ArchiveIndexStore.shardRoot(for: root)
    try FileManager.default.removeItem(at: generation.appendingPathComponent("index-2021.jsonl"))
    #expect(throws: (any Error).self) { try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: root) }
}

private actor ThumbnailSuspension {
    var started = false
    var continuation: CheckedContinuation<Void, Never>?
    func suspend() async { started = true; await withCheckedContinuation { continuation = $0 } }
    func resume() { continuation?.resume(); continuation = nil }
}

@Test func delayedImportIndexingReadsLatestCanonicalMetadata() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    let gate = ThumbnailSuspension()
    let store = ArchiveIndexStore(thumbnailGenerator: { photo, _ in await gate.suspend(); return photo })
    let queue = ArchiveIndexMutationQueue(store: store)
    let policy = ArchiveIndexWritePolicy(machineRole: .mainArchive)
    let task = Task { try await queue.updateAfterImport(result: imported, policy: policy) }
    while !(await gate.started) { await Task.yield() }
    var edited = imported.session
    edited.walkMetadata.location = "Latest location"
    try ArchiveManifestEditor().saveMetadata(for: edited, previousMetadata: imported.session.walkMetadata)
    try await queue.replaceWalkFolders(imported.walkManifests.map(\.archiveFolder), archiveRoot: edited.archiveRoot, policy: policy)
    await gate.resume()
    try await task.value
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: edited.archiveRoot)
    #expect(rows.filter { $0.kind == .walk || $0.kind == .photo }.allSatisfy { $0.location == "Latest location" })
}

@Test func largeImportUsesBoundedRecoveryCheckpoints() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var session = try reliabilitySession(root: root, count: 128)
    for item in session.mediaItems { try Data(repeating: 42, count: 262_144).write(to: item.sourceURL) }
    session.walkMetadata.notes = "Large deterministic recovery fixture"
    let start = Date()
    let imported = try await ImportCoordinator().commit(session: session)
    let elapsed = Date().timeIntervalSince(start)
    let files = try FileManager.default.contentsOfDirectory(at: ArchiveOperationRecovery(archiveRoot: session.archiveRoot).root, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }
    let total = try files.reduce(0) { $0 + (try Data(contentsOf: $1)).count }
    #expect(imported.fileManifests.count == 128)
    #expect(files.count == 129)
    #expect(total < 1_500_000)
    print("Walkfolio import benchmark: 128 x 256 KiB, \(String(format: "%.3f", elapsed)) seconds, \(total) recovery bytes")
}

@Test func metadataCanChangeLongTitleLocationAndNotesTogether() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    var edited = imported.session
    edited.walkMetadata.title = String(repeating: "Česká dlouhá cesta ", count: 30).trimmingCharacters(in: .whitespaces)
    edited.walkMetadata.location = String(repeating: "Longer Oxford location ", count: 30).trimmingCharacters(in: .whitespaces)
    edited.walkMetadata.notes = "New notes and headings\n\n## Imported Files\nHuman example stays."
    try ArchiveManifestEditor().saveMetadata(for: edited, previousMetadata: imported.session.walkMetadata)
    let walk = try #require(try ArchiveIndexStore().loadWalkManifest(folder: imported.walkManifest.archiveFolder, archiveRoot: edited.archiveRoot))
    #expect(walk.title == edited.walkMetadata.title)
    #expect(walk.location == edited.walkMetadata.location)
    #expect(walk.notes == edited.walkMetadata.notes)
}

@Test func cleanupRejectsChangedSourceAndDestinationAgainstImportDigest() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await ImportCoordinator().commit(session: reliabilitySession(root: root))
    let item = imported.session.mediaItems[0]
    try writeTestFile(item.sourceURL, contents: "both files changed")
    try writeTestFile(try #require(item.destinationURL), contents: "both files changed")
    await #expect(throws: (any Error).self) { try await ImportCoordinator().cleanupImportedSources(in: imported.session) }
    #expect(FileManager.default.fileExists(atPath: item.sourceURL.path))
}
