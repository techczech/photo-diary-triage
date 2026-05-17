import SwiftUI

@main
struct PhotoDiaryTriageApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var launchCoordinator = AppLaunchCoordinator.shared

    var body: some Scene {
        WindowGroup("Photo Diary Triage") {
            ContentView(appState: appState)
                .frame(minWidth: 1380, minHeight: 760)
                .onAppear {
                    launchCoordinator.activateApp()
                    appState.performInitialAutoLoadIfNeeded()
                }
        }
        .commands {
            SidebarCommands()
            PhotoDiaryCommands(appState: appState)
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
