import SwiftUI

@main
struct PopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // AppDelegate owns the menu bar, launcher panel, and settings window.
        Settings {
            EmptyView()
        }
    }
}
