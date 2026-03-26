import Foundation

struct ImportResult {
    var session: ImportSession
    var walkManifest: WalkManifest
    var fileManifests: [FileManifest]
    var events: [SessionLogEvent]
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
        let plan = archivePlanner.plan(for: session)
        try AppDirectories.ensureExists(plan.archiveFolder, fileManager: fileManager)

        var updatedSession = session
        var events: [SessionLogEvent] = [
            SessionLogEvent(timestamp: Date(), event: "session_commit_started", mediaItemID: nil, details: [
                "session_id": session.id.uuidString,
                "archive_folder": plan.archiveFolder.path
            ])
        ]

        let totalEntries = max(plan.entries.count, 1)
        var completedEntries = 0

        for entry in plan.entries {
            if !fileManager.fileExists(atPath: entry.destinationURL.path) {
                try fileManager.copyItem(at: entry.sourceURL, to: entry.destinationURL)
            }

            guard let index = updatedSession.mediaItems.firstIndex(where: { $0.id == entry.mediaItemID }) else {
                continue
            }

            if entry.isCompanion {
                if let companionIndex = updatedSession.mediaItems[index].companionFiles.firstIndex(where: { $0.id == entry.companionFileID }) {
                    updatedSession.mediaItems[index].companionFiles[companionIndex].destinationURL = entry.destinationURL
                    updatedSession.mediaItems[index].companionFiles[companionIndex].importedAt = Date()
                }
            } else {
                updatedSession.mediaItems[index].destinationURL = entry.destinationURL
                updatedSession.mediaItems[index].lifecycleState = try updatedSession.mediaItems[index].lifecycleState.transition(to: .imported)
                updatedSession.mediaItems[index].importedAt = Date()
            }

            events.append(
                SessionLogEvent(timestamp: Date(), event: "file_imported", mediaItemID: entry.mediaItemID, details: [
                    "source": entry.sourceURL.path,
                    "destination": entry.destinationURL.path,
                    "is_companion": entry.isCompanion ? "true" : "false"
                ])
            )

            completedEntries += 1
            if let progress {
                await progress(ImportProgress(current: completedEntries, total: totalEntries))
            }
        }

        updatedSession.lastUpdatedAt = Date()
        updatedSession.status = "imported"

        try verifyImportedFiles(in: &updatedSession, events: &events)

        let fileManifests = buildFileManifests(for: updatedSession)
        let walkManifest = buildWalkManifest(for: updatedSession, archiveFolder: plan.archiveFolder, fileManifests: fileManifests)
        try writeManifests(walkManifest: walkManifest, fileManifests: fileManifests, archiveFolder: plan.archiveFolder, events: events)

        return ImportResult(session: updatedSession, walkManifest: walkManifest, fileManifests: fileManifests, events: events)
    }

    func cleanupImportedSources(in session: ImportSession) async throws -> ImportSession {
        var updatedSession = session
        let cleanupAllowed = !session.mediaItems.contains {
            $0.selectionState.isIncluded && $0.lifecycleState != .sourceCleanupPending && $0.lifecycleState != .sourceCleaned
        }
        guard cleanupAllowed else { return session }

        for index in updatedSession.mediaItems.indices {
            guard updatedSession.mediaItems[index].lifecycleState == .sourceCleanupPending else { continue }
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
        updatedSession.status = "source_cleaned"
        return updatedSession
    }

    private func verifyImportedFiles(in session: inout ImportSession, events: inout [SessionLogEvent]) throws {
        for index in session.mediaItems.indices where session.mediaItems[index].selectionState.isIncluded {
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

            if session.walkMetadata.backupConfirmedAt != nil {
                session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: .sourceCleanupPending)
            }

            events.append(
                SessionLogEvent(timestamp: Date(), event: "file_verified", mediaItemID: session.mediaItems[index].id, details: [
                    "destination": destinationURL.path,
                    "size_bytes": destinationSize?.stringValue ?? "0"
                ])
            )

            if session.mediaItems[index].importRawCompanions {
                try verifyCompanionFiles(for: &session.mediaItems[index], events: &events)
            }
        }
    }

    private func verifyCompanionFiles(for item: inout MediaItem, events: inout [SessionLogEvent]) throws {
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
            events.append(
                SessionLogEvent(timestamp: Date(), event: "companion_verified", mediaItemID: item.id, details: [
                    "source": item.companionFiles[companionIndex].sourceURL.path,
                    "destination": destinationURL.path
                ])
            )
        }
    }

    private func buildFileManifests(for session: ImportSession) -> [FileManifest] {
        session.mediaItems
            .filter { $0.selectionState.isIncluded }
            .compactMap { item in
                guard let destinationURL = item.destinationURL else { return nil }
                return FileManifest(
                    mediaItemID: item.id,
                    archivePath: destinationURL.path,
                    sourceFileName: item.fileName,
                    companionArchivePaths: item.companionFiles.compactMap(\.destinationURL?.path),
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

    private func buildWalkManifest(for session: ImportSession, archiveFolder: URL, fileManifests: [FileManifest]) -> WalkManifest {
        let cleanupPending = session.mediaItems.filter { $0.lifecycleState == .sourceCleanupPending }.count
        let cleaned = session.mediaItems.filter { $0.lifecycleState == .sourceCleaned }.count

        return WalkManifest(
            sessionID: session.id,
            walkDate: session.mediaItems.compactMap(\.capturedAt).min(),
            sourceFolder: session.sourceFolder,
            archiveFolder: archiveFolder,
            title: session.walkMetadata.title.nonEmpty ?? "Photo Walk",
            location: session.walkMetadata.location,
            notes: session.walkMetadata.notes,
            summary: .init(
                totalSourceFiles: session.mediaItems.reduce(0) { $0 + 1 + $1.companionFiles.count },
                visibleItems: session.mediaItems.count,
                importedFiles: fileManifests.count + fileManifests.reduce(0) { $0 + $1.companionArchivePaths.count },
                skippedFiles: session.mediaItems.count - fileManifests.count,
                cleanupPendingFiles: cleanupPending,
                cleanedSourceFiles: cleaned
            ),
            importedFiles: fileManifests
        )
    }

    private func writeManifests(walkManifest: WalkManifest, fileManifests: [FileManifest], archiveFolder: URL, events: [SessionLogEvent]) throws {
        let sessionFolder = archiveFolder.appendingPathComponent("_session", isDirectory: true)
        try AppDirectories.ensureExists(sessionFolder, fileManager: fileManager)

        let walkManifestURL = sessionFolder.appendingPathComponent("WalkManifest.md")
        try manifestRenderer.renderWalkManifest(walkManifest).write(to: walkManifestURL, atomically: true, encoding: .utf8)

        let filesFolder = sessionFolder.appendingPathComponent("files", isDirectory: true)
        try AppDirectories.ensureExists(filesFolder, fileManager: fileManager)

        for fileManifest in fileManifests {
            let fileURL = filesFolder.appendingPathComponent("\(fileManifest.mediaItemID.uuidString).md")
            try manifestRenderer.renderFileManifest(fileManifest).write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let logURL = sessionFolder.appendingPathComponent("session-log.jsonl")
        try manifestRenderer.renderLog(events).write(to: logURL, atomically: true, encoding: .utf8)
    }
}
