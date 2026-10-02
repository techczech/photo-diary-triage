import Foundation
import ImageIO
import UniformTypeIdentifiers

struct DescriptionSnapshot: Codable, Hashable, Sendable {
    var target: DescriptionReference
    var baseline: String
    var activeID: UUID?
    var parentIdentity: UUID?
    var children: [DescriptionReference]
}
enum DescriptionJobState: String, Codable, Sendable { case pending, running, responseReady, committed, failed, cancelled, discarded }
struct ArchiveDescriptionJob: Codable, Sendable, Identifiable {
    var id = UUID()
    var createdAt = Date()
    var batchID: UUID? = nil
    var dependencyJobIDs: [UUID] = []
    var snapshot: DescriptionSnapshot
    var configuration: LMStudioConfiguration
    var machineRole: ArchiveMachineRole
    var state: DescriptionJobState = .pending
    var response: MachineDescriptionRevision? = nil
    var inputPath: String? = nil
    var inputFileDigest: String? = nil
    var error: String? = nil
    var indexWarning: String? = nil
}
struct DescriptionBatchPlan: Codable, Sendable {
    var id = UUID()
    var jobs: [ArchiveDescriptionJob]
}
struct DescriptionPreparedInput: Sendable {
    var prompt: LMStudioPrompt
    var digest: String
    var type: String
    var path: String?
    var fileDigest: String?
    var children: [DescriptionChildEvidence]
    var covered: Int
    var coveredTargetIDs: [UUID]
}

struct ArchiveDescriptionRepository: Sendable {
    let archiveRoot: URL
    let machineRole: ArchiveMachineRole
    var oneDrivePicturesRoot: URL? = nil
    var beforeCommitWrite: @Sendable () throws -> Void = {}
    var writeCanonical: @Sendable (String, URL) throws -> Void = { text, url in
        try text.write(to: url, atomically: true, encoding: .utf8)
        let handle = try FileHandle(forWritingTo: url); defer { try? handle.close() }; try handle.synchronize()
    }
    private func url(_ path: String) throws -> URL {
        guard !path.hasPrefix("_index/"), !path.hasPrefix(".walkfolio-recovery/") else { throw ArchiveFileVerification.failure("Choose canonical archived material.") }
        let value = try ArchiveIndexMediaLoader().indexedURL(path, archiveRoot: archiveRoot)
        guard value.resolvingSymlinksInPath().standardizedFileURL == archiveRoot.resolvingSymlinksInPath().appendingPathComponent(path).standardizedFileURL else {
            throw ArchiveFileVerification.failure("Description targets cannot use linked archive ancestors.")
        }
        return value
    }
    private func ownsPath(_ recorded: String?, absolute: String?, path: String, value: URL) -> Bool {
        if let recorded {
            let expected = ArchiveRelativePathResolver(root: oneDrivePicturesRoot ?? archiveRoot).relativePath(for: value)
            return recorded == path || recorded == expected
        }
        return absolute.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL == value.resolvingSymlinksInPath().standardizedFileURL } ?? false
    }
    private func isRealPinnedThumbnail(_ value: URL) -> Bool {
        let root = archiveRoot.standardizedFileURL.path
        let lexical = value.standardizedFileURL.path
        guard lexical.hasPrefix(root + "/_index/thumbs/") else { return false }
        let relative = String(lexical.dropFirst(root.count + 1))
        return value.resolvingSymlinksInPath().standardizedFileURL == archiveRoot.resolvingSymlinksInPath().appendingPathComponent(relative).standardizedFileURL
    }
    func manifestURL(_ target: DescriptionReference) throws -> URL {
        let value = try url(target.path)
        return target.kind == .photo ? value.deletingPathExtension().appendingPathExtension("md") : value.appendingPathComponent(value.lastPathComponent + ".md")
    }
    func text(_ target: DescriptionReference) throws -> String {
        let path = try manifestURL(target)
        let values = try path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ArchiveFileVerification.failure("Descriptions require a regular canonical manifest.") }
        return try String(contentsOf: path, encoding: .utf8)
    }
    func snapshot(kind: DescriptionTargetKind, path: String) throws -> DescriptionSnapshot {
        let provisional = DescriptionReference(kind: kind, path: path, identity: UUID())
        let value = try url(path), text = try text(provisional)
        let history = try MachineDescriptionHistory.read(in: text)
        let identity: UUID
        var parent: UUID?, children: [DescriptionReference] = []
        switch kind {
        case .photo:
            guard let id = ArchiveManifestText.scalar("media_item_id", in: text).flatMap(UUID.init(uuidString:)),
                  ownsPath(ArchiveManifestText.scalar("archive_relative_path", in: text), absolute: ArchiveManifestText.scalar("archive_path", in: text), path: path, value: value) else {
                throw ArchiveFileVerification.failure("Only verified canonical archived photos can be described. Organise historical material first.")
            }
            if let digest = ArchiveManifestText.scalar("sha256", in: text), digest.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) == nil { throw ArchiveFileVerification.failure("The photo checksum record is invalid.") }
            let walkPath = value.deletingLastPathComponent()
            let parentPath = path.split(separator: "/").dropLast().joined(separator: "/")
            let walkText = try self.text(.init(kind: .walk, path: parentPath, identity: UUID()))
            guard let session = ArchiveLocationEditor.identity("Session ID", in: walkText),
                  ownsPath(TripManifestText.headerValue("OneDrive Pictures relative folder", in: walkText)?.trimmingCharacters(in: CharacterSet(charactersIn: "`")), absolute: TripManifestText.headerValue("Archive folder", in: walkText)?.trimmingCharacters(in: CharacterSet(charactersIn: "`")), path: path.split(separator: "/").dropLast().joined(separator: "/"), value: walkPath) else {
                throw ArchiveFileVerification.failure("This photo has no matching canonical Walk.")
            }
            identity = id; parent = ArchiveLocationEditor.identity("Walk ID", in: walkText) ?? session
        case .walk:
            guard let session = ArchiveLocationEditor.identity("Session ID", in: text),
                  ownsPath(TripManifestText.headerValue("OneDrive Pictures relative folder", in: text)?.trimmingCharacters(in: CharacterSet(charactersIn: "`")), absolute: TripManifestText.headerValue("Archive folder", in: text)?.trimmingCharacters(in: CharacterSet(charactersIn: "`")), path: path, value: value) else {
                throw ArchiveFileVerification.failure("Choose a canonical archived Walk.")
            }
            identity = ArchiveLocationEditor.identity("Walk ID", in: text) ?? session
            children = try ArchiveIndexStore().loadFileManifests(folder: value, archiveRoot: archiveRoot).map { file in
                let child = try snapshot(kind: .photo, path: file.archiveRelativePath ?? "")
                return child.target
            }.sorted { $0.path < $1.path }
        case .trip:
            guard let id = TripManifestText.headerValue("Trip ID", in: text).flatMap({ UUID(uuidString: $0.trimmingCharacters(in: CharacterSet(charactersIn: "`"))) }) else {
                throw ArchiveFileVerification.failure("Choose a canonical Trip before describing it.")
            }
            identity = id
            let store = TripManifestStore(), manifest = store.loadTripManifest(folder: value, oneDrivePicturesRoot: oneDrivePicturesRoot ?? archiveRoot)
            let actual = Set(try store.canonicalWalkMembers(in: value, oneDrivePicturesRoot: oneDrivePicturesRoot ?? archiveRoot).map(\.relativePath))
            guard actual == Set(manifest.memberWalkFolderPaths), actual.count == manifest.memberWalkFolderPaths.count else {
                throw ArchiveFileVerification.failure("The Trip's canonical member list is incomplete or conflicting. Refresh it before describing.")
            }
            children = try manifest.memberWalkFolderPaths.map { member in
                let memberURL = (oneDrivePicturesRoot ?? archiveRoot).appendingPathComponent(member)
                guard let local = ArchiveIndexStore.archiveRelativePath(for: memberURL, archiveRoot: archiveRoot) else { throw ArchiveFileVerification.failure("A Trip member escapes the Archive.") }
                return try snapshot(kind: .walk, path: local).target
            }
        }
        return DescriptionSnapshot(target: .init(kind: kind, path: path, identity: identity), baseline: try MachineDescriptionHistory.baseline(in: text),
            activeID: history?.activeID, parentIdentity: parent, children: children)
    }
    func validate(_ expected: DescriptionSnapshot, acceptingOwnRevision id: UUID? = nil) throws {
        let current = try snapshot(kind: expected.target.kind, path: expected.target.path)
        guard current.target == expected.target, current.parentIdentity == expected.parentIdentity else { throw ArchiveFileVerification.failure("The description target identity changed. Its result has been retained in the queue.") }
        if let id, try MachineDescriptionHistory.read(in: text(expected.target))?.revisions.contains(where: { $0.id == id }) == true { return }
        guard current == expected else { throw ArchiveFileVerification.failure("This material changed while describing it. The previous description has been retained; queue a fresh request after resolving the old one.") }
    }
    func isCurrent(_ revision: MachineDescriptionRevision, snapshot: DescriptionSnapshot) throws -> Bool {
        guard revision.sourceBaseline == snapshot.baseline, revision.target == snapshot.target,
              revision.childEvidence.map(\.target) == snapshot.children else { return false }
        for child in revision.childEvidence {
            let current = try self.snapshot(kind: child.target.kind, path: child.target.path)
            guard current.target == child.target, current.baseline == child.baseline,
                  let active = try MachineDescriptionHistory.read(in: text(child.target))?.active,
                  active.id == child.revisionID, try isCurrent(active, snapshot: current) else { return false }
        }
        return true
    }
    func prepare(_ snapshot: DescriptionSnapshot) throws -> DescriptionPreparedInput {
        try validate(snapshot)
        let target = snapshot.target
        let folder = target.kind == .photo ? try url(target.path).deletingLastPathComponent() : try url(target.path)
        try ArchiveLocationEditor.assertNoPending(overlapping: folder, archiveRoot: archiveRoot)
        try ArchiveLocationEditor.assertNoUnfinishedFolderOperation(overlapping: folder, archiveRoot: archiveRoot)
        if target.kind == .photo {
            let photo = try url(target.path), thumb = ArchiveIndexStore.thumbnailURL(for: photo, archiveRoot: archiveRoot)
            let policy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: machineRole)
            let input: URL, type: String
            if FileManager.default.fileExists(atPath: thumb.path), isRealPinnedThumbnail(thumb), !policy.escapesArchive(thumb), !policy.isOnlineOnly(thumb) {
                input = thumb; type = "prepared-thumbnail"
            } else {
                guard machineRole == .mainArchive, policy.canReadBytes(at: photo), !policy.isOnlineOnly(photo) else {
                    throw ArchiveFileVerification.failure("A prepared thumbnail is unavailable. Prepare this folder's thumbnails on the main Mac, then retry. No original was downloaded.")
                }
                input = photo; type = ArchiveManifestText.scalar("sha256", in: try text(target)) == nil ? "resident-original-preview-unverified-copy" : "resident-original-preview"
            }
            let values = try input.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ArchiveFileVerification.failure("The description input must be a regular local file.") }
            let fileDigest = try ArchiveFileVerification.sha256(at: input)
            if input == photo, let recorded = ArchiveManifestText.scalar("sha256", in: try text(target)), fileDigest != recorded { throw ArchiveFileVerification.failure("The archived original no longer matches its verified bytes.") }
            guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1024] as CFDictionary) else {
                throw ArchiveFileVerification.failure("The selected model input could not be decoded. Prepare a thumbnail and retry.")
            }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { throw ArchiveFileVerification.failure("The description preview could not be prepared.") }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ArchiveFileVerification.failure("The description preview could not be encoded.") }
            let jpeg = data as Data
            return DescriptionPreparedInput(prompt: LMStudioPrompt(text: "Describe this archived photograph for search. State visible setting, objects, activity and composition concisely; do not guess people's identities, dates or place names.", imageJPEG: jpeg), digest: MachineDescriptionHistory.digest(jpeg), type: type,
                path: ArchiveIndexStore.archiveRelativePath(for: input, archiveRoot: archiveRoot), fileDigest: fileDigest, children: [], covered: 0, coveredTargetIDs: [])
        }
        guard !snapshot.children.isEmpty else { throw ArchiveFileVerification.failure("This canonical group has no archived members to summarise.") }
        var evidence: [DescriptionChildEvidence] = [], included: [String] = [], coveredIDs: [UUID] = []
        var characters = 0
        for child in snapshot.children {
            let childSnapshot = try self.snapshot(kind: child.kind, path: child.path)
            guard childSnapshot.target == child, let revision = try MachineDescriptionHistory.read(in: text(child))?.active,
                  try isCurrent(revision, snapshot: childSnapshot) else {
                throw ArchiveFileVerification.failure("A member description is missing. Retry the queued photo and Walk jobs first.")
            }
            evidence.append(.init(target: child, baseline: childSnapshot.baseline, revisionID: revision.id))
            let line = "\(included.count + 1). " + revision.text
            if included.count < 100, characters + line.count <= 18_000 { included.append(line); coveredIDs.append(child.identity); characters += line.count }
        }
        guard !included.isEmpty else { throw ArchiveFileVerification.failure("The member descriptions exceed the summary input limit.") }
        let prompt = "Write a concise \(target.kind.rawValue) overview from these recorded descriptions only. Coverage: \(included.count) of \(snapshot.children.count) members are supplied; explicitly state omitted coverage when incomplete. Do not invent missing scenes, identities or places.\n" + included.joined(separator: "\n")
        return DescriptionPreparedInput(prompt: LMStudioPrompt(text: prompt), digest: MachineDescriptionHistory.digest(Data(prompt.utf8)), type: "child-descriptions", path: nil, fileDigest: nil, children: evidence, covered: included.count, coveredTargetIDs: coveredIDs)
    }
    func commit(_ job: ArchiveDescriptionJob) throws {
        guard let revision = job.response else { throw ArchiveFileVerification.failure("The completed response is unavailable.") }
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        try validate(job.snapshot, acceptingOwnRevision: job.id)
        let original = try text(job.snapshot.target)
        if try MachineDescriptionHistory.read(in: original)?.revisions.contains(where: { $0.id == job.id }) == true { return }
        let folder = job.snapshot.target.kind == .photo ? try url(job.snapshot.target.path).deletingLastPathComponent() : try url(job.snapshot.target.path)
        try ArchiveLocationEditor.assertNoPending(overlapping: folder, archiveRoot: archiveRoot)
        try ArchiveLocationEditor.assertNoUnfinishedFolderOperation(overlapping: folder, archiveRoot: archiveRoot)
        if let path = job.inputPath, let digest = job.inputFileDigest {
            let input: URL
            if path.hasPrefix("_index/thumbs/"), let thumbnail = ArchiveIndexStore.validatedThumbnailURL(relativePath: path, archiveRoot: archiveRoot), isRealPinnedThumbnail(thumbnail) { input = thumbnail }
            else {
                guard machineRole == .mainArchive, path == job.snapshot.target.path else { throw ArchiveFileVerification.failure("Travel descriptions cannot reopen originals.") }
                input = try url(path)
            }
            let policy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: machineRole)
            guard !policy.escapesArchive(input), !policy.isOnlineOnly(input), try ArchiveFileVerification.sha256(at: input) == digest else {
                throw ArchiveFileVerification.failure("The description image changed or became unavailable; its result remains in the queue.")
            }
        }
        for child in revision.childEvidence {
            let snapshot = try self.snapshot(kind: child.target.kind, path: child.target.path)
            guard snapshot.target == child.target, snapshot.baseline == child.baseline,
                  let active = try MachineDescriptionHistory.read(in: text(child.target))?.active,
                  active.id == child.revisionID, try isCurrent(active, snapshot: snapshot) else {
                throw ArchiveFileVerification.failure("A member description changed while summarising; the old overview has been retained.")
            }
        }
        var history = try MachineDescriptionHistory.read(in: original) ?? .init(activeID: job.id, revisions: [])
        history.revisions.append(revision); history.activeID = job.id
        let destination = try manifestURL(job.snapshot.target)
        try beforeCommitWrite()
        guard try text(job.snapshot.target) == original else { throw ArchiveFileVerification.failure("The manifest changed before saving the description. Its latest text has been retained.") }
        try writeCanonical(history.setting(in: original), destination)
    }
}

protocol ArchiveDescriptionQueuing: Sendable {
    func jobs() async throws -> [ArchiveDescriptionJob]
    func enqueue(targets: [(DescriptionTargetKind, String)], configuration: LMStudioConfiguration, regenerate: Bool) async throws -> [ArchiveDescriptionJob]
    func run(jobIDs: Set<UUID>?, progress: (@Sendable ([ArchiveDescriptionJob]) async -> Void)?) async throws
    func cancel() async
    func discardFailed() async throws
}

actor ArchiveDescriptionQueue: ArchiveDescriptionQueuing {
    let archiveRoot: URL
    let machineRole: ArchiveMachineRole
    let client: any DescriptionGenerating
    var repository: ArchiveDescriptionRepository
    let contextIsCurrent: @Sendable () -> Bool
    let persist: @Sendable (ArchiveDescriptionJob, URL) throws -> Void
    private var running = false
    private var cancelled = false
    private var activeRequest: Task<LMStudioCompletion, Error>?

    init(archiveRoot: URL, machineRole: ArchiveMachineRole, client: any DescriptionGenerating = LMStudioDescriptionClient(),
         oneDrivePicturesRoot: URL? = nil, repository: ArchiveDescriptionRepository? = nil, contextIsCurrent: @escaping @Sendable () -> Bool = { true },
         persist: @escaping @Sendable (ArchiveDescriptionJob, URL) throws -> Void = { job, root in try ArchiveOperationRecovery(archiveRoot: root).save(job, kind: "description", sessionID: job.id) }) {
        self.archiveRoot = archiveRoot; self.machineRole = machineRole; self.client = client
        self.repository = repository ?? ArchiveDescriptionRepository(archiveRoot: archiveRoot, machineRole: machineRole, oneDrivePicturesRoot: oneDrivePicturesRoot)
        self.contextIsCurrent = contextIsCurrent; self.persist = persist
    }
    func jobs() throws -> [ArchiveDescriptionJob] {
        let recorded = try recordedJobs()
        // Discard targets the complete failed batch. Its first durable discarded
        // receipt records that intent even if cancellation interrupts later writes.
        // Completed revisions remain active; unfinished parents must not resume.
        let discardedBatches = Set(recorded.filter { $0.state == .discarded }.compactMap(\.batchID))
        return recorded.map { job in
            var value = job
            if value.state != .committed, value.batchID.map(discardedBatches.contains) == true { value.state = .discarded }
            return value
        }
    }
    private func recordedJobs() throws -> [ArchiveDescriptionJob] {
        let recovery = ArchiveOperationRecovery(archiveRoot: archiveRoot)
        guard FileManager.default.fileExists(atPath: recovery.root.path) else { return [] }
        guard recovery.root.resolvingSymlinksInPath().standardizedFileURL == archiveRoot.resolvingSymlinksInPath().appendingPathComponent(".walkfolio-recovery").standardizedFileURL else { throw ArchiveFileVerification.failure("The description queue cannot use linked recovery storage.") }
        let urls = try FileManager.default.contentsOfDirectory(at: recovery.root, includingPropertiesForKeys: [.isSymbolicLinkKey])
        var byID: [UUID: ArchiveDescriptionJob] = [:]
        for url in urls where url.pathExtension == "json" && url.lastPathComponent.hasPrefix("description-plan-") {
            guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ArchiveFileVerification.failure("The description queue contains a linked plan.") }
            let plan = try JSONDecoder().decode(DescriptionBatchPlan.self, from: Data(contentsOf: url))
            for job in plan.jobs { byID[job.id] = job }
        }
        for url in urls where url.pathExtension == "json" && UUID(uuidString: String(url.deletingPathExtension().lastPathComponent.dropFirst("description-".count))) != nil && url.lastPathComponent.hasPrefix("description-") {
            guard try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ArchiveFileVerification.failure("The description queue contains a linked record.") }
            let job = try JSONDecoder().decode(ArchiveDescriptionJob.self, from: Data(contentsOf: url)); byID[job.id] = job
        }
        return byID.values.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }
    @discardableResult
    func enqueue(targets: [(DescriptionTargetKind, String)], configuration: LMStudioConfiguration, regenerate: Bool = false) throws -> [ArchiveDescriptionJob] {
        guard !running, contextIsCurrent(), configuration.model.nonEmpty != nil else { throw ArchiveFileVerification.failure("Select a model and finish or cancel the current description batch first.") }
        _ = try configuration.endpoint("chat/completions")
        let lock = try ArchiveMutationLock(archiveRoot: archiveRoot); defer { withExtendedLifetime(lock) {} }
        let existing = try jobs()
        var ordered: [DescriptionSnapshot] = [], seen = Set<DescriptionReference>()
        func visit(_ kind: DescriptionTargetKind, _ path: String) throws {
            let snapshot = try repository.snapshot(kind: kind, path: path)
            guard seen.insert(snapshot.target).inserted else { return }
            for child in snapshot.children { try visit(child.kind, child.path) }
            let active = try MachineDescriptionHistory.read(in: repository.text(snapshot.target))?.active
            let childQueued = snapshot.children.contains { child in ordered.contains { $0.target == child } }
            let evidenceChanged = try active.map { revision in
                if revision.childEvidence.map(\.target) != snapshot.children { return snapshot.target.kind != .photo }
                return try revision.childEvidence.contains { child in
                    try MachineDescriptionHistory.read(in: repository.text(child.target))?.activeID != child.revisionID
                }
            } ?? false
            if regenerate || active == nil || active?.sourceBaseline != snapshot.baseline || childQueued || evidenceChanged { ordered.append(snapshot) }
        }
        for target in targets { try visit(target.0, target.1) }
        guard !ordered.contains(where: { snapshot in existing.contains { $0.state != .committed && $0.state != .discarded && $0.snapshot.target == snapshot.target } }) else {
            throw ArchiveFileVerification.failure("This material already has an unfinished request. Resume or discard it before queueing another.")
        }
        var created: [ArchiveDescriptionJob] = []
        let batchDate = Date(), batchID = UUID()
        for snapshot in ordered {
            var job = ArchiveDescriptionJob(snapshot: snapshot, configuration: configuration, machineRole: machineRole)
            // Preserve dependency order independent of filesystem listing and UUID order.
            job.batchID = batchID
            job.dependencyJobIDs = created.filter { snapshot.children.contains($0.snapshot.target) }.map(\.id)
            job.createdAt = batchDate.addingTimeInterval(Double(created.count) * 0.001)
            created.append(job)
        }
        guard !created.isEmpty else { return [] }
        guard contextIsCurrent(), !Task.isCancelled else { throw CancellationError() }
        let plan = DescriptionBatchPlan(id: batchID, jobs: created)
        try ArchiveOperationRecovery(archiveRoot: archiveRoot).save(plan, kind: "description-plan", sessionID: plan.id)
        for job in created {
            guard contextIsCurrent(), !Task.isCancelled else { throw CancellationError() }
            try persist(job, archiveRoot)
        }
        return created
    }
    func cancel() { cancelled = true; activeRequest?.cancel() }
    func discardFailed() throws {
        guard contextIsCurrent(), !Task.isCancelled else { throw CancellationError() }
        guard !running else { throw ArchiveFileVerification.failure("Cancel the running descriptions first.") }
        let all = try recordedJobs()
        let failedBatches = Set(all.filter { [.failed, .cancelled, .discarded].contains($0.state) }.compactMap(\.batchID))
        for var job in all where job.state != .committed && job.state != .discarded &&
            ([.failed, .cancelled].contains(job.state) || job.batchID.map(failedBatches.contains) == true) {
            guard contextIsCurrent(), !Task.isCancelled else { throw CancellationError() }
            job.state = .discarded; try persist(job, archiveRoot)
        }
    }
    func run(jobIDs: Set<UUID>? = nil, progress: (@Sendable ([ArchiveDescriptionJob]) async -> Void)? = nil) async throws {
        guard !running, contextIsCurrent() else { throw ArchiveFileVerification.failure("The archive context changed. Resume descriptions from the current archive.") }
        running = true; cancelled = false; defer { running = false }
        for var job in try jobs() where job.state != .committed && job.state != .discarded && (jobIDs == nil || jobIDs!.contains(job.id)) {
            do {
                guard !cancelled, contextIsCurrent(), job.machineRole == machineRole else { throw CancellationError() }
                try Task.checkCancellation()
                let states = Dictionary(uniqueKeysWithValues: try jobs().map { ($0.id, $0.state) })
                guard job.dependencyJobIDs.allSatisfy({ states[$0] == .committed }) else { throw ArchiveFileVerification.failure("A required member description did not finish. Retry that batch before refreshing the overview; the previous result has been retained.") }
                if job.response == nil {
                    job.state = .running; job.error = nil; try persist(job, archiveRoot)
                    if let progress { await progress(try jobs()) }
                    let input = try repository.prepare(job.snapshot)
                    let request = Task { [client] in try await client.complete(configuration: job.configuration, prompt: input.prompt) }
                    activeRequest = request
                    let completion: LMStudioCompletion
                    do { completion = try await request.value; activeRequest = nil }
                    catch { activeRequest = nil; throw error }
                    guard !cancelled, contextIsCurrent() else { throw CancellationError() }; try Task.checkCancellation()
                    guard completion.text.nonEmpty != nil, completion.text.count <= 20_000, completion.model.nonEmpty != nil else { throw ArchiveFileVerification.failure("The provider returned an invalid description; the previous result has been retained.") }
                    job.response = .init(id: job.id, text: completion.text, model: completion.model, requestedModel: job.configuration.model,
                        generatedAt: Date(), endpoint: job.configuration.baseURL, promptVersion: "walkfolio-description-v1", target: job.snapshot.target,
                        inputDigest: input.digest, inputType: input.type, childEvidence: input.children,
                        totalChildren: job.snapshot.children.count, coveredChildren: input.covered, sourceBaseline: job.snapshot.baseline, coveredTargetIDs: input.coveredTargetIDs)
                    job.inputPath = input.path; job.inputFileDigest = input.fileDigest; job.state = .responseReady
                    try persist(job, archiveRoot)
                }
                guard !cancelled, contextIsCurrent() else { throw CancellationError() }; try Task.checkCancellation()
                try repository.commit(job)
                job.state = .committed; job.error = nil
                if machineRole == .mainArchive {
                    do {
                        let target = job.snapshot.target, targetURL = try ArchiveIndexMediaLoader().indexedURL(target.path, archiveRoot: archiveRoot)
                        let walks = target.kind == .trip ? [] : [target.kind == .photo ? targetURL.deletingLastPathComponent() : targetURL]
                        try await ArchiveIndexMutationQueue.shared.replaceWalkFolders(walks, archiveRoot: archiveRoot, policy: .init(machineRole: machineRole), tripFolders: target.kind == .trip ? [targetURL] : [])
                    } catch { job.indexWarning = "Description saved; index refresh failed: " + error.localizedDescription }
                }
                try persist(job, archiveRoot)
            } catch {
                job.state = error is CancellationError ? .cancelled : .failed; job.error = error.localizedDescription
                try persist(job, archiveRoot)
            }
            if let progress { await progress(try jobs()) }
            if cancelled || !contextIsCurrent() || Task.isCancelled { break }
        }
    }
}
