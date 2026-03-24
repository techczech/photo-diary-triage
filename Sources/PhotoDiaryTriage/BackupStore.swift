import Foundation

struct AppBackupDocument: Codable {
    struct StoredSession: Codable {
        var session: ImportSession
        var bursts: [BurstGroup]
        var timeClusters: [TimeCluster]
    }

    var exportedAt: Date
    var settings: AppSettings
    var sessions: [StoredSession]
}

final class BackupStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func exportBackup(settings: AppSettings, sessions: [(ImportSession, [BurstGroup], [TimeCluster])], to url: URL) throws {
        let document = AppBackupDocument(
            exportedAt: Date(),
            settings: settings,
            sessions: sessions.map { .init(session: $0.0, bursts: $0.1, timeClusters: $0.2) }
        )
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    func importBackup(from url: URL) throws -> AppBackupDocument {
        let data = try Data(contentsOf: url)
        return try decoder.decode(AppBackupDocument.self, from: data)
    }
}
