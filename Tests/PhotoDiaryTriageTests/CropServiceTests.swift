import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PhotoDiaryTriage

@Test func cropServiceWritesNumberedCopyAndAppendsManifest() throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("IMG_0001.jpg")
    try writeTestImage(sourceURL, width: 100, height: 80)

    let item = MediaItem(
        sourceURL: sourceURL,
        relativePath: "IMG_0001.jpg",
        fileName: "IMG_0001.jpg",
        baseName: "IMG_0001",
        mediaKind: .jpeg,
        fileSizeBytes: Int64((try Data(contentsOf: sourceURL)).count),
        capturedAt: Date(timeIntervalSince1970: 0),
        metadata: MediaMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            pixelWidth: 100,
            pixelHeight: 80,
            cameraModel: nil,
            lensModel: nil,
            latitude: nil,
            longitude: nil,
            raw: [:]
        ),
        thumbnailCacheKey: "crop-test"
    )
    let release = AppRelease(version: "test", build: "1", featureSlug: "crop-test")
    let service = CropService()
    let rect = CropNormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    let first = try service.crop(item: item, normalizedRect: rect, trigger: .visibleZoom, appRelease: release)
    let second = try service.crop(item: item, normalizedRect: rect, trigger: .manualDrag, appRelease: release)

    #expect(first.outputURL.lastPathComponent == "IMG_0001-cropped.jpg")
    #expect(second.outputURL.lastPathComponent == "IMG_0001-cropped-2.jpg")
    #expect(first.outputWidth == 50)
    #expect(first.outputHeight == 40)
    #expect(FileManager.default.fileExists(atPath: first.outputURL.path))
    #expect(FileManager.default.fileExists(atPath: second.outputURL.path))

    let manifestData = try Data(contentsOf: first.manifestURL)
    let manifest = try JSONDecoder().decode(CropManifest.self, from: manifestData)
    #expect(manifest.sourcePath == sourceURL.path)
    #expect(manifest.crops.count == 2)
    #expect(manifest.crops.map(\.trigger) == [.visibleZoom, .manualDrag])
    #expect(manifest.crops[0].pixelRect == CropPixelRect(x: 25, y: 20, width: 50, height: 40))
    #expect(manifest.crops[0].appVersion == "test")
}

@Test func fileScannerMarksOriginalAndCropFromManifest() throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("IMG_0001.jpg")
    try writeTestImage(sourceURL, width: 100, height: 80)
    let item = MediaItem(
        sourceURL: sourceURL,
        relativePath: "IMG_0001.jpg",
        fileName: "IMG_0001.jpg",
        baseName: "IMG_0001",
        mediaKind: .jpeg,
        fileSizeBytes: Int64((try Data(contentsOf: sourceURL)).count),
        capturedAt: Date(timeIntervalSince1970: 0),
        metadata: makeTestMetadata(capturedAt: Date(timeIntervalSince1970: 0)),
        thumbnailCacheKey: "crop-scan"
    )
    _ = try CropService().crop(
        item: item,
        normalizedRect: CropNormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
        trigger: .visibleZoom,
        appRelease: AppRelease(version: "test", build: "1", featureSlug: "crop-scan")
    )

    let scanned = try FileScanner().scanFolder(root, settings: makeTestSettings(root: root))
    let original = try #require(scanned.first)
    let crop = try #require(scanned.last)

    #expect(scanned.map(\.fileName) == ["IMG_0001.jpg", "IMG_0001-cropped.jpg"])
    #expect(crop.cropRelationship?.role == .crop)
    #expect(crop.cropRelationship?.originalRelativePath == "IMG_0001.jpg")
    #expect(original.cropRelationship?.role == .original)
    #expect(original.cropRelationship?.cropRelativePaths == ["IMG_0001-cropped.jpg"])
    #expect(original.cropRelationship?.latestCropFileName == "IMG_0001-cropped.jpg")
}

@MainActor
@Test func cropMediaItemAddsOutputToReviewAndShowsCropImmediately() async throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("IMG_0001.jpg")
    try writeTestJPEGImage(sourceURL, width: 100, height: 80)
    let item = MediaItem(
        sourceURL: sourceURL,
        relativePath: "IMG_0001.jpg",
        fileName: "IMG_0001.jpg",
        baseName: "IMG_0001",
        mediaKind: .jpeg,
        fileSizeBytes: Int64((try Data(contentsOf: sourceURL)).count),
        capturedAt: Date(timeIntervalSince1970: 0),
        metadata: makeTestMetadata(capturedAt: Date(timeIntervalSince1970: 0)),
        thumbnailCacheKey: "crop-app-state"
    )
    let state = AppState(testing: true)
    state.currentSession = makeTestSession(
        sourceRoot: root,
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        items: [item]
    )
    state.setWorkspaceMode(.cameraTriage)
    if let leafID = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.contains(item.id) })?.id {
        state.selectedSidebarNodeID = leafID
    }
    state.previewingMediaItemID = item.id

    state.cropMediaItem(
        item,
        normalizedRect: CropNormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
        trigger: .visibleZoom
    )

    let didIntegrateCrop = await waitForCondition {
        state.currentSession?.mediaItems.count == 2 && !state.isCropInProgress(for: item)
    }
    #expect(didIntegrateCrop)
    let session = try #require(state.currentSession)
    let original = try #require(session.mediaItems.first { $0.fileName == "IMG_0001.jpg" })
    let crop = try #require(session.mediaItems.first { $0.fileName == "IMG_0001-cropped.jpg" })

    #expect(original.cropRelationship?.role == .original)
    #expect(original.cropRelationship?.latestCropRelativePath == "IMG_0001-cropped.jpg")
    #expect(crop.cropRelationship?.role == .crop)
    #expect(crop.cropRelationship?.originalRelativePath == "IMG_0001.jpg")
    #expect(state.previewingMediaItemID == crop.id)
    #expect(state.focusedReviewItemID == crop.id)
    #expect(state.selectedMediaItemIDs == Set([crop.id]))
    #expect(state.statusMessage.contains("showing cropped version"))

    state.setReviewFilter(.cropped)
    let croppedFileNames = state.visibleMediaItems.map(\.fileName)
    #expect(croppedFileNames.contains("IMG_0001-cropped.jpg"))
    #expect(croppedFileNames.contains("IMG_0001.jpg"))
}

@Test func cleanupKeepsOriginalWhenCropExists() async throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("IMG_0002.jpg")
    let cropURL = root.appendingPathComponent("IMG_0002-cropped.jpg")
    try writeTestFile(sourceURL, contents: "original")
    try writeTestFile(cropURL, contents: "crop")
    var item = makeTestMediaItem(
        sourceRoot: root,
        fileName: "IMG_0002.jpg",
        capturedAt: Date(timeIntervalSince1970: 0),
        selectionState: .included,
        lifecycleState: .sourceCleanupPending
    )
    item.cropRelationship = CropRelationship(
        role: .original,
        originalRelativePath: "IMG_0002.jpg",
        originalFileName: "IMG_0002.jpg",
        cropRelativePaths: ["IMG_0002-cropped.jpg"],
        cropFileNames: ["IMG_0002-cropped.jpg"],
        manifestRelativePath: "IMG_0002.crops.json",
        latestCropRelativePath: "IMG_0002-cropped.jpg",
        latestCropFileName: "IMG_0002-cropped.jpg"
    )
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let session = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [item],
        backupConfirmedAt: Date(timeIntervalSince1970: 10),
        sessionKind: .walkDraft,
        status: "source_cleanup_pending"
    )

    let cleaned = try await ImportCoordinator().cleanupImportedSources(in: session)

    #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    #expect(FileManager.default.fileExists(atPath: cropURL.path))
    #expect(cleaned.mediaItems.first?.lifecycleState == .sourceCleanupPending)
    #expect(cleaned.status == "source_cleanup_pending")
}

@Test func normalizedCropRectClampsToSourcePixels() {
    let rect = CropNormalizedRect(x: 0.9, y: 0.9, width: 0.5, height: 0.5)
    #expect(rect == CropNormalizedRect(x: 0.9, y: 0.9, width: 0.1, height: 0.1))
    #expect(rect.pixelRect(sourceWidth: 100, sourceHeight: 80) == CropPixelRect(x: 90, y: 72, width: 10, height: 8))
}

@Test func cropGeometryMapperMapsCenteredVisibleViewport() throws {
    let rect = try #require(CropGeometryMapper.normalizedCropRect(
        documentRect: CGRect(x: 200, y: 150, width: 400, height: 300),
        imageSize: CGSize(width: 400, height: 300),
        documentSize: CGSize(width: 800, height: 600)
    ))

    #expect(rect == CropNormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
}

@Test func cropGeometryMapperUsesTopLeftNormalizedY() throws {
    let topLeftQuarter = try #require(CropGeometryMapper.normalizedCropRect(
        documentRect: CGRect(x: 0, y: 300, width: 400, height: 300),
        imageSize: CGSize(width: 400, height: 300),
        documentSize: CGSize(width: 800, height: 600)
    ))
    let bottomLeftQuarter = try #require(CropGeometryMapper.normalizedCropRect(
        documentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
        imageSize: CGSize(width: 400, height: 300),
        documentSize: CGSize(width: 800, height: 600)
    ))

    #expect(topLeftQuarter == CropNormalizedRect(x: 0, y: 0, width: 0.5, height: 0.5))
    #expect(bottomLeftQuarter == CropNormalizedRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
}

@Test func cropGeometryMapperStandardizesManualDragRect() throws {
    let documentRect = CropGeometryMapper.standardizedDocumentRect(
        start: CGPoint(x: 80, y: 450),
        end: CGPoint(x: 400, y: 150),
        documentSize: CGSize(width: 800, height: 600)
    )
    let rect = try #require(CropGeometryMapper.normalizedCropRect(
        documentRect: documentRect,
        imageSize: CGSize(width: 400, height: 300),
        documentSize: CGSize(width: 800, height: 600)
    ))

    #expect(documentRect == CGRect(x: 80, y: 150, width: 320, height: 300))
    #expect(rect == CropNormalizedRect(x: 0.1, y: 0.25, width: 0.4, height: 0.5))
}

@Test func cropGeometryMapperMarksTinyManualDragUnusable() throws {
    let documentRect = CropGeometryMapper.standardizedDocumentRect(
        start: CGPoint(x: 200, y: 200),
        end: CGPoint(x: 205, y: 205),
        documentSize: CGSize(width: 800, height: 600)
    )
    let rect = try #require(CropGeometryMapper.normalizedCropRect(
        documentRect: documentRect,
        imageSize: CGSize(width: 400, height: 300),
        documentSize: CGSize(width: 800, height: 600)
    ))

    #expect(rect.isUsableCrop == false)
}

@Test func cropServiceWritesPixelsFromMappedTopLeftRectangle() throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("GRID.png")
    try writeTestGridPNGImage(sourceURL, width: 10, height: 8)
    let item = MediaItem(
        sourceURL: sourceURL,
        relativePath: "GRID.png",
        fileName: "GRID.png",
        baseName: "GRID",
        mediaKind: .other,
        fileSizeBytes: Int64((try Data(contentsOf: sourceURL)).count),
        capturedAt: Date(timeIntervalSince1970: 0),
        metadata: MediaMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            pixelWidth: 10,
            pixelHeight: 8,
            cameraModel: nil,
            lensModel: nil,
            latitude: nil,
            longitude: nil,
            raw: [:]
        ),
        thumbnailCacheKey: "crop-grid"
    )

    let result = try CropService().crop(
        item: item,
        normalizedRect: CropNormalizedRect(x: 0.2, y: 0.25, width: 0.5, height: 0.5),
        trigger: .visibleZoom,
        appRelease: AppRelease(version: "test", build: "1", featureSlug: "crop-grid")
    )

    #expect(result.pixelRect == CropPixelRect(x: 2, y: 2, width: 5, height: 4))
    #expect(result.outputWidth == 5)
    #expect(result.outputHeight == 4)
    #expect(try samplePixel(at: result.outputURL, x: 0, y: 0) == TestPixel(red: 20, green: 40, blue: 180, alpha: 255))
    #expect(try samplePixel(at: result.outputURL, x: 4, y: 3) == TestPixel(red: 60, green: 100, blue: 180, alpha: 255))
}

@Test func cropServiceCleansTemporaryFileAndFallsBackToBoundedJpegOutput() throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("GRID.source")
    try writeTestGridPNGImage(sourceURL, width: 60, height: 40)
    let item = MediaItem(
        sourceURL: sourceURL,
        relativePath: "GRID.source",
        fileName: "GRID.source",
        baseName: "GRID",
        mediaKind: .other,
        fileSizeBytes: Int64((try Data(contentsOf: sourceURL)).count),
        capturedAt: Date(timeIntervalSince1970: 0),
        metadata: MediaMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            pixelWidth: 60,
            pixelHeight: 40,
            cameraModel: nil,
            lensModel: nil,
            latitude: nil,
            longitude: nil,
            raw: [:]
        ),
        thumbnailCacheKey: "crop-temp"
    )

    let result = try CropService().crop(
        item: item,
        normalizedRect: CropNormalizedRect(x: 0.1, y: 0.1, width: 0.6, height: 0.6),
        trigger: .manualDrag,
        appRelease: AppRelease(version: "test", build: "1", featureSlug: "crop-temp")
    )

    let siblingNames = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(result.outputURL.pathExtension == "jpg")
    #expect(result.outputWidth == 36)
    #expect(result.outputHeight == 24)
    #expect(!siblingNames.contains { $0.hasPrefix(".GRID-cropped-") && $0.contains(".tmp") })
    #expect((try Data(contentsOf: result.outputURL)).count < 250_000)
}

@Test func cropServiceRemovesOutputWhenManifestWriteFails() throws {
    let root = try makeTemporaryDirectory()
    let sourceURL = root.appendingPathComponent("IMG_0003.jpg")
    let manifestURL = root.appendingPathComponent("IMG_0003.crops.json", isDirectory: true)
    let expectedOutputURL = root.appendingPathComponent("IMG_0003-cropped.jpg")
    try writeTestJPEGImage(sourceURL, width: 100, height: 80)
    try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: false)
    let item = MediaItem(
        sourceURL: sourceURL,
        relativePath: "IMG_0003.jpg",
        fileName: "IMG_0003.jpg",
        baseName: "IMG_0003",
        mediaKind: .jpeg,
        fileSizeBytes: Int64((try Data(contentsOf: sourceURL)).count),
        capturedAt: Date(timeIntervalSince1970: 0),
        metadata: makeTestMetadata(capturedAt: Date(timeIntervalSince1970: 0)),
        thumbnailCacheKey: "crop-manifest-failure"
    )

    do {
        _ = try CropService().crop(
            item: item,
            normalizedRect: CropNormalizedRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5),
            trigger: .visibleZoom,
            appRelease: AppRelease(version: "test", build: "1", featureSlug: "crop-manifest-failure")
        )
        Issue.record("Expected crop manifest write failure.")
    } catch CropServiceError.cannotWriteManifest(let path) {
        #expect(path == manifestURL.path)
    } catch {
        Issue.record("Unexpected crop error: \(error)")
    }

    let siblingNames = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(!FileManager.default.fileExists(atPath: expectedOutputURL.path))
    #expect(!siblingNames.contains { $0.hasPrefix(".IMG_0003-cropped-") && $0.contains(".tmp") })
}

@MainActor
private func waitForCondition(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}

private func writeTestImage(_ url: URL, width: Int, height: Int) throws {
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let offset = ((y * width) + x) * 4
            pixels[offset] = UInt8(x % 255)
            pixels[offset + 1] = UInt8(y % 255)
            pixels[offset + 2] = 180
            pixels[offset + 3] = 255
        }
    }

    let data = Data(pixels)
    let provider = try #require(CGDataProvider(data: data as CFData))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    let image = try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ))
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private struct TestPixel: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

private func writeTestGridPNGImage(_ url: URL, width: Int, height: Int) throws {
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let offset = ((y * width) + x) * 4
            pixels[offset] = UInt8(min(x * 10, 255))
            pixels[offset + 1] = UInt8(min(y * 20, 255))
            pixels[offset + 2] = 180
            pixels[offset + 3] = 255
        }
    }
    try writeRGBAImage(url, width: width, height: height, pixels: pixels, typeIdentifier: UTType.png.identifier)
}

private func samplePixel(at url: URL, x: Int, y: Int) throws -> TestPixel {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let width = image.width
    let height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = try #require(CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    let clampedX = min(max(x, 0), width - 1)
    let clampedY = min(max(y, 0), height - 1)
    let offset = ((clampedY * width) + clampedX) * 4
    return TestPixel(
        red: pixels[offset],
        green: pixels[offset + 1],
        blue: pixels[offset + 2],
        alpha: pixels[offset + 3]
    )
}

private func writeRGBAImage(
    _ url: URL,
    width: Int,
    height: Int,
    pixels: [UInt8],
    typeIdentifier: String
) throws {
    let data = Data(pixels)
    let provider = try #require(CGDataProvider(data: data as CFData))
    let image = try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ))
    let destination = try #require(CGImageDestinationCreateWithURL(
        url as CFURL,
        typeIdentifier as CFString,
        1,
        nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}
