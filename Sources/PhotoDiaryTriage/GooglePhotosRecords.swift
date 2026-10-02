import Foundation

enum GooglePhotosScopeKind: String, Codable, Sendable { case trip, photoLog }
struct GooglePhotosAlbumBinding: Codable, Hashable, Sendable {
    var operationID: UUID
    var accountID: String
    var clientID: String
    var scopeID: UUID
    var scopeKind: GooglePhotosScopeKind
    var album: GooglePhotosAlbum
    var recordedAt: Date
}
struct GooglePhotosMembership: Codable, Hashable, Sendable {
    var operationID: UUID
    var accountID: String
    var clientID: String
    var scopeID: UUID
    var photoID: UUID
    var albumID: String
    var media: GooglePhotosCreatedMedia
    var originalPathAtDelivery: String
    var originalSHA256: String
    var originalSize: Int64
    var membershipVerifiedAt: Date
}
struct GooglePhotosManualMark: Codable, Hashable, Sendable {
    var id = UUID()
    var markedAt = Date()
    var note: String
}
struct GooglePhotosRecord: Codable, Hashable, Sendable {
    var albums: [GooglePhotosAlbumBinding] = []
    var memberships: [GooglePhotosMembership] = []
    var manualMarks: [GooglePhotosManualMark] = []
    var badge: String? {
        if !memberships.isEmpty { return "Google Photos: \(Set(memberships.map(\.photoID)).count) verified" }
        return manualMarks.isEmpty ? nil : "Marked previously uploaded"
    }
    func coverageBadge(total: Int) -> String? {
        let groups = Dictionary(grouping: memberships) { $0.accountID + "|" + $0.albumID }
        let count = groups.values.map { Set($0.map(\.photoID)).count }.max() ?? 0
        return count > 0 ? "Google Photos: \(count)/\(total) originals recorded" : badge
    }
    private static let start = "\n## Google Photos\n<!-- walkfolio-google-photos:v1 -->\n```json\n"
    private static let end = "\n```\n<!-- /walkfolio-google-photos -->"
    private static func range(in text: String) throws -> Range<String.Index>? {
        let count = text.components(separatedBy: "\n").filter { $0 == "<!-- walkfolio-google-photos:v1 -->" }.count
        guard count <= 1 else { throw ArchiveFileVerification.failure("Conflicting Google Photos facts have been retained.") }
        guard count == 1 else { return nil }
        guard let start = text.range(of: Self.start), let end = text.range(of: Self.end, range: start.upperBound..<text.endIndex) else { throw ArchiveFileVerification.failure("The Google Photos fact section is incomplete. Its text has been retained.") }
        return start.lowerBound..<end.upperBound
    }
    static func read(in text: String) throws -> Self? {
        guard let range = try range(in: text) else { return nil }
        let a = text.index(range.lowerBound, offsetBy: start.count), b = text.index(range.upperBound, offsetBy: -end.count)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let value = try decoder.decode(Self.self, from: Data(text[a..<b].utf8))
        guard value.albums.allSatisfy({ $0.accountID.nonEmpty != nil && $0.clientID.nonEmpty != nil && $0.album.id.nonEmpty != nil }),
              value.memberships.allSatisfy({ $0.accountID.nonEmpty != nil && $0.albumID.nonEmpty != nil && $0.media.id.nonEmpty != nil && $0.originalSHA256.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil && $0.originalSize > 0 }) else { throw ArchiveFileVerification.failure("The Google Photos membership record is invalid.") }
        return value
    }
    static func removing(in text: String) throws -> String {
        guard let range = try range(in: text) else { return text }; var value = text; value.removeSubrange(range); return value
    }
    func setting(in text: String) throws -> String {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let block = Self.start + String(decoding: try encoder.encode(self), as: UTF8.self) + Self.end
        if let range = try Self.range(in: text) { var value = text; value.replaceSubrange(range, with: block); return value }
        return text + "\n" + block + "\n"
    }
    mutating func add(_ binding: GooglePhotosAlbumBinding) throws {
        if let old = albums.first(where: { $0.accountID == binding.accountID && $0.scopeID == binding.scopeID && $0.scopeKind == binding.scopeKind }) {
            guard old.album.id == binding.album.id, old.clientID == binding.clientID else { throw ArchiveFileVerification.failure("This Trip or Photo Log already belongs to another recorded album. Its binding has been retained.") }; return
        }
        albums.append(binding)
    }
    mutating func add(_ member: GooglePhotosMembership) {
        if !memberships.contains(where: { $0.accountID == member.accountID && $0.albumID == member.albumID && $0.photoID == member.photoID && $0.originalSHA256 == member.originalSHA256 }) { memberships.append(member) }
    }
}
