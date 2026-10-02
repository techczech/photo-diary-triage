import AppKit
import FileProvider
import Foundation
import ImageIO
import QuickLookThumbnailing
import UniformTypeIdentifiers

enum ArchiveIndexEntryKind: String, Codable, Sendable {
    case photo
    case walk
    case trip
    case unorganisedFolder
}

struct ArchiveIndexEntry: Codable, Hashable, Sendable {
    var kind: ArchiveIndexEntryKind
    var year: String
    var archiveRelativePath: String
    var date: String?
    var title: String
    var location: String?
    var exifSummary: String?
    var aiDescription: String?
    var notes: String?
    var thumbnailPath: String?
    var walkPath: String?
    var tripPath: String?
    var latitude: Double?
    var longitude: Double?
    var folderPath: String?
    var endDate: String?
    var photoCount: Int?
    var mediaItemID: UUID?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var cameraModel: String?
    var lensModel: String?
    var fileSizeBytes: Int64?
    var companionPaths: [String]?
    var cropRelationship: CropRelationship?
    var coordinateSource: ArchiveCoordinateSource?
    var isDerivedPhoto: Bool?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var locationOverride: PhotoLocationOverride?
    var sessionID: UUID?
    var walkID: UUID?

    init(
        kind: ArchiveIndexEntryKind,
        year: String,
        archiveRelativePath: String,
        date: String?,
        title: String,
        location: String?,
        exifSummary: String?,
        aiDescription: String?,
        notes: String? = nil,
        thumbnailPath: String?,
        walkPath: String?,
        tripPath: String?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        folderPath: String? = nil,
        endDate: String? = nil,
        photoCount: Int? = nil,
        mediaItemID: UUID? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        fileSizeBytes: Int64? = nil,
        companionPaths: [String]? = nil,
        cropRelationship: CropRelationship? = nil,
        coordinateSource: ArchiveCoordinateSource? = nil,
        isDerivedPhoto: Bool? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil,
        locationOverride: PhotoLocationOverride? = nil,
        sessionID: UUID? = nil,
        walkID: UUID? = nil
    ) {
        self.kind = kind
        self.year = year
        self.archiveRelativePath = archiveRelativePath
        self.date = date
        self.title = title
        self.location = location
        self.exifSummary = exifSummary
        self.aiDescription = aiDescription
        self.notes = notes
        self.thumbnailPath = thumbnailPath
        self.walkPath = walkPath
        self.tripPath = tripPath
        self.latitude = latitude
        self.longitude = longitude
        self.folderPath = folderPath
        self.endDate = endDate
        self.photoCount = photoCount
        self.mediaItemID = mediaItemID
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.fileSizeBytes = fileSizeBytes
        self.companionPaths = companionPaths
        self.cropRelationship = cropRelationship
        self.coordinateSource = coordinateSource
        self.isDerivedPhoto = isDerivedPhoto
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
        self.locationOverride = locationOverride
        self.sessionID = sessionID
        self.walkID = walkID
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case year
        case archiveRelativePath = "archive_relative_path"
        case date
        case title
        case location
        case exifSummary = "exif_summary"
        case aiDescription = "ai_description"
        case notes
        case thumbnailPath = "thumbnail_path"
        case walkPath = "walk_path"
        case tripPath = "trip_path"
        case latitude
        case longitude
        case folderPath = "folder_path"
        case endDate = "end_date"
        case photoCount = "photo_count"
        case mediaItemID = "media_item_id"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case cameraModel = "camera_model"
        case lensModel = "lens_model"
        case fileSizeBytes = "file_size_bytes"
        case companionPaths = "companion_paths"
        case cropRelationship = "crop_relationship"
        case coordinateSource = "coordinate_source"
        case isDerivedPhoto = "is_derived_photo"
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
        case locationOverride = "location_override"
        case sessionID = "session_id"
        case walkID = "walk_id"
    }
}

struct ArchiveIndexThumbnailResult: Sendable {
    var scannedPhotos: Int
    var generatedThumbnails: Int
    var existingThumbnails: Int
    var failures: [String]
    var evictedFiles: Int
    var stoppedForLowSpace: Bool
    var cancelled: Bool
}

struct ArchiveThumbnailBackfillSafety: Sendable {
    static let defaultMinimumFreeBytes: Int64 = 15 * 1_024 * 1_024 * 1_024

    var minimumFreeBytes: Int64 = defaultMinimumFreeBytes

    func hasSafeCapacity(_ availableBytes: Int64?) -> Bool {
        guard let availableBytes else { return false }
        return availableBytes >= minimumFreeBytes
    }

    func shouldEvict(wasOnlineOnly: Bool, hydrationAttempted: Bool) -> Bool {
        wasOnlineOnly && hydrationAttempted
    }
}

struct ArchiveIndexRebuildResult: Sendable {
    var entryCount: Int
    var years: [String]
}

struct ArchiveIndexWritePolicy: Sendable {
    var machineRole: ArchiveMachineRole

    var canWriteIndex: Bool {
        machineRole == .mainArchive
    }

    var disabledHelp: String {
        "Archive Index writes run only on the Main Archive machine. Travel mode keeps manifests writable but leaves _index read-only."
    }
}

struct ArchiveByteReadPolicy: Sendable {
    var archiveRoot: URL
    var machineRole: ArchiveMachineRole
    private var resolvedArchiveRootPath: String

    init(archiveRoot: URL, machineRole: ArchiveMachineRole) {
        self.archiveRoot = archiveRoot.standardizedFileURL
        self.machineRole = machineRole
        resolvedArchiveRootPath = archiveRoot.resolvingSymlinksInPath().standardizedFileURL.path
    }

    func canReadBytes(at url: URL, explicitDownload: Bool = false) -> Bool {
        guard !escapesArchive(url) else { return false }
        guard machineRole == .travel, explicitDownload == false else { return true }
        return !isOriginalArchiveFile(url)
    }

    func isOriginalArchiveFile(_ url: URL) -> Bool {
        guard isInsideArchive(url) else { return false }
        let relative = ArchiveIndexStore.archiveRelativePath(for: url, archiveRoot: archiveRoot)
        return relative?.hasPrefix("_index/thumbs/") != true
    }

    func canGenerateImplicitThumbnail(at url: URL) -> Bool {
        guard !escapesArchive(url) else { return false }
        guard isInsideArchive(url) else { return true }
        guard machineRole != .travel else { return false }
        return isOnlineOnly(url) == false
    }

    func isOnlineOnly(_ url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
            guard let logicalSize = values.fileSize, let allocatedSize = values.totalFileAllocatedSize else { return true }
            if logicalSize > 0 && allocatedSize == 0 { return true }
            guard logicalSize > 16_384 else { return false }
            return allocatedSize <= 4_096 || logicalSize > max(allocatedSize, 1) * 16
        } catch {
            return true
        }
    }

    func isInsideArchive(_ url: URL) -> Bool {
        let lexical = url.standardizedFileURL.path
        let resolved = ArchivePathSafety.resolvedForWrite(url).path
        return contains(lexical, in: archiveRoot.path) || contains(lexical, in: resolvedArchiveRootPath) || contains(resolved, in: resolvedArchiveRootPath)
    }

    func escapesArchive(_ url: URL) -> Bool {
        (contains(url.standardizedFileURL.path, in: archiveRoot.path) || contains(url.standardizedFileURL.path, in: resolvedArchiveRootPath))
            && !contains(ArchivePathSafety.resolvedForWrite(url).path, in: resolvedArchiveRootPath)
    }

    private func contains(_ path: String, in root: String) -> Bool {
        root == "/" || path == root || path.hasPrefix(root + "/")
    }
}

final class ArchiveByteReadPolicyContext: @unchecked Sendable {
    static let shared = ArchiveByteReadPolicyContext()

    private let lock = NSLock()
    private var policy = ArchiveByteReadPolicy(archiveRoot: URL(fileURLWithPath: "/", isDirectory: true), machineRole: .mainArchive)
    private var onlineOnlyVerdicts: [String: Bool] = [:]
    private var explicitViewPaths = Set<String>()
    private var policyGeneration = 0

    var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return policyGeneration
    }

    func update(settings: AppSettings) {
        lock.lock()
        policy = ArchiveByteReadPolicy(archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole)
        onlineOnlyVerdicts.removeAll()
        explicitViewPaths.removeAll()
        policyGeneration += 1
        lock.unlock()
    }

    func canReadBytes(at url: URL, explicitDownload: Bool = false) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        lock.lock()
        let current = policy
        let currentGeneration = policyGeneration
        let granted = explicitViewPaths.contains(path)
        lock.unlock()
        guard !current.escapesArchive(url) else { return false }
        let allowed = current.machineRole != .travel || !current.isOriginalArchiveFile(url)
            || ((explicitDownload || granted) && !current.isOnlineOnly(url))
        lock.lock()
        defer { lock.unlock() }
        return allowed && currentGeneration == policyGeneration
    }

    func canRequestExplicitViewing(at url: URL) -> Bool {
        let current = snapshot()
        return current.isOriginalArchiveFile(url) && !current.escapesArchive(url)
    }

    func isAvailableForExplicitViewing(at url: URL) -> Bool {
        let current = snapshot()
        return !current.escapesArchive(url) && current.isOriginalArchiveFile(url) && !current.isOnlineOnly(url)
    }

    @discardableResult
    func grantExplicitViewing(at url: URL, generation expectedGeneration: Int) -> Bool {
        guard isAvailableForExplicitViewing(at: url) else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard expectedGeneration == policyGeneration else { return false }
        explicitViewPaths.insert(url.resolvingSymlinksInPath().standardizedFileURL.path)
        onlineOnlyVerdicts.removeValue(forKey: url.standardizedFileURL.path)
        return true
    }

    func isOnlineOnlyArchiveFile(_ url: URL) -> Bool {
        let current = snapshot()
        guard current.machineRole == .travel, current.isInsideArchive(url) else { return false }
        return cachedOnlineOnlyVerdict(for: url, policy: current)
    }

    func canPreheatOriginal(at url: URL) -> Bool {
        let current = snapshot()
        guard !current.escapesArchive(url) else { return false }
        guard current.machineRole != .travel || !current.isInsideArchive(url) else { return false }
        return canReadBytes(at: url)
    }

    func canGenerateImplicitThumbnail(at url: URL) -> Bool {
        let current = snapshot()
        guard !current.escapesArchive(url) else { return false }
        guard current.isInsideArchive(url) else { return true }
        guard current.machineRole != .travel else { return false }
        return cachedOnlineOnlyVerdict(for: url, policy: current) == false
    }

    private func cachedOnlineOnlyVerdict(for url: URL, policy current: ArchiveByteReadPolicy) -> Bool {
        let key = url.standardizedFileURL.path
        lock.lock()
        if let cached = onlineOnlyVerdicts[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let verdict = current.isOnlineOnly(url)
        lock.lock()
        // A cached local verdict can become unsafe after external File Provider eviction.
        if verdict { onlineOnlyVerdicts[key] = true }
        lock.unlock()
        return verdict
    }

    func indexThumbnailURLIfAvailable(for archiveFileURL: URL) -> URL? {
        let current = snapshot()
        guard current.isInsideArchive(archiveFileURL) else { return nil }
        guard !current.escapesArchive(archiveFileURL) else { return nil }
        let url = ArchiveIndexStore.thumbnailURL(for: archiveFileURL, archiveRoot: current.archiveRoot)
        guard !current.escapesArchive(url) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func isArchiveFile(_ url: URL) -> Bool {
        snapshot().isInsideArchive(url)
    }

    func invalidateOnlineOnlyVerdict(for url: URL) {
        lock.lock()
        onlineOnlyVerdicts.removeValue(forKey: url.standardizedFileURL.path)
        lock.unlock()
    }

    func warmOnlineOnlyVerdicts(for urls: [URL]) {
        let current = snapshot()
        guard current.machineRole == .travel else { return }
        for url in urls where current.isInsideArchive(url) {
            let key = url.standardizedFileURL.path
            lock.lock()
            let hasCachedVerdict = onlineOnlyVerdicts[key] != nil
            lock.unlock()
            guard !hasCachedVerdict else { continue }
            let verdict = current.isOnlineOnly(url)
            lock.lock()
            if verdict { onlineOnlyVerdicts[key] = true }
            lock.unlock()
        }
    }

    private func snapshot() -> ArchiveByteReadPolicy {
        lock.lock()
        let current = policy
        lock.unlock()
        return current
    }
}

private struct ArchiveIndexGeneration: Codable {
    var shards: [String: String]
}

struct ArchiveIndexStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let backfillSafety: ArchiveThumbnailBackfillSafety
    let availableCapacityProvider: (URL) -> Int64?
    let evictor: (URL) async throws -> Void
    let thumbnailGenerator: ((URL, URL) async throws -> URL)?

    init(
        fileManager: FileManager = .default,
        backfillSafety: ArchiveThumbnailBackfillSafety = ArchiveThumbnailBackfillSafety(),
        availableCapacityProvider: @escaping (URL) -> Int64? = ArchiveIndexStore.availableCapacity,
        evictor: @escaping (URL) async throws -> Void = ArchiveFileProviderEvictor.evict,
        thumbnailGenerator: ((URL, URL) async throws -> URL)? = nil
    ) {
        self.fileManager = fileManager
        self.backfillSafety = backfillSafety
        self.availableCapacityProvider = availableCapacityProvider
        self.evictor = evictor
        self.thumbnailGenerator = thumbnailGenerator
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    static func indexRoot(for archiveRoot: URL) -> URL {
        archiveRoot.appendingPathComponent("_index", isDirectory: true)
    }

    static func shardRoot(for archiveRoot: URL) throws -> URL {
        let root = indexRoot(for: archiveRoot)
        let pointer = root.appendingPathComponent("index-current.json")
        guard FileManager.default.fileExists(atPath: pointer.path) else { return root }
        let name = try JSONDecoder().decode(String.self, from: Data(contentsOf: pointer))
        guard UUID(uuidString: name) != nil else {
            throw ArchiveFileVerification.failure("The Archive Index generation record is invalid. Rebuild the index from manifests.")
        }
        let generation = root.appendingPathComponent("generations/\(name)", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: generation.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArchiveFileVerification.failure("The current Archive Index generation is unavailable.")
        }
        let descriptor = try JSONDecoder().decode(ArchiveIndexGeneration.self,
            from: Data(contentsOf: generation.appendingPathComponent("generation.json")))
        for (file, digest) in descriptor.shards {
            guard file.range(of: #"^index-[^/]+\.jsonl$"#, options: .regularExpression) != nil,
                  (try? ArchiveFileVerification.sha256(at: generation.appendingPathComponent(file))) == digest else {
                throw ArchiveFileVerification.failure("The Archive Index has not completely synchronised. Wait for OneDrive or rebuild it from local manifests.")
            }
        }
        return generation
    }

    static func thumbnailURL(for archiveFileURL: URL, archiveRoot: URL) -> URL {
        let relative = archiveRelativePath(for: archiveFileURL, archiveRoot: archiveRoot) ?? archiveFileURL.lastPathComponent
        let components = relative.split(separator: "/").map(String.init)
        let year = components.first ?? "unknown"
        let stem = archiveFileURL.deletingPathExtension().lastPathComponent
        let ext = archiveFileURL.pathExtension.lowercased().nonEmpty ?? "file"
        let digest = CacheKeyBuilder.key(for: relative).prefix(12)
        return indexRoot(for: archiveRoot)
            .appendingPathComponent("thumbs", isDirectory: true)
            .appendingPathComponent(year, isDirectory: true)
            .appendingPathComponent("\(stem)-\(ext)-\(digest).jpg")
    }

    static func validatedThumbnailURL(relativePath: String, archiveRoot: URL) -> URL? {
        guard relativePath.hasPrefix("_index/thumbs/"), relativePath.hasSuffix(".jpg") else { return nil }
        return try? ArchiveIndexMediaLoader().indexedURL(relativePath, archiveRoot: archiveRoot)
    }

    static func thumbnailRelativePath(for archiveFileURL: URL, archiveRoot: URL) -> String? {
        archiveRelativePath(for: thumbnailURL(for: archiveFileURL, archiveRoot: archiveRoot), archiveRoot: archiveRoot)
    }

    static func archiveRelativePath(for url: URL, archiveRoot: URL) -> String? {
        // Index rows are archive-root-relative. Walk and Trip manifests may be
        // oneDrivePicturesRoot-relative when those roots diverge.
        ArchiveRelativePathResolver(root: archiveRoot.resolvingSymlinksInPath()).relativePath(for: url.resolvingSymlinksInPath())
    }

    func generateThumbnail(for archiveFileURL: URL, archiveRoot: URL, maxPixelSize: CGFloat = 512) async throws -> URL {
        let destination = Self.thumbnailURL(for: archiveFileURL, archiveRoot: archiveRoot)
        if isValidThumbnail(destination) { return destination }
        if let thumbnailGenerator { return try await thumbnailGenerator(archiveFileURL, archiveRoot) }
        try AppDirectories.ensureExists(destination.deletingLastPathComponent(), fileManager: fileManager)
        let request = QLThumbnailGenerator.Request(
            fileAt: archiveFileURL,
            size: CGSize(width: maxPixelSize, height: maxPixelSize),
            scale: 1,
            representationTypes: .thumbnail
        )
        let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        guard let data = jpegData(from: representation.nsImage, compressionQuality: 0.82) else {
            throw NSError(domain: "ArchiveIndexStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not encode archive thumbnail for \(archiveFileURL.lastPathComponent)."
            ])
        }
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func promoteCachedThumbnail(
        _ cachedThumbnailURL: URL,
        for archiveFileURL: URL,
        archiveRoot: URL
    ) throws -> URL {
        let destination = Self.thumbnailURL(for: archiveFileURL, archiveRoot: archiveRoot)
        if isValidThumbnail(destination) { return destination }

        guard let image = NSImage(contentsOf: cachedThumbnailURL),
              let data = jpegData(from: image, compressionQuality: 0.82) else {
            throw NSError(domain: "ArchiveIndexStore", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not reuse the cached thumbnail for \(archiveFileURL.lastPathComponent)."
            ])
        }
        try AppDirectories.ensureExists(destination.deletingLastPathComponent(), fileManager: fileManager)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func backfillThumbnails(
        archiveRoot: URL,
        supportedExtensions: Set<String>,
        photoURLs: [URL]? = nil,
        cachedThumbnailURLsByPhotoPath: [String: URL] = [:],
        throttleNanoseconds: UInt64 = 30_000_000,
        progress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async -> ArchiveIndexThumbnailResult {
        let bytePolicy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: .mainArchive)
        let photos = (photoURLs ?? archivePhotos(in: archiveRoot, supportedExtensions: supportedExtensions))
            .filter { bytePolicy.isInsideArchive($0) && supportedExtensions.contains($0.pathExtension.lowercased()) }
        var result = ArchiveIndexThumbnailResult(
            scannedPhotos: photos.count,
            generatedThumbnails: 0,
            existingThumbnails: 0,
            failures: [],
            evictedFiles: 0,
            stoppedForLowSpace: false,
            cancelled: false
        )
        for (offset, url) in photos.enumerated() {
            if Task.isCancelled {
                result.cancelled = true
                break
            }
            var hydrationAttempted = false
            do {
                let thumbnailURL = Self.thumbnailURL(for: url, archiveRoot: archiveRoot)
                if isValidThumbnail(thumbnailURL) {
                    result.existingThumbnails += 1
                } else if let cachedThumbnailURL = cachedThumbnailURLsByPhotoPath[url.standardizedFileURL.path],
                          fileManager.fileExists(atPath: cachedThumbnailURL.path) {
                    _ = try promoteCachedThumbnail(
                        cachedThumbnailURL,
                        for: url,
                        archiveRoot: archiveRoot
                    )
                    result.generatedThumbnails += 1
                } else {
                    guard backfillSafety.hasSafeCapacity(availableCapacityProvider(archiveRoot)) else {
                        result.stoppedForLowSpace = true
                        break
                    }
                    let wasOnlineOnly = bytePolicy.isOnlineOnly(url)
                    if wasOnlineOnly {
                        hydrationAttempted = true
                        let handle = try FileHandle(forReadingFrom: url)
                        defer { try? handle.close() }
                        _ = try handle.read(upToCount: 1)
                    }
                    try Task.checkCancellation()
                    _ = try await generateThumbnail(for: url, archiveRoot: archiveRoot)
                    result.generatedThumbnails += 1
                    if throttleNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: throttleNanoseconds)
                    }
                }
            } catch {
                if error is CancellationError { result.cancelled = true }
                else { result.failures.append("\(url.path): \(error.localizedDescription)") }
            }
            // Eviction also runs when decoding fails or cancellation interrupts generation.
            if hydrationAttempted {
                do {
                    try await evictor(url)
                    result.evictedFiles += 1
                } catch {
                    result.failures.append("\(url.path): the downloaded original could not be evicted: \(error.localizedDescription)")
                }
            }
            if result.cancelled || Task.isCancelled { result.cancelled = true; break }
            if offset % 10 == 0 || offset == photos.indices.last {
                await progress?(offset + 1, photos.count)
            }
        }

        return result
    }

    private func isValidThumbnail(_ url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }

    private static func availableCapacity(at archiveRoot: URL) -> Int64? {
        try? archiveRoot.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    @discardableResult
    func rebuildIndex(archiveRoot: URL) throws -> ArchiveIndexRebuildResult {
        let mutationLock = try ArchiveMutationLock(archiveRoot: archiveRoot)
        defer { withExtendedLifetime(mutationLock) {} }
        try ArchiveLocationEditor.assertNoPending(overlapping: archiveRoot, archiveRoot: archiveRoot)
        let entries = try entriesFromArchive(archiveRoot: archiveRoot)
        try replaceIndex(with: entries, archiveRoot: archiveRoot)
        let years = Array(Set(entries.map(\.year))).sorted()
        return ArchiveIndexRebuildResult(entryCount: entries.count, years: years)
    }

    func updateIndex(
        with entries: [ArchiveIndexEntry],
        archiveRoot: URL,
        removingArchiveRelativePaths: Set<String> = [],
        replacingWalkPaths: Set<String> = [],
        replacingTripPaths: Set<String> = []
    ) throws {
        guard !entries.isEmpty || !removingArchiveRelativePaths.isEmpty || !replacingWalkPaths.isEmpty || !replacingTripPaths.isEmpty else { return }
        let mutationLock = try ArchiveMutationLock(archiveRoot: archiveRoot)
        defer { withExtendedLifetime(mutationLock) {} }
        try updateIndexWhileLocked(with: entries, archiveRoot: archiveRoot,
            removingArchiveRelativePaths: removingArchiveRelativePaths,
            replacingWalkPaths: replacingWalkPaths, replacingTripPaths: replacingTripPaths)
    }

    private func updateIndexWhileLocked(with entries: [ArchiveIndexEntry], archiveRoot: URL,
        removingArchiveRelativePaths: Set<String> = [], replacingWalkPaths: Set<String> = [],
        replacingTripPaths: Set<String> = []) throws {
        try AppDirectories.ensureExists(Self.indexRoot(for: archiveRoot), fileManager: fileManager)
        let activeRoot = try Self.shardRoot(for: archiveRoot)
        let shards = try fileManager.contentsOfDirectory(at: activeRoot, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.range(of: #"^index-.+\.jsonl$"#, options: .regularExpression) != nil }
        var existing = try shards.flatMap { try readEntries(from: $0) }
        let replacementKeys = Set(entries.map(entryKey))
        existing.removeAll { entry in
            replacementKeys.contains(entryKey(entry))
                || removingArchiveRelativePaths.contains(entry.archiveRelativePath)
                || entry.walkPath.map(replacingWalkPaths.contains) == true
                || (entry.kind == .trip && entry.tripPath.map(replacingTripPaths.contains) == true)
                || replacingWalkPaths.contains(entry.archiveRelativePath)
                || (entry.kind == .trip && replacingTripPaths.contains(entry.archiveRelativePath))
        }
        existing.append(contentsOf: entries)
        try replaceIndex(with: existing, archiveRoot: archiveRoot)
    }

    func entriesForImport(
        result: ImportResult,
        archiveRoot: URL,
        generatedThumbnailPaths: [String: String] = [:]
    ) -> [ArchiveIndexEntry] {
        var entries: [ArchiveIndexEntry] = []
        let walkByPath = Dictionary(uniqueKeysWithValues: result.walkManifests.compactMap { walk -> (String, WalkManifest)? in
            guard let path = walk.archiveFolderRelativePath else { return nil }
            return (path, walk)
        })

        for file in result.fileManifests {
            let fileURL = URL(fileURLWithPath: file.archivePath)
            let relativePath = Self.archiveRelativePath(for: fileURL, archiveRoot: archiveRoot) ?? file.archiveRelativePath ?? fileURL.lastPathComponent
            let year = relativePath.split(separator: "/").first.map(String.init) ?? "unknown"
            let walkPath = relativePath.split(separator: "/").dropLast().joined(separator: "/")
            let walk = walkByPath[walkPath]
            entries.append(ArchiveIndexEntry(
                kind: .photo,
                year: year,
                archiveRelativePath: relativePath,
                date: file.capturedAt.map(DateFormatting.iso8601.string(from:)),
                title: file.sourceFileName,
                location: file.walkLocation.nonEmpty,
                exifSummary: exifSummary(cameraModel: file.cameraModel, lensModel: file.lensModel, pixelWidth: file.pixelWidth, pixelHeight: file.pixelHeight),
                aiDescription: "",
                notes: file.notes,
                thumbnailPath: generatedThumbnailPaths[relativePath],
                walkPath: walkPath.nonEmpty,
                tripPath: walk?.tripFolderRelativePath
            ))
        }

        entries.append(contentsOf: result.walkManifests.map { entry(from: $0, archiveRoot: archiveRoot) })
        entries.append(contentsOf: result.tripManifests.map { entry(from: $0, archiveRoot: archiveRoot) })
        let indexedTripPaths = Set(result.tripManifests.compactMap(\.folderRelativePath))
        let defaultTripGroups = Dictionary(grouping: result.walkManifests) { $0.tripFolderRelativePath ?? "" }
        for (tripPath, walks) in defaultTripGroups where !tripPath.isEmpty && !indexedTripPaths.contains(tripPath) {
            let tripFolder = archiveRoot.appendingPathComponent(tripPath, isDirectory: true)
            let dates = walks.compactMap(\.walkDate)
            entries.append(ArchiveIndexEntry(
                kind: .trip,
                year: tripPath.split(separator: "/").first.map(String.init) ?? "unknown",
                archiveRelativePath: tripPath,
                date: dates.min().map(DateFormatting.iso8601.string(from:)),
                title: tripFolder.lastPathComponent,
                location: nil,
                exifSummary: nil,
                aiDescription: "",
                notes: nil,
                thumbnailPath: walks.first?.importedFiles.first.flatMap {
                    generatedThumbnailPaths[Self.archiveRelativePath(for: URL(fileURLWithPath: $0.archivePath), archiveRoot: archiveRoot) ?? $0.archiveRelativePath ?? ""]
                },
                walkPath: nil,
                tripPath: tripPath
            ))
        }
        return entries
    }

    func replaceWalkFolders(_ walkFolders: [URL], archiveRoot: URL,
        removingWalkPaths: Set<String> = [], tripFolders: [URL] = []) throws {
        let mutationLock = try ArchiveMutationLock(archiveRoot: archiveRoot)
        defer { withExtendedLifetime(mutationLock) {} }
        for folder in walkFolders { try ArchiveLocationEditor.assertNoPending(overlapping: folder, archiveRoot: archiveRoot) }
        var entries: [ArchiveIndexEntry] = []
        for walkFolder in walkFolders {
            entries.append(contentsOf: try entriesForWalkFolder(walkFolder, archiveRoot: archiveRoot))
        }
        entries.append(contentsOf: tripFolders.map { entryForTripFolder($0, archiveRoot: archiveRoot) })
        let walkPaths = removingWalkPaths.union(Set(entries.compactMap(\.walkPath)))
        let tripPaths = Set(entries.filter { $0.kind == .trip }.compactMap(\.tripPath))
        try updateIndexWhileLocked(
            with: entries,
            archiveRoot: archiveRoot,
            replacingWalkPaths: walkPaths,
            replacingTripPaths: tripPaths
        )
    }

    func entriesForWalkFolder(_ walkFolder: URL, archiveRoot: URL) throws -> [ArchiveIndexEntry] {
        guard let walkManifest = try loadWalkManifest(folder: walkFolder, archiveRoot: archiveRoot) else { return [] }
        var entries = [entry(from: walkManifest, archiveRoot: archiveRoot)]
        for file in try loadFileManifests(folder: walkFolder, archiveRoot: archiveRoot) {
            entries.append(photoEntry(from: file, walk: walkManifest, archiveRoot: archiveRoot))
        }
        return try includingCropRelationships(entries, archiveRoot: archiveRoot)
    }

    func entryForTripFolder(_ tripFolder: URL, archiveRoot: URL) -> ArchiveIndexEntry {
        let tripManifest = TripManifestStore(fileManager: fileManager).loadTripManifest(folder: tripFolder, oneDrivePicturesRoot: archiveRoot)
        return entry(from: tripManifest, archiveRoot: archiveRoot)
    }

    private func replaceIndex(with entries: [ArchiveIndexEntry], archiveRoot: URL) throws {
        let root = Self.indexRoot(for: archiveRoot)
        let previous = try? Self.shardRoot(for: archiveRoot)
        let name = UUID().uuidString
        let generation = root.appendingPathComponent("generations/\(name)", isDirectory: true)
        try AppDirectories.ensureExists(generation, fileManager: fileManager)
        var published = false
        defer {
            if !published { try? fileManager.removeItem(at: generation) }
        }
        var shardDigests: [String: String] = [:]
        let byYear = Dictionary(grouping: entries, by: \.year)
        for year in byYear.keys.sorted() {
            try Task.checkCancellation()
            let values = byYear[year]!.sorted {
                $0.archiveRelativePath == $1.archiveRelativePath
                    ? $0.kind.rawValue < $1.kind.rawValue : $0.archiveRelativePath < $1.archiveRelativePath
            }
            let shard = generation.appendingPathComponent("index-\(year).jsonl")
            try writeEntries(values, to: shard)
            shardDigests[shard.lastPathComponent] = try ArchiveFileVerification.sha256(at: shard)
            guard try readEntries(from: shard) == values else {
                throw ArchiveFileVerification.failure("The replacement Archive Index could not be verified.")
            }
        }
        try Task.checkCancellation()
        try JSONEncoder().encode(ArchiveIndexGeneration(shards: shardDigests))
            .write(to: generation.appendingPathComponent("generation.json"), options: .atomic)
        let pointer = root.appendingPathComponent("index-current.json")
        try JSONEncoder().encode(name).write(to: pointer, options: .atomic)
        published = true
        // Keep the preceding complete generation; prune only app-owned older generations.
        let generations = root.appendingPathComponent("generations", isDirectory: true)
        for url in (try? fileManager.contentsOfDirectory(at: generations, includingPropertiesForKeys: nil)) ?? []
            where UUID(uuidString: url.lastPathComponent) != nil && url.standardizedFileURL.path != generation.standardizedFileURL.path && url.standardizedFileURL.path != previous?.standardizedFileURL.path {
            try? fileManager.removeItem(at: url)
        }
    }

    private func entriesFromArchive(archiveRoot: URL) throws -> [ArchiveIndexEntry] {
        var entries: [ArchiveIndexEntry] = []
        var walks: [WalkManifest] = []
        var explicitTripPaths = Set<String>()

        for manifestURL in try structuralManifestURLs(archiveRoot: archiveRoot) {
            try Task.checkCancellation()
            let folder = manifestURL.deletingLastPathComponent()
            let text = try String(contentsOf: manifestURL, encoding: .utf8)

            if text.contains("Trip ID:") {
                let manifest = TripManifestStore(fileManager: fileManager)
                    .loadTripManifest(folder: folder, oneDrivePicturesRoot: archiveRoot)
                let tripEntry = entry(from: manifest, archiveRoot: archiveRoot)
                explicitTripPaths.insert(tripEntry.archiveRelativePath)
                entries.append(tripEntry)
            } else if text.contains("Session ID:"),
                      text.contains("Archive folder:"),
                      let walkManifest = try loadWalkManifest(folder: folder, archiveRoot: archiveRoot) {
                walks.append(walkManifest)
                entries.append(entry(from: walkManifest, archiveRoot: archiveRoot))
                for file in try loadFileManifests(folder: folder, archiveRoot: archiveRoot) {
                    entries.append(photoEntry(from: file, walk: walkManifest, archiveRoot: archiveRoot))
                }
            }
        }

        let walksByTripPath = Dictionary(grouping: walks) { $0.tripFolderRelativePath ?? "" }
        for (tripPath, memberWalks) in walksByTripPath
            where !tripPath.isEmpty && !explicitTripPaths.contains(tripPath) {
            let tripFolder = archiveRoot.appendingPathComponent(tripPath, isDirectory: true)
            let dates = memberWalks.compactMap(\.walkDate)
            let coverPath = memberWalks
                .flatMap(\.importedFiles)
                .compactMap { file -> String? in
                    let photoURL = URL(fileURLWithPath: file.archivePath)
                    return existingThumbnailRelativePath(for: photoURL, archiveRoot: archiveRoot)
                }
                .first
            entries.append(ArchiveIndexEntry(
                kind: .trip,
                year: tripPath.split(separator: "/").first.map(String.init) ?? "unknown",
                archiveRelativePath: tripPath,
                date: dates.min().map(DateFormatting.iso8601.string(from:)),
                title: tripFolder.lastPathComponent,
                location: nil,
                exifSummary: nil,
                aiDescription: "",
                notes: nil,
                thumbnailPath: coverPath,
                walkPath: nil,
                tripPath: tripPath
            ))
        }
        let recognised = Set(entries.filter { $0.kind == .trip || $0.kind == .walk }.map(\.archiveRelativePath))
        let discovery = try ArchiveCatalogueBuilder(fileManager: fileManager).discoverHistoricalFolders(
            archiveRoot: archiveRoot, recognisedRoots: recognised, supportedExtensions: AppSettings.default().supportedExtensions)
        entries.append(contentsOf: try historicalEntries(discovery, archiveRoot: archiveRoot))
        return try includingCropRelationships(entries, archiveRoot: archiveRoot)
    }

    private func structuralManifestURLs(archiveRoot: URL) throws -> [URL] {
        _ = try fileManager.contentsOfDirectory(at: archiveRoot, includingPropertiesForKeys: nil)
        var enumerationError: Error?
        guard let enumerator = fileManager.enumerator(
            at: archiveRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, error in enumerationError = error; return false }
        ) else { throw ArchiveFileVerification.failure("Could not enumerate Archive manifests.") }

        let urls = enumerator.compactMap { entry -> URL? in
            guard let url = entry as? URL else { return nil }
            let relativePath = Self.archiveRelativePath(for: url, archiveRoot: archiveRoot) ?? ""
            if relativePath == "_index" || relativePath.hasPrefix("_index/") {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                return nil
            }
            guard url.pathExtension.lowercased() == "md",
                  url.deletingPathExtension().lastPathComponent == url.deletingLastPathComponent().lastPathComponent,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }
            return url
        }
        .sorted { $0.path < $1.path }
        if let enumerationError { throw enumerationError }
        return urls
    }

    private func entry(from manifest: WalkManifest, archiveRoot: URL) -> ArchiveIndexEntry {
        let relativePath = manifest.archiveFolderRelativePath
            ?? Self.archiveRelativePath(for: manifest.archiveFolder, archiveRoot: archiveRoot)
            ?? manifest.archiveFolder.lastPathComponent
        let year = relativePath.split(separator: "/").first.map(String.init) ?? "unknown"
        let cover = manifest.importedFiles.first.flatMap { URL(fileURLWithPath: $0.archivePath) }
        return ArchiveIndexEntry(
            kind: .walk,
            year: year,
            archiveRelativePath: relativePath,
            date: manifest.walkDate.map(DateFormatting.iso8601.string(from:)),
            title: manifest.title,
            location: manifest.location.nonEmpty,
            exifSummary: nil,
            aiDescription: "",
            notes: manifest.notes,
            thumbnailPath: cover.flatMap { existingThumbnailRelativePath(for: $0, archiveRoot: archiveRoot) },
            walkPath: relativePath,
            tripPath: manifest.tripFolderRelativePath,
            latitude: manifest.latitude,
            longitude: manifest.longitude,
            coordinateSource: ArchiveCoordinate(latitude: manifest.latitude, longitude: manifest.longitude) != nil ? .walkPin : nil,
            sessionID: manifest.sessionID, walkID: manifest.walkID
        )
    }

    private func entry(from manifest: TripManifest, archiveRoot: URL) -> ArchiveIndexEntry {
        let relativePath = manifest.folderRelativePath
            ?? Self.archiveRelativePath(for: manifest.folder, archiveRoot: archiveRoot)
            ?? manifest.folder.lastPathComponent
        let year = relativePath.split(separator: "/").first.map(String.init) ?? "unknown"
        return ArchiveIndexEntry(
            kind: .trip,
            year: year,
            archiveRelativePath: relativePath,
            date: manifest.startDate.map(DateFormatting.iso8601.string(from:)),
            title: manifest.title,
            location: nil,
            exifSummary: nil,
            aiDescription: "",
            notes: nil,
            thumbnailPath: nil,
            walkPath: nil,
            tripPath: relativePath
        )
    }

    private func photoEntry(from manifest: FileManifest, walk: WalkManifest, archiveRoot: URL) -> ArchiveIndexEntry {
        let fileURL = URL(fileURLWithPath: manifest.archivePath)
        let relativePath = Self.archiveRelativePath(for: fileURL, archiveRoot: archiveRoot)
            ?? manifest.archiveRelativePath
            ?? fileURL.lastPathComponent
        let year = relativePath.split(separator: "/").first.map(String.init) ?? "unknown"
        let gps = ArchiveCoordinate(latitude: manifest.latitude, longitude: manifest.longitude)
        let pin = ArchiveCoordinate(latitude: walk.latitude, longitude: walk.longitude)
        let coordinate = manifest.locationOverride?.coordinate ?? pin ?? gps
        return ArchiveIndexEntry(
            kind: .photo,
            year: year,
            archiveRelativePath: relativePath,
            date: manifest.capturedAt.map(DateFormatting.iso8601.string(from:)),
            title: manifest.sourceFileName,
            location: manifest.locationOverride?.name.nonEmpty ?? walk.location.nonEmpty,
            exifSummary: exifSummary(cameraModel: manifest.cameraModel, lensModel: manifest.lensModel, pixelWidth: manifest.pixelWidth, pixelHeight: manifest.pixelHeight),
            aiDescription: "",
            notes: manifest.notes,
            thumbnailPath: existingThumbnailRelativePath(for: fileURL, archiveRoot: archiveRoot),
            walkPath: walk.archiveFolderRelativePath,
            tripPath: walk.tripFolderRelativePath,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            mediaItemID: manifest.mediaItemID, pixelWidth: manifest.pixelWidth, pixelHeight: manifest.pixelHeight,
            cameraModel: manifest.cameraModel, lensModel: manifest.lensModel,
            companionPaths: manifest.companionArchivePaths.compactMap { Self.archiveRelativePath(for: URL(fileURLWithPath: $0), archiveRoot: archiveRoot) },
            coordinateSource: manifest.locationOverride?.coordinate != nil ? (manifest.locationOverride!.isShared ? .sharedOverride : .photoOverride)
                : (pin != nil ? .walkPin : (gps != nil ? .photoGPS : nil)),
            gpsLatitude: gps?.latitude, gpsLongitude: gps?.longitude, locationOverride: manifest.locationOverride,
            sessionID: walk.sessionID, walkID: walk.walkID
        )
    }

    func loadWalkManifest(folder: URL, archiveRoot: URL) throws -> WalkManifest? {
        let url = folder.appendingPathComponent("\(folder.lastPathComponent).md")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let storedSessionID = firstBacktickedValue(after: "Session ID:", in: text).flatMap(UUID.init(uuidString:)) else {
            throw ArchiveFileVerification.failure("Invalid Walk manifest: \(url.lastPathComponent)")
        }
        let title = firstHeading(in: text) ?? folder.lastPathComponent
        let sessionID = storedSessionID
        let walkID = firstBacktickedValue(after: "Walk ID:", in: text).flatMap(UUID.init(uuidString:))
        let sourceFolder = firstBacktickedValue(after: "Source folder:", in: text).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? folder
        let archiveFolder = folder
        let archiveRelativePath = Self.archiveRelativePath(for: folder, archiveRoot: archiveRoot)
            ?? firstBacktickedValue(after: "OneDrive Pictures relative folder:", in: text)
        let tripFolder = Self.archiveRelativePath(for: folder.deletingLastPathComponent(), archiveRoot: archiveRoot)
            ?? firstBacktickedValue(after: "Trip folder:", in: text)
        let walkDate = firstValue(after: "Walk date:", in: text).flatMap { DateFormatting.iso8601.date(from: $0) }
        let location = firstValue(after: "Location:", in: text) ?? ""
        let notes = notesSection(in: text)
        let files = try loadFileManifests(folder: folder, archiveRoot: archiveRoot)
        return WalkManifest(
            sessionID: sessionID,
            walkID: walkID,
            tripFolderRelativePath: tripFolder,
            walkDate: walkDate,
            sourceFolder: sourceFolder,
            archiveFolder: archiveFolder,
            archiveFolderRelativePath: archiveRelativePath,
            title: title,
            location: location,
            latitude: firstValue(after: "Latitude:", in: text).flatMap(Double.init),
            longitude: firstValue(after: "Longitude:", in: text).flatMap(Double.init),
            notes: notes,
            summary: .init(
                totalSourceFiles: files.count,
                visibleItems: files.count,
                importedFiles: files.count,
                excludedFiles: 0,
                candidateFiles: 0,
                undecidedFiles: 0,
                skippedFiles: 0,
                cleanupPendingFiles: 0,
                cleanedSourceFiles: 0
            ),
            importedFiles: files,
            excludedFiles: []
        )
    }

    func loadFileManifests(folder: URL, archiveRoot: URL? = nil) throws -> [FileManifest] {
        let urls = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.lowercased() == "md" }
            .filter { $0.lastPathComponent != "\(folder.lastPathComponent).md" }
        return try urls.compactMap { url in
            let text = try String(contentsOf: url, encoding: .utf8)
            guard text.contains("media_item_id:") else { return nil }
            guard var manifest = try parseFileManifest(text: text) else {
                throw ArchiveFileVerification.failure("Invalid photo manifest: \(url.lastPathComponent)")
            }
            let localFile = folder.appendingPathComponent(URL(fileURLWithPath: manifest.archivePath).lastPathComponent)
            manifest.archivePath = localFile.path
            if let archiveRoot {
                manifest.archiveRelativePath = Self.archiveRelativePath(for: localFile, archiveRoot: archiveRoot)
            }
            manifest.companionArchivePaths = manifest.companionArchivePaths.map {
                folder.appendingPathComponent(URL(fileURLWithPath: $0).lastPathComponent).path
            }
            if let archiveRoot {
                manifest.companionArchiveRelativePaths = manifest.companionArchivePaths.compactMap {
                    Self.archiveRelativePath(for: URL(fileURLWithPath: $0), archiveRoot: archiveRoot)
                }
            }
            return manifest
        }
    }

    private func parseFileManifest(text: String) throws -> FileManifest? {
        guard let id = yamlValue("media_item_id", in: text).flatMap(UUID.init(uuidString:)),
              let archivePath = yamlValue("archive_path", in: text),
              let sourceFileName = yamlValue("source_file_name", in: text) else { return nil }
        let notes = ArchiveManifestText.body(in: text)
        return FileManifest(
            mediaItemID: id,
            archivePath: archivePath,
            sha256: yamlValue("sha256", in: text),
            archiveRelativePath: yamlValue("archive_relative_path", in: text),
            sourceFileName: sourceFileName,
            companionArchivePaths: yamlList("companion_archive_paths", in: text),
            companionArchiveRelativePaths: yamlList("companion_archive_relative_paths", in: text),
            capturedAt: yamlValue("captured_at", in: text).flatMap { DateFormatting.iso8601.date(from: $0) },
            cameraModel: yamlValue("camera_model", in: text),
            lensModel: yamlValue("lens_model", in: text),
            pixelWidth: yamlValue("pixel_width", in: text).flatMap(Int.init),
            pixelHeight: yamlValue("pixel_height", in: text).flatMap(Int.init),
            latitude: yamlValue("latitude", in: text).flatMap(Double.init),
            longitude: yamlValue("longitude", in: text).flatMap(Double.init),
            walkTitle: yamlValue("walk_title", in: text) ?? "",
            walkLocation: yamlValue("walk_location", in: text) ?? "",
            notes: notes,
            locationOverride: try PhotoLocationOverride.read(in: text)
        )
    }

    private func archivePhotos(in archiveRoot: URL, supportedExtensions: Set<String>) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: archiveRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { entry -> URL? in
            guard let url = entry as? URL else { return nil }
            let relative = Self.archiveRelativePath(for: url, archiveRoot: archiveRoot) ?? ""
            guard !relative.hasPrefix("_index/") else { return nil }
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return nil }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
            return url
        }
        .sorted { $0.path < $1.path }
    }

    private func readEntries(from url: URL) throws -> [ArchiveIndexEntry] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try text.split(separator: "\n").map { line in
            try decoder.decode(ArchiveIndexEntry.self, from: Data(line.utf8))
        }
    }

    private func writeEntries(_ entries: [ArchiveIndexEntry], to url: URL) throws {
        try AppDirectories.ensureExists(url.deletingLastPathComponent(), fileManager: fileManager)
        let lines = try entries.map { entry -> String in
            let data = try encoder.encode(entry)
            return String(decoding: data, as: UTF8.self)
        }
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func indexShardURL(for year: String, archiveRoot: URL) -> URL {
        Self.indexRoot(for: archiveRoot).appendingPathComponent("index-\(year).jsonl")
    }

    private func entryKey(_ entry: ArchiveIndexEntry) -> String {
        "\(entry.kind.rawValue)|\(entry.archiveRelativePath)"
    }

    private func yearsPossiblyContaining(paths: Set<String>) -> Set<String> {
        Set(paths.compactMap { $0.split(separator: "/").first.map(String.init) })
    }

    private func existingThumbnailRelativePath(for archiveFileURL: URL, archiveRoot: URL) -> String? {
        let thumbnailURL = Self.thumbnailURL(for: archiveFileURL, archiveRoot: archiveRoot)
        guard fileManager.fileExists(atPath: thumbnailURL.path) else { return nil }
        return Self.archiveRelativePath(for: thumbnailURL, archiveRoot: archiveRoot)
    }

    private func subdirectories(of url: URL) -> [URL] {
        ((try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { $0.lastPathComponent != "_index" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func jpegData(from image: NSImage, compressionQuality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func exifSummary(cameraModel: String?, lensModel: String?, pixelWidth: Int?, pixelHeight: Int?) -> String? {
        var parts: [String] = []
        if let cameraModel { parts.append(cameraModel) }
        if let lensModel { parts.append(lensModel) }
        if let pixelWidth, let pixelHeight { parts.append("\(pixelWidth)x\(pixelHeight)") }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    private func firstHeading(in text: String) -> String? {
        text.split(separator: "\n").first { $0.hasPrefix("# ") }.map { String($0.dropFirst(2)) }
    }

    private func firstBacktickedValue(after label: String, in text: String) -> String? {
        guard let line = text.components(separatedBy: "## Notes")[0].split(separator: "\n").map(String.init).first(where: { $0.hasPrefix("- " + label) }),
              let first = line.firstIndex(of: "`"),
              let last = line.lastIndex(of: "`"),
              first < last else { return nil }
        return String(line[line.index(after: first)..<last])
    }

    private func firstValue(after label: String, in text: String) -> String? {
        text.components(separatedBy: "## Notes")[0].split(separator: "\n").map(String.init)
            .first { $0.hasPrefix("- " + label) }?
            .components(separatedBy: label)
            .last?
            .trimmingCharacters(in: .whitespaces)
    }

    private func notesSection(in text: String) -> String {
        guard let range = text.range(of: "## Notes") else { return "" }
        let after = text[range.upperBound...]
        if let next = ArchiveManifestText.sourceReport(in: text), next.lowerBound > range.upperBound {
            return String(after[..<next.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(after).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func yamlValue(_ key: String, in text: String) -> String? {
        ArchiveManifestText.scalar(key, in: text)
    }

    private func yamlList(_ key: String, in text: String) -> [String] {
        let lines = ArchiveManifestText.frontmatter(in: text).split(separator: "\n").map(String.init)
        guard let start = lines.firstIndex(where: { $0 == "\(key):" }) else { return [] }
        var values: [String] = []
        for line in lines[(start + 1)...] {
            guard line.hasPrefix("  - ") else { break }
            var value = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = ArchiveManifestText.unquote(value)
            }
            values.append(value)
        }
        return values
    }
}

enum ArchiveFileProviderEvictor {
    static func evict(_ url: URL) async throws {
        try await ArchiveAsyncOperation.withTimeout(seconds: 30) { try await evictWithoutTimeout(url) }
    }

    private static func evictWithoutTimeout(_ url: URL) async throws {
        let (manager, identifier) = try await managerAndIdentifier(url)
        try await ArchiveAsyncOperation.callback { (complete: @escaping (Result<Void, Error>) -> Void) in
            manager.evictItem(identifier: identifier) { error in
                if let error {
                    complete(.failure(error))
                } else {
                    complete(.success(()))
                }
            }
        }
    }
    static func requestDownload(_ url: URL) async throws {
        let (manager, identifier) = try await managerAndIdentifier(url)
        try await ArchiveAsyncOperation.callback { (complete: @escaping (Result<Void, Error>) -> Void) in
            manager.requestDownloadForItem(withIdentifier: identifier) { error in
                if let error { complete(.failure(error)) } else { complete(.success(())) }
            }
        }
    }

    private static func managerAndIdentifier(_ url: URL) async throws -> (NSFileProviderManager, NSFileProviderItemIdentifier) {
        let identifiers = try await ArchiveAsyncOperation.callback {
            (complete: @escaping (Result<(NSFileProviderItemIdentifier, NSFileProviderDomainIdentifier), Error>) -> Void) in
            NSFileProviderManager.getIdentifierForUserVisibleFile(at: url) { itemIdentifier, domainIdentifier, error in
                if let error {
                    complete(.failure(error))
                } else if let itemIdentifier, let domainIdentifier {
                    complete(.success((itemIdentifier, domainIdentifier)))
                } else {
                    complete(.failure(NSError(
                        domain: "ArchiveFileProviderEvictor",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The file is not managed by a File Provider domain."]
                    )))
                }
            }
        }
        let domains = try await ArchiveAsyncOperation.callback {
            (complete: @escaping (Result<[NSFileProviderDomain], Error>) -> Void) in
            NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
                if let error {
                    complete(.failure(error))
                } else {
                    complete(.success(domains))
                }
            }
        }
        guard let domain = domains.first(where: { $0.identifier == identifiers.1 }),
              let manager = NSFileProviderManager(for: domain) else {
            throw NSError(
                domain: "ArchiveFileProviderEvictor",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The File Provider manager is unavailable."]
            )
        }
        return (manager, identifiers.0)
    }

}

actor ArchiveIndexMutationQueue {
    static let shared = ArchiveIndexMutationQueue()

    private let store: ArchiveIndexStore
    private var rebuildTasks: [String: Task<ArchiveIndexRebuildResult, Error>] = [:]

    init(store: ArchiveIndexStore = ArchiveIndexStore()) {
        self.store = store
    }

    func saveLocation(target: ArchiveLocationTarget, name: String, coordinate: ArchiveCoordinate?, archiveRoot: URL) throws -> ArchiveLocationSaveResult {
        try ArchiveLocationEditor().save(target: target, name: name, coordinate: coordinate, archiveRoot: archiveRoot)
    }

    func resumeLocation(walkRelativePath: String, archiveRoot: URL) throws -> ArchiveLocationSaveResult {
        try ArchiveLocationEditor().resume(walkRelativePath: walkRelativePath, archiveRoot: archiveRoot)
    }

    func updateAfterImport(result: ImportResult, policy: ArchiveIndexWritePolicy) async throws {
        guard policy.canWriteIndex else { return }
        let archiveRoot = result.session.archiveRoot
        var thumbnailPaths: [String: String] = [:]
        for fileManifest in result.fileManifests {
            let fileURL = URL(fileURLWithPath: fileManifest.archivePath)
            let relativePath = ArchiveIndexStore.archiveRelativePath(for: fileURL, archiveRoot: archiveRoot)
                ?? fileManifest.archiveRelativePath
                ?? fileURL.lastPathComponent
            do {
                let thumbnailURL = try await store.generateThumbnail(for: fileURL, archiveRoot: archiveRoot)
                if let thumbnailPath = ArchiveIndexStore.archiveRelativePath(for: thumbnailURL, archiveRoot: archiveRoot) {
                    thumbnailPaths[relativePath] = thumbnailPath
                }
            } catch {
                continue
            }
        }

        // Thumbnail work can suspend this actor. Always re-read canonical metadata
        // afterwards, so a more recent edit or append cannot be overwritten by old results.
        let walkFolders = result.walkManifests.map(\.archiveFolder)
        let tripFolders = Array(Set(walkFolders.map { $0.deletingLastPathComponent() }))
        try replaceWalkFolders(walkFolders, archiveRoot: archiveRoot, policy: policy, tripFolders: tripFolders)
    }

    func replaceWalkFolders(_ walkFolders: [URL], archiveRoot: URL, policy: ArchiveIndexWritePolicy,
        removingWalkPaths: Set<String> = [], tripFolders: [URL] = []) throws {
        guard policy.canWriteIndex else { return }
        try store.replaceWalkFolders(walkFolders, archiveRoot: archiveRoot,
            removingWalkPaths: removingWalkPaths, tripFolders: tripFolders)
    }

    func backfillThumbnails(
        archiveRoot: URL,
        supportedExtensions: Set<String>,
        policy: ArchiveIndexWritePolicy,
        photoURLs: [URL]? = nil,
        cachedThumbnailURLsByPhotoPath: [String: URL] = [:],
        progress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async -> ArchiveIndexThumbnailResult? {
        guard policy.canWriteIndex else { return nil }
        return await store.backfillThumbnails(
            archiveRoot: archiveRoot,
            supportedExtensions: supportedExtensions,
            photoURLs: photoURLs,
            cachedThumbnailURLsByPhotoPath: cachedThumbnailURLsByPhotoPath,
            progress: progress
        )
    }

    func rebuildIndex(archiveRoot: URL, policy: ArchiveIndexWritePolicy) async throws -> ArchiveIndexRebuildResult? {
        guard policy.canWriteIndex else { return nil }
        let key = archiveRoot.resolvingSymlinksInPath().standardizedFileURL.path
        if let task = rebuildTasks[key] {
            return try await task.value
        }

        let task = Task<ArchiveIndexRebuildResult, Error> {
            try store.rebuildIndex(archiveRoot: archiveRoot)
        }
        rebuildTasks[key] = task
        defer { rebuildTasks[key] = nil }
        return try await task.value
    }
}
