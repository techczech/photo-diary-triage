import AppKit
import Foundation
import ImageIO

struct DecodedImageRequest: Sendable {
    static let interactiveMaxPixelSize = 4096

    let url: URL
    let cacheKey: String
    let maxPixelSize: Int?
    let priority: TaskPriority

    static func fullSize(_ url: URL, priority: TaskPriority = .userInitiated) -> DecodedImageRequest {
        DecodedImageRequest(
            url: url,
            cacheKey: "full:\(url.path)",
            maxPixelSize: nil,
            priority: priority
        )
    }

    static func interactiveDisplay(
        _ url: URL,
        maxPixelSize: Int = interactiveMaxPixelSize,
        priority: TaskPriority = .userInitiated
    ) -> DecodedImageRequest {
        DecodedImageRequest(
            url: url,
            cacheKey: "display:\(maxPixelSize):\(url.path)",
            maxPixelSize: maxPixelSize,
            priority: priority
        )
    }
}

actor DecodedImagePipeline {
    static let shared = DecodedImagePipeline()

    private struct InFlightDecode {
        let id: UUID
        let task: Task<NSImage?, Never>
    }

    private let cache = NSCache<NSString, NSImage>()
    private var inFlightTasks: [String: InFlightDecode] = [:]

    init() {
        cache.countLimit = 96
        cache.totalCostLimit = 512 * 1024 * 1024
    }

    func image(
        at url: URL,
        cacheKey: String,
        maxPixelSize: Int? = nil,
        priority: TaskPriority = .userInitiated
    ) async -> NSImage? {
        let key = cacheKey as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        if let inFlight = inFlightTasks[cacheKey] {
            return await inFlight.task.value
        }

        let inFlight = beginDecode(
            request: DecodedImageRequest(
                url: url,
                cacheKey: cacheKey,
                maxPixelSize: maxPixelSize,
                priority: priority
            ),
            key: key
        )
        return await inFlight.task.value
    }

    func image(_ request: DecodedImageRequest) async -> NSImage? {
        await image(
            at: request.url,
            cacheKey: request.cacheKey,
            maxPixelSize: request.maxPixelSize,
            priority: request.priority
        )
    }

    func preheat(_ requests: [DecodedImageRequest]) {
        for request in requests {
            let key = request.cacheKey as NSString
            guard cache.object(forKey: key) == nil else { continue }
            guard inFlightTasks[request.cacheKey] == nil else { continue }
            _ = beginDecode(request: request, key: key)
        }
    }

    func removeCachedImage(for cacheKey: String) {
        cache.removeObject(forKey: cacheKey as NSString)
        inFlightTasks[cacheKey]?.task.cancel()
        inFlightTasks[cacheKey] = nil
    }

    private func beginDecode(request: DecodedImageRequest, key: NSString) -> InFlightDecode {
        let decodeID = UUID()
        let task = Task.detached(priority: request.priority) {
            Self.decodeImage(at: request.url, maxPixelSize: request.maxPixelSize)
        }
        let inFlight = InFlightDecode(id: decodeID, task: task)
        inFlightTasks[request.cacheKey] = inFlight

        Task {
            let image = await task.value
            self.finishDecode(cacheKey: request.cacheKey, key: key, decodeID: decodeID, image: image)
        }

        return inFlight
    }

    private func finishDecode(cacheKey: String, key: NSString, decodeID: UUID, image: NSImage?) {
        guard inFlightTasks[cacheKey]?.id == decodeID else { return }
        inFlightTasks[cacheKey] = nil

        if let image {
            cache.setObject(image, forKey: key, cost: Self.cacheCost(for: image))
        }
    }

    private static func cacheCost(for image: NSImage) -> Int {
        let representation = image.representations.first
        let width = representation?.pixelsWide ?? Int(image.size.width)
        let height = representation?.pixelsHigh ?? Int(image.size.height)
        return max(width, 1) * max(height, 1) * 4
    }

    private static func decodeImage(at url: URL, maxPixelSize: Int?) -> NSImage? {
        if FileLocalityDetector.locality(for: url).isOnlineOnly {
            return nil
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let cgImage: CGImage?
        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
            ]
            cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceShouldCacheImmediately: true
            ]
            cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
        }

        guard let cgImage else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}

@MainActor
final class DecodedImageModel: ObservableObject {
    @Published private(set) var image: NSImage?

    private var currentRequestKey: String?
    private var loadTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
    }

    func load(_ request: DecodedImageRequest) {
        guard currentRequestKey != request.cacheKey || image == nil else { return }

        currentRequestKey = request.cacheKey
        image = nil
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let decoded = await DecodedImagePipeline.shared.image(
                at: request.url,
                cacheKey: request.cacheKey,
                maxPixelSize: request.maxPixelSize,
                priority: request.priority
            )
            guard !Task.isCancelled, self.currentRequestKey == request.cacheKey else { return }
            self.image = decoded
        }
    }
}
