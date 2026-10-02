import MapKit
import SwiftUI

struct ArchiveMapView: View {
    let snapshot: ArchiveMapSnapshot
    let selectedItemID: ArchiveMapItemID?
    let openWalk: (ArchiveMapWalk) -> Void
    let openFolder: (ArchiveBrowseEntry) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if snapshot.locatedWalks.isEmpty {
                    ContentUnavailableView("No located Walks", systemImage: "mappin.slash",
                        description: Text("Assign a Walk pin or record photo GPS on the Main Archive machine."))
                } else {
                    ClusteredArchiveMap(walks: snapshot.locatedWalks, openWalk: openWalk)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            ScrollViewReader { proxy in
                List {
                    Section("Located Walks · \(snapshot.locatedWalks.count)") {
                        ForEach(snapshot.locatedWalks) { walk in
                            Button { openWalk(walk) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(walk.title).font(.body.weight(.medium))
                                    Text([walk.location, walk.coordinateSource?.title].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                            .id(ArchiveMapItemID.walk(walk.archiveRelativePath))
                            .listRowBackground(selectedItemID == .walk(walk.archiveRelativePath) ? Color.accentColor.opacity(0.16) : Color.clear)
                        }
                    }
                    Section("Without a location · \(snapshot.unlocatedWalks.count)") {
                        ForEach(snapshot.unlocatedWalks) { walk in
                            Button(walk.title) { openWalk(walk) }.buttonStyle(.plain)
                                .id(ArchiveMapItemID.walk(walk.archiveRelativePath))
                                .listRowBackground(selectedItemID == .walk(walk.archiveRelativePath) ? Color.accentColor.opacity(0.16) : Color.clear)
                        }
                    }
                    if !snapshot.unlocatedHistoricalFolders.isEmpty {
                        Section("Historical folders · \(snapshot.unlocatedHistoricalFolders.count)") {
                            ForEach(snapshot.unlocatedHistoricalFolders) { folder in
                                Button(folder.title) { openFolder(folder) }.buttonStyle(.plain)
                                    .id(ArchiveMapItemID.folder(folder.id))
                                    .listRowBackground(selectedItemID == .folder(folder.id) ? Color.accentColor.opacity(0.16) : Color.clear)
                            }
                        }
                    }
                }
                .onChange(of: selectedItemID) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .frame(width: 270)
        }
    }
}

private final class ArchiveWalkAnnotation: NSObject, MKAnnotation {
    let walk: ArchiveMapWalk
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: walk.coordinate!.latitude, longitude: walk.coordinate!.longitude)
    }
    var title: String? { walk.title }
    var subtitle: String? { walk.location }
    init(_ walk: ArchiveMapWalk) { self.walk = walk }
}

private struct ClusteredArchiveMap: NSViewRepresentable {
    let walks: [ArchiveMapWalk]
    let openWalk: (ArchiveMapWalk) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(openWalk: openWalk) }
    func makeNSView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "walk")
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "cluster")
        return map
    }
    func updateNSView(_ map: MKMapView, context: Context) {
        context.coordinator.openWalk = openWalk
        guard context.coordinator.walks != walks else { return }
        context.coordinator.walks = walks
        map.removeAnnotations(map.annotations)
        let annotations = walks.map(ArchiveWalkAnnotation.init)
        map.addAnnotations(annotations)
        if !annotations.isEmpty { map.showAnnotations(annotations, animated: false) }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var walks: [ArchiveMapWalk] = []
        var openWalk: (ArchiveMapWalk) -> Void
        init(openWalk: @escaping (ArchiveMapWalk) -> Void) { self.openWalk = openWalk }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "cluster", for: cluster) as! MKMarkerAnnotationView
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.markerTintColor = .systemOrange
                return view
            }
            guard annotation is ArchiveWalkAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "walk", for: annotation) as! MKMarkerAnnotationView
            view.clusteringIdentifier = "archive-walks"
            view.glyphImage = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Walk")
            view.markerTintColor = .systemBlue
            return view
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
                mapView.deselectAnnotation(cluster, animated: false)
            } else if let annotation = view.annotation as? ArchiveWalkAnnotation {
                openWalk(annotation.walk)
            }
        }
    }
}
