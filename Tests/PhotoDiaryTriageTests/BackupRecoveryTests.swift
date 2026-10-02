import Foundation
import SQLite3
import Testing
@testable import PhotoDiaryTriage

private final class BackupFaultSettings: SettingsPersisting {
    var value: AppSettings
    var failures: Set<Int> = []
    var writes = 0
    init(_ value: AppSettings) { self.value = value }
    func load(defaults: @autoclosure () -> AppSettings) -> AppSettings { value }
    func save(_ value: AppSettings) throws {
        writes += 1
        if failures.contains(writes) { throw CocoaError(.fileWriteOutOfSpace) }
        self.value = value
    }
}
private final class BackupFaultSessions: SessionPersisting {
    let base = InMemorySessionStore()
    var saveFails = false
    var failures: Set<Int> = []
    var replacements = 0
    func save(session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) throws {
        if saveFails { throw CocoaError(.fileWriteOutOfSpace) }
        try base.save(session: session, bursts: bursts, clusters: clusters)
    }
    func loadSessions() throws -> [(ImportSession, [BurstGroup], [TimeCluster])] { try base.loadSessions() }
    func replaceAllSessions(with records: [(ImportSession, [BurstGroup], [TimeCluster])]) throws {
        replacements += 1
        if failures.contains(replacements) { throw CocoaError(.fileWriteOutOfSpace) }
        try base.replaceAllSessions(with: records)
    }
}
private struct BackupFixture {
    let root: URL
    let old: AppBackupDocument
    let new: AppBackupDocument
    let sessions: BackupFaultSessions
    let settings: BackupFaultSettings
    let gate: BackupPersistenceGate
    let restore: BackupRestoreCoordinator
    init() throws {
        root = try makeTemporaryDirectory()
        var oldSession = makeTestSession(sourceRoot: root.appendingPathComponent("old"), archiveRoot: root.appendingPathComponent("archive"), items: [], title: "Old", sessionKind: .inbox)
        oldSession.lastUpdatedAt = Date(timeIntervalSince1970: 1_700_000_000.123456)
        oldSession.sessionKindWasExplicit = false
        let newSession = makeTestSession(sourceRoot: root.appendingPathComponent("new"), archiveRoot: root.appendingPathComponent("archive"), items: [], title: "New")
        let original = makeTestSettings(root: root)
        var changed = original; changed.reviewGridColumnCount += 1
        old = AppBackupDocument(exportedAt: Date(), settings: original, sessions: [.init(session: oldSession, bursts: [], timeClusters: [])])
        new = AppBackupDocument(exportedAt: Date(), settings: changed, sessions: [.init(session: newSession, bursts: [], timeClusters: [])])
        sessions = BackupFaultSessions(); try sessions.replaceAllSessions(with: old.records); sessions.replacements = 0
        settings = BackupFaultSettings(original)
        gate = BackupPersistenceGate(); restore = BackupRestoreCoordinator(supportRoot: root, gate: gate)
    }
    func run() throws -> String? { try restore.restore(new, currentSettings: old.settings, sessions: sessions, settings: settings) }
    func checkOld() throws {
        #expect(try sessions.loadSessions().map { $0.0 } == old.sessions.map(\.session))
        #expect(settings.value == old.settings)
    }
}
private func backupSQL(_ url: URL, _ sql: String) throws {
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
}

@Test func backupV2RetainsPreciseDatesAndLegacyClassification() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let url = f.root.appendingPathComponent("backup.json")
    try BackupStore().exportBackup(settings: f.old.settings, sessions: f.old.records, to: url)
    let read = try BackupStore().importBackup(from: url)
    #expect(read.formatVersion == 2)
    #expect(read.sessions[0].session == f.old.sessions[0].session)
}
@Test func backupAcceptsLegacyISO8601AndRejectsUnsupportedVersion() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let url = f.root.appendingPathComponent("backup.json")
    var legacy = f.old; legacy.formatVersion = nil
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(legacy).write(to: url)
    let read = try BackupStore().importBackup(from: url)
    #expect(read.sessions[0].session.id == legacy.sessions[0].session.id)
    legacy.formatVersion = 99
    try encoder.encode(legacy).write(to: url)
    #expect(throws: (any Error).self) { try BackupStore().importBackup(from: url) }
}
@Test func backupRejectsDuplicateSessionsAndPhotosButAllowsCrossSessionPhotoIDs() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    var duplicate = f.old; duplicate.sessions += duplicate.sessions
    #expect(throws: (any Error).self) { try duplicate.validate() }
    let item = makeTestMediaItem(sourceRoot: f.root, fileName: "photo.jpg", capturedAt: Date())
    var one = f.old.sessions[0]; one.session.mediaItems = [item, item]
    duplicate.sessions = [one]
    #expect(throws: (any Error).self) { try duplicate.validate() }
    one.session.mediaItems = [item]
    var two = f.new.sessions[0]; two.session.mediaItems = [item]; two.session.sourceProvenances = one.session.sourceProvenances
    duplicate.sessions = [one, two]
    try duplicate.validate()
}
@Test func backupRejectsMissingGroupAndSourceReferences() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    var doc = f.old
    doc.sessions[0].bursts = [BurstGroup(id: UUID(), mediaItemIDs: [UUID()], startedAt: nil, endedAt: nil)]
    #expect(throws: (any Error).self) { try doc.validate() }
    doc.sessions[0].bursts = []
    var item = makeTestMediaItem(sourceRoot: f.root, fileName: "photo.jpg", capturedAt: Date())
    item.sourceProvenanceID = UUID(); doc.sessions[0].session.mediaItems = [item]
    #expect(throws: (any Error).self) { try doc.validate() }
}
@Test func backupStrictSnapshotRefusesCorruptRows() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let db = f.root.appendingPathComponent("sessions.sqlite"), store = try SessionStore(databaseURL: db)
    try store.replaceAllSessions(with: f.old.records)
    try backupSQL(db, "UPDATE import_sessions SET session_json = x'7B';")
    #expect(try store.loadSessions().isEmpty)
    #expect(throws: (any Error).self) { try store.loadBackupSnapshot() }
    #expect(throws: (any Error).self) { try f.restore.restore(f.new, currentSettings: f.old.settings, sessions: store, settings: f.settings) }
    #expect(!f.restore.hasRecoveryRecord)
}
@Test func backupStrictSnapshotReportsLockedDatabase() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let url = f.root.appendingPathComponent("sessions.sqlite"), store = try SessionStore(databaseURL: url)
    try store.replaceAllSessions(with: f.old.records)
    var db: OpaquePointer?; #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_exec(db, "ROLLBACK;", nil, nil, nil); sqlite3_close(db) }
    #expect(sqlite3_exec(db, "BEGIN EXCLUSIVE;", nil, nil, nil) == SQLITE_OK)
    #expect(throws: (any Error).self) { try store.loadBackupSnapshot() }
}
@Test func backupStrictSettingsReadDoesNotSubstituteDefaultsForCorruption() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let url = f.root.appendingPathComponent("settings.json"), store = SettingsStore(fileURL: url)
    try Data("{".utf8).write(to: url)
    #expect(throws: (any Error).self) { try store.loadBackupSnapshot(defaults: f.old.settings) }
    #expect(throws: (any Error).self) { try f.restore.restore(f.new, currentSettings: f.old.settings, sessions: f.sessions, settings: store) }
    #expect(!f.restore.hasRecoveryRecord)
}
@Test func backupRealSQLiteReplacementFailureRollsBackEveryRow() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let db = f.root.appendingPathComponent("sessions.sqlite"), store = try SessionStore(databaseURL: db)
    try store.replaceAllSessions(with: f.old.records)
    try backupSQL(db, "CREATE TRIGGER reject_new BEFORE INSERT ON import_sessions WHEN NEW.id = '\(f.new.sessions[0].session.id.uuidString)' BEGIN SELECT RAISE(ABORT, 'fixture failure'); END;")
    #expect(throws: (any Error).self) { try f.restore.restore(f.new, currentSettings: f.old.settings, sessions: store, settings: f.settings) }
    #expect(try store.loadBackupSnapshot()[0].0 == f.old.sessions[0].session)
    #expect(f.settings.value == f.old.settings)
    #expect(f.gate.blockedReason == nil)
}
@Test func backupJournalPreparationFailureChangesNeitherStore() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    f.restore.writeJournal = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
    #expect(throws: (any Error).self) { try f.run() }
    try f.checkOld(); #expect(!f.restore.hasRecoveryRecord)
}
@Test func backupSessionRestoreFailureRestoresOriginalSettingsAndSessions() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    f.sessions.failures = [1]
    #expect(throws: (any Error).self) { try f.run() }
    try f.checkOld(); #expect(f.gate.blockedReason == nil)
}
@Test func backupSettingsFailureRestoresBothStores() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    f.settings.failures = [1]
    #expect(throws: (any Error).self) { try f.run() }
    try f.checkOld(); #expect(!f.restore.hasRecoveryRecord)
}
@Test func backupFailedRollbackBlocksSavesAndPreservesJournalUntilRetry() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    f.settings.failures = [1, 2]
    #expect(throws: (any Error).self) { try f.run() }
    #expect(f.restore.hasRecoveryRecord); #expect(f.gate.blockedReason != nil)
    let guarded = BackupGuardedSessionStore(f.sessions, gate: f.gate)
    #expect(throws: (any Error).self) { try guarded.save(session: f.new.sessions[0].session, bursts: [], clusters: []) }
    #expect(throws: (any Error).self) { try BackupGuardedSettingsStore(f.settings, gate: f.gate).save(f.new.settings) }
    #expect(throws: (any Error).self) { try f.run() }
    f.settings.failures = []
    try f.restore.recover(sessions: f.sessions, settings: f.settings)
    try f.checkOld(); #expect(f.gate.blockedReason == nil)
}
@Test func backupCommitMarkerFailureBeforeWriteRollsBack() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let write = f.restore.writeJournal
    f.restore.writeJournal = { journal, url in
        if journal.phase == .committed { throw CocoaError(.fileWriteOutOfSpace) }
        try write(journal, url)
    }
    #expect(throws: (any Error).self) { try f.run() }
    try f.checkOld(); #expect(f.gate.blockedReason == nil)
}
@Test func backupCommitMarkerSyncFailureDoesNotUndoCommittedStores() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let write = f.restore.writeJournal
    f.restore.writeJournal = { journal, url in try write(journal, url); if journal.phase == .committed { throw CocoaError(.fileWriteUnknown) } }
    #expect(throws: (any Error).self) { try f.run() }
    #expect(f.gate.blockedReason != nil)
    try f.restore.recover(sessions: f.sessions, settings: f.settings)
    #expect(try f.sessions.loadSessions()[0].0 == f.new.sessions[0].session)
    #expect(f.settings.value == f.new.settings)
}
@Test func backupCompletedRestoreSurvivesCleanupFailureAndNextLaunch() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    f.restore.removeJournal = { _ in throw CocoaError(.fileWriteNoPermission) }
    #expect(try f.run() != nil)
    #expect(f.gate.blockedReason == nil); #expect(f.restore.hasRecoveryRecord)
    let reopened = BackupRestoreCoordinator(supportRoot: f.root, gate: f.gate)
    try reopened.recover(sessions: f.sessions, settings: f.settings)
    #expect(try f.sessions.loadSessions()[0].0 == f.new.sessions[0].session)
    #expect(f.settings.value == f.new.settings)
    #expect(!reopened.hasRecoveryRecord)
}
@Test func backupPreparedRecoveryRestoresPreciseBeforeImage() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    try f.restore.writeJournal(.init(phase: .prepared, before: f.old), f.restore.journalURL)
    try f.sessions.replaceAllSessions(with: f.new.records); try f.settings.save(f.new.settings)
    try BackupRestoreCoordinator(supportRoot: f.root, gate: f.gate).recover(sessions: f.sessions, settings: f.settings)
    try f.checkOld()
}
@Test func backupCorruptJournalBlocksRecoveryWithoutChangingStores() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    try Data("{".utf8).write(to: f.restore.journalURL)
    #expect(throws: (any Error).self) { try f.restore.recover(sessions: f.sessions, settings: f.settings) }
    try f.checkOld(); #expect(f.restore.hasRecoveryRecord); #expect(f.gate.blockedReason != nil)
}
@MainActor @Test func backupAppExportIncludesJustEditedMetadata() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.currentSession = f.old.sessions[0].session
    state.updateWalkMetadata(title: "Latest decision", location: "New location", notes: "Unslept edit")
    let url = f.root.appendingPathComponent("export.json")
    try state.exportBackup(to: url)
    #expect(try BackupStore().importBackup(from: url).sessions[0].session.walkMetadata.notes == "Unslept edit")
}
@MainActor @Test func backupAppRefusesExportWhenPendingSaveFailed() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.currentSession = f.old.sessions[0].session; f.sessions.saveFails = true
    state.updateWalkMetadata(title: "Latest", location: "New", notes: "Failed edit")
    let url = f.root.appendingPathComponent("export.json")
    #expect(throws: (any Error).self) { try state.exportBackup(to: url) }
    #expect(!FileManager.default.fileExists(atPath: url.path))
}
@MainActor @Test func backupAppEmptyRestoreClearsOldSessionAndSelection() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.currentSession = f.old.sessions[0].session; state.selectedMediaItemIDs = [UUID()]
    state.comparingMediaItemIDs = [UUID()]; state.previewingMediaItemID = UUID()
    let url = f.root.appendingPathComponent("empty.json")
    try BackupStore().exportBackup(settings: f.new.settings, sessions: [], to: url)
    try state.restoreBackup(from: url)
    #expect(state.currentSession == nil); #expect(state.selectedMediaItemIDs.isEmpty)
    #expect(state.comparingMediaItemIDs.isEmpty); #expect(state.previewingMediaItemID == nil)
    state.updateWalkMetadata(title: "Cannot resurrect", location: "", notes: "")
    #expect(try f.sessions.loadSessions().isEmpty); #expect(state.settings == f.new.settings)
}
@MainActor @Test func backupAppSettingsFailureDoesNotPublishNewState() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.currentSession = f.old.sessions[0].session; f.settings.failures = [1]
    let url = f.root.appendingPathComponent("incoming.json")
    try BackupStore().exportBackup(settings: f.new.settings, sessions: f.new.records, to: url)
    #expect(throws: (any Error).self) { try state.restoreBackup(from: url) }
    #expect(state.settings == f.old.settings); #expect(state.currentSession?.id == f.old.sessions[0].session.id)
    try f.checkOld()
}
@MainActor @Test func backupAppRestoreRefusesActiveWorkAndRecordedCurrentCopy() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    let url = f.root.appendingPathComponent("incoming.json")
    try BackupStore().exportBackup(settings: f.new.settings, sessions: f.new.records, to: url)
    state.isDescribing = true
    #expect(throws: (any Error).self) { try state.restoreBackup(from: url) }
    state.isDescribing = false
    var current = f.old.sessions[0].session; current.confirmedCopyPending = true; state.currentSession = current
    #expect(throws: (any Error).self) { try state.restoreBackup(from: url) }
    try f.checkOld()
}
@MainActor @Test func backupAppStartupRecoversBeforeLoadingSettingsAndSessions() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    // Explicit current-era session avoids subsequent legitimate legacy normalization.
    var before = f.old; before.sessions[0].session.sessionKindWasExplicit = true
    try f.restore.writeJournal(.init(phase: .prepared, before: before), f.restore.journalURL)
    try f.sessions.replaceAllSessions(with: f.new.records); try f.settings.save(f.new.settings)
    let state = AppState(testing: true, testingSettings: f.new.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    #expect(state.settings == f.old.settings)
    #expect(try f.sessions.loadSessions()[0].0.id == before.sessions[0].session.id)
    #expect(state.startupAlert == nil); #expect(!f.restore.hasRecoveryRecord)
}
@MainActor @Test func backupAppStartupFailedRecoveryBlocksAutosaveAndOffersRetry() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    try f.restore.writeJournal(.init(phase: .prepared, before: f.old), f.restore.journalURL)
    f.settings.failures = [1]
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    #expect(state.startupAlert?.recoveryAction == .retryBackupRecovery)
    state.currentSession = f.old.sessions[0].session
    state.updateWalkMetadata(title: "Blocked", location: "", notes: "")
    #expect(f.restore.hasRecoveryRecord)
    let url = f.root.appendingPathComponent("export.json")
    #expect(throws: (any Error).self) { try state.exportBackup(to: url) }
    #expect(!state.canMutateImportSelection)
}
@MainActor @Test func backupRapidEditsToTwoSessionsBothReachExport() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    try f.sessions.save(session: f.new.sessions[0].session, bursts: [], clusters: [])
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.openSavedWalk(f.old.sessions[0].session.id)
    state.updateWalkMetadata(title: "A latest", location: "", notes: "A pending")
    state.openSavedWalk(f.new.sessions[0].session.id)
    state.updateWalkMetadata(title: "B latest", location: "", notes: "B pending")
    let url = f.root.appendingPathComponent("two.json")
    try state.exportBackup(to: url)
    let read = try BackupStore().importBackup(from: url)
    #expect(Set(read.sessions.map { $0.session.walkMetadata.notes }) == ["A pending", "B pending"])
}
@MainActor @Test func backupEarlierFailedSaveIsNotHiddenByLaterSuccessfulSession() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    try f.sessions.save(session: f.new.sessions[0].session, bursts: [], clusters: [])
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.openSavedWalk(f.old.sessions[0].session.id); f.sessions.saveFails = true
    state.updateWalkMetadata(title: "A latest", location: "", notes: "A failed")
    // Force and observe A's failure, then allow B to succeed.
    let url = f.root.appendingPathComponent("two.json")
    #expect(throws: (any Error).self) { try state.exportBackup(to: url) }
    f.sessions.saveFails = false
    state.openSavedWalk(f.new.sessions[0].session.id)
    state.updateWalkMetadata(title: "B latest", location: "", notes: "B success")
    #expect(throws: (any Error).self) { try state.exportBackup(to: url) }
    #expect(!FileManager.default.fileExists(atPath: url.path))
    // Editing A again creates a complete fresh snapshot which repairs its failed save.
    state.openSavedWalk(f.old.sessions[0].session.id)
    state.updateWalkMetadata(title: "A retried", location: "", notes: "A repaired")
    try state.exportBackup(to: url)
    #expect(Set(try BackupStore().importBackup(from: url).sessions.map { $0.session.walkMetadata.notes }) == ["A repaired", "B success"])
}
@MainActor @Test func backupSameRootRestoreRevokesCapturedByteContextAndEditors() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.activeWalkCommitEditor = WalkCommitEditorState(id: UUID(), walks: [], existingTrips: [], tripDisplayLabel: "Trip", walkDisplayLabel: "Walk")
    state.activePhotoLogEditor = PhotoLogEditorState(id: UUID(), mode: .create, creationMode: .decidedInScope, title: "Stale", location: "", notes: "", scopeKind: .folder, scopeLabel: "Stale", sourceFolderPaths: [], startDate: nil, endDate: nil)
    let previous = ArchiveByteReadPolicyContext.shared.generation
    let url = f.root.appendingPathComponent("restore.json")
    try BackupStore().exportBackup(settings: f.old.settings, sessions: [], to: url)
    try state.restoreBackup(from: url)
    #expect(ArchiveByteReadPolicyContext.shared.generation != previous)
    #expect(state.activeWalkCommitEditor == nil); #expect(state.activePhotoLogEditor == nil)
}
@MainActor @Test func backupRetryCommittedEmptyRestoreCannotResurrectOldSession() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let settings = makeTestSettings(root: root), settingsStore = SettingsStore(fileURL: root.appendingPathComponent("settings.json"))
    try settingsStore.save(settings)
    let sessions = try SessionStore(databaseURL: root.appendingPathComponent("sessions.sqlite"))
    let old = makeTestSession(sourceRoot: root.appendingPathComponent("source"), archiveRoot: settings.archiveRoot, items: [])
    try sessions.save(session: old, bursts: [], clusters: [])
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root, testingSessionStore: sessions, testingSettingsStore: settingsStore)
    state.currentSession = old
    let write = state.backupRestoreCoordinator.writeJournal
    state.backupRestoreCoordinator.writeJournal = { journal, url in
        try write(journal, url)
        if journal.phase == .committed { throw CocoaError(.fileWriteUnknown) }
    }
    let url = root.appendingPathComponent("empty.json")
    try BackupStore().exportBackup(settings: settings, sessions: [], to: url)
    #expect(throws: (any Error).self) { try state.restoreBackup(from: url) }
    #expect(state.currentSession?.id == old.id)
    state.performStartupRecovery()
    #expect(state.startupAlert == nil); #expect(state.currentSession == nil)
    state.updateWalkMetadata(title: "Cannot resurrect", location: "", notes: "")
    #expect(try sessions.loadBackupSnapshot().isEmpty)
}
@Test func backupCoupledMembershipFailureRollsBackBothSQLiteRows() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let url = f.root.appendingPathComponent("sessions.sqlite"), store = try SessionStore(databaseURL: url)
    try store.replaceAllSessions(with: f.old.records + f.new.records)
    var old = f.old.sessions[0].session, new = f.new.sessions[0].session
    old.walkMetadata.notes = "Changed A"; new.walkMetadata.notes = "Changed B"
    try backupSQL(url, "CREATE TRIGGER reject_second BEFORE UPDATE ON import_sessions WHEN NEW.id = '\(new.id.uuidString)' BEGIN SELECT RAISE(ABORT, 'fixture'); END;")
    #expect(throws: (any Error).self) { try store.saveSessions([(old, [], []), (new, [], [])]) }
    #expect(Set(try store.loadBackupSnapshot().map { $0.0.walkMetadata.notes }) == ["Test notes"])
}
@MainActor @Test func backupMultiSourceMembershipTransferPreservesProvenance() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let settings = makeTestSettings(root: root), store = InMemorySessionStore()
    let firstSource = root.appendingPathComponent("camera"), secondSource = root.appendingPathComponent("phone")
    let first = SourceProvenance(folder: firstSource), second = SourceProvenance(folder: secondSource)
    var a = makeTestMediaItem(sourceRoot: firstSource, fileName: "camera.jpg", capturedAt: Date(), selectionState: .included)
    a.sourceProvenanceID = first.id
    var b = makeTestMediaItem(sourceRoot: secondSource, fileName: "phone.jpg", capturedAt: Date().addingTimeInterval(500))
    b.sourceProvenanceID = second.id
    var log = makeTestSession(sourceRoot: firstSource, archiveRoot: settings.archiveRoot, items: [a]); log.sourceProvenances = [first]
    var inbox = makeTestSession(sourceRoot: firstSource, archiveRoot: settings.archiveRoot, items: [b], sessionKind: .inbox); inbox.sourceProvenances = [first, second]
    try store.replaceAllSessions(with: [(log, [], []), (inbox, [], [])])
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root, testingSessionStore: store)
    state.editPhotoLogMembership(log.id)
    state.selectedMediaItemIDs = [b.id]; state.activePane = .media
    state.markCurrentSelectionForImport()
    let url = root.appendingPathComponent("multi.json")
    try state.exportBackup(to: url)
    let read = try BackupStore().importBackup(from: url)
    let saved = try #require(read.sessions.first { $0.session.id == log.id })
    #expect(saved.session.mediaItems.contains { $0.id == b.id })
    #expect(saved.session.sourceProvenances.contains { $0.id == second.id })
}
private actor BackupCleanupBarrier: ImportCoordinating {
    private var continuation: CheckedContinuation<ImportSession, Never>?
    private var session: ImportSession?
    func commit(session: ImportSession, progress: (@Sendable (ImportProgress) async -> Void)?) async throws -> ImportResult { throw CocoaError(.userCancelled) }
    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession {
        self.session = session
        return await withCheckedContinuation { continuation = $0 }
    }
    func entered() -> Bool { continuation != nil }
    func finish() { if let session { continuation?.resume(returning: session) }; continuation = nil }
}
@MainActor @Test func backupRestoreAndExportBlockedWhileSourceCleanupIsSuspended() async throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    let cleanup = BackupCleanupBarrier()
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingImportCoordinator: cleanup, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.currentSession = f.old.sessions[0].session
    let url = f.root.appendingPathComponent("incoming.json")
    try BackupStore().exportBackup(settings: f.new.settings, sessions: f.new.records, to: url)
    state.startConfirmedSourceCleanup(f.old.sessions[0].session)
    for _ in 0..<100 { if await cleanup.entered() { break }; await Task.yield() }
    #expect(await cleanup.entered())
    #expect(throws: (any Error).self) { try state.restoreBackup(from: url) }
    #expect(throws: (any Error).self) { try state.exportBackup(to: f.root.appendingPathComponent("out.json")) }
    await cleanup.finish()
    for _ in 0..<100 { await Task.yield() }
}

@MainActor @Test func backupProductionFallbackCannotReportDurableRestoreSuccess() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let settings = makeTestSettings(root: root)
    // Force actual SQLite opening to fail without invoking a file picker or opening a window.
    try AppDirectories.ensureExists(root.appendingPathComponent("sessions.sqlite"))
    let state = AppState(testingSettings: settings, testingSupportRoot: root)
    let url = root.appendingPathComponent("empty.json")
    try BackupStore().exportBackup(settings: settings, sessions: [], to: url)
    #expect(throws: (any Error).self) { try state.restoreBackup(from: url) }
    #expect(throws: (any Error).self) { try state.exportBackup(to: root.appendingPathComponent("out.json")) }
    #expect(!state.backupRestoreCoordinator.hasRecoveryRecord)
}

@MainActor @Test func backupPendingEditCannotResurrectDeletedPhotoLog() throws {
    let f = try BackupFixture(); defer { try? FileManager.default.removeItem(at: f.root) }
    try f.sessions.save(session: f.new.sessions[0].session, bursts: [], clusters: [])
    let state = AppState(testing: true, testingSettings: f.old.settings, testingSupportRoot: f.root, testingSessionStore: f.sessions, testingSettingsStore: f.settings)
    state.openSavedWalk(f.new.sessions[0].session.id)
    state.updateWalkMetadata(title: "Queued immediately before delete", location: "", notes: "Pending")
    state.deletePhotoLog(f.new.sessions[0].session.id)
    let url = f.root.appendingPathComponent("after-delete.json")
    try state.exportBackup(to: url)
    let read = try BackupStore().importBackup(from: url)
    #expect(!read.sessions.contains { $0.session.id == f.new.sessions[0].session.id })
    #expect(try !f.sessions.loadSessions().contains { $0.0.id == f.new.sessions[0].session.id })
}

@MainActor @Test func backupPhotoLogCreationFailureLeavesNoHalfTransferredMembership() throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let store = try SessionStore(databaseURL: root.appendingPathComponent("sessions.sqlite")), settings = makeTestSettings(root: root)
    let source = root.appendingPathComponent("source"); try AppDirectories.ensureExists(source)
    try writeTestFile(source.appendingPathComponent("photo.jpg"))
    let item = makeTestMediaItem(sourceRoot: source, fileName: "photo.jpg", capturedAt: Date(), selectionState: .included)
    let inbox = makeTestSession(sourceRoot: source, archiveRoot: settings.archiveRoot, items: [item], sessionKind: .inbox)
    try store.save(session: inbox, bursts: [], clusters: [])
    let state = AppState(testing: true, testingSettings: settings, testingSupportRoot: root, testingSessionStore: store)
    state.currentSession = inbox; state.setWorkspaceMode(.cameraTriage)
    if let leaf = state.browserNodeMap.values.first(where: { ($0.children?.isEmpty ?? true) && $0.mediaItemIDs.count == 1 }) { state.selectedSidebarNodeID = leaf.id }
    state.activePane = .media; state.presentPhotoLogCreation()
    #expect(state.activePhotoLogEditor != nil)
    // The first new-log insert succeeds; the second Inbox update fails inside the transaction.
    try backupSQL(root.appendingPathComponent("sessions.sqlite"), "CREATE TRIGGER reject_inbox BEFORE UPDATE ON import_sessions WHEN NEW.id = '\(inbox.id.uuidString)' BEGIN SELECT RAISE(ABORT, 'fixture'); END;")
    state.createPhotoLog(openAfterCreate: true)
    let read = try store.loadBackupSnapshot()
    #expect(read.count == 1); #expect(read[0].0.id == inbox.id)
    #expect(read[0].0.mediaItems == inbox.mediaItems)
    #expect(state.currentSession?.id == inbox.id)
}
