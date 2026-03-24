import Foundation
import ImageIO

struct MetadataExtractor {
    private let logger = AppLogger.metadataExtractor

    func extract(from url: URL) -> MediaMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            logger.error("Failed to read metadata for \(url.path, privacy: .public)")
            return MediaMetadata(capturedAt: nil, pixelWidth: nil, pixelHeight: nil, cameraModel: nil, lensModel: nil, latitude: nil, longitude: nil, raw: [:])
        }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        let capturedAt = parseCapturedDate(exif: exif, tiff: tiff)
        let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
        let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
        let cameraModel = tiff?[kCGImagePropertyTIFFModel] as? String
        let lensModel = exif?[kCGImagePropertyExifLensModel] as? String
        let latitude = gps?[kCGImagePropertyGPSLatitude] as? Double
        let longitude = gps?[kCGImagePropertyGPSLongitude] as? Double

        var raw: [String: String] = [:]
        for (key, value) in properties {
            raw[String(describing: key)] = String(describing: value)
        }

        return MediaMetadata(
            capturedAt: capturedAt,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            cameraModel: cameraModel,
            lensModel: lensModel,
            latitude: latitude,
            longitude: longitude,
            raw: raw
        )
    }

    private func parseCapturedDate(exif: [CFString: Any]?, tiff: [CFString: Any]?) -> Date? {
        let candidates: [Any?] = [
            exif?[kCGImagePropertyExifDateTimeOriginal],
            exif?[kCGImagePropertyExifDateTimeDigitized],
            tiff?[kCGImagePropertyTIFFDateTime]
        ]

        for candidate in candidates {
            if let string = candidate as? String, let date = Self.makeExifDateFormatter().date(from: string) {
                return date
            }
        }

        return nil
    }

    private static func makeExifDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }
}
