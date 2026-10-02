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
        let reviewedMarks = includeMarked
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .form,
            contextKey: localCommandContextKey([appState.commandGoogleContextKey, review.id.uuidString, String(reviewedMarks)]),
            actions: [
                .closeSheet: .init(run: { if appState.googleDeliveryReview?.id == review.id { appState.dismissGoogleDeliveryReview() } }),
                .confirmGoogleDelivery: .init(enabled: !appState.isDeliveringGooglePhotos && appState.googleDeliveryReview?.id == review.id,
                    run: { Task { await appState.confirmGoogleDelivery(review, includeMarked: reviewedMarks) } })
            ], ownsWindow: true) { commands in
            VStack(alignment: .leading, spacing: 16) {
                Text("Send originals to Google Photos").font(.title2)
                Text("Account: \(review.account.displayName)")
                Text("Album: \(review.existingAlbum?.title ?? review.scope.title)")
                Text("Up to \(review.photoCount) archived original photographs · \(ByteCountFormatter.string(fromByteCount: review.totalBytes, countStyle: .file))")
                Text("Original bytes are sent at original quality and count towards Google storage. RAW companions and generated crops are not included. Previous verified membership is reused. Delivery does not download unavailable originals.").foregroundStyle(.secondary)
                Toggle("Include material marked previously uploaded", isOn: $includeMarked)
                Text("Manual marks describe earlier uploads that this app cannot verify. They normally exclude material from this delivery.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Cancel") { commands.run(.closeSheet) }
                        .commandShortcutHint(.closeSheet, appState: appState, scope: .form, help: "Cancel this review")
                    Spacer()
                    Button("Send these originals") { commands.run(.confirmGoogleDelivery) }.buttonStyle(.borderedProminent).disabled(appState.isDeliveringGooglePhotos)
                        .commandShortcutHint(.confirmGoogleDelivery, appState: appState, scope: .form, help: "Send only this reviewed account and set of originals")
                }
            }.padding(24).frame(width: 580)
        }
    }
}
struct GooglePhotosQueueView: View {
    @ObservedObject var appState: AppState
    var onClose: (() -> Void)? = nil
    @State private var noAlbumTarget: GoogleJobCommandTarget?
    var body: some View {
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .information,
            contextKey: localCommandContextKey([appState.commandGoogleContextKey, String(appState.isDeliveringGooglePhotos)]),
            actions: [
                .closeSheet: .init(run: { if let onClose { onClose() } else { appState.showGoogleQueue = false } }),
                .resumeGoogleDelivery: .init(enabled: !appState.isDeliveringGooglePhotos, run: { appState.startGoogleResume() }),
                .cancelGoogleDelivery: .init(enabled: appState.isDeliveringGooglePhotos, run: { appState.cancelGoogleDelivery() })
            ], ownsWindow: true) { commands in
            VStack(alignment: .leading, spacing: 12) {
                Text("Google Photos deliveries").font(.title2)
                Text("Verified badges record album membership. Google exposes no original checksum; they do not prove byte-for-byte backup recovery.").foregroundStyle(.secondary)
                HStack {
                    Button(appState.isDeliveringGooglePhotos ? "Delivering…" : "Resume / retry") { commands.run(.resumeGoogleDelivery) }.disabled(appState.isDeliveringGooglePhotos)
                        .commandShortcutHint(.resumeGoogleDelivery, appState: appState, scope: .information, help: "Resume saved deliveries")
                    Button("Cancel") { commands.run(.cancelGoogleDelivery) }.disabled(!appState.isDeliveringGooglePhotos)
                        .commandShortcutHint(.cancelGoogleDelivery, appState: appState, scope: .information, help: "Cancel the running delivery")
                    Spacer()
                    Button("Close") { commands.run(.closeSheet) }
                        .commandShortcutHint(.closeSheet, appState: appState, scope: .information, help: "Close the queue")
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(appState.googleDeliveryJobs) { job in jobRow(job) }
                    }
                }
                if appState.googleDeliveryJobs.isEmpty { Text("Choose a Trip or imported Photo Log, then review its account and originals before sending.").foregroundStyle(.secondary) }
            }.padding(20).frame(minWidth: 720, minHeight: 460)
        }
        .alert("Allow another album creation request?", isPresented: Binding(get: { noAlbumTarget != nil }, set: { if !$0 { noAlbumTarget = nil } })) {
            Button("Cancel", role: .cancel) { noAlbumTarget = nil }
            Button("I confirmed no album was created") {
                if let target = noAlbumTarget {
                    Task {
                        guard target.isCurrent(appState) else { return }
                        await appState.confirmGoogleAlbumAbsent(jobID: target.jobID, accountID: target.accountID, expectedContext: target.contextKey)
                    }
                }
                noAlbumTarget = nil
            }
        } message: { Text("Check the captured Google account first. An empty API listing alone cannot prove failure. If an album actually exists, this action could create a duplicate album. Existing photos and receipts are retained.") }
    }
    private func jobRow(_ job: GooglePhotosDeliveryJob) -> some View {
        let target = GoogleJobCommandTarget(job: job, state: appState)
        return CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .googleJob,
            contextKey: localCommandContextKey([target.key, String(appState.isDeliveringGooglePhotos)]),
            actions: googleJobCommandActions(appState: appState, job: job, reviewAbsent: { noAlbumTarget = $0 })) { commands in
            VStack(alignment: .leading, spacing: 6) {
                Text(job.scope.title).font(.headline)
                Text("\(job.account.displayName) · \(job.state.rawValue) · \(job.photos.filter(\.committed).count)/\(job.photos.count) originals recorded")
                if let album = job.binding?.album, let link = album.productURL, let url = URL(string: link), url.scheme == "https", url.host == "photos.google.com" { Link("Open \(album.title) in Google Photos", destination: url) }
                if let error = job.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if let warning = job.indexWarning { Text(warning).foregroundStyle(.orange) }
                if let date = job.retryAfter, date > Date() { Text("Retry available after \(date.formatted())").font(.caption) }
                if job.state == .needsReconciliation {
                    Button("Find the created album…") { commands.run(.findGoogleAlbum) }.disabled(appState.isDeliveringGooglePhotos)
                        .commandShortcutHint(.findGoogleAlbum, appState: appState, scope: .googleJob, help: "Find candidate albums for this captured delivery")
                    ForEach(appState.googleAlbumCandidates[job.id] ?? []) { album in
                        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .googleAlbum,
                            contextKey: localCommandContextKey([target.key, album.id, album.title]),
                            actions: googleAlbumCommandActions(appState: appState, target: target, album: album)) { albumCommands in
                            HStack {
                                Button("Use \(album.title)") { albumCommands.run(.adoptGoogleAlbum) }.disabled(appState.isDeliveringGooglePhotos)
                                    .commandShortcutHint(.adoptGoogleAlbum, appState: appState, scope: .googleAlbum, help: "Use this album for this delivery")
                                if let link = album.productURL, let url = URL(string: link), url.scheme == "https", url.host == "photos.google.com" { Link("Inspect album first", destination: url) }
                            }
                        }
                    }
                    Button("I checked Google Photos; no album was created…") { commands.run(.reviewGoogleAlbumAbsent) }.disabled(appState.isDeliveringGooglePhotos)
                        .commandShortcutHint(.reviewGoogleAlbumAbsent, appState: appState, scope: .googleJob, help: "Review confirmation for this captured account and delivery")
                }
                if job.state != .completed && job.state != .abandoned && job.state != .needsReconciliation {
                    Button("Stop this delivery") { commands.run(.abandonGoogleJob) }.disabled(appState.isDeliveringGooglePhotos)
                        .commandShortcutHint(.abandonGoogleJob, appState: appState, scope: .googleJob, help: "Stop this saved delivery while retaining receipts")
                }
                ForEach(job.photos.filter { $0.error != nil }) { photo in Text(URL(fileURLWithPath: photo.target.path).lastPathComponent + ": " + (photo.error ?? "")).font(.caption).foregroundStyle(.secondary) }
                Divider()
            }
        }
    }
}
struct GooglePhotosControls: View {
    @ObservedObject var appState: AppState
    var body: some View {
        Menu {
            RegisteredWindowControl(id: .deliverTrip, title: "Send this Trip…", appState: appState)
            RegisteredWindowControl(id: .deliverPhotoLog, title: "Send this Photo Log…", appState: appState)
            Divider()
            RegisteredWindowControl(id: .markPreviousUpload, title: "Mark selected material previously uploaded", appState: appState)
            RegisteredWindowControl(id: .clearPreviousUpload, title: "Clear previous-upload marks", appState: appState)
            Divider()
            RegisteredWindowControl(id: .googleQueue, title: "Delivery queue…", appState: appState)
        } label: { Label(appState.isDeliveringGooglePhotos ? "Delivering…" : "Google Photos", systemImage: "cloud") }
        .sheet(item: $appState.googleDeliveryReview) { review in GooglePhotosReviewView(appState: appState, review: review) }
        .sheet(isPresented: $appState.showGoogleQueue) { GooglePhotosQueueView(appState: appState) }
    }
}
struct GooglePhotosSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var clientSecret = ""
    @State private var secretRevision = UUID()
    @State private var showQueue = false
    var body: some View {
        let revision = secretRevision
        CommandLocalSurface(coordinator: appState.commandCoordinator, scope: .googleAccount,
            contextKey: localCommandContextKey([appState.commandGoogleContextKey, revision.uuidString, String(appState.isConnectingGooglePhotos), String(appState.isDeliveringGooglePhotos)]),
            actions: googleAccountCommandActions(appState: appState, clientSecret: clientSecret,
                secretSaved: { if secretRevision == revision { clientSecret = "" } }, showQueue: { showQueue = true }), fillsAvailableHeight: true) { commands in
            Form {
                Section("Google Photos") {
                    TextField("Desktop client ID", text: Binding(get: { appState.settings.googlePhotosClientID }, set: { appState.setGooglePhotosClientID($0) }))
                    SecureField("Client secret, if required", text: $clientSecret)
                    Button("Save client secret to Keychain") { commands.run(.saveGoogleClientSecret) }.disabled(appState.settings.googlePhotosClientID.isEmpty)
                    HStack {
                        Button(appState.isConnectingGooglePhotos ? "Connecting…" : "Connect account…") { commands.run(.connectGoogleAccount) }.disabled(appState.isConnectingGooglePhotos || appState.settings.googlePhotosClientID.isEmpty || appState.isDeliveringGooglePhotos)
                        Button("Cancel sign-in") { commands.run(.cancelGoogleSignIn) }.disabled(!appState.isConnectingGooglePhotos)
                        Button("Disconnect") { commands.run(.disconnectGoogleAccount) }.disabled(appState.isConnectingGooglePhotos)
                    }
                    Button("Refresh account status") { commands.run(.refreshGoogleAccount) }.disabled(appState.isConnectingGooglePhotos)
                    Text(appState.googleAccount?.displayName ?? "No account loaded").foregroundStyle(.secondary)
                    Text("Create a Desktop OAuth client with the Photos Library API enabled. Sign-in opens your system browser and requests append-only upload, app-created verification and account identity. Tokens stay in Keychain. Earlier uploads outside Walkfolio cannot be inspected by this API.").font(.caption).foregroundStyle(.secondary)
                    Button("Delivery queue…") { commands.run(.googleQueue) }
                }
            }.formStyle(.grouped)
        }
        .onChange(of: clientSecret) { _, _ in secretRevision = UUID() }
        .sheet(isPresented: $showQueue) { GooglePhotosQueueView(appState: appState, onClose: { showQueue = false }) }
    }
}
