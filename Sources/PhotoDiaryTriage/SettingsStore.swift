import Foundation

final class SettingsStore: SettingsPersisting {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = AppLogger.settingsStore

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load(defaults: @autoclosure () -> AppSettings) -> AppSettings {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            if (error as NSError).code != NSFileReadNoSuchFileError {
                logger.error("Failed to load settings from \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            return defaults()
        }
    }

    func save(_ settings: AppSettings) throws {
        try AppDirectories.ensureExists(fileURL.deletingLastPathComponent())
        let data = try encoder.encode(settings)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save settings to \(self.fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
