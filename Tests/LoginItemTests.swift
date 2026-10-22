import Foundation
import ServiceManagement

@main
struct LoginItemTests {
    @MainActor static func main() {
        var status: SMAppService.Status = .notRegistered
        var registrations = 0
        var removals = 0
        let item = LoginItem(available: true, readStatus: { status }, register: {
            registrations += 1
            status = .requiresApproval
        }, unregister: { removals += 1; status = .notRegistered })
        precondition(!item.isOn && registrations == 0, "Never register at initialization")
        item.setEnabled(true)
        precondition(item.isOn && item.needsApproval && registrations == 1)
        status = .enabled
        item.refresh()
        precondition(item.isOn && !item.needsApproval)
        status = .notRegistered
        item.refresh()
        precondition(!item.isOn, "System changes must be reflected")
        item.setEnabled(false)
        precondition(!item.isOn && removals == 1)
        let failed = LoginItem(available: true, readStatus: { .notRegistered }, register: {
            throw NSError(domain: "test", code: 1)
        })
        failed.setEnabled(true)
        precondition(!failed.isOn && failed.error != nil, "Failure must not pretend registration succeeded")
        let development = LoginItem(available: false, readStatus: { .notRegistered }, register: {
            fatalError("Development build must not register")
        }, unregister: { fatalError("Development build must not unregister") })
        development.setEnabled(true)
        development.setEnabled(false)
        print("Login item registration, approval, external changes, failure and development isolation checks passed.")
    }
}
