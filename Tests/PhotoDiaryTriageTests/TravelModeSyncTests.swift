import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func archiveRelativePathResolverRemapsBetweenOneDriveRoots() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let travelRoot = root.appendingPathComponent("travel/OneDrive-Personal/Pictures", isDirectory: true)
    let mainRoot = root.appendingPathComponent("main/OneDrive-Personal/Pictures", isDirectory: true)
    let travelURL = travelRoot
        .appendingPathComponent("2026", isDirectory: true)
        .appendingPathComponent("05", isDirectory: true)
        .appendingPathComponent("2026-05-24-walk", isDirectory: true)
        .appendingPathComponent("2026-05-24-walk-001.jpg")

    let relativePath = try #require(ArchiveRelativePathResolver(root: travelRoot).relativePath(for: travelURL))
    let mainURL = ArchiveRelativePathResolver(root: mainRoot).url(for: relativePath)

    #expect(relativePath == "2026/05/2026-05-24-walk/2026-05-24-walk-001.jpg")
    #expect(mainURL.path == mainRoot.appendingPathComponent(relativePath).path)
}

@Test func importCoordinatorWritesOneDriveRelativePathsIntoSessionAndManifest() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("OneDrive-Personal/Pictures", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 1_770_000_000)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_1200.jpg"), contents: "travel-jpeg-data")

    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_1200.jpg",
        capturedAt: capturedAt,
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    let session = ImportSession(
        sourceFolder: sourceRoot,
        workspaceSourceFolder: sourceRoot,
        archiveRoot: archiveRoot,
        oneDrivePicturesRoot: archiveRoot,
        archiveMachineRole: .travel,
        sessionKind: .walkDraft,
        mediaItems: [item]
    )

    let result = try await ImportCoordinator().commit(session: session)
    let importedItem = try requireOnlyMediaItem(in: result.session)
    let manifest = try #require(result.fileManifests.first)

    #expect(importedItem.archiveRelativePath != nil)
    #expect(importedItem.archiveRelativePath == manifest.archiveRelativePath)
    #expect(importedItem.archiveRelativePath?.hasPrefix("/") == false)
    #expect(importedItem.archiveRelativePath?.hasSuffix(".jpg") == true)
    #expect(result.walkManifest.archiveFolderRelativePath?.hasPrefix("/") == false)
    #expect(importedItem.lifecycleState == .verified)
}

@Test func travelRoleDoesNotAdvanceCopiedItemsToSourceCleanupPending() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("OneDrive-Personal/Pictures", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_1201.jpg"), contents: "travel-source-kept")

    let item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_1201.jpg",
        capturedAt: Date(timeIntervalSince1970: 1_770_000_100),
        selectionState: .included,
        lifecycleState: .selectedForImport
    )
    let session = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: [item],
        title: "Travel Copy",
        backupConfirmedAt: Date()
    )
    var travelSession = session
    travelSession.archiveMachineRole = .travel
    travelSession.oneDrivePicturesRoot = archiveRoot

    let result = try await ImportCoordinator().commit(session: travelSession)
    let importedItem = try requireOnlyMediaItem(in: result.session)
    let cleaned = try await ImportCoordinator().cleanupImportedSources(in: result.session)

    #expect(importedItem.lifecycleState == .verified)
    #expect(cleaned == result.session)
    #expect(FileManager.default.fileExists(atPath: sourceRoot.appendingPathComponent("IMG_1201.jpg").path))
}

@Test func photoLogSyncStoreRemapsDestinationURLsToLocalOneDriveRoot() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let travelRoot = root.appendingPathComponent("travel/OneDrive-Personal/Pictures", isDirectory: true)
    let mainRoot = root.appendingPathComponent("main/OneDrive-Personal/Pictures", isDirectory: true)
    let relativePath = "2026/05/2026-05-24-walk/2026-05-24-walk-001.jpg"
    var item = makeTestMediaItem(
        sourceRoot: sourceRoot,
        fileName: "IMG_1202.jpg",
        capturedAt: Date(timeIntervalSince1970: 1_770_000_200),
        selectionState: .included,
        lifecycleState: .verified
    )
    item.destinationURL = ArchiveRelativePathResolver(root: travelRoot).url(for: relativePath)
    item.archiveRelativePath = relativePath

    let session = ImportSession(
        sourceFolder: sourceRoot,
        workspaceSourceFolder: sourceRoot,
        archiveRoot: travelRoot,
        oneDrivePicturesRoot: travelRoot,
        archiveMachineRole: .travel,
        sessionKind: .walkDraft,
        status: "imported",
        mediaItems: [item]
    )
    let store = PhotoLogSyncStore()
    _ = try store.export(session: session, bursts: [], timeClusters: [], to: travelRoot, machineName: "Travel Mac")

    let records = try store.importRecords(
        from: travelRoot,
        localArchiveRoot: mainRoot,
        localOneDrivePicturesRoot: mainRoot,
        localMachineRole: .mainArchive
    )
    let imported = try #require(records.first?.document.session)
    let importedItem = try requireOnlyMediaItem(in: imported)

    #expect(imported.archiveRoot == mainRoot)
    #expect(imported.oneDrivePicturesRoot == mainRoot)
    #expect(imported.archiveMachineRole == .mainArchive)
    #expect(importedItem.archiveRelativePath == relativePath)
    #expect(importedItem.destinationURL?.path == mainRoot.appendingPathComponent(relativePath).path)
}

private func requireOnlyMediaItem(in session: ImportSession) throws -> MediaItem {
    guard let item = session.mediaItems.first, session.mediaItems.count == 1 else {
        throw NSError(domain: "TravelModeSyncTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected exactly one media item."])
    }
    return item
}
