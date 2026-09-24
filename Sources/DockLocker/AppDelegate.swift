import AppKit
import DockLockerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let screenManager = ScreenManager()
    private let tapManager = EventTapManager()
    private let loginItems = LoginItemManager()
    private let authorizer = AccessibilityAuthorizer()
    private let dockDetector = DockLocationDetector()
    private var menuController: StatusMenuController?
    private var settingsWindow: SettingsWindowController?
    private var tapCreationFailed = false
    private var lastPermissionState: PermissionState?
    /// Last display seen hosting the Dock (follow mode); kept when detection
    /// transiently returns nil so the anchor never flaps.
    private var lastDockDisplayID: UInt32?

    var permissionState: PermissionState {
        PermissionState.resolve(
            axTrusted: authorizer.isTrusted,
            tapFailed: tapCreationFailed,
            wasGrantedBefore: settings.accessibilityWasGranted)
    }

    /// True when launchd started us as a login item — the launch Apple event
    /// carries 'lgit' in its property data. Manual launches (Finder,
    /// Spotlight, `open`) don't.
    private var launchedAsLoginItem: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
                == keyAELaunchedAsLogInItem
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsWindow = SettingsWindowController(
            settings: settings,
            screenManager: screenManager,
            loginItems: loginItems,
            permissionState: { [unowned self] in self.permissionState },
            resetAccessibility: { [unowned self] in self.resetAccessibility() },
            onSettingsChanged: { [unowned self] in
                self.refreshFollowAnchor()
                self.apply()
            })
        menuController = StatusMenuController(
            settings: settings,
            screenManager: screenManager,
            loginItems: loginItems,
            permissionState: { [unowned self] in self.permissionState },
            resetAccessibility: { [unowned self] in self.resetAccessibility() },
            dockHostDisplayID: { [unowned self] in
                self.refreshFollowAnchor()
                return self.lastDockDisplayID
            },
            onSettingsChanged: { [unowned self] in
                self.refreshFollowAnchor()
                self.apply()
            },
            openSettings: { [unowned self] in self.settingsWindow?.show() })
        screenManager.onChange = { [unowned self] in
            self.refreshFollowAnchor()
            self.apply()
        }
        authorizer.onPoll = { [unowned self] in self.permissionPolled() }
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
        authorizer.startMonitoring()
        refreshFollowAnchor()
        apply()
        lastPermissionState = permissionState
        // A stale grant needs a reset, not another prompt — the UI offers it.
        if lastPermissionState == .untrusted {
            authorizer.requestIfNeeded()
        }
        if !launchedAsLoginItem {
            settingsWindow?.show()
        }
    }

    /// Fires when the running app is opened again (Finder, Spotlight, `open`).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        settingsWindow?.show()
        return false
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

    /// Re-applies while the tap is failing (so it recovers by itself once the
    /// grant is valid) and whenever the permission state flips either way.
    private func permissionPolled() {
        if tapCreationFailed { apply() }
        let state = permissionState
        guard state != lastPermissionState else { return }
        lastPermissionState = state
        apply()
        settingsWindow?.refresh()
    }

    private func resetAccessibility() {
        authorizer.resetAndRequest { [weak self] in
            self?.settings.accessibilityWasGranted = false
            self?.tapCreationFailed = false
        }
    }

    /// Recomputes zones from current settings + displays and drives the tap.
    private func apply() {
        menuController?.setIconVisible(settings.showMenuBarIcon)
        tapManager.zones = ClampZone.zones(
            displays: screenManager.displays,
            anchorID: currentAnchorID())
        tapManager.bypassFlags = settings.bypassModifier.flags

        guard authorizer.isTrusted else {
            // Tear the tap down: a modifying tap that lost its permission
            // must not stay in the event stream.
            tapManager.stop()
            return
        }
        if settings.enabled {
            if !tapManager.isRunning {
                tapCreationFailed = !tapManager.start()
            } else {
                tapManager.setEnabled(true)
            }
        } else {
            tapManager.setEnabled(false)
        }
        if !tapCreationFailed { settings.accessibilityWasGranted = true }
    }
}
