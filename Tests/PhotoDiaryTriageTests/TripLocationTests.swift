import Foundation
import Testing
@testable import PhotoDiaryTriage

private func tripFixture(_ root: URL, day: Int = 0, title: String = "Morning", named: String? = nil) async throws -> ImportResult {
    let source = root.appendingPathComponent("source-\(day)-\(title)")
    try writeTestFile(source.appendingPathComponent("IMG_0001.jpg"), contents: "photo-\(day)-\(title)")
    let item = makeTestMediaItem(sourceRoot: source, fileName: "IMG_0001.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day * 86_400)), selectionState: .included)
    var session = makeTestSession(sourceRoot: source, archiveRoot: root.appendingPathComponent("archive"), items: [item], title: title, location: "Oxford")
    if let named {
        session.proposedWalks = [Walk(title: title, date: item.capturedAt!, mediaItemIDs: [item.id], tripTarget: TripTarget(kind: .newNamedTrip, title: named, folderRelativePath: nil), location: "Oxford")]
    }
    return try await ImportCoordinator().commit(session: session)
}
private func tripTarget(_ trip: TripManifest) -> TripLocationTarget {
    TripLocationTarget(relativePath: trip.folderRelativePath!, tripID: trip.tripID, expectedOverride: trip.locationLabelOverride)
}
private func tripManifestURL(_ trip: TripManifest) -> URL { trip.folder.appendingPathComponent(trip.folder.lastPathComponent + ".md") }

@Test(arguments: [false, true])
func tripLabelRoundTripClearPreservesIdentityNotesCoordinatesAndIndex(_ named: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await tripFixture(root, named: named ? "Holiday" : nil)
    let trip = try #require(imported.tripManifests.first)
    let url = tripManifestURL(trip)
    let custom = try String(contentsOf: url, encoding: .utf8) + "\n\n## Notes\n\nKeep my Czech notes: Příbram.\n\n## Custom\n\n- Unknown: unchanged\n"
    try custom.write(to: url, atomically: true, encoding: .utf8)
    let walkText = try String(contentsOf: imported.walkManifest.archiveFolder.appendingPathComponent(imported.walkManifest.archiveFolder.lastPathComponent + ".md"), encoding: .utf8)
    let label = #"Český ráj "north" \ lane"#
    let saved = try TripLocationEditor().save(target: tripTarget(trip), label: label, archiveRoot: imported.session.archiveRoot)
    #expect(saved.tripID == trip.tripID)
    #expect(saved.locationLabelOverride == label)
    let text = try String(contentsOf: url, encoding: .utf8)
    #expect(text.contains("Keep my Czech notes: Příbram."))
    #expect(text.contains("- Unknown: unchanged"))
    #expect(try String(contentsOf: imported.walkManifest.archiveFolder.appendingPathComponent(imported.walkManifest.archiveFolder.lastPathComponent + ".md"), encoding: .utf8) == walkText)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: imported.session.archiveRoot)
    let row = try #require(rows.first { $0.kind == .trip })
    #expect(row.tripID == trip.tripID && row.tripLocationOverride == label)
    let clear = try TripLocationEditor().save(target: tripTarget(saved), label: nil, archiveRoot: imported.session.archiveRoot)
    #expect(clear.locationLabelOverride == nil)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: imported.session.archiveRoot, supportedExtensions: ["jpg"])
    #expect(catalogue.entries.first { $0.kind == .trip }?.location == "Oxford")
}

@Test func tripFirstMonthRecordDiscoversOldMembersAndAppendMovePreserveLabels() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await tripFixture(root)
    let trip = try #require(first.tripManifests.first)
    try FileManager.default.removeItem(at: tripManifestURL(trip))
    let second = try await tripFixture(root, day: 1, title: "Evening")
    let rebuilt = try #require(second.tripManifests.first)
    #expect(rebuilt.memberWalkFolderPaths.count == 2)
    let saved = try TripLocationEditor().save(target: tripTarget(rebuilt), label: "Home month", archiveRoot: first.session.archiveRoot)
    let third = try await tripFixture(root, day: 2, title: "Afternoon")
    let appended = try #require(third.tripManifests.first)
    #expect(appended.tripID == saved.tripID && appended.locationLabelOverride == "Home month")
    #expect(appended.memberWalkFolderPaths.count == 3)
    let named = try await tripFixture(root, day: 3, title: "Arrival", named: "Holiday")
    let namedTrip = try #require(named.tripManifests.first)
    let namedSaved = try TripLocationEditor().save(target: tripTarget(namedTrip), label: "Holiday label", archiveRoot: first.session.archiveRoot)
    let moved = try WalkMover().moveWalk(at: first.walkManifest.archiveFolder, to: namedTrip.folder, oneDrivePicturesRoot: first.session.archiveRoot)
    let sourceAfter = TripManifestStore().loadTripManifest(folder: trip.folder, oneDrivePicturesRoot: first.session.archiveRoot)
    let destinationAfter = TripManifestStore().loadTripManifest(folder: namedTrip.folder, oneDrivePicturesRoot: first.session.archiveRoot)
    #expect(sourceAfter.tripID == saved.tripID && sourceAfter.locationLabelOverride == "Home month")
    #expect(sourceAfter.memberWalkFolderPaths.count == 2)
    #expect(destinationAfter.tripID == namedSaved.tripID && destinationAfter.locationLabelOverride == "Holiday label")
    #expect(destinationAfter.memberWalkFolderPaths.contains { $0.hasSuffix(moved.destinationFolder.lastPathComponent) })
    let relocated = root.appendingPathComponent("relocated")
    try FileManager.default.moveItem(at: first.session.archiveRoot, to: relocated)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: relocated)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: relocated)
    #expect(rows.contains { $0.kind == .trip && $0.tripID == saved.tripID && $0.tripLocationOverride == "Home month" })
}

@Test func tripLabelRejectsStaleIdentityConflictingLabelsAndInvalidText() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await tripFixture(root)
    let trip = try #require(imported.tripManifests.first), editor = TripLocationEditor()
    let saved = try editor.save(target: tripTarget(trip), label: "Current", archiveRoot: imported.session.archiveRoot)
    #expect(throws: (any Error).self) { try editor.save(target: tripTarget(trip), label: "Stale overwrite", archiveRoot: imported.session.archiveRoot) }
    #expect(throws: (any Error).self) { try editor.save(target: TripLocationTarget(relativePath: trip.folderRelativePath!, tripID: UUID(), expectedOverride: "Current"), label: "Other", archiveRoot: imported.session.archiveRoot) }
    #expect(throws: (any Error).self) { try editor.save(target: tripTarget(saved), label: "Line\nTwo", archiveRoot: imported.session.archiveRoot) }
    let url = tripManifestURL(trip), original = try String(contentsOf: url, encoding: .utf8)
    let duplicate = original.replacingOccurrences(of: "## Member Walks", with: "- Location label override: \"Duplicate\"\n\n## Member Walks")
    try duplicate.write(to: url, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try editor.save(target: tripTarget(saved), label: "Other", archiveRoot: imported.session.archiveRoot) }
    #expect(try String(contentsOf: url, encoding: .utf8) == duplicate)
}

@Test func tripLabelRejectsHistoricalFoldersAndEscapingLinks() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive"), historical = archive.appendingPathComponent("1987/old")
    try writeTestFile(historical.appendingPathComponent("photo.jpg"))
    #expect(throws: (any Error).self) { try TripLocationEditor().save(target: TripLocationTarget(relativePath: "1987/old", tripID: nil, expectedOverride: nil), label: "No promotion", archiveRoot: archive) }
    let outside = root.appendingPathComponent("outside"); try AppDirectories.ensureExists(outside)
    try FileManager.default.createSymbolicLink(at: archive.appendingPathComponent("escape"), withDestinationURL: outside)
    #expect(throws: (any Error).self) { try TripLocationEditor().save(target: TripLocationTarget(relativePath: "escape", tripID: nil, expectedOverride: nil), label: "No escape", archiveRoot: archive) }
}

@Test func tripAtomicFailureRetainsTextAndRetryAfterWrittenResponseFailureIsIdempotent() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await tripFixture(root), trip = try #require(imported.tripManifests.first)
    let url = tripManifestURL(trip), original = try String(contentsOf: url, encoding: .utf8)
    let fail = TripLocationEditor(writeText: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
    #expect(throws: (any Error).self) { try fail.save(target: tripTarget(trip), label: "Saved", archiveRoot: imported.session.archiveRoot) }
    #expect(try String(contentsOf: url, encoding: .utf8) == original)
    let afterWriteFailure = TripLocationEditor(writeText: { text, url in try text.write(to: url, atomically: true, encoding: .utf8); throw CocoaError(.fileWriteUnknown) })
    #expect(throws: (any Error).self) { try afterWriteFailure.save(target: tripTarget(trip), label: "Saved", archiveRoot: imported.session.archiveRoot) }
    let retried = try TripLocationEditor().save(target: tripTarget(trip), label: "Saved", archiveRoot: imported.session.archiveRoot)
    #expect(retried.tripID == trip.tripID && retried.locationLabelOverride == "Saved")
}

@MainActor @Test(arguments: [ArchiveMachineRole.mainArchive, .travel])
func tripAppStateSavesCapturedTargetAndTravelLeavesIndexAndBytesBlocked(_ role: ArchiveMachineRole) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await tripFixture(root), second = try await tripFixture(root, day: 1, named: "Elsewhere")
    try ArchiveIndexStore().rebuildIndex(archiveRoot: first.session.archiveRoot)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: first.session.archiveRoot, supportedExtensions: ["jpg"], machineRole: role)
    let before = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: first.session.archiveRoot)
    var settings = makeTestSettings(root: root); settings.archiveMachineRole = role
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    state.testingInstallArchiveCatalogue(catalogue)
    let firstEntry = try #require(catalogue.entries.first { $0.archiveRelativePath == first.tripManifests[0].folderRelativePath })
    let secondEntry = try #require(catalogue.entries.first { $0.archiveRelativePath == second.tripManifests[0].folderRelativePath })
    let target = try #require(state.tripLocationTarget(for: firstEntry))
    state.selectArchiveEntry(secondEntry.id); state.openSelectedArchiveItem()
    await state.saveTripLocationLabel("Captured first Trip", target: target, archiveRoot: first.session.archiveRoot)
    #expect(state.archiveBrowserState.snapshot.selectedTrip?.archiveRelativePath == secondEntry.archiveRelativePath)
    #expect(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: first.session.archiveRoot).locationLabelOverride == "Captured first Trip")
    #expect(TripManifestStore().loadTripManifest(folder: second.tripManifests[0].folder, oneDrivePicturesRoot: first.session.archiveRoot).locationLabelOverride == nil)
    if role == .travel {
        #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: first.session.archiveRoot) == before)
        #expect(!ArchiveByteReadPolicyContext.shared.canReadBytes(at: first.session.mediaItems[0].destinationURL!))
    } else {
        #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: first.session.archiveRoot).contains { $0.kind == .trip && $0.tripLocationOverride == "Captured first Trip" })
    }
}

private func legacyLabelledTrip(_ root: URL) async throws -> (TripManifest, URL) {
    let imported = try await tripFixture(root)
    let archive = imported.session.archiveRoot
    let legacyTrip = archive.appendingPathComponent("2023/11 - November")
    let legacyWalk = legacyTrip.appendingPathComponent("14-Tuesday-Old-walk")
    let oldWalk = imported.walkManifest.archiveFolder
    let resolver = ArchiveRelativePathResolver(root: archive)
    let operation = ArchiveFolderOperation(archiveRoot: archive)
    let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: oldWalk.path, newAbsoluteFolderPath: legacyWalk.path,
        oldRelativeFolderPath: resolver.relativePath(for: oldWalk), newRelativeFolderPath: resolver.relativePath(for: legacyWalk),
        oldTripRelativePath: resolver.relativePath(for: oldWalk.deletingLastPathComponent()), newTripRelativePath: resolver.relativePath(for: legacyTrip))
    let record = try operation.prepare(source: oldWalk, destination: legacyWalk, spec: spec,
        names: [oldWalk.lastPathComponent + ".md": legacyWalk.lastPathComponent + ".md", oldWalk.lastPathComponent + "-session-log.jsonl": legacyWalk.lastPathComponent + "-session-log.jsonl"])
    _ = try operation.execute(record); try operation.complete(record)
    try FileManager.default.removeItem(at: tripManifestURL(imported.tripManifests[0]))
    let trip = try TripManifestStore().updateNamedTripManifest(folder: legacyTrip, title: "Legacy chronicle", oneDrivePicturesRoot: archive, adding: [])
    let url = tripManifestURL(trip)
    let text = try String(contentsOf: url, encoding: .utf8) + "\n\n## Notes\n\nKeep these old paths as prose: 2023/11 - November.\n\n## Unknown\n\nUntouched.\n"
    try text.write(to: url, atomically: true, encoding: .utf8)
    return (try TripLocationEditor().save(target: tripTarget(trip), label: "Legacy label", archiveRoot: archive), archive)
}

@Test func tripLegacyMigrationPreservesLabelIdentityMembershipAndHumanText() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (trip, archive) = try await legacyLabelledTrip(root)
    let migrator = ArchiveLayoutMigrator(), plan = migrator.plan(archiveRoot: archive)
    #expect(plan.walks.count == 1)
    let result = migrator.execute(plan)
    #expect(result.failures.isEmpty)
    let moved = TripManifestStore().loadTripManifest(folder: archive.appendingPathComponent("2023/11-November"), oneDrivePicturesRoot: archive)
    #expect(moved.tripID == trip.tripID && moved.locationLabelOverride == "Legacy label")
    #expect(moved.memberWalkFolderPaths == ["2023/11-November/14-Tue-Old-walk"])
    let text = try String(contentsOf: tripManifestURL(moved), encoding: .utf8)
    #expect(text.contains("Keep these old paths as prose: 2023/11 - November."))
    #expect(text.contains("Untouched."))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive).contains { $0.kind == .trip && $0.tripID == trip.tripID && $0.tripLocationOverride == "Legacy label" })
}

private final class TripManifestRemovalFailure: FileManager, @unchecked Sendable {
    override func removeItem(at url: URL) throws {
        if url.lastPathComponent == "11 - November.md" { throw CocoaError(.fileWriteNoPermission) }
        try super.removeItem(at: url)
    }
}

@Test func tripMigrationResumesManifestTransferAndBlocksConflictingLabelOrIndexWork() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (trip, archive) = try await legacyLabelledTrip(root)
    let migrator = ArchiveLayoutMigrator(fileManager: TripManifestRemovalFailure())
    let result = migrator.execute(migrator.plan(archiveRoot: archive))
    #expect(!result.failures.isEmpty)
    #expect(FileManager.default.fileExists(atPath: tripManifestURL(trip).path))
    #expect(throws: (any Error).self) { try TripLocationEditor().save(target: tripTarget(trip), label: "Conflicting", archiveRoot: archive) }
    #expect(throws: (any Error).self) { try ArchiveIndexStore().rebuildIndex(archiveRoot: archive) }
    let destination = archive.appendingPathComponent("2023/11-November")
    let destinationManifest = destination.appendingPathComponent("11-November.md")
    let before = try String(contentsOf: destinationManifest, encoding: .utf8)
    let source = root.appendingPathComponent("blocked-source")
    try writeTestFile(source.appendingPathComponent("new.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "new.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included)
    let session = makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item], title: "Blocked append")
    await #expect(throws: (any Error).self) { try await ImportCoordinator().commit(session: session) }
    #expect(try ArchiveOperationRecovery(archiveRoot: archive).load(ImportRecoveryRecord.self, kind: "import", sessionID: session.id) == nil)
    let unrelated = try await tripFixture(root, day: 3, title: "Unrelated", named: "Other Trip")
    #expect(throws: (any Error).self) { try WalkMover().moveWalk(at: unrelated.walkManifest.archiveFolder, to: destination, oneDrivePicturesRoot: archive) }
    #expect(throws: (any Error).self) { try WalkMover().moveWalk(at: archive.appendingPathComponent("2023/11-November/14-Tue-Old-walk"), to: unrelated.tripManifests[0].folder, oneDrivePicturesRoot: archive) }
    #expect(try String(contentsOf: destinationManifest, encoding: .utf8) == before)
    #expect(FileManager.default.fileExists(atPath: unrelated.walkManifest.archiveFolder.path))
    let retry = ArchiveLayoutMigrator(), resumed = retry.execute(retry.plan(archiveRoot: archive))
    #expect(resumed.failures.isEmpty)
    let moved = TripManifestStore().loadTripManifest(folder: archive.appendingPathComponent("2023/11-November"), oneDrivePicturesRoot: archive)
    #expect(moved.tripID == trip.tripID && moved.locationLabelOverride == "Legacy label")
    #expect(!FileManager.default.fileExists(atPath: tripManifestURL(trip).path))
}

@Test func tripMigrationRefusesOccupiedCanonicalDestinationBeforeMovingWalks() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (trip, archive) = try await legacyLabelledTrip(root)
    let occupied = try TripManifestStore().updateNamedTripManifest(folder: archive.appendingPathComponent("2023/11-November"), title: "Other Trip", oneDrivePicturesRoot: archive, adding: [])
    let before = try String(contentsOf: tripManifestURL(occupied), encoding: .utf8)
    let migrator = ArchiveLayoutMigrator(), result = migrator.execute(migrator.plan(archiveRoot: archive))
    #expect(!result.failures.isEmpty && result.migratedWalks == 0)
    #expect(try String(contentsOf: tripManifestURL(occupied), encoding: .utf8) == before)
    #expect(FileManager.default.fileExists(atPath: archive.appendingPathComponent(trip.memberWalkFolderPaths[0]).path))
}

@Test func tripSyntheticMonthLabelCreatesStableCanonicalMembersAndFreshTravelReadsOnlyIndex() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await tripFixture(root), second = try await tripFixture(root, day: 1, title: "Second")
    let trip = try #require(second.tripManifests.first)
    try FileManager.default.removeItem(at: tripManifestURL(trip))
    #expect(ArchiveIndexStore().entryForTripFolder(trip.folder, archiveRoot: first.session.archiveRoot).tripID == nil)
    let saved = try TripLocationEditor().save(target: TripLocationTarget(relativePath: trip.folderRelativePath!, tripID: nil, expectedOverride: nil), label: "All old Walks", archiveRoot: first.session.archiveRoot)
    #expect(saved.memberWalkFolderPaths.count == 2)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: first.session.archiveRoot)
    let travelRoot = root.appendingPathComponent("travel"); try AppDirectories.ensureExists(travelRoot)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: first.session.archiveRoot), to: ArchiveIndexStore.indexRoot(for: travelRoot))
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: travelRoot, supportedExtensions: ["jpg"], machineRole: .travel)
    #expect(catalogue.entries.first { $0.kind == .trip }?.tripID == saved.tripID)
    #expect(catalogue.entries.first { $0.kind == .trip }?.location == "All old Walks")
    #expect(!FileManager.default.fileExists(atPath: travelRoot.appendingPathComponent(trip.folderRelativePath!).path))
}

@Test func tripProjectionRecomputesWalkFallbackWithoutReplacingOverrides() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await tripFixture(root)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: imported.session.archiveRoot, supportedExtensions: ["jpg"])
    let walk = try #require(catalogue.walksByTripPath.values.first?.first)
    let result = ArchiveLocationSaveResult(target: ArchiveLocationTarget(walkRelativePath: walk.archiveRelativePath), name: "New Walk place", coordinate: nil, photoOverride: nil)
    let projected = ArchiveLocationProjection.applying(result, to: catalogue)
    #expect(projected.entries.first?.location == "New Walk place")
    var trip = imported.tripManifests[0]; trip.locationLabelOverride = "Fixed label"
    let overridden = TripLocationProjection.applying(trip, to: projected)
    #expect(ArchiveLocationProjection.applying(result, to: overridden).entries.first?.location == "Fixed label")
}

@Test func tripOwnedHeaderEditPreservesEarlierHumanSectionsAndRejectsInternalAliases() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await tripFixture(root), trip = try #require(imported.tripManifests.first)
    let url = tripManifestURL(trip), original = try String(contentsOf: url, encoding: .utf8)
    let human = "## Notes\n\n- Location label override: this is human prose\n\n"
    let reordered = original.replacingOccurrences(of: "## Member Walks", with: human + "## Member Walks")
    try reordered.write(to: url, atomically: true, encoding: .utf8)
    _ = try TripLocationEditor().save(target: tripTarget(trip), label: "Owned header", archiveRoot: imported.session.archiveRoot)
    #expect(try String(contentsOf: url, encoding: .utf8).contains(human))
    let alias = imported.session.archiveRoot.appendingPathComponent("alias")
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: trip.folder)
    #expect(throws: (any Error).self) { try TripLocationEditor().save(target: TripLocationTarget(relativePath: "alias", tripID: nil, expectedOverride: nil), label: "No alias", archiveRoot: imported.session.archiveRoot) }
}

@Test func tripMigrationIncludesExistingDestinationWalksWithoutReplacingSourceIdentityOrText() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (trip, archive) = try await legacyLabelledTrip(root)
    let existing = try await tripFixture(root, day: 1, title: "Already modern")
    try FileManager.default.removeItem(at: tripManifestURL(existing.tripManifests[0]))
    let migrator = ArchiveLayoutMigrator(), result = migrator.execute(migrator.plan(archiveRoot: archive))
    #expect(result.failures.isEmpty)
    let moved = TripManifestStore().loadTripManifest(folder: archive.appendingPathComponent("2023/11-November"), oneDrivePicturesRoot: archive)
    #expect(moved.tripID == trip.tripID && moved.locationLabelOverride == "Legacy label")
    #expect(moved.memberWalkFolderPaths == ["2023/11-November/14-Tue-Old-walk", existing.walkManifest.archiveFolderRelativePath!])
    #expect(moved.endDate == existing.walkManifest.walkDate)
    let text = try String(contentsOf: tripManifestURL(moved), encoding: .utf8)
    #expect(text.contains("Keep these old paths as prose: 2023/11 - November.") && text.contains("Untouched."))
    let appended = try await tripFixture(root, day: 2, title: "Later")
    #expect(appended.tripManifests[0].memberWalkFolderPaths.prefix(2) == moved.memberWalkFolderPaths[...])
}

@Test func tripSameMonthMigrationKeepsManualMemberOrderAndHumanDateProse() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await tripFixture(root, title: "A"), second = try await tripFixture(root, day: 1, title: "B")
    let archive = first.session.archiveRoot, folder = first.tripManifests[0].folder
    var oldPaths: [String] = [], newPaths: [String] = []
    for (imported, legacyName, modernName) in [(first, "14-Tuesday-A", "14-Tue-A"), (second, "15-Wednesday-B", "15-Wed-B")] {
        let from = imported.walkManifest.archiveFolder, to = folder.appendingPathComponent(legacyName)
        let resolver = ArchiveRelativePathResolver(root: archive)
        let operation = ArchiveFolderOperation(archiveRoot: archive)
        let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: from.path, newAbsoluteFolderPath: to.path,
            oldRelativeFolderPath: resolver.relativePath(for: from), newRelativeFolderPath: resolver.relativePath(for: to))
        let record = try operation.prepare(source: from, destination: to, spec: spec,
            names: [from.lastPathComponent + ".md": legacyName + ".md", from.lastPathComponent + "-session-log.jsonl": legacyName + "-session-log.jsonl"])
        _ = try operation.execute(record); try operation.complete(record)
        oldPaths.append("2023/11-November/" + legacyName); newPaths.append("2023/11-November/" + modernName)
    }
    var manual = second.tripManifests[0]; manual.memberWalkFolderPaths = oldPaths.reversed(); manual.locationLabelOverride = "Ordered"
    let notes = "\n\n## Notes\n\n- Start date: keep this human text\n- End date: preserve this too\n"
    try (ManifestRenderer().renderTripManifest(manual) + notes).write(to: tripManifestURL(manual), atomically: true, encoding: .utf8)
    let migrator = ArchiveLayoutMigrator(), result = migrator.execute(migrator.plan(archiveRoot: archive))
    #expect(result.failures.isEmpty && result.migratedWalks == 2)
    let updated = TripManifestStore().loadTripManifest(folder: folder, oneDrivePicturesRoot: archive)
    #expect(updated.memberWalkFolderPaths == Array(newPaths.reversed()))
    #expect(updated.tripID == manual.tripID && updated.locationLabelOverride == "Ordered")
    #expect(try String(contentsOf: tripManifestURL(updated), encoding: .utf8).contains(notes))
}

private final class TripCopyFailure: FileManager, @unchecked Sendable {
    override func copyItem(at source: URL, to destination: URL) throws { throw CocoaError(.fileWriteOutOfSpace) }
}

@Test func tripMigrationRejectsExistingImportBeforeJournallingAndLeavesItsRetryAvailable() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (trip, archive) = try await legacyLabelledTrip(root)
    let source = root.appendingPathComponent("unfinished-source")
    try writeTestFile(source.appendingPathComponent("new.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "new.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000), selectionState: .included)
    var session = makeTestSession(sourceRoot: source, archiveRoot: archive, items: [item], title: "Unfinished")
    session.proposedWalks = [Walk(title: "Unfinished", date: item.capturedAt!, mediaItemIDs: [item.id], tripTarget: TripTarget(kind: .existingNamedTrip, title: trip.title, folderRelativePath: trip.folderRelativePath))]
    await #expect(throws: (any Error).self) { try await ImportCoordinator(fileManager: TripCopyFailure()).commit(session: session) }
    let before = try String(contentsOf: tripManifestURL(trip), encoding: .utf8)
    let migrator = ArchiveLayoutMigrator(), result = migrator.execute(migrator.plan(archiveRoot: archive))
    #expect(!result.failures.isEmpty && result.migratedWalks == 0)
    #expect(try String(contentsOf: tripManifestURL(trip), encoding: .utf8) == before)
    try ArchiveLayoutMigrator.assertNoPending(overlapping: archive, archiveRoot: archive)
    let resumed = try await ImportCoordinator().commit(session: session)
    #expect(resumed.session.mediaItems[0].lifecycleState.isImportedOrBeyond)
}

@Test func tripMixedLayoutMigrationPlansOneFinalDestinationManifestIncludingEveryRename() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (trip, archive) = try await legacyLabelledTrip(root)
    let existing = try await tripFixture(root, day: 1, title: "B")
    let from = existing.walkManifest.archiveFolder, to = from.deletingLastPathComponent().appendingPathComponent("15-Wednesday-B")
    let resolver = ArchiveRelativePathResolver(root: archive), operation = ArchiveFolderOperation(archiveRoot: archive)
    let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: from.path, newAbsoluteFolderPath: to.path,
        oldRelativeFolderPath: resolver.relativePath(for: from), newRelativeFolderPath: resolver.relativePath(for: to))
    let record = try operation.prepare(source: from, destination: to, spec: spec,
        names: [from.lastPathComponent + ".md": to.lastPathComponent + ".md", from.lastPathComponent + "-session-log.jsonl": to.lastPathComponent + "-session-log.jsonl"])
    _ = try operation.execute(record); try operation.complete(record)
    try FileManager.default.removeItem(at: tripManifestURL(existing.tripManifests[0]))
    let migrator = ArchiveLayoutMigrator(), plan = migrator.plan(archiveRoot: archive)
    #expect(plan.walks.count == 2)
    let result = migrator.execute(plan)
    #expect(result.failures.isEmpty && result.migratedWalks == 2)
    let updated = TripManifestStore().loadTripManifest(folder: from.deletingLastPathComponent(), oneDrivePicturesRoot: archive)
    #expect(updated.tripID == trip.tripID && updated.locationLabelOverride == "Legacy label")
    #expect(updated.memberWalkFolderPaths == ["2023/11-November/14-Tue-Old-walk", "2023/11-November/15-Wed-B"])
    #expect(updated.memberWalkFolderPaths.allSatisfy { FileManager.default.fileExists(atPath: archive.appendingPathComponent($0).path) })
    #expect(try String(contentsOf: tripManifestURL(updated), encoding: .utf8).contains("Untouched."))
    try ArchiveLayoutMigrator.assertNoPending(overlapping: archive, archiveRoot: archive)
}

@Test func tripDiscoveryDoesNotPromoteCopiedStaleWalkHeadersAsHistoricalMembers() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await tripFixture(root), archive = imported.session.archiveRoot
    let historical = archive.appendingPathComponent("1987/old"), child = historical.appendingPathComponent("copied")
    try AppDirectories.ensureExists(child)
    let actual = imported.walkManifest.archiveFolder.appendingPathComponent(imported.walkManifest.archiveFolder.lastPathComponent + ".md")
    try FileManager.default.copyItem(at: actual, to: child.appendingPathComponent("copied.md"))
    #expect(try TripManifestStore().canonicalWalkMembers(in: historical, oneDrivePicturesRoot: archive).isEmpty)
    #expect(throws: (any Error).self) { try TripLocationEditor().save(target: TripLocationTarget(relativePath: "1987/old", tripID: nil, expectedOverride: nil), label: "No promotion", archiveRoot: archive) }
}

@Test func tripSameMonthMigrationPreservesVerifiedUnchangedModernMembersInTheirPositions() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await tripFixture(root, title: "Modern"), second = try await tripFixture(root, day: 1, title: "B")
    let archive = first.session.archiveRoot, folder = first.tripManifests[0].folder
    let from = second.walkManifest.archiveFolder, to = folder.appendingPathComponent("15-Wednesday-B")
    let resolver = ArchiveRelativePathResolver(root: archive), operation = ArchiveFolderOperation(archiveRoot: archive)
    let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: from.path, newAbsoluteFolderPath: to.path,
        oldRelativeFolderPath: resolver.relativePath(for: from), newRelativeFolderPath: resolver.relativePath(for: to))
    let record = try operation.prepare(source: from, destination: to, spec: spec,
        names: [from.lastPathComponent + ".md": to.lastPathComponent + ".md", from.lastPathComponent + "-session-log.jsonl": to.lastPathComponent + "-session-log.jsonl"])
    _ = try operation.execute(record); try operation.complete(record)
    var manual = second.tripManifests[0]
    manual.memberWalkFolderPaths = ["2023/11-November/15-Wednesday-B", first.walkManifest.archiveFolderRelativePath!]
    manual.locationLabelOverride = "Mixed month"
    try ManifestRenderer().renderTripManifest(manual).write(to: tripManifestURL(manual), atomically: true, encoding: .utf8)
    let migrator = ArchiveLayoutMigrator(), result = migrator.execute(migrator.plan(archiveRoot: archive))
    #expect(result.failures.isEmpty && result.migratedWalks == 1)
    let updated = TripManifestStore().loadTripManifest(folder: folder, oneDrivePicturesRoot: archive)
    #expect(updated.memberWalkFolderPaths == ["2023/11-November/15-Wed-B", first.walkManifest.archiveFolderRelativePath!])
    #expect(updated.tripID == manual.tripID && updated.locationLabelOverride == "Mixed month")
}
