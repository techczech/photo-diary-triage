import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func archiveIndexRebuildsEntriesFromWalkFolderManifests() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let tripFolder = archiveRoot.appendingPathComponent("2026/05-May", isDirectory: true)
    let walkFolder = tripFolder.appendingPathComponent("23-Sat-Morning", isDirectory: true)
    try FileManager.default.createDirectory(at: walkFolder, withIntermediateDirectories: true)

    let photoURL = walkFolder.appendingPathComponent("2026-05-23-morning-001.jpg")
    try writeTestFile(photoURL, contents: "jpeg")
    let thumbnailURL = ArchiveIndexStore.thumbnailURL(for: photoURL, archiveRoot: archiveRoot)
    try writeTestFile(thumbnailURL, contents: "thumb")
    let expectedThumbnailPath = try #require(ArchiveIndexStore.thumbnailRelativePath(for: photoURL, archiveRoot: archiveRoot))
    let capturedAt = Date(timeIntervalSince1970: 1_779_532_200)
    let fileManifest = FileManifest(
        mediaItemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        archivePath: photoURL.path,
        archiveRelativePath: "2026/05-May/23-Sat-Morning/2026-05-23-morning-001.jpg",
        sourceFileName: "IMG_0001.jpg",
        companionArchivePaths: [],
        companionArchiveRelativePaths: [],
        capturedAt: capturedAt,
        cameraModel: "Canon Test",
        lensModel: "Test Lens",
        pixelWidth: 4000,
        pixelHeight: 3000,
        latitude: nil,
        longitude: nil,
        walkTitle: "Morning",
        walkLocation: "Oxford",
        notes: "Keeper note"
    )
    let walkManifest = WalkManifest(
        sessionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        walkID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        tripFolderRelativePath: "2026/05-May",
        walkDate: capturedAt,
        sourceFolder: root.appendingPathComponent("source", isDirectory: true),
        archiveFolder: walkFolder,
        archiveFolderRelativePath: "2026/05-May/23-Sat-Morning",
        title: "Morning",
        location: "Oxford",
        notes: "Walk note",
        summary: .init(
            totalSourceFiles: 1,
            visibleItems: 1,
            importedFiles: 1,
            excludedFiles: 0,
            candidateFiles: 0,
            undecidedFiles: 0,
            skippedFiles: 0,
            cleanupPendingFiles: 0,
            cleanedSourceFiles: 0
        ),
        importedFiles: [fileManifest],
        excludedFiles: []
    )
    let tripManifest = TripManifest(
        tripID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        title: "May",
        folder: tripFolder,
        folderRelativePath: "2026/05-May",
        startDate: capturedAt,
        endDate: capturedAt,
        memberWalkFolderPaths: ["2026/05-May/23-Sat-Morning"]
    )
    let renderer = ManifestRenderer()
    try renderer.renderTripManifest(tripManifest)
        .write(to: tripFolder.appendingPathComponent("05-May.md"), atomically: true, encoding: .utf8)
    try renderer.renderWalkManifest(walkManifest)
        .write(to: walkFolder.appendingPathComponent("23-Sat-Morning.md"), atomically: true, encoding: .utf8)
    try renderer.renderFileManifest(fileManifest)
        .write(to: walkFolder.appendingPathComponent("2026-05-23-morning-001.md"), atomically: true, encoding: .utf8)

    let result = try ArchiveIndexStore().rebuildIndex(archiveRoot: archiveRoot)
    let entries = try readIndexEntries(archiveRoot: archiveRoot, year: "2026")

    #expect(result.entryCount == 3)
    #expect(Set(entries.map(\.kind)) == [.photo, .walk, .trip])
    let photo = try #require(entries.first { $0.kind == .photo })
    let walk = try #require(entries.first { $0.kind == .walk })
    let trip = try #require(entries.first { $0.kind == .trip })
    #expect(photo.archiveRelativePath == "2026/05-May/23-Sat-Morning/2026-05-23-morning-001.jpg")
    #expect(photo.title == "IMG_0001.jpg")
    #expect(photo.location == "Oxford")
    #expect(photo.exifSummary?.contains("Canon Test") == true)
    #expect(photo.thumbnailPath == expectedThumbnailPath)
    #expect(walk.archiveRelativePath == "2026/05-May/23-Sat-Morning")
    #expect(walk.title == "Morning")
    #expect(trip.archiveRelativePath == "2026/05-May")
    #expect(trip.title == "May")
}

@Test func archiveByteReadPolicyTreatsSparseArchiveFileAsOnlineOnlyInTravelMode() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    try FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
    let sparse = archiveRoot.appendingPathComponent("2026/05-May/23-Sat-Morning/online.jpg")
    try FileManager.default.createDirectory(at: sparse.deletingLastPathComponent(), withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: sparse.path, contents: nil)
    let handle = try FileHandle(forWritingTo: sparse)
    try handle.truncate(atOffset: 10 * 1024 * 1024)
    try handle.close()

    let policy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: .travel)

    #expect(policy.isOnlineOnly(sparse))
    #expect(policy.canReadBytes(at: sparse) == false)
    #expect(policy.canReadBytes(at: sparse, explicitDownload: true))
}

@Test func archiveByteReadPolicyDoesNotTreatTinyLocalFilesAsOnlineOnly() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let tiny = archiveRoot.appendingPathComponent("2026/05-May/23-Sat-Morning/tiny.jpg")
    try writeTestFile(tiny, contents: "tiny")

    let policy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: .travel)

    #expect(policy.isOnlineOnly(tiny) == false)
    #expect(policy.canReadBytes(at: tiny))
}

@Test func archiveIndexThumbnailNamingUsesArchiveRelativePathAndExtension() throws {
    let archiveRoot = URL(fileURLWithPath: "/Archive", isDirectory: true)
    let jpg = archiveRoot
        .appendingPathComponent("2026/05-May/23-Sat-Morning", isDirectory: true)
        .appendingPathComponent("IMG_0001.jpg")
    let raw = archiveRoot
        .appendingPathComponent("2026/05-May/23-Sat-Morning", isDirectory: true)
        .appendingPathComponent("IMG_0001.cr3")

    let jpgThumbnail = ArchiveIndexStore.thumbnailURL(for: jpg, archiveRoot: archiveRoot)
    let rawThumbnail = ArchiveIndexStore.thumbnailURL(for: raw, archiveRoot: archiveRoot)
    let jpgRelative = ArchiveIndexStore.thumbnailRelativePath(for: jpg, archiveRoot: archiveRoot)
    let rawRelative = ArchiveIndexStore.thumbnailRelativePath(for: raw, archiveRoot: archiveRoot)

    #expect(jpgThumbnail != rawThumbnail)
    #expect(jpgThumbnail.path.contains("/Archive/_index/thumbs/2026/IMG_0001-jpg-"))
    #expect(rawThumbnail.path.contains("/Archive/_index/thumbs/2026/IMG_0001-cr3-"))
    #expect(jpgThumbnail.pathExtension == "jpg")
    #expect(rawThumbnail.pathExtension == "jpg")
    #expect(jpgRelative != rawRelative)
}

@Test func archiveIndexMutationQueueSerializesConcurrentWalkUpdates() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let walkA = try writeArchiveIndexFixtureWalk(
        archiveRoot: archiveRoot,
        tripName: "05-May",
        walkName: "23-Sat-Morning",
        photoName: "2026-05-23-morning-001.jpg",
        title: "Morning"
    )
    let walkB = try writeArchiveIndexFixtureWalk(
        archiveRoot: archiveRoot,
        tripName: "05-May",
        walkName: "24-Sun-Evening",
        photoName: "2026-05-24-evening-001.jpg",
        title: "Evening"
    )
    let queue = ArchiveIndexMutationQueue(store: ArchiveIndexStore())
    let policy = ArchiveIndexWritePolicy(machineRole: .mainArchive)

    async let first: Void = queue.replaceWalkFolders([walkA], archiveRoot: archiveRoot, policy: policy)
    async let second: Void = queue.replaceWalkFolders([walkB], archiveRoot: archiveRoot, policy: policy)
    _ = try await (first, second)

    let entries = try readIndexEntries(archiveRoot: archiveRoot, year: "2026")
    #expect(entries.contains { $0.archiveRelativePath == "2026/05-May/23-Sat-Morning/2026-05-23-morning-001.jpg" })
    #expect(entries.contains { $0.archiveRelativePath == "2026/05-May/24-Sun-Evening/2026-05-24-evening-001.jpg" })
}

@Test func archiveIndexMutationQueueDoesNotWriteInTravelMode() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let walk = try writeArchiveIndexFixtureWalk(
        archiveRoot: archiveRoot,
        tripName: "05-May",
        walkName: "23-Sat-Morning",
        photoName: "2026-05-23-morning-001.jpg",
        title: "Morning"
    )
    let queue = ArchiveIndexMutationQueue(store: ArchiveIndexStore())
    let policy = ArchiveIndexWritePolicy(machineRole: .travel)

    try await queue.replaceWalkFolders([walk], archiveRoot: archiveRoot, policy: policy)

    #expect(FileManager.default.fileExists(atPath: ArchiveIndexStore.indexRoot(for: archiveRoot).path) == false)
}

private func readIndexEntries(archiveRoot: URL, year: String) throws -> [ArchiveIndexEntry] {
    let url = ArchiveIndexStore.indexRoot(for: archiveRoot).appendingPathComponent("index-\(year).jsonl")
    let text = try String(contentsOf: url, encoding: .utf8)
    let decoder = JSONDecoder()
    return try text.split(separator: "\n").map { line in
        try decoder.decode(ArchiveIndexEntry.self, from: Data(line.utf8))
    }
}

@discardableResult
private func writeArchiveIndexFixtureWalk(
    archiveRoot: URL,
    tripName: String,
    walkName: String,
    photoName: String,
    title: String
) throws -> URL {
    let capturedAt = Date(timeIntervalSince1970: 1_779_532_200)
    let tripFolder = archiveRoot.appendingPathComponent("2026/\(tripName)", isDirectory: true)
    let walkFolder = tripFolder.appendingPathComponent(walkName, isDirectory: true)
    try FileManager.default.createDirectory(at: walkFolder, withIntermediateDirectories: true)
    let photoURL = walkFolder.appendingPathComponent(photoName)
    try writeTestFile(photoURL, contents: "jpeg")
    let fileManifest = FileManifest(
        mediaItemID: UUID(),
        archivePath: photoURL.path,
        archiveRelativePath: "2026/\(tripName)/\(walkName)/\(photoName)",
        sourceFileName: photoName,
        companionArchivePaths: [],
        companionArchiveRelativePaths: [],
        capturedAt: capturedAt,
        cameraModel: "Canon Test",
        lensModel: "Test Lens",
        pixelWidth: 4000,
        pixelHeight: 3000,
        latitude: nil,
        longitude: nil,
        walkTitle: title,
        walkLocation: "Oxford",
        notes: ""
    )
    let walkManifest = WalkManifest(
        sessionID: UUID(),
        walkID: UUID(),
        tripFolderRelativePath: "2026/\(tripName)",
        walkDate: capturedAt,
        sourceFolder: archiveRoot.appendingPathComponent("source", isDirectory: true),
        archiveFolder: walkFolder,
        archiveFolderRelativePath: "2026/\(tripName)/\(walkName)",
        title: title,
        location: "Oxford",
        notes: "",
        summary: .init(
            totalSourceFiles: 1,
            visibleItems: 1,
            importedFiles: 1,
            excludedFiles: 0,
            candidateFiles: 0,
            undecidedFiles: 0,
            skippedFiles: 0,
            cleanupPendingFiles: 0,
            cleanedSourceFiles: 0
        ),
        importedFiles: [fileManifest],
        excludedFiles: []
    )
    let renderer = ManifestRenderer()
    try renderer.renderWalkManifest(walkManifest)
        .write(to: walkFolder.appendingPathComponent("\(walkName).md"), atomically: true, encoding: .utf8)
    try renderer.renderFileManifest(fileManifest)
        .write(to: walkFolder.appendingPathComponent(photoURL.deletingPathExtension().lastPathComponent + ".md"), atomically: true, encoding: .utf8)
    return walkFolder
}
