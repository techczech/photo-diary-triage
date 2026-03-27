import Foundation
import SQLite3

final class SessionStore: SessionPersisting {
    private let databaseURL: URL
    private var db: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = AppLogger.sessionStore

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try AppDirectories.ensureExists(databaseURL.deletingLastPathComponent())
        try open()
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func save(session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) throws {
        let sessionData = try encoder.encode(session)
        let burstData = try encoder.encode(bursts)
        let clusterData = try encoder.encode(clusters)
        let walkMetadataData = try encoder.encode(session.walkMetadata)

        let sql = """
        INSERT INTO import_sessions(id, source_folder, status, started_at, updated_at, walk_metadata_json, session_json, burst_groups_json, time_clusters_json)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            source_folder = excluded.source_folder,
            status = excluded.status,
            started_at = excluded.started_at,
            updated_at = excluded.updated_at,
            walk_metadata_json = excluded.walk_metadata_json,
            session_json = excluded.session_json,
            burst_groups_json = excluded.burst_groups_json,
            time_clusters_json = excluded.time_clusters_json;
        """

        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }

        try bindText(session.id.uuidString, to: statement, index: 1)
        try bindText(session.sourceFolder.path, to: statement, index: 2)
        try bindText(session.status, to: statement, index: 3)
        try bindText(DateFormatting.iso8601.string(from: session.startedAt), to: statement, index: 4)
        try bindText(DateFormatting.iso8601.string(from: session.lastUpdatedAt), to: statement, index: 5)
        try bindText(String(data: walkMetadataData, encoding: .utf8) ?? "{}", to: statement, index: 6)
        try bindBlob(sessionData, to: statement, index: 7)
        try bindBlob(burstData, to: statement, index: 8)
        try bindBlob(clusterData, to: statement, index: 9)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError("Failed to save session")
        }

        logger.debug("Saved session \(session.id.uuidString, privacy: .public) to SQLite")
    }

    func loadSessions() throws -> [(ImportSession, [BurstGroup], [TimeCluster])] {
        let sql = """
        SELECT rowid, session_json, burst_groups_json, time_clusters_json
        FROM import_sessions
        ORDER BY updated_at DESC;
        """

        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }

        var result: [(ImportSession, [BurstGroup], [TimeCluster])] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(statement, 0)
            do {
                guard let sessionBytes = sqlite3_column_blob(statement, 1) else {
                    throw NSError(domain: "SessionStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing session blob"])
                }
                let sessionLength = Int(sqlite3_column_bytes(statement, 1))
                let sessionData = Data(bytes: sessionBytes, count: sessionLength)
                let session = try decoder.decode(ImportSession.self, from: sessionData)

                let burstData = blobData(statement: statement, column: 2)
                let clusterData = blobData(statement: statement, column: 3)

                let bursts = try decoder.decode([BurstGroup].self, from: burstData)
                let clusters = try decoder.decode([TimeCluster].self, from: clusterData)
                result.append((session, bursts, clusters))
            } catch {
                logger.error("Skipping corrupt persisted session row \(rowID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                continue
            }
        }

        logger.debug("Loaded \(result.count) persisted sessions from SQLite")
        return result
    }

    func replaceAllSessions(with sessions: [(ImportSession, [BurstGroup], [TimeCluster])]) throws {
        guard sqlite3_exec(db, "DELETE FROM import_sessions;", nil, nil, nil) == SQLITE_OK else {
            throw sqliteError("Failed to clear sessions")
        }

        for session in sessions {
            try save(session: session.0, bursts: session.1, clusters: session.2)
        }

        logger.log("Replaced all persisted sessions with \(sessions.count) session(s)")
    }

    private func open() throws {
        if sqlite3_open(databaseURL.path, &db) != SQLITE_OK {
            throw sqliteError("Failed to open database")
        }
    }

    private func migrate() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS import_sessions (
            id TEXT PRIMARY KEY,
            source_folder TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            walk_metadata_json TEXT NOT NULL,
            session_json BLOB NOT NULL,
            burst_groups_json BLOB NOT NULL,
            time_clusters_json BLOB NOT NULL
        );
        """

        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError("Failed to migrate database")
        }
    }

    private func sqliteError(_ message: String) -> NSError {
        let detail = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
        return NSError(domain: "SessionStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(message): \(detail)"])
    }

    private func bindText(_ text: String, to statement: OpaquePointer?, index: Int32) throws {
        let result = text.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, transientDestructor)
        }
        guard result == SQLITE_OK else {
            throw sqliteError("Failed to bind text")
        }
    }

    private func bindBlob(_ data: Data, to statement: OpaquePointer?, index: Int32) throws {
        let result = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), transientDestructor)
        }
        guard result == SQLITE_OK else {
            throw sqliteError("Failed to bind blob")
        }
    }
}

private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func blobData(statement: OpaquePointer?, column: Int32) -> Data {
    guard let bytes = sqlite3_column_blob(statement, column) else { return Data() }
    let count = Int(sqlite3_column_bytes(statement, column))
    return Data(bytes: bytes, count: count)
}
