import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func persistedSessionNormalizerDeduplicatesInboxesAndCountsLegacySessions() {
    let root = URL(fileURLWithPath: "/tmp/persisted-normalizer", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let base = Date(timeIntervalSince1970: 50_000)

    var newestInbox = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [],
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    newestInbox.lastUpdatedAt = base.addingTimeInterval(20)

    var duplicateInbox = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [],
        workspaceSourceFolder: root,
        sessionKind: .inbox
    )
    duplicateInbox.lastUpdatedAt = base
    duplicateInbox.sessionKindWasExplicit = false

    var explicitDraft = makeTestSession(
        sourceRoot: root,
        archiveRoot: archiveRoot,
        items: [],
        workspaceSourceFolder: root,
        sessionKind: .walkDraft
    )
    explicitDraft.lastUpdatedAt = base.addingTimeInterval(10)

    let normalized = PersistedSessionNormalizer().normalize([
        (duplicateInbox, [], []),
        (explicitDraft, [], []),
        (newestInbox, [], [])
    ])

    #expect(normalized.records.count == 2)
    #expect(normalized.deduplicatedInboxCount == 1)
    #expect(normalized.legacyRecoveredSessionCount == 1)
    #expect(normalized.records[0].0.id == newestInbox.id)
    #expect(normalized.records.contains(where: { $0.0.id == explicitDraft.id }))
}

@Test func sourceWorkspaceFolderResolverPrefersDCIMWhenPresent() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let selectedFolder = root.appendingPathComponent("EOS_DIGITAL", isDirectory: true)
    let dcimFolder = selectedFolder.appendingPathComponent("DCIM", isDirectory: true)
    try FileManager.default.createDirectory(at: dcimFolder, withIntermediateDirectories: true)

    let resolved = SourceWorkspaceFolderResolver(fileManager: .default).resolve(selectedFolder: selectedFolder)

    #expect(resolved.standardizedFileURL.path == dcimFolder.standardizedFileURL.path)
}

@Test func sourceWorkspaceFolderResolverLeavesFolderUnchangedWhenDCIMMissing() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let selectedFolder = root.appendingPathComponent("EOS_DIGITAL", isDirectory: true)
    try FileManager.default.createDirectory(at: selectedFolder, withIntermediateDirectories: true)

    let resolved = SourceWorkspaceFolderResolver(fileManager: .default).resolve(selectedFolder: selectedFolder)

    #expect(resolved.standardizedFileURL.path == selectedFolder.standardizedFileURL.path)
}
