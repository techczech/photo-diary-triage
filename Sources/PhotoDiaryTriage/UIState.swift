import AppKit
import Combine
import Foundation
import OSLog

struct SessionSummary: Equatable, Sendable {
    let sessionID: UUID
    let sourceFolderPath: String
    let workspaceSourceFolderPath: String
    let itemCount: Int
    let includedCount: Int
    let candidateCount: Int
    let excludedCount: Int
    let sessionKind: SessionKind
    let status: String
    let walkMetadata: WalkMetadata
    let photoLogScope: PhotoLogScopeDescriptor?
}

struct PhotoLogSummary: Identifiable, Equatable, Sendable {
    let sessionID: UUID
    let title: String
    let sourceFolderPath: String
    let workspaceSourceFolderPath: String
    let itemCount: Int
    let includedCount: Int
    let candidateCount: Int
    let excludedCount: Int
    let sessionKind: SessionKind
    let status: String
    let sourceIsAvailable: Bool
    let lastUpdatedAt: Date
    let isCurrentSession: Bool
    let scopeLabel: String

    var id: UUID { sessionID }

    var isMembershipLocked: Bool {
        PhotoLogStatusPolicy.isMembershipLocked(status: status)
    }

    var membershipLockMessage: String? {
        PhotoLogStatusPolicy.membershipLockMessage(status: status)
    }
}

struct PhotoLogGroupSnapshot: Identifiable, Equatable, Sendable {
    let scopeLabel: String
    let sourceIsAvailable: Bool
    let logs: [PhotoLogSummary]

    var id: String { scopeLabel }
}

struct PhotoLogEditorState: Identifiable, Equatable {
    enum Mode: Equatable {
        case create
        case edit(sessionID: UUID)
    }

    let id: UUID
    let mode: Mode
    var creationMode: PhotoLogCreationMode
    var title: String
    var location: String
    var notes: String
    var scopeKind: PhotoLogScopeKind
    var scopeLabel: String
    var sourceFolderPaths: [String]
    var startDate: Date?
    var endDate: Date?
}

struct PhotoLogRevealState: Identifiable, Equatable {
    let sessionID: UUID
    let title: String
    let relativePaths: [String]

    var id: UUID { sessionID }
}

struct ImportReadinessSnapshot: Equatable, Sendable {
    let sessionKind: SessionKind
    let includedItems: Int
    let candidateItems: Int
    let excludedItems: Int
    let undecidedItems: Int
    let rawCompanionFiles: Int
    let totalFiles: Int
    let destinationPath: String?
    let verifiedAwaitingBackupItems: Int
    let cleanupPendingItems: Int
    let backupConfirmed: Bool
    let cleanupRequiresBackupConfirmation: Bool

    var hasFilesToCopy: Bool {
        totalFiles > 0
    }

    var hasCopiedArchiveDestination: Bool {
        destinationPath != nil && (verifiedAwaitingBackupItems > 0 || cleanupPendingItems > 0 || backupConfirmed)
    }

    var archiveDestinationLabel: String {
        hasCopiedArchiveDestination ? "Copied archive folder" : "Planned archive folder"
    }

    var needsArchiveReviewBeforeBackupConfirmation: Bool {
        if verifiedAwaitingBackupItems > 0 {
            return cleanupRequiresBackupConfirmation && !backupConfirmed
        }
        if cleanupPendingItems > 0 {
            return cleanupRequiresBackupConfirmation && !backupConfirmed
        }
        return false
    }

    var copyButtonHelp: String {
        if hasFilesToCopy {
            return "Copy every S (include) photo into the archive destination shown here."
        }
        if sessionKind == .walkDraft {
            return "Continue this photo log and mark at least one keeper with S (include) before copying."
        }
        return "Open a photo log or mark at least one source photo with S (include) before copying."
    }

    var confirmBackupButtonHelp: String {
        if needsArchiveReviewBeforeBackupConfirmation {
            return "Open the archive folder, inspect the copied photos, then confirm that they are backed up."
        }
        return "Available after copied files have been verified."
    }

    var cleanupButtonHelp: String {
        if cleanupPendingItems > 0 {
            return backupConfirmed || !cleanupRequiresBackupConfirmation
                ? "Remove copied source files from the SSD."
                : "Confirm backup before cleaning copied source files from the SSD."
        }
        return "Available after files are copied, verified, and ready for cleanup."
    }

    var idleDetail: String {
        if hasFilesToCopy {
            let rawDetail = rawCompanionFiles == 0 ? "" : " plus \(rawCompanionFiles) RAW companion file(s)"
            return "\(includedItems) S (include) photo(s)\(rawDetail) will be copied and verified before cleanup is offered."
        }
        if verifiedAwaitingBackupItems > 0 {
            return "\(verifiedAwaitingBackupItems) copied photo(s) are verified. Open the archive folder, inspect them, then confirm the backup."
        }
        if cleanupPendingItems > 0 {
            return "\(cleanupPendingItems) copied photo(s) are ready for source cleanup."
        }
        if sessionKind == .walkDraft {
            if candidateItems > 0 || excludedItems > 0 {
                return "This photo log has C/X choices but no uncopied S photos. Mark keepers with S (include); only S photos are copied."
            }
            if undecidedItems > 0 {
                return "Continue this photo log by marking keepers with S (include). The copy button turns on after at least one uncopied S photo."
            }
            return "This photo log has no uncopied photos ready. Continue the log to review its state or create another log from the source inbox."
        }
        if candidateItems > 0 || excludedItems > 0 {
            return "Only S (include) photos are copied. Change keepers to S or continue triage before copying."
        }
        return "Open an existing photo log from the library or mark source photos with S (include) to make a copy plan visible here."
    }
}

enum ImportOperationPhase: Equatable, Sendable {
    case idle
    case copying
    case completed
    case failed
}

struct ImportOperationSnapshot: Equatable, Sendable {
    let phase: ImportOperationPhase
    let title: String
    let detail: String
    let progress: ImportProgress?
    let destinationPath: String?

    static let idle = ImportOperationSnapshot(
        phase: .idle,
        title: "Copy ready",
        detail: "",
        progress: nil,
        destinationPath: nil
    )

    var isRunning: Bool {
        phase == .copying
    }
}

struct SidebarTreeSnapshot: Equatable, Sendable {
    let browserRoots: [BrowserNode]
    let selectedSidebarNodeID: String?

    static let empty = SidebarTreeSnapshot(browserRoots: [], selectedSidebarNodeID: nil)
}

struct ReviewItemSnapshot: Identifiable, Equatable, Sendable {
    let item: MediaItem
    let archivePreview: String
    let sourceLogOwnership: SourceLogOwnershipSnapshot?
    let isSelected: Bool
    let isFocused: Bool
    let thumbnailFailed: Bool

    var id: UUID { item.id }
}

struct SourceLogOwnershipSnapshot: Equatable, Sendable {
    let title: String
    let statusLabel: String
    let isCopied: Bool

    var badgeLabel: String {
        if isCopied {
            return "Copied to \(title)"
        }
        return "In Log: \(title)"
    }

    var helpText: String {
        if isCopied {
            return "This source photo was already copied into \(title)."
        }
        return "This source photo already belongs to \(title)."
    }
}

struct WorkflowGuidanceSnapshot: Equatable, Sendable {
    let title: String
    let state: String
    let detail: String
    let nextAction: String
    let systemImage: String

    static let empty = WorkflowGuidanceSnapshot(
        title: "No Source Open",
        state: "Waiting",
        detail: "No source inbox or photo log is open.",
        nextAction: "Open the default source or choose a source folder.",
        systemImage: "tray"
    )
}

struct SidebarSnapshot: Equatable, Sendable {
    var isVisible: Bool
    let sourceWorkspaceState: SourceWorkspaceState
    let sessionSummary: SessionSummary?
    let workflowGuidance: WorkflowGuidanceSnapshot
    let photoLogGroups: [PhotoLogGroupSnapshot]
    let canMutateImportSelection: Bool
    let canPresentPhotoLogCreation: Bool
    let canOpenDefaultSourceWorkspace: Bool
    let canReloadSourceWorkspace: Bool
    let isWalkDetailsExpanded: Bool
    let archiveRootDisplayPath: String
    let archiveYearFolders: [String]
    let tree: SidebarTreeSnapshot
    let hiddenPhotoLogSummary: String?
    let statusMessage: String
    let importProgress: ImportProgress?
    let importReadiness: ImportReadinessSnapshot?
    let importOperation: ImportOperationSnapshot

    static let empty = SidebarSnapshot(
        isVisible: true,
        sourceWorkspaceState: .idle,
        sessionSummary: nil,
        workflowGuidance: .empty,
        photoLogGroups: [],
        canMutateImportSelection: false,
        canPresentPhotoLogCreation: false,
        canOpenDefaultSourceWorkspace: true,
        canReloadSourceWorkspace: false,
        isWalkDetailsExpanded: true,
        archiveRootDisplayPath: "",
        archiveYearFolders: [],
        tree: .empty,
        hiddenPhotoLogSummary: nil,
        statusMessage: "Choose a source folder on the SSD to begin.",
        importProgress: nil,
        importReadiness: nil,
        importOperation: .idle
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
    let canMarkSelectionAsCandidate: Bool
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
        canMarkSelectionAsCandidate: false,
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

    var preferredScrollTargetID: UUID? {
        items.first(where: \.isFocused)?.id
            ?? items.first(where: \.isSelected)?.id
            ?? itemIDs.first
    }
}

struct PresentationSnapshot: Equatable {
    let showKeyboardHelp: Bool
    let startupAlert: AppStartupAlert?
    let previewingMediaItem: MediaItem?
    let activePhotoLogEditor: PhotoLogEditorState?
    let revealedPhotoLog: PhotoLogRevealState?

    static let empty = PresentationSnapshot(
        showKeyboardHelp: false,
        startupAlert: nil,
        previewingMediaItem: nil,
        activePhotoLogEditor: nil,
        revealedPhotoLog: nil
    )
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
