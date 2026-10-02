import Foundation

struct AppBackupDocument: Codable {
    struct StoredSession: Codable {
        var session: ImportSession
        var bursts: [BurstGroup]
        var timeClusters: [TimeCluster]
    }

    // Version 2 uses JSONEncoder's exact Date representation. Version 1 used ISO8601 seconds.
    var formatVersion: Int? = 2
    var exportedAt: Date
    var settings: AppSettings
    var sessions: [StoredSession]

    var records: [(ImportSession, [BurstGroup], [TimeCluster])] {
        sessions.map { ($0.session, $0.bursts, $0.timeClusters) }
    }

    func validate() throws {
        guard formatVersion == nil || formatVersion == 1 || formatVersion == 2 else {
            throw BackupRecoveryError.invalid("This backup version is not supported.")
        }
        guard Set(sessions.map { $0.session.id }).count == sessions.count else {
            throw BackupRecoveryError.invalid("The backup contains duplicate session identities.")
        }
        for record in sessions {
            let session = record.session
            let ids = Set(session.mediaItems.map(\.id))
            guard ids.count == session.mediaItems.count,
                  Set(record.bursts.map(\.id)).count == record.bursts.count,
                  Set(record.timeClusters.map(\.id)).count == record.timeClusters.count,
                  Set(session.proposedWalks.map(\.id)).count == session.proposedWalks.count else {
                throw BackupRecoveryError.invalid("A saved session contains duplicate photo or group identities.")
            }
            let provenanceIDs = Set(session.sourceProvenances.map(\.id))
            guard provenanceIDs.count == session.sourceProvenances.count,
                  session.mediaItems.allSatisfy({ $0.sourceProvenanceID.map { provenanceIDs.contains($0) } ?? true }),
                  session.proposedWalks.allSatisfy({ Set($0.sourceProvenanceIDs).count == $0.sourceProvenanceIDs.count && Set($0.sourceProvenanceIDs).isSubset(of: provenanceIDs) }) else {
                throw BackupRecoveryError.invalid("A saved session has duplicate or missing Source identities.")
            }
            let walkMembers = session.proposedWalks.flatMap(\.mediaItemIDs)
            guard Set(walkMembers).count == walkMembers.count else {
                throw BackupRecoveryError.invalid("A photo belongs to more than one proposed Walk.")
            }
            let groups = record.bursts.map(\.mediaItemIDs) + record.timeClusters.map(\.mediaItemIDs) + session.proposedWalks.map(\.mediaItemIDs)
            guard groups.allSatisfy({ Set($0).count == $0.count && Set($0).isSubset(of: ids) }) else {
                throw BackupRecoveryError.invalid("A saved group references missing or repeated photos.")
            }
        }
    }
}

final class BackupStore {
    func exportBackup(settings: AppSettings, sessions: [(ImportSession, [BurstGroup], [TimeCluster])], to url: URL) throws {
        let document = AppBackupDocument(exportedAt: Date(), settings: settings,
            sessions: sessions.map { .init(session: $0.0, bursts: $0.1, timeClusters: $0.2) })
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try BackupDurableFile.write(try encoder.encode(document), to: url)
    }

    func importBackup(from url: URL) throws -> AppBackupDocument {
        let data = try Data(contentsOf: url)
        let header = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let version = header?["formatVersion"] as? Int
        guard version == nil || version == 1 || version == 2 else {
            throw BackupRecoveryError.invalid("This backup version is not supported.")
        }
        let decoder = JSONDecoder()
        if version == nil || version == 1 { decoder.dateDecodingStrategy = .iso8601 }
        let document = try decoder.decode(AppBackupDocument.self, from: data)
        try document.validate()
        return document
    }
}
