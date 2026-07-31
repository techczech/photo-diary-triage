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
        tripPath: String?
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

    func shouldEvict(wasOnlineOnly: Bool, generatedThumbnail: Bool) -> Bool {
        wasOnlineOnly && generatedThumbnail
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
        guard machineRole == .travel, explicitDownload == false else { return true }
        guard isInsideArchive(url) else { return true }
        return isOnlineOnly(url) == false
    }

    func isOnlineOnly(_ url: URL) -> Bool {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
            let logicalSize = values.fileSize ?? 0
            let allocatedSize = values.totalFileAllocatedSize ?? logicalSize
            guard logicalSize > 16_384 else { return false }
            return allocatedSize <= 4_096 || logicalSize > max(allocatedSize, 1) * 16
        } catch {
            return false
        }
    }

    func isInsideArchive(_ url: URL) -> Bool {
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        return filePath == resolvedArchiveRootPath || filePath.hasPrefix(resolvedArchiveRootPath + "/")
    }
}

final class ArchiveByteReadPolicyContext: @unchecked Sendable {
    static let shared = ArchiveByteReadPolicyContext()

    private let lock = NSLock()
    private var policy = ArchiveByteReadPolicy(archiveRoot: URL(fileURLWithPath: "/", isDirectory: true), machineRole: .mainArchive)
    private var onlineOnlyVerdicts: [String: Bool] = [:]

    func update(settings: AppSettings) {
        lock.lock()
        policy = ArchiveByteReadPolicy(archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole)
        onlineOnlyVerdicts.removeAll()
        lock.unlock()
    }

    func canReadBytes(at url: URL, explicitDownload: Bool = false) -> Bool {
        if explicitDownload { return true }
        return isOnlineOnlyArchiveFile(url) == false
    }

    func isOnlineOnlyArchiveFile(_ url: URL) -> Bool {
        let current = snapshot()
        guard current.machineRole == .travel, current.isInsideArchive(url) else { return false }
        let key = url.standardizedFileURL.path
        lock.lock()
        if let cached = onlineOnlyVerdicts[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let verdict = current.isOnlineOnly(url)
        lock.lock()
        onlineOnlyVerdicts[key] = verdict
        lock.unlock()
        return verdict
    }

    func indexThumbnailURLIfAvailable(for archiveFileURL: URL) -> URL? {
        let current = snapshot()
        guard current.isInsideArchive(archiveFileURL) else { return nil }
        let url = ArchiveIndexStore.thumbnailURL(for: archiveFileURL, archiveRoot: current.archiveRoot)
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
            onlineOnlyVerdicts[key] = verdict
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

struct ArchiveIndexStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let backfillSafety: ArchiveThumbnailBackfillSafety
    let availableCapacityProvider: (URL) -> Int64?
    let evictor: (URL) async throws -> Void

    init(
        fileManager: FileManager = .default,
        backfillSafety: ArchiveThumbnailBackfillSafety = ArchiveThumbnailBackfillSafety(),
        availableCapacityProvider: @escaping (URL) -> Int64? = ArchiveIndexStore.availableCapacity,
        evictor: @escaping (URL) async throws -> Void = ArchiveFileProviderEvictor.evict
    ) {
        self.fileManager = fileManager
        self.backfillSafety = backfillSafety
        self.availableCapacityProvider = availableCapacityProvider
        self.evictor = evictor
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    static func indexRoot(for archiveRoot: URL) -> URL {
        archiveRoot.appendingPathComponent("_index", isDirectory: true)
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
        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

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
        try data.write(to: destination)
        return destination
    }

    func backfillThumbnails(
        archiveRoot: URL,
        supportedExtensions: Set<String>,
        throttleNanoseconds: UInt64 = 30_000_000,
        progress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async -> ArchiveIndexThumbnailResult {
        let photos = archivePhotos(in: archiveRoot, supportedExtensions: supportedExtensions)
        var result = ArchiveIndexThumbnailResult(
            scannedPhotos: photos.count,
            generatedThumbnails: 0,
            existingThumbnails: 0,
            failures: [],
            evictedFiles: 0,
            stoppedForLowSpace: false,
            cancelled: false
        )
        let bytePolicy = ArchiveByteReadPolicy(archiveRoot: archiveRoot, machineRole: .mainArchive)

        for (offset, url) in photos.enumerated() {
            if Task.isCancelled {
                result.cancelled = true
                break
            }
            do {
                let thumbnailURL = Self.thumbnailURL(for: url, archiveRoot: archiveRoot)
                if fileManager.fileExists(atPath: thumbnailURL.path) {
                    result.existingThumbnails += 1
                } else {
                    guard backfillSafety.hasSafeCapacity(availableCapacityProvider(archiveRoot)) else {
                        result.stoppedForLowSpace = true
                        break
                    }
                    let wasOnlineOnly = bytePolicy.isOnlineOnly(url)
                    if wasOnlineOnly {
                        let handle = try FileHandle(forReadingFrom: url)
                        _ = try handle.read(upToCount: 1)
                        try handle.close()
                    }
                    _ = try await generateThumbnail(for: url, archiveRoot: archiveRoot)
                    result.generatedThumbnails += 1
                    if backfillSafety.shouldEvict(wasOnlineOnly: wasOnlineOnly, generatedThumbnail: true) {
                        do {
                            try await evictor(url)
                            result.evictedFiles += 1
                        } catch {
                            result.failures.append("\(url.path): thumbnail generated, but the downloaded original could not be evicted: \(error.localizedDescription)")
                        }
                    }
                    if throttleNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: throttleNanoseconds)
                    }
                }
            } catch {
                result.failures.append("\(url.path): \(error.localizedDescription)")
            }
            if offset % 10 == 0 || offset == photos.indices.last {
                await progress?(offset + 1, photos.count)
            }
        }

        return result
    }

    private static func availableCapacity(at archiveRoot: URL) -> Int64? {
        try? archiveRoot.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    @discardableResult
    func rebuildIndex(archiveRoot: URL) throws -> ArchiveIndexRebuildResult {
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
        try AppDirectories.ensureExists(Self.indexRoot(for: archiveRoot), fileManager: fileManager)
        let years = Set(entries.map(\.year))
            .union(yearsPossiblyContaining(paths: removingArchiveRelativePaths))
            .union(yearsPossiblyContaining(paths: replacingWalkPaths))
            .union(yearsPossiblyContaining(paths: replacingTripPaths))

        for year in years {
            let shardURL = indexShardURL(for: year, archiveRoot: archiveRoot)
            var existing = try readEntries(from: shardURL)
            let replacementKeys = Set(entries.filter { $0.year == year }.map(entryKey))
            existing.removeAll { entry in
                replacementKeys.contains(entryKey(entry))
                    || removingArchiveRelativePaths.contains(entry.archiveRelativePath)
                    || entry.walkPath.map(replacingWalkPaths.contains) == true
                    || (entry.kind == .trip && entry.tripPath.map(replacingTripPaths.contains) == true)
                    || replacingWalkPaths.contains(entry.archiveRelativePath)
                    || (entry.kind == .trip && replacingTripPaths.contains(entry.archiveRelativePath))
            }
            existing.append(contentsOf: entries.filter { $0.year == year })
            existing.sort { lhs, rhs in
                if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
                return lhs.archiveRelativePath < rhs.archiveRelativePath
            }
            try writeEntries(existing, to: shardURL)
        }
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

    func entriesForWalkFolder(_ walkFolder: URL, archiveRoot: URL) -> [ArchiveIndexEntry] {
        guard let walkManifest = loadWalkManifest(folder: walkFolder, archiveRoot: archiveRoot) else { return [] }
        var entries = [entry(from: walkManifest, archiveRoot: archiveRoot)]
        for file in loadFileManifests(folder: walkFolder) {
            entries.append(photoEntry(from: file, walk: walkManifest, archiveRoot: archiveRoot))
        }
        return entries
    }

    func entryForTripFolder(_ tripFolder: URL, archiveRoot: URL) -> ArchiveIndexEntry {
        let tripManifest = TripManifestStore(fileManager: fileManager).loadTripManifest(folder: tripFolder, oneDrivePicturesRoot: archiveRoot)
        return entry(from: tripManifest, archiveRoot: archiveRoot)
    }

    private func replaceIndex(with entries: [ArchiveIndexEntry], archiveRoot: URL) throws {
        let indexRoot = Self.indexRoot(for: archiveRoot)
        try AppDirectories.ensureExists(indexRoot, fileManager: fileManager)
        for oldShard in (try? fileManager.contentsOfDirectory(at: indexRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            where oldShard.lastPathComponent.range(of: #"^index-.+\.jsonl$"#, options: .regularExpression) != nil {
            try? fileManager.removeItem(at: oldShard)
        }

        let byYear = Dictionary(grouping: entries) { $0.year }
        for (year, entries) in byYear {
            try writeEntries(entries.sorted { $0.archiveRelativePath < $1.archiveRelativePath }, to: indexShardURL(for: year, archiveRoot: archiveRoot))
        }
    }

    private func entriesFromArchive(archiveRoot: URL) throws -> [ArchiveIndexEntry] {
        var entries: [ArchiveIndexEntry] = []
        var walks: [WalkManifest] = []
        var explicitTripPaths = Set<String>()

        for manifestURL in structuralManifestURLs(archiveRoot: archiveRoot) {
            try Task.checkCancellation()
            let folder = manifestURL.deletingLastPathComponent()
            guard let text = try? String(contentsOf: manifestURL, encoding: .utf8) else { continue }

            if text.contains("Trip ID:") {
                let manifest = TripManifestStore(fileManager: fileManager)
                    .loadTripManifest(folder: folder, oneDrivePicturesRoot: archiveRoot)
                let tripEntry = entry(from: manifest, archiveRoot: archiveRoot)
                explicitTripPaths.insert(tripEntry.archiveRelativePath)
                entries.append(tripEntry)
            } else if text.contains("Session ID:"),
                      text.contains("Archive folder:"),
                      let walkManifest = loadWalkManifest(folder: folder, archiveRoot: archiveRoot) {
                walks.append(walkManifest)
                entries.append(entry(from: walkManifest, archiveRoot: archiveRoot))
                for file in loadFileManifests(folder: folder) {
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
        return entries
    }

    private func structuralManifestURLs(archiveRoot: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: archiveRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { entry -> URL? in
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
            tripPath: manifest.tripFolderRelativePath
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
        return ArchiveIndexEntry(
            kind: .photo,
            year: year,
            archiveRelativePath: relativePath,
            date: manifest.capturedAt.map(DateFormatting.iso8601.string(from:)),
            title: manifest.sourceFileName,
            location: manifest.walkLocation.nonEmpty,
            exifSummary: exifSummary(cameraModel: manifest.cameraModel, lensModel: manifest.lensModel, pixelWidth: manifest.pixelWidth, pixelHeight: manifest.pixelHeight),
            aiDescription: "",
            notes: manifest.notes,
            thumbnailPath: existingThumbnailRelativePath(for: fileURL, archiveRoot: archiveRoot),
            walkPath: walk.archiveFolderRelativePath,
            tripPath: walk.tripFolderRelativePath
        )
    }

    private func loadWalkManifest(folder: URL, archiveRoot: URL) -> WalkManifest? {
        let url = folder.appendingPathComponent("\(folder.lastPathComponent).md")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let title = firstHeading(in: text) ?? folder.lastPathComponent
        let sessionID = firstBacktickedValue(after: "Session ID:", in: text).flatMap(UUID.init(uuidString:)) ?? UUID()
        let walkID = firstBacktickedValue(after: "Walk ID:", in: text).flatMap(UUID.init(uuidString:))
        let sourceFolder = firstBacktickedValue(after: "Source folder:", in: text).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? folder
        let archiveFolder = firstBacktickedValue(after: "Archive folder:", in: text).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? folder
        let archiveRelativePath = firstBacktickedValue(after: "OneDrive Pictures relative folder:", in: text)
            ?? Self.archiveRelativePath(for: folder, archiveRoot: archiveRoot)
        let tripFolder = firstBacktickedValue(after: "Trip folder:", in: text)
        let walkDate = firstValue(after: "Walk date:", in: text).flatMap { DateFormatting.iso8601.date(from: $0) }
        let location = firstValue(after: "Location:", in: text) ?? ""
        let notes = notesSection(in: text)
        let files = loadFileManifests(folder: folder)
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

    private func loadFileManifests(folder: URL) -> [FileManifest] {
        let urls = ((try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension.lowercased() == "md" }
            .filter { $0.lastPathComponent != "\(folder.lastPathComponent).md" }

        return urls.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.contains("media_item_id:") else { return nil }
            return parseFileManifest(text: text)
        }
    }

    private func parseFileManifest(text: String) -> FileManifest? {
        guard let id = yamlValue("media_item_id", in: text).flatMap(UUID.init(uuidString:)),
              let archivePath = yamlValue("archive_path", in: text),
              let sourceFileName = yamlValue("source_file_name", in: text) else { return nil }
        let notes = text.components(separatedBy: "---").dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
        return FileManifest(
            mediaItemID: id,
            archivePath: archivePath,
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
            notes: notes
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
        guard let line = text.split(separator: "\n").map(String.init).first(where: { $0.contains(label) }),
              let first = line.firstIndex(of: "`"),
              let last = line.lastIndex(of: "`"),
              first < last else { return nil }
        return String(line[line.index(after: first)..<last])
    }

    private func firstValue(after label: String, in text: String) -> String? {
        text.split(separator: "\n").map(String.init)
            .first { $0.contains(label) }?
            .components(separatedBy: label)
            .last?
            .trimmingCharacters(in: .whitespaces)
    }

    private func notesSection(in text: String) -> String {
        guard let range = text.range(of: "## Notes") else { return "" }
        let after = text[range.upperBound...]
        if let next = after.range(of: "\n## ") {
            return String(after[..<next.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(after).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func yamlValue(_ key: String, in text: String) -> String? {
        guard let line = text.split(separator: "\n").map(String.init).first(where: { $0.hasPrefix("\(key):") }) else { return nil }
        var value = String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
            value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
        }
        return value
    }

    private func yamlList(_ key: String, in text: String) -> [String] {
        let lines = text.split(separator: "\n").map(String.init)
        guard let start = lines.firstIndex(where: { $0 == "\(key):" }) else { return [] }
        var values: [String] = []
        for line in lines[(start + 1)...] {
            guard line.hasPrefix("  - ") else { break }
            var value = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
            }
            values.append(value)
        }
        return values
    }
}

enum ArchiveFileProviderEvictor {
    static func evict(_ url: URL) async throws {
        let identifiers = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(NSFileProviderItemIdentifier, NSFileProviderDomainIdentifier), Error>) in
            NSFileProviderManager.getIdentifierForUserVisibleFile(at: url) { itemIdentifier, domainIdentifier, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let itemIdentifier, let domainIdentifier {
                    continuation.resume(returning: (itemIdentifier, domainIdentifier))
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "ArchiveFileProviderEvictor",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The file is not managed by a File Provider domain."]
                    ))
                }
            }
        }
        let domains = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[NSFileProviderDomain], Error>) in
            NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: domains)
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.evictItem(identifier: identifiers.0) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

actor ArchiveIndexMutationQueue {
    static let shared = ArchiveIndexMutationQueue()

    private let store: ArchiveIndexStore
    private var rebuildTasks: [String: Task<ArchiveIndexRebuildResult, Error>] = [:]

    init(store: ArchiveIndexStore = ArchiveIndexStore()) {
        self.store = store
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

        let entries = store.entriesForImport(result: result, archiveRoot: archiveRoot, generatedThumbnailPaths: thumbnailPaths)
        let walkPaths = Set(result.walkManifests.compactMap(\.archiveFolderRelativePath))
        let tripPaths = Set(result.tripManifests.compactMap(\.folderRelativePath))
            .union(Set(result.walkManifests.compactMap(\.tripFolderRelativePath)))
        try store.updateIndex(
            with: entries,
            archiveRoot: archiveRoot,
            replacingWalkPaths: walkPaths,
            replacingTripPaths: tripPaths
        )
    }

    func replaceWalkFolders(
        _ walkFolders: [URL],
        archiveRoot: URL,
        policy: ArchiveIndexWritePolicy,
        removingWalkPaths: Set<String> = [],
        tripFolders: [URL] = []
    ) throws {
        guard policy.canWriteIndex else { return }
        var entries: [ArchiveIndexEntry] = []
        for walkFolder in walkFolders {
            entries.append(contentsOf: store.entriesForWalkFolder(walkFolder, archiveRoot: archiveRoot))
        }
        entries.append(contentsOf: tripFolders.map { store.entryForTripFolder($0, archiveRoot: archiveRoot) })
        let walkPaths = removingWalkPaths.union(Set(entries.compactMap(\.walkPath)))
        let tripPaths = Set(entries.compactMap(\.tripPath))
        try store.updateIndex(
            with: entries,
            archiveRoot: archiveRoot,
            replacingWalkPaths: walkPaths,
            replacingTripPaths: tripPaths
        )
    }

    func backfillThumbnails(
        archiveRoot: URL,
        supportedExtensions: Set<String>,
        policy: ArchiveIndexWritePolicy,
        progress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async -> ArchiveIndexThumbnailResult? {
        guard policy.canWriteIndex else { return nil }
        return await store.backfillThumbnails(
            archiveRoot: archiveRoot,
            supportedExtensions: supportedExtensions,
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
