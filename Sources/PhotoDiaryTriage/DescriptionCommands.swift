import Foundation

// Requests carry their selected paths/year and configuration before Task scheduling.
enum DescriptionCommandRequest {
    case targets([(DescriptionTargetKind, String)], regenerate: Bool)
    case year(String)
}

private struct DescriptionOperation {
    let id: UUID, context: String, cancellation: Int
    let configuration: LMStudioConfiguration
}

extension AppState {
    var commandDescriptionContextKey: String {
        localCommandContextKey([settings.archiveRoot.standardizedFileURL.path,
            settings.oneDrivePicturesRoot.standardizedFileURL.path, settings.archiveMachineRole.rawValue,
            String(ArchiveByteReadPolicyContext.shared.generation)])
    }
    private func currentDescriptionQueue() -> any ArchiveDescriptionQueuing {
        if let testingDescriptionQueue { return testingDescriptionQueue }
        let generation = ArchiveByteReadPolicyContext.shared.generation
        if let descriptionQueue, descriptionQueueGeneration == generation { return descriptionQueue }
        let queue = ArchiveDescriptionQueue(archiveRoot: settings.archiveRoot, machineRole: settings.archiveMachineRole,
            client: descriptionClient, oneDrivePicturesRoot: settings.oneDrivePicturesRoot,
            contextIsCurrent: { ArchiveByteReadPolicyContext.shared.generation == generation })
        descriptionQueue = queue; descriptionQueueGeneration = generation; return queue
    }
    private func beginDescriptionOperation() -> DescriptionOperation? {
        guard !isDescribing else { return nil }
        let operation = DescriptionOperation(id: UUID(), context: commandDescriptionContextKey,
            cancellation: descriptionCancellationRevision, configuration: settings.lmStudioConfiguration)
        descriptionOperationID = operation.id; descriptionQueueReadRequestID = nil; isDescribing = true
        return operation
    }
    private func ownsDescriptionOperation(_ operation: DescriptionOperation) -> Bool {
        descriptionOperationID == operation.id && operation.context == commandDescriptionContextKey
            && operation.cancellation == descriptionCancellationRevision && !Task.isCancelled
    }
    private func finishDescriptionOperation(_ operation: DescriptionOperation) {
        guard descriptionOperationID == operation.id else { return }
        descriptionOperationID = nil; isDescribing = false; descriptionTask = nil
    }

    func startDescriptionCommand(_ request: DescriptionCommandRequest) {
        guard workspaceMode == .archiveView, let operation = beginDescriptionOperation() else { return }
        let queue = currentDescriptionQueue(), root = settings.archiveRoot
        descriptionTask = Task { [weak self] in
            guard let self else { return }; defer { finishDescriptionOperation(operation) }
            guard ownsDescriptionOperation(operation) else { return }
            await prepareDescriptionRequest(request, operation: operation, queue: queue, root: root)
        }
    }
    func describeCurrentMaterial(regenerate: Bool = false) async {
        await enqueueDescriptions(targets: contextualDescriptionTargets, regenerate: regenerate)
    }
    func describeCurrentTrip(regenerate: Bool = false) async {
        guard let path = descriptionTripPath else { return }
        await enqueueDescriptions(targets: [(.trip, path)], regenerate: regenerate)
    }
    func describeCurrentYear() async {
        guard workspaceMode == .archiveView, let year = descriptionYear, let operation = beginDescriptionOperation() else { return }
        let queue = currentDescriptionQueue(), root = settings.archiveRoot
        defer { finishDescriptionOperation(operation) }
        await prepareDescriptionRequest(.year(year), operation: operation, queue: queue, root: root)
    }
    private func prepareDescriptionRequest(_ request: DescriptionCommandRequest, operation: DescriptionOperation,
                                           queue: any ArchiveDescriptionQueuing, root: URL) async {
        switch request {
        case .targets(let targets, let regenerate):
            await performDescriptionEnqueue(targets: targets, regenerate: regenerate, operation: operation, queue: queue)
        case .year(let year):
            do {
                let rows: [ArchiveIndexEntry]
                if let reader = testingDescriptionYearReader { rows = try await reader(root) }
                else { rows = try await Task.detached { try ArchiveCatalogueBuilder().readIndexEntries(archiveRoot: root) }.value }
                guard ownsDescriptionOperation(operation) else { return }
                let targets = rows.filter { $0.year == year && (($0.kind == .trip && $0.tripID != nil) || ($0.kind == .walk && $0.sessionID != nil)) }
                    .map { ($0.kind == .trip ? DescriptionTargetKind.trip : .walk, $0.archiveRelativePath) }
                await performDescriptionEnqueue(targets: targets, regenerate: false, operation: operation, queue: queue)
            } catch { if ownsDescriptionOperation(operation) { statusMessage = "Description year queue failed: " + error.localizedDescription } }
        }
    }
    func enqueueDescriptions(targets: [(DescriptionTargetKind, String)], regenerate: Bool = false) async {
        guard workspaceMode == .archiveView, !targets.isEmpty, let operation = beginDescriptionOperation() else { return }
        let queue = currentDescriptionQueue(); defer { finishDescriptionOperation(operation) }
        await performDescriptionEnqueue(targets: targets, regenerate: regenerate, operation: operation, queue: queue)
    }
    private func performDescriptionEnqueue(targets: [(DescriptionTargetKind, String)], regenerate: Bool,
                                           operation: DescriptionOperation, queue: any ArchiveDescriptionQueuing) async {
        await descriptionCancellationTask?.value
        guard ownsDescriptionOperation(operation), !targets.isEmpty else { return }
        do {
            let created = try await queue.enqueue(targets: targets, configuration: operation.configuration, regenerate: regenerate)
            guard ownsDescriptionOperation(operation) else { return }
            let jobs = try await queue.jobs()
            guard ownsDescriptionOperation(operation) else { return }
            descriptionJobs = jobs; showDescriptionQueue = true
            if created.isEmpty { statusMessage = "The selected material already has descriptions. Use Regenerate to replace the active result." }
            else { await performDescriptionResume(jobIDs: Set(created.map(\.id)), operation: operation, queue: queue) }
        } catch { if ownsDescriptionOperation(operation) { statusMessage = "Could not queue descriptions: " + error.localizedDescription } }
    }
    @discardableResult
    func loadDescriptionQueue(show: Bool = true) async -> Bool {
        guard !isDescribing else { if show { showDescriptionQueue = true }; return true }
        let queue = currentDescriptionQueue(), context = commandDescriptionContextKey, request = UUID()
        descriptionQueueReadRequestID = request
        do {
            let jobs = try await queue.jobs()
            guard context == commandDescriptionContextKey, descriptionQueueReadRequestID == request, !Task.isCancelled else { return false }
            descriptionJobs = jobs; if show { showDescriptionQueue = true }; return true
        } catch {
            if context == commandDescriptionContextKey, descriptionQueueReadRequestID == request, !Task.isCancelled {
                statusMessage = "Description queue unavailable: " + error.localizedDescription
            }
            return false
        }
    }
    func resumeDescriptions(jobIDs: Set<UUID>? = nil) async {
        guard let operation = beginDescriptionOperation() else { return }
        let queue = currentDescriptionQueue(); defer { finishDescriptionOperation(operation) }
        await performDescriptionResume(jobIDs: jobIDs, operation: operation, queue: queue)
    }
    private func performDescriptionResume(jobIDs: Set<UUID>?, operation: DescriptionOperation, queue: any ArchiveDescriptionQueuing) async {
        await descriptionCancellationTask?.value
        guard ownsDescriptionOperation(operation) else { return }
        do {
            try await queue.run(jobIDs: jobIDs, progress: { [weak self] jobs in
                await self?.publishDescriptionProgress(jobs, operation: operation)
            })
            guard ownsDescriptionOperation(operation) else { return }
            let jobs = try await queue.jobs()
            guard ownsDescriptionOperation(operation) else { return }
            descriptionJobs = jobs
            let failed = jobs.filter { $0.state == .failed || $0.state == .cancelled }.count
            statusMessage = failed == 0 ? "Description queue completed." : "Description queue has \(failed) requests needing retry or a fresh request."
            if settings.archiveMachineRole == .mainArchive { reloadArchiveCatalogue() }
            else { statusMessage += " Canonical results are saved; the main Mac publishes the searchable index." }
        } catch { if ownsDescriptionOperation(operation) { statusMessage = "Description queue stopped: " + error.localizedDescription } }
    }
    private func publishDescriptionProgress(_ jobs: [ArchiveDescriptionJob], operation: DescriptionOperation) {
        guard ownsDescriptionOperation(operation) else { return }
        descriptionJobs = jobs
    }
    func startDescriptionResume() {
        guard let operation = beginDescriptionOperation() else { return }
        let queue = currentDescriptionQueue()
        descriptionTask = Task { [weak self] in
            guard let self else { return }; defer { finishDescriptionOperation(operation) }
            await performDescriptionResume(jobIDs: nil, operation: operation, queue: queue)
        }
    }
    func cancelDescriptions() {
        descriptionCancellationRevision &+= 1; descriptionQueueReadRequestID = nil
        descriptionTask?.cancel()
        let queue = testingDescriptionQueue ?? descriptionQueue
        let previousCancellation = descriptionCancellationTask
        descriptionCancellationTask = Task {
            await previousCancellation?.value
            await queue?.cancel()
        }
        if isDescribing { statusMessage = "Description request cancelled. Saved requests can be resumed." }
    }
    @discardableResult
    func startDescriptionDiscard() -> Task<Void, Never>? {
        guard let operation = beginDescriptionOperation() else { return nil }
        let queue = currentDescriptionQueue()
        let task = Task { [weak self] in
            guard let self else { return }; defer { finishDescriptionOperation(operation) }
            await performDescriptionDiscard(operation: operation, queue: queue)
        }
        descriptionTask = task; return task
    }
    func discardFailedDescriptions() async {
        guard let task = startDescriptionDiscard() else { return }
        await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
    }
    private func performDescriptionDiscard(operation: DescriptionOperation, queue: any ArchiveDescriptionQueuing) async {
        await descriptionCancellationTask?.value
        guard ownsDescriptionOperation(operation) else { return }
        do {
            try await queue.discardFailed()
            guard ownsDescriptionOperation(operation) else { return }
            let jobs = try await queue.jobs()
            guard ownsDescriptionOperation(operation) else { return }
            descriptionJobs = jobs
        } catch { if ownsDescriptionOperation(operation) { statusMessage = "Could not discard failed requests: " + error.localizedDescription } }
    }

}

@MainActor
func descriptionQueueCommandActions(appState: AppState, onClose: @escaping () -> Void) -> [AppCommandID: SheetCommandAction] {
    let context = appState.commandDescriptionContextKey
    return [
        .closeSheet: .init(run: onClose),
        .resumeDescriptions: .init(enabled: !appState.isDescribing, run: {
            guard context == appState.commandDescriptionContextKey else { return }; appState.startDescriptionResume()
        }),
        .cancelDescriptions: .init(enabled: appState.isDescribing, run: {
            guard context == appState.commandDescriptionContextKey else { return }; appState.cancelDescriptions()
        }),
        .discardDescriptions: .init(enabled: !appState.isDescribing, run: {
            guard context == appState.commandDescriptionContextKey else { return }; appState.startDescriptionDiscard()
        })
    ]
}

@MainActor
func descriptionSettingsCommandActions(appState: AppState, showQueue: @escaping () -> Void) -> [AppCommandID: SheetCommandAction] {
    let context = appState.commandDescriptionContextKey, configuration = appState.settings.lmStudioConfiguration, revision = appState.lmStudioConfigurationRevision
    func current() -> Bool { context == appState.commandDescriptionContextKey && configuration == appState.settings.lmStudioConfiguration && revision == appState.lmStudioConfigurationRevision }
    return [
        .refreshDescriptionModels: .init(enabled: !appState.isRefreshingLMStudioModels, run: {
            Task { guard current() else { return }; await appState.refreshLMStudioModels() }
        }),
        .descriptionQueue: .init(run: {
            Task { guard current() else { return }; if await appState.loadDescriptionQueue(show: false), current() { showQueue() } }
        })
    ]
}
