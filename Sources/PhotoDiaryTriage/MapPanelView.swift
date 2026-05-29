import CoreLocation
import MapKit
import SwiftUI

/// Inline map panel shown above the review grid. C.1: plots the photos in the current
/// context that carry GPS coordinates. Location assignment (walk/day/cluster/photo) lands
/// in a later slice.
struct MapPanelView: View {
    let items: [ReviewItemSnapshot]

    private struct PhotoAnnotation: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let label: String
    }

    private var annotations: [PhotoAnnotation] {
        items.compactMap { snapshot in
            guard let latitude = snapshot.item.metadata.latitude,
                  let longitude = snapshot.item.metadata.longitude else { return nil }
            return PhotoAnnotation(
                id: snapshot.id,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                label: snapshot.item.compactDisplayName
            )
        }
    }

    var body: some View {
        let annotations = annotations
        Group {
            if annotations.isEmpty {
                ContentUnavailableView(
                    "No GPS in these photos",
                    systemImage: "mappin.slash",
                    description: Text("Photos here have no embedded location. Assigning locations to walks, days, and photos is coming in the next update.")
                )
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            } else {
                Map(initialPosition: .region(Self.region(for: annotations))) {
                    ForEach(annotations) { annotation in
                        Marker(annotation.label, coordinate: annotation.coordinate)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Text("\(annotations.count) located")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    /// Region that frames all annotations with padding; falls back to a small span for a single point.
    private static func region(for annotations: [PhotoAnnotation]) -> MKCoordinateRegion {
        let latitudes = annotations.map(\.coordinate.latitude)
        let longitudes = annotations.map(\.coordinate.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
            )
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
