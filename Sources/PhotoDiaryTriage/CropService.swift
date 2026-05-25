import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CropTrigger: String, Codable, Sendable {
    case visibleZoom = "visible_zoom"
    case manualDrag = "manual_drag"
}

struct CropNormalizedRect: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let fullFrame = CropNormalizedRect(x: 0, y: 0, width: 1, height: 1)

    init(x: Double, y: Double, width: Double, height: Double) {
        let clampedX = min(max(x, 0), 1)
        let clampedY = min(max(y, 0), 1)
        self.x = clampedX
        self.y = clampedY
        self.width = min(max(width, 0), 1 - clampedX)
        self.height = min(max(height, 0), 1 - clampedY)
    }

    var isUsableCrop: Bool {
        width > 0.01 && height > 0.01
    }

    var isEffectivelyFullFrame: Bool {
        x <= 0.002 && y <= 0.002 && width >= 0.996 && height >= 0.996
    }

    func pixelRect(sourceWidth: Int, sourceHeight: Int) -> CropPixelRect {
        let sourceWidth = max(sourceWidth, 1)
        let sourceHeight = max(sourceHeight, 1)
        let rawX = Int((x * Double(sourceWidth)).rounded(.down))
        let rawY = Int((y * Double(sourceHeight)).rounded(.down))
        let rawWidth = Int((width * Double(sourceWidth)).rounded())
        let rawHeight = Int((height * Double(sourceHeight)).rounded())
        let clampedX = min(max(rawX, 0), sourceWidth - 1)
        let clampedY = min(max(rawY, 0), sourceHeight - 1)
        let clampedWidth = min(max(rawWidth, 1), sourceWidth - clampedX)
        let clampedHeight = min(max(rawHeight, 1), sourceHeight - clampedY)

        return CropPixelRect(
            x: clampedX,
            y: clampedY,
            width: clampedWidth,
            height: clampedHeight
        )
    }
}

struct CropPixelRect: Codable, Equatable, Sendable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct CropResult: Equatable, Sendable {
    let outputURL: URL
    let manifestURL: URL
    let pixelRect: CropPixelRect
    let outputWidth: Int
    let outputHeight: Int
}

struct CropManifest: Codable, Sendable {
    var sourcePath: String
    var sourceFileName: String
    var sourceMediaItemID: UUID
    var crops: [CropManifestEntry]
}

struct CropManifestEntry: Codable, Sendable {
    var id: UUID
    var createdAt: String
    var trigger: CropTrigger
    var outputPath: String
    var outputFileName: String
    var outputTypeIdentifier: String
    var sourcePixelWidth: Int
    var sourcePixelHeight: Int
    var outputPixelWidth: Int
    var outputPixelHeight: Int
    var normalizedRect: CropNormalizedRect
    var pixelRect: CropPixelRect
    var appVersion: String
    var appBuild: String
    var featureSlug: String
}

enum CropServiceError: LocalizedError, Equatable {
    case unusableCrop
    case cannotReadSource(String)
    case cannotDecodeImage(String)
    case cannotCreateCrop
    case cannotCreateDestination(String)
    case cannotWriteDestination(String)
    case cannotWriteManifest(String)

    var errorDescription: String? {
        switch self {
        case .unusableCrop:
            return "Crop area is too small."
        case .cannotReadSource(let path):
            return "Could not read source image at \(path)."
        case .cannotDecodeImage(let path):
            return "Could not decode source image at \(path)."
        case .cannotCreateCrop:
            return "Could not create the cropped image."
        case .cannotCreateDestination(let path):
            return "Could not create crop output at \(path)."
        case .cannotWriteDestination(let path):
            return "Could not write crop output at \(path)."
        case .cannotWriteManifest(let path):
            return "Could not write crop manifest at \(path)."
        }
    }
}

struct CropService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func crop(
        item: MediaItem,
        normalizedRect: CropNormalizedRect,
        trigger: CropTrigger,
        appRelease: AppRelease = .current
    ) throws -> CropResult {
        guard normalizedRect.isUsableCrop else {
            throw CropServiceError.unusableCrop
        }

        let sourceURL = item.sourceURL
        guard fileManager.fileExists(atPath: sourceURL.path),
              let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw CropServiceError.cannotReadSource(sourceURL.path)
        }

        guard let fullImage = makeOrientationAppliedImage(from: source) else {
            throw CropServiceError.cannotDecodeImage(sourceURL.path)
        }

        let pixelRect = normalizedRect.pixelRect(sourceWidth: fullImage.width, sourceHeight: fullImage.height)
        guard let croppedImage = fullImage.cropping(to: pixelRect.cgRect) else {
            throw CropServiceError.cannotCreateCrop
        }

        let output = outputTarget(for: sourceURL)
        let destinationURL = uniqueDestinationURL(
            sourceURL: sourceURL,
            outputExtension: output.fileExtension
        )
        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            output.typeIdentifier as CFString,
            1,
            nil
        ) else {
            throw CropServiceError.cannotCreateDestination(destinationURL.path)
        }

        let properties = destinationProperties(
            from: source,
            outputWidth: croppedImage.width,
            outputHeight: croppedImage.height
        )
        CGImageDestinationAddImage(destination, croppedImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw CropServiceError.cannotWriteDestination(destinationURL.path)
        }

        let manifestURL = cropManifestURL(for: sourceURL)
        let entry = CropManifestEntry(
            id: UUID(),
            createdAt: DateFormatting.iso8601.string(from: Date()),
            trigger: trigger,
            outputPath: destinationURL.path,
            outputFileName: destinationURL.lastPathComponent,
            outputTypeIdentifier: output.typeIdentifier,
            sourcePixelWidth: fullImage.width,
            sourcePixelHeight: fullImage.height,
            outputPixelWidth: croppedImage.width,
            outputPixelHeight: croppedImage.height,
            normalizedRect: normalizedRect,
            pixelRect: pixelRect,
            appVersion: appRelease.version,
            appBuild: appRelease.build,
            featureSlug: appRelease.featureSlug
        )

        do {
            try appendManifestEntry(entry, for: item, manifestURL: manifestURL)
        } catch {
            throw CropServiceError.cannotWriteManifest(manifestURL.path)
        }

        return CropResult(
            outputURL: destinationURL,
            manifestURL: manifestURL,
            pixelRect: pixelRect,
            outputWidth: croppedImage.width,
            outputHeight: croppedImage.height
        )
    }

    private func makeOrientationAppliedImage(from source: CGImageSource) -> CGImage? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let maxPixelSize = max(width, height, 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func destinationProperties(
        from source: CGImageSource,
        outputWidth: Int,
        outputHeight: Int
    ) -> [CFString: Any] {
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        properties[kCGImagePropertyPixelWidth] = outputWidth
        properties[kCGImagePropertyPixelHeight] = outputHeight
        properties[kCGImagePropertyOrientation] = 1
        properties[kCGImageDestinationLossyCompressionQuality] = 1.0
        return properties
    }

    private func appendManifestEntry(
        _ entry: CropManifestEntry,
        for item: MediaItem,
        manifestURL: URL
    ) throws {
        var manifest = try existingManifest(at: manifestURL) ?? CropManifest(
            sourcePath: item.sourceURL.path,
            sourceFileName: item.fileName,
            sourceMediaItemID: item.id,
            crops: []
        )
        manifest.sourcePath = item.sourceURL.path
        manifest.sourceFileName = item.fileName
        manifest.sourceMediaItemID = item.id
        manifest.crops.append(entry)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func existingManifest(at manifestURL: URL) throws -> CropManifest? {
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(CropManifest.self, from: data)
    }

    private func outputTarget(for sourceURL: URL) -> (typeIdentifier: String, fileExtension: String) {
        switch sourceURL.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return (UTType.jpeg.identifier, "jpg")
        case "heic":
            return (UTType.heic.identifier, "heic")
        case "png":
            return (UTType.png.identifier, "png")
        case "tif", "tiff":
            return (UTType.tiff.identifier, "tiff")
        default:
            return (UTType.tiff.identifier, "tiff")
        }
    }

    private func uniqueDestinationURL(sourceURL: URL, outputExtension: String) -> URL {
        let folder = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let first = folder.appendingPathComponent("\(baseName)-cropped").appendingPathExtension(outputExtension)
        guard fileManager.fileExists(atPath: first.path) else {
            return first
        }

        var index = 2
        while true {
            let candidate = folder
                .appendingPathComponent("\(baseName)-cropped-\(index)")
                .appendingPathExtension(outputExtension)
            if fileManager.fileExists(atPath: candidate.path) == false {
                return candidate
            }
            index += 1
        }
    }

    private func cropManifestURL(for sourceURL: URL) -> URL {
        sourceURL
            .deletingPathExtension()
            .appendingPathExtension("crops.json")
    }
}
