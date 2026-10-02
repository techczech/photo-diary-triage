import Foundation
import Testing
@testable import PhotoDiaryTriage

private func importedMoveFixture(root: URL) async throws -> ImportResult {
    let source = root.appendingPathComponent("source")
    try writeTestFile(source.appendingPathComponent("photo.jpg"), contents: "photograph contents")
    let item = makeTestMediaItem(sourceRoot: source, fileName: "photo.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included, lifecycleState: .selectedForImport)
    return try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source,
        archiveRoot: root.appendingPathComponent("archive"), items: [item], backupConfirmedAt: Date()))
}

private final class InterruptedMoveFileManager: FileManager, @unchecked Sendable {
    var failName: String?
    override func moveItem(at source: URL, to destination: URL) throws {
        if source.lastPathComponent == failName { throw CocoaError(.fileWriteNoPermission) }
        try super.moveItem(at: source, to: destination)
    }
}

@Test func collisionMoveRebuildsCanonicalRecordsAndSavedSessionPaths() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await importedMoveFixture(root: root)
    let old = imported.walkManifest.archiveFolder
    let trip = old.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent(old.deletingLastPathComponent().lastPathComponent + "-Oxford")
    try FileManager.default.createDirectory(at: trip.appendingPathComponent(old.lastPathComponent), withIntermediateDirectories: true)
    let manifest = old.appendingPathComponent("\(old.lastPathComponent).md")
    var edited = imported.session
    edited.walkMetadata.notes = "Remember \(old.path); keep 03-Monday-example and Czech příběh."
    try ArchiveManifestEditor().saveMetadata(for: edited)
    let oldText = try String(contentsOf: manifest, encoding: .utf8)
    let result = try WalkMover().moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    #expect(result.destinationFolder.lastPathComponent == old.lastPathComponent + "-1")
    #expect(FileManager.default.fileExists(atPath: result.destinationFolder.appendingPathComponent("\(result.destinationFolder.lastPathComponent).md").path))
    #expect(FileManager.default.fileExists(atPath: result.destinationFolder.appendingPathComponent("\(result.destinationFolder.lastPathComponent)-session-log.jsonl").path))
    let movedText = try String(contentsOf: result.destinationFolder.appendingPathComponent("\(result.destinationFolder.lastPathComponent).md"), encoding: .utf8)
    #expect(movedText.contains(edited.walkMetadata.notes))
    #expect(oldText.contains(edited.walkMetadata.notes))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: imported.session.archiveRoot)
    #expect(rows.filter { $0.kind == .walk }.count == 1)
    #expect(rows.first { $0.kind == .walk }?.notes == edited.walkMetadata.notes)
    let reconciled = try ArchiveSessionPathReconciler().reconcile(edited)
    #expect(reconciled.mediaItems[0].destinationURL?.deletingLastPathComponent() == result.destinationFolder)
    #expect(reconciled.mediaItems[0].sourceURL == edited.mediaItems[0].sourceURL)
    #expect(reconciled.mediaItems[0].archiveRelativePath == rows.first { $0.kind == .photo }?.archiveRelativePath)
}

@Test func sameTripMoveDoesNothingAndInterruptedCollisionMoveResumesOnce() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await importedMoveFixture(root: root)
    let old = imported.walkManifest.archiveFolder
    #expect(try WalkMover().moveWalk(at: old, to: old.deletingLastPathComponent(), oneDrivePicturesRoot: imported.session.archiveRoot).destinationFolder == old)
    let trip = old.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-Test")
    try FileManager.default.createDirectory(at: trip.appendingPathComponent(old.lastPathComponent), withIntermediateDirectories: true)
    let manager = InterruptedMoveFileManager()
    manager.failName = old.lastPathComponent + ".md"
    #expect(throws: (any Error).self) {
        try WalkMover(fileManager: manager).moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    }
    #expect(!FileManager.default.fileExists(atPath: old.path))
    let result = try WalkMover().moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    #expect(result.destinationFolder.lastPathComponent == old.lastPathComponent + "-1")
    #expect(!FileManager.default.fileExists(atPath: trip.appendingPathComponent(old.lastPathComponent + "-2").path))
    #expect(try WalkMover().moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot).destinationFolder == result.destinationFolder)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: imported.session.archiveRoot).filter { $0.kind == .photo }.count == 1)
}

@Test func moveRejectsInvalidSidecarAndEscapingSymlinkBeforeMoving() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await importedMoveFixture(root: root)
    let old = imported.walkManifest.archiveFolder
    let invalid = old.appendingPathComponent("crop.json")
    try writeTestFile(invalid, contents: "{broken-json")
    let trip = old.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-Test")
    #expect(throws: (any Error).self) {
        try WalkMover().moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    }
    #expect(FileManager.default.fileExists(atPath: old.path))
    try FileManager.default.removeItem(at: invalid)
    let external = root.appendingPathComponent("external")
    try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: trip, withDestinationURL: external)
    #expect(throws: (any Error).self) {
        try WalkMover().moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    }
    #expect(FileManager.default.fileExists(atPath: old.path))
}

@Test func typedRewritePreservesHumanTextUnknownJSONAndSharedPrefix() throws {
    let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: "/archive/2026/05-May/walk", newAbsoluteFolderPath: "/archive/2026/05-May-Oxford/walk",
        oldRelativeFolderPath: "2026/05-May/walk", newRelativeFolderPath: "2026/05-May-Oxford/walk",
        oldTripRelativePath: "2026/05-May", newTripRelativePath: "2026/05-May-Oxford")
    let text = "# Keep 05-May\n- Archive folder: `/archive/2026/05-May/walk`\n- Trip folder: `2026/05-May`\n\n## Notes\n\nRemember /archive/2026/05-May/walk.\n\n## Imported Files\n\n- `source.jpg` -> `/archive/2026/05-May/walk/photo.jpg` (`2026/05-May/walk/photo.jpg`)\n\n## Excluded Files\n"
    let result = try ArchiveTextSidecarRewriter().rewriteStructured(text, extension: "md", spec: spec)
    #expect(result.contains("Remember /archive/2026/05-May/walk."))
    #expect(result.contains("`2026/05-May-Oxford/walk/photo.jpg`"))
    #expect(!result.contains("Oxford-Oxford"))
    let unknown = #"{"notes":"/archive/2026/05-May/walk", "user": "příběh"}"#
    #expect(try ArchiveTextSidecarRewriter().rewriteStructured(unknown, extension: "json", spec: spec) == unknown)
}

@Test func tripMovePreservesHumanTitleCustomTextAndRecomputesDates() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await importedMoveFixture(root: root)
    let old = imported.walkManifest.archiveFolder
    let trip = old.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-Oxford")
    let store = TripManifestStore()
    _ = try store.updateNamedTripManifest(folder: trip, title: "My Oxford story", oneDrivePicturesRoot: imported.session.archiveRoot, adding: [])
    let tripURL = trip.appendingPathComponent("\(trip.lastPathComponent).md")
    let text = try String(contentsOf: tripURL, encoding: .utf8)
    try (text + "\n\n## Memories\nCzech příběh; preserve this.").write(to: tripURL, atomically: true, encoding: .utf8)
    let moved = try WalkMover().moveWalk(at: old, to: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    let updated = try String(contentsOf: tripURL, encoding: .utf8)
    #expect(updated.hasPrefix("# My Oxford story"))
    #expect(updated.contains("Czech příběh; preserve this."))
    #expect(store.loadTripManifest(folder: trip, oneDrivePicturesRoot: imported.session.archiveRoot).startDate == imported.walkManifest.walkDate)
    let third = trip.deletingLastPathComponent().appendingPathComponent("11-November-Woodstock")
    _ = try WalkMover().moveWalk(at: moved.destinationFolder, to: third, oneDrivePicturesRoot: imported.session.archiveRoot)
    let empty = store.loadTripManifest(folder: trip, oneDrivePicturesRoot: imported.session.archiveRoot)
    #expect(empty.memberWalkFolderPaths.isEmpty)
    #expect(empty.startDate == nil)
    #expect(empty.title == "My Oxford story")
}

@Test func returnMovesAndSourcePathReuseDoNotRedirectOtherPhotoLogs() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let first = try await importedMoveFixture(root: root)
    let original = first.walkManifest.archiveFolder
    let secondTrip = original.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-Story")
    let moved = try WalkMover().moveWalk(at: original, to: secondTrip, oneDrivePicturesRoot: first.session.archiveRoot)
    let returned = try WalkMover().moveWalk(at: moved.destinationFolder, to: original.deletingLastPathComponent(), oneDrivePicturesRoot: first.session.archiveRoot)
    #expect(returned.destinationFolder == original)
    var reconciled = try ArchiveSessionPathReconciler().reconcile(first.session)
    #expect(reconciled.mediaItems[0].destinationURL?.deletingLastPathComponent() == original)
    #expect(try ArchiveSessionPathReconciler().reconcile(reconciled) == reconciled)
    _ = try WalkMover().moveWalk(at: original, to: secondTrip, oneDrivePicturesRoot: first.session.archiveRoot)
    let other = try await importedMoveFixture(root: root)
    #expect(other.walkManifest.archiveFolder == original)
    #expect(other.session.mediaItems[0].id != first.session.mediaItems[0].id)
    #expect(try ArchiveSessionPathReconciler().reconcile(other.session).mediaItems[0].destinationURL == other.session.mediaItems[0].destinationURL)
    reconciled = try ArchiveSessionPathReconciler().reconcile(first.session)
    #expect(reconciled.mediaItems[0].destinationURL?.deletingLastPathComponent() == moved.destinationFolder)
}

@Test func canonicalLookingNotesAndExternalCropSourceRemainUnchanged() throws {
    let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: "/archive/legacy", newAbsoluteFolderPath: "/archive/new",
        oldRelativeFolderPath: "legacy", newRelativeFolderPath: "new", oldStemBase: "02-Monday-Walk", newStemBase: "2020-03-02-walk")
    let notes = "archive_path: /archive/legacy/02-Monday-Walk-001.jpg\narchive_relative_path: legacy/02-Monday-Walk-001.jpg\ncompanion_archive_paths: /archive/legacy/a.raw\ncompanion_archive_relative_paths: legacy/a.raw"
    let photo = "---\narchive_path: \"/archive/legacy/02-Monday-Walk-001.jpg\"\n---\n\n" + notes
    let rewriter = ArchiveTextSidecarRewriter()
    let rewritten = try rewriter.rewriteStructured(photo, extension: "md", spec: spec)
    #expect(ArchiveManifestText.body(in: rewritten) == notes)
    let walkNotes = "## Imported Files\n- `camera.jpg` -> `/archive/legacy/example.jpg`\n\n## Source Report\nMy own source report."
    let walk = "# Walk\n- Archive folder: `/archive/legacy`\n\n## Notes\n\n" + walkNotes + "\n\n## Source Report\n\n- Total source files: 1\n\n## Imported Files\n\n- `camera.jpg` -> `/archive/legacy/photo.jpg`\n\n## Excluded Files\n"
    #expect(try rewriter.rewriteStructured(walk, extension: "md", spec: spec).contains(walkNotes))
    let crop = #"{"sourceMediaItemID":"id","sourcePath":"/camera/02-Monday-Walk-001.jpg","sourceFileName":"02-Monday-Walk-001.jpg","crops":[{"outputPath":"/archive/legacy/02-Monday-Walk-001-crop.jpg","outputFileName":"02-Monday-Walk-001-crop.jpg"}]}"#
    let object = try JSONSerialization.jsonObject(with: Data(rewriter.rewriteStructured(crop, extension: "json", spec: spec).utf8)) as! [String: Any]
    #expect(object["sourcePath"] as? String == "/camera/02-Monday-Walk-001.jpg")
    #expect(object["sourceFileName"] as? String == "02-Monday-Walk-001.jpg")
    #expect((object["crops"] as? [[String: Any]])?[0]["outputPath"] as? String == "/archive/new/2020-03-02-walk-001-crop.jpg")
}

@Test func missingWalkManifestAndUnreadableTripMemberNeverMutateExistingRecords() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    let historical = archive.appendingPathComponent("2020/03-March/02-Mon-Historical")
    try writeTestFile(historical.appendingPathComponent("photo.jpg"), contents: "original")
    #expect(throws: (any Error).self) { try WalkMover().moveWalk(at: historical, to: archive.appendingPathComponent("2020/03-March-Story"), oneDrivePicturesRoot: archive) }
    #expect(FileManager.default.fileExists(atPath: historical.appendingPathComponent("photo.jpg").path))
    let trip = archive.appendingPathComponent("2020/03-March-Existing")
    let original = TripManifest(tripID: UUID(), title: "Human title", folder: trip, folderRelativePath: "2020/03-March-Existing",
        startDate: Date(timeIntervalSince1970: 1_000_000_000), endDate: Date(), memberWalkFolderPaths: ["2020/03-March-Existing/unavailable"])
    let url = trip.appendingPathComponent("\(trip.lastPathComponent).md")
    try writeTestFile(url, contents: ManifestRenderer().renderTripManifest(original))
    let before = try Data(contentsOf: url)
    #expect(throws: (any Error).self) { try TripManifestStore().updateNamedTripManifest(folder: trip, title: nil, oneDrivePicturesRoot: archive, adding: []) }
    #expect(try Data(contentsOf: url) == before)
}

@Test func preparedMoveRevalidatesChangedDestinationBeforeAnyMutation() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await importedMoveFixture(root: root)
    let source = imported.walkManifest.archiveFolder
    let trip = source.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-Prepared")
    try FileManager.default.createDirectory(at: trip, withIntermediateDirectories: true)
    let destination = trip.appendingPathComponent(source.lastPathComponent)
    let operation = ArchiveFolderOperation(archiveRoot: imported.session.archiveRoot)
    let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: source.path, newAbsoluteFolderPath: destination.path)
    let record = try operation.prepare(source: source, destination: destination, spec: spec)
    let external = root.appendingPathComponent("external")
    try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
    try FileManager.default.removeItem(at: trip)
    try FileManager.default.createSymbolicLink(at: trip, withDestinationURL: external)
    #expect(throws: (any Error).self) { try operation.execute(record) }
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(try FileManager.default.contentsOfDirectory(at: external, includingPropertiesForKeys: nil).isEmpty)
}
