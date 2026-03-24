import Foundation
import SQLite3
import Testing
@testable import PhotoDiaryTriage

@Test func sessionStoreSaveAndLoadRoundTripsSessionData() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = root.appendingPathComponent("sessions.sqlite")
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 1_000)
    let item = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0001.jpg", capturedAt: capturedAt)
    let session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item])
    let bursts = [BurstGroup(id: UUID(), mediaItemIDs: [item.id], startedAt: capturedAt, endedAt: capturedAt)]
    let clusters = [TimeCluster(id: UUID(), mediaItemIDs: [item.id], startedAt: capturedAt, endedAt: capturedAt)]

    let store = try SessionStore(databaseURL: databaseURL)
    try store.save(session: session, bursts: bursts, clusters: clusters)

    let loaded = try store.loadSessions()

    #expect(loaded.count == 1)
    #expect(loaded[0].0.id == session.id)
    #expect(loaded[0].0.walkMetadata.title == session.walkMetadata.title)
    #expect(loaded[0].1 == bursts)
    #expect(loaded[0].2 == clusters)
}

@Test func sessionStoreSaveUpsertsExistingSessionID() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = root.appendingPathComponent("sessions.sqlite")
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 2_000)
    let item = makeTestMediaItem(sourceRoot: sourceRoot, fileName: "IMG_0002.jpg", capturedAt: capturedAt)

    var session = makeTestSession(sourceRoot: sourceRoot, archiveRoot: archiveRoot, items: [item], title: "First Title")
    let store = try SessionStore(databaseURL: databaseURL)
    try store.save(session: session, bursts: [], clusters: [])

    session.walkMetadata.title = "Updated Title"
    session.status = "imported"
    session.lastUpdatedAt = session.lastUpdatedAt.addingTimeInterval(60)
    try store.save(session: session, bursts: [], clusters: [])

    let loaded = try store.loadSessions()

    #expect(loaded.count == 1)
    #expect(loaded[0].0.walkMetadata.title == "Updated Title")
    #expect(loaded[0].0.status == "imported")
}

@Test func sessionStoreLoadsNewestSessionFirst() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = root.appendingPathComponent("sessions.sqlite")
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 3_000)

    var older = makeTestSession(
        sourceRoot: sourceRoot.appendingPathComponent("older", isDirectory: true),
        archiveRoot: archiveRoot,
        items: [makeTestMediaItem(sourceRoot: sourceRoot, fileName: "older.jpg", capturedAt: capturedAt)]
    )
    older.lastUpdatedAt = Date(timeIntervalSince1970: 10)

    var newer = makeTestSession(
        sourceRoot: sourceRoot.appendingPathComponent("newer", isDirectory: true),
        archiveRoot: archiveRoot,
        items: [makeTestMediaItem(sourceRoot: sourceRoot, fileName: "newer.jpg", capturedAt: capturedAt.addingTimeInterval(10))]
    )
    newer.lastUpdatedAt = Date(timeIntervalSince1970: 20)

    let store = try SessionStore(databaseURL: databaseURL)
    try store.save(session: older, bursts: [], clusters: [])
    try store.save(session: newer, bursts: [], clusters: [])

    let loaded = try store.loadSessions()

    #expect(loaded.count == 2)
    #expect(loaded[0].0.id == newer.id)
    #expect(loaded[1].0.id == older.id)
}

@Test func sessionStoreReplaceAllSessionsClearsExistingRows() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = root.appendingPathComponent("sessions.sqlite")
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 4_000)

    let existing = makeTestSession(
        sourceRoot: sourceRoot.appendingPathComponent("existing", isDirectory: true),
        archiveRoot: archiveRoot,
        items: [makeTestMediaItem(sourceRoot: sourceRoot, fileName: "existing.jpg", capturedAt: capturedAt)]
    )
    let replacement = makeTestSession(
        sourceRoot: sourceRoot.appendingPathComponent("replacement", isDirectory: true),
        archiveRoot: archiveRoot,
        items: [makeTestMediaItem(sourceRoot: sourceRoot, fileName: "replacement.jpg", capturedAt: capturedAt.addingTimeInterval(30))]
    )

    let store = try SessionStore(databaseURL: databaseURL)
    try store.save(session: existing, bursts: [], clusters: [])
    try store.replaceAllSessions(with: [(replacement, [], [])])

    let loaded = try store.loadSessions()

    #expect(loaded.count == 1)
    #expect(loaded[0].0.id == replacement.id)
}

@Test func sessionStoreReopensExistingDatabaseWithSavedSessions() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = root.appendingPathComponent("sessions.sqlite")
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 5_000)
    let session = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: [makeTestMediaItem(sourceRoot: sourceRoot, fileName: "reopen.jpg", capturedAt: capturedAt)]
    )

    do {
        let store = try SessionStore(databaseURL: databaseURL)
        try store.save(session: session, bursts: [], clusters: [])
    }

    let reopenedStore = try SessionStore(databaseURL: databaseURL)
    let loaded = try reopenedStore.loadSessions()

    #expect(loaded.count == 1)
    #expect(loaded[0].0.id == session.id)
}

@Test func sessionStoreThrowsWhenStoredSessionBlobIsCorrupted() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let databaseURL = root.appendingPathComponent("sessions.sqlite")
    let sourceRoot = root.appendingPathComponent("source", isDirectory: true)
    let archiveRoot = root.appendingPathComponent("archive", isDirectory: true)
    let capturedAt = Date(timeIntervalSince1970: 6_000)
    let session = makeTestSession(
        sourceRoot: sourceRoot,
        archiveRoot: archiveRoot,
        items: [makeTestMediaItem(sourceRoot: sourceRoot, fileName: "corrupt.jpg", capturedAt: capturedAt)]
    )

    do {
        let store = try SessionStore(databaseURL: databaseURL)
        try store.save(session: session, bursts: [], clusters: [])
    }

    try corruptSessionBlob(in: databaseURL)

    let reopenedStore = try SessionStore(databaseURL: databaseURL)
    var didThrow = false
    do {
        _ = try reopenedStore.loadSessions()
    } catch {
        didThrow = true
    }

    #expect(didThrow)
}

private func corruptSessionBlob(in databaseURL: URL) throws {
    var db: OpaquePointer?
    guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
        throw NSError(domain: "SessionStoreTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open database for corruption test."])
    }
    defer { sqlite3_close(db) }

    guard sqlite3_exec(db, "UPDATE import_sessions SET session_json = X'00';", nil, nil, nil) == SQLITE_OK else {
        throw NSError(domain: "SessionStoreTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to corrupt stored session blob."])
    }
}
