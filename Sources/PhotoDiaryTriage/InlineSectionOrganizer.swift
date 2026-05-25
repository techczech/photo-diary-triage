import Foundation

struct InlineSectionOrganizer {
    let burstGroups: [BurstGroup]

    func inlineDaySections(from selectedBrowserNode: BrowserNode?, visibleItems: [MediaItem]) -> [InlineDaySection] {
        guard let node = selectedBrowserNode else { return [] }
        if node.kind == .day {
            return [makeInlineDaySection(from: node)].compactMap { $0 }
        }

        let dayChildren = (node.children ?? []).filter { $0.kind == .day }
        if !dayChildren.isEmpty {
            return dayChildren.compactMap(makeInlineDaySection(from:))
        }

        return syntheticInlineDaySections(from: visibleItems, parentNodeID: node.id)
    }

    func organizedInlineSections(from daySections: [InlineDaySection], mode: DayOrganizationMode) -> [InlineSection] {
        daySections.map { buildInlineSection(for: $0, mode: mode) }
    }

    func flattenSectionIDs(from sections: [InlineSection]) -> [String] {
        sections.flatMap { [$0.id] + flattenSectionIDs(from: $0.children) }
    }

    func groupedReviewSections(from sections: [InlineSection]) -> [GroupedReviewSection] {
        flattenGroupedReviewSections(from: sections, depth: 0)
    }

    func visibleMediaItemIDs(from sections: [InlineSection], expandedSectionIDs: Set<String>) -> [UUID] {
        sections.flatMap { visibleMediaItemIDs(in: $0, expandedSectionIDs: expandedSectionIDs) }
    }

    func previewItemIDs(
        for section: InlineSection,
        availableItems: [UUID: MediaItem],
        limit: Int
    ) -> [UUID] {
        let burstRepresentativeIDs = representativeBurstItemIDs(in: section, availableItems: availableItems)
        let nonBurstIDs = evenlySampledIDs(
            from: section.mediaItemIDs.filter { !burstRepresentativeIDs.contains($0) },
            limit: max(0, limit - burstRepresentativeIDs.count)
        )

        return Array((burstRepresentativeIDs + nonBurstIDs).prefix(limit)).filter { availableItems[$0] != nil }
    }

    private func makeInlineDaySection(from node: BrowserNode) -> InlineDaySection? {
        guard node.kind == .day else { return nil }
        let children = node.children ?? []
        let photosNode = children.first { $0.kind == .photosFolder }
        let burstFolderNode = children.first { $0.kind == .burstsFolder }
        let timeClusterFolderNode = children.first { $0.kind == .timeClustersFolder }
        return InlineDaySection(
            id: node.id,
            dayNode: node,
            photosNode: photosNode,
            burstFolderNode: burstFolderNode,
            timeClusterFolderNode: timeClusterFolderNode
        )
    }

    private func syntheticInlineDaySections(from items: [MediaItem], parentNodeID: String?) -> [InlineDaySection] {
        guard !items.isEmpty else { return [] }

        let calendar = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: items) { item in
            item.capturedAt.flatMap { calendar.startOfDay(for: $0) }
        }

        let orderedKeys = grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (lhs?, rhs?):
                return lhs < rhs
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return false
            }
        }

        return orderedKeys.compactMap { dayStart in
            guard let dayItems = grouped[dayStart]?.sorted(by: mediaSort) else { return nil }
            return makeSyntheticInlineDaySection(
                from: dayItems,
                dayStart: dayStart,
                parentNodeID: parentNodeID
            )
        }
    }

    private func makeSyntheticInlineDaySection(from items: [MediaItem], dayStart: Date?, parentNodeID: String?) -> InlineDaySection {
        let dayID = syntheticDayID(for: dayStart, items: items)
        let dayNode = BrowserNode(
            id: dayID,
            title: syntheticDayTitle(for: dayStart),
            subtitle: "\(items.count) item(s)",
            kind: .day,
            parentID: parentNodeID,
            mediaItemIDs: items.map(\.id),
            children: nil,
            folderURL: nil
        )

        let photosNode = BrowserNode(
            id: "\(dayID)-photos",
            title: "Photos",
            subtitle: "\(items.count) item(s)",
            kind: .photosFolder,
            parentID: dayID,
            mediaItemIDs: items.map(\.id),
            children: nil,
            folderURL: nil
        )

        let burstFolderNode = syntheticGroupFolderNode(
            kind: .burstsFolder,
            title: "Bursts",
            nodeID: "\(dayID)-bursts",
            parentID: dayID,
            items: items,
            groupID: \.burstGroupID,
            childKind: .burstGroup,
            childTitlePrefix: "Burst"
        )

        let timeClusterFolderNode = syntheticGroupFolderNode(
            kind: .timeClustersFolder,
            title: "Time Clusters",
            nodeID: "\(dayID)-clusters",
            parentID: dayID,
            items: items,
            groupID: \.timeClusterID,
            childKind: .timeCluster,
            childTitlePrefix: "Cluster"
        )

        return InlineDaySection(
            id: dayID,
            dayNode: dayNode,
            photosNode: photosNode,
            burstFolderNode: burstFolderNode,
            timeClusterFolderNode: timeClusterFolderNode
        )
    }

    private func syntheticGroupFolderNode(
        kind: BrowserNodeKind,
        title: String,
        nodeID: String,
        parentID: String,
        items: [MediaItem],
        groupID: KeyPath<MediaItem, UUID?>,
        childKind: BrowserNodeKind,
        childTitlePrefix: String
    ) -> BrowserNode? {
        let groupedItems = Dictionary(grouping: items.compactMap { item -> (UUID, MediaItem)? in
            guard let id = item[keyPath: groupID] else { return nil }
            return (id, item)
        }, by: \.0)

        let children = groupedItems.keys.sorted { lhs, rhs in
            let lhsDate = groupedItems[lhs]?.compactMap(\.1.capturedAt).min() ?? .distantPast
            let rhsDate = groupedItems[rhs]?.compactMap(\.1.capturedAt).min() ?? .distantPast
            return lhsDate < rhsDate
        }
        .compactMap { id -> BrowserNode? in
            guard let grouped = groupedItems[id]?.map(\.1).sorted(by: mediaSort), !grouped.isEmpty else { return nil }
            return BrowserNode(
                id: "\(nodeID)-\(id.uuidString)",
                title: "\(childTitlePrefix) \(grouped.count)",
                subtitle: "\(grouped.count) item(s)",
                kind: childKind,
                parentID: nodeID,
                mediaItemIDs: grouped.map(\.id),
                children: nil,
                folderURL: nil
            )
        }

        guard !children.isEmpty else { return nil }
        return BrowserNode(
            id: nodeID,
            title: title,
            subtitle: "\(children.count) group(s)",
            kind: kind,
            parentID: parentID,
            mediaItemIDs: items.map(\.id),
            children: children,
            folderURL: nil
        )
    }

    private func syntheticDayID(for dayStart: Date?, items: [MediaItem]) -> String {
        if let dayStart {
            return "synthetic-day-\(syntheticDayFormatter.string(from: dayStart))"
        }
        return "synthetic-day-unknown-\(items.count)"
    }

    private func syntheticDayTitle(for dayStart: Date?) -> String {
        guard let dayStart else { return "Unknown Date" }
        return syntheticDayFormatter.string(from: dayStart)
    }

    private var syntheticDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func mediaSort(lhs: MediaItem, rhs: MediaItem) -> Bool {
        let lhsDate = lhs.capturedAt ?? .distantPast
        let rhsDate = rhs.capturedAt ?? .distantPast
        if lhsDate == rhsDate {
            if lhs.cropSortFamilyKey == rhs.cropSortFamilyKey,
               lhs.cropSortPriority != rhs.cropSortPriority {
                return lhs.cropSortPriority < rhs.cropSortPriority
            }
            return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }
        return lhsDate < rhsDate
    }

    private func buildInlineSection(for section: InlineDaySection, mode: DayOrganizationMode) -> InlineSection {
        let dayItemIDs = section.mediaItemIDs

        switch mode {
        case .days:
            return InlineSection(
                id: section.id,
                title: section.dayNode.title,
                kind: .day,
                mediaItemIDs: dayItemIDs,
                photoItemIDs: dayItemIDs,
                children: []
            )
        case .daysAndBursts:
            let burstChildren = buildBurstSections(from: section.burstFolderNode?.children ?? [], allowedItemIDs: Set(dayItemIDs))
            let remainder = makeRemainderSection(
                id: "\(section.id)-other-photos",
                title: "Other Photos",
                itemIDs: dayItemIDs,
                groupedItemIDs: Set(burstChildren.flatMap(\.mediaItemIDs))
            )
            return InlineSection(
                id: section.id,
                title: section.dayNode.title,
                kind: .day,
                mediaItemIDs: dayItemIDs,
                photoItemIDs: [],
                children: burstChildren + (remainder.map { [$0] } ?? [])
            )
        case .daysAndClusters:
            let clusterChildren = buildClusterSections(
                from: section.timeClusterFolderNode?.children ?? [],
                allowedItemIDs: Set(dayItemIDs),
                includeBursts: false
            )
            let remainder = makeRemainderSection(
                id: "\(section.id)-other-photos",
                title: "Other Photos",
                itemIDs: dayItemIDs,
                groupedItemIDs: Set(clusterChildren.flatMap(\.mediaItemIDs))
            )
            return InlineSection(
                id: section.id,
                title: section.dayNode.title,
                kind: .day,
                mediaItemIDs: dayItemIDs,
                photoItemIDs: [],
                children: clusterChildren + (remainder.map { [$0] } ?? [])
            )
        case .daysClustersAndBursts:
            let clusterChildren = buildClusterSections(
                from: section.timeClusterFolderNode?.children ?? [],
                allowedItemIDs: Set(dayItemIDs),
                includeBursts: true
            )
            let remainder = makeRemainderSection(
                id: "\(section.id)-other-photos",
                title: "Other Photos",
                itemIDs: dayItemIDs,
                groupedItemIDs: Set(clusterChildren.flatMap(\.mediaItemIDs))
            )
            return InlineSection(
                id: section.id,
                title: section.dayNode.title,
                kind: .day,
                mediaItemIDs: dayItemIDs,
                photoItemIDs: [],
                children: clusterChildren + (remainder.map { [$0] } ?? [])
            )
        }
    }

    private func buildClusterSections(from clusters: [BrowserNode], allowedItemIDs: Set<UUID>, includeBursts: Bool) -> [InlineSection] {
        clusters.compactMap { cluster in
            let clusterItemIDs = cluster.mediaItemIDs.filter { allowedItemIDs.contains($0) }
            guard !clusterItemIDs.isEmpty else { return nil }

            if includeBursts {
                let burstChildren = buildBurstSections(
                    from: burstGroups.compactMap { burst -> BrowserNode? in
                        let ids = burst.mediaItemIDs.filter { clusterItemIDs.contains($0) }
                        guard !ids.isEmpty else { return nil }
                        return BrowserNode(
                            id: "nested-burst-\(burst.id.uuidString)",
                            title: "Burst",
                            subtitle: "\(ids.count) item(s)",
                            kind: .burstGroup,
                            parentID: cluster.id,
                            mediaItemIDs: ids,
                            children: nil,
                            folderURL: nil
                        )
                    },
                    allowedItemIDs: Set(clusterItemIDs)
                )
                let remainder = makeRemainderSection(
                    id: "\(cluster.id)-other-photos",
                    title: "Other Photos",
                    itemIDs: clusterItemIDs,
                    groupedItemIDs: Set(burstChildren.flatMap(\.mediaItemIDs))
                )
                return InlineSection(
                    id: cluster.id,
                    title: cluster.title,
                    kind: .cluster,
                    mediaItemIDs: clusterItemIDs,
                    photoItemIDs: [],
                    children: burstChildren + (remainder.map { [$0] } ?? [])
                )
            }

            return InlineSection(
                id: cluster.id,
                title: cluster.title,
                kind: .cluster,
                mediaItemIDs: clusterItemIDs,
                photoItemIDs: clusterItemIDs,
                children: []
            )
        }
    }

    private func buildBurstSections(from bursts: [BrowserNode], allowedItemIDs: Set<UUID>) -> [InlineSection] {
        bursts.compactMap { burst in
            let burstItemIDs = burst.mediaItemIDs.filter { allowedItemIDs.contains($0) }
            guard !burstItemIDs.isEmpty else { return nil }
            return InlineSection(
                id: burst.id,
                title: burst.title,
                kind: .burst,
                mediaItemIDs: burstItemIDs,
                photoItemIDs: burstItemIDs,
                children: []
            )
        }
    }

    private func makeRemainderSection(id: String, title: String, itemIDs: [UUID], groupedItemIDs: Set<UUID>) -> InlineSection? {
        let remainderIDs = itemIDs.filter { !groupedItemIDs.contains($0) }
        guard !remainderIDs.isEmpty else { return nil }
        return InlineSection(
            id: id,
            title: title,
            kind: .remainder,
            mediaItemIDs: remainderIDs,
            photoItemIDs: remainderIDs,
            children: []
        )
    }

    private func representativeBurstItemIDs(in section: InlineSection, availableItems: [UUID: MediaItem]) -> [UUID] {
        let burstSections = flattenedBurstSections(in: section)
        guard !burstSections.isEmpty else { return [] }
        return burstSections.compactMap { burst in
            evenlySampledIDs(from: burst.mediaItemIDs, limit: 1).first
        }
        .filter { availableItems[$0] != nil }
    }

    private func flattenedBurstSections(in section: InlineSection) -> [InlineSection] {
        var result: [InlineSection] = []
        if section.kind == .burst {
            result.append(section)
        }
        for child in section.children {
            result.append(contentsOf: flattenedBurstSections(in: child))
        }
        return result
    }

    private func evenlySampledIDs(from ids: [UUID], limit: Int) -> [UUID] {
        guard limit > 0, !ids.isEmpty else { return [] }
        if ids.count <= limit { return ids }
        if limit == 1 { return [ids[ids.count / 2]] }

        let lastIndex = ids.count - 1
        return (0..<limit).map { position in
            let fraction = Double(position) / Double(limit - 1)
            let index = Int((fraction * Double(lastIndex)).rounded())
            return ids[index]
        }
    }

    private func flattenGroupedReviewSections(from sections: [InlineSection], depth: Int) -> [GroupedReviewSection] {
        sections.flatMap { section in
            let directItemIDs = section.photoItemIDs.isEmpty && section.children.isEmpty ? section.mediaItemIDs : section.photoItemIDs

            var flattened: [GroupedReviewSection] = [
                GroupedReviewSection(
                    id: section.id,
                    title: section.title,
                    kind: section.kind,
                    depth: depth,
                    mediaItemIDs: directItemIDs
                )
            ]

            flattened.append(contentsOf: flattenGroupedReviewSections(from: section.children, depth: depth + 1))
            return flattened
        }
    }

    private func visibleMediaItemIDs(in section: InlineSection, expandedSectionIDs: Set<String>) -> [UUID] {
        let isExpanded = expandedSectionIDs.contains(section.id)
        guard isExpanded else { return [] }

        var ids = section.photoItemIDs
        for child in section.children {
            ids.append(contentsOf: visibleMediaItemIDs(in: child, expandedSectionIDs: expandedSectionIDs))
        }
        return ids
    }
}
