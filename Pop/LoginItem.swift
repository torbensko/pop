import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var error: String?
    let available: Bool
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void

    var isOn: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }

    init(available: Bool? = nil,
         readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }) {
        self.available = available ?? Self.isInstalledRelease
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        refresh()
    }

    static var isInstalledRelease: Bool {
        #if DEBUG
        return false
        #else
        return ["/Applications/Pop.app", NSHomeDirectory() + "/Applications/Pop.app"]
            .contains(Bundle.main.bundleURL.standardizedFileURL.path)
        #endif
    }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) {
        guard available else { return }
        error = nil
        do {
            if enabled { try register() } else { try unregister() }
        } catch {
            self.error = "Could not change Start at login: \(error.localizedDescription)"
        }
        refresh()
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
