import Foundation

enum LocationAssignmentOrigin: Equatable, Sendable {
    case sourceWalk(UUID)
    case archive(ArchiveLocationTarget)
}

struct LocationAssignmentContext: Equatable, Sendable {
    let key: String
    let title: String
    let origin: LocationAssignmentOrigin
    let archiveRoot: URL
    let name: String
    let coordinate: ArchiveCoordinate?
    let isMixed: Bool
    let hasSavedAssignment: Bool
}

enum ArchiveLocationProjection {
    static func applying(_ result: ArchiveLocationSaveResult, to initial: ArchiveCatalogue) -> ArchiveCatalogue {
        var catalogue = initial
        guard let trip = catalogue.walksByTripPath.first(where: { $0.value.contains { $0.archiveRelativePath == result.target.walkRelativePath } })?.key,
              let walkIndex = catalogue.walksByTripPath[trip]?.firstIndex(where: { $0.archiveRelativePath == result.target.walkRelativePath }) else { return catalogue }
        if result.target.photos.isEmpty {
            catalogue.walksByTripPath[trip]![walkIndex].location = result.name.nonEmpty
            catalogue.walksByTripPath[trip]![walkIndex].latitude = result.coordinate?.latitude
            catalogue.walksByTripPath[trip]![walkIndex].longitude = result.coordinate?.longitude
            catalogue.walksByTripPath[trip]![walkIndex].coordinateSource = result.coordinate == nil ? nil : .walkPin
        }
        let walk = catalogue.walksByTripPath[trip]![walkIndex]
        let targets = Dictionary(uniqueKeysWithValues: result.target.photos.map { ($0.archiveRelativePath, $0.mediaItemID) })
        for index in catalogue.photos.indices {
            guard catalogue.photos[index].walkPath == walk.archiveRelativePath else { continue }
            if targets[catalogue.photos[index].archiveRelativePath] == catalogue.photos[index].mediaItemID,
               targets[catalogue.photos[index].archiveRelativePath] != nil {
                catalogue.photos[index].locationOverride = result.photoOverride
            }
        }
        let byPath = Dictionary(uniqueKeysWithValues: catalogue.photos.map { ($0.archiveRelativePath, $0) })
        for index in catalogue.photos.indices {
            guard catalogue.photos[index].walkPath == walk.archiveRelativePath else { continue }
            var photo = catalogue.photos[index]
            if photo.isDerivedPhoto, let original = rootPhoto(for: photo, in: byPath) {
                photo.locationOverride = original.locationOverride
                photo.gpsLatitude = original.gpsLatitude
                photo.gpsLongitude = original.gpsLongitude
            }
            // Older index rows identified as GPS can supply the raw fallback until a main rebuild.
            let gps = ArchiveCoordinate(latitude: photo.gpsLatitude, longitude: photo.gpsLongitude)
                ?? (photo.coordinateSource == .photoGPS ? ArchiveCoordinate(latitude: photo.latitude, longitude: photo.longitude) : nil)
            if photo.gpsLatitude == nil { photo.gpsLatitude = gps?.latitude; photo.gpsLongitude = gps?.longitude }
            let pin = ArchiveCoordinate(latitude: walk.latitude, longitude: walk.longitude)
            let coordinate = photo.locationOverride?.coordinate ?? pin ?? gps
            photo.latitude = coordinate?.latitude; photo.longitude = coordinate?.longitude
            photo.location = photo.locationOverride?.name.nonEmpty ?? walk.location
            photo.coordinateSource = photo.locationOverride?.coordinate != nil ? (photo.locationOverride!.isShared ? .sharedOverride : .photoOverride)
                : (pin != nil ? .walkPin : (gps != nil ? .photoGPS : nil))
            catalogue.photos[index] = photo
        }
        return catalogue
    }

    private static func rootPhoto(for photo: ArchivePhotoSummary, in photos: [String: ArchivePhotoSummary]) -> ArchivePhotoSummary? {
        var current = photo, seen: Set<String> = []
        while current.isDerivedPhoto {
            guard seen.insert(current.archiveRelativePath).inserted,
                  let path = current.originalPhotoPath, let parent = photos[path] else { return nil }
            current = parent
        }
        return current
    }
}
