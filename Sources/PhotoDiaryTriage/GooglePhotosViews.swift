import SwiftUI

struct GooglePhotosDeliveryReview: Identifiable, Sendable {
    var id = UUID()
    var scope: GooglePhotosDeliveryScope
    var account: GooglePhotosAccount
    var archiveRoot: URL
    var generation: Int
    var photoCount: Int
    var totalBytes: Int64
    var existingAlbum: GooglePhotosAlbum?
}
struct GooglePhotosReviewView: View {
    @ObservedObject var appState: AppState
    let review: GooglePhotosDeliveryReview
    @State private var includeMarked = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Send originals to Google Photos").font(.title2)
            Text("Account: \(review.account.displayName)")
            Text("Album: \(review.existingAlbum?.title ?? review.scope.title)")
            Text("Up to \(review.photoCount) archived original photographs · \(ByteCountFormatter.string(fromByteCount: review.totalBytes, countStyle: .file))")
            Text("Original bytes are sent at original quality and count towards Google storage. RAW companions and generated crops are not included. Previous verified membership is reused. Delivery does not download unavailable originals.").foregroundStyle(.secondary)
            Toggle("Include material marked previously uploaded", isOn: $includeMarked)
            Text("Manual marks describe earlier uploads that this app cannot verify. They normally exclude material from this delivery.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { appState.commandCoordinator.execute(.closeSheet) }
                    .commandShortcutHint(.closeSheet, appState: appState, scope: .form, help: "Cancel this review")
                Spacer()
                Button("Send these originals") { appState.commandCoordinator.execute(.confirmGoogleDelivery) }.buttonStyle(.borderedProminent).disabled(appState.isDeliveringGooglePhotos)
            }
        }.padding(24).frame(width: 580)
        .background(CommandSheetAnchor(coordinator: appState.commandCoordinator, actions: [
            .closeSheet: .init(run: { appState.googleDeliveryReview = nil }),
            .confirmGoogleDelivery: .init(enabled: !appState.isDeliveringGooglePhotos, run: { Task { await appState.confirmGoogleDelivery(review, includeMarked: includeMarked) } })
        ]))
    }
}
struct GooglePhotosQueueView: View {
    @ObservedObject var appState: AppState
    var onClose: (() -> Void)? = nil
    @State private var noAlbumJob: GooglePhotosDeliveryJob?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Google Photos deliveries").font(.title2)
            Text("Verified badges record album membership. Google exposes no original checksum; they do not prove byte-for-byte backup recovery.").foregroundStyle(.secondary)
            HStack {
                Button(appState.isDeliveringGooglePhotos ? "Delivering…" : "Resume / retry") { appState.commandCoordinator.execute(.resumeGoogleDelivery) }.disabled(appState.isDeliveringGooglePhotos)
                Button("Cancel") { appState.commandCoordinator.execute(.cancelGoogleDelivery) }.disabled(!appState.isDeliveringGooglePhotos)
                Spacer()
                Button("Close") { appState.commandCoordinator.execute(.closeSheet) }
                    .commandShortcutHint(.closeSheet, appState: appState, scope: .information, help: "Close the queue")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(appState.googleDeliveryJobs) { job in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(job.scope.title).font(.headline)
                            Text("\(job.account.displayName) · \(job.state.rawValue) · \(job.photos.filter(\.committed).count)/\(job.photos.count) originals recorded")
                            if let album = job.binding?.album, let link = album.productURL, let url = URL(string: link), url.scheme == "https", url.host == "photos.google.com" { Link("Open \(album.title) in Google Photos", destination: url) }
                            if let error = job.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                            if let warning = job.indexWarning { Text(warning).foregroundStyle(.orange) }
                            if let date = job.retryAfter, date > Date() { Text("Retry available after \(date.formatted())").font(.caption) }
                            if job.state == .needsReconciliation {
                                Button("Find the created album…") { Task { await appState.loadGoogleAlbumCandidates(jobID: job.id) } }.disabled(appState.isDeliveringGooglePhotos)
                                ForEach(appState.googleAlbumCandidates[job.id] ?? []) { album in
                                    HStack {
                                        Button("Use \(album.title)") { Task { await appState.adoptGoogleAlbum(albumID: album.id, jobID: job.id) } }
                                        if let link = album.productURL, let url = URL(string: link), url.scheme == "https", url.host == "photos.google.com" { Link("Inspect album first", destination: url) }
                                    }
                                }
                                Button("I checked Google Photos; no album was created…") { noAlbumJob = job }.disabled(appState.isDeliveringGooglePhotos)
                            }
                            if job.state != .completed && job.state != .abandoned && job.state != .needsReconciliation {
                                Button("Stop this delivery") { Task { await appState.abandonGoogleDelivery(jobID: job.id) } }.disabled(appState.isDeliveringGooglePhotos)
                            }
                            ForEach(job.photos.filter { $0.error != nil }) { photo in Text(URL(fileURLWithPath: photo.target.path).lastPathComponent + ": " + (photo.error ?? "")).font(.caption).foregroundStyle(.secondary) }
                            Divider()
                        }
                    }
                }
            }
            if appState.googleDeliveryJobs.isEmpty { Text("Choose a Trip or imported Photo Log, then review its account and originals before sending.").foregroundStyle(.secondary) }
        }.padding(20).frame(minWidth: 720, minHeight: 460)
        .background(CommandSheetAnchor(coordinator: appState.commandCoordinator, scope: .information, actions: [
            .closeSheet: .init(run: { if let onClose { onClose() } else { appState.showGoogleQueue = false } })
        ]))
        .alert("Allow another album creation request?", isPresented: Binding(get: { noAlbumJob != nil }, set: { if !$0 { noAlbumJob = nil } })) {
            Button("Cancel", role: .cancel) { noAlbumJob = nil }
            Button("I confirmed no album was created") { if let job = noAlbumJob { Task { await appState.confirmGoogleAlbumAbsent(jobID: job.id, accountID: job.account.id) } }; noAlbumJob = nil }
        } message: { Text("Check the captured Google account first. An empty API listing alone cannot prove failure. If an album actually exists, this action could create a duplicate album. Existing photos and receipts are retained.") }
    }
}
struct GooglePhotosControls: View {
    @ObservedObject var appState: AppState
    var body: some View {
        Menu {
            Button("Send this Trip…") { Task { await appState.reviewGoogleTrip() } }.disabled(appState.descriptionTripPath == nil || appState.isDeliveringGooglePhotos)
            Button("Send this Photo Log…") { Task { await appState.reviewGooglePhotoLog() } }.disabled(!appState.canDeliverGooglePhotoLog || appState.isDeliveringGooglePhotos)
            Divider()
            Button("Mark selected material previously uploaded") { Task { await appState.markGoogleMaterial(clear: false) } }.disabled(!appState.canMarkGoogleMaterial)
            Button("Clear previous-upload marks") { Task { await appState.markGoogleMaterial(clear: true) } }.disabled(!appState.canMarkGoogleMaterial)
            Divider()
            Button("Delivery queue…") { Task { await appState.loadGoogleDeliveryQueue() } }
        } label: { Label(appState.isDeliveringGooglePhotos ? "Delivering…" : "Google Photos", systemImage: "cloud") }
        .sheet(item: $appState.googleDeliveryReview) { review in GooglePhotosReviewView(appState: appState, review: review) }
        .sheet(isPresented: $appState.showGoogleQueue) { GooglePhotosQueueView(appState: appState) }
    }
}
struct GooglePhotosSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var clientSecret = ""
    @State private var showQueue = false
    var body: some View {
        Form {
            Section("Google Photos") {
                TextField("Desktop client ID", text: Binding(get: { appState.settings.googlePhotosClientID }, set: { appState.setGooglePhotosClientID($0) }))
                SecureField("Client secret, if required", text: $clientSecret)
                Button("Save client secret to Keychain") { Task { await appState.saveGoogleClientSecret(clientSecret); clientSecret = "" } }.disabled(appState.settings.googlePhotosClientID.isEmpty)
                HStack {
                    Button(appState.isConnectingGooglePhotos ? "Connecting…" : "Connect account…") { appState.startGoogleSignIn() }.disabled(appState.isConnectingGooglePhotos || appState.settings.googlePhotosClientID.isEmpty || appState.isDeliveringGooglePhotos)
                    Button("Cancel sign-in") { appState.cancelGoogleSignIn() }.disabled(!appState.isConnectingGooglePhotos)
                    Button("Disconnect") { Task { await appState.disconnectGooglePhotos() } }.disabled(appState.isConnectingGooglePhotos)
                }
                Button("Refresh account status") { Task { await appState.loadGoogleAccount() } }
                Text(appState.googleAccount?.displayName ?? "No account loaded").foregroundStyle(.secondary)
                Text("Create a Desktop OAuth client with the Photos Library API enabled. Sign-in opens your system browser and requests append-only upload, app-created verification and account identity. Tokens stay in Keychain. Earlier uploads outside Walkfolio cannot be inspected by this API.").font(.caption).foregroundStyle(.secondary)
                Button("Delivery queue…") { Task { await appState.loadGoogleDeliveryQueue(show: false); showQueue = true } }
            }
        }.formStyle(.grouped).sheet(isPresented: $showQueue) { GooglePhotosQueueView(appState: appState, onClose: { showQueue = false }) }
    }
}
