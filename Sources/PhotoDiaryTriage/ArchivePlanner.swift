import Foundation

struct ArchivePlanner {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func plan(for session: ImportSession) -> ArchiveCommitPlan {
        planWalks(for: session).first ?? ArchiveCommitPlan(
            archiveFolder: session.archiveRoot,
            entries: [],
            totalSourceFiles: session.mediaItems.count,
            selectedCount: 0,
            skippedCount: session.mediaItems.count
        )
    }

    func planWalks(for session: ImportSession, timeClusters: [TimeCluster] = []) -> [ArchiveCommitPlan] {
        let selectedItems = session.mediaItems
            .filter { $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond }
        let sortedSelectedItems = MediaItemSort.sorted(selectedItems)
        let proposedWalks = session.proposedWalks.isEmpty
            ? WalkBoundaryProposalService().proposedWalks(for: session, timeClusters: timeClusters)
            : session.proposedWalks
        let selectedByID = Dictionary(uniqueKeysWithValues: sortedSelectedItems.map { ($0.id, $0) })
        let walks = proposedWalks.isEmpty
            ? [Walk(
                title: session.walkMetadata.title.nonEmpty ?? session.walkMetadata.location.nonEmpty ?? "photo-walk",
                date: sortedSelectedItems.compactMap(\.capturedAt).min() ?? session.startedAt,
                mediaItemIDs: sortedSelectedItems.map(\.id),
                location: session.walkMetadata.location,
                latitude: session.walkMetadata.latitude,
                longitude: session.walkMetadata.longitude
            )]
            : proposedWalks

        var reservedDestinations: Set<String> = []
        return walks.compactMap { walk in
            let walkItems = MediaItemSort.sorted(walk.mediaItemIDs.compactMap { selectedByID[$0] })
            guard !walkItems.isEmpty else { return nil }
            return plan(for: walk, items: walkItems, session: session, reservedDestinations: &reservedDestinations)
        }
    }

    private func plan(
        for walk: Walk,
        items: [MediaItem],
        session: ImportSession,
        reservedDestinations: inout Set<String>
    ) -> ArchiveCommitPlan {
        let walkDate = items.compactMap(\.capturedAt).min() ?? walk.date
        let titleSource = walk.title.nonEmpty ?? session.walkMetadata.title.nonEmpty ?? session.walkMetadata.location.nonEmpty ?? "photo-walk"
        let walkFolderName = DateFormatting.archiveWalkFolderName(
            from: walkDate,
            title: titleSource,
            weekdayTokenStyle: session.weekdayTokenStyle
        )
        let tripTarget = walk.tripTarget
        let yearFolder = session.archiveRoot
            .appendingPathComponent(DateFormatting.archiveYearFolderName(from: walkDate), isDirectory: true)
        let tripFolder: URL
        switch tripTarget.kind {
        case .defaultMonth:
            tripFolder = yearFolder.appendingPathComponent(DateFormatting.archiveTripFolderName(from: walkDate), isDirectory: true)
        case .existingNamedTrip:
            if let relativePath = tripTarget.folderRelativePath {
                tripFolder = session.archiveRoot.appendingPathComponent(relativePath, isDirectory: true)
            } else {
                tripFolder = yearFolder.appendingPathComponent(DateFormatting.archiveTripFolderName(from: walkDate), isDirectory: true)
            }
        case .newNamedTrip:
            let title = tripTarget.title?.nonEmpty ?? walk.title.nonEmpty ?? "Trip"
            tripFolder = yearFolder.appendingPathComponent(DateFormatting.archiveTripFolderName(from: walkDate, tripTitle: title), isDirectory: true)
        }
        let archiveFolder = tripFolder.appendingPathComponent(walkFolderName, isDirectory: true)

        var entries: [ArchiveEntry] = []
        let fileStemBase = DateFormatting.archiveFileStem(from: walkDate, title: titleSource)
        for (offset, item) in items.enumerated() {
            let archiveStem = "\(fileStemBase)-\(String(format: "%03d", offset + 1))"
            let destination = makeUniqueDestination(stem: archiveStem, originalFileName: item.fileName, in: archiveFolder, reserved: &reservedDestinations)
            entries.append(
                ArchiveEntry(
                    mediaItemID: item.id,
                    companionFileID: nil,
                    sourceURL: item.sourceURL,
                    destinationURL: destination,
                    isCompanion: false
                )
            )

            if item.importRawCompanions {
                for companion in item.companionFiles {
                    let companionDestination = makeUniqueDestination(stem: archiveStem, originalFileName: companion.fileName, in: archiveFolder, reserved: &reservedDestinations)
                    entries.append(
                        ArchiveEntry(
                            mediaItemID: item.id,
                            companionFileID: companion.id,
                            sourceURL: companion.sourceURL,
                            destinationURL: companionDestination,
                            isCompanion: true
                        )
                    )
                }
            }
        }

        return ArchiveCommitPlan(
            walkID: walk.id,
            walkTitle: titleSource,
            tripTarget: tripTarget,
            archiveFolder: archiveFolder,
            tripFolder: tripFolder,
            entries: entries,
            totalSourceFiles: session.mediaItems.count,
            selectedCount: items.count,
            skippedCount: session.mediaItems.count - items.count
        )
    }

    private func makeUniqueDestination(stem: String, originalFileName: String, in folder: URL, reserved: inout Set<String>) -> URL {
        let ext = URL(fileURLWithPath: originalFileName).pathExtension.lowercased()
        let fileName = stem + (ext.isEmpty ? "" : ".\(ext)")
        var candidate = folder.appendingPathComponent(fileName)
        var counter = 1

        while reserved.contains(candidate.path) || fileManager.fileExists(atPath: candidate.path) {
            let numbered = "\(stem)-\(counter)" + (ext.isEmpty ? "" : ".\(ext)")
            candidate = folder.appendingPathComponent(numbered)
            counter += 1
        }

        reserved.insert(candidate.path)
        return candidate
    }

}
