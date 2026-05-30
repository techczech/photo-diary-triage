import CryptoKit
import Foundation

struct ImportResult {
    var session: ImportSession
    var walkManifest: WalkManifest
    var fileManifests: [FileManifest]
    var events: [SessionLogEvent]
}

private struct FileVerificationResult {
    var eventDetails: [String: String]
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
        verificationMode: ImportVerificationMode = .sizeOnly,
        progress: (@Sendable (ImportProgress) async -> Void)? = nil
    ) async throws -> ImportResult {
        let plan = archivePlanner.plan(for: session)
        let relativePathResolver = ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot)
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

        try await verifyImportedFiles(in: &updatedSession, verificationMode: verificationMode, events: &events)
        refreshArchiveRelativePaths(in: &updatedSession)

        let fileManifests = buildFileManifests(for: updatedSession)
        let walkManifest = buildWalkManifest(for: updatedSession, archiveFolder: plan.archiveFolder, fileManifests: fileManifests)
        try writeManifests(walkManifest: walkManifest, fileManifests: fileManifests, archiveFolder: plan.archiveFolder, events: events)

        return ImportResult(session: updatedSession, walkManifest: walkManifest, fileManifests: fileManifests, events: events)
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
        verificationMode: ImportVerificationMode,
        events: inout [SessionLogEvent]
    ) async throws {
        for index in session.mediaItems.indices where session.mediaItems[index].selectionState.isIncluded && session.mediaItems[index].lifecycleState == .imported {
            guard let destinationURL = session.mediaItems[index].destinationURL else { continue }
            let verification = try await verifyFile(
                sourceURL: session.mediaItems[index].sourceURL,
                destinationURL: destinationURL,
                fileName: session.mediaItems[index].fileName,
                mode: verificationMode,
                failureCode: 1,
                failurePrefix: "Imported file verification failed"
            )

            session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: .verified)
            session.mediaItems[index].verifiedAt = Date()

            if session.walkMetadata.backupConfirmedAt != nil && session.archiveMachineRole.allowsSourceCleanup {
                session.mediaItems[index].lifecycleState = try session.mediaItems[index].lifecycleState.transition(to: .sourceCleanupPending)
            }

            events.append(
                SessionLogEvent(timestamp: Date(), event: "file_verified", mediaItemID: session.mediaItems[index].id, details: verification.eventDetails)
            )

            if session.mediaItems[index].importRawCompanions {
                try await verifyCompanionFiles(for: &session.mediaItems[index], verificationMode: verificationMode, events: &events)
            }
        }
    }

    private func verifyCompanionFiles(
        for item: inout MediaItem,
        verificationMode: ImportVerificationMode,
        events: inout [SessionLogEvent]
    ) async throws {
        for companionIndex in item.companionFiles.indices {
            guard let destinationURL = item.companionFiles[companionIndex].destinationURL else { continue }
            let verification = try await verifyFile(
                sourceURL: item.companionFiles[companionIndex].sourceURL,
                destinationURL: destinationURL,
                fileName: item.companionFiles[companionIndex].fileName,
                mode: verificationMode,
                failureCode: 2,
                failurePrefix: "Imported RAW sidecar verification failed"
            )

            item.companionFiles[companionIndex].verifiedAt = Date()
            events.append(
                SessionLogEvent(timestamp: Date(), event: "companion_verified", mediaItemID: item.id, details: verification.eventDetails)
            )
        }
    }

    private func verifyFile(
        sourceURL: URL,
        destinationURL: URL,
        fileName: String,
        mode: ImportVerificationMode,
        failureCode: Int,
        failurePrefix: String
    ) async throws -> FileVerificationResult {
        let sourceAttributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let destinationAttributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let sourceSize = sourceAttributes[.size] as? NSNumber
        let destinationSize = destinationAttributes[.size] as? NSNumber

        guard sourceSize == destinationSize else {
            logger.error("Verification failed for \(sourceURL.path, privacy: .public): size mismatch")
            throw verificationError(
                code: failureCode,
                description: "\(failurePrefix) for \(fileName): source and destination sizes differ.",
                sourceURL: sourceURL,
                destinationURL: destinationURL
            )
        }

        var details = [
            "source": sourceURL.path,
            "destination": destinationURL.path,
            "verification_mode": mode.rawValue,
            "size_bytes": destinationSize?.stringValue ?? "0"
        ]

        switch mode {
        case .sizeOnly:
            return FileVerificationResult(eventDetails: details)
        case .checksum:
            let sourceChecksum = try await sha256Digest(for: sourceURL)
            let destinationChecksum = try await sha256Digest(for: destinationURL)
            guard sourceChecksum == destinationChecksum else {
                logger.error("Verification failed for \(sourceURL.path, privacy: .public): checksum mismatch")
                throw verificationError(
                    code: failureCode,
                    description: "\(failurePrefix) for \(fileName): source and destination checksums differ.",
                    sourceURL: sourceURL,
                    destinationURL: destinationURL
                )
            }
            details["sha256"] = destinationChecksum
            return FileVerificationResult(eventDetails: details)
        }
    }

    private func sha256Digest(for url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        }.value
    }

    private func verificationError(code: Int, description: String, sourceURL: URL, destinationURL: URL) -> NSError {
        NSError(domain: "ImportCoordinator", code: code, userInfo: [
            NSLocalizedDescriptionKey: description,
            "source": sourceURL.path,
            "destination": destinationURL.path
        ])
    }

    private func buildFileManifests(for session: ImportSession) -> [FileManifest] {
        session.mediaItems
            .filter { $0.selectionState.isIncluded }
            .compactMap { item in
                guard let destinationURL = item.destinationURL else { return nil }
                return FileManifest(
                    mediaItemID: item.id,
                    archivePath: destinationURL.path,
                    archiveRelativePath: item.archiveRelativePath,
                    thumbnailCacheKey: item.thumbnailCacheKey,
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

    private func buildWalkManifest(for session: ImportSession, archiveFolder: URL, fileManifests: [FileManifest]) -> WalkManifest {
        let cleanupPending = session.mediaItems.filter { $0.lifecycleState == .sourceCleanupPending }.count
        let cleaned = session.mediaItems.filter { $0.lifecycleState == .sourceCleaned }.count
        let excludedFiles = session.mediaItems
            .filter { $0.selectionState.isExcluded }
            .map {
                RejectedFileManifest(
                    mediaItemID: $0.id,
                    sourceFileName: $0.fileName,
                    relativePath: $0.relativePath,
                    reason: "excluded"
                )
            }
        let candidateCount = session.mediaItems.filter { $0.selectionState.isCandidate }.count
        let undecidedCount = session.mediaItems.filter { $0.selectionState.isUndecided }.count

        return WalkManifest(
            sessionID: session.id,
            walkDate: session.mediaItems.compactMap(\.capturedAt).min(),
            sourceFolder: session.sourceFolder,
            archiveFolder: archiveFolder,
            archiveFolderRelativePath: ArchiveRelativePathResolver(root: session.oneDrivePicturesRoot).relativePath(for: archiveFolder),
            title: session.walkMetadata.title.nonEmpty ?? "Photo Walk",
            location: session.walkMetadata.location,
            notes: session.walkMetadata.notes,
            summary: .init(
                totalSourceFiles: session.mediaItems.reduce(0) { $0 + 1 + $1.companionFiles.count },
                visibleItems: session.mediaItems.count,
                importedFiles: fileManifests.count + fileManifests.reduce(0) { $0 + $1.companionArchivePaths.count },
                excludedFiles: excludedFiles.count,
                candidateFiles: candidateCount,
                undecidedFiles: undecidedCount,
                skippedFiles: session.mediaItems.count - fileManifests.count,
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
