import SwiftUI

@main
struct PhotoDiaryTriageApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var launchCoordinator = AppLaunchCoordinator.shared

    var body: some Scene {
        WindowGroup("Walkfolio") {
            ContentView(appState: appState)
                .frame(minWidth: 1120, minHeight: 700)
                .onAppear {
                    launchCoordinator.activateApp()
                    appState.performInitialAutoLoadIfNeeded()
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            SidebarCommands()
            PhotoDiaryCommands(appState: appState)
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
