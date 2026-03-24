import Foundation

protocol CaptionProvider {
    func caption(for fileURL: URL) async throws -> String
}

protocol TrackCorrelationProvider {
    func correlate(files: [URL]) async throws -> [URL: String]
}

protocol MapReferenceProvider {
    func reference(for latitude: Double, longitude: Double) async throws -> String
}

enum IntegrationUnavailable: Error {
    case notImplemented
}

struct StubCaptionProvider: CaptionProvider {
    func caption(for fileURL: URL) async throws -> String {
        throw IntegrationUnavailable.notImplemented
    }
}

struct StubTrackCorrelationProvider: TrackCorrelationProvider {
    func correlate(files: [URL]) async throws -> [URL: String] {
        throw IntegrationUnavailable.notImplemented
    }
}

struct StubMapReferenceProvider: MapReferenceProvider {
    func reference(for latitude: Double, longitude: Double) async throws -> String {
        throw IntegrationUnavailable.notImplemented
    }
}
