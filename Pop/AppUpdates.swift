import AppKit
import Combine
import Sparkle

@MainActor
final class AppUpdates: ObservableObject {
    let controller: SPUStandardUpdaterController?
    @Published private(set) var canCheck = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var automaticDownloads = false

    init() {
        #if DEBUG
        controller = nil
        #else
        // Local Release builds also stay separate from the installed app.
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        let installedPaths = ["/Applications/Pop.app", NSHomeDirectory() + "/Applications/Pop.app"]
        controller = installedPaths.contains(path)
            ? SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        #endif
        guard let updater = controller?.updater else { return }
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticChecks)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticDownloads)
    }

    func start() {
        guard let controller else { return }
        controller.startUpdater()
        // Check on reopening even if Sparkle's regular interval has not elapsed.
        DispatchQueue.main.async { [weak self] in
            guard let updater = self?.controller?.updater,
                  updater.automaticallyChecksForUpdates, updater.canCheckForUpdates else { return }
            updater.checkForUpdatesInBackground()
        }
    }

    func check() { controller?.checkForUpdates(nil) }
    func setAutomaticChecks(_ value: Bool) { controller?.updater.automaticallyChecksForUpdates = value }
    func setAutomaticDownloads(_ value: Bool) { controller?.updater.automaticallyDownloadsUpdates = value }
}
