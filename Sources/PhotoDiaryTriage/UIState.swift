import AppKit
import Combine
import Foundation
import OSLog

struct SessionSummary: Equatable, Sendable {
    let sessionID: UUID
    let sourceFolderPath: String
    let itemCount: Int
    let includedCount: Int
    let walkMetadata: WalkMetadata
}

struct SidebarTreeSnapshot: Equatable, Sendable {
    let browserRoots: [BrowserNode]
    let selectedSidebarNodeID: String?

    static let empty = SidebarTreeSnapshot(browserRoots: [], selectedSidebarNodeID: nil)
}

struct ReviewItemSnapshot: Identifiable, Equatable, Sendable {
    let item: MediaItem
    let archivePreview: String
    let isSelected: Bool
    let isFocused: Bool
    let thumbnailFailed: Bool

    var id: UUID { item.id }
}

struct SidebarSnapshot: Equatable, Sendable {
    let sessionSummary: SessionSummary?
    let canMutateImportSelection: Bool
    let isWalkDetailsExpanded: Bool
    let archiveRootDisplayPath: String
    let archiveYearFolders: [String]
    let tree: SidebarTreeSnapshot
    let statusMessage: String
    let importProgress: ImportProgress?

    static let empty = SidebarSnapshot(
        sessionSummary: nil,
        canMutateImportSelection: false,
        isWalkDetailsExpanded: true,
        archiveRootDisplayPath: "",
        archiveYearFolders: [],
        tree: .empty,
        statusMessage: "Choose a source folder on the SSD to begin.",
        importProgress: nil
    )
}

struct ReviewSnapshot: Equatable, Sendable {
    let breadcrumbTitles: [String]
    let contextMediaItemCount: Int
    let detailFolderNodes: [BrowserNode]
    let visibleItems: [ReviewItemSnapshot]
    let itemSnapshotsByID: [UUID: ReviewItemSnapshot]
    let organizedInlineSections: [InlineSection]
    let groupedReviewSections: [GroupedReviewSection]
    let canUseGroupedReviewMode: Bool
    let availableDayDetailDisplayModes: [DayDetailDisplayMode]
    let dayOrganizationMode: DayOrganizationMode
    let dayDetailDisplayMode: DayDetailDisplayMode
    let reviewFilter: ReviewFilter
    let reviewPresentationMode: ReviewPresentationMode
    let reviewGridPreferredColumnCount: Int
    let reviewGridColumnCount: Int
    let reviewGridCardWidth: Double
    let selectedMediaItemIDs: Set<UUID>
    let focusedReviewItemID: UUID?
    let focusedInlineSectionID: String?
    let expandedInlineSectionIDs: Set<String>
    let canMutateImportSelection: Bool
    let canFocusReviewSurface: Bool
    let canUseGroupedSectionNavigation: Bool
    let canExpandAllGroupedSections: Bool
    let canCollapseAllGroupedSections: Bool
    let canOpenComparison: Bool
    let canMarkSelectionForImport: Bool
    let canExcludeSelectionFromImport: Bool
    let canUnmarkSelectionForImport: Bool
    let canToggleRawForSelection: Bool

    static let empty = ReviewSnapshot(
        breadcrumbTitles: [],
        contextMediaItemCount: 0,
        detailFolderNodes: [],
        visibleItems: [],
        itemSnapshotsByID: [:],
        organizedInlineSections: [],
        groupedReviewSections: [],
        canUseGroupedReviewMode: false,
        availableDayDetailDisplayModes: [.review],
        dayOrganizationMode: .days,
        dayDetailDisplayMode: .review,
        reviewFilter: .all,
        reviewPresentationMode: .grid,
        reviewGridPreferredColumnCount: ReviewGridMetrics.defaultRequestedColumnCount(),
        reviewGridColumnCount: 1,
        reviewGridCardWidth: ReviewGridMetrics.defaultCardWidth,
        selectedMediaItemIDs: [],
        focusedReviewItemID: nil,
        focusedInlineSectionID: nil,
        expandedInlineSectionIDs: [],
        canMutateImportSelection: false,
        canFocusReviewSurface: false,
        canUseGroupedSectionNavigation: false,
        canExpandAllGroupedSections: false,
        canCollapseAllGroupedSections: false,
        canOpenComparison: false,
        canMarkSelectionForImport: false,
        canExcludeSelectionFromImport: false,
        canUnmarkSelectionForImport: false,
        canToggleRawForSelection: false
    )
}

struct ReviewNavigationSnapshot: Equatable, Sendable {
    let activePane: ActivePane
    let reviewGridHasFocus: Bool
    let isGroupedSectionKeyboardTargetActive: Bool
    let pendingInlineScrollTargetID: UUID?
    let pendingReviewScrollTargetID: UUID?
    let pendingInlineSectionScrollTargetID: String?
    let pendingInlineSectionScrollRevision: Int

    static let empty = ReviewNavigationSnapshot(
        activePane: .sidebar,
        reviewGridHasFocus: false,
        isGroupedSectionKeyboardTargetActive: false,
        pendingInlineScrollTargetID: nil,
        pendingReviewScrollTargetID: nil,
        pendingInlineSectionScrollTargetID: nil,
        pendingInlineSectionScrollRevision: 0
    )
}

struct InspectorSnapshot: Equatable, Sendable {
    let isVisible: Bool
    let browserNode: BrowserNode?
    let fallbackFolderPath: String?
    let walkTitle: String?
    let walkLocation: String?
    let mediaItem: MediaItem?

    static let empty = InspectorSnapshot(
        isVisible: true,
        browserNode: nil,
        fallbackFolderPath: nil,
        walkTitle: nil,
        walkLocation: nil,
        mediaItem: nil
    )
}

struct CompareSnapshot: Equatable, Sendable {
    let title: String
    let itemIDs: [UUID]
    let items: [ReviewItemSnapshot]
    let gridColumnCount: Int

    static let empty = CompareSnapshot(title: "Compare Selection", itemIDs: [], items: [], gridColumnCount: 1)
}

struct PresentationSnapshot: Equatable {
    let showKeyboardHelp: Bool
    let startupAlert: AppStartupAlert?
    let previewingMediaItem: MediaItem?

    static let empty = PresentationSnapshot(showKeyboardHelp: false, startupAlert: nil, previewingMediaItem: nil)
}

@MainActor
final class SidebarState: ObservableObject {
    private(set) var snapshot: SidebarSnapshot = .empty
    private(set) var generation: Int = 0

    func update(_ snapshot: SidebarSnapshot) {
        guard self.snapshot != snapshot else { return }
        generation &+= 1
        objectWillChange.send()
        self.snapshot = snapshot
    }
}

@MainActor
final class ReviewState: ObservableObject {
    private(set) var snapshot: ReviewSnapshot = .empty
    private(set) var generation: Int = 0

    func update(_ snapshot: ReviewSnapshot) {
        guard self.snapshot != snapshot else { return }
        generation &+= 1
        objectWillChange.send()
        self.snapshot = snapshot
    }
}

@MainActor
final class ReviewNavigationState: ObservableObject {
    private(set) var snapshot: ReviewNavigationSnapshot = .empty
    private(set) var generation: Int = 0

    func update(_ snapshot: ReviewNavigationSnapshot) {
        guard self.snapshot != snapshot else { return }
        generation &+= 1
        objectWillChange.send()
        self.snapshot = snapshot
    }
}

@MainActor
final class InspectorState: ObservableObject {
    private(set) var snapshot: InspectorSnapshot = .empty
    private(set) var generation: Int = 0

    func update(_ snapshot: InspectorSnapshot) {
        guard self.snapshot != snapshot else { return }
        generation &+= 1
        objectWillChange.send()
        self.snapshot = snapshot
    }
}

@MainActor
final class CompareState: ObservableObject {
    private(set) var snapshot: CompareSnapshot = .empty
    private(set) var generation: Int = 0

    func update(_ snapshot: CompareSnapshot) {
        guard self.snapshot != snapshot else { return }
        generation &+= 1
        objectWillChange.send()
        self.snapshot = snapshot
    }
}

@MainActor
final class PresentationState: ObservableObject {
    private(set) var snapshot: PresentationSnapshot = .empty
    private(set) var generation: Int = 0

    func update(_ snapshot: PresentationSnapshot) {
        guard self.snapshot != snapshot else { return }
        generation &+= 1
        objectWillChange.send()
        self.snapshot = snapshot
    }
}

@MainActor
final class ThumbnailSlot: ObservableObject {
    private(set) var image: NSImage?
    private(set) var isMissing = false

    func update(image: NSImage?, isMissing: Bool) {
        let sameImage = self.image === image
        guard sameImage == false || self.isMissing != isMissing else { return }
        objectWillChange.send()
        self.image = image
        self.isMissing = isMissing
    }
}

@MainActor
final class ThumbnailRegistry {
    private var slots: [UUID: ThumbnailSlot] = [:]

    func slot(for itemID: UUID) -> ThumbnailSlot {
        if let slot = slots[itemID] {
            return slot
        }
        let slot = ThumbnailSlot()
        slots[itemID] = slot
        return slot
    }

    func update(itemID: UUID, image: NSImage?, isMissing: Bool) {
        slot(for: itemID).update(image: image, isMissing: isMissing)
    }

    func reset() {
        slots.removeAll()
    }
}

@MainActor
final class LatencyRecorder {
    private let logger = Logger(subsystem: "PhotoDiaryTriage", category: "Latency")
    private var activeMeasurements: [String: ContinuousClock.Instant] = [:]
    private let clock = ContinuousClock()

    func begin(_ action: String) {
#if DEBUG
        activeMeasurements[action] = clock.now
#endif
    }

    func end(_ action: String) {
#if DEBUG
        guard let start = activeMeasurements.removeValue(forKey: action) else { return }
        let duration = start.duration(to: clock.now)
        let milliseconds = Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        logger.debug("\(action, privacy: .public) latency: \(milliseconds, format: .fixed(precision: 2))ms")
#endif
    }
}
