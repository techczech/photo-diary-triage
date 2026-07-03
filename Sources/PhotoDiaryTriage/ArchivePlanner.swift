import Foundation

struct ArchivePlanner {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func plan(for session: ImportSession) -> ArchiveCommitPlan {
        let selectedItems = session.mediaItems
            .filter { $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond }
        let sortedSelectedItems = MediaItemSort.sorted(selectedItems)
        let walkDate = sortedSelectedItems.compactMap(\.capturedAt).min() ?? session.startedAt
        let titleSource = session.walkMetadata.title.nonEmpty ?? session.walkMetadata.location.nonEmpty ?? "photo-walk"
        let walkFolderName = DateFormatting.archiveWalkFolderName(from: walkDate, title: titleSource)
        let archiveFolder = session.archiveRoot
            .appendingPathComponent(DateFormatting.archiveYearFolderName(from: walkDate), isDirectory: true)
            .appendingPathComponent(DateFormatting.archiveTripFolderName(from: walkDate), isDirectory: true)
            .appendingPathComponent(walkFolderName, isDirectory: true)

        var reservedDestinations: Set<String> = []
        var entries: [ArchiveEntry] = []
        let fileStemBase = DateFormatting.archiveFileStem(from: walkDate, title: titleSource)
        for (offset, item) in sortedSelectedItems.enumerated() {
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
            archiveFolder: archiveFolder,
            entries: entries,
            totalSourceFiles: session.mediaItems.count,
            selectedCount: sortedSelectedItems.count,
            skippedCount: session.mediaItems.count - sortedSelectedItems.count
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
