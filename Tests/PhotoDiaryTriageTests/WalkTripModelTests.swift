import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func walkBoundaryProposalSplitsSelectedItemsByDay() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let firstDay = Date(timeIntervalSince1970: 1_779_532_200)
    let secondDay = firstDay.addingTimeInterval(86_400)
    let items = [
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "A.jpg", capturedAt: firstDay, selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "B.jpg", capturedAt: secondDay, selectionState: .included, lifecycleState: .selectedForImport),
        makeTestMediaItem(sourceRoot: sourceRoot, fileName: "C.jpg", capturedAt: secondDay.addingTimeInterval(60), selectionState: .excluded)
    ]
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: items)

    let walks = WalkBoundaryProposalService().proposedWalks(for: session)

    #expect(walks.count == 2)
    #expect(walks.map(\.mediaItemIDs.count) == [1, 1])
}

@Test func archivePlannerBuildsOnePlanPerProposedWalkAndNamedTripTarget() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let firstDay = Date(timeIntervalSince1970: 1_779_532_200)
    let secondDay = firstDay.addingTimeInterval(86_400)
    let first = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "A.jpg", capturedAt: firstDay, selectionState: .included, lifecycleState: .selectedForImport)
    let second = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "B.jpg", capturedAt: secondDay, selectionState: .included, lifecycleState: .selectedForImport)
    var session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [first, second])
    session.proposedWalks = [
        Walk(title: "Morning", date: firstDay, mediaItemIDs: [first.id], tripTarget: .newNamed(title: "Oxford")),
        Walk(title: "Evening", date: secondDay, mediaItemIDs: [second.id])
    ]

    let plans = ArchivePlanner().planWalks(for: session)

    #expect(plans.count == 2)
    #expect(plans[0].archiveFolder.path.contains("05-May-Oxford/23-Sat-Morning"))
    #expect(plans[1].archiveFolder.path.contains("05-May/24-Sun-Evening"))
}

@Test func sameDayTimeClusterWalksGetDistinctDefaultTitlesAndCommitDestinations() async throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0001.jpg"), contents: "morning")
    try writeTestFile(sourceRoot.appendingPathComponent("IMG_0002.jpg"), contents: "evening")
    let day = Date(timeIntervalSince1970: 1_779_532_200)
    let morning = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001.jpg", capturedAt: day, selectionState: .included, lifecycleState: .selectedForImport)
    let evening = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0002.jpg", capturedAt: day.addingTimeInterval(7_200), selectionState: .included, lifecycleState: .selectedForImport)
    var session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [morning, evening], title: "", location: "", notes: "")

    session.proposedWalks = WalkBoundaryProposalService().proposedWalks(
        for: session,
        timeClusters: [
            TimeCluster(id: UUID(), mediaItemIDs: [morning.id], startedAt: morning.capturedAt, endedAt: morning.capturedAt),
            TimeCluster(id: UUID(), mediaItemIDs: [evening.id], startedAt: evening.capturedAt, endedAt: evening.capturedAt)
        ]
    )

    #expect(session.proposedWalks.count == 2)
    #expect(Set(session.proposedWalks.map(\.title)).count == 2)

    let result = try await ImportCoordinator().commit(session: session)
    let destinationPaths = result.fileManifests.map(\.archivePath)
    let walkFolders = Set(result.walkManifests.map(\.archiveFolder.path))

    #expect(result.walkManifests.count == 2)
    #expect(walkFolders.count == 2)
    #expect(destinationPaths.count == 2)
    for path in destinationPaths {
        #expect(FileManager.default.fileExists(atPath: path))
    }
}

@Test func tripManifestRendererRecordsMemberWalks() {
    let folder = URL(fileURLWithPath: "/Archive/2026/05-May-Oxford", isDirectory: true)
    let manifest = TripManifest(
        tripID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Oxford",
        folder: folder,
        folderRelativePath: "2026/05-May-Oxford",
        startDate: Date(timeIntervalSince1970: 1_779_532_200),
        endDate: Date(timeIntervalSince1970: 1_779_532_260),
        memberWalkFolderPaths: ["2026/05-May-Oxford/23-Sat-Morning"]
    )

    let rendered = ManifestRenderer().renderTripManifest(manifest)

    #expect(rendered.contains("# Oxford"))
    #expect(rendered.contains("2026/05-May-Oxford/23-Sat-Morning"))
}

@Test func walkMoverMovesFolderAndRewritesSidecars() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let oldTrip = root.appendingPathComponent("2026/05-May-Old", isDirectory: true)
    let oldWalk = oldTrip.appendingPathComponent("23-Sat-Morning", isDirectory: true)
    let newTrip = root.appendingPathComponent("2026/05-May-Oxford", isDirectory: true)
    try FileManager.default.createDirectory(at: oldWalk, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: newTrip, withIntermediateDirectories: true)
    let oldTripManifest = TripManifest(
        tripID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        title: "Old",
        folder: oldTrip,
        folderRelativePath: "2026/05-May-Old",
        startDate: nil,
        endDate: nil,
        memberWalkFolderPaths: ["2026/05-May-Old/23-Sat-Morning"]
    )
    try ManifestRenderer().renderTripManifest(oldTripManifest).write(
        to: oldTrip.appendingPathComponent("05-May-Old.md"),
        atomically: true,
        encoding: .utf8
    )
    let sidecar = oldWalk.appendingPathComponent("23-Sat-Morning.md")
    try "archive_path: \(oldWalk.path)/photo.jpg\narchive_relative_path: 2026/05-May-Old/23-Sat-Morning/photo.jpg\nTrip folder: 2026/05-May-Old\n"
        .write(to: sidecar, atomically: true, encoding: .utf8)
    let cropSidecar = oldWalk.appendingPathComponent("crop.json")
    try #"{"archiveRelativePath":"2026/05-May-Old/23-Sat-Morning/crop.jpg","tripFolderRelativePath":"2026/05-May-Old"}"#
        .write(to: cropSidecar, atomically: true, encoding: .utf8)

    let result = try WalkMover().moveWalk(at: oldWalk, to: newTrip, oneDrivePicturesRoot: root)
    let rewritten = try String(contentsOf: result.destinationFolder.appendingPathComponent("23-Sat-Morning.md"), encoding: .utf8)
    let rewrittenCrop = try String(contentsOf: result.destinationFolder.appendingPathComponent("crop.json"), encoding: .utf8)
    let sourceTripManifest = try String(contentsOf: oldTrip.appendingPathComponent("05-May-Old.md"), encoding: .utf8)
    let destinationTripManifest = try String(contentsOf: newTrip.appendingPathComponent("05-May-Oxford.md"), encoding: .utf8)

    #expect(FileManager.default.fileExists(atPath: oldWalk.path) == false)
    #expect(result.destinationFolder.deletingLastPathComponent() == newTrip)
    #expect(rewritten.contains(result.destinationFolder.path))
    #expect(rewritten.contains("2026/05-May-Oxford/23-Sat-Morning/photo.jpg"))
    #expect(rewrittenCrop.contains("2026/05-May-Oxford/23-Sat-Morning/crop.jpg"))
    #expect(rewrittenCrop.contains("2026/05-May-Oxford"))
    #expect(sourceTripManifest.contains("2026/05-May-Old/23-Sat-Morning") == false)
    #expect(destinationTripManifest.contains("2026/05-May-Oxford/23-Sat-Morning"))
}
