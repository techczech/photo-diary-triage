import AppKit
import SwiftUI

@MainActor
final class AppLaunchCoordinator: ObservableObject {
    static let shared = AppLaunchCoordinator()

    private init() {}

    func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        NSApplication.shared.mainWindow?.makeKeyAndOrderFront(nil)
    }
}
