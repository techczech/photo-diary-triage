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

    var isImportedOrBeyond: Bool {
        switch self {
        case .imported, .verified, .sourceCleanupPending, .sourceCleaned:
            return true
        case .discovered, .selectedForImport:
            return false
        }
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
    var archiveRelativePath: String?
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
        archiveRelativePath: String? = nil,
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
        self.archiveRelativePath = archiveRelativePath
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
    var latitude: Double?
    var longitude: Double?

    static let empty = WalkMetadata(title: "", location: "", notes: "", backupConfirmedAt: nil)
}

enum PhotoLogScopeKind: String, Codable, CaseIterable, Hashable, Sendable {
    case folder
    case dateRange
    case custom

    var title: String {
        switch self {
        case .folder:
            return "Folder"
        case .dateRange:
            return "Date Range"
        case .custom:
            return "Custom Label"
        }
    }
}

struct PhotoLogScopeDescriptor: Codable, Hashable, Sendable {
    var kind: PhotoLogScopeKind
    var label: String
    var sourceFolderPaths: [String]
    var startDate: Date?
    var endDate: Date?

    static let empty = PhotoLogScopeDescriptor(
        kind: .folder,
        label: "",
        sourceFolderPaths: [],
        startDate: nil,
        endDate: nil
    )
}

enum PhotoLogCreationMode: String, CaseIterable, Hashable, Sendable {
    case decidedInScope
    case selectedOnly

    var title: String {
        switch self {
        case .decidedInScope:
            return "Decided In Scope"
        case .selectedOnly:
            return "Current Selection"
        }
    }
}

enum SessionKind: String, Codable, Hashable, Sendable {
    case inbox
    case walkDraft

    var title: String {
        switch self {
        case .inbox:
            return "Inbox"
        case .walkDraft:
            return "Photo Log"
        }
    }
}

enum StartupSelectionPolicy: String, Equatable, Sendable {
    case sourceInboxFirst
}

enum WorkspaceMode: String, CaseIterable, Equatable, Sendable {
    case archiveView
    case cameraTriage
    case photoLogs
    case archiveTriage

    static let displayOrder: [WorkspaceMode] = [.archiveView, .cameraTriage, .photoLogs, .archiveTriage]

    var title: String {
        switch self {
        case .archiveView:
            return "Archive View"
        case .cameraTriage:
            return "Camera Triage"
        case .photoLogs:
            return "Photo Logs"
        case .archiveTriage:
            return "Archive Triage"
        }
    }

    var systemImage: String {
        switch self {
        case .archiveView:
            return "photo.stack"
        case .cameraTriage:
            return "externaldrive.badge.checkmark"
        case .photoLogs:
            return "books.vertical"
        case .archiveTriage:
            return "archivebox"
        }
    }

    var showsArchiveLibrary: Bool {
        switch self {
        case .archiveView, .archiveTriage:
            return true
        case .cameraTriage, .photoLogs:
            return false
        }
    }

    var allowsImportSelectionMutation: Bool {
        self == .cameraTriage
    }
}

enum ArchiveMachineRole: String, Codable, CaseIterable, Hashable, Sendable {
    case mainArchive = "main_archive"
    case travel

    var title: String {
        switch self {
        case .mainArchive:
            return "Main Archive"
        case .travel:
            return "Travel"
        }
    }

    var allowsSourceCleanup: Bool {
        self == .mainArchive
    }
}

enum SourceLoadOrigin: String, Equatable, Sendable {
    case launchDefault
    case mountedDefault
    case manualPicker
    case savedWalkInbox
    case openDefaultSource
    case settingsDefaultRoot
    case reloadCurrentSource
}

enum SourceWorkspaceState: Equatable, Sendable {
    case idle
    case loading(sourcePath: String)
    case loaded(itemCount: Int, sourcePath: String)
    case empty(sourcePath: String)
    case failed(sourcePath: String, message: String)

    var sourcePath: String? {
        switch self {
        case .idle:
            return nil
        case .loading(let sourcePath),
             .loaded(_, let sourcePath),
             .empty(let sourcePath),
             .failed(let sourcePath, _):
            return sourcePath
        }
    }

    var summary: String {
        switch self {
        case .idle:
            return "No live source inbox is open."
        case .loading(let sourcePath):
            return "Loading source inbox from \(sourcePath)."
        case .loaded(let itemCount, let sourcePath):
            return "Loaded \(itemCount) visible item(s) from \(sourcePath)."
        case .empty(let sourcePath):
            return "No supported media were found in \(sourcePath)."
        case .failed(let sourcePath, let message):
            return "Failed to load \(sourcePath): \(message)"
        }
    }
}

enum ImportVerificationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case sizeOnly
    case checksum

    var title: String {
        switch self {
        case .sizeOnly:
            return "Size Only"
        case .checksum:
            return "SHA-256 Checksum"
        }
    }

    var detail: String {
        switch self {
        case .sizeOnly:
            return "Fast copy checks compare source and destination file sizes."
        case .checksum:
            return "Stronger checks compare SHA-256 hashes after copy."
        }
    }
}

struct AppSettings: Codable, Hashable, Sendable {
    var defaultSourceRoot: URL
    var archiveRoot: URL
    var oneDrivePicturesRoot: URL
    var archiveMachineRole: ArchiveMachineRole
    var cacheRoot: URL
    var supportedExtensions: Set<String>
    var burstThresholdSeconds: TimeInterval
    var proximityThresholdSeconds: TimeInterval
    var cleanupRequiresBackupConfirmation: Bool
    var verificationMode: ImportVerificationMode
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
            oneDrivePicturesRoot: archiveRoot,
            archiveMachineRole: .mainArchive,
            cacheRoot: cacheRoot,
            supportedExtensions: ["jpg", "jpeg", "png", "heic", "tif", "tiff", "dng", "raf", "cr2", "cr3", "nef"],
            burstThresholdSeconds: 2,
            proximityThresholdSeconds: 600,
            cleanupRequiresBackupConfirmation: true,
            verificationMode: .sizeOnly,
            reviewPresentationMode: .grid,
            reviewGridColumnCount: ReviewGridMetrics.defaultRequestedColumnCount()
        )
    }

    var archiveRootDisplayPath: String {
        archiveRoot.path
    }

    var oneDrivePicturesRootDisplayPath: String {
        oneDrivePicturesRoot.path
    }

    var defaultSourceRootDisplayPath: String {
        defaultSourceRoot.path
    }

    init(
        defaultSourceRoot: URL,
        archiveRoot: URL,
        oneDrivePicturesRoot: URL? = nil,
        archiveMachineRole: ArchiveMachineRole = .mainArchive,
        cacheRoot: URL,
        supportedExtensions: Set<String>,
        burstThresholdSeconds: TimeInterval,
        proximityThresholdSeconds: TimeInterval,
        cleanupRequiresBackupConfirmation: Bool,
        verificationMode: ImportVerificationMode = .sizeOnly,
        reviewPresentationMode: ReviewPresentationMode,
        reviewGridColumnCount: Int
    ) {
        self.defaultSourceRoot = defaultSourceRoot
        self.archiveRoot = archiveRoot
        self.oneDrivePicturesRoot = oneDrivePicturesRoot ?? archiveRoot
        self.archiveMachineRole = archiveMachineRole
        self.cacheRoot = cacheRoot
        self.supportedExtensions = supportedExtensions
        self.burstThresholdSeconds = burstThresholdSeconds
        self.proximityThresholdSeconds = proximityThresholdSeconds
        self.cleanupRequiresBackupConfirmation = cleanupRequiresBackupConfirmation
        self.verificationMode = verificationMode
        self.reviewPresentationMode = reviewPresentationMode
        self.reviewGridColumnCount = reviewGridColumnCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let defaults = AppSettings.default()
        defaultSourceRoot = try container.decodeIfPresent(URL.self, forKey: .defaultSourceRoot) ?? defaults.defaultSourceRoot
        archiveRoot = try container.decodeIfPresent(URL.self, forKey: .archiveRoot) ?? defaults.archiveRoot
        oneDrivePicturesRoot = try container.decodeIfPresent(URL.self, forKey: .oneDrivePicturesRoot) ?? archiveRoot
        archiveMachineRole = try container.decodeIfPresent(ArchiveMachineRole.self, forKey: .archiveMachineRole) ?? defaults.archiveMachineRole
        cacheRoot = try container.decodeIfPresent(URL.self, forKey: .cacheRoot) ?? defaults.cacheRoot
        supportedExtensions = try container.decodeIfPresent(Set<String>.self, forKey: .supportedExtensions) ?? defaults.supportedExtensions
        burstThresholdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .burstThresholdSeconds) ?? defaults.burstThresholdSeconds
        proximityThresholdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .proximityThresholdSeconds) ?? defaults.proximityThresholdSeconds
        cleanupRequiresBackupConfirmation = try container.decodeIfPresent(Bool.self, forKey: .cleanupRequiresBackupConfirmation) ?? defaults.cleanupRequiresBackupConfirmation
        verificationMode = try container.decodeIfPresent(ImportVerificationMode.self, forKey: .verificationMode) ?? defaults.verificationMode
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
        try container.encode(oneDrivePicturesRoot, forKey: .oneDrivePicturesRoot)
        try container.encode(archiveMachineRole, forKey: .archiveMachineRole)
        try container.encode(cacheRoot, forKey: .cacheRoot)
        try container.encode(supportedExtensions, forKey: .supportedExtensions)
        try container.encode(burstThresholdSeconds, forKey: .burstThresholdSeconds)
        try container.encode(proximityThresholdSeconds, forKey: .proximityThresholdSeconds)
        try container.encode(cleanupRequiresBackupConfirmation, forKey: .cleanupRequiresBackupConfirmation)
        try container.encode(verificationMode, forKey: .verificationMode)
        try container.encode(reviewPresentationMode, forKey: .reviewPresentationMode)
        try container.encode(reviewGridColumnCount, forKey: .reviewGridColumnCount)
    }

    private enum CodingKeys: String, CodingKey {
        case defaultSourceRoot
        case archiveRoot
        case oneDrivePicturesRoot
        case archiveMachineRole
        case cacheRoot
        case supportedExtensions
        case burstThresholdSeconds
        case proximityThresholdSeconds
        case cleanupRequiresBackupConfirmation
        case verificationMode
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
    var photoLogScope: PhotoLogScopeDescriptor?
    var archiveRoot: URL
    var oneDrivePicturesRoot: URL
    var archiveMachineRole: ArchiveMachineRole
    var sessionKind: SessionKind
    var sessionKindWasExplicit: Bool
    var status: String
    var mediaItems: [MediaItem]

    init(
        id: UUID = UUID(),
        sourceFolder: URL,
        workspaceSourceFolder: URL? = nil,
        startedAt: Date = Date(),
        lastUpdatedAt: Date = Date(),
        walkMetadata: WalkMetadata = .empty,
        photoLogScope: PhotoLogScopeDescriptor? = nil,
        archiveRoot: URL,
        oneDrivePicturesRoot: URL? = nil,
        archiveMachineRole: ArchiveMachineRole = .mainArchive,
        sessionKind: SessionKind = .walkDraft,
        sessionKindWasExplicit: Bool = true,
        status: String = "draft",
        mediaItems: [MediaItem] = []
    ) {
        self.id = id
        self.sourceFolder = sourceFolder
        self.workspaceSourceFolder = workspaceSourceFolder ?? sourceFolder
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.walkMetadata = walkMetadata
        self.photoLogScope = photoLogScope
        self.archiveRoot = archiveRoot
        self.oneDrivePicturesRoot = oneDrivePicturesRoot ?? archiveRoot
        self.archiveMachineRole = archiveMachineRole
        self.sessionKind = sessionKind
        self.sessionKindWasExplicit = sessionKindWasExplicit
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
        case photoLogScope
        case archiveRoot
        case oneDrivePicturesRoot
        case archiveMachineRole
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
        photoLogScope = try container.decodeIfPresent(PhotoLogScopeDescriptor.self, forKey: .photoLogScope)
        archiveRoot = try container.decode(URL.self, forKey: .archiveRoot)
        oneDrivePicturesRoot = try container.decodeIfPresent(URL.self, forKey: .oneDrivePicturesRoot) ?? archiveRoot
        archiveMachineRole = try container.decodeIfPresent(ArchiveMachineRole.self, forKey: .archiveMachineRole) ?? .mainArchive
        sessionKindWasExplicit = container.contains(.sessionKind)
        sessionKind = try container.decodeIfPresent(SessionKind.self, forKey: .sessionKind) ?? .inbox
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
        try container.encodeIfPresent(photoLogScope, forKey: .photoLogScope)
        try container.encode(archiveRoot, forKey: .archiveRoot)
        try container.encode(oneDrivePicturesRoot, forKey: .oneDrivePicturesRoot)
        try container.encode(archiveMachineRole, forKey: .archiveMachineRole)
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

enum CropRelationshipRole: String, Codable, Hashable, Sendable {
    case original
    case crop
}

struct CropRelationship: Codable, Hashable, Sendable {
    var role: CropRelationshipRole
    var originalRelativePath: String
    var originalFileName: String
    var cropRelativePaths: [String]
    var cropFileNames: [String]
    var manifestRelativePath: String?
    var latestCropRelativePath: String?
    var latestCropFileName: String?

    var isCrop: Bool {
        role == .crop
    }

    var hasCrops: Bool {
        !cropRelativePaths.isEmpty
    }

    var linkedPreviewRelativePath: String? {
        switch role {
        case .original:
            return latestCropRelativePath
        case .crop:
            return originalRelativePath
        }
    }

    var badgeLabel: String {
        switch role {
        case .original:
            return cropRelativePaths.count == 1 ? "Has Crop" : "Has \(cropRelativePaths.count) Crops"
        case .crop:
            return "Crop"
        }
    }

    var linkActionLabel: String {
        switch role {
        case .original:
            return cropRelativePaths.count == 1 ? "Show Crop" : "Show Latest Crop"
        case .crop:
            return "Show Original"
        }
    }

    var helpText: String {
        switch role {
        case .original:
            return latestCropFileName.map { "This original has crop output \($0). Click to preview the latest crop." }
                ?? "This original has crop outputs. Click to preview a crop."
        case .crop:
            return "This is a crop of \(originalFileName). Click to preview the original."
        }
    }
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
    var archiveRelativePath: String?
    var importedAt: Date?
    var verifiedAt: Date?
    var sourceCleanedAt: Date?
    var cropRelationship: CropRelationship?
    var fileLocality: FileLocality?

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
        archiveRelativePath: String? = nil,
        importedAt: Date? = nil,
        verifiedAt: Date? = nil,
        sourceCleanedAt: Date? = nil,
        cropRelationship: CropRelationship? = nil,
        fileLocality: FileLocality? = nil
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
        self.archiveRelativePath = archiveRelativePath
        self.importedAt = importedAt
        self.verifiedAt = verifiedAt
        self.sourceCleanedAt = sourceCleanedAt
        self.cropRelationship = cropRelationship
        self.fileLocality = fileLocality
    }
}

extension MediaItem {
    var resolvedFileLocality: FileLocality {
        fileLocality ?? .unknown
    }

    var isSourceOnlineOnly: Bool {
        resolvedFileLocality.isOnlineOnly
    }

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

    var cropSortFamilyKey: String {
        cropRelationship?.originalRelativePath.lowercased() ?? relativePath.lowercased()
    }

    var cropSortPriority: Int {
        if cropRelationship?.role == .original {
            return 0
        }
        if cropRelationship?.role == .crop {
            if let index = cropRelationship?.cropRelativePaths.firstIndex(of: relativePath) {
                return index + 1
            }
            return 1
        }
        return 0
    }
}

enum MediaItemSort {
    static func sorted(_ items: [MediaItem]) -> [MediaItem] {
        let familyDates = familyDateMap(for: items)
        return items.sorted { lhs, rhs in
            areInIncreasingOrder(lhs, rhs, familyDates: familyDates)
        }
    }

    static func areInIncreasingOrder(_ lhs: MediaItem, _ rhs: MediaItem) -> Bool {
        let familyDates = familyDateMap(for: [lhs, rhs])
        return areInIncreasingOrder(lhs, rhs, familyDates: familyDates)
    }

    static func familyDateMap(for items: [MediaItem]) -> [String: Date] {
        let grouped = Dictionary(grouping: items, by: \.cropSortFamilyKey)
        return grouped.reduce(into: [String: Date]()) { result, entry in
            if let date = entry.value.first(where: { $0.cropRelationship?.role == .original })?.capturedAt
                ?? entry.value.compactMap(\.capturedAt).min() {
                result[entry.key] = date
            }
        }
    }

    static func familyDate(for item: MediaItem, familyDates: [String: Date]) -> Date? {
        familyDates[item.cropSortFamilyKey] ?? item.capturedAt
    }

    private static func areInIncreasingOrder(
        _ lhs: MediaItem,
        _ rhs: MediaItem,
        familyDates: [String: Date]
    ) -> Bool {
        let lhsDate = familyDates[lhs.cropSortFamilyKey] ?? lhs.capturedAt ?? .distantPast
        let rhsDate = familyDates[rhs.cropSortFamilyKey] ?? rhs.capturedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        if lhs.cropSortFamilyKey == rhs.cropSortFamilyKey,
           lhs.cropSortPriority != rhs.cropSortPriority {
            return lhs.cropSortPriority < rhs.cropSortPriority
        }

        let familyComparison = lhs.cropSortFamilyKey.localizedCaseInsensitiveCompare(rhs.cropSortFamilyKey)
        if familyComparison != .orderedSame {
            return familyComparison == .orderedAscending
        }
        return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
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
    var archiveFolderRelativePath: String?
    var title: String
    var location: String
    var notes: String
    var summary: Summary
    var importedFiles: [FileManifest]
    var excludedFiles: [RejectedFileManifest] = []

    init(
        sessionID: UUID,
        walkDate: Date?,
        sourceFolder: URL,
        archiveFolder: URL,
        archiveFolderRelativePath: String? = nil,
        title: String,
        location: String,
        notes: String,
        summary: Summary,
        importedFiles: [FileManifest],
        excludedFiles: [RejectedFileManifest] = []
    ) {
        self.sessionID = sessionID
        self.walkDate = walkDate
        self.sourceFolder = sourceFolder
        self.archiveFolder = archiveFolder
        self.archiveFolderRelativePath = archiveFolderRelativePath
        self.title = title
        self.location = location
        self.notes = notes
        self.summary = summary
        self.importedFiles = importedFiles
        self.excludedFiles = excludedFiles
    }
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
    var archiveRelativePath: String?
    var thumbnailCacheKey: String?
    var sourceFileName: String
    var companionArchivePaths: [String]
    var companionArchiveRelativePaths: [String]
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

    init(
        mediaItemID: UUID,
        archivePath: String,
        archiveRelativePath: String? = nil,
        thumbnailCacheKey: String? = nil,
        sourceFileName: String,
        companionArchivePaths: [String],
        companionArchiveRelativePaths: [String] = [],
        capturedAt: Date?,
        cameraModel: String?,
        lensModel: String?,
        pixelWidth: Int?,
        pixelHeight: Int?,
        latitude: Double?,
        longitude: Double?,
        walkTitle: String,
        walkLocation: String,
        notes: String
    ) {
        self.mediaItemID = mediaItemID
        self.archivePath = archivePath
        self.archiveRelativePath = archiveRelativePath
        self.thumbnailCacheKey = thumbnailCacheKey
        self.sourceFileName = sourceFileName
        self.companionArchivePaths = companionArchivePaths
        self.companionArchiveRelativePaths = companionArchiveRelativePaths
        self.capturedAt = capturedAt
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.latitude = latitude
        self.longitude = longitude
        self.walkTitle = walkTitle
        self.walkLocation = walkLocation
        self.notes = notes
    }
}

struct SessionLogEvent: Codable, Hashable, Sendable {
    var timestamp: Date
    var event: String
    var mediaItemID: UUID?
    var details: [String: String]
}
