import ServiceManagement

/// Thin wrapper around SMAppService for the "Start at Login" toggle.
/// Status is always queried live, never persisted.
@MainActor
final class LoginItemManager {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    var isEnabled: Bool { status == .enabled }

    func toggle() throws {
        if isEnabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
