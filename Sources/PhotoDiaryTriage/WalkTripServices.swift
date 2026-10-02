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
            let baseTitle = historicalTitle(items: items, session: session) ?? session.walkMetadata.title.nonEmpty ?? DateFormatting.automaticPhotoLogTitle.string(from: date)
            let dayKey = DateFormatting.archiveFormatterForParsing.string(from: calendar.startOfDay(for: date))
            baseCounts["\(dayKey)|\(baseTitle)", default: 0] += 1
        }

        var baseOrdinals: [String: Int] = [:]
        return sortedGroups.map { items in
                let date = items.compactMap(\.capturedAt).min() ?? session.startedAt
                let sourceIDs = Array(Set(items.compactMap(\.sourceProvenanceID))).sorted { $0.uuidString < $1.uuidString }
                let baseTitle = historicalTitle(items: items, session: session) ?? session.walkMetadata.title.nonEmpty ?? DateFormatting.automaticPhotoLogTitle.string(from: date)
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
                    tripTarget: historicalTrip(items: items, session: session),
                    location: session.walkMetadata.location,
                    latitude: session.walkMetadata.latitude,
                    longitude: session.walkMetadata.longitude
                )
            }
    }
    private func historicalContext(items: [MediaItem], session: ImportSession) -> HistoricalSourceContext? {
        let contexts = items.compactMap { HistoricalSourceSafety.context(for: $0.sourceURL, in: session) }
        guard contexts.count == items.count, Set(contexts.map(\.root)).count == 1 else { return nil }
        return contexts.first
    }

    private func historicalTitle(items: [MediaItem], session: ImportSession) -> String? {
        guard let context = historicalContext(items: items, session: session),
              session.walkMetadata.title.isEmpty || session.walkMetadata.title == context.proposedTripTitle else { return nil }
        return HistoricalSourceHints.walkTitle(for: items, context: context)
    }

    private func historicalTrip(items: [MediaItem], session: ImportSession) -> TripTarget {
        guard let context = historicalContext(items: items, session: session), let title = context.proposedTripTitle else { return .defaultMonth }
        return TripTarget(kind: .newNamedTrip, title: title, folderRelativePath: nil)
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
            text = try rewriteStructured(text, extension: sidecar.pathExtension.lowercased(), spec: spec)
            if text != original {
                try text.write(to: sidecar, atomically: true, encoding: .utf8)
                rewrittenCount += 1
            }
        }
        return rewrittenCount
    }

    func rewrite(_ text: String, spec: ArchiveTextRewriteSpec) -> String {
        (try? rewriteStructured(text, extension: "md", spec: spec)) ?? text
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
        removing removals: [String] = [],
        replacing replacements: [String: String] = [:]
    ) throws -> TripManifest {
        try AppDirectories.ensureExists(folder, fileManager: fileManager)
        let url = tripManifestURL(for: folder)
        let original = fileManager.fileExists(atPath: url.path) ? try String(contentsOf: url, encoding: .utf8) : nil
        if let original, firstBacktickedValue(after: "Trip ID:", in: original).flatMap(UUID.init(uuidString:)) == nil {
            throw ArchiveFileVerification.failure("The existing Trip identity could not be read. Its text has been retained.")
        }
        let existing = loadTripManifest(folder: folder, oneDrivePicturesRoot: oneDrivePicturesRoot)
        let removalSet = Set(removals)
        let knownMembers = original == nil ? try canonicalWalkMembers(in: folder, oneDrivePicturesRoot: oneDrivePicturesRoot).map(\.relativePath) : existing.memberWalkFolderPaths
        var members = knownMembers.filter { !removalSet.contains($0) }.map { replacements[$0] ?? $0 }
        for addition in additions where !members.contains(addition.relativePath) {
            members.append(addition.relativePath)
        }
        if original == nil { members.sort() }

        let compactDates = try members.compactMap { member -> Date? in
            if let date = additions.first(where: { $0.relativePath == member })?.date { return date }
            let walk = oneDrivePicturesRoot.appendingPathComponent(member)
            let url = walk.appendingPathComponent("\(walk.lastPathComponent).md")
            let text = try String(contentsOf: url, encoding: .utf8)
            return firstValue(after: "Walk date:", in: text).flatMap { DateFormatting.iso8601.date(from: $0) }
        }
        let manifest = TripManifest(
            tripID: existing.tripID,
            title: original != nil ? existing.title : (title?.nonEmpty ?? existing.title.nonEmpty ?? folder.lastPathComponent),
            folder: folder,
            folderRelativePath: ArchiveRelativePathResolver(root: oneDrivePicturesRoot).relativePath(for: folder),
            startDate: compactDates.min(),
            endDate: compactDates.max(),
            memberWalkFolderPaths: members,
            locationLabelOverride: existing.locationLabelOverride,
            descriptions: existing.descriptions, googlePhotos: existing.googlePhotos
        )
        var rendered = renderer.renderTripManifest(manifest)
        if let original { rendered = try TripManifestText.settingMembership(manifest, in: original, renderer: renderer) }
        try rendered.write(to: url, atomically: true, encoding: .utf8)
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
        let memberText = text.components(separatedBy: "## Member Walks").dropFirst().first?.components(separatedBy: "\n## ").first ?? ""
        let members = memberText.split(separator: "\n").compactMap { line -> String? in
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
            memberWalkFolderPaths: members,
            locationLabelOverride: TripManifestText.headerValue("Location label override", in: text)?.nonEmpty,
            descriptions: try? MachineDescriptionHistory.read(in: text), googlePhotos: try? GooglePhotosRecord.read(in: text)
        )
    }

    func canonicalWalkMembers(in folder: URL, oneDrivePicturesRoot: URL) throws -> [TripManifestMemberUpdate] {
        let resolver = ArchiveRelativePathResolver(root: oneDrivePicturesRoot)
        var members: [TripManifestMemberUpdate] = []
        for child in try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) {
            let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
            let manifestURL = child.appendingPathComponent(child.lastPathComponent + ".md")
            guard fileManager.fileExists(atPath: manifestURL.path) else { continue }
            let file = try manifestURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard file.isRegularFile == true, file.isSymbolicLink != true else { throw ArchiveFileVerification.failure("A canonical Walk manifest must be a regular file.") }
            let text = try String(contentsOf: manifestURL, encoding: .utf8)
            guard firstBacktickedValue(after: "Session ID:", in: text).flatMap(UUID.init(uuidString:)) != nil,
                  let absolute = firstBacktickedValue(after: "Archive folder:", in: text),
                  let relative = resolver.relativePath(for: child) else { continue }
            // A relocated Archive retains its canonical relative path; an unrelated copied header does not establish a Walk.
            if let recorded = firstBacktickedValue(after: "OneDrive Pictures relative folder:", in: text) {
                guard recorded == relative else { continue }
            } else {
                guard URL(fileURLWithPath: absolute).resolvingSymlinksInPath().standardizedFileURL == child.resolvingSymlinksInPath().standardizedFileURL else { continue }
            }
            members.append(TripManifestMemberUpdate(relativePath: relative,
                date: firstValue(after: "Walk date:", in: text).flatMap { DateFormatting.iso8601.date(from: $0) }))
        }
        return members.sorted { $0.relativePath < $1.relativePath }
    }

    private func tripManifestURL(for folder: URL) -> URL {
        folder.appendingPathComponent("\(folder.lastPathComponent).md")
    }

    private func firstBacktickedValue(after label: String, in text: String) -> String? {
        guard let line = text.components(separatedBy: "## ")[0].split(separator: "\n").map(String.init).first(where: { $0.hasPrefix("- " + label) }),
              let first = line.firstIndex(of: "`"),
              let last = line.lastIndex(of: "`"),
              first < last else { return nil }
        return String(line[line.index(after: first)..<last])
    }

    private func firstValue(after label: String, in text: String) -> String? {
        text.components(separatedBy: "## ")[0].split(separator: "\n").map(String.init).first { $0.hasPrefix("- " + label) }?.components(separatedBy: label).last?.trimmingCharacters(in: .whitespaces)
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

    func moveWalk(at walkFolder: URL, to tripFolder: URL, oneDrivePicturesRoot: URL, archiveRoot: URL? = nil) throws -> WalkMoveResult {
        let oldTripFolder = walkFolder.deletingLastPathComponent()
        if oldTripFolder.standardizedFileURL == tripFolder.standardizedFileURL {
            return WalkMoveResult(sourceFolder: walkFolder, destinationFolder: walkFolder)
        }
        let root = archiveRoot ?? walkFolder.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let mutationLock = try ArchiveMutationLock(archiveRoot: root)
        defer { withExtendedLifetime(mutationLock) {} }
        try ArchiveLayoutMigrator.assertNoPending(overlapping: oldTripFolder, archiveRoot: root)
        try ArchiveLayoutMigrator.assertNoPending(overlapping: tripFolder, archiveRoot: root)
        let operation = ArchiveFolderOperation(archiveRoot: root, fileManager: fileManager)
        let previous = try operation.recorded(for: walkFolder)
        let destination: URL
        if let previous, !previous.complete || !fileManager.fileExists(atPath: walkFolder.path) {
            guard previous.destination.deletingLastPathComponent().standardizedFileURL == tripFolder.standardizedFileURL else {
                throw ArchiveFileVerification.failure("Finish the previous move before selecting a different Trip.")
            }
            destination = previous.destination
        } else { destination = uniqueDestination(for: walkFolder.lastPathComponent, in: tripFolder) }
        let resolver = ArchiveRelativePathResolver(root: oneDrivePicturesRoot)
        let oldWalkRelative = resolver.relativePath(for: walkFolder)
        let newWalkRelative = resolver.relativePath(for: destination)
        let spec = ArchiveTextRewriteSpec(oldAbsoluteFolderPath: walkFolder.path, newAbsoluteFolderPath: destination.path,
            oldRelativeFolderPath: oldWalkRelative, newRelativeFolderPath: newWalkRelative,
            oldTripRelativePath: resolver.relativePath(for: oldTripFolder), newTripRelativePath: resolver.relativePath(for: tripFolder))
        var names: [String: String] = [:]
        if walkFolder.lastPathComponent != destination.lastPathComponent, fileManager.fileExists(atPath: walkFolder.path) {
            for suffix in [".md", "-session-log.jsonl"] {
                let oldName = walkFolder.lastPathComponent + suffix
                if fileManager.fileExists(atPath: walkFolder.appendingPathComponent(oldName).path) {
                    names[oldName] = destination.lastPathComponent + suffix
                }
            }
        }
        let record = try operation.prepare(source: walkFolder, destination: destination, spec: spec, names: names)
        _ = try operation.execute(record)
        let date = try ArchiveIndexStore(fileManager: fileManager).loadWalkManifest(folder: destination, archiveRoot: root)?.walkDate
        if let oldWalkRelative {
            _ = try tripManifestStore.updateNamedTripManifest(folder: oldTripFolder, title: nil,
                oneDrivePicturesRoot: oneDrivePicturesRoot, adding: [], removing: [oldWalkRelative])
        }
        if let newWalkRelative {
            _ = try tripManifestStore.updateNamedTripManifest(folder: tripFolder, title: nil,
                oneDrivePicturesRoot: oneDrivePicturesRoot,
                adding: [TripManifestMemberUpdate(relativePath: newWalkRelative, date: date)])
        }
        try operation.complete(record)
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
