import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct GooglePhotosDeliveryScope: Codable, Hashable, Sendable {
    var kind: GooglePhotosScopeKind
    var id: UUID
    var path: String
    var title: String
    var photos: [DescriptionReference]
}
struct GooglePhotosDeliveryPhoto: Codable, Sendable, Identifiable {
    var id: UUID { target.identity }
    var target: DescriptionReference
    var parentIdentity: UUID?
    var sha256: String
    var size: Int64
    var mimeType: String
    var blockHashes: [String]
    var media: GooglePhotosCreatedMedia? = nil
    var verifiedAt: Date? = nil
    var committed = false
    var error: String? = nil
}
enum GooglePhotosDeliveryState: String, Codable, Sendable { case pending, running, needsReconciliation, cancelled, failed, completed, abandoned }
struct GooglePhotosDeliveryJob: Codable, Sendable, Identifiable {
    var id = UUID()
    var createdAt = Date()
    var account: GooglePhotosAccount
    var scope: GooglePhotosDeliveryScope
    var photos: [GooglePhotosDeliveryPhoto]
    var machineRole: ArchiveMachineRole
    var state: GooglePhotosDeliveryState = .pending
    var albumCreationStarted = false
    var precedingAlbumIDs: Set<String> = []
    var binding: GooglePhotosAlbumBinding? = nil
    var retryAfter: Date? = nil
    var retryCount = 0
    var error: String? = nil
    var indexWarning: String? = nil
    var totalBytes: Int64 { photos.reduce(0) { $0 + $1.size } }
}
private struct GooglePhotosUploadSecret: Codable, Sendable {
    var session: GooglePhotosUploadSession? = nil
    var token: String? = nil
    var tokenCreatedAt: Date? = nil
    var tokenDigest: String? = nil
    var tokenSize: Int64? = nil
}
actor GooglePhotosAccountLock {
    static let shared = GooglePhotosAccountLock()
    private var owners: [String: UUID] = [:]
    func acquire(account: String, owner: UUID) throws {
        guard owners[account] == nil else { throw ArchiveFileVerification.failure("Another Google Photos delivery is running for this account. Finish or cancel it first.") }; owners[account] = owner
    }
    func release(account: String, owner: UUID) { if owners[account] == owner { owners.removeValue(forKey: account) } }
}
struct GooglePhotosDeliveryRepository: Sendable {
    var archiveRoot: URL
    var machineRole: ArchiveMachineRole
    var picturesRoot: URL? = nil
    var write: @Sendable (String, URL) throws -> Void = { text, url in
        try text.write(to: url, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forWritingTo: url); defer { try? handle.close() }; try handle.synchronize()
    }
    var beforeWrite: @Sendable () throws -> Void = {}
    var canonical: ArchiveDescriptionRepository { .init(archiveRoot: archiveRoot, machineRole: machineRole, oneDrivePicturesRoot: picturesRoot) }
    func trip(path: String) throws -> GooglePhotosDeliveryScope {
        let snapshot = try canonical.snapshot(kind: .trip, path: path)
        var photos: [DescriptionReference] = []
        for walk in snapshot.children { photos += try canonical.snapshot(kind: .walk, path: walk.path).children }
        return .init(kind: .trip, id: snapshot.target.identity, path: path, title: TripManifestStore().loadTripManifest(folder: archiveRoot.appendingPathComponent(path), oneDrivePicturesRoot: picturesRoot ?? archiveRoot).title, photos: photos)
    }
    func photoLog(id: UUID, title: String, paths: [String]) throws -> GooglePhotosDeliveryScope {
        let photos = try paths.map { try canonical.snapshot(kind: .photo, path: $0).target }
        return .init(kind: .photoLog, id: id, path: ".walkfolio-google-photos/photo-log-\(id.uuidString).md", title: title, photos: photos)
    }
    private func ownerURL(_ scope: GooglePhotosDeliveryScope) throws -> URL {
        if scope.kind == .trip { return try canonical.manifestURL(.init(kind: .trip, path: scope.path, identity: scope.id)) }
        guard scope.path == ".walkfolio-google-photos/photo-log-\(scope.id.uuidString).md" else { throw ArchiveFileVerification.failure("The Photo Log delivery record has an invalid path.") }
        let url = archiveRoot.appendingPathComponent(scope.path)
        guard url.resolvingSymlinksInPath().standardizedFileURL == archiveRoot.resolvingSymlinksInPath().appendingPathComponent(scope.path).standardizedFileURL else { throw ArchiveFileVerification.failure("Delivery records cannot use linked storage.") }; return url
    }
    func ownerText(_ scope: GooglePhotosDeliveryScope) throws -> String {
        if scope.kind == .trip {
            let current = try canonical.snapshot(kind: .trip, path: scope.path)
            guard current.target.identity == scope.id else { throw ArchiveFileVerification.failure("The captured Trip identity changed.") }
            return try canonical.text(current.target)
        }
        let url = try ownerURL(scope)
        if FileManager.default.fileExists(atPath: url.path) {
            guard try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isSymbolicLink != true else { throw ArchiveFileVerification.failure("The Photo Log delivery record is linked.") }
            let text = try String(contentsOf: url, encoding: .utf8)
            let identityLines = text.components(separatedBy: "\n").prefix { !$0.hasPrefix("## ") }.filter { $0.hasPrefix("- Photo Log ID: ") }
            let identity = identityLines.count == 1 ? UUID(uuidString: String(identityLines[0].dropFirst("- Photo Log ID: ".count)).trimmingCharacters(in: CharacterSet(charactersIn: "` \t"))) : nil
            guard identity == scope.id else { throw ArchiveFileVerification.failure("The Photo Log delivery identity changed.") }; return text
        }
        return "# Photo Log\n\n- Photo Log ID: `\(scope.id.uuidString)`\n"
    }
    func binding(scope: GooglePhotosDeliveryScope, account: GooglePhotosAccount) throws -> GooglePhotosAlbumBinding? {
        let bindings = try GooglePhotosRecord.read(in: ownerText(scope))?.albums.filter { $0.scopeID == scope.id && $0.scopeKind == scope.kind && $0.accountID == account.id && $0.clientID == account.clientID } ?? []
        guard bindings.count <= 1 else { throw ArchiveFileVerification.failure("Conflicting album bindings have been retained.") }; return bindings.first
    }
    func capture(_ scope: GooglePhotosDeliveryScope, includeMarked: Bool) throws -> [GooglePhotosDeliveryPhoto] {
        _ = try ownerText(scope)
        let ownerMarks = try GooglePhotosRecord.read(in: ownerText(scope))?.manualMarks.isEmpty == false
        guard !ownerMarks || includeMarked else { throw ArchiveFileVerification.failure("This folder is marked previously uploaded. Review Include marked material before sending it again.") }
        guard !scope.photos.isEmpty, scope.photos.count <= 20_000, Set(scope.photos.map(\.identity)).count == scope.photos.count else { throw ArchiveFileVerification.failure("Select 1–20,000 distinct canonical original photographs.") }
        return try scope.photos.compactMap { target in
            let snapshot = try canonical.snapshot(kind: .photo, path: target.path)
            guard snapshot.target == target else { throw ArchiveFileVerification.failure("A selected photo identity changed.") }
            let record = try GooglePhotosRecord.read(in: canonical.text(target))
            let parentPath = target.path.split(separator: "/").dropLast().joined(separator: "/")
            let parentMarks = try GooglePhotosRecord.read(in: canonical.text(.init(kind: .walk, path: parentPath, identity: snapshot.parentIdentity!)))?.manualMarks.isEmpty == false
            if !includeMarked && (record?.manualMarks.isEmpty == false || parentMarks) { return nil }
            let source = try readableOriginal(target)
            let values = try source.resourceValues(forKeys: [.fileSizeKey])
            guard let bytes = values.fileSize, bytes > 0, bytes <= 200_000_000,
                  let mime = UTType(filenameExtension: source.pathExtension)?.preferredMIMEType, mime.hasPrefix("image/") else { throw ArchiveFileVerification.failure("Google Photos supports original images up to 200 MB. This file has no supported image type; no conversion was made.") }
            let evidence = try captureBlocks(source)
            let digest = evidence.digest
            if let recorded = ArchiveManifestText.scalar("sha256", in: try canonical.text(target)), recorded != digest { throw ArchiveFileVerification.failure("An original no longer matches its verified archive copy.") }
            return .init(target: target, parentIdentity: snapshot.parentIdentity, sha256: digest, size: Int64(bytes), mimeType: mime, blockHashes: evidence.blocks)
        }
    }
    private let blockSize = 1_048_576
    private func captureBlocks(_ source: URL) throws -> (digest: String, blocks: [String]) {
        let before = try FileManager.default.attributesOfItem(atPath: source.path)
        let handle = try FileHandle(forReadingFrom: source); defer { try? handle.close() }
        var digest = SHA256(), blocks: [String] = []
        while let data = try handle.read(upToCount: blockSize), !data.isEmpty {
            try Task.checkCancellation()
            digest.update(data: data); blocks.append(MachineDescriptionHistory.digest(data))
        }
        let after = try FileManager.default.attributesOfItem(atPath: source.path)
        guard before[.systemFileNumber] as? UInt64 == after[.systemFileNumber] as? UInt64, before[.size] as? Int64 == after[.size] as? Int64, before[.modificationDate] as? Date == after[.modificationDate] as? Date else { throw ArchiveFileVerification.failure("The original changed while capturing the delivery. Review it again.") }
        return (digest.finalize().map { String(format: "%02x", $0) }.joined(), blocks)
    }
    func verifiedRange(source: URL, photo: GooglePhotosDeliveryPhoto, offset: Int64, count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset + Int64(count) <= photo.size else { throw GooglePhotosFailure.invalidResponse }
        if count == 0 { return Data() }
        let handle = try FileHandle(forReadingFrom: source); defer { try? handle.close() }
        var result = Data(), cursor = offset
        let end = offset + Int64(count)
        while cursor < end {
            let block = Int(cursor / Int64(blockSize)), start = Int64(block * blockSize)
            guard photo.blockHashes.indices.contains(block) else { throw GooglePhotosFailure.invalidResponse }
            try handle.seek(toOffset: UInt64(start))
            let length = Int(min(Int64(blockSize), photo.size - start)), data = try handle.read(upToCount: length) ?? Data()
            guard data.count == length, MachineDescriptionHistory.digest(data) == photo.blockHashes[block] else { throw ArchiveFileVerification.failure("An original changed while streaming. No changed byte range was sent; restore the captured original before retrying.") }
            let a = Int(cursor - start), b = Int(min(end, start + Int64(length)) - start)
            result.append(data[a..<b]); cursor = start + Int64(b)
        }
        return result
    }
    func readableOriginal(_ target: DescriptionReference) throws -> URL {
        let current = try canonical.snapshot(kind: .photo, path: target.path)
        guard current.target == target else { throw ArchiveFileVerification.failure("The captured original identity changed.") }
        let url = try ArchiveIndexMediaLoader().indexedURL(target.path, archiveRoot: archiveRoot)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        let policy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: machineRole)
        guard values.isRegularFile == true, values.isSymbolicLink != true, !policy.isOnlineOnly(url), (machineRole == .mainArchive || ArchiveByteReadPolicyContext.shared.hasExplicitViewing(at: url, archiveRoot: archiveRoot)) else { throw ArchiveFileVerification.failure("An original is unavailable or has no explicit Travel byte permission. Prepare it with Download to view, then retry; delivery does not hydrate originals.") }
        return url
    }
    func validateOriginal(_ photo: GooglePhotosDeliveryPhoto) throws -> URL {
        let url = try readableOriginal(photo.target)
        let current = try canonical.snapshot(kind: .photo, path: photo.target.path)
        guard current.parentIdentity == photo.parentIdentity, try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(photo.size),
              try ArchiveFileVerification.sha256(at: url) == photo.sha256 else { throw ArchiveFileVerification.failure("The captured original changed. Its delivered receipt remains in the queue; a different file will not be substituted.") }
        try ArchiveLocationEditor.assertNoPending(overlapping: url.deletingLastPathComponent(), archiveRoot: archiveRoot)
        try ArchiveLocationEditor.assertNoUnfinishedFolderOperation(overlapping: url.deletingLastPathComponent(), archiveRoot: archiveRoot)
        return url
    }
    private func patch(_ original: String, url: URL, change: (inout GooglePhotosRecord) throws -> Void) throws {
        var record = try GooglePhotosRecord.read(in: original) ?? .init(); try change(&record)
        let updated = try record.setting(in: original); guard updated != original else { return }
        try beforeWrite()
        if FileManager.default.fileExists(atPath: url.path) {
            guard try String(contentsOf: url, encoding: .utf8) == original else { throw ArchiveFileVerification.failure("The canonical notes changed before saving delivery facts. Their latest text has been retained.") }
        }
        try AppDirectories.ensureExists(url.deletingLastPathComponent()); try write(updated, url)
    }
    func commitBinding(_ binding: GooglePhotosAlbumBinding, scope: GooglePhotosDeliveryScope) throws {
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        let original = try ownerText(scope), url = try ownerURL(scope)
        try patch(original, url: url) { try $0.add(binding) }
    }
    func commit(_ member: GooglePhotosMembership, photo: GooglePhotosDeliveryPhoto, scope: GooglePhotosDeliveryScope) throws {
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        _ = try validateOriginal(photo)
        let original = try canonical.text(photo.target), url = try canonical.manifestURL(photo.target)
        try patch(original, url: url) { $0.add(member) }
        let owner = try ownerText(scope)
        try patch(owner, url: ownerURL(scope)) { $0.add(member) }
    }
    func markHistorical(path: String, note: String, clear: Bool) throws {
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        guard !path.hasPrefix("_index"), !path.hasPrefix("."), path != "." else { throw ArchiveFileVerification.failure("Choose an unorganised archive folder.") }
        let folder = try ArchiveIndexMediaLoader().indexedURL(path, archiveRoot: archiveRoot)
        guard folder.resolvingSymlinksInPath().standardizedFileURL == archiveRoot.resolvingSymlinksInPath().appendingPathComponent(path).standardizedFileURL,
              try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true else { throw ArchiveFileVerification.failure("The historical mark cannot follow linked folders.") }
        try ArchiveLocationEditor.assertNoPending(overlapping: folder, archiveRoot: archiveRoot)
        try ArchiveLocationEditor.assertNoUnfinishedFolderOperation(overlapping: folder, archiveRoot: archiveRoot)
        let url = folder.appendingPathComponent(folder.lastPathComponent + ".md")
        let text: String
        if FileManager.default.fileExists(atPath: url.path) {
            guard try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isSymbolicLink != true else { throw ArchiveFileVerification.failure("The historical record is linked.") }
            text = try String(contentsOf: url, encoding: .utf8)
            guard TripManifestText.headerValue("Trip ID", in: text) == nil, ArchiveLocationEditor.identity("Session ID", in: text) == nil else { throw ArchiveFileVerification.failure("This folder now has a canonical identity. Refresh its contextual mark action.") }
        } else { text = "# Historical folder\n\n" }
        try patch(text, url: url) { record in if clear { record.manualMarks = [] } else if record.manualMarks.isEmpty { record.manualMarks.append(.init(note: note)) } }
    }
    func mark(_ target: DescriptionReference, note: String, clear: Bool) throws {
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        let snapshot = try canonical.snapshot(kind: target.kind, path: target.path)
        guard snapshot.target == target else { throw ArchiveFileVerification.failure("The mark target changed.") }
        let url = try canonical.manifestURL(target), original = try canonical.text(target)
        try ArchiveLocationEditor.assertNoPending(overlapping: target.kind == .photo ? url.deletingLastPathComponent() : url.deletingLastPathComponent(), archiveRoot: archiveRoot)
        try ArchiveLocationEditor.assertNoUnfinishedFolderOperation(overlapping: url.deletingLastPathComponent(), archiveRoot: archiveRoot)
        try patch(original, url: url) { record in
            if clear { record.manualMarks = [] } else if record.manualMarks.isEmpty { record.manualMarks.append(.init(note: note)) }
        }
    }
}

actor GooglePhotosDeliveryQueue {
    let archiveRoot: URL
    let credentials: any GooglePhotosCredentials
    let client: any GooglePhotosDelivering
    let secrets: any GooglePhotosSecretStoring
    var repository: GooglePhotosDeliveryRepository
    let contextIsCurrent: @Sendable () -> Bool
    let persist: @Sendable (GooglePhotosDeliveryJob, URL) throws -> Void
    private var running = false
    private var cancelled = false
    private var requestTask: Task<Void, Error>?
    init(archiveRoot: URL, credentials: any GooglePhotosCredentials, client: any GooglePhotosDelivering, secrets: any GooglePhotosSecretStoring = GooglePhotosKeychain(),
         repository: GooglePhotosDeliveryRepository, contextIsCurrent: @escaping @Sendable () -> Bool = { true },
         persist: @escaping @Sendable (GooglePhotosDeliveryJob, URL) throws -> Void = { job, root in try ArchiveOperationRecovery(archiveRoot: root).save(job, kind: "google-delivery", sessionID: job.id) }) {
        self.archiveRoot = archiveRoot; self.credentials = credentials; self.client = client; self.secrets = secrets; self.repository = repository; self.contextIsCurrent = contextIsCurrent; self.persist = persist
    }
    func jobs() throws -> [GooglePhotosDeliveryJob] {
        let recovery = ArchiveOperationRecovery(archiveRoot: archiveRoot)
        guard FileManager.default.fileExists(atPath: recovery.root.path) else { return [] }
        guard recovery.root.resolvingSymlinksInPath().standardizedFileURL == archiveRoot.resolvingSymlinksInPath().appendingPathComponent(".walkfolio-recovery").standardizedFileURL else { throw ArchiveFileVerification.failure("Delivery recovery storage is linked.") }
        return try FileManager.default.contentsOfDirectory(at: recovery.root, includingPropertiesForKeys: [.isSymbolicLinkKey]).filter { $0.lastPathComponent.hasPrefix("google-delivery-") && $0.pathExtension == "json" }.map { url in
            guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ArchiveFileVerification.failure("The delivery recovery record is linked.") }
            let job = try JSONDecoder().decode(GooglePhotosDeliveryJob.self, from: Data(contentsOf: url))
            let validDigest: (String) -> Bool = { $0.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil }
            guard job.account.id.nonEmpty != nil, job.account.clientID.nonEmpty != nil, !job.photos.isEmpty, job.photos.count <= 20_000,
                  Set(job.photos.map(\.id)).count == job.photos.count, job.photos.allSatisfy({ photo in
                    photo.target.kind == .photo && job.scope.photos.contains(photo.target) && validDigest(photo.sha256) && photo.size > 0 && photo.size <= 200_000_000 && photo.mimeType.hasPrefix("image/") &&
                    photo.blockHashes.count == Int((photo.size + 1_048_575) / 1_048_576) && photo.blockHashes.allSatisfy(validDigest) &&
                    (photo.verifiedAt == nil || photo.media?.id.nonEmpty != nil) && (!photo.committed || (photo.verifiedAt != nil && job.binding != nil))
                  }), job.binding.map({ $0.accountID == job.account.id && $0.clientID == job.account.clientID && $0.scopeID == job.scope.id && $0.scopeKind == job.scope.kind && $0.album.id.nonEmpty != nil }) ?? true else {
                throw ArchiveFileVerification.failure("The delivery recovery record has conflicting identity or progress. It was retained without sending requests.")
            }
            return job
        }.sorted { $0.createdAt < $1.createdAt }
    }
    func enqueue(scope: GooglePhotosDeliveryScope, expectedAccount: GooglePhotosAccount, includeMarked: Bool = false) async throws -> GooglePhotosDeliveryJob {
        let connected = try await credentials.account()
        try Task.checkCancellation()
        guard !running, contextIsCurrent(), connected == expectedAccount else { throw ArchiveFileVerification.failure("The Google account or archive changed. Review the delivery again.") }
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        guard !(try jobs()).contains(where: { $0.scope.id == scope.id && $0.account.id == expectedAccount.id && $0.state != .completed && $0.state != .abandoned }) else { throw ArchiveFileVerification.failure("This Trip or Photo Log has an unfinished delivery. Resume it first.") }
        guard scope.title.nonEmpty != nil, scope.title.count <= 500 else { throw ArchiveFileVerification.failure("Choose an album title of 1–500 characters.") }
        let photos = try repository.capture(scope, includeMarked: includeMarked)
        try Task.checkCancellation()
        guard contextIsCurrent(), !running else { throw CancellationError() }
        guard !photos.isEmpty else { throw ArchiveFileVerification.failure("All selected photos are marked previously uploaded. Review Include marked material to send them again.") }
        var job = GooglePhotosDeliveryJob(account: expectedAccount, scope: scope, photos: photos, machineRole: repository.machineRole)
        job.binding = try repository.binding(scope: scope, account: expectedAccount) ?? jobs().last(where: { $0.scope.id == scope.id && $0.scope.kind == scope.kind && $0.account.id == expectedAccount.id && $0.binding != nil })?.binding
        if let binding = job.binding {
            for i in job.photos.indices {
                if let old = try GooglePhotosRecord.read(in: repository.canonical.text(job.photos[i].target))?.memberships.first(where: { $0.accountID == expectedAccount.id && $0.clientID == expectedAccount.clientID && $0.albumID == binding.album.id && $0.photoID == job.photos[i].id && $0.originalSHA256 == job.photos[i].sha256 }) {
                    job.photos[i].media = old.media; job.photos[i].verifiedAt = old.membershipVerifiedAt
                }
            }
        }
        try persist(job, archiveRoot); return job
    }
    func cancel() { cancelled = true; requestTask?.cancel() }
    private func check(_ job: GooglePhotosDeliveryJob, idleRecovery: Bool = false) async throws {
        guard (idleRecovery || !cancelled), contextIsCurrent(), job.machineRole == repository.machineRole else { throw CancellationError() }
        try Task.checkCancellation()
        let connected = try await credentials.account()
        guard (idleRecovery || !cancelled), contextIsCurrent(), job.machineRole == repository.machineRole else { throw CancellationError() }
        guard connected?.id == job.account.id, connected?.clientID == job.account.clientID else { throw ArchiveFileVerification.failure("The connected Google account changed. Reconnect the original account to resume this delivery.") }
    }
    func candidates(jobID: UUID) async throws -> [GooglePhotosAlbum] {
        guard let job = try jobs().first(where: { $0.id == jobID }), job.albumCreationStarted, job.binding == nil else { return [] }
        try await check(job, idleRecovery: true)
        return try await client.albums(accountID: job.account.id).filter { !job.precedingAlbumIDs.contains($0.id) && $0.title == job.scope.title }
    }
    func adopt(albumID: String, jobID: UUID) async throws {
        guard !running, var job = try jobs().first(where: { $0.id == jobID }), job.albumCreationStarted, job.binding == nil else { throw GooglePhotosFailure.ambiguousAlbum }
        // Explicit selection, after a fresh authenticated complete album listing.
        guard let album = try await candidates(jobID: jobID).first(where: { $0.id == albumID }) else { throw GooglePhotosFailure.ambiguousAlbum }
        try await check(job, idleRecovery: true)
        guard !running, let current = try jobs().first(where: { $0.id == jobID }), current.binding == nil, current.state == job.state else { throw ArchiveFileVerification.failure("The delivery changed while reconciling. Reload its state.") }
        job = current
        job.binding = .init(operationID: job.id, accountID: job.account.id, clientID: job.account.clientID, scopeID: job.scope.id, scopeKind: job.scope.kind, album: album, recordedAt: Date())
        job.state = .pending; job.error = nil; try persist(job, archiveRoot)
        try repository.commitBinding(job.binding!, scope: job.scope)
    }
    func abandon(jobID: UUID) throws {
        guard !running, var job = try jobs().first(where: { $0.id == jobID }), job.state != .completed else { throw ArchiveFileVerification.failure("Cancel the running delivery first.") }
        guard !job.albumCreationStarted || job.binding != nil else { throw GooglePhotosFailure.ambiguousAlbum }
        job.state = .abandoned; job.error = "Stopped by you. Remote albums/media and recorded receipts are retained."; try persist(job, archiveRoot)
    }
    func confirmNoAlbumCreated(jobID: UUID, expectedAccountID: String) async throws {
        guard !running, var job = try jobs().first(where: { $0.id == jobID }), job.account.id == expectedAccountID, job.binding == nil, job.albumCreationStarted else { throw GooglePhotosFailure.ambiguousAlbum }
        try await check(job, idleRecovery: true)
        guard !running, let latest = try jobs().first(where: { $0.id == jobID }), latest.binding == nil else { throw GooglePhotosFailure.ambiguousAlbum }
        job = latest; job.albumCreationStarted = false; job.state = .pending; job.error = nil; try persist(job, archiveRoot)
    }
    private func secretKey(_ job: GooglePhotosDeliveryJob, _ photo: GooglePhotosDeliveryPhoto) -> String { "upload-\(job.account.id)-\(job.id.uuidString)-\(photo.id.uuidString)" }
    private func upload(_ photo: GooglePhotosDeliveryPhoto, job: GooglePhotosDeliveryJob) async throws -> String {
        let source = try repository.validateOriginal(photo), key = secretKey(job, photo)
        var saved = try secrets.read(key).map { try JSONDecoder().decode(GooglePhotosUploadSecret.self, from: $0) } ?? .init()
        if let token = saved.token, saved.tokenDigest == photo.sha256, saved.tokenSize == photo.size, saved.tokenCreatedAt.map({ Date().timeIntervalSince($0) < 86_340 }) == true { return token }
        saved.token = nil; saved.tokenCreatedAt = nil; saved.tokenDigest = nil; saved.tokenSize = nil
        if saved.session.map({ Date().timeIntervalSince($0.createdAt) >= 604_740 }) == true { saved.session = nil }
        func save() throws { try secrets.write(JSONEncoder().encode(saved), key: key) }
        var offset: Int64 = 0
        if let session = saved.session {
            do {
                try await check(job)
                let progress = try await client.queryUpload(session, accountID: job.account.id)
                guard progress.offset >= 0, progress.offset <= photo.size else { throw GooglePhotosFailure.invalidResponse }
                if progress.active { offset = progress.offset }
                else if let token = progress.token, Date().timeIntervalSince(session.createdAt) < 86_340 { saved.token = token; saved.tokenCreatedAt = Date(); saved.tokenDigest = photo.sha256; saved.tokenSize = photo.size; try save(); return token }
                else { saved.session = nil }
            } catch GooglePhotosFailure.sessionExpired { saved.session = nil }
        }
        if saved.session == nil {
            try await check(job)
            saved.session = try await client.startUpload(size: photo.size, mimeType: photo.mimeType, accountID: job.account.id); try save()
        }
        let session = saved.session!
        guard session.granularity > 0, session.granularity <= 8_388_608 else { throw GooglePhotosFailure.invalidResponse }
        let capacity = max(session.granularity, (4_194_304 / session.granularity) * session.granularity)
        repeat {
            try await check(job)
            let count = Int(min(Int64(capacity), photo.size - offset))
            let bytes = try repository.verifiedRange(source: source, photo: photo, offset: offset, count: count)
            guard bytes.count == count else { throw ArchiveFileVerification.failure("The original changed while streaming. Its upload will not be substituted or converted.") }
            let final = offset + Int64(count) == photo.size
            let token = try await client.upload(session, offset: offset, data: bytes, final: final, accountID: job.account.id)
            offset += Int64(count)
            if final {
                guard let token, token.nonEmpty != nil else { throw GooglePhotosFailure.invalidResponse }
                saved.token = token; saved.tokenCreatedAt = Date(); saved.tokenDigest = photo.sha256; saved.tokenSize = photo.size; try save(); return token
            }
        } while offset < photo.size
        throw GooglePhotosFailure.invalidResponse
    }
    func run(jobIDs: Set<UUID>? = nil, progress: (@Sendable ([GooglePhotosDeliveryJob]) async -> Void)? = nil) async throws {
        guard !running, contextIsCurrent() else { throw ArchiveFileVerification.failure("A delivery is running or the Archive changed.") }
        running = true; cancelled = false; defer { running = false }
        for initial in try jobs() where initial.state != .completed && initial.state != .abandoned && (jobIDs == nil || jobIDs!.contains(initial.id)) {
            var job = initial
            if let retry = job.retryAfter, retry > Date() { continue }
            let lease = UUID()
            try await GooglePhotosAccountLock.shared.acquire(account: job.account.id, owner: lease)
            do {
                guard let current = try jobs().first(where: { $0.id == initial.id }), current.state != .completed && current.state != .abandoned else { await GooglePhotosAccountLock.shared.release(account: initial.account.id, owner: lease); continue }
                job = current
            } catch { await GooglePhotosAccountLock.shared.release(account: initial.account.id, owner: lease); throw error }
            let task = Task { [self] in
                do {
                    try await check(job)
                    job.state = .running; job.error = nil; try persist(job, archiveRoot)
                    if let progress { await progress(try jobs()) }
                    if job.binding == nil {
                        guard !job.albumCreationStarted else { throw GooglePhotosFailure.ambiguousAlbum }
                        let preceding = try await client.albums(accountID: job.account.id)
                        try await check(job)
                        job.precedingAlbumIDs = Set(preceding.map(\.id)); job.albumCreationStarted = true; try persist(job, archiveRoot)
                        let album: GooglePhotosAlbum
                        do { album = try await client.createAlbum(title: job.scope.title, accountID: job.account.id) }
                        catch {
                            switch error {
                            case GooglePhotosFailure.notSent, GooglePhotosFailure.authentication, GooglePhotosFailure.permission, GooglePhotosFailure.quota: job.albumCreationStarted = false
                            case GooglePhotosFailure.server(let code) where (400..<500).contains(code): job.albumCreationStarted = false
                            default: break
                            }; throw error
                        }
                        // Record the returned remote ID before cancellation or canonical checks.
                        job.binding = .init(operationID: job.id, accountID: job.account.id, clientID: job.account.clientID, scopeID: job.scope.id, scopeKind: job.scope.kind, album: album, recordedAt: Date())
                        try persist(job, archiveRoot)
                    }
                    try await check(job)
                    let binding = job.binding!
                    try repository.commitBinding(binding, scope: job.scope)
                    var firstFailure: Error?
                    for i in job.photos.indices where !job.photos[i].committed && job.photos[i].media == nil {
                        do {
                            try await check(job)
                            let token = try await upload(job.photos[i], job: job)
                            _ = try repository.validateOriginal(job.photos[i]); try await check(job)
                            job.photos[i].media = try await client.createMedia(token: token, fileName: URL(fileURLWithPath: job.photos[i].target.path).lastPathComponent, albumID: binding.album.id, accountID: job.account.id)
                            job.photos[i].error = nil; try persist(job, archiveRoot)
                        } catch {
                            job.photos[i].error = error.localizedDescription; firstFailure = error; try persist(job, archiveRoot)
                            if error is CancellationError { throw error }
                            if case GooglePhotosFailure.quota = error { throw error }
                            if case GooglePhotosFailure.authentication = error { throw error }
                            break
                        }
                        if let progress { await progress(try jobs()) }
                    }
                    let requiringVerification = job.photos.indices.filter { !job.photos[$0].committed && job.photos[$0].media != nil && job.photos[$0].verifiedAt == nil }
                    if !requiringVerification.isEmpty {
                        try await check(job)
                        let members = try await client.memberIDs(albumID: binding.album.id, accountID: job.account.id)
                        for i in requiringVerification {
                            if members.contains(job.photos[i].media!.id) { job.photos[i].verifiedAt = Date(); job.photos[i].error = nil }
                            else { job.photos[i].error = GooglePhotosFailure.membershipMissing.localizedDescription; firstFailure = GooglePhotosFailure.membershipMissing }
                        }
                        try persist(job, archiveRoot)
                    }
                    for i in job.photos.indices where !job.photos[i].committed && job.photos[i].verifiedAt != nil {
                        try await check(job)
                        let photo = job.photos[i]
                        let receipt = GooglePhotosMembership(operationID: job.id, accountID: job.account.id, clientID: job.account.clientID, scopeID: job.scope.id, photoID: photo.id, albumID: binding.album.id, media: photo.media!, originalPathAtDelivery: photo.target.path, originalSHA256: photo.sha256, originalSize: photo.size, membershipVerifiedAt: photo.verifiedAt!)
                        try repository.commit(receipt, photo: photo, scope: job.scope)
                        job.photos[i].committed = true; job.photos[i].error = nil; try persist(job, archiveRoot)
                        try secrets.write(nil, key: secretKey(job, photo))
                    }
                    if repository.machineRole == .mainArchive && job.photos.contains(where: \.committed) {
                        do {
                            let walks = try Set(job.photos.filter(\.committed).map { try ArchiveIndexMediaLoader().indexedURL($0.target.path, archiveRoot: archiveRoot).deletingLastPathComponent() })
                            let trips = job.scope.kind == .trip ? [try ArchiveIndexMediaLoader().indexedURL(job.scope.path, archiveRoot: archiveRoot)] : []
                            try await ArchiveIndexMutationQueue.shared.replaceWalkFolders(Array(walks), archiveRoot: archiveRoot, policy: .init(machineRole: repository.machineRole), tripFolders: trips)
                        } catch { job.indexWarning = "Membership saved; index refresh failed: " + error.localizedDescription }
                    }
                    if let firstFailure { throw firstFailure }
                    guard job.photos.allSatisfy(\.committed) else { throw GooglePhotosFailure.membershipMissing }
                    job.state = .completed; job.error = nil; job.retryAfter = nil; try persist(job, archiveRoot)
                } catch {
                    job.state = job.albumCreationStarted && job.binding == nil ? .needsReconciliation : ((error is CancellationError || Task.isCancelled) ? .cancelled : .failed)
                    job.error = error.localizedDescription
                    if case GooglePhotosFailure.quota(let retry) = error { job.retryCount += 1; job.retryAfter = max(retry, Date().addingTimeInterval(min(3600, 30 * pow(2, Double(min(job.retryCount - 1, 7)))))) }
                    try persist(job, archiveRoot)
                }
            }
            requestTask = task
            do { try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() }) }
            catch { await GooglePhotosAccountLock.shared.release(account: job.account.id, owner: lease); requestTask = nil; throw error }
            await GooglePhotosAccountLock.shared.release(account: job.account.id, owner: lease); requestTask = nil
            if let progress { await progress(try jobs()) }
            if cancelled || !contextIsCurrent() || Task.isCancelled { break }
        }
    }
}

final class GooglePhotosContextCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var generation: Int { lock.lock(); defer { lock.unlock() }; return value }
    func invalidate() { lock.lock(); value += 1; lock.unlock() }
}
