import Foundation
import Testing
@testable import PhotoDiaryTriage

private final class GoogleTestSecrets: GooglePhotosSecretStoring, @unchecked Sendable {
    let lock = NSLock(); var values: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { lock.lock(); defer { lock.unlock() }; return values[key] }
    func write(_ data: Data?, key: String) throws { lock.lock(); defer { lock.unlock() }; values[key] = data }
    func changeUploadDates(to date: Date) throws {
        lock.lock(); defer { lock.unlock() }
        for (key, data) in values where key.hasPrefix("upload-") {
            var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            if var session = json["session"] as? [String: Any] { session["createdAt"] = date.timeIntervalSinceReferenceDate; json["session"] = session }
            if json["tokenCreatedAt"] != nil { json["tokenCreatedAt"] = date.timeIntervalSinceReferenceDate }
            values[key] = try JSONSerialization.data(withJSONObject: json)
        }
    }
}
private let googleTestAccount = GooglePhotosAccount(id: "fixture-account-a", clientID: "fixture-client", subject: "fixture-sub-a", displayName: "test-account@example.invalid")
private actor GoogleTestCredentials: GooglePhotosCredentials {
    var current: GooglePhotosAccount? = googleTestAccount
    var tokenCalls = 0
    var action: (@Sendable (Int) async throws -> Void)?
    var accountAction: (@Sendable () async throws -> Void)?
    func setAccountAction(_ action: (@Sendable () async throws -> Void)?) { accountAction = action }
    func account() async throws -> GooglePhotosAccount? { if let accountAction { try await accountAction() }; return current }
    func set(_ account: GooglePhotosAccount?) { current = account }
    func setAction(_ action: @escaping @Sendable (Int) async throws -> Void) { self.action = action }
    func accessToken(accountID: String) async throws -> String {
        tokenCalls += 1; if let action { try await action(tokenCalls) }
        guard current?.id == accountID else { throw CocoaError(.userCancelled) }; return "fixture-access-token"
    }
}
private actor GoogleTestClient: GooglePhotosDelivering {
    var calls: [String: Int] = [:]
    var albumRows: [GooglePhotosAlbum] = []
    var sessionBytes: [String: Data] = [:]
    var tokenBytes: [String: Data] = [:]
    var albumMembers: [String: Set<String>] = [:]
    var hideMembers = false
    var lostAlbum = false
    var lostMedia = false
    var interruptedUpload = false
    var action: (@Sendable (String, Int) async throws -> Void)?
    func configure(lostAlbum: Bool = false, lostMedia: Bool = false, interruptedUpload: Bool = false, hideMembers: Bool = false) {
        self.lostAlbum = lostAlbum; self.lostMedia = lostMedia; self.interruptedUpload = interruptedUpload; self.hideMembers = hideMembers
    }
    func setAction(_ action: @escaping @Sendable (String, Int) async throws -> Void) { self.action = action }
    func call(_ name: String) async throws {
        calls[name, default: 0] += 1; if let action { try await action(name, calls[name]!) }
    }
    func albums(accountID: String) async throws -> [GooglePhotosAlbum] { try await call("albums"); return albumRows }
    func createAlbum(title: String, accountID: String) async throws -> GooglePhotosAlbum {
        calls["createAlbum", default: 0] += 1
        let album = GooglePhotosAlbum(id: "album-\(albumRows.count + 1)", title: title, productURL: "https://photos.google.com/album/fixture")
        albumRows.append(album)
        if let action { try await action("createAlbum", calls["createAlbum"]!) }
        if lostAlbum { lostAlbum = false; throw GooglePhotosFailure.network }; return album
    }
    func startUpload(size: Int64, mimeType: String, accountID: String) async throws -> GooglePhotosUploadSession {
        try await call("startUpload")
        let url = URL(string: "https://photoslibrary.googleapis.com/v1/uploads?upload_id=fixture-\(calls["startUpload"]!)")!
        sessionBytes[url.absoluteString] = Data(); return .init(url: url, granularity: 1024)
    }
    func queryUpload(_ session: GooglePhotosUploadSession, accountID: String) async throws -> GooglePhotosUploadProgress {
        try await call("queryUpload"); return .init(offset: Int64(sessionBytes[session.url.absoluteString]?.count ?? 0), active: true, token: nil)
    }
    func upload(_ session: GooglePhotosUploadSession, offset: Int64, data: Data, final: Bool, accountID: String) async throws -> String? {
        calls["upload", default: 0] += 1
        var bytes = sessionBytes[session.url.absoluteString] ?? Data()
        guard bytes.count == Int(offset) else { throw GooglePhotosFailure.invalidResponse }; bytes.append(data); sessionBytes[session.url.absoluteString] = bytes
        if let action { try await action("upload", calls["upload"]!) }
        if interruptedUpload { interruptedUpload = false; throw GooglePhotosFailure.network }
        if !final { return nil }
        let token = "token-" + MachineDescriptionHistory.digest(bytes); tokenBytes[token] = bytes; return token
    }
    func createMedia(token: String, fileName: String, albumID: String, accountID: String) async throws -> GooglePhotosCreatedMedia {
        try await call("createMedia")
        guard let bytes = tokenBytes[token] else { throw GooglePhotosFailure.invalidResponse }
        let media = GooglePhotosCreatedMedia(id: "media-" + MachineDescriptionHistory.digest(bytes), mimeType: "image/jpeg", productURL: "https://photos.google.com/photo/fixture")
        albumMembers[albumID, default: []].insert(media.id)
        if lostMedia { lostMedia = false; throw GooglePhotosFailure.network }; return media
    }
    func memberIDs(albumID: String, accountID: String) async throws -> Set<String> { try await call("members"); return hideMembers ? [] : albumMembers[albumID] ?? [] }
    func count(_ name: String) -> Int { calls[name] ?? 0 }
    func remoteCount() -> Int { Set(albumMembers.values.flatMap { $0 }).count }
    func uploaded() -> [Data] { Array(tokenBytes.values) }
}
private func googleFixture(_ root: URL, large: Bool = false, title: String = "Morning", count: Int = 1) async throws -> ImportResult {
    let source = root.appendingPathComponent("source-\(title)"); try AppDirectories.ensureExists(source)
    var items: [MediaItem] = []
    for n in 0..<count {
        let name = "photo-\(n).jpg", url = source.appendingPathComponent(name)
        try writeTestJPEGImage(url)
        if large { let handle = try FileHandle(forWritingTo: url); try handle.seekToEnd(); try handle.write(contentsOf: Data(repeating: 17, count: 5_000_000)); try handle.close() }
        items.append(makeTestMediaItem(sourceRoot: source, fileName: name, capturedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(n)), selectionState: .included))
    }
    let session = makeTestSession(sourceRoot: source, archiveRoot: root.appendingPathComponent("archive"), items: items, title: title)
    let result = try await ImportCoordinator().commit(session: session); try ArchiveIndexStore().rebuildIndex(archiveRoot: session.archiveRoot); return result
}
private func googleRepository(_ imported: ImportResult, role: ArchiveMachineRole = .mainArchive) -> GooglePhotosDeliveryRepository { .init(archiveRoot: imported.session.archiveRoot, machineRole: role) }
private func googleScope(_ imported: ImportResult) throws -> GooglePhotosDeliveryScope { try googleRepository(imported).trip(path: imported.tripManifests[0].folderRelativePath!) }
private func googleQueue(_ imported: ImportResult, client: GoogleTestClient, secrets: GoogleTestSecrets = .init(), credentials: GoogleTestCredentials = .init(), repository: GooglePhotosDeliveryRepository? = nil,
                         context: @escaping @Sendable () -> Bool = { true }) -> GooglePhotosDeliveryQueue {
    .init(archiveRoot: imported.session.archiveRoot, credentials: credentials, client: client, secrets: secrets, repository: repository ?? googleRepository(imported), contextIsCurrent: context)
}

@Test func googleDeliveryOriginalBytesCanonicalReceiptsAndFreshIndexOnlyTravel() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root, large: true), client = GoogleTestClient(), secrets = GoogleTestSecrets(), queue = googleQueue(imported, client: client, secrets: secrets)
    let job = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount)
    try await queue.run(jobIDs: [job.id])
    let complete = try #require(try await queue.jobs().first)
    #expect(complete.state == .completed && complete.photos.allSatisfy(\.committed) && complete.indexWarning == nil)
    let original = try Data(contentsOf: URL(fileURLWithPath: imported.fileManifests[0].archivePath))
    let observed1 = await client.uploaded()
    let observed2 = await client.count("upload")
    #expect(observed1 == [original] && observed2 == 2)
    let record = try #require(try GooglePhotosRecord.read(in: googleRepository(imported).canonical.text(job.photos[0].target)))
    #expect(record.memberships.count == 1 && record.memberships[0].originalSHA256 == MachineDescriptionHistory.digest(original))
    #expect(record.memberships[0].accountID == googleTestAccount.id && record.badge != nil)
    let rawJob = try String(contentsOf: ArchiveOperationRecovery(archiveRoot: imported.session.archiveRoot).root.appendingPathComponent("google-delivery-\(job.id.uuidString).json"), encoding: .utf8)
    #expect(!rawJob.contains("upload_id") && !rawJob.contains("token-") && !rawJob.contains("fixture-access-token"))
    let travel = root.appendingPathComponent("travel"); try AppDirectories.ensureExists(travel)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: imported.session.archiveRoot), to: ArchiveIndexStore.indexRoot(for: travel))
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: travel, supportedExtensions: ["jpg"], machineRole: .travel)
    #expect(catalogue.entries.first?.googlePhotos?.memberships.count == 1)
    var settings = AppSettings.default(); settings.archiveRoot = travel; settings.archiveMachineRole = .travel
    let items = try ArchiveIndexMediaLoader().load(folder: travel.appendingPathComponent(imported.walkManifest.archiveFolderRelativePath!), settings: settings)
    #expect(items[0].googlePhotos?.memberships.count == 1 && !FileManager.default.fileExists(atPath: items[0].sourceURL.path))
    let next = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run(jobIDs: [next.id])
    let observed3 = await client.count("createAlbum")
    let observed4 = await client.count("createMedia")
    #expect(observed3 == 1 && observed4 == 1)
}

@Test func googleLostAlbumResponseRequiresExplicitReconciliationAndNeverCreatesAnotherAutomatically() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.configure(lostAlbum: true)
    let job = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let observed5 = try await queue.jobs()
    #expect(observed5.first?.state == .needsReconciliation)
    try await queue.run();
    let observed6 = await client.count("createAlbum")
    #expect(observed6 == 1)
    let candidates = try await queue.candidates(jobID: job.id);
    #expect(candidates.count == 1)
    try await queue.adopt(albumID: candidates[0].id, jobID: job.id); try await queue.run()
    let observed7 = try await queue.jobs()
    let observed8 = await client.count("createAlbum")
    #expect(observed7.first?.state == .completed && observed8 == 1)
}

@Test func googleLostMediaResponseDeduplicatesExactOriginalOnRetry() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.configure(lostMedia: true)
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let observed9 = try await queue.jobs()
    let observed10 = await client.remoteCount()
    #expect(observed9.first?.state == .failed && observed10 == 1)
    try await queue.run()
    let observed11 = try await queue.jobs()
    let observed12 = await client.remoteCount()
    #expect(observed11.first?.state == .completed && observed12 == 1)
    let observed13 = await client.count("createMedia")
    let observed14 = await client.count("startUpload")
    #expect(observed13 == 2 && observed14 == 1)
}

@Test func googleInterruptedUploadQueriesServerAndResumesItsOffset() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root, large: true), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.configure(interruptedUpload: true)
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let observed15 = await client.count("createMedia")
    #expect(observed15 == 0)
    try await queue.run()
    let observed16 = try await queue.jobs()
    let observed17 = await client.count("queryUpload")
    #expect(observed16.first?.state == .completed && observed17 == 1)
    let observed18 = await client.count("startUpload")
    let observed19 = await client.count("upload")
    #expect(observed18 == 1 && observed19 == 2)
    let observed20 = await client.uploaded()
    #expect(observed20 == [try Data(contentsOf: URL(fileURLWithPath: imported.fileManifests[0].archivePath))])
}

@Test func googleStreamingMutationCannotCacheOrPublishChangedBytesEvenAfterRestore() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root, large: true), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    let url = URL(fileURLWithPath: imported.fileManifests[0].archivePath), original = try Data(contentsOf: url)
    await client.setAction { event, count in
        if event == "upload" && count == 1 { var changed = original; changed[4_500_000] ^= 1; try changed.write(to: url) }
    }
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let observed21 = await client.count("createMedia")
    let observed22 = await client.count("upload")
    #expect(observed21 == 0 && observed22 == 1)
    try original.write(to: url); try await queue.run()
    let observed23 = try await queue.jobs()
    let observed24 = await client.uploaded()
    #expect(observed23.first?.state == .completed && observed24 == [original])
}

@Test func googleVerificationRetryNeverRepeatsUploadOrCreation() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.configure(hideMembers: true)
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let observed25 = try await queue.jobs()
    #expect(observed25.first?.photos[0].committed == false)
    await client.configure(); try await queue.run()
    let observed26 = try await queue.jobs()
    let observed27 = await client.count("createMedia")
    let observed28 = await client.count("startUpload")
    #expect(observed26.first?.state == .completed && observed27 == 1 && observed28 == 1)
}

private final class GoogleOneFailure: @unchecked Sendable {
    let lock = NSLock(); var failed = false
    func shouldFail(_ trigger: Bool) -> Bool { lock.lock(); defer { lock.unlock() }; if trigger && !failed { failed = true; return true }; return false }
}
@Test(arguments: [false, true]) func googleRemoteSuccessSurvivesCanonicalAndReceiptFailureWithoutAnotherRequest(_ receipt: Bool) async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), failure = GoogleOneFailure(), secrets = GoogleTestSecrets()
    var repository = googleRepository(imported)
    if !receipt { repository.write = { text, url in if failure.shouldFail(text.contains("membershipVerifiedAt") && url.deletingLastPathComponent().lastPathComponent == imported.tripManifests[0].folder.lastPathComponent) { throw CocoaError(.fileWriteOutOfSpace) }; try text.write(to: url, atomically: true, encoding: .utf8) } }
    let queue = GooglePhotosDeliveryQueue(archiveRoot: imported.session.archiveRoot, credentials: GoogleTestCredentials(), client: client, secrets: secrets, repository: repository,
        persist: { job, root in if receipt && failure.shouldFail(job.photos.contains(where: \.committed)) { throw CocoaError(.fileWriteOutOfSpace) }; try ArchiveOperationRecovery(archiveRoot: root).save(job, kind: "google-delivery", sessionID: job.id) })
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run(); try await queue.run()
    let observed29 = try await queue.jobs()
    let observed30 = await client.count("createMedia")
    let observed31 = await client.count("members")
    #expect(observed29.first?.state == .completed && observed30 == 1 && observed31 == 1)
    let observed32 = try await queue.jobs()
    #expect(try GooglePhotosRecord.read(in: googleRepository(imported).canonical.text((observed32)[0].photos[0].target))?.memberships.count == 1)
}

@Test func googleExpiredSessionOrTokenReuploadsCapturedBytesAndDeduplicates() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), secrets = GoogleTestSecrets(), queue = googleQueue(imported, client: client, secrets: secrets)
    await client.configure(lostMedia: true)
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    try secrets.changeUploadDates(to: Date().addingTimeInterval(-8 * 86_400)); try await queue.run()
    let observed33 = try await queue.jobs()
    let observed34 = await client.count("startUpload")
    let observed35 = await client.remoteCount()
    #expect(observed33.first?.state == .completed && observed34 == 2 && observed35 == 1)
}

@Test func googleCapturedAccountAndContextChangesStopFurtherRequests() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), credentials = GoogleTestCredentials(), context = GooglePhotosContextCounter()
    let queue = googleQueue(imported, client: client, credentials: credentials, context: { context.generation == 0 })
    await client.setAction { event, _ in if event == "createAlbum" { context.invalidate() } }
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let observed36 = await client.count("startUpload")
    let observed37 = try await queue.jobs()
    #expect(observed36 == 0 && (observed37)[0].binding != nil)
    let secondQueue = googleQueue(imported, client: client, credentials: credentials)
    await credentials.set(.init(id: "fixture-account-b", clientID: "fixture-client", subject: "fixture-sub-b", displayName: "second@example.invalid"))
    try await secondQueue.run();
    let observed38 = await client.count("startUpload")
    #expect(observed38 == 0)
    await credentials.set(googleTestAccount); try await secondQueue.run();
    let observed39 = try await secondQueue.jobs()
    #expect((observed39)[0].state == .completed)
}

@Test func googleTravelNeedsExactViewGrantAndNeverFallsBackToThumbnail() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), repository = googleRepository(imported, role: .travel), scope = try googleScope(imported)
    var settings = AppSettings.default(); settings.archiveRoot = imported.session.archiveRoot; settings.archiveMachineRole = .travel
    ArchiveByteReadPolicyContext.shared.update(settings: settings)
    #expect(throws: (any Error).self) { try repository.capture(scope, includeMarked: true) }
    let photo = URL(fileURLWithPath: imported.fileManifests[0].archivePath)
    #expect(ArchiveByteReadPolicyContext.shared.grantExplicitViewing(at: photo, generation: ArchiveByteReadPolicyContext.shared.generation))
    #expect(try repository.capture(scope, includeMarked: true).count == 1)
    ArchiveByteReadPolicyContext.shared.update(settings: settings)
    #expect(throws: (any Error).self) { try repository.capture(scope, includeMarked: true) }
}

@Test func googleManualWalkMarksExcludeTripAndPhotoLogWithoutPretendingVerification() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), repository = googleRepository(imported)
    let walk = try repository.canonical.snapshot(kind: .walk, path: imported.walkManifest.archiveFolderRelativePath!).target
    try repository.mark(walk, note: "I uploaded this before Walkfolio.", clear: false)
    let trip = try googleScope(imported), log = try repository.photoLog(id: imported.session.id, title: "Log", paths: trip.photos.map(\.path))
    #expect(try repository.capture(trip, includeMarked: false).isEmpty && repository.capture(log, includeMarked: false).isEmpty)
    #expect(try repository.capture(trip, includeMarked: true).count == 1)
    let record = try #require(try GooglePhotosRecord.read(in: repository.canonical.text(walk)))
    #expect(record.memberships.isEmpty && record.badge == "Marked previously uploaded")
    try repository.mark(walk, note: "", clear: true); #expect(try repository.capture(trip, includeMarked: false).count == 1)
}

@Test func googleCancelledUnknownAlbumCanReconcileWithoutAnInterveningResume() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.setAction { event, _ in if event == "createAlbum" { try await Task.sleep(nanoseconds: 30_000_000_000) } }
    let job = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount)
    let run = Task { try await queue.run() }
    while await client.count("createAlbum") == 0 { try await Task.sleep(nanoseconds: 1_000_000) }
    await queue.cancel(); try await run.value
    let candidates = try await queue.candidates(jobID: job.id);
    #expect(candidates.count == 1)
    try await queue.adopt(albumID: candidates[0].id, jobID: job.id)
    let observed40 = try await queue.jobs()
    #expect(observed40.first?.binding?.album.id == candidates[0].id)
}

@Test func googleAbandonedKnownAlbumRetainsBindingForFreshCapturedDelivery() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.configure(hideMembers: true)
    let job = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    try await queue.abandon(jobID: job.id); await client.configure()
    let fresh = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run(jobIDs: [fresh.id])
    let observed41 = await client.count("createAlbum")
    let observed42 = await client.remoteCount()
    #expect(observed41 == 1 && observed42 == 1)
    let observed43 = try await queue.jobs()
    #expect((observed43).first { $0.id == job.id }?.state == .abandoned)
}

private func googleHTTP(_ request: URLRequest, json: Any, code: Int = 200, headers: [String: String] = [:]) throws -> GooglePhotosHTTPResult {
    .init(data: try JSONSerialization.data(withJSONObject: json), response: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: headers)!)
}
@Test func googleOAuthPKCECallbackStateAndGrantedScopes() async throws {
    let request = try GooglePhotosOAuthRequest(clientID: "fixture-client", redirect: URL(string: "http://127.0.0.1:9876/oauth2/callback")!, state: "fixture-state", verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    #expect(request.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    #expect(try request.code(from: URL(string: "http://127.0.0.1:9876/oauth2/callback?state=fixture-state&code=fixture-code")!) == "fixture-code")
    for suffix in ["?state=wrong&code=x", "?state=fixture-state&state=fixture-state&code=x", "?state=fixture-state&error=access_denied"] {
        #expect(throws: (any Error).self) { try request.code(from: URL(string: request.redirect.absoluteString + suffix)!) }
    }
    let secrets = GoogleTestSecrets()
    let auth = GooglePhotosAuthentication(secrets: secrets, transport: .init(send: { req in
        if req.url!.path == "/token" { return try googleHTTP(req, json: ["access_token": "fixture-access", "refresh_token": "fixture-refresh", "token_type": "Bearer", "expires_in": 3600, "scope": "openid https://www.googleapis.com/auth/photoslibrary.appendonly"]) }
        return try googleHTTP(req, json: ["sub": "fixture-sub"])
    }))
    await #expect(throws: (any Error).self) { try await auth.exchange(code: "fixture-code", request: request) }
    let observed44 = try await auth.account()
    let storedCredential = try secrets.read("account")
    #expect(observed44 == nil && storedCredential == nil)
}

@Test func googleLoopbackRetainsEarlyCallbackAndCancellationStopsWaiting() async throws {
    let listener = GooglePhotosLoopback(), redirect = try await listener.start()
    let callback = URL(string: redirect.absoluteString + "?state=fixture&code=fixture")!
    let response = try await URLSession.shared.data(from: callback)
    #expect((response.1 as? HTTPURLResponse)?.statusCode == 200)
    #expect(try await listener.wait() == callback)
    let cancelled = GooglePhotosLoopback(), task = Task { try await cancelled.start() }; task.cancel()
    _ = try? await task.value; cancelled.cancel()
}

@Test func googleProtocolPaginationEmptyPagesOriginalPayloadAndSafeErrors() async throws {
    let credentials = GoogleTestCredentials(), gate = GoogleOneFailure()
    let client = GooglePhotosClient(credentials: credentials, transport: .init(send: { req in
        if req.url!.path == "/v1/mediaItems:search" {
            let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
            if body["pageToken"] == nil { return try googleHTTP(req, json: ["nextPageToken": "second"]) }
            return try googleHTTP(req, json: ["mediaItems": [["id": "fixture-media"]]])
        }
        if req.url!.path == "/v1/mediaItems:batchCreate" {
            let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any], items = body["newMediaItems"] as! [[String: Any]]
            #expect(items[0]["description"] == nil && body["albumId"] as? String == "fixture-album")
            return try googleHTTP(req, json: ["newMediaItemResults": [["uploadToken": "fixture-token", "status": [:], "mediaItem": ["id": "fixture-media", "mimeType": "image/jpeg"]]]], code: 207)
        }
        if gate.shouldFail(true) { return try googleHTTP(req, json: ["error": "fixture-private-detail"], code: 429, headers: ["Retry-After": "1"]) }
        return try googleHTTP(req, json: ["albums": []])
    }))
    #expect(try await client.memberIDs(albumID: "fixture-album", accountID: googleTestAccount.id) == ["fixture-media"])
    #expect(try await client.createMedia(token: "fixture-token", fileName: "original.jpg", albumID: "fixture-album", accountID: googleTestAccount.id).id == "fixture-media")
    do { _ = try await client.albums(accountID: googleTestAccount.id); Issue.record("Quota should fail") }
    catch GooglePhotosFailure.quota(let date) { #expect(date.timeIntervalSinceNow > 29) }
    catch { Issue.record("Unexpected safe error") }
    #expect(!GooglePhotosFailure.permission.localizedDescription.contains("fixture-private-detail"))
}

@Test func googleProtocolRefusesUntrustedSessionAndCredentialFailureIsProvenNotSent() async throws {
    let credentials = GoogleTestCredentials(), client = GooglePhotosClient(credentials: credentials, transport: .init(send: { _ in Issue.record("Untrusted or unauthorised request must not send"); throw GooglePhotosFailure.network }))
    await #expect(throws: (any Error).self) { try await client.queryUpload(.init(url: URL(string: "https://example.invalid/steal")!, granularity: 1024), accountID: googleTestAccount.id) }
    await credentials.set(nil)
    await #expect(throws: GooglePhotosFailure.self) { try await client.createAlbum(title: "Trip", accountID: googleTestAccount.id) }
}

@Test @MainActor func googleAppStateReviewCapturesTripAndDoesNotSendUntilConfirmed() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), credentials = GoogleTestCredentials()
    var settings = AppSettings.default(); settings.archiveRoot = imported.session.archiveRoot; settings.oneDrivePicturesRoot = settings.archiveRoot; settings.googlePhotosClientID = googleTestAccount.clientID
    let app = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingGoogleCredentials: credentials, testingGoogleClient: client, testingGoogleSecrets: GoogleTestSecrets())
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: settings.archiveRoot, supportedExtensions: ["jpg"])
    app.testingInstallArchiveCatalogue(catalogue); app.setWorkspaceMode(.archiveView); app.selectArchiveEntry(catalogue.entries[0].id)
    await app.reviewGoogleTrip(); let review = try #require(app.googleDeliveryReview)
    let observed45 = await client.count("createAlbum")
    #expect(observed45 == 0 && review.photoCount == 1)
    app.setWorkspaceMode(.cameraTriage)
    await app.confirmGoogleDelivery(review)
    let observed46 = await client.count("createAlbum")
    #expect(app.googleDeliveryJobs.first?.state == .completed && observed46 == 1)
    app.googleDeliveryReview = nil; await app.reviewGoogleTrip();
    #expect(app.googleDeliveryReview == nil)
}

private actor GoogleTestBarrier {
    var entered = false
    var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    var releaseWaiter: CheckedContinuation<Void, Never>?
    func stop() async {
        entered = true; for waiter in enteredWaiters { waiter.resume() }; enteredWaiters = []
        await withCheckedContinuation { releaseWaiter = $0 }
    }
    func waitForEntry() async { if !entered { await withCheckedContinuation { enteredWaiters.append($0) } } }
    func release() { releaseWaiter?.resume(); releaseWaiter = nil }
}
@Test @MainActor func googleCancelDuringConfirmedPreparationCannotStartAnUpload() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), credentials = GoogleTestCredentials(), gate = GoogleTestBarrier()
    var settings = AppSettings.default(); settings.archiveRoot = imported.session.archiveRoot; settings.oneDrivePicturesRoot = settings.archiveRoot; settings.googlePhotosClientID = googleTestAccount.clientID
    let app = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingGoogleCredentials: credentials, testingGoogleClient: client, testingGoogleSecrets: GoogleTestSecrets())
    await app.reviewGoogleScope(try googleScope(imported)); let review = try #require(app.googleDeliveryReview)
    await credentials.setAccountAction { await gate.stop() }
    let task = Task { await app.confirmGoogleDelivery(review) }
    await gate.waitForEntry(); app.cancelGoogleDelivery(); await gate.release(); await task.value
    let albums = await client.count("createAlbum"), uploads = await client.count("startUpload"), requests = await client.count("albums")
    #expect(albums == 0 && uploads == 0 && requests == 0 && !app.isDeliveringGooglePhotos)
    await credentials.setAccountAction(nil); await app.loadGoogleDeliveryQueue()
    #expect(app.googleDeliveryJobs.isEmpty)
}
@Test func googleFreshDeliveryRepairsMissingOwnerReceiptAfterAbandonment() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), failure = GoogleOneFailure(), scope = try googleScope(imported)
    var repository = googleRepository(imported)
    let ownerURL = imported.tripManifests[0].folder.appendingPathComponent(imported.tripManifests[0].folder.lastPathComponent + ".md")
    repository.write = { text, url in
        if failure.shouldFail(url == ownerURL && text.contains("membershipVerifiedAt")) { throw CocoaError(.fileWriteOutOfSpace) }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
    let queue = googleQueue(imported, client: client, repository: repository)
    let first = try await queue.enqueue(scope: scope, expectedAccount: googleTestAccount); try await queue.run()
    #expect(try GooglePhotosRecord.read(in: repository.canonical.text(first.photos[0].target))?.memberships.count == 1)
    #expect(try GooglePhotosRecord.read(in: repository.ownerText(scope))?.memberships.isEmpty == true)
    try await queue.abandon(jobID: first.id)
    let fresh = try await queue.enqueue(scope: scope, expectedAccount: googleTestAccount); try await queue.run(jobIDs: [fresh.id])
    let jobs = try await queue.jobs(), creates = await client.count("createMedia"), members = await client.count("members")
    #expect(jobs.first { $0.id == fresh.id }?.state == .completed && creates == 1 && members == 1)
    #expect(try GooglePhotosRecord.read(in: repository.ownerText(scope))?.memberships.count == 1)
    #expect(try GooglePhotosRecord.read(in: repository.canonical.text(first.photos[0].target))?.memberships.count == 1)
}
@Test func googleCropHasNoReceiptAndDoesNotInflateOriginalCoverage() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    var settings = AppSettings.default(); settings.archiveRoot = imported.session.archiveRoot
    let original = try #require(try ArchiveIndexMediaLoader().load(folder: imported.walkManifest.archiveFolder, settings: settings).first)
    _ = try CropService().crop(item: original, normalizedRect: .init(x: 0.25, y: 0.25, width: 0.5, height: 0.5), trigger: .manualDrag, appRelease: .init(version: "fixture", build: "1", featureSlug: "google-crop"))
    try ArchiveIndexStore().rebuildIndex(archiveRoot: settings.archiveRoot)
    let items = try ArchiveIndexMediaLoader().load(folder: imported.walkManifest.archiveFolder, settings: settings)
    #expect(items.count == 2 && items.first { $0.cropRelationship?.isCrop == true }?.googlePhotos == nil)
    #expect(items.first { $0.cropRelationship?.isCrop != true }?.googlePhotos?.memberships.count == 1)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: settings.archiveRoot, supportedExtensions: ["jpg"])
    let trip = try #require(catalogue.entries.first), walk = try #require(catalogue.walksByTripPath.values.first?.first)
    #expect(trip.photoCount == 2 && trip.originalPhotoCount == 1 && trip.googlePhotos?.coverageBadge(total: trip.originalPhotoCount!) == "Google Photos: 1/1 originals recorded")
    #expect(walk.photoCount == 2 && walk.originalPhotoCount == 1 && walk.googlePhotos?.coverageBadge(total: walk.originalPhotoCount!) == "Google Photos: 1/1 originals recorded")
}
private func googleIndexDigests(_ archive: URL) throws -> [String: String] {
    let root = ArchiveIndexStore.indexRoot(for: archive), files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
    var result: [String: String] = [:]
    for case let url as URL in files where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true { result[url.path] = try ArchiveFileVerification.sha256(at: url) }
    return result
}
@Test @MainActor func googleTravelManualMarkAndClearUpdateDisplayWithoutIndexMutation() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), archive = imported.session.archiveRoot
    let historical = archive.appendingPathComponent("2020/Old visit"); try AppDirectories.ensureExists(historical); try writeTestJPEGImage(historical.appendingPathComponent("old.jpg"))
    let note = historical.appendingPathComponent("Old visit.md"); try "My original human note.".write(to: note, atomically: true, encoding: .utf8)
    try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    var settings = AppSettings.default(); settings.archiveRoot = archive; settings.oneDrivePicturesRoot = archive; settings.archiveMachineRole = .travel
    let app = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support")), before = try googleIndexDigests(archive)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: archive, supportedExtensions: ["jpg"], machineRole: .travel)
    let folder = try #require(catalogue.entries.first { $0.kind == .unorganisedFolder })
    app.testingInstallArchiveCatalogue(catalogue); app.setWorkspaceMode(.archiveView); app.selectArchiveEntry(folder.id)
    await app.markGoogleMaterial(clear: false)
    #expect(app.archiveBrowserState.snapshot.entries.first { $0.id == folder.id }?.googlePhotos?.badge == "Marked previously uploaded")
    await app.markGoogleMaterial(clear: true)
    #expect(app.archiveBrowserState.snapshot.entries.first { $0.id == folder.id }?.googlePhotos?.badge == nil)
    #expect(try googleIndexDigests(archive) == before)
    let text = try String(contentsOf: note, encoding: .utf8)
    #expect(text.contains("My original human note.") && !text.contains("Trip ID:"))
    let trip = try #require(catalogue.entries.first { $0.kind == .trip }); app.selectArchiveEntry(trip.id)
    await app.markGoogleMaterial(clear: false)
    #expect(app.archiveBrowserState.snapshot.entries.first { $0.id == trip.id }?.googlePhotos?.manualMarks.count == 1)
    await app.markGoogleMaterial(clear: true)
    #expect(app.archiveBrowserState.snapshot.entries.first { $0.id == trip.id }?.googlePhotos?.badge == nil)
    #expect(try googleIndexDigests(archive) == before)
}

@Test @MainActor func googleTravelDeliveryUpdatesWalkAndPhotoLogBadgesWithoutWritingIndex() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient()
    var settings = AppSettings.default(); settings.archiveRoot = imported.session.archiveRoot; settings.oneDrivePicturesRoot = settings.archiveRoot; settings.archiveMachineRole = .travel; settings.googlePhotosClientID = googleTestAccount.clientID
    let app = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingGoogleCredentials: GoogleTestCredentials(), testingGoogleClient: client, testingGoogleSecrets: GoogleTestSecrets())
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: settings.archiveRoot, supportedExtensions: ["jpg"], machineRole: .travel)
    app.testingInstallArchiveCatalogue(catalogue); app.currentSession = imported.session
    #expect(ArchiveByteReadPolicyContext.shared.grantExplicitViewing(at: imported.session.mediaItems[0].destinationURL!, generation: ArchiveByteReadPolicyContext.shared.generation))
    let before = try googleIndexDigests(settings.archiveRoot)
    await app.reviewGooglePhotoLog(); let review = try #require(app.googleDeliveryReview)
    await app.confirmGoogleDelivery(review)
    #expect(app.googleDeliveryJobs.first?.state == .completed && app.currentSession?.mediaItems[0].googlePhotos?.memberships.count == 1)
    let scope = review.scope
    #expect(try GooglePhotosRecord.read(in: googleRepository(imported, role: .travel).ownerText(scope))?.memberships.count == 1)
    app.setWorkspaceMode(.archiveView); app.selectArchiveEntry(catalogue.entries[0].id); app.openSelectedArchiveItem()
    #expect(app.archiveBrowserState.snapshot.walks.first?.googlePhotos?.memberships.count == 1)
    #expect(try googleIndexDigests(settings.archiveRoot) == before)
}
@Test @MainActor func googleMovedHistoricalReceiptDoesNotBlockNewScopedDeliveryDisplay() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let old = try await googleFixture(root, title: "Morning"), client = GoogleTestClient(), secrets = GoogleTestSecrets(), credentials = GoogleTestCredentials()
    let queue = googleQueue(old, client: client, secrets: secrets, credentials: credentials)
    let oldJob = try await queue.enqueue(scope: googleScope(old), expectedAccount: googleTestAccount); try await queue.run()
    try FileManager.default.removeItem(at: old.tripManifests[0].folder)
    let fresh = try await googleFixture(root, title: "Evening")
    var settings = AppSettings.default(); settings.archiveRoot = fresh.session.archiveRoot; settings.oneDrivePicturesRoot = settings.archiveRoot; settings.googlePhotosClientID = googleTestAccount.clientID
    let app = AppState(testing: true, testingSettings: settings, testingSupportRoot: root.appendingPathComponent("support"), testingGoogleCredentials: credentials, testingGoogleClient: client, testingGoogleSecrets: secrets)
    app.currentSession = fresh.session
    await app.reviewGoogleScope(try googleScope(fresh)); await app.confirmGoogleDelivery(try #require(app.googleDeliveryReview))
    #expect(app.googleDeliveryJobs.first { $0.id != oldJob.id }?.state == .completed)
    #expect(app.currentSession?.mediaItems[0].googlePhotos?.memberships.count == 1)
    #expect(!app.statusMessage.hasPrefix("Google Photos delivery stopped"))
}
@Test func googleQuotaStopsImmediateRetryAndAllowsExplicitLaterResume() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    await client.setAction { event, count in if event == "startUpload" && count == 1 { throw GooglePhotosFailure.quota(Date().addingTimeInterval(30)) } }
    let job = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount); try await queue.run()
    let failed = try #require(try await queue.jobs().first)
    #expect(failed.state == .failed && failed.retryAfter!.timeIntervalSinceNow > 29)
    try await queue.run()
    let starts = await client.count("startUpload"); #expect(starts == 1)
    var saved = failed; saved.retryAfter = Date().addingTimeInterval(-1)
    try ArchiveOperationRecovery(archiveRoot: imported.session.archiveRoot).save(saved, kind: "google-delivery", sessionID: job.id)
    try await queue.run()
    let resumed = try #require(try await queue.jobs().first); #expect(resumed.state == .completed)
}
@Test func googleOldRefreshCannotOverwriteNewAccountExchange() async throws {
    let secrets = GoogleTestSecrets(), gate = GoogleTestBarrier()
    let auth = GooglePhotosAuthentication(secrets: secrets, transport: .init(send: { request in
        if request.url!.path == "/token" {
            let body = String(decoding: request.httpBody!, as: UTF8.self)
            let refresh = body.contains("grant_type=refresh_token"), initial = body.contains("code=initial")
            if refresh { await gate.stop() }
            return try googleHTTP(request, json: ["access_token": refresh ? "old-refreshed" : (initial ? "old" : "new"), "refresh_token": "fixture-refresh", "token_type": "Bearer", "expires_in": initial ? 1 : 3600, "scope": (GooglePhotosOAuthRequest.photosScopes.union(["openid", "email"])).joined(separator: " ")])
        }
        return try googleHTTP(request, json: ["sub": "fixture-sub", "email": "test@example.invalid"])
    }))
    let request = try GooglePhotosOAuthRequest(clientID: "fixture-client", redirect: URL(string: "http://127.0.0.1:9876/oauth2/callback")!, state: "fixture-state", verifier: "fixture-verifier")
    let account = try await auth.exchange(code: "initial", request: request)
    let refresh = Task { try await auth.accessToken(accountID: account.id) }
    await gate.waitForEntry(); _ = try await auth.exchange(code: "new", request: request); await gate.release()
    await #expect(throws: (any Error).self) { try await refresh.value }
    #expect(try await auth.accessToken(accountID: account.id) == "new")
}
@Test func googleInvalidRecoveryProgressIsRetainedWithoutSendingOrCrashing() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    var job = try await queue.enqueue(scope: googleScope(imported), expectedAccount: googleTestAccount)
    job.photos[0].verifiedAt = Date(); job.photos[0].media = nil
    try ArchiveOperationRecovery(archiveRoot: imported.session.archiveRoot).save(job, kind: "google-delivery", sessionID: job.id)
    await #expect(throws: (any Error).self) { try await queue.run() }
    let calls = await client.count("albums"); #expect(calls == 0)
    #expect(FileManager.default.fileExists(atPath: ArchiveOperationRecovery(archiveRoot: imported.session.archiveRoot).root.appendingPathComponent("google-delivery-\(job.id.uuidString).json").path))
}
private actor GoogleJourneyDescriptionClient: DescriptionGenerating {
    var calls = 0
    func models(configuration: LMStudioConfiguration) async throws -> [String] { ["fixture-vision"] }
    func complete(configuration: LMStudioConfiguration, prompt: LMStudioPrompt) async throws -> LMStudioCompletion {
        calls += 1; return .init(text: "A stone wall beside a woodland footpath.", model: "fixture-vision")
    }
}
@Test func completeCameraPhoneArchiveStoryTravelAndVerifiedAlbumJourney() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let camera = root.appendingPathComponent("camera"), phone = root.appendingPathComponent("phone"), archive = root.appendingPathComponent("archive"), day = Date(timeIntervalSince1970: 1_700_000_000)
    try AppDirectories.ensureExists(camera); try AppDirectories.ensureExists(phone)
    let sources = [SourceProvenance(folder: camera, label: "Camera"), SourceProvenance(folder: phone, label: "Phone")]
    var items: [MediaItem] = []
    for n in 0..<3 {
        let folder = n == 0 ? camera : phone, name = "image-\(n).jpg", url = folder.appendingPathComponent(name)
        try writeTestJPEGImage(url); let handle = try FileHandle(forWritingTo: url); try handle.seekToEnd(); try handle.write(contentsOf: Data("fixture-\(n)".utf8)); try handle.close()
        var item = makeTestMediaItem(sourceRoot: folder, fileName: name, capturedAt: day.addingTimeInterval(Double(n) * 3600), selectionState: .included)
        item.sourceProvenanceID = sources[n == 0 ? 0 : 1].id; item.metadata.latitude = 51.84; item.metadata.longitude = -1.36
        items.append(item)
    }
    var session = makeTestSession(sourceRoot: camera, archiveRoot: archive, items: items, title: "Park visit", notes: "My own story.")
    session.sourceProvenances = sources
    session.proposedWalks = [Walk(title: "Morning", date: day, sourceProvenanceIDs: sources.map(\.id), mediaItemIDs: [items[0].id, items[1].id], tripTarget: .newNamed(title: "Oxford")), Walk(title: "Evening", date: day.addingTimeInterval(7200), sourceProvenanceIDs: [sources[1].id], mediaItemIDs: [items[2].id], tripTarget: .newNamed(title: "Oxford"))]
    let imported = try await ImportCoordinator().commit(session: session)
    #expect(imported.walkManifests.count == 2 && imported.tripManifests.count == 1 && imported.fileManifests.count == 3)
    for file in imported.fileManifests {
        let url = URL(fileURLWithPath: file.archivePath).deletingPathExtension().appendingPathExtension("md")
        let text = try String(contentsOf: url, encoding: .utf8)
        try (text + "\nHuman recollection of the walk.\n").write(to: url, atomically: true, encoding: .utf8)
    }
    for walk in imported.walkManifests {
        _ = try ArchiveLocationEditor().save(target: .init(walkRelativePath: walk.archiveFolderRelativePath!, sessionID: walk.sessionID, walkID: walk.walkID), name: "Blenheim Park", coordinate: .init(latitude: 51.85, longitude: -1.37), archiveRoot: archive)
    }
    let descriptionClient = GoogleJourneyDescriptionClient(), descriptionQueue = ArchiveDescriptionQueue(archiveRoot: archive, machineRole: .mainArchive, client: descriptionClient)
    let config = LMStudioConfiguration(baseURL: "http://localhost:1234/v1", model: "fixture-vision")
    let descriptions = try await descriptionQueue.enqueue(targets: [(.trip, imported.tripManifests[0].folderRelativePath!)], configuration: config)
    #expect(descriptions.count == 6); try await descriptionQueue.run()
    let client = GoogleTestClient(), queue = googleQueue(imported, client: client)
    let scope = try googleScope(imported), job = try await queue.enqueue(scope: scope, expectedAccount: googleTestAccount); try await queue.run(jobIDs: [job.id])
    let delivered = try #require(try await queue.jobs().first), remote = await client.remoteCount()
    #expect(delivered.state == .completed && remote == 3)
    let noNewDescriptions = try await descriptionQueue.enqueue(targets: [(.trip, scope.path)], configuration: config)
    #expect(noNewDescriptions.isEmpty)
    try FileManager.default.removeItem(at: ArchiveIndexStore.indexRoot(for: archive)); try ArchiveIndexStore().rebuildIndex(archiveRoot: archive)
    let catalogue = try ArchiveCatalogueBuilder().build(archiveRoot: archive, supportedExtensions: ["jpg"])
    #expect(catalogue.entries[0].photoCount == 3 && catalogue.walksByTripPath.values.first?.count == 2)
    #expect(catalogue.entries[0].googlePhotos?.coverageBadge(total: 3) == "Google Photos: 3/3 originals recorded")
    let travel = root.appendingPathComponent("travel"); try AppDirectories.ensureExists(travel)
    try FileManager.default.copyItem(at: ArchiveIndexStore.indexRoot(for: archive), to: ArchiveIndexStore.indexRoot(for: travel))
    let travelCatalogue = try ArchiveCatalogueBuilder().build(archiveRoot: travel, supportedExtensions: ["jpg"], machineRole: .travel)
    let map = ArchiveMapProjection.snapshot(catalogue: travelCatalogue, visibleEntries: travelCatalogue.entries, searchQuery: "", matchingPaths: [])
    #expect(map.locatedWalks.count == 2 && map.locatedWalks.allSatisfy { $0.coordinate?.latitude == 51.85 })
    let rows = try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: travel), search = ArchiveSearchCache(databaseURL: root.appendingPathComponent("search.sqlite"))
    try search.rebuild(indexEntries: rows, browseEntries: travelCatalogue.entries)
    #expect(try search.matchingPaths(query: "woodland").count == 6)
    var settings = AppSettings.default(); settings.archiveRoot = travel; settings.archiveMachineRole = .travel
    for walk in imported.walkManifests {
        let grid = try ArchiveIndexMediaLoader().load(folder: travel.appendingPathComponent(walk.archiveFolderRelativePath!), settings: settings)
        #expect(grid.allSatisfy { $0.googlePhotos?.memberships.count == 1 && !FileManager.default.fileExists(atPath: $0.sourceURL.path) })
    }
    for file in imported.fileManifests {
        let text = try String(contentsOf: URL(fileURLWithPath: file.archivePath).deletingPathExtension().appendingPathExtension("md"), encoding: .utf8)
        #expect(text.contains("Human recollection") && text.contains("fixture-vision") && ArchiveManifestText.scalar("latitude", in: text) == "51.84")
    }
    #expect(items.allSatisfy { FileManager.default.fileExists(atPath: $0.sourceURL.path) })
}

@Test func googlePhotoLogOwnerIdentityReadsQuotedAndPlainRecoveryForms() async throws {
    let root = try makeTemporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let imported = try await googleFixture(root), repository = googleRepository(imported), trip = try googleScope(imported)
    let log = try repository.photoLog(id: imported.session.id, title: "Log", paths: trip.photos.map(\.path))
    let url = imported.session.archiveRoot.appendingPathComponent(log.path); try AppDirectories.ensureExists(url.deletingLastPathComponent())
    for quoted in [false, true] {
        let value = quoted ? "`\(log.id.uuidString)`" : log.id.uuidString
        try "# Photo Log\n\n- Photo Log ID: \(value)\n".write(to: url, atomically: true, encoding: .utf8)
        #expect(try repository.capture(log, includeMarked: true).count == 1)
    }
    try "# Photo Log\n\n- Photo Log ID: `\(UUID().uuidString)`\n".write(to: url, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try repository.ownerText(log) }
}
