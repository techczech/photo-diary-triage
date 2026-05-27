import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PhotoDiaryTriage

func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    return url
}

func makeTestSettings(root: URL) -> AppSettings {
    AppSettings(
        defaultSourceRoot: root.appendingPathComponent("source-default", isDirectory: true),
        archiveRoot: root.appendingPathComponent("archive", isDirectory: true),
        oneDrivePicturesRoot: root.appendingPathComponent("archive", isDirectory: true),
        archiveMachineRole: .mainArchive,
        cacheRoot: root.appendingPathComponent("cache", isDirectory: true),
        supportedExtensions: ["jpg", "jpeg", "cr3", "cr2", "dng"],
        burstThresholdSeconds: 2,
        proximityThresholdSeconds: 600,
        cleanupRequiresBackupConfirmation: true,
        reviewPresentationMode: .grid,
        reviewGridColumnCount: ReviewGridMetrics.defaultRequestedColumnCount()
    )
}

func makeTestMetadata(capturedAt: Date) -> MediaMetadata {
    MediaMetadata(
        capturedAt: capturedAt,
        pixelWidth: 4000,
        pixelHeight: 3000,
        cameraModel: "Test Camera",
        lensModel: "Test Lens",
        latitude: nil,
        longitude: nil,
        raw: [:]
    )
}

func writeTestJPEGImage(_ url: URL, width: Int = 100, height: Int = 80) throws {
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

@discardableResult
func writeTestFile(_ url: URL, contents: String = UUID().uuidString) throws -> Int64 {
    try AppDirectories.ensureExists(url.deletingLastPathComponent())
    let data = contents.data(using: .utf8) ?? Data()
    try data.write(to: url)
    return Int64(data.count)
}

func makeTestCompanionFile(sourceRoot: URL, fileName: String) -> CompanionFile {
    let url = sourceRoot.appendingPathComponent(fileName)
    let fileSize = (try? Data(contentsOf: url).count).map(Int64.init) ?? 1
    return CompanionFile(
        sourceURL: url,
        relativePath: fileName,
        fileName: fileName,
        fileSizeBytes: fileSize,
        kind: .raw
    )
}

func makeTestMediaItem(
    sourceRoot: URL,
    fileName: String,
    capturedAt: Date,
    selectionState: SelectionState = .undecided,
    importRawCompanions: Bool = false,
    companionFiles: [CompanionFile] = [],
    lifecycleState: LifecycleState = .discovered
) -> MediaItem {
    let sourceURL = sourceRoot.appendingPathComponent(fileName)
    let fileSize = (try? Data(contentsOf: sourceURL).count).map(Int64.init) ?? 1

    return MediaItem(
        sourceURL: sourceURL,
        relativePath: fileName,
        fileName: fileName,
        baseName: sourceURL.deletingPathExtension().lastPathComponent,
        mediaKind: .jpeg,
        fileSizeBytes: fileSize,
        capturedAt: capturedAt,
        metadata: makeTestMetadata(capturedAt: capturedAt),
        thumbnailCacheKey: UUID().uuidString,
        selectionState: selectionState,
        importRawCompanions: importRawCompanions,
        companionFiles: companionFiles,
        lifecycleState: lifecycleState
    )
}

func makeTestSession(
    sourceRoot: URL,
    archiveRoot: URL,
    items: [MediaItem],
    title: String = "Test Walk",
    location: String = "Bristol",
    notes: String = "Test notes",
    backupConfirmedAt: Date? = nil,
    workspaceSourceFolder: URL? = nil,
    sessionKind: SessionKind = .walkDraft,
    status: String = "draft"
) -> ImportSession {
    var session = ImportSession(
        sourceFolder: sourceRoot,
        workspaceSourceFolder: workspaceSourceFolder ?? sourceRoot,
        archiveRoot: archiveRoot,
        oneDrivePicturesRoot: archiveRoot,
        sessionKind: sessionKind,
        status: status
    )
    session.walkMetadata.title = title
    session.walkMetadata.location = location
    session.walkMetadata.notes = notes
    session.walkMetadata.backupConfirmedAt = backupConfirmedAt
    session.mediaItems = items
    return session
}
