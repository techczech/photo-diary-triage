import AppKit
import Foundation
import ImageIO

struct DecodedImageRequest {
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
}

actor DecodedImagePipeline {
    static let shared = DecodedImagePipeline()

    private let cache = NSCache<NSString, NSImage>()
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]

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
            return await inFlight.value
        }

        let task = Task.detached(priority: priority) {
            Self.decodeImage(at: url, maxPixelSize: maxPixelSize)
        }
        inFlightTasks[cacheKey] = task

        let image = await task.value
        inFlightTasks[cacheKey] = nil

        if let image {
            cache.setObject(image, forKey: key)
        }

        return image
    }

    func removeCachedImage(for cacheKey: String) {
        cache.removeObject(forKey: cacheKey as NSString)
        inFlightTasks[cacheKey]?.cancel()
        inFlightTasks[cacheKey] = nil
    }

    private static func decodeImage(at url: URL, maxPixelSize: Int?) -> NSImage? {
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
