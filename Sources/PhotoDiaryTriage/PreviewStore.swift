import AppKit
import Foundation
import ImageIO
import OSLog
import QuickLookThumbnailing
import UniformTypeIdentifiers

final class PreviewStore: PreviewCaching {
    private let cacheRoot: URL
    private let fileManager: FileManager
    private let logger: Logger

    init(cacheRoot: URL, fileManager: FileManager = .default, logger: Logger = AppLogger.previewStore) throws {
        self.cacheRoot = cacheRoot
        self.fileManager = fileManager
        self.logger = logger
        try AppDirectories.ensureExists(cacheRoot, fileManager: fileManager)
    }

    var isPersistentCacheAvailable: Bool { true }

    func cachedThumbnailURL(for item: MediaItem) -> URL {
        cacheRoot.appendingPathComponent("\(item.thumbnailCacheKey).png")
    }

    func generateThumbnail(for item: MediaItem) async -> Bool {
        await generateThumbnail(for: item, size: CGSize(width: 320, height: 320))
    }

    func generateThumbnail(for item: MediaItem, size: CGSize = CGSize(width: 320, height: 320)) async -> Bool {
        let destinationURL = cachedThumbnailURL(for: item)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return true
        }

        if FileLocalityDetector.locality(for: item.sourceURL).isOnlineOnly {
            logger.info("Skipping thumbnail generation for online-only file \(item.sourceURL.path, privacy: .public)")
            return false
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let maxPixelSize = max(1, Int(ceil(max(size.width, size.height) * scale)))
        if generateImageIOThumbnail(for: item, destinationURL: destinationURL, maxPixelSize: maxPixelSize) {
            return true
        }

        let request = QLThumbnailGenerator.Request(fileAt: item.sourceURL, size: size, scale: scale, representationTypes: .thumbnail)

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard writeThumbnail(representation.cgImage, to: destinationURL) else {
                logger.error("Failed to encode thumbnail PNG for \(item.sourceURL.path, privacy: .public)")
                return false
            }
            return true
        } catch {
            logger.error("Failed to generate thumbnail for \(item.sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func generateImageIOThumbnail(for item: MediaItem, destinationURL: URL, maxPixelSize: Int) -> Bool {
        guard let source = CGImageSourceCreateWithURL(item.sourceURL as CFURL, nil) else {
            return false
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return false
        }
        return writeThumbnail(cgImage, to: destinationURL)
    }

    private func writeThumbnail(_ cgImage: CGImage, to destinationURL: URL) -> Bool {
        let tempURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp", isDirectory: false)
        defer {
            try? fileManager.removeItem(at: tempURL)
        }

        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return false
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: tempURL)
                return true
            }
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            return true
        } catch {
            logger.error("Failed to write thumbnail cache file \(destinationURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
