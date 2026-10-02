import AppKit
import Foundation
import Testing
@testable import PhotoDiaryTriage

private actor CoverDecodeCounter {
    var count = 0
    func decode() -> NSImage {
        count += 1
        return NSImage(size: NSSize(width: count, height: count))
    }
}

@Test func decodedImageCacheDoesNotSurvivePolicyGenerationReplacement() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = root; settings.archiveMachineRole = .mainArchive
    let policy = ArchiveByteReadPolicyContext(); policy.update(settings: settings)
    let counter = CoverDecodeCounter()
    let pipeline = DecodedImagePipeline(policyContext: policy, testingDecoder: { _, _ in await counter.decode() })
    let request = DecodedImageRequest.interactiveDisplay(root.appendingPathComponent("image.jpg"))
    let first = await pipeline.image(request)
    #expect(first?.size.width == 1)
    try await Task.sleep(for: .milliseconds(10))
    policy.update(settings: settings)
    let replacement = await pipeline.image(request)
    #expect(replacement?.size.width == 2)
    #expect(await counter.count == 2)
}

@Test func travelExplicitOriginalConsentDoesNotPermitPipelinePreheat() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let original = root.appendingPathComponent("original.jpg")
    try writeTestFile(original, contents: "resident original")
    var settings = makeTestSettings(root: root)
    settings.archiveRoot = root; settings.archiveMachineRole = .travel
    let policy = ArchiveByteReadPolicyContext(); policy.update(settings: settings)
    #expect(policy.grantExplicitViewing(at: original, generation: policy.generation))
    let counter = CoverDecodeCounter()
    let pipeline = DecodedImagePipeline(policyContext: policy, testingDecoder: { _, _ in await counter.decode() })
    await pipeline.preheat([.interactiveDisplay(original)])
    try await Task.sleep(for: .milliseconds(30))
    #expect(await counter.count == 0)
    let image = await pipeline.image(.fullSize(original))
    #expect(image != nil)
    #expect(await counter.count == 1)
}


private func coverIsMainThread() -> Bool { Thread.isMainThread }

private func coverTestImage(width: Int = 2, height: Int = 2, bytesPerRow: Int? = nil) -> CGImage {
    let row = bytesPerRow ?? width * 4
    let provider = CGDataProvider(data: Data(repeating: 128, count: row * height) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: row,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

private actor CoverGate {
    private(set) var started: [String] = []
    private var held: [String: CheckedContinuation<Void, Never>] = [:]
    private var unblocked = false
    func hold(_ name: String) async {
        started.append(name)
        guard !unblocked else { return }
        await withCheckedContinuation { held[name] = $0 }
    }
    func release(_ name: String) { held.removeValue(forKey: name)?.resume() }
    func releaseAll() { unblocked = true; for c in held.values { c.resume() }; held.removeAll() }
}

private func coverEventually(_ predicate: () async -> Bool) async -> Bool {
    for _ in 0..<500 { if await predicate() { return true }; try? await Task.sleep(for: .milliseconds(1)) }
    return false
}

private func coverFixture(_ root: URL, role: ArchiveMachineRole = .travel) -> (ArchiveByteReadPolicyContext, ArchiveCoverContext) {
    var settings = makeTestSettings(root: root); settings.archiveRoot = root; settings.archiveMachineRole = role
    let policy = ArchiveByteReadPolicyContext(); policy.update(settings: settings)
    return (policy, ArchiveCoverContext(policyGeneration: policy.generation, catalogueRevision: UUID()))
}

private func coverRequest(_ root: URL, _ context: ArchiveCoverContext, _ name: String = "a") throws -> ArchiveCoverRequest {
    try #require(ArchiveCoverRequest(archiveRoot: root, thumbnailPath: "_index/thumbs/2023/\(name).jpg", context: context, showPreview: true))
}

private func coverImage(_ result: ArchiveCoverLoadResult) -> NSImage? {
    if case .image(let image) = result { return image }; return nil
}

@Test func coverDecodesResidentJPEGOffMainAndDownsamplesLargeInput() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), request = try coverRequest(root, context)
    let url = root.appendingPathComponent(request.thumbnailPath)
    try AppDirectories.ensureExists(url.deletingLastPathComponent())
    try writeTestJPEGImage(url, width: 2048, height: 1536)
    let pipeline = ArchiveCoverPipeline(policy: policy, testingLoad: { captured in
        #expect(!coverIsMainThread())
        return ArchiveCoverSource.decode(captured)
    })
    let image = try #require(coverImage(await pipeline.image(request)))
    #expect(image.size.width == 512); #expect(image.size.height == 384)
    #expect(await pipeline.statistics.cachedBytes == 512 * 384 * 4)
}

@Test func coversRejectLinkedAncestorsLeafOriginalMissingCorruptAndTraversal() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), request = try coverRequest(root, context)
    let thumb = root.appendingPathComponent(request.thumbnailPath)
    try AppDirectories.ensureExists(thumb.deletingLastPathComponent())
    let original = root.appendingPathComponent("original.jpg")
    try writeTestJPEGImage(original)
    // A link to an original INSIDE this archive passed the former general path validator.
    try FileManager.default.createSymbolicLink(at: thumb, withDestinationURL: original)
    let pipeline = ArchiveCoverPipeline(policy: policy)
    #expect(coverImage(await pipeline.image(request)) == nil)
    try FileManager.default.removeItem(at: thumb)
    try writeTestFile(thumb, contents: "corrupt JPEG")
    #expect(coverImage(await pipeline.image(request)) == nil)
    try FileManager.default.removeItem(at: thumb)
    #expect(coverImage(await pipeline.image(request)) == nil)
    let internalDirectory = root.appendingPathComponent("original-folder")
    try AppDirectories.ensureExists(internalDirectory)
    try writeTestJPEGImage(internalDirectory.appendingPathComponent("b.jpg"))
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("_index/thumbs/linked"), withDestinationURL: internalDirectory)
    let linked = try #require(ArchiveCoverRequest(archiveRoot: root, thumbnailPath: "_index/thumbs/linked/b.jpg", context: context, showPreview: true))
    #expect(coverImage(await pipeline.image(linked)) == nil)
    for path in ["original.jpg", "/_index/thumbs/a.jpg", "_index/thumbs/../original.jpg", "_index/thumbs//a.jpg", "_index/thumbs/a.png", "_index/thumbs/./a.jpg"] {
        #expect(ArchiveCoverRequest(archiveRoot: root, thumbnailPath: path, context: context, showPreview: true) == nil)
    }
}

@Test func coversRejectOnlineOnlyAndOversizedFileBeforeByteOpen() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (_, context) = coverFixture(root), request = try coverRequest(root, context)
    let url = root.appendingPathComponent(request.thumbnailPath)
    try AppDirectories.ensureExists(url.deletingLastPathComponent())
    #expect(FileManager.default.createFile(atPath: url.path, contents: Data()))
    let handle = try FileHandle(forWritingTo: url); try handle.truncate(atOffset: 1_048_576); try handle.close()
    var didOpen = false
    #expect(ArchiveCoverSource.residentJPEGData(request, beforeByteOpen: { didOpen = true }) == nil)
    #expect(!didOpen)
    let large = try FileHandle(forWritingTo: url); try large.truncate(atOffset: 17 * 1024 * 1024); try large.close()
    #expect(ArchiveCoverSource.residentJPEGData(request, beforeByteOpen: { didOpen = true }) == nil)
    #expect(!didOpen)
}

@Test func coverRootAliasWorksButThumbsAliasNeverDoes() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let archive = root.appendingPathComponent("actual"), alias = root.appendingPathComponent("alias")
    let thumb = archive.appendingPathComponent("_index/thumbs/2023/a.jpg")
    try AppDirectories.ensureExists(thumb.deletingLastPathComponent()); try writeTestJPEGImage(thumb)
    try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: archive)
    let (policy, context) = coverFixture(alias), pipeline = ArchiveCoverPipeline(policy: policy)
    #expect(coverImage(await pipeline.image(try coverRequest(alias, context))) != nil)
}

@Test func coverActiveQueueBoundsRetainCancelledWorkerSlotUntilPhysicalReturn() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1, queued: 1), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath)
        return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b"), c = try coverRequest(root, context, "c")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let second = Task { await pipeline.image(b) }
    #expect(await coverEventually { await pipeline.statistics.queued == 1 })
    if case .deferred = await pipeline.image(c) {} else { Issue.record("A saturated queue must defer admission") }
    first.cancel(); #expect(coverImage(await first.value) == nil)
    #expect(await pipeline.statistics.active == 1)
    #expect(await gate.started == [a.thumbnailPath])
    // The caller has returned, but its noncooperative decoder still occupies the slot.
    await gate.release(a.thumbnailPath)
    #expect(await coverEventually { await gate.started.count == 2 })
    #expect(await pipeline.statistics.active == 1)
    await gate.release(b.thumbnailPath); #expect(coverImage(await second.value) != nil)
    #expect(await pipeline.statistics.active == 0)
}

@Test func queuedCoverCancellationPerformsNoWorkerFileWork() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1, queued: 2), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let second = Task { await pipeline.image(b) }
    #expect(await coverEventually { await pipeline.statistics.queued == 1 })
    second.cancel(); #expect(coverImage(await second.value) == nil)
    #expect(await pipeline.statistics.queued == 0)
    await gate.release(a.thumbnailPath); _ = await first.value
    #expect(await gate.started == [a.thumbnailPath])
}

@Test func sharedCoverSubscribersCancelIndependentlyAndDeduplicate() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate(), request = try coverRequest(root, context)
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let first = Task { await pipeline.image(request) }, second = Task { await pipeline.image(request) }
    #expect(await coverEventually { await pipeline.statistics.subscribers == 2 })
    first.cancel(); #expect(coverImage(await first.value) == nil)
    #expect(await pipeline.statistics.subscribers == 1)
    await gate.release(request.thumbnailPath)
    #expect(coverImage(await second.value) != nil); #expect(await gate.started.count == 1)
    #expect(coverImage(await pipeline.image(request)) != nil); #expect(await gate.started.count == 1)
}

@Test func visibleCoverPromotesQueuedSpeculativeRequestWithoutDuplicateDecode() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1, queued: 3), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b"), c = try coverRequest(root, context, "c")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let speculative = Task { await pipeline.image(b, visible: false) }
    #expect(await coverEventually { await pipeline.statistics.queued == 1 })
    let visible = Task { await pipeline.image(c) }
    #expect(await coverEventually { await pipeline.statistics.queued == 2 })
    let promoted = Task { await pipeline.image(b) }
    #expect(await coverEventually { await pipeline.statistics.subscribers == 4 })
    await gate.release(a.thumbnailPath); _ = await first.value
    #expect(await coverEventually { await gate.started.count == 2 })
    #expect(await gate.started == [a.thumbnailPath, b.thumbnailPath])
    await gate.release(b.thumbnailPath); _ = await speculative.value; _ = await promoted.value
    #expect(await coverEventually { await gate.started.count == 3 })
    await gate.release(c.thumbnailPath); _ = await visible.value
    #expect(await gate.started == [a.thumbnailPath, b.thumbnailPath, c.thumbnailPath])
}

@Test(arguments: [true, false]) func coverCacheHardCountAndByteBoundsUseLeastRecentlyViewedEviction(byteLimit: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), counter = CoverDecodeCounter()
    let limits = ArchiveCoverPipeline.Limits(cacheCount: byteLimit ? 128 : 2, cacheBytes: byteLimit ? 32 : 1_000_000)
    let pipeline = ArchiveCoverPipeline(limits: limits, policy: policy, testingLoad: { _ in
        _ = await counter.decode(); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b"), c = try coverRequest(root, context, "c")
    _ = await pipeline.image(a); _ = await pipeline.image(b); _ = await pipeline.image(a); _ = await pipeline.image(c)
    #expect(await counter.count == 3)
    #expect(await pipeline.statistics.cached == 2); #expect(await pipeline.statistics.cachedBytes == 32)
    _ = await pipeline.image(a); #expect(await counter.count == 3)
    _ = await pipeline.image(b); #expect(await counter.count == 4)
    #expect(await pipeline.statistics.cachedBytes == 32)
}

@Test func oversizedDecodedCoverIsNeverRetainedBeyondCacheBudget() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), request = try coverRequest(root, context)
    let pipeline = ArchiveCoverPipeline(limits: .init(cacheBytes: 16), policy: policy, testingLoad: { _ in coverTestImage(width: 3, height: 3) })
    _ = await pipeline.image(request)
    #expect(await pipeline.statistics.cached == 0); #expect(await pipeline.statistics.cachedBytes == 0)
}

@Test func policyReplacementRejectsOldActiveAndQueuedCoversBeforePublicationOrFileWork() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let second = Task { await pipeline.image(b) }
    #expect(await coverEventually { await pipeline.statistics.queued == 1 })
    var settings = makeTestSettings(root: root); settings.archiveRoot = root; settings.archiveMachineRole = .mainArchive
    policy.update(settings: settings)
    await gate.release(a.thumbnailPath)
    #expect(coverImage(await first.value) == nil); #expect(coverImage(await second.value) == nil)
    #expect(await pipeline.statistics.cached == 0); #expect(await gate.started == [a.thumbnailPath])
    #expect(coverImage(await pipeline.image(a)) == nil)
    let foreign = try coverRequest(root.appendingPathComponent("foreign"), .init(policyGeneration: policy.generation, catalogueRevision: UUID()))
    #expect(coverImage(await pipeline.image(foreign)) == nil); #expect(await gate.started.count == 1)
}

@MainActor
@Test func modelHidesWithoutFileWorkAndCancelsDisappearedCard() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let model = ArchiveCoverModel(pipeline: pipeline, policy: policy)
    let hidden = ArchiveCoverRequest(archiveRoot: root, thumbnailPath: "_index/thumbs/2023/a.jpg", context: context, showPreview: false)
    #expect(hidden == nil); model.load(hidden); #expect(await gate.started.isEmpty)
    let request = try coverRequest(root, context); model.load(request)
    let operation = try #require(model.loadTask)
    #expect(await coverEventually { await gate.started.count == 1 })
    model.cancel(); await operation.value
    #expect(model.image == nil); #expect(model.request == nil)
    await gate.releaseAll()
    #expect(await coverEventually { await pipeline.statistics.active == 0 })
    #expect(await pipeline.statistics.cached == 0)
}

@MainActor
@Test func modelRevisionAndRootReuseCannotPublishOldCoverAndCachedImageDoesNotFlash() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(policy: policy, testingLoad: { request in
        await gate.hold(request.context.catalogueRevision.uuidString)
        return coverTestImage()
    })
    let model = ArchiveCoverModel(pipeline: pipeline, policy: policy), old = try coverRequest(root, context)
    model.load(old); let oldTask = try #require(model.loadTask)
    #expect(await coverEventually { await gate.started.count == 1 })
    let freshContext = ArchiveCoverContext(policyGeneration: policy.generation, catalogueRevision: UUID())
    let fresh = try coverRequest(root, freshContext)
    #expect(model.image(for: fresh) == nil)
    model.load(fresh); let freshTask = try #require(model.loadTask)
    #expect(await coverEventually { await gate.started.count == 2 })
    await gate.release(context.catalogueRevision.uuidString); await oldTask.value
    #expect(model.image == nil)
    await gate.release(freshContext.catalogueRevision.uuidString); await freshTask.value
    #expect(model.image(for: fresh) != nil); #expect(model.image(for: old) == nil)
    var settings = makeTestSettings(root: root); settings.archiveRoot = root.appendingPathComponent("other")
    policy.update(settings: settings)
    #expect(model.image(for: fresh) == nil)
    settings.archiveRoot = root; policy.update(settings: settings)
    #expect(model.image(for: fresh) == nil)
}

@MainActor
@Test func saturatedQueueRetriesAdmissionUntilVisibleCoverCanLoad() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate(), retry = CoverGate()
    defer { Task { await gate.releaseAll(); await retry.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1, queued: 0), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let model = ArchiveCoverModel(pipeline: pipeline, policy: policy, retryAdmission: { await retry.hold("retry") })
    model.load(b); let pending = try #require(model.loadTask)
    #expect(await coverEventually { await retry.started.count == 1 })
    await gate.release(a.thumbnailPath); _ = await first.value
    await retry.releaseAll()
    #expect(await coverEventually { await gate.started.count == 2 })
    await gate.release(b.thumbnailPath); await pending.value
    #expect(model.image(for: b) != nil)
}

@Test func fullPreviewRemainsAvailableWhileCoverQueueIsBlockedAndTravelPreheatStaysDenied() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let request = try coverRequest(root, context)
    let covers = ArchiveCoverPipeline(limits: .init(active: 1), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let held = Task { await covers.image(request) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let original = root.appendingPathComponent("original.jpg"); try writeTestJPEGImage(original)
    #expect(policy.grantExplicitViewing(at: original, generation: policy.generation))
    let preview = DecodedImagePipeline(policyContext: policy)
    #expect(await preview.image(.fullSize(original)) != nil)
    #expect(await covers.statistics.active == 1)
    await gate.releaseAll(); _ = await held.value
}

@Test func visibleCoverDisplacesFullQueueSpeculation() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1, queued: 1), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b"), c = try coverRequest(root, context, "c")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let preheat = Task { await pipeline.image(b, visible: false) }
    #expect(await coverEventually { await pipeline.statistics.queued == 1 })
    let visible = Task { await pipeline.image(c) }
    #expect(await coverEventually { await pipeline.statistics.visibleQueued == 1 })
    await gate.release(a.thumbnailPath); _ = await first.value
    #expect(await coverEventually { await gate.started.count == 2 })
    #expect(await gate.started == [a.thumbnailPath, c.thumbnailPath])
    await gate.releaseAll(); #expect(coverImage(await visible.value) != nil)
    if case .deferred = await preheat.value {} else { Issue.record("Displaced speculation must receive deferred admission") }
}

@Test func coverCacheAccountsForPaddedDecodedRows() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), request = try coverRequest(root, context)
    let image = coverTestImage(bytesPerRow: 64)
    let pipeline = ArchiveCoverPipeline(limits: .init(cacheBytes: 100), policy: policy, testingLoad: { _ in image })
    _ = await pipeline.image(request)
    #expect(await pipeline.statistics.cached == 0)
    #expect(await pipeline.statistics.cachedBytes == 0)
}

@Test func coverReadDisablesDatalessMaterialisationAndRestoresThreadPolicy() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (_, context) = coverFixture(root), request = try coverRequest(root, context)
    let url = root.appendingPathComponent(request.thumbnailPath)
    try AppDirectories.ensureExists(url.deletingLastPathComponent()); try writeTestJPEGImage(url)
    let previous = getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD)
    var observed: Int32 = -1
    #expect(ArchiveCoverSource.residentJPEGData(request, beforeByteOpen: {
        observed = getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD)
    }) != nil)
    #expect(observed == IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
    #expect(getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD) == previous)
    var dataless = stat(); dataless.st_mode = mode_t(S_IFREG); dataless.st_size = 4096; dataless.st_blocks = 8; dataless.st_flags = UInt32(SF_DATALESS)
    #expect(!ArchiveCoverSource.isResidentRegularFile(dataless))
}

@Test func unavailableDatalessPolicyFailsClosedAndRestoresAfterMissingFile() throws {
    var attempted = false, values: [Int32] = []
    let absent: Int? = ArchiveCoverSource.withoutMaterialisation(getPolicy: { -1 }, setPolicy: { values.append($0); return 0 }) {
        attempted = true; return 1
    }
    #expect(absent == nil); #expect(!attempted); #expect(values.isEmpty)
    let rejected: Int? = ArchiveCoverSource.withoutMaterialisation(getPolicy: { 2 }, setPolicy: { _ in -1 }) {
        attempted = true; return 1
    }
    #expect(rejected == nil); #expect(!attempted)
    let missing: Int? = ArchiveCoverSource.withoutMaterialisation(getPolicy: { 2 }, setPolicy: { values.append($0); return 0 }) { nil }
    #expect(missing == nil); #expect(values == [IOPOL_MATERIALIZE_DATALESS_FILES_OFF, 2])
}

@Test func coverProductionLimitsStayBoundedUnderManyDistinctRequests() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate()
    defer { Task { await gate.releaseAll() } }
    let limits = ArchiveCoverPipeline.Limits(), pipeline = ArchiveCoverPipeline(policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    var tasks: [Task<ArchiveCoverLoadResult, Never>] = []
    for index in 0..<(limits.active + limits.queued) {
        let request = try coverRequest(root, context, "photo-\(index)")
        tasks.append(Task { await pipeline.image(request) })
    }
    #expect(await coverEventually { await pipeline.statistics.subscribers == limits.active + limits.queued })
    #expect(await pipeline.statistics.active == limits.active); #expect(await pipeline.statistics.queued == limits.queued)
    for index in 0..<100 {
        if case .deferred = await pipeline.image(try coverRequest(root, context, "extra-\(index)")) {} else { Issue.record("No overflow admission") }
    }
    #expect(await gate.started.count == limits.active)
    for task in tasks { task.cancel() }
    for task in tasks { _ = await task.value }
    #expect(await pipeline.statistics.active == limits.active); #expect(await pipeline.statistics.queued == 0)
    await gate.releaseAll()
    #expect(await coverEventually { await pipeline.statistics.active == 0 })
    #expect(await pipeline.statistics.cached == 0)
}

@Test func coverWorkerRejectsOversizedInjectedPixelsBeforePublication() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), request = try coverRequest(root, context)
    let pipeline = ArchiveCoverPipeline(policy: policy, testingLoad: { _ in coverTestImage(width: 513, height: 1) })
    #expect(coverImage(await pipeline.image(request)) == nil)
    #expect(await pipeline.statistics.cachedBytes == 0)
}

@MainActor
@Test func cancellingDeferredCoverModelDoesNotRetryOrReadFiles() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let (policy, context) = coverFixture(root), gate = CoverGate(), retry = CoverGate()
    defer { Task { await gate.releaseAll(); await retry.releaseAll() } }
    let pipeline = ArchiveCoverPipeline(limits: .init(active: 1, queued: 0), policy: policy, testingLoad: { request in
        await gate.hold(request.thumbnailPath); return coverTestImage()
    })
    let a = try coverRequest(root, context, "a"), b = try coverRequest(root, context, "b")
    let first = Task { await pipeline.image(a) }
    #expect(await coverEventually { await gate.started.count == 1 })
    let model = ArchiveCoverModel(pipeline: pipeline, policy: policy, retryAdmission: { await retry.hold("retry") })
    model.load(b); let pending = try #require(model.loadTask)
    #expect(await coverEventually { await retry.started.count == 1 })
    model.cancel(); await gate.releaseAll(); _ = await first.value
    await retry.releaseAll(); await pending.value
    #expect(await gate.started == [a.thumbnailPath]); #expect(model.image == nil)
}
