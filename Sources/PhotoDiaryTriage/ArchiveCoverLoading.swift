import AppKit
import Darwin
import Foundation
import ImageIO
import SwiftUI

struct ArchiveCoverContext: Equatable, Sendable {
    var policyGeneration: Int
    var catalogueRevision: UUID
    static let inactive = ArchiveCoverContext(policyGeneration: -1, catalogueRevision: UUID())
}

private struct ArchiveCoverContextKey: EnvironmentKey {
    static let defaultValue = ArchiveCoverContext.inactive
}

extension EnvironmentValues {
    var archiveCoverContext: ArchiveCoverContext {
        get { self[ArchiveCoverContextKey.self] }
        set { self[ArchiveCoverContextKey.self] = newValue }
    }
}

struct ArchiveCoverRequest: Hashable, Sendable {
    let archiveRoot: URL
    let thumbnailPath: String
    let context: ArchiveCoverContext
    // A cover never requests an unbounded/full-size decode.
    let maxPixelSize = 512

    init?(archiveRoot: URL, thumbnailPath: String?, context: ArchiveCoverContext, showPreview: Bool) {
        guard showPreview, context.policyGeneration >= 0, let thumbnailPath,
              Self.components(thumbnailPath) != nil else { return nil }
        self.archiveRoot = archiveRoot.standardizedFileURL
        self.thumbnailPath = thumbnailPath
        self.context = context
    }

    static func components(_ path: String) -> [String]? {
        let pieces = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard pieces.count >= 3, pieces[0] == "_index", pieces[1] == "thumbs",
              path.hasSuffix(".jpg"), !pieces.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." || $0.contains("\0") }) else { return nil }
        return pieces
    }
}

extension ArchiveCoverContext: Hashable {}

enum ArchiveCoverLoadResult {
    case image(NSImage)
    case unavailable
    case deferred
}

/// A separate queue prevents covers from occupying full-size Preview's decode path.
/// Limits apply to actual workers, distinct pending keys and retained decoded bytes.
actor ArchiveCoverPipeline {
    static let shared = ArchiveCoverPipeline()

    struct Limits: Sendable {
        var active = 3
        var queued = 128
        var cacheCount = 128
        var cacheBytes = 64 * 1024 * 1024
    }
    struct Statistics: Sendable {
        let active: Int
        let queued: Int
        let visibleQueued: Int
        let subscribers: Int
        let cached: Int
        let cachedBytes: Int
    }
    private struct Job {
        let id: UUID
        let order: Int
        var visible: Bool
        var subscribers: [UUID: CheckedContinuation<ArchiveCoverLoadResult, Never>]
        var task: Task<CGImage?, Never>?
        var abandoned = false
    }
    private struct Cached {
        let image: CGImage
        let bytes: Int
        var touched: Int
    }
    private let limits: Limits
    private let policy: ArchiveByteReadPolicyContext
    private let testingLoad: (@Sendable (ArchiveCoverRequest) async -> CGImage?)?
    private var jobs: [ArchiveCoverRequest: Job] = [:]
    private var cache: [ArchiveCoverRequest: Cached] = [:]
    private var cacheBytes = 0
    private var clock = 0
    private var active = 0

    init(limits: Limits = Limits(), policy: ArchiveByteReadPolicyContext = .shared,
         testingLoad: (@Sendable (ArchiveCoverRequest) async -> CGImage?)? = nil) {
        self.limits = Limits(active: max(1, limits.active), queued: max(0, limits.queued),
                             cacheCount: max(0, limits.cacheCount), cacheBytes: max(0, limits.cacheBytes))
        self.policy = policy; self.testingLoad = testingLoad
    }

    func image(_ request: ArchiveCoverRequest, visible: Bool = true) async -> ArchiveCoverLoadResult {
        let subscriber = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled, isCurrent(request) else { continuation.resume(returning: .unavailable); return }
                if var cached = cache[request] {
                    clock += 1; cached.touched = clock; cache[request] = cached
                    continuation.resume(returning: .image(Self.displayImage(cached.image))); return
                }
                if var job = jobs[request] {
                    // A noncooperative cancelled worker still owns its slot until return.
                    guard !job.abandoned else { continuation.resume(returning: .deferred); return }
                    job.visible = job.visible || visible; job.subscribers[subscriber] = continuation
                    jobs[request] = job; drain(); return
                }
                if active >= limits.active && queuedCount >= limits.queued {
                    // Visible requests may displace queued speculation, never another
                    // visible card or an active worker. Displaced subscribers can retry.
                    guard visible, let victim = jobs.filter({ $0.value.task == nil && !$0.value.visible })
                        .min(by: { $0.value.order < $1.value.order }) else {
                        continuation.resume(returning: .deferred); return
                    }
                    jobs[victim.key] = nil
                    for subscriber in victim.value.subscribers.values { subscriber.resume(returning: .deferred) }
                }
                clock += 1
                jobs[request] = Job(id: UUID(), order: clock, visible: visible, subscribers: [subscriber: continuation])
                drain()
            }
        } onCancel: {
            Task { await self.cancel(subscriber, request: request) }
        }
    }

    var statistics: Statistics {
        Statistics(active: active, queued: queuedCount, visibleQueued: jobs.values.filter { $0.task == nil && $0.visible }.count, subscribers: jobs.values.reduce(0) { $0 + $1.subscribers.count },
                   cached: cache.count, cachedBytes: cacheBytes)
    }
    private var queuedCount: Int { jobs.values.filter { $0.task == nil }.count }
    private func isCurrent(_ request: ArchiveCoverRequest) -> Bool {
        policy.matchesArchive(root: request.archiveRoot, generation: request.context.policyGeneration)
    }
    private func cancel(_ subscriber: UUID, request: ArchiveCoverRequest) {
        guard var job = jobs[request], let continuation = job.subscribers.removeValue(forKey: subscriber) else { return }
        continuation.resume(returning: .unavailable)
        if job.subscribers.isEmpty {
            if let task = job.task {
                job.abandoned = true; task.cancel(); jobs[request] = job
            } else { jobs[request] = nil }
        } else { jobs[request] = job }
        drain()
    }
    private func drain() {
        // Reject old queued requests without performing any path checks.
        for (request, job) in jobs where job.task == nil && !isCurrent(request) {
            jobs[request] = nil
            for continuation in job.subscribers.values { continuation.resume(returning: .unavailable) }
        }
        while active < limits.active {
            let next = jobs.filter { $0.value.task == nil }.min {
                if $0.value.visible != $1.value.visible { return $0.value.visible }
                return $0.value.order < $1.value.order
            }
            guard let (request, initial) = next else { return }
            var job = initial
            let policy = policy, loader = testingLoad, id = job.id
            let task = Task.detached(priority: job.visible ? .userInitiated : .utility) {
                guard !Task.isCancelled, policy.matchesArchive(root: request.archiveRoot, generation: request.context.policyGeneration) else { return nil as CGImage? }
                let image: CGImage?
                if let loader { image = await loader(request) }
                else { image = ArchiveCoverSource.decode(request) }
                guard !Task.isCancelled, policy.matchesArchive(root: request.archiveRoot, generation: request.context.policyGeneration),
                      let image, image.width <= request.maxPixelSize, image.height <= request.maxPixelSize else { return nil }
                return image
            }
            job.task = task; jobs[request] = job; active += 1
            Task { let image = await task.value; self.finish(request, id: id, image: image) }
        }
    }
    private func finish(_ request: ArchiveCoverRequest, id: UUID, image: CGImage?) {
        guard let job = jobs[request], job.id == id else { return }
        jobs[request] = nil; active -= 1
        let accepted = !job.abandoned && isCurrent(request) ? image : nil
        if let accepted { insert(accepted, request: request) }
        for continuation in job.subscribers.values {
            continuation.resume(returning: accepted.map { .image(Self.displayImage($0)) } ?? .unavailable)
        }
        drain()
    }
    private static func displayImage(_ image: CGImage) -> NSImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
    private func insert(_ image: CGImage, request: ArchiveCoverRequest) {
        // Retain one CGImage buffer; padding is part of its actual allocation.
        let (bytes, overflow) = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
        guard !overflow, limits.cacheCount > 0, bytes <= limits.cacheBytes else { return }
        while cache.count >= limits.cacheCount || cacheBytes > limits.cacheBytes - bytes {
            guard let oldest = cache.min(by: { $0.value.touched < $1.value.touched }) else { break }
            cache.removeValue(forKey: oldest.key); cacheBytes -= oldest.value.bytes
        }
        clock += 1; cache[request] = Cached(image: image, bytes: bytes, touched: clock); cacheBytes += bytes
    }
}

/// openat + O_NOFOLLOW on every component prevents a linked thumbnail/ancestor from
/// opening an original, including a link whose destination is inside the archive.
/// The root's user-configured alias is resolved once on this background worker.
enum ArchiveCoverSource {
    static func decode(_ request: ArchiveCoverRequest) -> CGImage? {
        guard let data = residentJPEGData(request),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == "public.jpeg" else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: request.maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return image
    }

    static func residentJPEGData(_ request: ArchiveCoverRequest, beforeByteOpen: () -> Void = {}) -> Data? {
        withoutMaterialisation { readResidentJPEGData(request, beforeByteOpen: beforeByteOpen) }
    }

    // Synchronous only: the policy must be restored on this same worker thread.
    // Apple TN3150, Getting ready for dataless files. Fail closed if unavailable.
    static func withoutMaterialisation<T>(
        getPolicy: () -> Int32 = { getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD) },
        setPolicy: (Int32) -> Int32 = { setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD, $0) },
        _ body: () -> T?
    ) -> T? {
        let previous = getPolicy()
        guard previous >= 0 else { return nil }
        guard setPolicy(IOPOL_MATERIALIZE_DATALESS_FILES_OFF) == 0 else { return nil }
        let result = body()
        guard setPolicy(previous) == 0 else { return nil }
        return result
    }

    private static func readResidentJPEGData(_ request: ArchiveCoverRequest, beforeByteOpen: () -> Void) -> Data? {
        guard let components = ArchiveCoverRequest.components(request.thumbnailPath) else { return nil }
        var directory = open(request.archiveRoot.resolvingSymlinksInPath().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directory >= 0 else { return nil }
        defer { close(directory) }
        for component in components.dropLast() {
            let next = openat(directory, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard next >= 0 else { return nil }
            close(directory); directory = next
        }
        // Opening a File Provider placeholder can itself trigger hydration. Inspect
        // its resident allocation without following/opening it before obtaining bytes.
        var before = stat()
        guard fstatat(directory, components.last!, &before, AT_SYMLINK_NOFOLLOW) == 0,
              isResidentRegularFile(before) else { return nil }
        beforeByteOpen()
        let descriptor = openat(directory, components.last!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0, isResidentRegularFile(attributes),
              before.st_dev == attributes.st_dev, before.st_ino == attributes.st_ino else { return nil }
        // Read only the bounded recorded size, retaining the descriptor across validation.
        guard let data = try? handle.read(upToCount: Int(attributes.st_size)), data.count == attributes.st_size else { return nil }
        return data
    }

    static func isResidentRegularFile(_ attributes: stat) -> Bool {
        guard attributes.st_mode & S_IFMT == S_IFREG, attributes.st_flags & UInt32(SF_DATALESS) == 0, attributes.st_size > 0,
              attributes.st_size <= 16 * 1024 * 1024 else { return false }
        let allocated = attributes.st_blocks * 512
        return allocated > 0 && !(attributes.st_size > 16_384 && (allocated <= 4_096 || attributes.st_size > allocated * 16))
    }
}

@MainActor
final class ArchiveCoverModel: ObservableObject {
    @Published private(set) var image: NSImage?
    private(set) var request: ArchiveCoverRequest?
    private(set) var loadTask: Task<Void, Never>?
    private var operation = UUID()
    private let pipeline: ArchiveCoverPipeline
    private let policy: ArchiveByteReadPolicyContext
    private let retryAdmission: @Sendable () async throws -> Void

    init(pipeline: ArchiveCoverPipeline = .shared, policy: ArchiveByteReadPolicyContext = .shared,
         retryAdmission: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .milliseconds(150)) }) {
        self.pipeline = pipeline; self.policy = policy; self.retryAdmission = retryAdmission
    }
    deinit { loadTask?.cancel() }
    func load(_ next: ArchiveCoverRequest?) {
        if request == next, loadTask != nil { return }
        cancel(); request = next
        guard let next else { return }
        let token = operation, pipeline = pipeline, policy = policy, retry = retryAdmission
        loadTask = Task { [weak self] in
            while !Task.isCancelled, policy.matchesArchive(root: next.archiveRoot, generation: next.context.policyGeneration) {
                let result = await pipeline.image(next)
                guard !Task.isCancelled, let self, self.operation == token, self.request == next,
                      policy.matchesArchive(root: next.archiveRoot, generation: next.context.policyGeneration) else { return }
                switch result {
                case .image(let decoded): self.image = decoded; return
                case .unavailable: return
                case .deferred:
                    do { try await retry() } catch { return }
                }
            }
        }
    }
    func cancel() {
        operation = UUID(); loadTask?.cancel(); loadTask = nil; request = nil; image = nil
    }
    func image(for current: ArchiveCoverRequest?) -> NSImage? {
        guard current == request, let current, policy.matchesArchive(root: current.archiveRoot, generation: current.context.policyGeneration) else { return nil }
        return image
    }
}
