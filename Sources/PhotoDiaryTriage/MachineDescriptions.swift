import CryptoKit
import Foundation

enum DescriptionTargetKind: String, Codable, Sendable { case photo, walk, trip }
struct DescriptionReference: Codable, Hashable, Sendable {
    var kind: DescriptionTargetKind
    var path: String
    var identity: UUID
}
struct DescriptionChildEvidence: Codable, Hashable, Sendable {
    var target: DescriptionReference
    var baseline: String
    var revisionID: UUID
}
struct MachineDescriptionRevision: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var text: String
    var model: String
    var requestedModel: String
    var generatedAt: Date
    var endpoint: String
    var promptVersion: String
    var target: DescriptionReference
    var inputDigest: String
    var inputType: String
    var childEvidence: [DescriptionChildEvidence]
    var totalChildren: Int
    var coveredChildren: Int
    var sourceBaseline: String? = nil
    var coveredTargetIDs: [UUID] = []
}
struct MachineDescriptionHistory: Codable, Hashable, Sendable {
    var activeID: UUID
    var revisions: [MachineDescriptionRevision]
    var active: MachineDescriptionRevision? { revisions.first { $0.id == activeID } }

    private static let start = "\n## AI descriptions\n<!-- walkfolio-ai:v1 -->\n```json\n"
    private static let finish = "\n```\n<!-- /walkfolio-ai -->"

    private static func ownedRange(in text: String) throws -> Range<String.Index>? {
        let marker = "<!-- walkfolio-ai:v1 -->"
        let occurrences = text.components(separatedBy: "\n").filter { $0 == marker }.count
        guard occurrences <= 1 else { throw ArchiveFileVerification.failure("Conflicting machine-description sections have been retained.") }
        guard occurrences == 1 else { return nil }
        guard let start = text.range(of: Self.start), let end = text.range(of: finish, range: start.upperBound..<text.endIndex) else {
            throw ArchiveFileVerification.failure("The machine-description record is incomplete. Its text has been retained.")
        }
        return start.lowerBound..<end.upperBound
    }
    static func read(in text: String) throws -> Self? {
        guard let range = try ownedRange(in: text) else { return nil }
        let jsonStart = text.index(range.lowerBound, offsetBy: start.count)
        let jsonEnd = text.index(range.upperBound, offsetBy: -finish.count)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(Self.self, from: Data(text[jsonStart..<jsonEnd].utf8))
        guard result.active != nil, Set(result.revisions.map(\.id)).count == result.revisions.count,
              result.revisions.allSatisfy({ $0.text.nonEmpty != nil && $0.model.nonEmpty != nil }) else {
            throw ArchiveFileVerification.failure("The machine-description identity or provenance is invalid.")
        }
        return result
    }
    static func removing(in text: String) throws -> String {
        guard let range = try ownedRange(in: text) else { return text }
        var result = text; result.removeSubrange(range); return result
    }
    static func humanText(in text: String) -> String { (try? removing(in: text)) ?? text }
    func setting(in text: String) throws -> String {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let block = Self.start + String(decoding: try encoder.encode(self), as: UTF8.self) + Self.finish
        if let range = try Self.ownedRange(in: text) {
            var result = text; result.replaceSubrange(range, with: block); return result
        }
        return text + "\n" + block + "\n"
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func baseline(in text: String) throws -> String {
        digest(Data(try removing(in: text).trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    }
}
