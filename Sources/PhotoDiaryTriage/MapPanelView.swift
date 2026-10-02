import CoreLocation
import MapKit
import SwiftUI

/// Inline map panel above the review grid.
/// Plots effective photo locations. Assignment follows the active Walk or selected
/// canonical originals; source Walk pins persist on the current Photo Log.
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
            guard let point = ArchiveCoordinate(latitude: snapshot.item.metadata.latitude,
                                                 longitude: snapshot.item.metadata.longitude) else { return nil }
            return PhotoAnnotation(
                id: snapshot.id,
                coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                label: snapshot.item.compactDisplayName
            )
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            if (appState.locationAssignmentContext != nil) {
                assignmentBar
            }
            mapBody
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .onAppear { syncFromWalkIfNeeded() }
        .onChange(of: appState.locationAssignmentContext) { _, _ in
            didSync = false
            syncFromWalkIfNeeded()
        }
        .onChange(of: appState.locationAssignmentKey) { _, _ in
            didSync = false
            syncFromWalkIfNeeded()
        }
    }

    // MARK: Assignment bar (C.2)

    private var assignmentBar: some View {
        let context = appState.locationAssignmentContext
        let name = locationName, latitude = pinCoordinate?.latitude, longitude = pinCoordinate?.longitude
        let centre = mapCenter
        return CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .location,
            contextKey: localCommandContextKey([context?.key ?? "", name, String(describing: latitude), String(describing: longitude),
                String(describing: centre?.latitude), String(describing: centre?.longitude)]),
            actions: [
                .saveLocation: .init(enabled: context != nil && hasUnsavedChanges && !appState.isSavingLocation,
                    run: { Task { await appState.saveContextLocation(name: name, latitude: latitude, longitude: longitude, context: context) } }),
                .clearLocation: .init(enabled: context != nil && walkHasSavedLocation && !appState.isSavingLocation,
                    run: { locationName = ""; pinCoordinate = nil; Task { await appState.saveContextLocation(name: "", latitude: nil, longitude: nil, context: context) } }),
                .retryLocationSave: .init(enabled: appState.canRetryArchiveLocationSave && !appState.isSavingLocation,
                    run: { Task { await appState.retryArchiveLocationSave(context: context) } }),
                .pinLocationAtMapCentre: .init(enabled: centre != nil && !appState.isSavingLocation, run: { pinCoordinate = centre })
            ]) { commands in
            HStack(spacing: 8) {
                Text(appState.locationAssignmentContext?.title ?? "Location")
                    .font(.caption)
                TextField(appState.locationAssignmentContext?.isMixed == true ? "Mixed locations — assign a new pin" : "Location (e.g. Blenheim Park)", text: $locationName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180, maxWidth: 320)

                Button {
                    commands.run(.pinLocationAtMapCentre)
                } label: {
                    Label("Pin to map centre", systemImage: "mappin")
                }
                .controlSize(.small)
                .disabled(mapCenter == nil)
                .help("Drop the location pin at the centre of the map (or click directly on the map)")

                Button("Save Location") { commands.run(.saveLocation) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!hasUnsavedChanges || appState.isSavingLocation)
                    .commandShortcutHint([.saveLocation], appState: appState, scope: .locationEditor, help: "Save this location assignment.")

                if walkHasSavedLocation {
                    Button("Clear") { commands.run(.clearLocation) }
                        .controlSize(.small)
                }

                if appState.canRetryArchiveLocationSave {
                    Button("Retry unfinished save") { commands.run(.retryLocationSave) }
                        .controlSize(.small)
                }
                Spacer(minLength: 0)

                Text(pinStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .disabled(appState.isSavingLocation)
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
            if !(appState.locationAssignmentContext != nil) && photoAnnotations.isEmpty {
                ContentUnavailableView(
                    "No recorded locations",
                    systemImage: "mappin.slash",
                    description: Text("Location editing needs a canonical Walk and original-photo records.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            } else {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        ForEach(photoAnnotations) { annotation in
                            Marker(annotation.label, coordinate: annotation.coordinate)
                                .tint(.blue)
                        }
                        if let pinCoordinate {
                            Marker(appState.locationAssignmentContext?.title ?? "Location", systemImage: "mappin", coordinate: pinCoordinate)
                                .tint(.orange)
                        }
                    }
                    .onTapGesture { point in
                        guard appState.locationAssignmentContext != nil, !appState.isSavingLocation,
                              let coordinate = proxy.convert(point, from: .local) else { return }
                        pinCoordinate = coordinate
                    }
                    .onMapCameraChange(frequency: .continuous) { context in
                        mapCenter = context.region.center
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: State sync + persistence

    private var savedCoordinate: CLLocationCoordinate2D? {
        guard let coordinate = appState.locationAssignmentContext?.coordinate else { return nil }
        return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var walkHasSavedLocation: Bool {
        appState.locationAssignmentContext?.hasSavedAssignment == true
    }

    private var hasUnsavedChanges: Bool {
        locationName.trimmingCharacters(in: .whitespacesAndNewlines) != (appState.locationAssignmentContext?.name ?? "")
            || !coordinatesEqual(pinCoordinate, savedCoordinate)
    }

    private func syncFromWalkIfNeeded() {
        guard !didSync else { return }
        didSync = true
        locationName = (appState.locationAssignmentContext?.name ?? "")
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
