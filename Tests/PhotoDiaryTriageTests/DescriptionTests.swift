import Foundation
import Testing
@testable import PhotoDiaryTriage

private func descriptionFixture(_ root: URL, title: String = "Morning", day: Int = 0, picturesRoot: URL? = nil) async throws -> ImportResult {
    let source = root.appendingPathComponent("source-\(title)")
    try AppDirectories.ensureExists(source)
    try writeTestJPEGImage(source.appendingPathComponent("photo.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "photo.jpg", capturedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day * 86_400)), selectionState: .included)
    var session = makeTestSession(sourceRoot: source, archiveRoot: root.appendingPathComponent("archive"), items: [item], title: title)
    if let picturesRoot { session.oneDrivePicturesRoot = picturesRoot }
    let result = try await ImportCoordinator().commit(session: session)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: session.archiveRoot)
    return result
}
private actor DescriptionFixtureClient: DescriptionGenerating {
    var calls = 0
    var modelAction: (@Sendable (LMStudioConfiguration) async throws -> [String])?
    var fail = false
    var textOverride: String?
    var action: (@Sendable (LMStudioPrompt) async throws -> Void)?
    init(fail: Bool = false, text: String? = nil, action: (@Sendable (LMStudioPrompt) async throws -> Void)? = nil) { self.fail = fail; self.textOverride = text; self.action = action }
    func setAction(_ action: @escaping @Sendable (LMStudioPrompt) async throws -> Void) { self.action = action }
    func setModelAction(_ action: @escaping @Sendable (LMStudioConfiguration) async throws -> [String]) { modelAction = action }
    func models(configuration: LMStudioConfiguration) async throws -> [String] { if let modelAction { return try await modelAction(configuration) }; return ["fixture-vision"] }
    func complete(configuration: LMStudioConfiguration, prompt: LMStudioPrompt) async throws -> LMStudioCompletion {
        calls += 1
        if let action { try await action(prompt) }
        if fail { throw CocoaError(.fileReadUnknown) }
        return .init(text: textOverride ?? (prompt.imageJPEG != nil ? "A wooded footpath and stone wall. Revision \(calls)." : "A walk through woodland beside a stone wall. Revision \(calls)."), model: "fixture-vision")
    }
}
private let descriptionConfiguration = LMStudioConfiguration(baseURL: "http://localhost:1234/v1", model: "fixture-vision")
private func photoDescriptionTarget(_ result: ImportResult) -> (DescriptionTargetKind, String) { (.photo, ArchiveIndexStore.archiveRelativePath(for: URL(fileURLWithPath: result.fileManifests[0].archivePath), archiveRoot: result.session.archiveRoot)!) }

@Test func descriptionsRoundTripKeeperWalkTripProvenanceNotesAndActiveOnlySearch() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let photoURL = URL(fileURLWithPath: imported.fileManifests[0].archivePath).deletingPathExtension().appendingPathExtension("md")
    let note = "\n\nMy human Czech note: Příbram.\n"
    try (String(contentsOf: photoURL, encoding: .utf8) + note).write(to: photoURL, atomically: true, encoding: .utf8)
    let client = DescriptionFixtureClient(), queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    let created = try await queue.enqueue(targets: [(.trip, imported.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration)
    #expect(created.map { $0.snapshot.target.kind } == [.photo, .walk, .trip])
    try await queue.run()
    let jobs = try await queue.jobs()
    #expect(jobs.allSatisfy { $0.state == .committed && $0.indexWarning == nil })
    #expect(await client.calls == 3)
    let files = try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder, archiveRoot: archive)
    let record = try #require(files[0].descriptions?.active)
    #expect(record.model == "fixture-vision" && record.target.identity == imported.fileManifests[0].mediaItemID)
    #expect(record.inputDigest.count == 64 && record.inputType == "resident-original-preview")
    #expect(files[0].notes.contains("My human Czech note: Příbram.") && !files[0].notes.contains("AI descriptions"))
    let walk = try #require(try ArchiveIndexStore().loadWalkManifest(folder: imported.walkManifest.archiveFolder, archiveRoot: archive))
    #expect(walk.descriptions?.active?.coveredChildren == 1)
    #expect(TripManifestStore().loadTripManifest(folder: imported.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions?.active?.childEvidence.count == 1)
    let firstText = try String(contentsOf: photoURL, encoding: .utf8)
    let secondQueue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    try await secondQueue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration, regenerate: true)
    try await secondQueue.run()
    let history = try #require(try MachineDescriptionHistory.read(in: String(contentsOf: photoURL, encoding: .utf8)))
    #expect(history.revisions.count == 2 && history.revisions[0] == record && history.active?.text.contains("Revision 4.") == true)
    #expect(MachineDescriptionHistory.humanText(in: try String(contentsOf: photoURL, encoding: .utf8)).contains(note.trimmingCharacters(in: .whitespacesAndNewlines)))
    #expect(firstText.contains("Revision 1."))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let entries = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
    #expect(entries.first { $0.kind == .photo }?.aiDescription == history.active?.text)
    let search = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    try search.rebuild(indexEntries: entries, browseEntries: [])
    #expect(try search.matchingPaths(query: "wooded").contains(imported.fileManifests[0].archiveRelativePath!))
    let relocated = root.appendingPathComponent("relocated")
    try FileManager.default.moveItem(at: archive, to: relocated)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: relocated)
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: relocated).first { $0.kind == .photo }?.aiDescription == history.active?.text)
}

private final class DescriptionReceiptFailure: @unchecked Sendable {
    let lock = NSLock(); var failed = false
    let failureState: DescriptionJobState
    init(state: DescriptionJobState = .committed) { failureState = state }
    func save(_ job: ArchiveDescriptionJob, _ root: URL) throws {
        lock.lock(); let shouldFail = job.state == failureState && !failed; if shouldFail { failed = true }; lock.unlock()
        if shouldFail { throw CocoaError(.fileWriteOutOfSpace) }
        try ArchiveOperationRecovery(archiveRoot: root).save(job, kind: "description", sessionID: job.id)
    }
}
@Test(arguments: [false, true])
func descriptionsResumePersistedResponseAfterCanonicalOrReceiptFailureWithoutAnotherModelCall(_ receipt: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let client = DescriptionFixtureClient(), failure = DescriptionReceiptFailure()
    var repository = ArchiveDescriptionRepository(archiveRoot: archive, machineRole: .mainArchive)
    if !receipt { repository.writeCanonical = { _, _ in throw CocoaError(.fileWriteOutOfSpace) } }
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client, repository: repository, persist: { job, root in try failure.save(job, root) })
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration)
    try await queue.run()
    #expect(try await queue.jobs().first?.state == .failed)
    #expect(try await queue.jobs().first?.response != nil)
    let retry = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    try await retry.run()
    #expect(try await retry.jobs().first?.state == .committed)
    #expect(await client.calls == 1)
    let history = try #require(ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions)
    #expect(history.revisions.count == 1)
}

@Test func descriptionsFailedRegenerationRetainsPreviousActiveAndDiscardAllowsFreshRequest() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    let previous = try #require(ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions)
    let failing = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient(fail: true))
    try await failing.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration, regenerate: true); try await failing.run()
    #expect(try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions == previous)
    try await failing.discardFailed()
    let fresh = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    #expect(try await fresh.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration, regenerate: true).count == 1)
}

@Test(arguments: [false, true])
func descriptionsRefuseStaleIdentityOrHumanEditsAfterResponse(_ identity: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let file = URL(fileURLWithPath: imported.fileManifests[0].archivePath).deletingPathExtension().appendingPathExtension("md")
    let client = DescriptionFixtureClient(action: { _ in
        let old = try String(contentsOf: file, encoding: .utf8)
        let changed = identity ? ArchiveManifestText.settingScalar("media_item_id", to: UUID().uuidString, in: old) : old + "\nHuman edit during request.\n"
        try changed.write(to: file, atomically: true, encoding: .utf8)
    })
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try await queue.jobs().first?.state == .failed)
    #expect(try MachineDescriptionHistory.read(in: String(contentsOf: file, encoding: .utf8)) == nil)
    if !identity { #expect(try String(contentsOf: file, encoding: .utf8).contains("Human edit during request.")) }
}

@Test func descriptionsTravelUsesPinnedThumbnailWithOriginalAbsentAndLeavesIndexUntouched() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let photo = URL(fileURLWithPath: imported.fileManifests[0].archivePath), thumb = ArchiveIndexStore.thumbnailURL(for: photo, archiveRoot: archive)
    try AppDirectories.ensureExists(thumb.deletingLastPathComponent()); try writeTestJPEGImage(thumb)
    try FileManager.default.removeItem(at: photo)
    let before = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive)
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .travel, client: DescriptionFixtureClient())
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    let job = try #require(try await queue.jobs().first)
    #expect(job.state == .committed && job.response?.inputType == "prepared-thumbnail")
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: archive) == before)
    #expect(!FileManager.default.fileExists(atPath: photo.path))
}

@Test func descriptionsTravelMissingThumbnailNeverReadsResidentOriginal() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient()
    let queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .travel, client: client)
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(await client.calls == 0)
    #expect(try await queue.jobs().first?.state == .failed)
}

@Test func descriptionsRequireCanonicalKeepersAndRejectHistoricalOrLinkedTargets() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let old = archive.appendingPathComponent("1987/old/photo.jpg"); try writeTestFile(old)
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    await #expect(throws: (any Error).self) { try await queue.enqueue(targets: [(.photo, "1987/old/photo.jpg")], configuration: descriptionConfiguration) }
    try FileManager.default.createSymbolicLink(at: archive.appendingPathComponent("alias"), withDestinationURL: imported.walkManifest.archiveFolder)
    await #expect(throws: (any Error).self) { try await queue.enqueue(targets: [(.photo, "alias/" + URL(fileURLWithPath: imported.fileManifests[0].archivePath).lastPathComponent)], configuration: descriptionConfiguration) }
}

private final class DescriptionContextFlag: @unchecked Sendable {
    let lock = NSLock(); var value = true
    func get() -> Bool { lock.lock(); defer { lock.unlock() }; return value }
    func invalidate() { lock.lock(); value = false; lock.unlock() }
}
@Test func descriptionsContextChangeAfterNetworkPreventsCanonicalPublication() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), flag = DescriptionContextFlag()
    let client = DescriptionFixtureClient(action: { _ in flag.invalidate() })
    let queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client, contextIsCurrent: { flag.get() })
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try await queue.jobs().first?.state == .cancelled)
    #expect(try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions == nil)
}

@Test func descriptionsLiteralFramingWordsInModelTextRemainReadableAndMachineFactsStaySeparate() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root)
    let literal = "A sign reading <!-- walkfolio-ai:v1 --> and a fence."
    let queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: DescriptionFixtureClient(text: literal))
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions?.active?.text == literal)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: imported.session.archiveRoot)
    #expect(try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: imported.session.archiveRoot).first { $0.kind == .photo }?.aiDescription == literal)
}

@Test func descriptionsSeparatePicturesRootAndLegacyMissingChecksumRemainEligible() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root, picturesRoot: root), archive = imported.session.archiveRoot
    let file = URL(fileURLWithPath: imported.fileManifests[0].archivePath).deletingPathExtension().appendingPathExtension("md")
    try ArchiveManifestText.removingScalar("sha256", in: String(contentsOf: file, encoding: .utf8)).write(to: file, atomically: true, encoding: .utf8)
    let trip = try #require(ArchiveIndexStore.archiveRelativePath(for: imported.tripManifests[0].folder, archiveRoot: archive))
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient(), oneDrivePicturesRoot: root)
    try await queue.enqueue(targets: [(.trip, trip)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try await queue.jobs().allSatisfy { $0.state == .committed })
    let record = try #require(try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions?.active)
    #expect(record.inputType == "resident-original-preview-unverified-copy" && record.inputDigest.count == 64)
}

@Test func descriptionsTravelRejectsLinkedThumbnailAncestorsBeforeAnyModelCall() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let photo = URL(fileURLWithPath: imported.fileManifests[0].archivePath), thumb = ArchiveIndexStore.thumbnailURL(for: photo, archiveRoot: archive)
    let actual = archive.appendingPathComponent("resident"); try AppDirectories.ensureExists(actual)
    try writeTestJPEGImage(actual.appendingPathComponent(thumb.lastPathComponent))
    try AppDirectories.ensureExists(thumb.deletingLastPathComponent().deletingLastPathComponent())
    try FileManager.default.createSymbolicLink(at: thumb.deletingLastPathComponent(), withDestinationURL: actual)
    let client = DescriptionFixtureClient(), queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .travel, client: client)
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(await client.calls == 0)
    #expect(try await queue.jobs().first?.state == .failed)
}

@Test func descriptionsFinalCompareRetainsAnExternalNoteEditDuringCommitChecks() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let file = URL(fileURLWithPath: imported.fileManifests[0].archivePath).deletingPathExtension().appendingPathExtension("md")
    var repository = ArchiveDescriptionRepository(archiveRoot: archive, machineRole: .mainArchive)
    repository.beforeCommitWrite = {
        try (String(contentsOf: file, encoding: .utf8) + "\nExternal final note.\n").write(to: file, atomically: true, encoding: .utf8)
    }
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient(), repository: repository)
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try await queue.jobs().first?.state == .failed)
    let text = try String(contentsOf: file, encoding: .utf8)
    #expect(text.contains("External final note.") && MachineDescriptionHistory.humanText(in: text) == text)
}

@Test func descriptionsEnqueueFailureRetainsTheCompletePlannedBatchForResume() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let failure = DescriptionReceiptFailure(state: .pending), client = DescriptionFixtureClient()
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client, persist: { try failure.save($0, $1) })
    await #expect(throws: (any Error).self) { try await queue.enqueue(targets: [(.trip, imported.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration) }
    let reopened = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    #expect(try await reopened.jobs().map { $0.snapshot.target.kind } == [.photo, .walk, .trip])
    try await reopened.run()
    #expect(try await reopened.jobs().allSatisfy { $0.state == .committed })
}

@Test func descriptionsCancellationInterruptsTheRequestAndPublishesNothing() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(action: { _ in try await Task.sleep(for: .seconds(5)) })
    let queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration)
    let run = Task { try await queue.run() }
    for _ in 0..<1000 { if await client.calls > 0 { break }; try await Task.sleep(for: .milliseconds(1)) }
    await queue.cancel(); try await run.value
    #expect(try await queue.jobs().first?.state == .cancelled)
    #expect(try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions == nil)
}

@Test func descriptionsChangedTripMembershipDuringItsResponseRetainsTheOldOverview() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot
    let client = DescriptionFixtureClient(action: { prompt in
        if prompt.imageJPEG == nil && prompt.text.contains("trip overview") { _ = try await descriptionFixture(root, title: "Added", day: 1) }
    })
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    try await queue.enqueue(targets: [(.trip, imported.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try await queue.jobs().last?.state == .failed)
    #expect(TripManifestStore().loadTripManifest(folder: imported.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions == nil)
}

@MainActor @Test func descriptionsActualAppStateCapturesTripSelectionAndDoesNotRunDuringTriage() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await descriptionFixture(root), second = try await descriptionFixture(root, title: "Other", day: 35)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: first.session.archiveRoot, supportedExtensions: ["jpg"])
    let client = DescriptionFixtureClient()
    var settings = makeTestSettings(root: root); settings.lmStudioConfiguration = descriptionConfiguration
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingDescriptionClient: client)
    state.setWorkspaceMode(.cameraTriage)
    await state.enqueueDescriptions(targets: [photoDescriptionTarget(first)])
    #expect(await client.calls == 0 && state.descriptionJobs.isEmpty)
    state.setWorkspaceMode(.archiveView)
    state.testingInstallArchiveCatalogue(catalogue)
    #expect(await client.calls == 0)
    let firstEntry = try #require(catalogue.entries.first { $0.archiveRelativePath == first.tripManifests[0].folderRelativePath })
    let secondEntry = try #require(catalogue.entries.first { $0.archiveRelativePath == second.tripManifests[0].folderRelativePath })
    state.selectArchiveEntry(firstEntry.id)
    await client.setAction { _ in await MainActor.run { state.selectArchiveEntry(secondEntry.id) } }
    await state.describeCurrentTrip()
    #expect(state.descriptionJobs.filter { $0.state == .committed }.count == 3)
    #expect(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: first.session.archiveRoot).descriptions != nil)
    #expect(TripManifestStore().loadTripManifest(folder: second.tripManifests[0].folder, oneDrivePicturesRoot: first.session.archiveRoot).descriptions == nil)
}

@Test func lmStudioClientUsesExplicitModelAndBoundedImagePayloadAndRejectsBadResponses() async throws {
    let config = descriptionConfiguration, jpeg = Data([1, 2, 3])
    let client = LMStudioDescriptionClient(transport: { request in
        if request.url?.lastPathComponent == "models" { return (Data(#"{"data":[{"id":"z"},{"id":"a"},{"id":"a"}]}"#.utf8), 200) }
        #expect(request.url?.path == "/v1/chat/completions" && request.httpMethod == "POST")
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "fixture-vision" && body["stream"] as? Bool == false)
        let messages = body["messages"] as! [[String: Any]], parts = messages[1]["content"] as! [[String: Any]]
        #expect((parts[1]["image_url"] as! [String: String])["url"] == "data:image/jpeg;base64,AQID")
        return (Data(#"{"model":"actual-model","choices":[{"finish_reason":"stop","message":{"content":"A path."}}]}"#.utf8), 200)
    })
    #expect(try await client.models(configuration: config) == ["a", "z"])
    #expect(try await client.complete(configuration: config, prompt: .init(text: "Describe", imageJPEG: jpeg)).model == "actual-model")
    for (body, status) in [("{}", 200), (#"{"model":"m","choices":[{"finish_reason":"length","message":{"content":"Partial"}}]}"#, 200), (#"{"model":"m","choices":[{"finish_reason":"stop","message":{"content":" "}}]}"#, 200), ("private error", 401), ("busy", 429), ("redirect", 302)] {
        let invalid = LMStudioDescriptionClient(transport: { _ in (Data(body.utf8), status) })
        await #expect(throws: (any Error).self) { try await invalid.complete(configuration: config, prompt: .init(text: "Describe")) }
    }
    #expect(throws: (any Error).self) { try LMStudioConfiguration(baseURL: "http://user:password@localhost:1234/v1", model: "m").endpoint("models") }
}

@Test func descriptionsAnAppendedKeeperRefreshesTheAffectedWalkAndTripWithoutMergingOldText() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await descriptionFixture(root), archive = first.session.archiveRoot, client = DescriptionFixtureClient()
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    try await queue.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration); try await queue.run()
    let oldTrip = try #require(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions?.active)
    let appended = try await descriptionFixture(root)
    let next = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    let jobs = try await next.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration)
    #expect(jobs.map { $0.snapshot.target.kind } == [.photo, .walk, .trip])
    try await next.run()
    let walk = try #require(try ArchiveIndexStore().loadWalkManifest(folder: first.walkManifest.archiveFolder, archiveRoot: archive))
    #expect(walk.descriptions?.active?.totalChildren == 2 && walk.descriptions?.active?.coveredTargetIDs.contains(appended.fileManifests[0].mediaItemID) == true)
    let trip = try #require(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions)
    #expect(trip.revisions.count == 2 && trip.revisions[0] == oldTrip && trip.activeID != oldTrip.id)
}

private actor LargeFirstDescriptionClient: DescriptionGenerating {
    var calls = 0
    func models(configuration: LMStudioConfiguration) async throws -> [String] { ["fixture"] }
    func complete(configuration: LMStudioConfiguration, prompt: LMStudioPrompt) async throws -> LMStudioCompletion {
        calls += 1
        return .init(text: calls == 1 ? String(repeating: "tree ", count: 3800) : "A stone wall.", model: "fixture")
    }
}
@Test func descriptionsBoundedSummaryRecordsExactlyWhichMembersWereCoveredAndOmitted() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await descriptionFixture(root), second = try await descriptionFixture(root), archive = first.session.archiveRoot
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: LargeFirstDescriptionClient())
    try await queue.enqueue(targets: [photoDescriptionTarget(first), photoDescriptionTarget(second)], configuration: descriptionConfiguration); try await queue.run()
    let repository = ArchiveDescriptionRepository(archiveRoot: archive, machineRole: .mainArchive)
    let snapshot = try repository.snapshot(kind: .walk, path: first.walkManifest.archiveFolderRelativePath!)
    let input = try repository.prepare(snapshot)
    #expect(input.covered == 1 && input.children.count == 2 && input.coveredTargetIDs == [second.fileManifests[0].mediaItemID])
    #expect(input.prompt.text.contains("Coverage: 1 of 2") && input.prompt.text.count < 18_500)
    let summaryQueue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    try await summaryQueue.enqueue(targets: [(.walk, first.walkManifest.archiveFolderRelativePath!)], configuration: descriptionConfiguration); try await summaryQueue.run()
    let record = try #require(try ArchiveIndexStore().loadWalkManifest(folder: first.walkManifest.archiveFolder, archiveRoot: archive)?.descriptions?.active)
    #expect(record.coveredTargetIDs == input.coveredTargetIDs && record.totalChildren == 2)
}

@Test func descriptionsCanonicalFactsSurviveLabelEditsMovesAndIndexOnlyTravelReconstruction() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await descriptionFixture(root), archive = first.session.archiveRoot
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    try await queue.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration); try await queue.run()
    let walk = try #require(try ArchiveIndexStore().loadWalkManifest(folder: first.walkManifest.archiveFolder, archiveRoot: archive))
    let trip = TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: archive)
    _ = try TripLocationEditor().save(target: TripLocationTarget(relativePath: trip.folderRelativePath!, tripID: trip.tripID, expectedOverride: nil), label: "New label", archiveRoot: archive)
    #expect(TripManifestStore().loadTripManifest(folder: trip.folder, oneDrivePicturesRoot: archive).descriptions == trip.descriptions)
    let other = try await descriptionFixture(root, title: "Later", day: 35)
    let moved = try WalkMover().moveWalk(at: first.walkManifest.archiveFolder, to: other.tripManifests[0].folder, oneDrivePicturesRoot: archive, archiveRoot: archive)
    let loaded = try #require(try ArchiveIndexStore().loadWalkManifest(folder: moved.destinationFolder, archiveRoot: archive))
    #expect(loaded.descriptions == walk.descriptions && loaded.importedFiles[0].descriptions == walk.importedFiles[0].descriptions)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let travel = root.appendingPathComponent("travel"); try AppDirectories.ensureExists(travel)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: archive), to: ArchiveIndexStore.indexRoot(for: travel))
    let entries = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: travel)
    #expect(entries.filter { $0.kind == .photo }.contains { $0.aiDescription == loaded.importedFiles[0].descriptions?.active?.text })
    let search = ArchiveSearchCache(databaseURL: root.appendingPathComponent("travel-search.sqlite"))
    try search.rebuild(indexEntries: entries, browseEntries: [])
    #expect(try search.matchingPaths(query: "wooded").count == 1)
}

@Test func descriptionsEmptyProviderResultRetainsCanonicalTextAndSettingsRemainBackwardCompatible() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root)
    let queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: DescriptionFixtureClient(text: ""))
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    #expect(try await queue.jobs().first?.state == .failed)
    #expect(try ArchiveIndexStore().loadFileManifests(folder: imported.walkManifest.archiveFolder)[0].descriptions == nil)
    var settings = makeTestSettings(root: root); settings.lmStudioConfiguration = descriptionConfiguration
    #expect(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)).lmStudioConfiguration == descriptionConfiguration)
    var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]; old.removeValue(forKey: "lmStudioConfiguration")
    #expect(try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: old)).lmStudioConfiguration.model == "")
}

@Test func descriptionsNewBatchDoesNotResumeCancelledWorkAndDiscardReleasesAllPendingMembers() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await descriptionFixture(root), second = try await descriptionFixture(root, title: "Separate", day: 35)
    let client = DescriptionFixtureClient(action: { _ in try await Task.sleep(for: .seconds(5)) })
    let queue = ArchiveDescriptionQueue(archiveRoot: first.session.archiveRoot, machineRole: .mainArchive, client: client)
    let cancelledBatch = try await queue.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration)
    let run = Task { try await queue.run(jobIDs: Set(cancelledBatch.map(\.id))) }
    for _ in 0..<1000 { if await client.calls > 0 { break }; try await Task.sleep(for: .milliseconds(1)) }
    await queue.cancel(); try await run.value
    await client.setAction { _ in }
    let separate = try await queue.enqueue(targets: [photoDescriptionTarget(second)], configuration: descriptionConfiguration)
    try await queue.run(jobIDs: Set(separate.map(\.id)))
    let jobs = try await queue.jobs(), old = jobs.filter { $0.batchID == cancelledBatch[0].batchID }
    #expect(old.map(\.state) == [.cancelled, .pending, .pending])
    #expect(await client.calls == 2)
    #expect(jobs.first { $0.id == separate[0].id }?.state == .committed)
    try await queue.discardFailed()
    #expect(try await queue.jobs().filter { $0.batchID == cancelledBatch[0].batchID }.allSatisfy { $0.state == .discarded })
    #expect(try await queue.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration).count == 3)
}

@Test(arguments: [false, true])
func descriptionsFailedChildRefreshCannotPublishANewlyDatedStaleOverview(_ failWalk: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let first = try await descriptionFixture(root), archive = first.session.archiveRoot
    let initial = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    try await initial.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration); try await initial.run()
    let previous = try #require(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions)
    _ = try await descriptionFixture(root)
    let failingClient = DescriptionFixtureClient(action: { prompt in
        if (failWalk && prompt.text.contains("walk overview")) || (!failWalk && prompt.imageJPEG != nil) { throw CocoaError(.fileReadUnknown) }
    })
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: failingClient)
    try await queue.enqueue(targets: [(.trip, first.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration); try await queue.run()
    #expect(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions == previous)
    #expect(try await queue.jobs().last?.state == .failed)
    let retry = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: DescriptionFixtureClient())
    try await retry.run()
    let refreshed = try #require(TripManifestStore().loadTripManifest(folder: first.tripManifests[0].folder, oneDrivePicturesRoot: archive).descriptions)
    #expect(refreshed.revisions.count == 2 && refreshed.revisions[0] == previous.revisions[0] && refreshed.activeID != previous.activeID)
}

@Test func descriptionsRejectLinkedParentWalkBeforeQueueingASelectedPhoto() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root)
    let walk = imported.walkManifest.archiveFolder.appendingPathComponent(imported.walkManifest.archiveFolder.lastPathComponent + ".md")
    let outside = root.appendingPathComponent("outside.md")
    try FileManager.default.moveItem(at: walk, to: outside)
    try FileManager.default.createSymbolicLink(at: walk, withDestinationURL: outside)
    let client = DescriptionFixtureClient(), queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    await #expect(throws: (any Error).self) { try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration) }
    #expect(await client.calls == 0)
}

private actor DescriptionTestBarrier {
    var entered = false, released = false
    var entryWaiters: [CheckedContinuation<Void, Never>] = [], releaseWaiters: [CheckedContinuation<Void, Never>] = []
    func stop() async {
        guard !released else { return }; entered = true
        for waiter in entryWaiters { waiter.resume() }; entryWaiters = []
        await withCheckedContinuation { releaseWaiters.append($0) }
    }
    func waitForEntry() async { if !entered { await withCheckedContinuation { entryWaiters.append($0) } } }
    func release() { released = true; for waiter in releaseWaiters { waiter.resume() }; releaseWaiters = [] }
}
private actor GatedDescriptionQueue: ArchiveDescriptionQueuing {
    enum Phase { case enqueue, jobs, run, cancel, discard }
    let base: ArchiveDescriptionQueue, gate: DescriptionTestBarrier, phase: Phase, failRead: Bool
    var runs = 0, cancels = 0
    init(_ base: ArchiveDescriptionQueue, gate: DescriptionTestBarrier, phase: Phase, failRead: Bool = false) {
        self.base = base; self.gate = gate; self.phase = phase; self.failRead = failRead
    }
    func jobs() async throws -> [ArchiveDescriptionJob] {
        let value = try await base.jobs()
        if phase == .jobs { await gate.stop(); if failRead { throw CocoaError(.fileReadUnknown) } }
        return value
    }
    func enqueue(targets: [(DescriptionTargetKind, String)], configuration: LMStudioConfiguration, regenerate: Bool) async throws -> [ArchiveDescriptionJob] {
        let value = try await base.enqueue(targets: targets, configuration: configuration, regenerate: regenerate)
        if phase == .enqueue { await gate.stop() }; return value
    }
    func run(jobIDs: Set<UUID>?, progress: (@Sendable ([ArchiveDescriptionJob]) async -> Void)?) async throws {
        runs += 1; try await base.run(jobIDs: jobIDs, progress: progress)
        if phase == .run { await gate.stop() }
    }
    func cancel() async {
        cancels += 1
        if phase == .cancel && cancels == 1 { await gate.stop() }
        await base.cancel()
    }
    func discardFailed() async throws {
        if phase == .discard { await gate.stop() }
        try await base.discardFailed()
    }
}
@MainActor
private func descriptionTestApp(_ imported: ImportResult, root: URL, client: DescriptionFixtureClient, queue: any ArchiveDescriptionQueuing) -> AppState {
    var settings = AppSettings.default(); settings.archiveRoot = imported.session.archiveRoot; settings.oneDrivePicturesRoot = settings.archiveRoot
    settings.lmStudioConfiguration = descriptionConfiguration
    let app = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingDescriptionClient: client)
    app.testingDescriptionQueue = queue; app.setWorkspaceMode(.archiveView); return app
}

@Test @MainActor func cancellingDescriptionPreparationCannotAutomaticallyRestartTheQueue() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    let queue = GatedDescriptionQueue(base, gate: gate, phase: .enqueue)
    let app = descriptionTestApp(imported, root: root, client: client, queue: queue)
    let task = Task { await app.enqueueDescriptions(targets: [photoDescriptionTarget(imported)]) }
    await gate.waitForEntry(); app.cancelDescriptions(); await gate.release(); await task.value
    #expect(await client.calls == 0); #expect(await queue.runs == 0); #expect(!app.isDescribing)
    #expect(try await base.jobs().first?.state == .pending)
    await app.resumeDescriptions()
    #expect(await client.calls == 1); #expect(try await base.jobs().first?.state == .committed)
}

@Test @MainActor func staleDescriptionPreparationReadCannotPublishOrResumeAfterRootRoundTrip() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    let queue = GatedDescriptionQueue(base, gate: gate, phase: .jobs)
    let app = descriptionTestApp(imported, root: root, client: client, queue: queue)
    let task = Task { await app.enqueueDescriptions(targets: [photoDescriptionTarget(imported)]) }
    await gate.waitForEntry(); app.setArchiveRoot(root.appendingPathComponent("B")); app.setArchiveRoot(imported.session.archiveRoot)
    app.descriptionJobs = []; app.showDescriptionQueue = false; app.statusMessage = "Current context sentinel"
    await gate.release(); await task.value
    #expect(app.descriptionJobs.isEmpty); #expect(!app.showDescriptionQueue); #expect(app.statusMessage == "Current context sentinel")
    #expect(await client.calls == 0); #expect(await queue.runs == 0); #expect(!app.isDescribing)
}

@Test @MainActor func staleDescriptionResumeReadCannotPublishAfterRootRoundTrip() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    try await base.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration)
    let app = descriptionTestApp(imported, root: root, client: client, queue: GatedDescriptionQueue(base, gate: gate, phase: .jobs))
    let task = Task { await app.resumeDescriptions() }
    await gate.waitForEntry(); app.setArchiveRoot(root.appendingPathComponent("B")); app.setArchiveRoot(imported.session.archiveRoot)
    app.descriptionJobs = []; app.statusMessage = "Current resume sentinel"
    await gate.release(); await task.value
    #expect(app.descriptionJobs.isEmpty); #expect(app.statusMessage == "Current resume sentinel"); #expect(!app.isDescribing)
    #expect(await client.calls == 1) // A's legitimate result remains saved; B receives no substituted work.
}

@Test(arguments: [false, true]) @MainActor func staleDescriptionQueueLoadCannotPublishSuccessOrFailure(_ failure: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    try await base.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration)
    let app = descriptionTestApp(imported, root: root, client: client, queue: GatedDescriptionQueue(base, gate: gate, phase: .jobs, failRead: failure))
    let task = Task { await app.loadDescriptionQueue() }
    await gate.waitForEntry(); app.setArchiveRoot(root.appendingPathComponent("B")); app.setArchiveRoot(imported.session.archiveRoot)
    app.descriptionJobs = []; app.showDescriptionQueue = false; app.statusMessage = "Current load sentinel"
    await gate.release(); await task.value
    #expect(app.descriptionJobs.isEmpty); #expect(!app.showDescriptionQueue); #expect(app.statusMessage == "Current load sentinel")
}

@Test func staleDescriptionQueueCannotDiscardDurableFailedRequests() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), flag = DescriptionContextFlag()
    let queue = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: DescriptionFixtureClient(fail: true), contextIsCurrent: { flag.get() })
    try await queue.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await queue.run()
    let before = try await queue.jobs().map { ($0.id, $0.state) }
    flag.invalidate()
    await #expect(throws: CancellationError.self) { try await queue.discardFailed() }
    let after = try await queue.jobs()
    #expect(after.map(\.id) == before.map { $0.0 }); #expect(after.map(\.state) == before.map { $0.1 })
}

@Test @MainActor func descriptionResumeReservesItsOperationBeforeScheduling() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    try await base.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration)
    let queue = GatedDescriptionQueue(base, gate: gate, phase: .run)
    let app = descriptionTestApp(imported, root: root, client: client, queue: queue)
    app.startDescriptionResume(); #expect(app.isDescribing)
    app.startDescriptionResume(); await gate.waitForEntry(); #expect(await queue.runs == 1)
    await gate.release()
    for _ in 0..<50 where app.isDescribing { try await Task.sleep(for: .milliseconds(10)) }
    #expect(!app.isDescribing); #expect(await client.calls == 1)
}

@Test @MainActor func yearDescriptionRetainsIssuedConfigurationAcrossIndexEnumeration() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    let app = descriptionTestApp(imported, root: root, client: client, queue: base)
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: imported.session.archiveRoot)
    app.setArchiveYearFilter(try #require(rows.first?.year))
    app.testingDescriptionYearReader = { _ in await gate.stop(); return rows }
    let task = Task { await app.describeCurrentYear() }
    await gate.waitForEntry(); app.setLMStudio(baseURL: "http://localhost:4321/v1", model: "replacement-model")
    await gate.release(); await task.value
    let jobs = try await base.jobs()
    #expect(jobs.count == 3); #expect(jobs.allSatisfy { $0.configuration == descriptionConfiguration && $0.state == .committed })
    #expect(app.settings.lmStudioConfiguration.model == "replacement-model"); #expect(await client.calls == 3)
}

@Test @MainActor func registeredDescriptionRequestCapturesTheChosenTripBeforeScheduling() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let a = try await descriptionFixture(root), b = try await descriptionFixture(root, title: "Other", day: 35)
    let client = DescriptionFixtureClient(), base = ArchiveDescriptionQueue(archiveRoot: a.session.archiveRoot, machineRole: .mainArchive, client: client)
    let app = descriptionTestApp(a, root: root, client: client, queue: base)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: a.session.archiveRoot, supportedExtensions: ["jpg"])
    app.testingInstallArchiveCatalogue(catalogue)
    let entryA = try #require(catalogue.entries.first { $0.archiveRelativePath == a.tripManifests[0].folderRelativePath }), entryB = try #require(catalogue.entries.first { $0.archiveRelativePath == b.tripManifests[0].folderRelativePath })
    app.selectArchiveEntry(entryA.id); AppCommandRegistry.definition(.describeTrip).run(app)
    #expect(app.isDescribing); app.selectArchiveEntry(entryB.id)
    for _ in 0..<100 where app.isDescribing { try await Task.sleep(for: .milliseconds(10)) }
    #expect(!app.isDescribing)
    #expect(TripManifestStore().loadTripManifest(folder: a.tripManifests[0].folder, oneDrivePicturesRoot: a.session.archiveRoot).descriptions != nil)
    #expect(TripManifestStore().loadTripManifest(folder: b.tripManifests[0].folder, oneDrivePicturesRoot: a.session.archiveRoot).descriptions == nil)
    #expect(app.archiveBrowserState.snapshot.selectedEntryID == entryB.id); #expect(await client.calls == 3)
}

@Test @MainActor func repeatedDescriptionCancellationWaitsForEveryAcknowledgementBeforeResume() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    let queue = GatedDescriptionQueue(base, gate: gate, phase: .cancel)
    let app = descriptionTestApp(imported, root: root, client: client, queue: queue)
    app.cancelDescriptions(); await gate.waitForEntry()
    app.cancelDescriptions(); app.startDescriptionResume()
    try await Task.sleep(for: .milliseconds(40))
    #expect(await queue.runs == 0); #expect(app.isDescribing); #expect(await queue.cancels == 1)
    await gate.release()
    for _ in 0..<50 where app.isDescribing { try await Task.sleep(for: .milliseconds(10)) }
    #expect(await queue.cancels == 2); #expect(await queue.runs == 1); #expect(!app.isDescribing)
}

@Test(arguments: [false, true]) @MainActor func descriptionSettingsQueueOpenerRequiresCurrentSuccessfulLoad(_ failure: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    let app = descriptionTestApp(imported, root: root, client: client, queue: GatedDescriptionQueue(base, gate: gate, phase: .jobs, failRead: failure))
    var opened = 0
    let actions = descriptionSettingsCommandActions(appState: app, showQueue: { opened += 1 })
    actions[.descriptionQueue]?.run(); await gate.waitForEntry()
    if !failure { app.setArchiveRoot(root.appendingPathComponent("B")); app.setArchiveRoot(imported.session.archiveRoot) }
    app.showDescriptionQueue = false; await gate.release(); try await Task.sleep(for: .milliseconds(40))
    #expect(opened == 0); #expect(!app.showDescriptionQueue)
    app.testingDescriptionQueue = base
    descriptionSettingsCommandActions(appState: app, showQueue: { opened += 1 })[.descriptionQueue]?.run()
    for _ in 0..<50 where opened == 0 { try await Task.sleep(for: .milliseconds(10)) }
    #expect(opened == 1); #expect(!app.showDescriptionQueue)
}

@Test(arguments: [false, true]) @MainActor func staleModelRefreshCannotPublishAfterConfigurationRoundTrip(_ failure: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(), gate = DescriptionTestBarrier()
    let app = descriptionTestApp(imported, root: root, client: client, queue: ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client))
    await client.setModelAction { _ in await gate.stop(); if failure { throw CocoaError(.fileReadUnknown) }; return ["obsolete-model"] }
    let task = Task { await app.refreshLMStudioModels() }; await gate.waitForEntry()
    app.setLMStudio(baseURL: "http://localhost:4321/v1"); app.setLMStudio(baseURL: descriptionConfiguration.baseURL)
    app.lmStudioModels = ["current-model"]; app.statusMessage = "Current model sentinel"
    await gate.release(); await task.value
    #expect(app.lmStudioModels == ["current-model"]); #expect(app.statusMessage == "Current model sentinel"); #expect(!app.isRefreshingLMStudioModels)
    await client.setModelAction { _ in ["fresh-model"] }; await app.refreshLMStudioModels()
    #expect(app.lmStudioModels == ["fresh-model"])
}

@Test @MainActor func cancellingDescriptionDiscardPreservesDurableRequestsUntilFreshConfirmation() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), client = DescriptionFixtureClient(fail: true), gate = DescriptionTestBarrier()
    let base = ArchiveDescriptionQueue(archiveRoot: imported.session.archiveRoot, machineRole: .mainArchive, client: client)
    try await base.enqueue(targets: [photoDescriptionTarget(imported)], configuration: descriptionConfiguration); try await base.run()
    #expect(try await base.jobs().first?.state == .failed)
    let app = descriptionTestApp(imported, root: root, client: client, queue: GatedDescriptionQueue(base, gate: gate, phase: .discard))
    let task = Task { await app.discardFailedDescriptions() }
    await gate.waitForEntry(); app.cancelDescriptions(); await gate.release(); await task.value
    #expect(try await base.jobs().first?.state == .failed); #expect(!app.isDescribing)
    app.testingDescriptionQueue = base; await app.discardFailedDescriptions()
    #expect(try await base.jobs().first?.state == .discarded); #expect(!app.isDescribing)
}

@Test func interruptedDescriptionDiscardRetainsWholeBatchIntentAndNeverResumesPendingParents() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await descriptionFixture(root), archive = imported.session.archiveRoot, flag = DescriptionContextFlag()
    let client = DescriptionFixtureClient(action: { _ in try await Task.sleep(for: .seconds(5)) })
    let queue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client, contextIsCurrent: { flag.get() }, persist: { job, root in
        try ArchiveOperationRecovery(archiveRoot: root).save(job, kind: "description", sessionID: job.id)
        if job.state == .discarded { flag.invalidate() } // Stop after the first durable discard.
    })
    let batch = try await queue.enqueue(targets: [(.trip, imported.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration)
    let task = Task { try await queue.run() }
    for _ in 0..<1000 { if await client.calls > 0 { break }; try await Task.sleep(for: .milliseconds(1)) }
    await queue.cancel(); try await task.value; await client.setAction { _ in }
    #expect(try await queue.jobs().map(\.state) == [.cancelled, .pending, .pending])
    await #expect(throws: CancellationError.self) { try await queue.discardFailed() }
    let recovery = ArchiveOperationRecovery(archiveRoot: archive)
    let rawStates = try batch.map { value in
        let recorded = try recovery.load(ArchiveDescriptionJob.self, kind: "description", sessionID: value.id)
        let job = try #require(recorded); return job.state
    }
    #expect(rawStates == [.discarded, .pending, .pending])
    let fresh = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: client)
    #expect(try await fresh.jobs().allSatisfy { $0.state == .discarded })
    try await fresh.run(); #expect(await client.calls == 1)
    #expect(try await fresh.jobs().allSatisfy { $0.state == .discarded })
    try await fresh.discardFailed()
    #expect(try batch.allSatisfy { try recovery.load(ArchiveDescriptionJob.self, kind: "description", sessionID: $0.id)?.state == .discarded })
    #expect(try await fresh.enqueue(targets: [(.trip, imported.tripManifests[0].folderRelativePath!)], configuration: descriptionConfiguration).count == 3)
}
