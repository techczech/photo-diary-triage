import Foundation

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
        let plans = archivePlanner.planWalks(for: session)
        let relativePathResolver = ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot)

        var updatedSession = session
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
                guard !fileManager.fileExists(atPath: entry.destinationURL.path) else {
                    throw NSError(domain: "ImportCoordinator", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "Planned archive destination already exists: \(entry.destinationURL.path)"
                    ])
                }
                try fileManager.copyItem(at: entry.sourceURL, to: entry.destinationURL)

                guard let index = updatedSession.mediaItems.firstIndex(where: { $0.id == entry.mediaItemID }) else {
                    continue
                }

                if entry.isCompanion {
                    if let companionIndex = updatedSession.mediaItems[index].companionFiles.firstIndex(where: { $0.id == entry.companionFileID }) {
                        updatedSession.mediaItems[index].companionFiles[companionIndex].destinationURL = entry.destinationURL
                        updatedSession.mediaItems[index].companionFiles[companionIndex].archiveRelativePath = relativePathResolver.relativePath(for: entry.destinationURL)
                        updatedSession.mediaItems[index].companionFiles[companionIndex].importedAt = Date()
                    }
                } else {
                    updatedSession.mediaItems[index].destinationURL = entry.destinationURL
                    updatedSession.mediaItems[index].archiveRelativePath = relativePathResolver.relativePath(for: entry.destinationURL)
                    if updatedSession.mediaItems[index].lifecycleState == .discovered {
                        updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .selectedForImport)
                    }
                    updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .imported)
                    updatedSession.mediaItems[index].importedAt = Date()
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

            try verifyImportedFiles(in: &updatedSession, mediaItemIDs: Set(plan.entries.map(\.mediaItemID)), events: &events, walkEvents: &walkEvents)
            refreshArchiveRelativePaths(in: &updatedSession)

            let planMediaIDs = Set(plan.entries.filter { !$0.isCompanion }.map(\.mediaItemID))
            let fileManifests = buildFileManifests(for: updatedSession, mediaItemIDs: planMediaIDs)
            let walkManifest = buildWalkManifest(for: updatedSession, plan: plan, fileManifests: fileManifests)
            try writeManifests(walkManifest: walkManifest, fileManifests: fileManifests, archiveFolder: plan.archiveFolder, events: walkEvents)
            walkManifestResults.append(walkManifest)
            allFileManifests.append(contentsOf: fileManifests)
            if plan.tripTarget.kind != .defaultMonth {
                let key = plan.tripFolder.path
                var entry = namedTripMembers[key] ?? (plan, [])
                entry.walks.append(walkManifest)
                namedTripMembers[key] = entry
            }
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
        guard session.archiveMachineRole.allowsSourceCleanup else { return session }

        var updatedSession = session
        let cleanupAllowed = !session.mediaItems.contains {
            $0.selectionState.isIncluded && $0.lifecycleState != .sourceCleanupPending && $0.lifecycleState != .sourceCleaned
        }
        guard cleanupAllowed else { return session }

        for index in updatedSession.mediaItems.indices {
            guard updatedSession.mediaItems[index].lifecycleState == .sourceCleanupPending else { continue }
            if updatedSession.mediaItems[index].cropRelationship?.role == .original,
               updatedSession.mediaItems[index].cropRelationship?.hasCrops == true {
                continue
            }
            try fileManager.removeItem(at: updatedSession.mediaItems[index].sourceURL)
            if updatedSession.mediaItems[index].importRawCompanions {
                for companionIndex in updatedSession.mediaItems[index].companionFiles.indices where updatedSession.mediaItems[index].companionFiles[companionIndex].destinationURL != nil {
                    try fileManager.removeItem(at: updatedSession.mediaItems[index].companionFiles[companionIndex].sourceURL)
                    updatedSession.mediaItems[index].companionFiles[companionIndex].sourceCleanedAt = Date()
                }
            }
            updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .sourceCleaned)
            updatedSession.mediaItems[index].sourceCleanedAt = Date()
        }

        updatedSession.lastUpdatedAt = Date()
        updatedSession.status = updatedSession.mediaItems.contains { $0.lifecycleState == .sourceCleanupPending } ? "source_cleanup_pending" : "source_cleaned"
        return updatedSession
    }

    private func verifyImportedFiles(
        in session: inout ImportSession,
        mediaItemIDs: Set<UUID>,
        events: inout [SessionLogEvent],
        walkEvents: inout [SessionLogEvent]
    ) throws {
        for index in session.mediaItems.indices where mediaItemIDs.contains(session.mediaItems[index].id) && session.mediaItems[index].selectionState.isIncluded && session.mediaItems[index].lifecycleState == .imported {
            guard let destinationURL = session.mediaItems[index].destinationURL else { continue }
            let sourceAttributes = try fileManager.attributesOfItem(atPath: session.mediaItems[index].sourceURL.path)
            let destinationAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)

            let sourceSize = sourceAttributes[.size] as? NSNumber
            let destinationSize = destinationAttributes[.size] as? NSNumber

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
                    "size_bytes": destinationSize?.stringValue ?? "0"
                ])
            events.append(event)
            walkEvents.append(event)

            if session.mediaItems[index].importRawCompanions {
                try verifyCompanionFiles(for: &session.mediaItems[index], events: &events, walkEvents: &walkEvents)
            }
        }
    }

    private func verifyCompanionFiles(
        for item: inout MediaItem,
        events: inout [SessionLogEvent],
        walkEvents: inout [SessionLogEvent]
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

            item.companionFiles[companionIndex].verifiedAt = Date()
            let event = SessionLogEvent(timestamp: Date(), event: "companion_verified", mediaItemID: item.id, details: [
                "source": item.companionFiles[companionIndex].sourceURL.path,
                "destination": destinationURL.path
            ])
            events.append(event)
            walkEvents.append(event)
        }
    }

    private func buildFileManifests(for session: ImportSession, mediaItemIDs: Set<UUID>) -> [FileManifest] {
        session.mediaItems
            .filter { mediaItemIDs.contains($0.id) && $0.selectionState.isIncluded }
            .compactMap { item in
                guard let destinationURL = item.destinationURL else { return nil }
                return FileManifest(
                    mediaItemID: item.id,
                    archivePath: destinationURL.path,
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
                    walkTitle: session.walkMetadata.title,
                    walkLocation: session.walkMetadata.location,
                    notes: session.walkMetadata.notes
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
            location: session.walkMetadata.location,
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

    private func writeManifests(walkManifest: WalkManifest, fileManifests: [FileManifest], archiveFolder: URL, events: [SessionLogEvent]) throws {
        let walkBasename = archiveFolder.lastPathComponent
        let walkManifestURL = archiveFolder.appendingPathComponent("\(walkBasename).md")
        try manifestRenderer.renderWalkManifest(walkManifest).write(to: walkManifestURL, atomically: true, encoding: .utf8)

        for fileManifest in fileManifests {
            let destinationURL = URL(fileURLWithPath: fileManifest.archivePath)
            let fileURL = destinationURL.deletingPathExtension().appendingPathExtension("md")
            try manifestRenderer.renderFileManifest(fileManifest).write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let logURL = archiveFolder.appendingPathComponent("\(walkBasename)-session-log.jsonl")
        try manifestRenderer.renderLog(events).write(to: logURL, atomically: true, encoding: .utf8)
    }

}
