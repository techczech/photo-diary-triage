import Foundation
import os

struct ImportResult {
    var session: ImportSession
    var walkManifest: WalkManifest
    var walkManifests: [WalkManifest]
    var tripManifests: [TripManifest]
    var fileManifests: [FileManifest]
    var events: [SessionLogEvent]

    init(
        session: ImportSession,
        walkManifest: WalkManifest,
        walkManifests: [WalkManifest]? = nil,
        tripManifests: [TripManifest] = [],
        fileManifests: [FileManifest],
        events: [SessionLogEvent]
    ) {
        self.session = session
        self.walkManifest = walkManifest
        self.walkManifests = walkManifests ?? [walkManifest]
        self.tripManifests = tripManifests
        self.fileManifests = fileManifests
        self.events = events
    }
}

struct ImportCoordinator: ImportCoordinating {
    let fileManager: FileManager
    let archivePlanner: ArchivePlanner
    let manifestRenderer: ManifestRenderer
    private let logger = AppLogger.importCoordinator

    init(
        fileManager: FileManager = .default,
        archivePlanner: ArchivePlanner = ArchivePlanner(),
        manifestRenderer: ManifestRenderer = ManifestRenderer()
    ) {
        self.fileManager = fileManager
        self.archivePlanner = archivePlanner
        self.manifestRenderer = manifestRenderer
    }

    func commit(
        session: ImportSession,
        progress: (@Sendable (ImportProgress) async -> Void)? = nil
    ) async throws -> ImportResult {
        let mutationLock = try ArchiveMutationLock(archiveRoot: session.archiveRoot)
        defer { withExtendedLifetime(mutationLock) {} }
        let recovery = ArchiveOperationRecovery(archiveRoot: session.archiveRoot)
        let pendingIDs = Set(session.mediaItems.filter {
            $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond
        }.map(\.id))
        var record: ImportRecoveryRecord
        if let saved = try recovery.load(ImportRecoveryRecord.self, kind: "import", sessionID: session.id),
           !saved.complete || !saved.mediaItemIDs.isDisjoint(with: pendingIDs) {
            let original = saved.originalSession ?? saved.session
            let currentSelection = Set(session.mediaItems.filter {
                $0.selectionState.isIncluded && (!$0.lifecycleState.isImportedOrBeyond || saved.mediaItemIDs.contains($0.id))
            }.map(\.id))
            guard currentSelection == saved.mediaItemIDs,
                  session.walkMetadata == original.walkMetadata,
                  session.proposedWalks == original.proposedWalks,
                  session.sourceProvenances == original.sourceProvenances,
                  session.oneDrivePicturesRoot == original.oneDrivePicturesRoot,
                  session.weekdayTokenStyle == original.weekdayTokenStyle,
                  original.mediaItems.allSatisfy({ previous in
                      session.mediaItems.first { $0.id == previous.id }.map {
                          $0.selectionState == previous.selectionState && $0.importRawCompanions == previous.importRawCompanions
                              && $0.cropRelationship == previous.cropRelationship
                      } ?? false
                  }),
                  saved.session.archiveRoot == session.archiveRoot,
                  saved.plans.flatMap(\.entries).allSatisfy({ entry in
                      session.mediaItems.first { $0.id == entry.mediaItemID }.map { item in
                          entry.isCompanion
                              ? item.companionFiles.contains { $0.id == entry.companionFileID && $0.sourceURL == entry.sourceURL }
                              : item.sourceURL == entry.sourceURL
                      } ?? false
                  }) else {
                throw ArchiveFileVerification.failure("An unfinished import has different source files or selections. Resume the original photo log before starting another copy.")
            }
            record = saved
            for plan in record.plans { try ArchiveLayoutMigrator.assertNoPending(overlapping: plan.tripFolder, archiveRoot: session.archiveRoot) }
            try validateHistoricalPlans(record.plans, session: session)
        } else {
            let plans = archivePlanner.planWalks(for: session)
            for plan in plans { try ArchiveLayoutMigrator.assertNoPending(overlapping: plan.tripFolder, archiveRoot: session.archiveRoot) }
            try validateHistoricalPlans(plans, session: session)
            record = ImportRecoveryRecord(session: session, plans: plans, originalSession: session)
            try recovery.save(record, kind: "import", sessionID: session.id)
        }
        let plans = record.plans
        let relativePathResolver = ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot)

        var updatedSession = record.session
        var events: [SessionLogEvent] = [
            SessionLogEvent(timestamp: Date(), event: "session_commit_started", mediaItemID: nil, details: [
                "session_id": session.id.uuidString,
                "walk_count": "\(plans.count)"
            ])
        ]

        let totalEntries = max(plans.reduce(0) { $0 + $1.entries.count }, 1)
        var completedEntries = 0
        var walkManifestResults: [WalkManifest] = []
        var allFileManifests: [FileManifest] = []
        var namedTripMembers: [String: (plan: ArchiveCommitPlan, walks: [WalkManifest])] = [:]
        let tripManifestStore = TripManifestStore(fileManager: fileManager, renderer: manifestRenderer)

        for plan in plans {
            try AppDirectories.ensureExists(plan.archiveFolder, fileManager: fileManager)
            var walkEvents: [SessionLogEvent] = [
                SessionLogEvent(timestamp: Date(), event: "walk_commit_started", mediaItemID: nil, details: [
                    "session_id": session.id.uuidString,
                    "walk_id": plan.walkID?.uuidString ?? "",
                    "archive_folder": plan.archiveFolder.path
                ])
            ]

            for entry in plan.entries {
                try Task.checkCancellation()
                guard ArchiveRelativePathResolver(root: session.archiveRoot.resolvingSymlinksInPath())
                    .relativePath(for: ArchivePathSafety.resolvedForWrite(entry.destinationURL)) != nil else {
                    throw ArchiveFileVerification.failure("The import destination must remain inside the Archive.")
                }
                let checkpointKind = "import-file-\(entry.companionFileID ?? entry.mediaItemID)"
                let checkpoint = try recovery.load(ImportFileCheckpoint.self, kind: checkpointKind, sessionID: session.id)
                let digest = try ArchiveFileVerification.sha256(at: entry.sourceURL)
                if let expected = checkpoint?.sha256 ?? record.sha256ByDestination[entry.destinationURL.path], expected != digest {
                    throw ArchiveFileVerification.failure("The source changed during this import: \(entry.sourceURL.lastPathComponent). Its earlier copy has been retained.")
                }
                record.sha256ByDestination[entry.destinationURL.path] = digest
                if checkpoint == nil {
                    try recovery.save(ImportFileCheckpoint(sha256: digest), kind: checkpointKind, sessionID: session.id)
                }
                if !fileManager.fileExists(atPath: entry.destinationURL.path) {
                    let temporary = entry.destinationURL.deletingLastPathComponent().appendingPathComponent(
                        ".walkfolio-copy-\(record.operationID.uuidString)-\(entry.companionFileID ?? entry.mediaItemID).partial"
                    )
                    if fileManager.fileExists(atPath: temporary.path) {
                        try fileManager.removeItem(at: temporary)
                    }
                    try fileManager.copyItem(at: entry.sourceURL, to: temporary)
                    guard try ArchiveFileVerification.sha256(at: temporary) == digest else {
                        throw ArchiveFileVerification.failure("The copied contents could not be verified: \(entry.sourceURL.lastPathComponent). The source has been retained.")
                    }
                    let handle = try FileHandle(forWritingTo: temporary)
                    try handle.synchronize()
                    try handle.close()
                    try fileManager.moveItem(at: temporary, to: entry.destinationURL)
                } else if try ArchiveFileVerification.sha256(at: entry.destinationURL) != digest {
                    throw ArchiveFileVerification.failure("The existing copy does not match this import: \(entry.destinationURL.lastPathComponent). Both files have been retained.")
                }

                guard let index = updatedSession.mediaItems.firstIndex(where: { $0.id == entry.mediaItemID }) else {
                    continue
                }

                if entry.isCompanion {
                    if let companionIndex = updatedSession.mediaItems[index].companionFiles.firstIndex(where: { $0.id == entry.companionFileID }) {
                        updatedSession.mediaItems[index].companionFiles[companionIndex].destinationURL = entry.destinationURL
                        updatedSession.mediaItems[index].companionFiles[companionIndex].archiveRelativePath = relativePathResolver.relativePath(for: entry.destinationURL)
                        updatedSession.mediaItems[index].companionFiles[companionIndex].importedAt = checkpoint?.importedAt ?? Date()
                    }
                } else {
                    updatedSession.mediaItems[index].destinationURL = entry.destinationURL
                    updatedSession.mediaItems[index].archiveRelativePath = relativePathResolver.relativePath(for: entry.destinationURL)
                    if updatedSession.mediaItems[index].lifecycleState == .discovered {
                        updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .selectedForImport)
                    }
                    if !updatedSession.mediaItems[index].lifecycleState.isImportedOrBeyond {
                        updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .imported)
                    }
                    updatedSession.mediaItems[index].importedAt = updatedSession.mediaItems[index].importedAt ?? checkpoint?.importedAt ?? Date()
                }

                if checkpoint?.importedAt == nil {
                    try recovery.save(ImportFileCheckpoint(sha256: digest, importedAt: Date()), kind: checkpointKind, sessionID: session.id)
                }
                let event = SessionLogEvent(timestamp: Date(), event: "file_imported", mediaItemID: entry.mediaItemID, details: [
                    "source": entry.sourceURL.path,
                    "destination": entry.destinationURL.path,
                    "is_companion": entry.isCompanion ? "true" : "false",
                    "walk_id": plan.walkID?.uuidString ?? ""
                ])
                events.append(event)
                walkEvents.append(event)

                completedEntries += 1
                if let progress {
                    await progress(ImportProgress(current: completedEntries, total: totalEntries))
                }
            }

            updatedSession.lastUpdatedAt = Date()
            updatedSession.status = "imported"

            try verifyImportedFiles(in: &updatedSession, mediaItemIDs: Set(plan.entries.map(\.mediaItemID)), events: &events, walkEvents: &walkEvents, expectedDigests: record.sha256ByDestination)
            refreshArchiveRelativePaths(in: &updatedSession)

            let planMediaIDs = Set(plan.entries.filter { !$0.isCompanion }.map(\.mediaItemID))
            let fileManifests = buildFileManifests(for: updatedSession, mediaItemIDs: planMediaIDs, plan: plan, sha256ByDestination: record.sha256ByDestination)
            let newWalk = buildWalkManifest(for: updatedSession, plan: plan, fileManifests: fileManifests)
            let walkManifest = try writeManifests(walkManifest: newWalk, fileManifests: fileManifests,
                archiveFolder: plan.archiveFolder, archiveRoot: session.archiveRoot, events: walkEvents)
            walkManifestResults.append(walkManifest)
            allFileManifests.append(contentsOf: fileManifests)
            let key = plan.tripFolder.path
            var entry = namedTripMembers[key] ?? (plan, [])
            entry.walks.append(walkManifest)
            namedTripMembers[key] = entry
        }

        let manifestedIDs = Set(allFileManifests.map(\.mediaItemID))
        let existingCopiedIDs = Set(updatedSession.mediaItems
            .filter { $0.selectionState.isIncluded && $0.destinationURL != nil && !manifestedIDs.contains($0.id) }
            .map(\.id))
        if !existingCopiedIDs.isEmpty {
            allFileManifests.append(contentsOf: buildFileManifests(for: updatedSession, mediaItemIDs: existingCopiedIDs))
        }

        let tripManifests = try namedTripMembers.values.map { entry in
            try tripManifestStore.updateNamedTripManifest(
                folder: entry.plan.tripFolder,
                title: entry.plan.tripTarget.title,
                oneDrivePicturesRoot: updatedSession.oneDrivePicturesRoot,
                adding: entry.walks.compactMap { walk in
                    guard let relativePath = walk.archiveFolderRelativePath else { return nil }
                    return TripManifestMemberUpdate(relativePath: relativePath, date: walk.walkDate)
                }
            )
        }
        updatedSession.proposedWalks = []
        updatedSession.confirmedCopyPending = nil
        record.session = updatedSession
        record.complete = true
        try recovery.save(record, kind: "import", sessionID: session.id)
        guard let primaryWalkManifest = walkManifestResults.first else {
            let empty = buildWalkManifest(
                for: updatedSession,
                plan: archivePlanner.plan(for: updatedSession),
                fileManifests: []
            )
            return ImportResult(session: updatedSession, walkManifest: empty, walkManifests: [], tripManifests: tripManifests, fileManifests: [], events: events)
        }

        return ImportResult(
            session: updatedSession,
            walkManifest: primaryWalkManifest,
            walkManifests: walkManifestResults,
            tripManifests: tripManifests,
            fileManifests: allFileManifests,
            events: events
        )
    }

    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession {
        guard session.archiveMachineRole.allowsSourceCleanup,
              session.walkMetadata.backupConfirmedAt != nil else { return session }
        guard !session.mediaItems.contains(where: {
            $0.selectionState.isIncluded && $0.lifecycleState != .sourceCleanupPending && $0.lifecycleState != .sourceCleaned
        }) else { return session }

        let mutationLock = try ArchiveMutationLock(archiveRoot: session.archiveRoot)
        defer { withExtendedLifetime(mutationLock) {} }
        let recovery = ArchiveOperationRecovery(archiveRoot: session.archiveRoot)
        var record = try recovery.load(CleanupRecoveryRecord.self, kind: "cleanup", sessionID: session.id) ?? CleanupRecoveryRecord()
        let archiveResolver = ArchiveRelativePathResolver(root: session.archiveRoot.resolvingSymlinksInPath())
        var candidates: [(UUID, UUID?, URL, URL)] = []
        let importRecord = try recovery.load(ImportRecoveryRecord.self, kind: "import", sessionID: session.id)
        var validatedHistoricalRoots: Set<URL> = []
        for item in session.mediaItems where item.lifecycleState == .sourceCleanupPending {
            guard item.recognisedArchiveCopy != true else { throw ArchiveFileVerification.failure("A recognised previous archive copy does not authorise source cleanup.") }
            if item.cropRelationship?.role == .original && item.cropRelationship?.hasCrops == true { continue }
            guard let destination = item.destinationURL else {
                throw ArchiveFileVerification.failure("The archived copy is missing for \(item.fileName). No sources were removed.")
            }
            candidates.append((item.id, nil, item.sourceURL, destination))
            if item.importRawCompanions {
                for companion in item.companionFiles {
                    guard let destination = companion.destinationURL else {
                        throw ArchiveFileVerification.failure("The archived RAW copy is missing for \(companion.fileName). No sources were removed.")
                    }
                    candidates.append((item.id, companion.id, companion.sourceURL, destination))
                }
            }
        }

        // Verify the whole cleanup set before deleting any source, including RAW companions.
        for (itemID, companionID, source, destination) in candidates {
            try Task.checkCancellation()
            guard archiveResolver.relativePath(for: destination.resolvingSymlinksInPath()) != nil else {
                throw ArchiveFileVerification.failure("Cleanup requires a verified destination inside the Archive.")
            }
            if archiveResolver.relativePath(for: source.resolvingSymlinksInPath()) != nil {
                guard let context = HistoricalSourceSafety.context(for: source, in: session),
                      let importRecord, importRecord.complete,
                      let original = importRecord.originalSession,
                      HistoricalSourceSafety.context(for: source, in: original)?.root == context.root,
                      importRecord.plans.flatMap(\.entries).contains(where: { $0.mediaItemID == itemID && $0.companionFileID == companionID && $0.sourceURL == source && $0.destinationURL == destination }),
                      !destination.resolvingSymlinksInPath().path.hasPrefix(context.root.resolvingSymlinksInPath().path + "/") else {
                    throw ArchiveFileVerification.failure("Archive-source cleanup requires a completed recorded historical import into a separate destination.")
                }
                if validatedHistoricalRoots.insert(context.root).inserted { try HistoricalSourceSafety.validate(root: context.root, archiveRoot: session.archiveRoot, fileManager: fileManager) }
            }
            guard source.resolvingSymlinksInPath().standardizedFileURL != destination.resolvingSymlinksInPath().standardizedFileURL else {
                throw ArchiveFileVerification.failure("Source and destination are the same file.")
            }
            if fileManager.fileExists(atPath: source.path) {
                let a = try fileManager.attributesOfItem(atPath: source.path), b = try fileManager.attributesOfItem(atPath: destination.path)
                guard a[.systemNumber] as? NSNumber != b[.systemNumber] as? NSNumber || a[.systemFileNumber] as? NSNumber != b[.systemFileNumber] as? NSNumber else {
                    throw ArchiveFileVerification.failure("Source and destination are aliases of the same file.")
                }
            }
            if let previous = record.entries.first(where: { $0.source == source }) {
                guard previous.destination == destination, previous.mediaItemID == itemID,
                      previous.companionFileID == companionID,
                      try ArchiveFileVerification.sha256(at: destination) == previous.sha256 else {
                    throw ArchiveFileVerification.failure("The archived copy changed during cleanup: \(source.lastPathComponent). Remaining sources have been retained.")
                }
                if fileManager.fileExists(atPath: source.path) {
                    try ArchiveFileVerification.verify(source: source, destination: destination, expectedSHA256: previous.sha256)
                } else if !previous.deletionStarted {
                    throw ArchiveFileVerification.failure("The source is unavailable: \(source.lastPathComponent). Cleanup has stopped.")
                }
            } else {
                let checkpointKind = "import-file-\(companionID ?? itemID)"
                let checkpoint = try recovery.load(ImportFileCheckpoint.self, kind: checkpointKind, sessionID: session.id)
                var expected = checkpoint?.sha256
                let manifest = destination.deletingPathExtension().appendingPathExtension("md")
                if companionID == nil, fileManager.fileExists(atPath: manifest.path) {
                    expected = ArchiveManifestText.scalar("sha256", in: try String(contentsOf: manifest, encoding: .utf8)) ?? expected
                }
                let digest = try ArchiveFileVerification.verify(source: source, destination: destination, expectedSHA256: expected)
                record.entries.append(CleanupRecoveryEntry(mediaItemID: itemID, companionFileID: companionID,
                                                          source: source, destination: destination, sha256: digest))
            }
        }
        try recovery.save(record, kind: "cleanup", sessionID: session.id)

        var updatedSession = session
        for (itemID, companionID, source, destination) in candidates {
            try Task.checkCancellation()
            let index = record.entries.firstIndex { $0.source == source }!
            if fileManager.fileExists(atPath: source.path) {
                try ArchiveFileVerification.verify(source: source, destination: destination, expectedSHA256: record.entries[index].sha256)
                record.entries[index].deletionStarted = true
                try recovery.save(record, kind: "cleanup", sessionID: session.id)
                try fileManager.removeItem(at: source)
            }
            record.entries[index].deletedAt = record.entries[index].deletedAt ?? Date()
            try recovery.save(record, kind: "cleanup", sessionID: session.id)
            if let itemIndex = updatedSession.mediaItems.firstIndex(where: { $0.id == itemID }) {
                if let companionID,
                   let companionIndex = updatedSession.mediaItems[itemIndex].companionFiles.firstIndex(where: { $0.id == companionID }) {
                    updatedSession.mediaItems[itemIndex].companionFiles[companionIndex].sourceCleanedAt = record.entries[index].deletedAt
                } else if companionID == nil {
                    updatedSession.mediaItems[itemIndex].sourceCleanedAt = record.entries[index].deletedAt
                }
            }
        }
        for index in updatedSession.mediaItems.indices where updatedSession.mediaItems[index].lifecycleState == .sourceCleanupPending {
            let item = updatedSession.mediaItems[index]
            if item.sourceCleanedAt != nil,
               !item.importRawCompanions || item.companionFiles.allSatisfy({ $0.sourceCleanedAt != nil }) {
                updatedSession.mediaItems[index].lifecycleState = try item.lifecycleState.transition(to: .sourceCleaned)
            }
        }
        updatedSession.lastUpdatedAt = Date()
        updatedSession.status = updatedSession.mediaItems.contains { $0.lifecycleState == .sourceCleanupPending } ? "source_cleanup_pending" : "source_cleaned"
        return updatedSession
    }

    private func verifyImportedFiles(
        in session: inout ImportSession,
        mediaItemIDs: Set<UUID>,
        events: inout [SessionLogEvent],
        walkEvents: inout [SessionLogEvent],
        expectedDigests: [String: String] = [:]
    ) throws {
        for index in session.mediaItems.indices where mediaItemIDs.contains(session.mediaItems[index].id) && session.mediaItems[index].selectionState.isIncluded && session.mediaItems[index].lifecycleState == .imported {
            guard let destinationURL = session.mediaItems[index].destinationURL else { continue }
            let sourceAttributes = try fileManager.attributesOfItem(atPath: session.mediaItems[index].sourceURL.path)
            let destinationAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)

            let sourceSize = sourceAttributes[.size] as? NSNumber
            let destinationSize = destinationAttributes[.size] as? NSNumber

            let verifiedDigest = try ArchiveFileVerification.verify(source: session.mediaItems[index].sourceURL, destination: destinationURL, expectedSHA256: expectedDigests[destinationURL.path])
            guard sourceSize == destinationSize else {
                let sourcePath = session.mediaItems[index].sourceURL.path
                logger.error("Verification failed for \(sourcePath, privacy: .public): size mismatch")
                throw NSError(domain: "ImportCoordinator", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Imported file verification failed for \(session.mediaItems[index].fileName)"
                ])
            }

            session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: .verified)
            session.mediaItems[index].verifiedAt = Date()

            if session.walkMetadata.backupConfirmedAt != nil && session.archiveMachineRole.allowsSourceCleanup {
                session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: .sourceCleanupPending)
            }

            let event = SessionLogEvent(timestamp: Date(), event: "file_verified", mediaItemID: session.mediaItems[index].id, details: [
                    "destination": destinationURL.path,
                    "size_bytes": destinationSize?.stringValue ?? "0",
                    "sha256": verifiedDigest
                ])
            events.append(event)
            walkEvents.append(event)

            if session.mediaItems[index].importRawCompanions {
                try verifyCompanionFiles(for: &session.mediaItems[index], events: &events, walkEvents: &walkEvents, expectedDigests: expectedDigests)
            }
        }
    }

    private func verifyCompanionFiles(
        for item: inout MediaItem,
        events: inout [SessionLogEvent],
        walkEvents: inout [SessionLogEvent],
        expectedDigests: [String: String] = [:]
    ) throws {
        for companionIndex in item.companionFiles.indices {
            guard let destinationURL = item.companionFiles[companionIndex].destinationURL else { continue }
            let sourceAttributes = try fileManager.attributesOfItem(atPath: item.companionFiles[companionIndex].sourceURL.path)
            let destinationAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let sourceSize = sourceAttributes[.size] as? NSNumber
            let destinationSize = destinationAttributes[.size] as? NSNumber

            guard sourceSize == destinationSize else {
                let sourcePath = item.companionFiles[companionIndex].sourceURL.path
                logger.error("Companion verification failed for \(sourcePath, privacy: .public): size mismatch")
                throw NSError(domain: "ImportCoordinator", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Imported RAW sidecar verification failed for \(item.companionFiles[companionIndex].fileName)"
                ])
            }

            try ArchiveFileVerification.verify(source: item.companionFiles[companionIndex].sourceURL, destination: destinationURL, expectedSHA256: expectedDigests[destinationURL.path])
            item.companionFiles[companionIndex].verifiedAt = Date()
            let event = SessionLogEvent(timestamp: Date(), event: "companion_verified", mediaItemID: item.id, details: [
                "source": item.companionFiles[companionIndex].sourceURL.path,
                "destination": destinationURL.path
            ])
            events.append(event)
            walkEvents.append(event)
        }
    }

    private func validateHistoricalPlans(_ plans: [ArchiveCommitPlan], session: ImportSession) throws {
        for context in session.sourceProvenances.compactMap(\.historical) {
            try HistoricalSourceSafety.validate(root: context.root, archiveRoot: session.archiveRoot, fileManager: fileManager)
            let sourceRoot = context.root.resolvingSymlinksInPath().standardizedFileURL
            guard !plans.contains(where: {
                let destination = ArchivePathSafety.resolvedForWrite($0.archiveFolder)
                return destination.path.hasPrefix(sourceRoot.path + "/") || destination == sourceRoot
            }) else {
                throw ArchiveFileVerification.failure("Choose an archive destination outside the historical source folder.")
            }
        }
    }

    private func buildFileManifests(for session: ImportSession, mediaItemIDs: Set<UUID>, plan: ArchiveCommitPlan? = nil, sha256ByDestination: [String: String] = [:]) -> [FileManifest] {
        session.mediaItems
            .filter { mediaItemIDs.contains($0.id) && $0.selectionState.isIncluded }
            .compactMap { item in
                guard let destinationURL = item.destinationURL else { return nil }
                return FileManifest(
                    mediaItemID: item.id,
                    archivePath: destinationURL.path,
                    sha256: sha256ByDestination[destinationURL.path],
                    archiveRelativePath: item.archiveRelativePath,
                    sourceFileName: item.fileName,
                    companionArchivePaths: item.companionFiles.compactMap(\.destinationURL?.path),
                    companionArchiveRelativePaths: item.companionFiles.compactMap(\.archiveRelativePath),
                    capturedAt: item.capturedAt,
                    cameraModel: item.metadata.cameraModel,
                    lensModel: item.metadata.lensModel,
                    pixelWidth: item.metadata.pixelWidth,
                    pixelHeight: item.metadata.pixelHeight,
                    latitude: item.metadata.latitude,
                    longitude: item.metadata.longitude,
                    walkTitle: plan?.walkTitle ?? session.walkMetadata.title,
                    walkLocation: plan?.walkLocation ?? session.walkMetadata.location,
                    notes: session.walkMetadata.notes,
                    captureDateEvidence: item.captureDateEvidence
                )
            }
    }

    private func buildWalkManifest(for session: ImportSession, plan: ArchiveCommitPlan, fileManifests: [FileManifest]) -> WalkManifest {
        let planMediaIDs = Set(plan.entries.filter { !$0.isCompanion }.map(\.mediaItemID))
        let manifestItems = session.mediaItems.filter { planMediaIDs.contains($0.id) }
        let cleanupPending = manifestItems.filter { $0.lifecycleState == .sourceCleanupPending }.count
        let cleaned = manifestItems.filter { $0.lifecycleState == .sourceCleaned }.count
        let excludedFiles = manifestItems
            .filter { $0.selectionState.isExcluded }
            .map {
                RejectedFileManifest(
                    mediaItemID: $0.id,
                    sourceFileName: $0.fileName,
                    relativePath: $0.relativePath,
                    reason: "excluded"
                )
            }
        let candidateCount = manifestItems.filter { $0.selectionState.isCandidate }.count
        let undecidedCount = manifestItems.filter { $0.selectionState.isUndecided }.count
        let relativeResolver = ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot)

        return WalkManifest(
            sessionID: session.id,
            walkID: plan.walkID,
            tripFolderRelativePath: relativeResolver.relativePath(for: plan.tripFolder),
            walkDate: manifestItems.compactMap(\.capturedAt).min(),
            sourceFolder: session.sourceFolder,
            archiveFolder: plan.archiveFolder,
            archiveFolderRelativePath: relativeResolver.relativePath(for: plan.archiveFolder),
            title: plan.walkTitle?.nonEmpty ?? session.walkMetadata.title.nonEmpty ?? "Photo Walk",
            location: plan.walkLocation ?? session.walkMetadata.location,
            latitude: (ArchiveCoordinate(latitude: plan.walkLatitude, longitude: plan.walkLongitude) ?? ArchiveCoordinate(latitude: session.walkMetadata.latitude, longitude: session.walkMetadata.longitude))?.latitude,
            longitude: (ArchiveCoordinate(latitude: plan.walkLatitude, longitude: plan.walkLongitude) ?? ArchiveCoordinate(latitude: session.walkMetadata.latitude, longitude: session.walkMetadata.longitude))?.longitude,
            notes: session.walkMetadata.notes,
            summary: .init(
                totalSourceFiles: manifestItems.reduce(0) { $0 + 1 + $1.companionFiles.count },
                visibleItems: manifestItems.count,
                importedFiles: fileManifests.count + fileManifests.reduce(0) { $0 + $1.companionArchivePaths.count },
                excludedFiles: excludedFiles.count,
                candidateFiles: candidateCount,
                undecidedFiles: undecidedCount,
                skippedFiles: manifestItems.count - fileManifests.count,
                cleanupPendingFiles: cleanupPending,
                cleanedSourceFiles: cleaned
            ),
            importedFiles: fileManifests,
            excludedFiles: excludedFiles
        )
    }

    private func refreshArchiveRelativePaths(in session: inout ImportSession) {
        let resolver = ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot)
        for index in session.mediaItems.indices {
            if let destinationURL = session.mediaItems[index].destinationURL {
                session.mediaItems[index].archiveRelativePath = resolver.relativePath(for: destinationURL)
            }
            for companionIndex in session.mediaItems[index].companionFiles.indices {
                guard let destinationURL = session.mediaItems[index].companionFiles[companionIndex].destinationURL else { continue }
                session.mediaItems[index].companionFiles[companionIndex].archiveRelativePath = resolver.relativePath(for: destinationURL)
            }
        }
    }

    private func writeManifests(walkManifest: WalkManifest, fileManifests: [FileManifest], archiveFolder: URL,
                                archiveRoot: URL, events: [SessionLogEvent]) throws -> WalkManifest {
        let walkBasename = archiveFolder.lastPathComponent
        let walkManifestURL = archiveFolder.appendingPathComponent("\(walkBasename).md")
        var combined = walkManifest
        var existingText: String?
        if fileManager.fileExists(atPath: walkManifestURL.path) {
            existingText = try String(contentsOf: walkManifestURL, encoding: .utf8)
            guard let existing = try ArchiveIndexStore(fileManager: fileManager).loadWalkManifest(folder: archiveFolder, archiveRoot: archiveRoot) else {
                throw ArchiveFileVerification.failure("The existing Walk manifest could not be read.")
            }
            combined = existing
            let newIDs = Set(fileManifests.map(\.mediaItemID))
            combined.importedFiles = existing.importedFiles.filter { !newIDs.contains($0.mediaItemID) } + fileManifests
        }
        for fileManifest in fileManifests {
            let destinationURL = URL(fileURLWithPath: fileManifest.archivePath)
            let fileURL = destinationURL.deletingPathExtension().appendingPathExtension("md")
            if fileManager.fileExists(atPath: fileURL.path) {
                let current = try String(contentsOf: fileURL, encoding: .utf8)
                guard ArchiveManifestText.scalar("media_item_id", in: current) == fileManifest.mediaItemID.uuidString else {
                    throw ArchiveFileVerification.failure("Another photo already owns this manifest: \(fileURL.lastPathComponent)")
                }
                // Retry retains later human edits and unknown fields on existing manifests.
            } else {
                try manifestRenderer.renderFileManifest(fileManifest).write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
        var rendered = manifestRenderer.renderWalkManifest(combined)
        if let original = existingText {
            guard let report = ArchiveManifestText.sourceReport(in: original),
                  let oldStart = original.range(of: "## Imported Files\n", range: report.upperBound..<original.endIndex),
                  let oldEnd = original.range(of: "## Excluded Files", range: oldStart.upperBound..<original.endIndex),
                  let newStart = rendered.range(of: "## Imported Files\n"),
                  let newEnd = rendered.range(of: "## Excluded Files", range: newStart.upperBound..<rendered.endIndex) else {
                throw ArchiveFileVerification.failure("The existing Walk membership section could not be read.")
            }
            // Keep the original notes, title, source report, exclusions and custom fields.
            rendered = String(original[..<oldStart.lowerBound]) + rendered[newStart.lowerBound..<newEnd.lowerBound]
                + original[oldEnd.lowerBound...]
        }
        try rendered.write(to: walkManifestURL, atomically: true, encoding: .utf8)
        let logURL = archiveFolder.appendingPathComponent("\(walkBasename)-session-log.jsonl")
        let previousLog = fileManager.fileExists(atPath: logURL.path) ? try String(contentsOf: logURL, encoding: .utf8) : ""
        let newLog = manifestRenderer.renderLog(events)
        try (previousLog + (previousLog.isEmpty ? "" : "\n") + newLog).write(to: logURL, atomically: true, encoding: .utf8)
        return combined
    }

}
