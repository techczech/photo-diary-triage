import AppKit
import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func travelOriginalRequiresConsentEvenWhenResidentAndThumbnailsRemainReadable() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    let clicked = archive.appendingPathComponent("clicked.jpg")
    let neighbour = archive.appendingPathComponent("neighbour.jpg")
    try writeTestFile(clicked, contents: "clicked original")
    try writeTestFile(neighbour, contents: "neighbour original")
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext()
    policy.update(settings: settings)
    #expect(!policy.canReadBytes(at: clicked))
    let service = ArchiveOriginalViewingService(requestDownload: { _ in throw CocoaError(.featureUnsupported) }, wait: {}, maximumReadinessChecks: 1)
    try await service.prepare(clicked, policy: policy)
    #expect(policy.canReadBytes(at: clicked))
    #expect(!policy.canReadBytes(at: neighbour))
    #expect(!policy.canPreheatOriginal(at: clicked))
    #expect(!policy.canGenerateImplicitThumbnail(at: clicked))
    let thumb = ArchiveIndexStore.thumbnailURL(for: clicked, archiveRoot: archive)
    try writeTestFile(thumb, contents: "prepared thumbnail")
    #expect(policy.canReadBytes(at: thumb))
    policy.update(settings: settings)
    #expect(!policy.canReadBytes(at: clicked))
}

@Test func explicitViewingTimeoutFailureCancellationAndStaleCompletionDoNotGrant() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    let missing = archive.appendingPathComponent("missing.jpg")
    try AppDirectories.ensureExists(archive)
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext()
    policy.update(settings: settings)
    let timeout = ArchiveOriginalViewingService(requestDownload: { _ in }, wait: {}, maximumReadinessChecks: 2)
    await #expect(throws: (any Error).self) { try await timeout.prepare(missing, policy: policy) }
    #expect(!policy.canReadBytes(at: missing))
    let failed = ArchiveOriginalViewingService(requestDownload: { _ in throw CocoaError(.fileReadNoPermission) }, wait: {}, maximumReadinessChecks: 1)
    await #expect(throws: (any Error).self) { try await failed.prepare(missing, policy: policy) }
    let cancelled = ArchiveOriginalViewingService(requestDownload: { _ in throw CancellationError() }, wait: {}, maximumReadinessChecks: 1)
    await #expect(throws: CancellationError.self) { try await cancelled.prepare(missing, policy: policy) }
    let staleSettings = settings
    let stale = ArchiveOriginalViewingService(requestDownload: { url in
        try Data("downloaded original".utf8).write(to: url)
        policy.update(settings: staleSettings)
    }, wait: {}, maximumReadinessChecks: 1)
    await #expect(throws: (any Error).self) { try await stale.prepare(missing, policy: policy) }
    #expect(!policy.canReadBytes(at: missing))
}

@Test func explicitViewingRejectsForeignAndEscapingPathsBeforeDownload() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(archive)
    let outside = root.appendingPathComponent("outside.jpg")
    try writeTestFile(outside, contents: "foreign original")
    let linked = archive.appendingPathComponent("linked.jpg")
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: outside)
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext()
    policy.update(settings: settings)
    let service = ArchiveOriginalViewingService(requestDownload: { _ in Issue.record("A foreign original must never trigger a download") }, wait: {}, maximumReadinessChecks: 1)
    for url in [outside, linked] {
        await #expect(throws: (any Error).self) { try await service.prepare(url, policy: policy) }
    }
}

@MainActor
@Test func explicitResidentViewingOpensInsideWalkfolioWithoutExternalApp() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try writeTestJPEGImageAfterCreatingParent(archive.appendingPathComponent("local.jpg"))
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"))
    let item = makeTestMediaItem(sourceRoot: archive, fileName: "local.jpg", capturedAt: Date(timeIntervalSince1970: 0))
    #expect(state.isArchiveByteReadBlocked(for: item))
    state.testingOriginalViewingService = ArchiveOriginalViewingService(requestDownload: { _ in Issue.record("Resident viewing should not call FileProvider") }, wait: {}, maximumReadinessChecks: 1)
    state.downloadArchiveItemForViewing(item)
    for _ in 0..<100 where state.isArchiveByteReadBlocked(for: item) { try await Task.sleep(for: .milliseconds(10)) }
    #expect(!state.isArchiveByteReadBlocked(for: item))
    #expect(state.previewingMediaItemID == item.id)
    #expect(state.originalViewingRevision > 0)
}

private func writeTestJPEGImageAfterCreatingParent(_ url: URL) throws {
    try AppDirectories.ensureExists(url.deletingLastPathComponent())
    try writeTestJPEGImage(url)
}

private actor SuspendedArchiveOperation {
    var started = false
    private var continuation: CheckedContinuation<Void, Never>?
    func suspend() async {
        started = true
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { continuation?.resume(); continuation = nil }
}

@Test func stalledDownloadIsBoundedAndLateCompletionCannotGrant() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(archive)
    let original = archive.appendingPathComponent("original.jpg")
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext()
    policy.update(settings: settings)
    let gate = SuspendedArchiveOperation()
    let service = ArchiveOriginalViewingService(requestDownload: { _ in await gate.suspend() }, wait: {}, maximumReadinessChecks: 1, timeoutSeconds: 0.025)
    let start = ContinuousClock.now
    await #expect(throws: (any Error).self) { try await service.prepare(original, policy: policy) }
    #expect(start.duration(to: .now) < .seconds(1))
    try writeTestFile(original, contents: "late downloaded original")
    await gate.release()
    try await Task.sleep(for: .milliseconds(10))
    #expect(!policy.canReadBytes(at: original))
}

@Test func cancellingStalledDownloadReturnsWithoutWaitingForTransport() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(archive)
    let original = archive.appendingPathComponent("original.jpg")
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext()
    policy.update(settings: settings)
    let gate = SuspendedArchiveOperation()
    let service = ArchiveOriginalViewingService(requestDownload: { _ in await gate.suspend() }, wait: {}, maximumReadinessChecks: 1)
    let task = Task { try await service.prepare(original, policy: policy) }
    for _ in 0..<100 { if await gate.started { break }; try await Task.sleep(for: .milliseconds(1)) }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    await gate.release()
    #expect(!policy.canReadBytes(at: original))
}

@Test func revokedInFlightDecodeDoesNotReturnOrCacheOriginal() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    let original = archive.appendingPathComponent("original.jpg")
    try writeTestFile(original, contents: "resident original")
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = archive; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext()
    policy.update(settings: settings)
    #expect(policy.grantExplicitViewing(at: original, generation: policy.generation))
    let gate = SuspendedArchiveOperation()
    let pipeline = DecodedImagePipeline(policyContext: policy, testingDecoder: { _, _ in
        await gate.suspend()
        return NSImage(size: NSSize(width: 2, height: 2))
    })
    let pending = Task { await pipeline.image(at: original, cacheKey: "consented-original") }
    for _ in 0..<100 { if await gate.started { break }; try await Task.sleep(for: .milliseconds(1)) }
    policy.update(settings: settings)
    await gate.release()
    #expect(await pending.value == nil)
    #expect(await pipeline.image(at: original, cacheKey: "consented-original") == nil)
}

@Test func archiveCoversCannotUseOriginalOrEscapingThumbnailPaths() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("archive")
    try AppDirectories.ensureExists(archive)
    #expect(ArchiveIndexStore.validatedThumbnailURL(relativePath: "2023/Trip/original.jpg", archiveRoot: archive) == nil)
    #expect(ArchiveIndexStore.validatedThumbnailURL(relativePath: "_index/thumbs/../../original.jpg", archiveRoot: archive) == nil)
    #expect(ArchiveIndexStore.validatedThumbnailURL(relativePath: "_index/thumbs/2023/prepared.jpg", archiveRoot: archive) != nil)
    let outside = root.appendingPathComponent("outside")
    try AppDirectories.ensureExists(outside)
    try AppDirectories.ensureExists(archive.appendingPathComponent("_index/thumbs"))
    try FileManager.default.createSymbolicLink(at: archive.appendingPathComponent("_index/thumbs/linked"), withDestinationURL: outside)
    #expect(ArchiveIndexStore.validatedThumbnailURL(relativePath: "_index/thumbs/linked/private.jpg", archiveRoot: archive) == nil)
}
