import Foundation

struct ArchivePlanner {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func plan(for session: ImportSession) -> ArchiveCommitPlan {
        let selectedItems = session.mediaItems
            .filter { $0.selectionState.isIncluded }
            .sorted(by: Self.mediaSort)
        let walkDate = selectedItems.compactMap(\.capturedAt).min() ?? session.startedAt
        let titleSource = session.walkMetadata.title.nonEmpty ?? session.walkMetadata.location.nonEmpty ?? "photo-walk"
        let walkFolderName = DateFormatting.archiveWalkFolderName(from: walkDate, title: titleSource)
        let archiveFolder = session.archiveRoot
            .appendingPathComponent(DateFormatting.archiveYearFolderName(from: walkDate), isDirectory: true)
            .appendingPathComponent(DateFormatting.archiveMonthFolderName(from: walkDate), isDirectory: true)
            .appendingPathComponent(walkFolderName, isDirectory: true)

        var reservedDestinations: Set<String> = []
        var entries: [ArchiveEntry] = []
        for (offset, item) in selectedItems.enumerated() {
            let archiveStem = "\(walkFolderName)-\(String(format: "%03d", offset + 1))"
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
            selectedCount: selectedItems.count,
            skippedCount: session.mediaItems.count - selectedItems.count
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

    private static func mediaSort(lhs: MediaItem, rhs: MediaItem) -> Bool {
        let lhsDate = lhs.capturedAt ?? .distantPast
        let rhsDate = rhs.capturedAt ?? .distantPast
        if lhsDate == rhsDate {
            return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }
        return lhsDate < rhsDate
    }
}
