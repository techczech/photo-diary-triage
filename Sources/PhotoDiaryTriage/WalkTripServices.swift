import Foundation

struct WalkBoundaryProposalService {
    func proposedWalks(for session: ImportSession, timeClusters: [TimeCluster] = []) -> [Walk] {
        let selectedItems = MediaItemSort.sorted(
            session.mediaItems.filter { $0.selectionState.isIncluded && !$0.lifecycleState.isImportedOrBeyond }
        )
        guard !selectedItems.isEmpty else { return [] }

        let itemByID = Dictionary(uniqueKeysWithValues: selectedItems.map { ($0.id, $0) })
        var consumedIDs: Set<UUID> = []
        var groups: [[MediaItem]] = []

        for cluster in timeClusters.sorted(by: { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }) {
            let clusterItems = MediaItemSort.sorted(cluster.mediaItemIDs.compactMap { itemByID[$0] })
            guard !clusterItems.isEmpty else { continue }
            groups.append(clusterItems)
            consumedIDs.formUnion(clusterItems.map(\.id))
        }

        let remaining = selectedItems.filter { !consumedIDs.contains($0.id) }
        let calendar = Calendar(identifier: .gregorian)
        let remainingByDay = Dictionary(grouping: remaining) { item -> Date in
            calendar.startOfDay(for: item.capturedAt ?? session.startedAt)
        }

        for day in remainingByDay.keys.sorted() {
            groups.append(MediaItemSort.sorted(remainingByDay[day] ?? []))
        }

        let sortedGroups = groups
            .filter { !$0.isEmpty }
            .sorted { lhs, rhs in
                (lhs.compactMap(\.capturedAt).min() ?? session.startedAt) < (rhs.compactMap(\.capturedAt).min() ?? session.startedAt)
            }

        var baseCounts: [String: Int] = [:]
        for items in sortedGroups {
            let date = items.compactMap(\.capturedAt).min() ?? session.startedAt
            let baseTitle = session.walkMetadata.title.nonEmpty ?? DateFormatting.automaticPhotoLogTitle.string(from: date)
            let dayKey = DateFormatting.archiveFormatterForParsing.string(from: calendar.startOfDay(for: date))
            baseCounts["\(dayKey)|\(baseTitle)", default: 0] += 1
        }

        var baseOrdinals: [String: Int] = [:]
        return sortedGroups.map { items in
                let date = items.compactMap(\.capturedAt).min() ?? session.startedAt
                let sourceIDs = Array(Set(items.compactMap(\.sourceProvenanceID))).sorted { $0.uuidString < $1.uuidString }
                let baseTitle = session.walkMetadata.title.nonEmpty ?? DateFormatting.automaticPhotoLogTitle.string(from: date)
                let dayKey = DateFormatting.archiveFormatterForParsing.string(from: calendar.startOfDay(for: date))
                let titleKey = "\(dayKey)|\(baseTitle)"
                baseOrdinals[titleKey, default: 0] += 1
                let defaultTitle = (baseCounts[titleKey] ?? 0) > 1
                    ? "\(baseTitle) \(baseOrdinals[titleKey] ?? 1)"
                    : baseTitle
                return Walk(
                    title: defaultTitle,
                    date: date,
                    sourceProvenanceIDs: sourceIDs,
                    mediaItemIDs: items.map(\.id),
                    location: session.walkMetadata.location,
                    latitude: session.walkMetadata.latitude,
                    longitude: session.walkMetadata.longitude
                )
            }
    }
}

struct ExistingTrip: Identifiable, Hashable, Sendable {
    var id: String { folderRelativePath }
    var title: String
    var folder: URL
    var folderRelativePath: String
    var year: String
}

struct TripLibraryScanner {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func namedTrips(in archiveRoot: URL, year: String? = nil) -> [ExistingTrip] {
        let yearFolders: [URL]
        if let year {
            yearFolders = [archiveRoot.appendingPathComponent(year, isDirectory: true)]
        } else {
            yearFolders = ((try? fileManager.contentsOfDirectory(
                at: archiveRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { $0.lastPathComponent.range(of: #"^(19|20)\d\d$"#, options: .regularExpression) != nil }
        }

        return yearFolders.flatMap { yearURL in
            ((try? fileManager.contentsOfDirectory(
                at: yearURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { Self.isNamedTripFolder($0) }
            .map { tripURL in
                let relative = "\(yearURL.lastPathComponent)/\(tripURL.lastPathComponent)"
                let title = tripURL.lastPathComponent
                    .replacingOccurrences(of: #"^\d\d-[^-]+-"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "-", with: " ")
                return ExistingTrip(
                    title: title,
                    folder: tripURL,
                    folderRelativePath: relative,
                    year: yearURL.lastPathComponent
                )
            }
        }
        .sorted { $0.folderRelativePath < $1.folderRelativePath }
    }

    static func isNamedTripFolder(_ url: URL) -> Bool {
        url.lastPathComponent.range(of: #"^\d\d-[^-]+-.+"#, options: .regularExpression) != nil
    }
}

struct ArchiveTextRewriteSpec {
    var oldAbsoluteFolderPath: String?
    var newAbsoluteFolderPath: String?
    var oldRelativeFolderPath: String?
    var newRelativeFolderPath: String?
    var oldTripRelativePath: String?
    var newTripRelativePath: String?
    var oldStemBase: String?
    var newStemBase: String?
    var oldWalkName: String?
    var newWalkName: String?
}

struct ArchiveTextSidecarRewriter {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    func rewriteSidecars(in folder: URL, spec: ArchiveTextRewriteSpec) throws -> Int {
        let textExtensions: Set<String> = ["md", "json", "jsonl"]
        let sidecars = textSidecars(in: folder, textExtensions: textExtensions)
        var rewrittenCount = 0

        for sidecar in sidecars {
            var text = try String(contentsOf: sidecar, encoding: .utf8)
            let original = text
            text = rewrite(text, spec: spec)
            if text != original {
                try text.write(to: sidecar, atomically: true, encoding: .utf8)
                rewrittenCount += 1
            }
        }
        return rewrittenCount
    }

    func rewrite(_ text: String, spec: ArchiveTextRewriteSpec) -> String {
        var rewritten = text
        if let old = spec.oldAbsoluteFolderPath, let new = spec.newAbsoluteFolderPath {
            rewritten = rewritten.replacingOccurrences(of: old, with: new)
        }
        if let old = spec.oldRelativeFolderPath, let new = spec.newRelativeFolderPath {
            rewritten = rewritten.replacingOccurrences(of: old, with: new)
        }
        if let old = spec.oldTripRelativePath, let new = spec.newTripRelativePath {
            rewritten = rewritten.replacingOccurrences(of: old, with: new)
        }
        if let old = spec.oldStemBase, let new = spec.newStemBase {
            rewritten = rewritten.replacingOccurrences(
                of: "\(NSRegularExpression.escapedPattern(for: old))-(\\d{3})",
                with: "\(new)-$1",
                options: .regularExpression
            )
        }
        if let old = spec.oldWalkName, let new = spec.newWalkName {
            rewritten = rewritten.replacingOccurrences(of: old, with: new)
        }
        return rewritten
    }

    private func textSidecars(in folder: URL, textExtensions: Set<String>) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { entry -> URL? in
            guard let url = entry as? URL else { return nil }
            guard textExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            return url
        }
    }
}

struct TripManifestMemberUpdate: Sendable {
    var relativePath: String
    var date: Date?
}

struct TripManifestStore {
    let fileManager: FileManager
    let renderer: ManifestRenderer

    init(fileManager: FileManager = .default, renderer: ManifestRenderer = ManifestRenderer()) {
        self.fileManager = fileManager
        self.renderer = renderer
    }

    @discardableResult
    func updateNamedTripManifest(
        folder: URL,
        title: String?,
        oneDrivePicturesRoot: URL,
        adding additions: [TripManifestMemberUpdate],
        removing removals: [String] = []
    ) throws -> TripManifest {
        try AppDirectories.ensureExists(folder, fileManager: fileManager)
        let existing = loadTripManifest(folder: folder, oneDrivePicturesRoot: oneDrivePicturesRoot)
        let removalSet = Set(removals)
        var members = existing.memberWalkFolderPaths.filter { !removalSet.contains($0) }
        for addition in additions where !members.contains(addition.relativePath) {
            members.append(addition.relativePath)
        }
        members.sort()

        let dates = [existing.startDate, existing.endDate] + additions.map(\.date)
        let compactDates = dates.compactMap { $0 }
        let manifest = TripManifest(
            tripID: existing.tripID,
            title: title?.nonEmpty ?? existing.title.nonEmpty ?? folder.lastPathComponent,
            folder: folder,
            folderRelativePath: ArchiveRelativePathResolver(root: oneDrivePicturesRoot).relativePath(for: folder),
            startDate: compactDates.min(),
            endDate: compactDates.max(),
            memberWalkFolderPaths: members
        )
        try renderer.renderTripManifest(manifest).write(to: tripManifestURL(for: folder), atomically: true, encoding: .utf8)
        return manifest
    }

    func loadTripManifest(folder: URL, oneDrivePicturesRoot: URL) -> TripManifest {
        let url = tripManifestURL(for: folder)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return TripManifest(
                tripID: UUID(),
                title: folder.lastPathComponent,
                folder: folder,
                folderRelativePath: ArchiveRelativePathResolver(root: oneDrivePicturesRoot).relativePath(for: folder),
                startDate: nil,
                endDate: nil,
                memberWalkFolderPaths: []
            )
        }

        let title = text.split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix("# ") }
            .map { String($0.dropFirst(2)) } ?? folder.lastPathComponent
        let tripID = firstBacktickedValue(after: "Trip ID:", in: text).flatMap(UUID.init(uuidString:)) ?? UUID()
        let startDate = firstValue(after: "Start date:", in: text).flatMap { DateFormatting.iso8601.date(from: $0) }
        let endDate = firstValue(after: "End date:", in: text).flatMap { DateFormatting.iso8601.date(from: $0) }
        let members = text.split(separator: "\n").compactMap { line -> String? in
            let string = String(line.trimmingCharacters(in: .whitespaces))
            guard string.hasPrefix("- `"), string.hasSuffix("`") else { return nil }
            let value = String(string.dropFirst(3).dropLast())
            guard value.contains("/") else { return nil }
            return value
        }
        return TripManifest(
            tripID: tripID,
            title: title,
            folder: folder,
            folderRelativePath: ArchiveRelativePathResolver(root: oneDrivePicturesRoot).relativePath(for: folder),
            startDate: startDate,
            endDate: endDate,
            memberWalkFolderPaths: members
        )
    }

    private func tripManifestURL(for folder: URL) -> URL {
        folder.appendingPathComponent("\(folder.lastPathComponent).md")
    }

    private func firstBacktickedValue(after label: String, in text: String) -> String? {
        guard let line = text.split(separator: "\n").map(String.init).first(where: { $0.contains(label) }),
              let first = line.firstIndex(of: "`"),
              let last = line.lastIndex(of: "`"),
              first < last else { return nil }
        return String(line[line.index(after: first)..<last])
    }

    private func firstValue(after label: String, in text: String) -> String? {
        text.split(separator: "\n").map(String.init).first { $0.contains(label) }?.components(separatedBy: label).last?.trimmingCharacters(in: .whitespaces)
    }
}

struct WalkMoveResult: Sendable {
    var sourceFolder: URL
    var destinationFolder: URL
}

struct WalkMover {
    let fileManager: FileManager
    let rewriter: ArchiveTextSidecarRewriter
    let tripManifestStore: TripManifestStore

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rewriter = ArchiveTextSidecarRewriter(fileManager: fileManager)
        self.tripManifestStore = TripManifestStore(fileManager: fileManager)
    }

    func moveWalk(at walkFolder: URL, to tripFolder: URL, oneDrivePicturesRoot: URL) throws -> WalkMoveResult {
        try AppDirectories.ensureExists(tripFolder, fileManager: fileManager)
        let oldTripFolder = walkFolder.deletingLastPathComponent()
        let destination = uniqueDestination(for: walkFolder.lastPathComponent, in: tripFolder)
        try fileManager.moveItem(at: walkFolder, to: destination)

        let resolver = ArchiveRelativePathResolver(root: oneDrivePicturesRoot)
        let oldWalkRelative = resolver.relativePath(for: walkFolder)
        let newWalkRelative = resolver.relativePath(for: destination)
        let oldTripRelative = resolver.relativePath(for: oldTripFolder)
        let newTripRelative = resolver.relativePath(for: tripFolder)
        try rewriter.rewriteSidecars(
            in: destination,
            spec: ArchiveTextRewriteSpec(
                oldAbsoluteFolderPath: walkFolder.path,
                newAbsoluteFolderPath: destination.path,
                oldRelativeFolderPath: oldWalkRelative,
                newRelativeFolderPath: newWalkRelative,
                oldTripRelativePath: oldTripRelative,
                newTripRelativePath: newTripRelative,
                oldWalkName: walkFolder.lastPathComponent,
                newWalkName: destination.lastPathComponent
            )
        )

        if oldTripFolder.standardizedFileURL != tripFolder.standardizedFileURL,
           let oldWalkRelative {
            if TripLibraryScanner.isNamedTripFolder(oldTripFolder) {
                _ = try tripManifestStore.updateNamedTripManifest(
                    folder: oldTripFolder,
                    title: oldTripFolder.lastPathComponent,
                    oneDrivePicturesRoot: oneDrivePicturesRoot,
                    adding: [],
                    removing: [oldWalkRelative]
                )
            }
            if TripLibraryScanner.isNamedTripFolder(tripFolder), let newWalkRelative {
                _ = try tripManifestStore.updateNamedTripManifest(
                    folder: tripFolder,
                    title: tripFolder.lastPathComponent,
                    oneDrivePicturesRoot: oneDrivePicturesRoot,
                    adding: [TripManifestMemberUpdate(relativePath: newWalkRelative, date: nil)]
                )
            }
        }
        return WalkMoveResult(sourceFolder: walkFolder, destinationFolder: destination)
    }

    private func uniqueDestination(for folderName: String, in tripFolder: URL) -> URL {
        var candidate = tripFolder.appendingPathComponent(folderName, isDirectory: true)
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = tripFolder.appendingPathComponent("\(folderName)-\(counter)", isDirectory: true)
            counter += 1
        }
        return candidate
    }
}
