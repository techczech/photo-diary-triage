import Darwin
import Foundation

enum BackupRecoveryError: LocalizedError {
    case invalid(String)
    case recoveryRequired(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .recoveryRequired(let message): return "Backup recovery is required before saving or restoring again. " + message
        }
    }
}

// Atomic replacement plus file/directory sync: do not acknowledge a merely buffered journal.
enum BackupDurableFile {
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
        try syncDirectory(url.deletingLastPathComponent())
    }
    static func syncDirectory(_ url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(fd) }
        guard fsync(fd) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}

final class BackupPersistenceGate: @unchecked Sendable {
    private let lock = NSLock()
    private var failure: String?
    var blockedReason: String? { lock.lock(); defer { lock.unlock() }; return failure }
    func block(_ message: String) { lock.lock(); failure = message; lock.unlock() }
    func clear() { lock.lock(); failure = nil; lock.unlock() }
    func check() throws {
        if let message = blockedReason { throw BackupRecoveryError.recoveryRequired(message) }
    }
}

final class BackupGuardedSessionStore: SessionPersisting {
    let base: SessionPersisting
    let gate: BackupPersistenceGate
    init(_ base: SessionPersisting, gate: BackupPersistenceGate) { self.base = base; self.gate = gate }
    func save(session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) throws {
        try gate.check(); try base.save(session: session, bursts: bursts, clusters: clusters)
    }
    func loadSessions() throws -> [(ImportSession, [BurstGroup], [TimeCluster])] { try gate.check(); return try base.loadSessions() }
    func loadBackupSnapshot() throws -> [(ImportSession, [BurstGroup], [TimeCluster])] { try gate.check(); return try base.loadBackupSnapshot() }
    func saveSessions(_ sessions: [(ImportSession, [BurstGroup], [TimeCluster])]) throws { try gate.check(); try base.saveSessions(sessions) }
    func replaceAllSessions(with sessions: [(ImportSession, [BurstGroup], [TimeCluster])]) throws { try gate.check(); try base.replaceAllSessions(with: sessions) }
}

final class BackupGuardedSettingsStore: SettingsPersisting {
    let base: SettingsPersisting
    let gate: BackupPersistenceGate
    init(_ base: SettingsPersisting, gate: BackupPersistenceGate) { self.base = base; self.gate = gate }
    func load(defaults: @autoclosure () -> AppSettings) -> AppSettings { base.load(defaults: defaults()) }
    func loadBackupSnapshot(defaults: AppSettings) throws -> AppSettings { try gate.check(); return try base.loadBackupSnapshot(defaults: defaults) }
    func save(_ settings: AppSettings) throws { try gate.check(); try base.save(settings) }
}

struct BackupRestoreJournal: Codable {
    enum Phase: String, Codable { case prepared, committed }
    var phase: Phase
    var before: AppBackupDocument
}

// There is one application state. The journal is outside the disposable preview/cache directories.
final class BackupRestoreCoordinator {
    let journalURL: URL
    let gate: BackupPersistenceGate
    var writeJournal: (BackupRestoreJournal, URL) throws -> Void = { journal, url in
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try BackupDurableFile.write(try encoder.encode(journal), to: url)
    }
    var removeJournal: (URL) throws -> Void = { url in
        try FileManager.default.removeItem(at: url)
        try BackupDurableFile.syncDirectory(url.deletingLastPathComponent())
    }
    init(supportRoot: URL, gate: BackupPersistenceGate) {
        self.journalURL = supportRoot.appendingPathComponent("walkfolio-state-restore.json")
        self.gate = gate
    }
    var hasRecoveryRecord: Bool { FileManager.default.fileExists(atPath: journalURL.path) }
    private func readJournal() throws -> BackupRestoreJournal {
        let journal = try JSONDecoder().decode(BackupRestoreJournal.self, from: Data(contentsOf: journalURL))
        try journal.before.validate()
        return journal
    }
    func recover(sessions: SessionPersisting, settings: SettingsPersisting) throws {
        guard hasRecoveryRecord else { gate.clear(); return }
        do {
            let journal = try readJournal()
            if journal.phase == .prepared {
                try sessions.replaceAllSessions(with: journal.before.records)
                try settings.save(journal.before.settings)
            }
            try removeJournal(journalURL)
            gate.clear()
        } catch {
            gate.block(error.localizedDescription)
            throw BackupRecoveryError.recoveryRequired(error.localizedDescription)
        }
    }

    // Return a cleanup warning only after both stores and the commit marker are durable.
    func restore(_ document: AppBackupDocument, currentSettings: AppSettings,
                 sessions: SessionPersisting, settings: SettingsPersisting) throws -> String? {
        try gate.check()
        try document.validate()
        guard !hasRecoveryRecord else { throw BackupRecoveryError.recoveryRequired("An earlier restore needs recovery.") }
        let before = AppBackupDocument(exportedAt: Date(), settings: try settings.loadBackupSnapshot(defaults: currentSettings),
            sessions: try sessions.loadBackupSnapshot().map { .init(session: $0.0, bursts: $0.1, timeClusters: $0.2) })
        try before.validate()
        try AppDirectories.ensureExists(journalURL.deletingLastPathComponent())
        var journal = BackupRestoreJournal(phase: .prepared, before: before)
        // If preparing fails, no application store has changed. A possibly written record is retained.
        do { try writeJournal(journal, journalURL) }
        catch {
            if hasRecoveryRecord { gate.block(error.localizedDescription) }
            throw error
        }
        gate.block("A restore is in progress.")
        do {
            try sessions.replaceAllSessions(with: document.records)
            try settings.save(document.settings)
            journal.phase = .committed
            try writeJournal(journal, journalURL)
        } catch {
            // A marker sync can fail after replacement. Never roll back a marker already on disk.
            if let disk = try? readJournal(), disk.phase == .committed {
                gate.block(error.localizedDescription)
                throw BackupRecoveryError.recoveryRequired(error.localizedDescription)
            }
            do { try recover(sessions: sessions, settings: settings) }
            catch { throw BackupRecoveryError.recoveryRequired(error.localizedDescription) }
            throw error
        }
        gate.clear()
        do { try removeJournal(journalURL); return nil }
        catch { return "The restore completed, but its recovery record could not be removed: " + error.localizedDescription }
    }
}

final class SessionPersistenceOutcome: @unchecked Sendable {
    private let lock = NSLock()
    private var failure: Error?
    private var completed = false
    func perform(_ operation: () throws -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        if completed { if let failure { throw failure }; return }
        completed = true
        do { try operation() } catch { failure = error; throw error }
    }
    func check() throws { lock.lock(); defer { lock.unlock() }; if let failure { throw failure } }
}
