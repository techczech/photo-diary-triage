import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func importCoordinatorCommitCopiesSelectedFilesAndWritesManifests() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 11_000)
    let sourceURL = sourceRoot.appendingPathComponent("IMG_0001.jpg")
    try writeTestFile(sourceURL, contents: "selected-image-data")

    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0001.jpg",
        capturedAt: capturedAt,
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item], title: "Morning Walk")

    let result = try await ImportCoordinator().commit(session: session)
    let importedItem = try requireSingleMediaItem(in: result.session)
    let walkBasename = result.walkManifest.archiveFolder.lastPathComponent
    let fileStem = DateFormatting.archiveFileStem(from: capturedAt, title: "Morning Walk")
    let walkManifestURL = result.walkManifest.archiveFolder.appendingPathComponent("\(walkBasename).md")
    let fileManifestURL = try #require(importedItem.destinationURL?.deletingPathExtension().appendingPathExtension("md"))
    let sessionLogURL = result.walkManifest.archiveFolder.appendingPathComponent("\(walkBasename)-session-log.jsonl")

    #expect(importedItem.destinationURL != nil)
    #expect(importedItem.lifecycleState == .verified)
    #expect(importedItem.importedAt != nil)
    #expect(importedItem.verifiedAt != nil)
    #expect(result.session.status == "imported")
    #expect(result.fileManifests.count == 1)
    #expect(FileManager.default.fileExists(atPath: importedItem.destinationURL?.path ?? ""))
    #expect(importedItem.destinationURL?.lastPathComponent == "\(fileStem)-001.jpg")
    #expect(FileManager.default.fileExists(atPath: walkManifestURL.path))
    #expect(FileManager.default.fileExists(atPath: fileManifestURL.path))
    #expect(fileManifestURL.deletingPathExtension().lastPathComponent == importedItem.destinationURL?.deletingPathExtension().lastPathComponent)
    #expect(FileManager.default.fileExists(atPath: sessionLogURL.path))
    #expect(!FileManager.default.fileExists(atPath: result.walkManifest.archiveFolder.appendingPathComponent("_session", isDirectory: true).path))
}

@Test func importCoordinatorCommitSurvivesUnwritableArchiveIndexPath() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    try writeTestFile(archiveRoot.appendingPathComponent("_index"), contents: "not a directory")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0099.jpg"), contents: "selected-image-data")

    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0099.jpg",
        capturedAt: Date(timeIntervalSince1970: 11_500),
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item], title: "Index Failure Walk")

    let result = try await ImportCoordinator().commit(session: session)
    let importedItem = try requireSingleMediaItem(in: result.session)

    #expect(importedItem.destinationURL != nil)
    #expect(importedItem.lifecycleState == .verified)
    #expect(result.fileManifests.count == 1)
    #expect(FileManager.default.fileExists(atPath: result.walkManifest.archiveFolder.appendingPathComponent("\(result.walkManifest.archiveFolder.lastPathComponent).md").path))
}

@Test func importCoordinatorCommitImportsCompanionsWhenEnabled() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 12_000)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0002.jpg"), contents: "jpeg-data")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0002.cr3"), contents: "raw-data")

    let companion = makeTestCompanionFile(sourceRoot: sourceRoot, fileName: "IMG_0002.cr3")
    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0002.jpg",
        capturedAt: capturedAt,
        selectionState: .included,
        importRawCompanions: true,
        companionFiles: [companion],
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item], title: "RAW Walk")

    let result = try await ImportCoordinator().commit(session: session)
    let importedItem = try requireSingleMediaItem(in: result.session)
    let importedCompanion = try requireSingleCompanion(in: importedItem)

    #expect(result.fileManifests.count == 1)
    #expect(result.fileManifests[0].companionArchivePaths.count == 1)
    #expect(importedCompanion.destinationURL != nil)
    #expect(importedCompanion.verifiedAt != nil)
    #expect(FileManager.default.fileExists(atPath: importedCompanion.destinationURL?.path ?? ""))
    #expect(result.walkManifest.summary.importedFiles == 2)
}

@Test func importCoordinatorCommitMarksCleanupPendingWhenBackupAlreadyConfirmed() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 13_000)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0003.jpg"), contents: "backup-confirmed-data")

    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0003.jpg",
        capturedAt: capturedAt,
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: [item],
        title: "Confirmed Backup Walk",
        backupConfirmedAt: Date()
    )

    let result = try await ImportCoordinator().commit(session: session)

    #expect(result.session.mediaItems[0].lifecycleState == .sourceCleanupPending)
    #expect(result.walkManifest.summary.cleanupPendingFiles == 1)
}

@Test func importCoordinatorCommitSkipsAlreadyCopiedIncludedItems() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.jpg"), contents: "already copied")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0002.jpg"), contents: "new copy")

    var copiedItem = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0001.jpg",
        capturedAt: Date(timeIntervalSince1970: 13_100),
        selectionState: .included,
        lifecycleState: .sourceCleanupPending
    )
    let copiedDestination = archiveRoot.appendingPathComponent("existing/IMG_0001.jpg")
    try writeTestFile(copiedDestination, contents: "already copied")
    copiedItem.destinationURL = copiedDestination

    let newItem = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0002.jpg",
        capturedAt: Date(timeIntervalSince1970: 13_200),
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: [copiedItem, newItem],
        title: "Continued Copy"
    )

    let result = try await ImportCoordinator().commit(session: session)
    let refreshedCopiedItem = try #require(result.session.mediaItems.first { $0.id == copiedItem.id })
    let refreshedNewItem = try #require(result.session.mediaItems.first { $0.id == newItem.id })

    #expect(refreshedCopiedItem.lifecycleState == .sourceCleanupPending)
    #expect(refreshedCopiedItem.destinationURL == copiedDestination)
    #expect(refreshedNewItem.lifecycleState == .verified)
    #expect(refreshedNewItem.destinationURL != nil)
    #expect(result.fileManifests.count == 2)
}

@Test func importCoordinatorCleanupSkipsWhenSelectedItemsAreNotCleanupPending() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let sourceURL = sourceRoot.appendingPathComponent("IMG_0004.jpg")
    try writeTestFile(sourceURL, contents: "keep-source")

    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0004.jpg",
        capturedAt: Date(timeIntervalSince1970: 14_000),
        selectionState: .included,
        lifecycleState: .verified
    )
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item])

    let cleaned = try await ImportCoordinator().cleanupImportedSources(in: session)

    #expect(cleaned == session)
    #expect(FileManager.default.fileExists(atPath: sourceURL.path))
}

@Test func importCoordinatorCleanupRemovesPendingSourcesAndCompanions() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let sourceURL = sourceRoot.appendingPathComponent("IMG_0005.jpg")
    let companionSourceURL = sourceRoot.appendingPathComponent("IMG_0005.cr3")
    try writeTestFile(sourceURL, contents: "cleanup-source")
    try writeTestFile(companionSourceURL, contents: "cleanup-companion")

    var companion = makeTestCompanionFile(sourceRoot: sourceRoot, fileName: "IMG_0005.cr3")
    companion.destinationURL = archiveRoot.appendingPathComponent("2026/03/example/IMG_0005.cr3")

    var item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_0005.jpg",
        capturedAt: Date(timeIntervalSince1970: 15_000),
        selectionState: .included,
        importRawCompanions: true,
        companionFiles: [companion],
        lifecycleState: .sourceCleanupPending
    )
    item.destinationURL = archiveRoot.appendingPathComponent("2026/03/example/IMG_0005.jpg")

    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item])
    let cleaned = try await ImportCoordinator().cleanupImportedSources(in: session)
    let cleanedItem = try requireSingleMediaItem(in: cleaned)
    let cleanedCompanion = try requireSingleCompanion(in: cleanedItem)

    #expect(cleanedItem.lifecycleState == .sourceCleaned)
    #expect(cleanedItem.sourceCleanedAt != nil)
    #expect(cleanedCompanion.sourceCleanedAt != nil)
    #expect(FileManager.default.fileExists(atPath: sourceURL.path) == false)
    #expect(FileManager.default.fileExists(atPath: companionSourceURL.path) == false)
}

@MainActor
@Test func importWorkflowPublishesProgressAndResetsOnSuccess() async throws {
    let session = makeWorkflowSession(selectedCount: 2)
    let result = makeStubImportResult(session: session)
    let coordinator = StubImportCoordinator(
        result: result,
        progressSteps: [
            ImportProgress(current: 1, total: 2),
            ImportProgress(current: 2, total: 2)
        ]
    )
    let workflow = ImportWorkflow(coordinator: coordinator)
    var snapshots: [ImportProgress?] = []

    _ = try await workflow.commit(session: session) { progress in
        snapshots.append(progress)
    }

    #expect(snapshots.first == ImportProgress(current: 0, total: 2))
    #expect(snapshots.contains(ImportProgress(current: 1, total: 2)))
    #expect(snapshots.contains(ImportProgress(current: 2, total: 2)))
    #expect(snapshots[snapshots.count - 1] == nil)
    #expect(workflow.importProgress == nil)
}

@MainActor
@Test func importWorkflowInitialProgressCountsRawCompanions() async throws {
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
        capturedAt: Date(timeIntervalSince1970: 60_000),
        selectionState: .included,
        importRawCompanions: true,
        companionFiles: [companion],
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item])
    let coordinator = StubImportCoordinator(
        result: makeStubImportResult(session: session),
        progressSteps: [ImportProgress(current: 2, total: 2)]
    )
    let workflow = ImportWorkflow(coordinator: coordinator)
    var snapshots: [ImportProgress?] = []

    _ = try await workflow.commit(session: session) { progress in
        snapshots.append(progress)
    }

    #expect(snapshots.first == ImportProgress(current: 0, total: 2))
    #expect(snapshots.contains(ImportProgress(current: 2, total: 2)))
}

@MainActor
@Test func importWorkflowResetsProgressOnFailure() async {
    let session = makeWorkflowSession(selectedCount: 1)
    let coordinator = StubImportCoordinator(
        result: nil,
        progressSteps: [ImportProgress(current: 1, total: 1)],
        error: NSError(domain: "ImportWorkflowTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Stub import failure"])
    )
    let workflow = ImportWorkflow(coordinator: coordinator)
    var snapshots: [ImportProgress?] = []
    var didThrow = false

    do {
        _ = try await workflow.commit(session: session) { progress in
            snapshots.append(progress)
        }
    } catch {
        didThrow = true
    }

    #expect(didThrow)
    #expect(snapshots.first == ImportProgress(current: 0, total: 1))
    #expect(snapshots.contains(ImportProgress(current: 1, total: 1)))
    #expect(snapshots[snapshots.count - 1] == nil)
    #expect(workflow.importProgress == nil)
}

private final class StubImportCoordinator: ImportCoordinating {
    let result: ImportResult?
    let progressSteps: [ImportProgress]
    let error: Error?

    init(result: ImportResult?, progressSteps: [ImportProgress], error: Error? = nil) {
        self.result = result
        self.progressSteps = progressSteps
        self.error = error
    }

    func commit(
        session: ImportSession,
        progress: (@Sendable (ImportProgress) async -> Void)?
    ) async throws -> ImportResult {
        for step in progressSteps {
            if let progress {
                await progress(step)
            }
        }

        if let error {
            throw error
        }

        return result ?? makeStubImportResult(session: session)
    }

    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession {
        session
    }
}

private func makeWorkflowSession(selectedCount: Int) -> ImportSession {
    let sourceRoot = URL(fileURLWithPath: "/tmp/workflow-source", isDirectory: true)
    let archiveRoot = URL(fileURLWithPath: "/tmp/workflow-archive", isDirectory: true)
    let base = Date(timeIntervalSince1970: 16_000)
    let items = (0..<selectedCount).map { index in
        makeTestMediaItem(
            sourceRoot: sourceRoot,
            fileName: "workflow-\(index).jpg",
            capturedAt: base.addingTimeInterval(Double(index)),
            selectionState: .included,
            lifecycleState: .selectedForImport
        )
    }
    return makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: items)
}

private func makeStubImportResult(session: ImportSession) -> ImportResult {
    ImportResult(
        session: session,
        walkManifest: WalkManifest(
            sessionID: session.id,
            walkDate: session.mediaItems.compactMap(\.capturedAt).min(),
            sourceFolder: session.sourceFolder,
            archiveFolder: session.archiveRoot.appendingPathComponent("stub"),
            title: session.walkMetadata.title,
            location: session.walkMetadata.location,
            notes: session.walkMetadata.notes,
            summary: .init(
                totalSourceFiles: session.mediaItems.count,
                visibleItems: session.mediaItems.count,
                importedFiles: session.mediaItems.count,
                skippedFiles: 0,
                cleanupPendingFiles: 0,
                cleanedSourceFiles: 0
            ),
            importedFiles: []
        ),
        fileManifests: [],
        events: []
    )
}

private func requireSingleMediaItem(in session: ImportSession) throws -> MediaItem {
    guard let item = session.mediaItems.first, session.mediaItems.count == 1 else {
        throw NSError(domain: "ImportWorkflowTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected exactly one media item."])
    }
    return item
}

private func requireSingleCompanion(in item: MediaItem) throws -> CompanionFile {
    guard let companion = item.companionFiles.first, item.companionFiles.count == 1 else {
        throw NSError(domain: "ImportWorkflowTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected exactly one companion file."])
    }
    return companion
}
