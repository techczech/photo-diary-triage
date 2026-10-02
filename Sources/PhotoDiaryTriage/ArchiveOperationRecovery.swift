import CryptoKit
import Darwin
import Foundation

enum ArchiveFileVerification {
    static func sha256(at url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw failure("Verification requires a regular file: \(url.lastPathComponent)")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            try Task.checkCancellation()
            digest.update(data: data)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    static func verify(source: URL, destination: URL, expectedSHA256: String? = nil) throws -> String {
        let sourceDigest = try sha256(at: source)
        let destinationDigest = try sha256(at: destination)
        guard sourceDigest == destinationDigest,
              expectedSHA256.map({ $0 == sourceDigest }) ?? true else {
            throw failure("File contents do not match the verified copy: \(source.lastPathComponent). The source has been retained.")
        }
        return sourceDigest
    }

    static func failure(_ message: String) -> NSError {
        NSError(domain: "ArchiveFileVerification", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

// Recovery is canonical operation state, deliberately outside the disposable index.
struct ArchiveOperationRecovery {
    let archiveRoot: URL

    var root: URL { archiveRoot.appendingPathComponent(".walkfolio-recovery", isDirectory: true) }

    func url(kind: String, sessionID: UUID) -> URL {
        root.appendingPathComponent("\(kind)-\(sessionID.uuidString).json")
    }

    func load<T: Decodable>(_ type: T.Type, kind: String, sessionID: UUID) throws -> T? {
        let path = url(kind: kind, sessionID: sessionID)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: path))
    }

    func save<T: Encodable>(_ record: T, kind: String, sessionID: UUID) throws {
        try AppDirectories.ensureExists(root)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let path = url(kind: kind, sessionID: sessionID)
        try encoder.encode(record).write(to: path, options: .atomic)
        let handle = try FileHandle(forWritingTo: path)
        defer { try? handle.close() }
        try handle.synchronize()
    }
}

final class ArchiveMutationLock {
    private let descriptor: Int32

    init(archiveRoot: URL) throws {
        let recovery = ArchiveOperationRecovery(archiveRoot: archiveRoot)
        try AppDirectories.ensureExists(recovery.root)
        descriptor = Darwin.open(recovery.root.appendingPathComponent("archive.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw ArchiveFileVerification.failure("Could not lock the Archive for this operation.") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            throw ArchiveFileVerification.failure("Another Archive operation is running. Please retry after it finishes.")
        }
    }

    deinit {
        flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }
}

struct ImportRecoveryRecord: Codable {
    var operationID = UUID()
    var session: ImportSession
    var plans: [ArchiveCommitPlan]
    var originalSession: ImportSession? = nil
    var sha256ByDestination: [String: String] = [:]
    var complete = false

    var mediaItemIDs: Set<UUID> {
        Set(plans.flatMap(\.entries).map(\.mediaItemID))
    }
}

struct CleanupRecoveryEntry: Codable {
    var mediaItemID: UUID
    var companionFileID: UUID?
    var source: URL
    var destination: URL
    var sha256: String
    var deletionStarted = false
    var deletedAt: Date?
}

struct CleanupRecoveryRecord: Codable {
    var entries: [CleanupRecoveryEntry] = []
}

struct ImportFileCheckpoint: Codable {
    var sha256: String
    var importedAt: Date?
}


enum ArchivePathSafety {
    static func resolvedForWrite(_ url: URL) -> URL {
        var ancestor = url.standardizedFileURL
        var suffix: [String] = []
        while !FileManager.default.fileExists(atPath: ancestor.path) && ancestor.path != "/" {
            suffix.insert(ancestor.lastPathComponent, at: 0)
            ancestor.deleteLastPathComponent()
        }
        return suffix.reduce(ancestor.resolvingSymlinksInPath()) { $0.appendingPathComponent($1) }
    }
}
