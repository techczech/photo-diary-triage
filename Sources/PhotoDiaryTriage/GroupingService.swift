import Foundation

struct GroupingResult: Sendable {
    var items: [MediaItem]
    var burstGroups: [BurstGroup]
    var timeClusters: [TimeCluster]
}

struct GroupingService {
    func group(items: [MediaItem], settings: AppSettings) -> GroupingResult {
        let sorted = items.sorted {
            let lhs = $0.capturedAt ?? .distantPast
            let rhs = $1.capturedAt ?? .distantPast
            if lhs == rhs {
                return $0.fileName < $1.fileName
            }
            return lhs < rhs
        }

        var mutableItems = sorted
        for index in mutableItems.indices {
            mutableItems[index].burstGroupID = nil
            mutableItems[index].timeClusterID = nil
        }
        let burstGroups = assignBurstGroups(to: &mutableItems, threshold: settings.burstThresholdSeconds)
        let timeClusters = assignTimeClusters(to: &mutableItems, threshold: settings.proximityThresholdSeconds)

        return GroupingResult(items: mutableItems, burstGroups: burstGroups, timeClusters: timeClusters)
    }

    private func assignBurstGroups(to items: inout [MediaItem], threshold: TimeInterval) -> [BurstGroup] {
        let groups = contiguousGroups(in: items, threshold: threshold)
        for group in groups {
            for index in items.indices where group.mediaItemIDs.contains(items[index].id) {
                items[index].burstGroupID = group.id
            }
        }
        return groups.map { BurstGroup(id: $0.id, mediaItemIDs: $0.mediaItemIDs, startedAt: $0.startedAt, endedAt: $0.endedAt) }
    }

    private func assignTimeClusters(to items: inout [MediaItem], threshold: TimeInterval) -> [TimeCluster] {
        let groups = contiguousGroups(in: items, threshold: threshold)
        for group in groups {
            for index in items.indices where group.mediaItemIDs.contains(items[index].id) {
                items[index].timeClusterID = group.id
            }
        }
        return groups.map { TimeCluster(id: $0.id, mediaItemIDs: $0.mediaItemIDs, startedAt: $0.startedAt, endedAt: $0.endedAt) }
    }

    private func contiguousGroups(in items: [MediaItem], threshold: TimeInterval) -> [(id: UUID, mediaItemIDs: [UUID], startedAt: Date?, endedAt: Date?)] {
        var groups: [(id: UUID, mediaItemIDs: [UUID], startedAt: Date?, endedAt: Date?)] = []
        var currentIDs: [UUID] = []
        var groupStart: Date?
        var previousItem: MediaItem?

        func finalizeGroupIfNeeded(endDate: Date?) {
            guard currentIDs.count > 1 else {
                currentIDs.removeAll()
                groupStart = nil
                return
            }
            groups.append((id: UUID(), mediaItemIDs: currentIDs, startedAt: groupStart, endedAt: endDate))
            currentIDs.removeAll()
            groupStart = nil
        }

        for item in items {
            guard let capturedAt = item.capturedAt else {
                finalizeGroupIfNeeded(endDate: previousItem?.capturedAt)
                previousItem = nil
                continue
            }

            if let previousItem, let previousDate = previousItem.capturedAt, capturedAt.timeIntervalSince(previousDate) <= threshold {
                if currentIDs.isEmpty {
                    currentIDs.append(previousItem.id)
                    groupStart = previousDate
                }
                currentIDs.append(item.id)
            } else {
                finalizeGroupIfNeeded(endDate: previousItem?.capturedAt)
            }

            previousItem = item
        }

        finalizeGroupIfNeeded(endDate: previousItem?.capturedAt)
        return groups
    }
}
