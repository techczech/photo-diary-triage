import Foundation

enum ArchiveCoordinateSource: String, Codable, Hashable, Sendable {
    case walkPin = "walk_pin"
    case photoGPS = "photo_gps"
    case gpsCentroid = "gps_centroid"
    case photoOverride = "photo_override"
    case sharedOverride = "shared_override"
    case photoCentroid = "photo_centroid"
    case legacy = "legacy"

    var title: String {
        switch self {
        case .walkPin: return "Walk pin"
        case .photoGPS: return "Photo GPS"
        case .gpsCentroid: return "Photo GPS centroid"
        case .photoOverride: return "Photo assignment"
        case .sharedOverride: return "Shared assignment"
        case .photoCentroid: return "Photo location centroid"
        case .legacy: return "Recorded location"
        }
    }
}

struct ArchiveCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init?(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude, latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    static func centroid(_ coordinates: [ArchiveCoordinate]) -> ArchiveCoordinate? {
        guard !coordinates.isEmpty else { return nil }
        var x = 0.0, y = 0.0, z = 0.0
        for coordinate in coordinates {
            let latitude = coordinate.latitude * .pi / 180
            let longitude = coordinate.longitude * .pi / 180
            x += cos(latitude) * cos(longitude)
            y += cos(latitude) * sin(longitude)
            z += sin(latitude)
        }
        let magnitude = sqrt(x*x + y*y + z*z)
        guard magnitude / Double(coordinates.count) > 1e-9 else { return nil }
        return ArchiveCoordinate(latitude: atan2(z, sqrt(x*x + y*y)) * 180 / .pi,
            longitude: atan2(y, x) * 180 / .pi)
    }
}

struct ArchiveMapWalk: Identifiable, Equatable, Sendable {
    var id: String { archiveRelativePath }
    let archiveRelativePath: String
    let tripPath: String
    let title: String
    let location: String?
    let date: Date?
    let photoCount: Int
    let coordinate: ArchiveCoordinate?
    let coordinateSource: ArchiveCoordinateSource?
}

struct ArchiveMapSnapshot: Equatable, Sendable {
    let walks: [ArchiveMapWalk]
    let unlocatedHistoricalFolders: [ArchiveBrowseEntry]
    var locatedWalks: [ArchiveMapWalk] { walks.filter { $0.coordinate != nil } }
    var unlocatedWalks: [ArchiveMapWalk] { walks.filter { $0.coordinate == nil } }
    static let empty = ArchiveMapSnapshot(walks: [], unlocatedHistoricalFolders: [])
}

enum ArchiveMapProjection {
    static func snapshot(catalogue: ArchiveCatalogue, visibleEntries: [ArchiveBrowseEntry],
                         searchQuery: String, matchingPaths: Set<String>) -> ArchiveMapSnapshot {
        let visibleTrips = Set(visibleEntries.filter { $0.kind == .trip }.map(\.archiveRelativePath))
        let hasSearch = !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let photosByWalk = Dictionary(grouping: catalogue.photos.filter { $0.walkPath != nil }) { $0.walkPath! }
        let walks = catalogue.walksByTripPath.values.flatMap { $0 }.filter { walk in
            guard visibleTrips.contains(walk.tripPath) else { return false }
            return !hasSearch || matchingPaths.contains(walk.tripPath) || matchingPaths.contains(walk.archiveRelativePath)
                || matchingPaths.contains { $0.hasPrefix(walk.archiveRelativePath + "/") }
        }.map { walk in
            let photos = photosByWalk[walk.archiveRelativePath] ?? []
            let pin = ArchiveCoordinate(latitude: walk.latitude, longitude: walk.longitude)
            let gps = photos.filter { !$0.isDerivedPhoto && $0.cropRole != .crop && [.photoGPS, .photoOverride, .sharedOverride].contains($0.coordinateSource) }
                .compactMap { ArchiveCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
            let centroid = ArchiveCoordinate.centroid(gps)
            return ArchiveMapWalk(archiveRelativePath: walk.archiveRelativePath, tripPath: walk.tripPath,
                title: walk.title, location: walk.location, date: walk.date, photoCount: walk.photoCount,
                coordinate: pin ?? centroid, coordinateSource: pin != nil ? (walk.coordinateSource ?? .legacy) : (centroid != nil ? (photos.contains { [.photoOverride, .sharedOverride].contains($0.coordinateSource) } ? .photoCentroid : .gpsCentroid) : nil))
        }.sorted { $0.archiveRelativePath < $1.archiveRelativePath }
        return ArchiveMapSnapshot(walks: walks,
            unlocatedHistoricalFolders: visibleEntries.filter { $0.kind == .unorganisedFolder })
    }
}
