import Foundation

struct ArchivePlanner {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func plan(for session: ImportSession) -> ArchiveCommitPlan {
        let selectedItems = session.mediaItems.filter { $0.selectionState == .selected }
        let walkDate = selectedItems.compactMap(\.capturedAt).min() ?? session.startedAt
        let walkFolder = DateFormatting.walkFolderPath(from: walkDate)
        let titleSource = session.walkMetadata.title.nonEmpty ?? session.walkMetadata.location.nonEmpty ?? "photo-walk"
        let archiveFolder = session.archiveRoot
            .appendingPathComponent(walkFolder, isDirectory: true)
            .appendingPathComponent(Slugifier.makeSlug(from: titleSource), isDirectory: true)

        var reservedDestinations: Set<String> = []
        var entries: [ArchiveEntry] = []
        for item in selectedItems {
            let destination = makeUniqueDestination(for: item.fileName, in: archiveFolder, reserved: &reservedDestinations)
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
                    let companionDestination = makeUniqueDestination(for: companion.fileName, in: archiveFolder, reserved: &reservedDestinations)
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
            selectedCount: selectedItems.count,
            skippedCount: session.mediaItems.count - selectedItems.count
        )
    }

    private func makeUniqueDestination(for fileName: String, in folder: URL, reserved: inout Set<String>) -> URL {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension
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
