import Foundation
import Testing
@testable import PhotoDiaryTriage

private func locationFixture(_ root: URL, count: Int = 3) async throws -> ImportResult {
    let source = root.appendingPathComponent("source"), archive = root.appendingPathComponent("archive")
    let items = try (0..<count).map { number in
        let name = "gps\(number).jpg"
        try writeTestFile(source.appendingPathComponent(name), contents: "untouched original \(number)")
        var item = makeTestMediaItem(sourceRoot: source, fileName: name,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(number)), selectionState: .included)
        item.metadata.latitude = 50 + Double(number); item.metadata.longitude = 14 + Double(number)
        return item
    }
    return try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: archive, items: items))
}

private func locationTarget(_ result: ImportResult, selected: [Int] = []) throws -> ArchiveLocationTarget {
    let walk = result.walkManifest
    return ArchiveLocationTarget(walkRelativePath: try #require(walk.archiveFolderRelativePath),
        sessionID: walk.sessionID, walkID: walk.walkID,
        photos: try selected.map { index in
            ArchiveLocationPhotoTarget(mediaItemID: result.fileManifests[index].mediaItemID,
                archiveRelativePath: try #require(result.fileManifests[index].archiveRelativePath))
        })
}

private func locationPhotoText(_ result: ImportResult, index: Int) throws -> String {
    try String(contentsOf: URL(fileURLWithPath: result.fileManifests[index].archivePath)
        .deletingPathExtension().appendingPathExtension("md"), encoding: .utf8)
}

private final class LocationFailingWriter: @unchecked Sendable {
    let lock = NSLock()
    var count = 0
    func write(_ text: String, at url: URL) throws {
        let current = lock.withLock { count += 1; return count }
        if current == 2 { throw CocoaError(.fileWriteOutOfSpace) }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}

@Test func selectedLocationRoundTripPreservesGPSNotesAndUnknownFields() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot
    let firstURL = URL(fileURLWithPath: imported.fileManifests[0].archivePath).deletingPathExtension().appendingPathExtension("md")
    var before = try locationPhotoText(imported, index: 0)
    before = ArchiveManifestText.settingScalar("human_custom", to: "retain \"this\"", in: before)
    before += "\nA human paragraph with location_override_name: inside the prose."
    try before.write(to: firstURL, atomically: true, encoding: .utf8)
    let untouched = try locationPhotoText(imported, index: 2)
    let point = try #require(ArchiveCoordinate(latitude: 51.84, longitude: -1.36))
    let result = try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [0, 1]), name: "Blenheim Park", coordinate: point, archiveRoot: archive)
    let first = try locationPhotoText(imported, index: 0), second = try locationPhotoText(imported, index: 1)
    #expect(ArchiveManifestText.scalar("latitude", in: first) == ArchiveManifestText.scalar("latitude", in: before))
    #expect(ArchiveManifestText.scalar("longitude", in: first) == ArchiveManifestText.scalar("longitude", in: before))
    #expect(ArchiveManifestText.scalar("human_custom", in: first) == "retain \"this\"")
    #expect(ArchiveManifestText.body(in: first) == ArchiveManifestText.body(in: before))
    #expect(try locationPhotoText(imported, index: 2) == untouched)
    let assignment = try #require(try PhotoLocationOverride.read(in: first))
    #expect(assignment.coordinate == point && assignment.isShared)
    #expect(try PhotoLocationOverride.read(in: second)?.assignmentID == assignment.assignmentID)
    #expect(result.photoOverride?.assignmentID == assignment.assignmentID)
    let loaded = try #require(try ArchiveIndexStore().loadWalkManifest(folder: imported.walkManifest.archiveFolder, archiveRoot: archive))
    #expect(loaded.importedFiles.first(where: { $0.mediaItemID == imported.fileManifests[0].mediaItemID })?.locationOverride == assignment)
    let rendered = ManifestRenderer().renderFileManifest(try #require(loaded.importedFiles.first { $0.mediaItemID == imported.fileManifests[0].mediaItemID }))
    #expect(try PhotoLocationOverride.read(in: rendered) == assignment)
    let movedRoot = root.appendingPathComponent("relocated")
    try FileManager.default.moveItem(at: archive, to: movedRoot)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: movedRoot)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: movedRoot)
    let row = try #require(rows.first { $0.mediaItemID == imported.fileManifests[0].mediaItemID && $0.kind == .photo })
    #expect(row.gpsLatitude == imported.fileManifests[0].latitude)
    #expect(row.latitude == point.latitude && row.coordinateSource == .sharedOverride)
}

@Test func clearAndReassignRestoreWalkThenRawGPSFallback() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot, editor = ArchiveLocationEditor()
    let pin = ArchiveCoordinate(latitude: 52, longitude: -2)!, override = ArchiveCoordinate(latitude: 53, longitude: -3)!
    _ = try editor.save(target: locationTarget(imported), name: "Walk place", coordinate: pin, archiveRoot: archive)
    _ = try editor.save(target: locationTarget(imported, selected: [0, 1]), name: "Shared place", coordinate: override, archiveRoot: archive)
    let shared = try #require(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 1)))
    _ = try editor.save(target: locationTarget(imported, selected: [0]), name: "Individual place", coordinate: pin, archiveRoot: archive)
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 0))?.assignmentID != shared.assignmentID)
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 1)) == shared)
    _ = try editor.save(target: locationTarget(imported, selected: [0]), name: "", coordinate: nil, archiveRoot: archive)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    var row = try #require(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).first { $0.mediaItemID == imported.fileManifests[0].mediaItemID })
    #expect(row.latitude == pin.latitude && row.coordinateSource == .walkPin)
    #expect(row.gpsLatitude == imported.fileManifests[0].latitude)
    _ = try editor.save(target: locationTarget(imported), name: "", coordinate: nil, archiveRoot: archive)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    row = try #require(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).first { $0.mediaItemID == imported.fileManifests[0].mediaItemID })
    #expect(row.latitude == row.gpsLatitude && row.coordinateSource == .photoGPS)
    #expect(row.location == nil)
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 0)) == nil)
}

@Test func invalidLocationOverrideAndHistoricalTargetsFailBeforeMutation() async throws {
    for text in ["location_override_latitude: 50", "location_override_latitude: nan\nlocation_override_longitude: 14", "location_override_name: place"] {
        #expect(throws: (any Error).self) { try PhotoLocationOverride.read(in: "---\n\(text)\n---\n\nNotes") }
    }
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let before = try locationPhotoText(imported, index: 0)
    var target = try locationTarget(imported, selected: [0, 1]); target.photos[1] = ArchiveLocationPhotoTarget(mediaItemID: UUID(), archiveRelativePath: target.photos[1].archiveRelativePath)
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().save(target: target, name: "Place", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: imported.session.archiveRoot) }
    #expect(try locationPhotoText(imported, index: 0) == before)
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [0]), name: "Only a label", coordinate: nil, archiveRoot: imported.session.archiveRoot) }
    let historical = imported.session.archiveRoot.appendingPathComponent("2000/Old photos")
    try writeTestFile(historical.appendingPathComponent("photo.jpg"), contents: "historical")
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().save(target: ArchiveLocationTarget(walkRelativePath: "2000/Old photos"), name: "Place", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: imported.session.archiveRoot) }
}

@Test func interruptedSharedLocationResumesWithSameIdentityAndBlocksMove() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let writer = LocationFailingWriter(), target = try locationTarget(imported, selected: [0, 1, 2])
    let editor = ArchiveLocationEditor(writeText: { try writer.write($0, at: $1) })
    #expect(throws: (any Error).self) { try editor.save(target: target, name: "Shared", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: imported.session.archiveRoot) }
    let savedID = try #require(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 0))) .assignmentID
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 1)) == nil)
    #expect(throws: (any Error).self) { try ArchiveLocationEditor.assertNoPending(overlapping: imported.walkManifest.archiveFolder, archiveRoot: imported.session.archiveRoot) }
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [2]), name: "Other", coordinate: ArchiveCoordinate(latitude: 52, longitude: -2), archiveRoot: imported.session.archiveRoot) }
    let result = try ArchiveLocationEditor().resume(walkRelativePath: target.walkRelativePath, archiveRoot: imported.session.archiveRoot)
    #expect(result.photoOverride?.assignmentID == savedID)
    for index in 0..<3 { #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: index))?.assignmentID == savedID) }
    try ArchiveLocationEditor.assertNoPending(overlapping: imported.walkManifest.archiveFolder, archiveRoot: imported.session.archiveRoot)
}

@Test func locationRecoveryConflictPreflightsEntireBatchAndRetainsHumanEdit() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let writer = LocationFailingWriter(), target = try locationTarget(imported, selected: [0, 1, 2])
    #expect(throws: (any Error).self) { try ArchiveLocationEditor(writeText: { try writer.write($0, at: $1) }).save(target: target, name: "Shared", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: imported.session.archiveRoot) }
    let second = try locationPhotoText(imported, index: 1)
    let thirdURL = URL(fileURLWithPath: imported.fileManifests[2].archivePath).deletingPathExtension().appendingPathExtension("md")
    let edited = try locationPhotoText(imported, index: 2) + "\nA new human note."
    try edited.write(to: thirdURL, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().resume(walkRelativePath: target.walkRelativePath, archiveRoot: imported.session.archiveRoot) }
    #expect(try locationPhotoText(imported, index: 1) == second)
    #expect(try locationPhotoText(imported, index: 2) == edited)
}

@Test func manualPhotoLocationsDriveIndexOnlyCentroidWithExplicitProvenance() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root, count: 2)
    _ = try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [0, 1]), name: "Manual", coordinate: ArchiveCoordinate(latitude: 10, longitude: 179), archiveRoot: imported.session.archiveRoot)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    let travel = root.appendingPathComponent("travel"); try AppDirectories.ensureExists(travel)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: imported.session.archiveRoot), to: ArchiveIndexStore.indexRoot(for: travel))
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: travel, supportedExtensions: ["jpg"], machineRole: .travel)
    let map = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: catalogue.entries, searchQuery: "", matchingPaths: [])
    #expect(map.locatedWalks.first?.coordinateSource == .photoCentroid)
    #expect(abs(try #require(map.locatedWalks.first?.coordinate).longitude - 179) < 0.001)
    #expect(catalogue.photos.allSatisfy { $0.locationOverride?.isShared == true && $0.gpsLatitude != nil })
}

@MainActor
@Test(arguments: [ArchiveMachineRole.mainArchive, .travel])
func archiveContextLocationTargetsSelectionWithoutTouchingLoadedLogOrTravelIndex(role: ArchiveMachineRole) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: archive, supportedExtensions: ["jpg"], machineRole: .travel)
    var settings = makeTestSettings(root: root); settings.archiveRoot = archive; settings.oneDrivePicturesRoot = archive; settings.archiveMachineRole = role
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    var unrelated = imported.session; unrelated.walkMetadata.location = "Unrelated log"; unrelated.walkMetadata.latitude = 70; unrelated.walkMetadata.longitude = 80
    state.currentSession = unrelated
    state.testingInstallArchiveCatalogue(catalogue)
    let map = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: catalogue.entries, searchQuery: "", matchingPaths: [])
    state.openArchiveMapWalk(try #require(map.walks.first))
    for _ in 0..<100 where state.visibleMediaItems.count != 3 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(state.locationAssignmentContext?.title == "This Walk")
    #expect(state.locationAssignmentContext?.name != "Unrelated log")
    let indexBefore = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
    await state.saveContextLocation(name: "Walk pin", latitude: 52, longitude: -2)
    #expect(state.currentSession == unrelated)
    #expect(state.locationAssignmentContext?.coordinate == ArchiveCoordinate(latitude: 52, longitude: -2))
    state.selectedMediaItemIDs = [imported.session.mediaItems[0].id, imported.session.mediaItems[1].id]
    let captured = try #require(state.locationAssignmentContext)
    #expect(captured.title == "2 selected photos")
    state.selectedMediaItemIDs = [imported.session.mediaItems[2].id]
    #expect(state.locationAssignmentKey != captured.key)
    await state.saveContextLocation(name: "Selected group", latitude: 53, longitude: -3, context: captured)
    #expect(!state.statusMessage.hasPrefix("Location save failed"), Comment(rawValue: state.statusMessage))
    #expect(state.currentSession == unrelated)
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 0))?.isShared == true)
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 1))?.isShared == true)
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 2)) == nil)
    #expect(state.visibleMediaItems.first { $0.id == imported.session.mediaItems[0].id }?.metadata.latitude == 53)
    if role == .travel {
        #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive) == indexBefore)
    } else {
        for _ in 0..<100 {
            let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
            if rows.filter({ $0.kind == .photo && $0.latitude == 53 }).count == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).filter { $0.kind == .photo && $0.latitude == 53 }.count == 2)
    }
    state.selectedMediaItemIDs = [imported.session.mediaItems[0].id, imported.session.mediaItems[2].id]
    #expect(state.locationAssignmentContext?.isMixed == true)
    #expect(state.locationAssignmentContext?.coordinate == nil)
    let policy = ArchiveByteReadPolicy(archiveRoot: archive, machineRole: .travel)
    #expect(imported.session.mediaItems.allSatisfy { !policy.canReadBytes(at: $0.destinationURL!) })
}

@Test func legacyLocationRecoveryCapturesCanonicalIdentityAndRejectsReplacedWalk() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot
    var target = try locationTarget(imported, selected: [0, 1]); target.sessionID = nil; target.walkID = nil
    let writer = LocationFailingWriter()
    #expect(throws: (any Error).self) { try ArchiveLocationEditor(writeText: { try writer.write($0, at: $1) }).save(target: target, name: "Shared", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: archive) }
    let pending = try #require(try ArchiveLocationEditor().pending(for: target.walkRelativePath, archiveRoot: archive))
    #expect(pending.target.sessionID == imported.walkManifest.sessionID)
    #expect(pending.target.walkID == imported.walkManifest.walkID)
    let url = imported.walkManifest.archiveFolder.appendingPathComponent(imported.walkManifest.archiveFolder.lastPathComponent + ".md")
    var text = try String(contentsOf: url, encoding: .utf8)
    text = text.replacingOccurrences(of: imported.walkManifest.sessionID.uuidString, with: UUID().uuidString)
    try text.write(to: url, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().resume(walkRelativePath: target.walkRelativePath, archiveRoot: archive) }
    #expect(try PhotoLocationOverride.read(in: locationPhotoText(imported, index: 1)) == nil)
}

@Test func locationRecoveryUsesRelativePathsAfterArchiveRelocationAndRetainsOldIndexUntilComplete() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let before = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
    let target = try locationTarget(imported, selected: [0, 1, 2]), writer = LocationFailingWriter()
    #expect(throws: (any Error).self) { try ArchiveLocationEditor(writeText: { try writer.write($0, at: $1) }).save(target: target, name: "Shared", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: archive) }
    #expect(throws: (any Error).self) { try ArchiveIndexStore().rebuildIndex(archiveRoot: archive) }
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive) == before)
    let relocated = root.appendingPathComponent("relocated")
    try FileManager.default.moveItem(at: archive, to: relocated)
    _ = try ArchiveLocationEditor().resume(walkRelativePath: target.walkRelativePath, archiveRoot: relocated)
    for photo in target.photos {
        let url = relocated.appendingPathComponent(photo.archiveRelativePath).deletingPathExtension().appendingPathExtension("md")
        #expect(try PhotoLocationOverride.read(in: String(contentsOf: url, encoding: .utf8))?.coordinate == ArchiveCoordinate(latitude: 51, longitude: -1))
    }
    try ArchiveIndexStore().rebuildIndex(archiveRoot: relocated)
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: relocated).filter { $0.kind == .photo }.allSatisfy { $0.coordinateSource == .sharedOverride })
}

@Test func unfinishedMovesBlockLocationSavesAndResumedMovesCheckLocationRecovery() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot, source = imported.walkManifest.archiveFolder
    let destination = source.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-Other/" + source.lastPathComponent)
    let operation = ArchiveFolderOperation(archiveRoot: archive)
    let record = ArchiveFolderRecoveryRecord(source: source, destination: destination, renames: [], changes: [],
        canonicalWalkSessionID: imported.walkManifest.sessionID, canonicalWalkID: imported.walkManifest.walkID)
    try ArchiveOperationRecovery(archiveRoot: archive).save(record, kind: "folder", sessionID: operation.id(for: source))
    let before = try locationPhotoText(imported, index: 0)
    #expect(throws: (any Error).self) { try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [0]), name: "Place", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: archive) }
    #expect(try locationPhotoText(imported, index: 0) == before)
    try operation.complete(record)
    let writer = LocationFailingWriter(), target = try locationTarget(imported, selected: [0, 1])
    #expect(throws: (any Error).self) { try ArchiveLocationEditor(writeText: { try writer.write($0, at: $1) }).save(target: target, name: "Shared", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: archive) }
    #expect(throws: (any Error).self) { try operation.execute(record) }
    #expect(FileManager.default.fileExists(atPath: source.path))
    #expect(!FileManager.default.fileExists(atPath: destination.path))
}

@Test func completedPhotoAssignmentSurvivesWalkMoveAndCanonicalRebuild() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await locationFixture(root)
    let archive = imported.session.archiveRoot
    let assignment = try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [0, 1]), name: "Moved place", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: archive)
    let trip = imported.walkManifest.archiveFolder.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("11-November-New")
    try AppDirectories.ensureExists(trip)
    let moved = try WalkMover().moveWalk(at: imported.walkManifest.archiveFolder, to: trip, oneDrivePicturesRoot: archive, archiveRoot: archive)
    let walk = try #require(try ArchiveIndexStore().loadWalkManifest(folder: moved.destinationFolder, archiveRoot: archive))
    #expect(walk.importedFiles.filter { $0.locationOverride != nil }.count == 2)
    #expect(walk.importedFiles.first { $0.mediaItemID == imported.fileManifests[0].mediaItemID }?.locationOverride?.assignmentID == assignment.photoOverride?.assignmentID)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).filter { $0.coordinateSource == .sharedOverride }.count == 2)
}

@MainActor
@Test func cropLocationsInheritOriginalAssignmentAndRemainReadOnly() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source"), archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("keeper.jpg"))
    var item = makeTestMediaItem(sourceRoot: source, fileName: "keeper.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included)
    item.metadata.latitude = 50; item.metadata.longitude = 14
    let imported = try await ImportCoordinator().commit(session: makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item]))
    var original = imported.session.mediaItems[0]; original.sourceURL = original.destinationURL!
    _ = try CropService().crop(item: original, normalizedRect: CropNormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5), trigger: .manualDrag)
    _ = try ArchiveLocationEditor().save(target: locationTarget(imported, selected: [0]), name: "Manual", coordinate: ArchiveCoordinate(latitude: 51, longitude: -1), archiveRoot: archive)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    var settings = makeTestSettings(root: root); settings.archiveMachineRole = .travel
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: archive, supportedExtensions: ["jpg"], machineRole: .travel)
    let crop = try #require(catalogue.photos.first { $0.isDerivedPhoto })
    #expect(crop.locationOverride?.coordinate == ArchiveCoordinate(latitude: 51, longitude: -1))
    #expect(crop.gpsLatitude == 50 && crop.coordinateSource == .photoOverride)
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    state.testingInstallArchiveCatalogue(catalogue)
    let map = ArchiveMapProjection.snapshot(catalogue: catalogue, visibleEntries: catalogue.entries, searchQuery: "", matchingPaths: [])
    state.openArchiveMapWalk(try #require(map.walks.first))
    for _ in 0..<100 where state.visibleMediaItems.count != 2 { try await Task.sleep(for: .milliseconds(10)) }
    state.selectedMediaItemIDs = [try #require(crop.mediaItemID)]
    #expect(state.locationAssignmentContext == nil)
    let before = try locationPhotoText(imported, index: 0)
    await state.saveContextLocation(name: "Wrong crop target", latitude: 60, longitude: 0)
    #expect(try locationPhotoText(imported, index: 0) == before)
    state.selectedMediaItemIDs = [original.id]
    await state.saveContextLocation(name: "", latitude: nil, longitude: nil)
    #expect(state.visibleMediaItems.allSatisfy { $0.metadata.latitude == 50 && $0.metadata.longitude == 14 })
}
