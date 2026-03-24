import Foundation

struct InlineSectionOrganizer {
    let burstGroups: [BurstGroup]

    func inlineDaySections(from selectedBrowserNode: BrowserNode?) -> [InlineDaySection] {
        guard let node = selectedBrowserNode else { return [] }
        if node.kind == .day {
            return [makeInlineDaySection(from: node)].compactMap { $0 }
        }

        let dayChildren = (node.children ?? []).filter { $0.kind == .day }
        guard !dayChildren.isEmpty else { return [] }
        return dayChildren.compactMap(makeInlineDaySection(from:))
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
        let isExpanded = section.children.isEmpty || expandedSectionIDs.contains(section.id)
        guard isExpanded else { return [] }

        var ids = section.photoItemIDs
        for child in section.children {
            ids.append(contentsOf: visibleMediaItemIDs(in: child, expandedSectionIDs: expandedSectionIDs))
        }
        return ids
    }
}
