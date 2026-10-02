import Foundation

/// Non-secret command authority. It includes account generation, so a client/account
/// round trip cannot revive a retained queue, settings or confirmation action.
@MainActor
struct GoogleJobCommandTarget {
    let jobID: UUID, accountID: String, clientID: String
    let contextKey: String, revision: String
    init(job: GooglePhotosDeliveryJob, state: AppState) {
        jobID = job.id; accountID = job.account.id; clientID = job.account.clientID
        contextKey = state.commandGoogleContextKey; revision = Self.revision(job)
    }
    static func revision(_ job: GooglePhotosDeliveryJob) -> String {
        localCommandContextKey([job.id.uuidString, job.account.id, job.account.clientID, job.scope.id.uuidString,
            job.scope.kind.rawValue, job.scope.path, job.scope.title, job.machineRole.rawValue,
            String(job.createdAt.timeIntervalSinceReferenceDate), job.state.rawValue, String(job.albumCreationStarted),
            job.binding?.operationID.uuidString ?? "", job.binding?.album.id ?? ""])
    }
    func isCurrent(_ state: AppState) -> Bool {
        contextKey == state.commandGoogleContextKey && state.googleDeliveryJobs.contains {
            $0.id == jobID && $0.account.id == accountID && $0.account.clientID == clientID && Self.revision($0) == revision
        }
    }
    var key: String { localCommandContextKey([contextKey, revision]) }
}

@MainActor
func googleJobCommandActions(appState: AppState, job: GooglePhotosDeliveryJob,
    reviewAbsent: @escaping (GoogleJobCommandTarget) -> Void) -> [AppCommandID: SheetCommandAction] {
    let target = GoogleJobCommandTarget(job: job, state: appState)
    let idle = !appState.isDeliveringGooglePhotos
    return [
        .findGoogleAlbum: .init(enabled: idle && job.state == .needsReconciliation, run: {
            Task { guard target.isCurrent(appState), !appState.isDeliveringGooglePhotos else { return }; await appState.loadGoogleAlbumCandidates(jobID: target.jobID, expectedContext: target.contextKey) }
        }),
        .reviewGoogleAlbumAbsent: .init(enabled: idle && job.state == .needsReconciliation, run: {
            guard target.isCurrent(appState), !appState.isDeliveringGooglePhotos else { return }; reviewAbsent(target)
        }),
        .abandonGoogleJob: .init(enabled: idle && ![.completed, .abandoned, .needsReconciliation].contains(job.state), run: {
            Task { guard target.isCurrent(appState), !appState.isDeliveringGooglePhotos else { return }; await appState.abandonGoogleDelivery(jobID: target.jobID, expectedContext: target.contextKey) }
        })
    ]
}

@MainActor
func googleAlbumCommandActions(appState: AppState, target: GoogleJobCommandTarget, album: GooglePhotosAlbum) -> [AppCommandID: SheetCommandAction] {
    [.adoptGoogleAlbum: .init(enabled: !appState.isDeliveringGooglePhotos && target.isCurrent(appState), run: {
        Task {
            guard target.isCurrent(appState), !appState.isDeliveringGooglePhotos, appState.googleAlbumCandidates[target.jobID]?.contains(album) == true else { return }
            await appState.adoptGoogleAlbum(albumID: album.id, jobID: target.jobID, expectedContext: target.contextKey)
        }
    })]
}

@MainActor
func googleAccountCommandActions(appState: AppState, clientSecret: String,
    secretSaved: @escaping () -> Void, showQueue: @escaping () -> Void) -> [AppCommandID: SheetCommandAction] {
    let context = appState.commandGoogleContextKey
    func current() -> Bool { context == appState.commandGoogleContextKey }
    return [
        .saveGoogleClientSecret: .init(enabled: !appState.settings.googlePhotosClientID.isEmpty, run: {
            Task { guard current() else { return }; if await appState.saveGoogleClientSecret(clientSecret, expectedContext: context) { secretSaved() } }
        }),
        .connectGoogleAccount: .init(enabled: !appState.isConnectingGooglePhotos && !appState.isDeliveringGooglePhotos && !appState.settings.googlePhotosClientID.isEmpty,
            run: { guard current() else { return }; appState.startGoogleSignIn() }),
        .cancelGoogleSignIn: .init(enabled: appState.isConnectingGooglePhotos, run: { guard current() else { return }; appState.cancelGoogleSignIn() }),
        .disconnectGoogleAccount: .init(enabled: !appState.isConnectingGooglePhotos, run: {
            Task { guard current() else { return }; await appState.disconnectGooglePhotos() }
        }),
        .refreshGoogleAccount: .init(enabled: !appState.isConnectingGooglePhotos, run: { Task { guard current() else { return }; await appState.loadGoogleAccount() } }),
        .googleQueue: .init(run: {
            Task { guard current() else { return }; await appState.loadGoogleDeliveryQueue(show: false); if current() { showQueue() } }
        })
    ]
}
