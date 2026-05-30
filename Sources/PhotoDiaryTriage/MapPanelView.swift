import CoreLocation
import MapKit
import SwiftUI

/// Inline map panel above the review grid.
/// - C.1: plots photos in the current context that carry GPS coordinates.
/// - C.2: assign a location (name + dropped pin) to the current walk; persisted on the session.
struct MapPanelView: View {
    @ObservedObject var appState: AppState
    let items: [ReviewItemSnapshot]

    @State private var locationName: String = ""
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var didSync = false

    private struct PhotoAnnotation: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let label: String
    }

    private var photoAnnotations: [PhotoAnnotation] {
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
        VStack(spacing: 6) {
            if appState.canAssignWalkLocation {
                assignmentBar
            }
            mapBody
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .onAppear { syncFromWalkIfNeeded() }
        .onChange(of: appState.currentSession?.id) { _, _ in
            didSync = false
            syncFromWalkIfNeeded()
        }
    }

    // MARK: Assignment bar (C.2)

    private var assignmentBar: some View {
        HStack(spacing: 8) {
            TextField("Location for this walk (e.g. Blenheim Park)", text: $locationName)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, maxWidth: 320)
                .onSubmit { saveLocation() }

            Button {
                pinCoordinate = mapCenter
            } label: {
                Label("Pin to map centre", systemImage: "mappin")
            }
            .controlSize(.small)
            .disabled(mapCenter == nil)
            .help("Drop the walk pin at the centre of the map (or click directly on the map)")

            Button("Save Location") { saveLocation() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasUnsavedChanges)

            if walkHasSavedLocation {
                Button("Clear") { clearLocation() }
                    .controlSize(.small)
            }

            Spacer(minLength: 0)

            Text(pinStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var pinStatus: String {
        if pinCoordinate == nil {
            return "Click the map (or use the button) to drop a pin"
        }
        return "Pin set — Save Location to keep it"
    }

    // MARK: Map

    private var mapBody: some View {
        Group {
            if !appState.canAssignWalkLocation && photoAnnotations.isEmpty {
                ContentUnavailableView(
                    "No GPS in these photos",
                    systemImage: "mappin.slash",
                    description: Text("These photos have no embedded location, and this view is read-only.")
                )
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            } else {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        ForEach(photoAnnotations) { annotation in
                            Marker(annotation.label, coordinate: annotation.coordinate)
                                .tint(.blue)
                        }
                        if let pinCoordinate {
                            Marker("This walk", systemImage: "figure.walk", coordinate: pinCoordinate)
                                .tint(.orange)
                        }
                    }
                    .onTapGesture { point in
                        guard appState.canAssignWalkLocation,
                              let coordinate = proxy.convert(point, from: .local) else { return }
                        pinCoordinate = coordinate
                    }
                    .onMapCameraChange(frequency: .continuous) { context in
                        mapCenter = context.region.center
                    }
                }
            }
        }
    }

    // MARK: State sync + persistence

    private var savedCoordinate: CLLocationCoordinate2D? {
        guard let coordinate = appState.currentWalkCoordinate else { return nil }
        return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var walkHasSavedLocation: Bool {
        !appState.currentWalkLocationName.isEmpty || savedCoordinate != nil
    }

    private var hasUnsavedChanges: Bool {
        locationName.trimmingCharacters(in: .whitespacesAndNewlines) != appState.currentWalkLocationName
            || !coordinatesEqual(pinCoordinate, savedCoordinate)
    }

    private func syncFromWalkIfNeeded() {
        guard !didSync else { return }
        didSync = true
        locationName = appState.currentWalkLocationName
        pinCoordinate = savedCoordinate
        if let coordinate = savedCoordinate ?? photoAnnotations.first?.coordinate {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            ))
        } else {
            cameraPosition = .automatic
        }
    }

    private func saveLocation() {
        appState.setCurrentWalkLocation(
            name: locationName,
            latitude: pinCoordinate?.latitude,
            longitude: pinCoordinate?.longitude
        )
    }

    private func clearLocation() {
        locationName = ""
        pinCoordinate = nil
        appState.setCurrentWalkLocation(name: "", latitude: nil, longitude: nil)
    }

    private func coordinatesEqual(_ lhs: CLLocationCoordinate2D?, _ rhs: CLLocationCoordinate2D?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return abs(left.latitude - right.latitude) < 0.000_001
                && abs(left.longitude - right.longitude) < 0.000_001
        default:
            return false
        }
    }
}
