import AppKit
import DockLockerCore

/// Menu-bar icon and menu. All dynamic state (checkmarks, permission hints,
/// display list) is rebuilt each time the menu opens.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let settings: SettingsStore
    private let screenManager: ScreenManager
    private let loginItems: LoginItemManager
    private let authorizer: AccessibilityAuthorizer
    private let permissionState: () -> PermissionState
    private let dockHostDisplayID: () -> UInt32?
    private let onSettingsChanged: () -> Void
    private let openSettings: () -> Void

    init(
        settings: SettingsStore,
        screenManager: ScreenManager,
        loginItems: LoginItemManager,
        authorizer: AccessibilityAuthorizer,
        permissionState: @escaping () -> PermissionState,
        dockHostDisplayID: @escaping () -> UInt32?,
        onSettingsChanged: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.screenManager = screenManager
        self.loginItems = loginItems
        self.authorizer = authorizer
        self.permissionState = permissionState
        self.dockHostDisplayID = dockHostDisplayID
        self.onSettingsChanged = onSettingsChanged
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "dock.rectangle",
            accessibilityDescription: "DockLocker")
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func setIconVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    private func rebuild() {
        menu.removeAllItems()
        let permission = permissionState()

        let enableItem = NSMenuItem(
            title: "Enable DockLocker",
            action: #selector(toggleEnabled),
            keyEquivalent: "")
        enableItem.target = self
        enableItem.state = settings.enabled ? .on : .off
        enableItem.isEnabled = permission == .trusted
        menu.addItem(enableItem)

        switch permission {
        case .untrusted:
            let grant = NSMenuItem(
                title: "Grant Accessibility Access…",
                action: #selector(grantAccessibility),
                keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        case .stale:
            let stale = NSMenuItem(
                title: "Permission stale — reset Accessibility for DockLocker",
                action: nil,
                keyEquivalent: "")
            stale.isEnabled = false
            menu.addItem(stale)
            let open = NSMenuItem(
                title: "Open Accessibility Settings…",
                action: #selector(grantAccessibility),
                keyEquivalent: "")
            open.target = self
            menu.addItem(open)
        case .trusted:
            break
        }

        menu.addItem(.separator())
        menu.addItem(makeDisplaySubmenu())
        menu.addItem(makeModifierSubmenu())
        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Start at Login",
            action: #selector(toggleLoginItem),
            keyEquivalent: "")
        loginItem.target = self
        loginItem.state = loginItems.isEnabled ? .on : .off
        menu.addItem(loginItem)
        if loginItems.status == .requiresApproval {
            let approval = NSMenuItem(
                title: "Open Login Items Settings…",
                action: #selector(openLoginItemSettings),
                keyEquivalent: "")
            approval.target = self
            menu.addItem(approval)
        }

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let about = NSMenuItem(
            title: "About DockLocker",
            action: #selector(showAbout),
            keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(
            title: "Quit DockLocker",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func makeDisplaySubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Lock Dock to", action: nil, keyEquivalent: "")
        item.isEnabled = true
        let submenu = NSMenu()
        submenu.autoenablesItems = false

        let follow = NSMenuItem(
            title: "Follow the Dock",
            action: #selector(selectFollowDock),
            keyEquivalent: "")
        follow.target = self
        follow.state = settings.followDock ? .on : .off
        submenu.addItem(follow)
        submenu.addItem(.separator())

        let hostID = dockHostDisplayID()
        let anchor = screenManager.resolveAnchor(
            uuid: settings.anchorDisplayUUID,
            name: settings.anchorDisplayName)

        if !settings.followDock, anchor.isFallback {
            let ghostName = settings.anchorDisplayName ?? "Chosen display"
            let ghost = NSMenuItem(
                title: "\(ghostName) (disconnected — using \(anchor.display.name))",
                action: nil,
                keyEquivalent: "")
            ghost.isEnabled = false
            submenu.addItem(ghost)
            submenu.addItem(.separator())
        }

        for display in screenManager.displays {
            var title = display.name
            if display.id == hostID {
                title += " — Dock is here"
            }
            let displayItem = NSMenuItem(
                title: title,
                action: #selector(selectDisplay(_:)),
                keyEquivalent: "")
            displayItem.target = self
            displayItem.representedObject = display
            displayItem.state =
                !settings.followDock && display.id == anchor.display.id && !anchor.isFallback
                ? .on : .off
            submenu.addItem(displayItem)
        }
        item.submenu = submenu
        return item
    }

    private func makeModifierSubmenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Hold to Move Dock", action: nil, keyEquivalent: "")
        item.isEnabled = true
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for key in ModifierKey.allCases {
            let keyItem = NSMenuItem(
                title: key.displayName,
                action: #selector(selectModifier(_:)),
                keyEquivalent: "")
            keyItem.target = self
            keyItem.representedObject = key.rawValue
            keyItem.state = key == settings.bypassModifier ? .on : .off
            submenu.addItem(keyItem)
        }
        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        onSettingsChanged()
    }

    @objc private func grantAccessibility() {
        authorizer.requestIfNeeded()
        authorizer.openSystemSettings()
    }

    @objc private func selectFollowDock() {
        settings.followDock = true
        onSettingsChanged()
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let display = sender.representedObject as? DisplayInfo else { return }
        settings.followDock = false
        settings.anchorDisplayUUID = display.uuid
        settings.anchorDisplayName = display.name
        onSettingsChanged()
    }

    @objc private func selectModifier(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
            let key = ModifierKey(rawValue: raw)
        else { return }
        settings.bypassModifier = key
        onSettingsChanged()
    }

    @objc private func toggleLoginItem() {
        do {
            try loginItems.toggle()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update Login Item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func openLoginItemSettings() {
        loginItems.openSystemSettings()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func showAbout() {
        AboutPanel.show()
    }
}
