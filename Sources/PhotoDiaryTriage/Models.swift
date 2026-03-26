import Foundation

enum LifecycleState: String, Codable, CaseIterable, Sendable {
    case discovered
    case selectedForImport = "selected_for_import"
    case imported
    case verified
    case sourceCleanupPending = "source_cleanup_pending"
    case sourceCleaned = "source_cleaned"

    func canTransition(to newState: LifecycleState) -> Bool {
        if self == newState {
            return true
        }

        switch (self, newState) {
        case (.discovered, .selectedForImport),
             (.selectedForImport, .discovered),
             (.selectedForImport, .imported),
             (.imported, .verified),
             (.verified, .sourceCleanupPending),
             (.sourceCleanupPending, .sourceCleaned):
            return true
        default:
            return false
        }
    }

    func transition(to newState: LifecycleState) throws -> LifecycleState {
        guard canTransition(to: newState) else {
            throw LifecycleTransitionError.invalidTransition(from: self, to: newState)
        }
        return newState
    }
}

enum LifecycleTransitionError: LocalizedError, Sendable {
    case invalidTransition(from: LifecycleState, to: LifecycleState)

    var errorDescription: String? {
        switch self {
        case let .invalidTransition(from, to):
            return "Invalid lifecycle transition from \(from.rawValue) to \(to.rawValue)."
        }
    }
}

enum SelectionState: String, Codable, CaseIterable, Sendable {
    case undecided
    case candidate
    case included
    case excluded

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "selected", "included":
            self = .included
        case "candidate":
            self = .candidate
        case "skipped", "undecided":
            self = .undecided
        case "excluded":
            self = .excluded
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown selection state: \(rawValue)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var isIncluded: Bool {
        self == .included
    }

    var isCandidate: Bool {
        self == .candidate
    }

    var isExcluded: Bool {
        self == .excluded
    }

    var isUndecided: Bool {
        self == .undecided
    }

    var statusLabel: String {
        switch self {
        case .undecided:
            return "Undecided"
        case .candidate:
            return "Candidate"
        case .included:
            return "Included"
        case .excluded:
            return "Excluded"
        }
    }
}

enum MediaKind: String, Codable, CaseIterable, Sendable {
    case jpeg
    case raw
    case other
}

struct CompanionFile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sourceURL: URL
    var relativePath: String
    var fileName: String
    var fileSizeBytes: Int64
    var kind: MediaKind
    var destinationURL: URL?
    var importedAt: Date?
    var verifiedAt: Date?
    var sourceCleanedAt: Date?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        relativePath: String,
        fileName: String,
        fileSizeBytes: Int64,
        kind: MediaKind,
        destinationURL: URL? = nil,
        importedAt: Date? = nil,
        verifiedAt: Date? = nil,
        sourceCleanedAt: Date? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.relativePath = relativePath
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.kind = kind
        self.destinationURL = destinationURL
        self.importedAt = importedAt
        self.verifiedAt = verifiedAt
        self.sourceCleanedAt = sourceCleanedAt
    }
}

struct WalkMetadata: Codable, Hashable, Sendable {
    var title: String
    var location: String
    var notes: String
    var backupConfirmedAt: Date?

    static let empty = WalkMetadata(title: "", location: "", notes: "", backupConfirmedAt: nil)
}

enum SessionKind: String, Codable, Hashable, Sendable {
    case inbox
    case walkDraft

    var title: String {
        switch self {
        case .inbox:
            return "Inbox"
        case .walkDraft:
            return "Walk Draft"
        }
    }
}

struct AppSettings: Codable, Hashable, Sendable {
    var defaultSourceRoot: URL
    var archiveRoot: URL
    var cacheRoot: URL
    var supportedExtensions: Set<String>
    var burstThresholdSeconds: TimeInterval
    var proximityThresholdSeconds: TimeInterval
    var cleanupRequiresBackupConfirmation: Bool
    var reviewPresentationMode: ReviewPresentationMode
    var reviewGridColumnCount: Int

    static func `default`(fileManager: FileManager = .default) -> AppSettings {
        let libraryRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let supportRoot = libraryRoot.appendingPathComponent("PhotoDiaryTriage", isDirectory: true)
        let defaultSourceRoot = URL(fileURLWithPath: "/Volumes/EOS_DIGITAL/", isDirectory: true)
        let archiveRoot = URL(fileURLWithPath: "/Users/dominiklukes/Library/CloudStorage/OneDrive-Personal/Pictures/", isDirectory: true)
        let cacheRoot = supportRoot.appendingPathComponent("Cache", isDirectory: true)

        return AppSettings(
            defaultSourceRoot: defaultSourceRoot,
            archiveRoot: archiveRoot,
            cacheRoot: cacheRoot,
            supportedExtensions: ["jpg", "jpeg", "png", "heic", "tif", "tiff", "dng", "raf", "cr2", "cr3", "nef"],
            burstThresholdSeconds: 2,
            proximityThresholdSeconds: 600,
            cleanupRequiresBackupConfirmation: true,
            reviewPresentationMode: .grid,
            reviewGridColumnCount: ReviewGridMetrics.defaultRequestedColumnCount()
        )
    }

    var archiveRootDisplayPath: String {
        archiveRoot.path
    }

    var defaultSourceRootDisplayPath: String {
        defaultSourceRoot.path
    }

    init(
        defaultSourceRoot: URL,
        archiveRoot: URL,
        cacheRoot: URL,
        supportedExtensions: Set<String>,
        burstThresholdSeconds: TimeInterval,
        proximityThresholdSeconds: TimeInterval,
        cleanupRequiresBackupConfirmation: Bool,
        reviewPresentationMode: ReviewPresentationMode,
        reviewGridColumnCount: Int
    ) {
        self.defaultSourceRoot = defaultSourceRoot
        self.archiveRoot = archiveRoot
        self.cacheRoot = cacheRoot
        self.supportedExtensions = supportedExtensions
        self.burstThresholdSeconds = burstThresholdSeconds
        self.proximityThresholdSeconds = proximityThresholdSeconds
        self.cleanupRequiresBackupConfirmation = cleanupRequiresBackupConfirmation
        self.reviewPresentationMode = reviewPresentationMode
        self.reviewGridColumnCount = reviewGridColumnCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let defaults = AppSettings.default()
        defaultSourceRoot = try container.decodeIfPresent(URL.self, forKey: .defaultSourceRoot) ?? defaults.defaultSourceRoot
        archiveRoot = try container.decodeIfPresent(URL.self, forKey: .archiveRoot) ?? defaults.archiveRoot
        cacheRoot = try container.decodeIfPresent(URL.self, forKey: .cacheRoot) ?? defaults.cacheRoot
        supportedExtensions = try container.decodeIfPresent(Set<String>.self, forKey: .supportedExtensions) ?? defaults.supportedExtensions
        burstThresholdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .burstThresholdSeconds) ?? defaults.burstThresholdSeconds
        proximityThresholdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .proximityThresholdSeconds) ?? defaults.proximityThresholdSeconds
        cleanupRequiresBackupConfirmation = try container.decodeIfPresent(Bool.self, forKey: .cleanupRequiresBackupConfirmation) ?? defaults.cleanupRequiresBackupConfirmation
        reviewPresentationMode = try container.decodeIfPresent(ReviewPresentationMode.self, forKey: .reviewPresentationMode) ?? defaults.reviewPresentationMode
        if let storedColumns = try container.decodeIfPresent(Int.self, forKey: .reviewGridColumnCount) {
            reviewGridColumnCount = min(max(storedColumns, 1), ReviewGridMetrics.maxSuggestedColumns)
        } else if let legacyWidth = try legacyContainer.decodeIfPresent(Double.self, forKey: .reviewGridCardWidth) {
            reviewGridColumnCount = ReviewGridMetrics.columnCount(forLegacyCardWidth: legacyWidth)
        } else {
            reviewGridColumnCount = defaults.reviewGridColumnCount
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultSourceRoot, forKey: .defaultSourceRoot)
        try container.encode(archiveRoot, forKey: .archiveRoot)
        try container.encode(cacheRoot, forKey: .cacheRoot)
        try container.encode(supportedExtensions, forKey: .supportedExtensions)
        try container.encode(burstThresholdSeconds, forKey: .burstThresholdSeconds)
        try container.encode(proximityThresholdSeconds, forKey: .proximityThresholdSeconds)
        try container.encode(cleanupRequiresBackupConfirmation, forKey: .cleanupRequiresBackupConfirmation)
        try container.encode(reviewPresentationMode, forKey: .reviewPresentationMode)
        try container.encode(reviewGridColumnCount, forKey: .reviewGridColumnCount)
    }

    private enum CodingKeys: String, CodingKey {
        case defaultSourceRoot
        case archiveRoot
        case cacheRoot
        case supportedExtensions
        case burstThresholdSeconds
        case proximityThresholdSeconds
        case cleanupRequiresBackupConfirmation
        case reviewPresentationMode
        case reviewGridColumnCount
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case reviewGridCardWidth
    }
}

struct ImportSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sourceFolder: URL
    var workspaceSourceFolder: URL
    var startedAt: Date
    var lastUpdatedAt: Date
    var walkMetadata: WalkMetadata
    var archiveRoot: URL
    var sessionKind: SessionKind
    var status: String
    var mediaItems: [MediaItem]

    init(
        id: UUID = UUID(),
        sourceFolder: URL,
        workspaceSourceFolder: URL? = nil,
        startedAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        walkMetadata: WalkMetadata = .empty,
        archiveRoot: URL,
        sessionKind: SessionKind = .walkDraft,
        status: String = "draft",
        mediaItems: [MediaItem] = []
    ) {
        self.id = id
        self.sourceFolder = sourceFolder
        self.workspaceSourceFolder = workspaceSourceFolder ?? sourceFolder
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.walkMetadata = walkMetadata
        self.archiveRoot = archiveRoot
        self.sessionKind = sessionKind
        self.status = status
        self.mediaItems = mediaItems
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceFolder
        case workspaceSourceFolder
        case startedAt
        case lastUpdatedAt
        case walkMetadata
        case archiveRoot
        case sessionKind
        case status
        case mediaItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceFolder = try container.decode(URL.self, forKey: .sourceFolder)
        workspaceSourceFolder = try container.decodeIfPresent(URL.self, forKey: .workspaceSourceFolder) ?? sourceFolder
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        lastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .lastUpdatedAt) ?? startedAt
        walkMetadata = try container.decodeIfPresent(WalkMetadata.self, forKey: .walkMetadata) ?? .empty
        archiveRoot = try container.decode(URL.self, forKey: .archiveRoot)
        sessionKind = try container.decodeIfPresent(SessionKind.self, forKey: .sessionKind) ?? .walkDraft
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "draft"
        mediaItems = try container.decodeIfPresent([MediaItem].self, forKey: .mediaItems) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceFolder, forKey: .sourceFolder)
        try container.encode(workspaceSourceFolder, forKey: .workspaceSourceFolder)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(walkMetadata, forKey: .walkMetadata)
        try container.encode(archiveRoot, forKey: .archiveRoot)
        try container.encode(sessionKind, forKey: .sessionKind)
        try container.encode(status, forKey: .status)
        try container.encode(mediaItems, forKey: .mediaItems)
    }
}

struct MediaMetadata: Codable, Hashable, Sendable {
    var capturedAt: Date?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var cameraModel: String?
    var lensModel: String?
    var latitude: Double?
    var longitude: Double?
    var raw: [String: String]
}

struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var sourceURL: URL
    var relativePath: String
    var fileName: String
    var baseName: String
    var mediaKind: MediaKind
    var fileSizeBytes: Int64
    var capturedAt: Date?
    var metadata: MediaMetadata
    var thumbnailCacheKey: String
    var selectionState: SelectionState
    var importRawCompanions: Bool
    var companionFiles: [CompanionFile]
    var lifecycleState: LifecycleState
    var burstGroupID: UUID?
    var timeClusterID: UUID?
    var destinationURL: URL?
    var importedAt: Date?
    var verifiedAt: Date?
    var sourceCleanedAt: Date?

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        relativePath: String,
        fileName: String,
        baseName: String,
        mediaKind: MediaKind,
        fileSizeBytes: Int64,
        capturedAt: Date?,
        metadata: MediaMetadata,
        thumbnailCacheKey: String,
        selectionState: SelectionState = .undecided,
        importRawCompanions: Bool = false,
        companionFiles: [CompanionFile] = [],
        lifecycleState: LifecycleState = .discovered,
        burstGroupID: UUID? = nil,
        timeClusterID: UUID? = nil,
        destinationURL: URL? = nil,
        importedAt: Date? = nil,
        verifiedAt: Date? = nil,
        sourceCleanedAt: Date? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.relativePath = relativePath
        self.fileName = fileName
        self.baseName = baseName
        self.mediaKind = mediaKind
        self.fileSizeBytes = fileSizeBytes
        self.capturedAt = capturedAt
        self.metadata = metadata
        self.thumbnailCacheKey = thumbnailCacheKey
        self.selectionState = selectionState
        self.importRawCompanions = importRawCompanions
        self.companionFiles = companionFiles
        self.lifecycleState = lifecycleState
        self.burstGroupID = burstGroupID
        self.timeClusterID = timeClusterID
        self.destinationURL = destinationURL
        self.importedAt = importedAt
        self.verifiedAt = verifiedAt
        self.sourceCleanedAt = sourceCleanedAt
    }
}

extension MediaItem {
    var displayAspectRatio: Double {
        if let pixelWidth = metadata.pixelWidth,
           let pixelHeight = metadata.pixelHeight,
           pixelWidth > 0,
           pixelHeight > 0 {
            return Double(pixelWidth) / Double(pixelHeight)
        }

        return 4.0 / 3.0
    }

    var compactDisplayName: String {
        let stem = baseName
        if let trailingDigits = stem.range(of: #"\d+$"#, options: .regularExpression) {
            return String(stem[trailingDigits])
        }

        let components = stem.split(separator: "_")
        if let last = components.last, !last.isEmpty {
            return String(last)
        }

        return stem
    }

    var compactCapturedAtLabel: String? {
        guard let capturedAt else { return nil }
        return DateFormatting.reviewCardTimestamp.string(from: capturedAt)
    }
}

struct BurstGroup: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var mediaItemIDs: [UUID]
    var startedAt: Date?
    var endedAt: Date?
}

struct TimeCluster: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var mediaItemIDs: [UUID]
    var startedAt: Date?
    var endedAt: Date?
}

struct ArchiveEntry: Codable, Hashable, Sendable {
    var mediaItemID: UUID
    var companionFileID: UUID?
    var sourceURL: URL
    var destinationURL: URL
    var isCompanion: Bool
}

struct ArchiveCommitPlan: Codable, Hashable, Sendable {
    var archiveFolder: URL
    var entries: [ArchiveEntry]
    var totalSourceFiles: Int
    var selectedCount: Int
    var skippedCount: Int
}

struct WalkManifest: Codable, Hashable, Sendable {
    struct Summary: Codable, Hashable, Sendable {
        var totalSourceFiles: Int
        var visibleItems: Int
        var importedFiles: Int
        var excludedFiles: Int = 0
        var candidateFiles: Int = 0
        var undecidedFiles: Int = 0
        var skippedFiles: Int
        var cleanupPendingFiles: Int
        var cleanedSourceFiles: Int
    }

    var sessionID: UUID
    var walkDate: Date?
    var sourceFolder: URL
    var archiveFolder: URL
    var title: String
    var location: String
    var notes: String
    var summary: Summary
    var importedFiles: [FileManifest]
    var excludedFiles: [RejectedFileManifest] = []
}

struct RejectedFileManifest: Codable, Hashable, Sendable {
    var mediaItemID: UUID
    var sourceFileName: String
    var relativePath: String
    var reason: String
}

struct FileManifest: Codable, Hashable, Sendable {
    var mediaItemID: UUID
    var archivePath: String
    var sourceFileName: String
    var companionArchivePaths: [String]
    var capturedAt: Date?
    var cameraModel: String?
    var lensModel: String?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var latitude: Double?
    var longitude: Double?
    var walkTitle: String
    var walkLocation: String
    var notes: String
}

struct SessionLogEvent: Codable, Hashable, Sendable {
    var timestamp: Date
    var event: String
    var mediaItemID: UUID?
    var details: [String: String]
}
