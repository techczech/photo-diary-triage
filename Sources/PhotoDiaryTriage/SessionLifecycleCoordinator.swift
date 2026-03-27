import Foundation
import OSLog

struct PersistenceConfiguration {
    let sessionStore: SessionPersisting
    let previewStore: PreviewCaching
    let sessionManager: SessionManager
    let importWorkflow: ImportWorkflow
    let browserViewModel: BrowserViewModel
    let startupAlert: AppStartupAlert?
}

enum AutoLoadReason {
    case launch
    case mounted
}

enum AutoLoadPlan {
    case waitForDefaultSource(statusMessage: String?)
    case keepCurrentSession(statusMessage: String?, refreshCurrentSelection: Bool)
    case openSession(folder: URL, statusMessage: String?)
}

@MainActor
final class SessionLifecycleCoordinator {
    private let scanner: FileScanner
    private let groupingService: GroupingService
    private let importCoordinator: ImportCoordinator
    private let fileManager: FileManager
    private let supportRoot: URL
    private let logger: Logger

    init(
        scanner: FileScanner,
        groupingService: GroupingService,
        importCoordinator: ImportCoordinator,
        fileManager: FileManager = .default,
        supportRoot: URL,
        logger: Logger = AppLogger.sessionLifecycle
    ) {
        self.scanner = scanner
        self.groupingService = groupingService
        self.importCoordinator = importCoordinator
        self.fileManager = fileManager
        self.supportRoot = supportRoot
        self.logger = logger
    }

    func configurePersistence(settings: AppSettings) -> PersistenceConfiguration {
        var startupAlert: AppStartupAlert?

        do {
            try AppDirectories.ensureExists(supportRoot)
        } catch {
            logger.error("Failed to create support directory \(self.supportRoot.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            startupAlert = AppStartupAlert(
                title: "Local Storage Setup Failed",
                message: "The app support directory could not be created. The app will continue with in-memory session storage until you reset local support data.\n\n\(error.localizedDescription)",
                recoveryAction: .resetSupportData
            )
        }

        let sessionStore: SessionPersisting
        do {
            sessionStore = try SessionStore(databaseURL: supportRoot.appendingPathComponent("sessions.sqlite"))
        } catch {
            logger.error("Failed to initialize session store: \(error.localizedDescription, privacy: .public)")
            sessionStore = InMemorySessionStore()
            startupAlert = AppStartupAlert(
                title: "Session Database Unavailable",
                message: "Persistent session storage could not be opened. The app is using in-memory sessions until local support data is reset.\n\n\(error.localizedDescription)",
                recoveryAction: .resetSupportData
            )
        }

        let previewStore: PreviewCaching
        do {
            previewStore = try PreviewStore(cacheRoot: settings.cacheRoot)
        } catch {
            logger.error("Failed to initialize preview cache: \(error.localizedDescription, privacy: .public)")
            previewStore = NoCachePreviewStore(cacheRoot: settings.cacheRoot)
            if startupAlert == nil {
                startupAlert = AppStartupAlert(
                    title: "Preview Cache Unavailable",
                    message: "Thumbnail caching could not be initialized. The app will continue without a persistent preview cache.\n\n\(error.localizedDescription)",
                    recoveryAction: nil
                )
            }
        }

        return PersistenceConfiguration(
            sessionStore: sessionStore,
            previewStore: previewStore,
            sessionManager: SessionManager(scanner: scanner, groupingService: groupingService),
            importWorkflow: ImportWorkflow(coordinator: importCoordinator),
            browserViewModel: BrowserViewModel(scanner: scanner),
            startupAlert: startupAlert
        )
    }

    func resetSupportData() throws {
        guard fileManager.fileExists(atPath: supportRoot.path) else { return }
        try fileManager.removeItem(at: supportRoot)
    }

    func loadMostRecentSession(
        from store: SessionPersisting,
        using sessionManager: SessionManager
    ) throws -> SessionLoadResult? {
        try sessionManager.loadMostRecentSession(from: store)
    }

    func openSession(
        for folder: URL,
        settings: AppSettings,
        using sessionManager: SessionManager,
        store: SessionPersisting
    ) throws -> SessionOpenResult {
        let opened = try sessionManager.openSession(for: folder, settings: settings)
        try sessionManager.save(opened.session, bursts: opened.bursts, clusters: opened.clusters, to: store)
        return opened
    }

    func persistCurrentSession(
        _ session: ImportSession,
        bursts: [BurstGroup],
        clusters: [TimeCluster],
        using sessionManager: SessionManager,
        to store: SessionPersisting
    ) throws {
        try sessionManager.save(session, bursts: bursts, clusters: clusters, to: store)
    }

    func persistSettings(_ settings: AppSettings, to store: SettingsPersisting) throws {
        try store.save(settings)
    }

    func matchesDefaultSourceMount(_ mountedURL: URL?, defaultSourceRoot: URL) -> Bool {
        guard let mountedURL else { return false }

        let defaultRoot = defaultSourceRoot.standardizedFileURL
        let mounted = mountedURL.standardizedFileURL
        return defaultRoot.path == mounted.path || defaultRoot.path.hasPrefix(mounted.path + "/")
    }

    func autoLoadPlan(
        reason: AutoLoadReason,
        settings: AppSettings,
        currentSession: ImportSession?
    ) -> AutoLoadPlan {
        guard let folder = resolvedDefaultSourceFolder(settings: settings) else {
            if reason == .launch {
                return .waitForDefaultSource(statusMessage: "Waiting for default SSD at \(settings.defaultSourceRoot.path).")
            }
            return .waitForDefaultSource(statusMessage: nil)
        }

        switch autoLoadDecision(for: folder, currentSession: currentSession, settings: settings) {
        case .openSession:
            let statusMessage = reason == .mounted ? "Default SSD mounted and loaded from \(folder.lastPathComponent)." : nil
            return .openSession(folder: folder, statusMessage: statusMessage)
        case .keepCurrentSession(let refreshCurrentSelection):
            let statusMessage = reason == .mounted ? "Default SSD mounted at \(folder.path), keeping the current session." : nil
            return .keepCurrentSession(statusMessage: statusMessage, refreshCurrentSelection: refreshCurrentSelection)
        }
    }

    func resolvedDefaultSourceFolder(settings: AppSettings) -> URL? {
        let root = settings.defaultSourceRoot.standardizedFileURL
        guard fileManager.fileExists(atPath: root.path) else { return nil }

        let dcimURL = root.appendingPathComponent("DCIM", isDirectory: true)
        if fileManager.fileExists(atPath: dcimURL.path) {
            return dcimURL
        }

        return root
    }

    private func autoLoadDecision(
        for folder: URL,
        currentSession: ImportSession?,
        settings: AppSettings
    ) -> SessionAutoLoadDecision {
        let candidate = folder.standardizedFileURL

        guard let currentSession else {
            return .openSession
        }

        let currentSource = currentSession.sourceFolder.standardizedFileURL
        if currentSource.path == candidate.path {
            return .keepCurrentSession(refreshCurrentSelection: true)
        }

        let currentIsMissing = fileManager.fileExists(atPath: currentSource.path) == false
        if currentIsMissing {
            return .openSession
        }

        let currentIsFromDefaultRoot = currentSource.path.hasPrefix(settings.defaultSourceRoot.standardizedFileURL.path)
        return currentIsFromDefaultRoot ? .openSession : .keepCurrentSession(refreshCurrentSelection: false)
    }
}

private enum SessionAutoLoadDecision {
    case openSession
    case keepCurrentSession(refreshCurrentSelection: Bool)
}
