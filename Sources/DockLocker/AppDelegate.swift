import AppKit
import DockLockerCore

enum PermissionState {
    case trusted
    case untrusted
    /// TCC reports trusted but tap creation failed — typical after an ad-hoc
    /// rebuild left a stale Accessibility grant behind.
    case stale
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let screenManager = ScreenManager()
    private let tapManager = EventTapManager()
    private let loginItems = LoginItemManager()
    private let authorizer = AccessibilityAuthorizer()
    private var menuController: StatusMenuController?
    private var tapCreationFailed = false

    var permissionState: PermissionState {
        if !authorizer.isTrusted { return .untrusted }
        return tapCreationFailed ? .stale : .trusted
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuController = StatusMenuController(
            settings: settings,
            screenManager: screenManager,
            loginItems: loginItems,
            authorizer: authorizer,
            permissionState: { [unowned self] in self.permissionState },
            onSettingsChanged: { [unowned self] in self.apply() })
        screenManager.onChange = { [unowned self] in self.apply() }
        authorizer.onTrusted = { [unowned self] in self.apply() }
        authorizer.requestIfNeeded()
        apply()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tapManager.stop()
    }

    /// Recomputes zones from current settings + displays and drives the tap.
    private func apply() {
        let anchor = screenManager.resolveAnchor(
            uuid: settings.anchorDisplayUUID,
            name: settings.anchorDisplayName)
        tapManager.zones = ClampZone.zones(
            displays: screenManager.displays,
            anchorID: anchor.display.id)
        tapManager.bypassFlags = settings.bypassModifier.flags

        if settings.enabled, authorizer.isTrusted {
            if !tapManager.isRunning {
                tapCreationFailed = !tapManager.start()
            } else {
                tapManager.setEnabled(true)
            }
        } else {
            tapManager.setEnabled(false)
        }
    }
}
