import Foundation
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
