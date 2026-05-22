import Foundation
import OSLog

struct ArchiveLoadResult {
    let nodeID: String
    let items: [MediaItem]
    let statusMessage: String
}

final class BrowserViewModel {
    private let scanner: FileScanner
    private let fileManager: FileManager
    private let logger: Logger

    init(
        scanner: FileScanner,
        fileManager: FileManager = .default,
        logger: Logger = AppLogger.appState
    ) {
        self.scanner = scanner
        self.fileManager = fileManager
        self.logger = logger
    }

    func browserRoots(
        currentSession: ImportSession?,
        bursts: [BurstGroup],
        clusters: [TimeCluster],
        archiveRoot: URL,
        sourceWorkspaceState: SourceWorkspaceState,
        workspaceMode: WorkspaceMode
    ) -> [BrowserNode] {
        switch workspaceMode {
        case .archiveView, .archiveTriage:
            return [buildArchiveSection(rootURL: archiveRoot)]
        case .cameraTriage:
            return [buildCurrentSessionSection(currentSession: currentSession, bursts: bursts, clusters: clusters, sourceWorkspaceState: sourceWorkspaceState)]
        }
    }

    private func buildCurrentSessionSection(
        currentSession: ImportSession?,
        bursts: [BurstGroup],
        clusters: [TimeCluster],
        sourceWorkspaceState: SourceWorkspaceState
    ) -> BrowserNode {
        if let session = currentSession {
            return BrowserNode(
                id: "section-current-session",
                title: "Current Session",
                subtitle: session.sourceFolder.lastPathComponent,
                kind: .sessionSection,
                parentID: nil,
                mediaItemIDs: [],
                children: [buildSessionRoot(for: session, bursts: bursts, clusters: clusters)],
                folderURL: nil
            )
        }

        return BrowserNode(
            id: "section-current-session",
            title: "Current Session",
            subtitle: subtitleForEmptyCurrentSession(sourceWorkspaceState),
            kind: .sessionSection,
            parentID: nil,
            mediaItemIDs: [],
            children: nil,
            folderURL: nil
        )
    }

    private func subtitleForEmptyCurrentSession(_ state: SourceWorkspaceState) -> String {
        switch state {
        case .idle:
            return "No live source inbox loaded"
        case .loading(let sourcePath):
            return "Loading \(URL(fileURLWithPath: sourcePath).lastPathComponent)"
        case .loaded(let itemCount, let sourcePath):
            return "\(itemCount) item(s) loaded from \(URL(fileURLWithPath: sourcePath).lastPathComponent)"
        case .empty(let sourcePath):
            return "No supported media in \(URL(fileURLWithPath: sourcePath).lastPathComponent)"
        case .failed(_, let message):
            return message
        }
    }

    func nodeMap(for roots: [BrowserNode]) -> [String: BrowserNode] {
        var map: [String: BrowserNode] = [:]

        func walk(_ node: BrowserNode) {
            map[node.id] = node
            node.children?.forEach(walk)
        }

        roots.forEach(walk)
        return map
    }

    func preferredInitialSidebarNodeID(
        for session: ImportSession?,
        bursts: [BurstGroup],
        clusters: [TimeCluster]
    ) -> String {
        guard let session else { return "section-current-session" }

        let rootNode = buildSessionRoot(for: session, bursts: bursts, clusters: clusters)
        let nodeMap = nodeMap(for: [rootNode])

        var currentID = rootNode.id
        while let node = nodeMap[currentID] {
            let children = node.children ?? []
            let primaryChildren = children.filter { [.year, .month, .day].contains($0.kind) }
            guard primaryChildren.count == 1, let only = primaryChildren.first else { break }
            currentID = only.id
        }

        return currentID
    }

    func loadArchiveMediaIfNeeded(
        for nodeID: String?,
        browserNodeMap: [String: BrowserNode],
        archiveMediaCache: [String: [MediaItem]],
        settings: AppSettings
    ) throws -> ArchiveLoadResult? {
        guard let nodeID, archiveMediaCache[nodeID] == nil, let node = browserNodeMap[nodeID] else { return nil }
        guard (node.children?.isEmpty ?? true), let folderURL = node.folderURL, node.kind == .archiveWalkFolder else { return nil }

        let items = try scanner.scanFolder(folderURL, settings: settings)
        logger.log("Loaded \(items.count) archived items from \(folderURL.path, privacy: .public)")
        return ArchiveLoadResult(
            nodeID: nodeID,
            items: items,
            statusMessage: "Loaded \(items.count) archived item(s) from \(folderURL.lastPathComponent)."
        )
    }

    private func buildSessionRoot(for session: ImportSession, bursts: [BurstGroup], clusters: [TimeCluster]) -> BrowserNode {
        let calendar = Calendar(identifier: .gregorian)
        let sortedItems = session.mediaItems.sorted(by: Self.mediaSort)

        var byYear: [Int: [Int: [Int: [MediaItem]]]] = [:]
        var unknownDateItems: [MediaItem] = []

        for item in sortedItems {
            guard let capturedAt = item.capturedAt else {
                unknownDateItems.append(item)
                continue
            }

            let components = calendar.dateComponents([.year, .month, .day], from: capturedAt)
            guard let year = components.year, let month = components.month, let day = components.day else {
                unknownDateItems.append(item)
                continue
            }

            byYear[year, default: [:]][month, default: [:]][day, default: []].append(item)
        }

        let yearNodes = byYear.keys.sorted().map { year in
            buildYearNode(year: year, months: byYear[year] ?? [:], bursts: bursts, clusters: clusters)
        }

        var children = yearNodes
        if !unknownDateItems.isEmpty {
            children.append(buildUnknownNode(items: unknownDateItems))
        }

        return BrowserNode(
            id: "session-root",
            title: session.sourceFolder.lastPathComponent,
            subtitle: session.sourceFolder.path,
            kind: .sessionRoot,
            parentID: "section-current-session",
            mediaItemIDs: sortedItems.map(\.id),
            children: children,
            folderURL: session.sourceFolder
        )
    }

    private func buildYearNode(year: Int, months: [Int: [Int: [MediaItem]]], bursts: [BurstGroup], clusters: [TimeCluster]) -> BrowserNode {
        let monthNodes = months.keys.sorted().map { month in
            buildMonthNode(year: year, month: month, days: months[month] ?? [:], bursts: bursts, clusters: clusters)
        }

        return BrowserNode(
            id: "year-\(year)",
            title: String(year),
            subtitle: "\(monthNodes.reduce(0) { $0 + $1.mediaItemIDs.count }) photos",
            kind: .year,
            parentID: "session-root",
            mediaItemIDs: monthNodes.flatMap(\.mediaItemIDs),
            children: monthNodes,
            folderURL: nil
        )
    }

    private func buildMonthNode(year: Int, month: Int, days: [Int: [MediaItem]], bursts: [BurstGroup], clusters: [TimeCluster]) -> BrowserNode {
        let dayNodes = days.keys.sorted().map { day in
            buildDayNode(year: year, month: month, day: day, items: days[day] ?? [], bursts: bursts, clusters: clusters)
        }

        return BrowserNode(
            id: "month-\(year)-\(month)",
            title: String(format: "%02d", month),
            subtitle: "\(dayNodes.count) day(s)",
            kind: .month,
            parentID: "year-\(year)",
            mediaItemIDs: dayNodes.flatMap(\.mediaItemIDs),
            children: dayNodes,
            folderURL: nil
        )
    }

    private func buildDayNode(year: Int, month: Int, day: Int, items: [MediaItem], bursts: [BurstGroup], clusters: [TimeCluster]) -> BrowserNode {
        let dayID = "day-\(year)-\(month)-\(day)"
        var children: [BrowserNode] = [
            BrowserNode(
                id: "\(dayID)-photos",
                title: "Photos",
                subtitle: "\(items.count) item(s)",
                kind: .photosFolder,
                parentID: dayID,
                mediaItemIDs: items.map(\.id),
                children: nil,
                folderURL: nil
            )
        ]

        let dayItemIDs = Set(items.map(\.id))
        let dayBursts = bursts.compactMap { group -> BrowserNode? in
            let ids = group.mediaItemIDs.filter { dayItemIDs.contains($0) }
            guard !ids.isEmpty else { return nil }
            return BrowserNode(
                id: "burst-\(group.id.uuidString)",
                title: "Burst \(children.count + 1)",
                subtitle: "\(ids.count) item(s)",
                kind: .burstGroup,
                parentID: "\(dayID)-bursts",
                mediaItemIDs: ids,
                children: nil,
                folderURL: nil
            )
        }

        if !dayBursts.isEmpty {
            children.append(
                BrowserNode(
                    id: "\(dayID)-bursts",
                    title: "Bursts",
                    subtitle: "\(dayBursts.count) group(s)",
                    kind: .burstsFolder,
                    parentID: dayID,
                    mediaItemIDs: dayBursts.flatMap(\.mediaItemIDs),
                    children: dayBursts,
                    folderURL: nil
                )
            )
        }

        let dayTimeClusters = clusters.compactMap { group -> BrowserNode? in
            let ids = group.mediaItemIDs.filter { dayItemIDs.contains($0) }
            guard !ids.isEmpty else { return nil }
            return BrowserNode(
                id: "timecluster-\(group.id.uuidString)",
                title: "Time Cluster \(children.count + 1)",
                subtitle: "\(ids.count) item(s)",
                kind: .timeCluster,
                parentID: "\(dayID)-timeclusters",
                mediaItemIDs: ids,
                children: nil,
                folderURL: nil
            )
        }

        if !dayTimeClusters.isEmpty {
            children.append(
                BrowserNode(
                    id: "\(dayID)-timeclusters",
                    title: "Time Clusters",
                    subtitle: "\(dayTimeClusters.count) group(s)",
                    kind: .timeClustersFolder,
                    parentID: dayID,
                    mediaItemIDs: dayTimeClusters.flatMap(\.mediaItemIDs),
                    children: dayTimeClusters,
                    folderURL: nil
                )
            )
        }

        return BrowserNode(
            id: dayID,
            title: String(format: "%02d", day),
            subtitle: "\(items.count) item(s)",
            kind: .day,
            parentID: "month-\(year)-\(month)",
            mediaItemIDs: items.map(\.id),
            children: children,
            folderURL: nil
        )
    }

    private func buildArchiveSection(rootURL: URL) -> BrowserNode {
        let children = buildArchiveYearNodes(rootURL: rootURL)
        return BrowserNode(
            id: "section-archive-library",
            title: "Archive Library",
            subtitle: rootURL.path,
            kind: .archiveSection,
            parentID: nil,
            mediaItemIDs: [],
            children: [
                BrowserNode(
                    id: "archive-root",
                    title: rootURL.lastPathComponent.nonEmpty ?? "Pictures",
                    subtitle: rootURL.path,
                    kind: .archiveRoot,
                    parentID: "section-archive-library",
                    mediaItemIDs: [],
                    children: children,
                    folderURL: rootURL
                )
            ],
            folderURL: nil
        )
    }

    private func buildArchiveYearNodes(rootURL: URL) -> [BrowserNode] {
        let years = (try? fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return years
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { $0.lastPathComponent.range(of: #"^202\d$"#, options: .regularExpression) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { yearURL in
                let months = buildArchiveMonthNodes(yearURL: yearURL)
                return BrowserNode(
                    id: "archive-year-\(yearURL.lastPathComponent)",
                    title: yearURL.lastPathComponent,
                    subtitle: "\(months.count) month(s)",
                    kind: .year,
                    parentID: "archive-root",
                    mediaItemIDs: [],
                    children: months,
                    folderURL: yearURL
                )
            }
    }

    private func buildArchiveMonthNodes(yearURL: URL) -> [BrowserNode] {
        let months = (try? fileManager.contentsOfDirectory(at: yearURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return months
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { monthURL in
                let walks = buildArchiveWalkNodes(monthURL: monthURL)
                return BrowserNode(
                    id: "archive-month-\(yearURL.lastPathComponent)-\(monthURL.lastPathComponent)",
                    title: monthURL.lastPathComponent,
                    subtitle: "\(walks.count) walk folder(s)",
                    kind: .month,
                    parentID: "archive-year-\(yearURL.lastPathComponent)",
                    mediaItemIDs: [],
                    children: walks,
                    folderURL: monthURL
                )
            }
    }

    private func buildArchiveWalkNodes(monthURL: URL) -> [BrowserNode] {
        let walks = (try? fileManager.contentsOfDirectory(at: monthURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return walks
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { walkURL in
                BrowserNode(
                    id: "archive-walk-\(walkURL.path)",
                    title: walkURL.lastPathComponent,
                    subtitle: walkURL.path,
                    kind: .archiveWalkFolder,
                    parentID: "archive-month-\(monthURL.deletingLastPathComponent().lastPathComponent)-\(monthURL.lastPathComponent)",
                    mediaItemIDs: [],
                    children: nil,
                    folderURL: walkURL
                )
            }
    }

    private func buildUnknownNode(items: [MediaItem]) -> BrowserNode {
        let rootID = "unknown-date"
        let photosNode = BrowserNode(
            id: "\(rootID)-photos",
            title: "Photos",
            subtitle: "\(items.count) item(s)",
            kind: .photosFolder,
            parentID: rootID,
            mediaItemIDs: items.map(\.id),
            children: nil,
            folderURL: nil
        )

        return BrowserNode(
            id: rootID,
            title: "Unknown Date",
            subtitle: "\(items.count) item(s)",
            kind: .unknownDate,
            parentID: "session-root",
            mediaItemIDs: items.map(\.id),
            children: [photosNode],
            folderURL: nil
        )
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
