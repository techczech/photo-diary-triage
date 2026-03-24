import Foundation

enum ThumbnailPriority: Sendable {
    case visible
    case background
}

actor ThumbnailScheduler {
    private let maxConcurrent: Int
    private var inFlightIDs: Set<UUID> = []
    private var pendingVisible: [MediaItem] = []
    private var pendingBackground: [MediaItem] = []
    private var queuedIDs: Set<UUID> = []

    init(maxConcurrent: Int = 4) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    func enqueue(_ items: [MediaItem], priority: ThumbnailPriority) -> [MediaItem] {
        for item in items where !inFlightIDs.contains(item.id) && !queuedIDs.contains(item.id) {
            queuedIDs.insert(item.id)
            switch priority {
            case .visible:
                pendingVisible.append(item)
            case .background:
                pendingBackground.append(item)
            }
        }
        return scheduleAvailable()
    }

    func complete(_ itemID: UUID) -> [MediaItem] {
        inFlightIDs.remove(itemID)
        return scheduleAvailable()
    }

    private func scheduleAvailable() -> [MediaItem] {
        var scheduled: [MediaItem] = []

        while inFlightIDs.count < maxConcurrent {
            guard let next = nextPendingItem() else { break }
            queuedIDs.remove(next.id)
            inFlightIDs.insert(next.id)
            scheduled.append(next)
        }

        return scheduled
    }

    private func nextPendingItem() -> MediaItem? {
        if !pendingVisible.isEmpty {
            return pendingVisible.removeFirst()
        }
        if !pendingBackground.isEmpty {
            return pendingBackground.removeFirst()
        }
        return nil
    }
}
