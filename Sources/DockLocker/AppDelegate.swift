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
    private let dockDetector = DockLocationDetector()
    private var menuController: StatusMenuController?
    private var tapCreationFailed = false
    /// Last display seen hosting the Dock (follow mode); kept when detection
    /// transiently returns nil so the anchor never flaps.
    private var lastDockDisplayID: UInt32?

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
            dockHostDisplayID: { [unowned self] in
                self.refreshFollowAnchor()
                return self.lastDockDisplayID
            },
            onSettingsChanged: { [unowned self] in
                self.refreshFollowAnchor()
                self.apply()
            })
        screenManager.onChange = { [unowned self] in
            self.refreshFollowAnchor()
            self.apply()
        }
        authorizer.onTrusted = { [unowned self] in self.apply() }
        // A deliberate Fn-move finishes shortly after the key is released;
        // the Dock's migration animation can lag, so check a few times.
        tapManager.onBypassReleased = { [unowned self] in
            for delay in [0.6, 1.6, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self else { return }
                    self.refreshFollowAnchor()
                }
            }
        }
        authorizer.requestIfNeeded()
        refreshFollowAnchor()
        apply()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tapManager.stop()
    }

    /// Re-detects which display hosts the Dock; on a change, re-applies zones.
    private func refreshFollowAnchor() {
        guard settings.followDock else { return }
        guard let id = dockDetector.currentDockDisplayID(displays: screenManager.displays)
        else { return }
        if id != lastDockDisplayID {
            lastDockDisplayID = id
            apply()
        }
    }

    private func currentAnchorID() -> UInt32 {
        if settings.followDock,
            let id = lastDockDisplayID,
            screenManager.displays.contains(where: { $0.id == id })
        {
            return id
        }
        return screenManager.resolveAnchor(
            uuid: settings.anchorDisplayUUID,
            name: settings.anchorDisplayName
        ).display.id
    }

    /// Recomputes zones from current settings + displays and drives the tap.
    private func apply() {
        tapManager.zones = ClampZone.zones(
            displays: screenManager.displays,
            anchorID: currentAnchorID())
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
