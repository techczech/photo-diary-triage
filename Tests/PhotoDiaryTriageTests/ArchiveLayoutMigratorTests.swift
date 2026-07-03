import Foundation
import Testing
@testable import PhotoDiaryTriage

@Suite("Archive layout v2 naming")
struct ArchiveLayoutNamingTests {
    private let date = DateFormatting.iso8601.date(from: "2026-06-02T10:00:00.000Z")!

    @Test func tripFolderNameDefaultsToMonth() {
        #expect(DateFormatting.archiveTripFolderName(from: date) == "06-June")
    }

    @Test func tripFolderNameAppendsTripSlug() {
        #expect(DateFormatting.archiveTripFolderName(from: date, tripTitle: "Lake District trip") == "06-June-Lake-district-trip")
    }

    @Test func walkFolderNameUsesAbbreviatedWeekday() {
        #expect(DateFormatting.archiveWalkFolderName(from: date, title: "Walk in Blenheim") == "02-Tue-Walk-in-blenheim")
    }

    @Test func fileStemCarriesFullDate() {
        #expect(DateFormatting.archiveFileStem(from: date, title: "Walk in Blenheim") == "2026-06-02-walk-in-blenheim")
    }
}

@Suite("Archive layout migrator")
struct ArchiveLayoutMigratorTests {
    private func makeLegacyArchive() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("migrator-tests-\(UUID().uuidString)", isDirectory: true)
        let walk = root
            .appendingPathComponent("2020", isDirectory: true)
            .appendingPathComponent("03 - March", isDirectory: true)
            .appendingPathComponent("02-Monday-Port-meadow", isDirectory: true)
        try FileManager.default.createDirectory(at: walk, withIntermediateDirectories: true)

        let stem = "02-Monday-Port-meadow"
        try Data([0xFF, 0xD8]).write(to: walk.appendingPathComponent("\(stem)-001.jpg"))
        try Data([0xFF, 0xD8]).write(to: walk.appendingPathComponent("\(stem)-002.jpg"))
        try """
        archive_path: \(walk.path)/\(stem)-001.jpg
        archive_relative_path: 2020/03 - March/\(stem)/\(stem)-001.jpg
        source_file_name: DSCF0001.JPG
        """.write(to: walk.appendingPathComponent("\(stem)-001.md"), atomically: true, encoding: .utf8)
        try """
        # Walk manifest
        Archive folder: \(walk.path)
        - DSCF0001.JPG -> \(stem)-001.jpg (2020/03 - March/\(stem)/\(stem)-001.jpg)
        """.write(to: walk.appendingPathComponent("\(stem).md"), atomically: true, encoding: .utf8)
        try #"{"event":"commit","archive_folder":"\#(walk.path)"}"#
            .write(to: walk.appendingPathComponent("\(stem)-session-log.jsonl"), atomically: true, encoding: .utf8)

        // Pre-app material that must be skipped untouched.
        let preApp = root
            .appendingPathComponent("2020", isDirectory: true)
            .appendingPathComponent("03", isDirectory: true)
            .appendingPathComponent("28", isDirectory: true)
        try FileManager.default.createDirectory(at: preApp, withIntermediateDirectories: true)
        try Data([0x00]).write(to: preApp.appendingPathComponent("IMG_1234.jpg"))

        return root
    }

    @Test func planIdentifiesLegacyWalksAndSkipsPreAppFolders() throws {
        let root = try makeLegacyArchive()
        defer { try? FileManager.default.removeItem(at: root) }

        let plan = ArchiveLayoutMigrator().plan(archiveRoot: root)

        #expect(plan.walks.count == 1)
        let walk = try #require(plan.walks.first)
        #expect(walk.newMonthName == "03-March")
        #expect(walk.newWalkName == "02-Mon-Port-meadow")
        #expect(walk.newStemBase == "2020-03-02-port-meadow")
        #expect(plan.skipped.contains { $0.0.lastPathComponent == "03" })
    }

    @Test func executeMovesRenamesAndRewrites() throws {
        let root = try makeLegacyArchive()
        defer { try? FileManager.default.removeItem(at: root) }

        let migrator = ArchiveLayoutMigrator()
        let plan = migrator.plan(archiveRoot: root)
        let result = migrator.execute(plan)

        #expect(result.failures.isEmpty)
        #expect(result.migratedWalks == 1)
        #expect(result.removedLegacyMonthFolders == 1)
        #expect(migrator.verify(plan).isEmpty)

        let newWalk = root
            .appendingPathComponent("2020", isDirectory: true)
            .appendingPathComponent("03-March", isDirectory: true)
            .appendingPathComponent("02-Mon-Port-meadow", isDirectory: true)
        let names = try FileManager.default
            .contentsOfDirectory(at: newWalk, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent).sorted()
        #expect(names.contains("2020-03-02-port-meadow-001.jpg"))
        #expect(names.contains("2020-03-02-port-meadow-001.md"))
        #expect(names.contains("02-Mon-Port-meadow.md"))
        #expect(names.contains("02-Mon-Port-meadow-session-log.jsonl"))

        let fileManifest = try String(contentsOf: newWalk.appendingPathComponent("2020-03-02-port-meadow-001.md"), encoding: .utf8)
        #expect(fileManifest.contains("2020/03-March/02-Mon-Port-meadow/2020-03-02-port-meadow-001.jpg"))
        #expect(fileManifest.contains(newWalk.path))
        #expect(!fileManifest.contains("02-Monday-Port-meadow"))
        #expect(fileManifest.contains("source_file_name: DSCF0001.JPG"))

        // Pre-app folder untouched.
        let preApp = root.appendingPathComponent("2020/03/28/IMG_1234.jpg")
        #expect(FileManager.default.fileExists(atPath: preApp.path))
    }

    @Test func planIsEmptyOnV2Archive() throws {
        let root = try makeLegacyArchive()
        defer { try? FileManager.default.removeItem(at: root) }
        let migrator = ArchiveLayoutMigrator()
        _ = migrator.execute(migrator.plan(archiveRoot: root))

        let secondPlan = migrator.plan(archiveRoot: root)
        #expect(secondPlan.walks.isEmpty)
    }
}
