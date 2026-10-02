import AppKit
import Foundation
import OSLog
import QuickLookThumbnailing

final class PreviewStore: PreviewCaching {
    private let cacheRoot: URL
    private let fileManager: FileManager
    private let policyContext: ArchiveByteReadPolicyContext
    private let logger: Logger

    init(cacheRoot: URL, fileManager: FileManager = .default, logger: Logger = AppLogger.previewStore, policyContext: ArchiveByteReadPolicyContext = .shared) throws {
        self.cacheRoot = cacheRoot
        self.fileManager = fileManager
        self.logger = logger
        self.policyContext = policyContext
        try AppDirectories.ensureExists(cacheRoot, fileManager: fileManager)
    }

    var isPersistentCacheAvailable: Bool { true }

    func cachedThumbnailURL(for item: MediaItem) -> URL {
        if let archiveThumbnail = policyContext.indexThumbnailURLIfAvailable(for: item.sourceURL) {
            return archiveThumbnail
        }
        return cacheRoot.appendingPathComponent("\(item.thumbnailCacheKey).png")
    }

    func generateThumbnail(for item: MediaItem) async -> Bool {
        await generateThumbnail(for: item, size: CGSize(width: 320, height: 320))
    }

    func generateThumbnail(for item: MediaItem, size: CGSize = CGSize(width: 320, height: 320)) async -> Bool {
        let destinationURL = cachedThumbnailURL(for: item)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return true
        }

        guard policyContext.canGenerateImplicitThumbnail(at: item.sourceURL) else {
            logger.error("Original thumbnail generation is unavailable during travel browsing for \(item.sourceURL.path, privacy: .public)")
            return false
        }

        let request = QLThumbnailGenerator.Request(fileAt: item.sourceURL, size: size, scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail)

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard let pngData = representation.nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: pngData),
                  let data = bitmap.representation(using: .png, properties: [:]) else {
                logger.error("Failed to encode thumbnail PNG for \(item.sourceURL.path, privacy: .public)")
                return false
            }
            try data.write(to: destinationURL)
            return true
        } catch {
            logger.error("Failed to generate thumbnail for \(item.sourceURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
