import AppKit
import DockLockerCore
import SwiftUI

/// The window shown when DockLocker is launched or re-opened from
/// Finder/Spotlight. Mirrors every menu-bar setting, and is the only UI left
/// when the user hides the menu-bar icon.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settings: SettingsStore
    private let screenManager: ScreenManager
    private let loginItems: LoginItemManager
    private let authorizer: AccessibilityAuthorizer
    private let permissionState: () -> PermissionState
    private let onSettingsChanged: () -> Void

    init(
        settings: SettingsStore,
        screenManager: ScreenManager,
        loginItems: LoginItemManager,
        authorizer: AccessibilityAuthorizer,
        permissionState: @escaping () -> PermissionState,
        onSettingsChanged: @escaping () -> Void
    ) {
        self.settings = settings
        self.screenManager = screenManager
        self.loginItems = loginItems
        self.authorizer = authorizer
        self.permissionState = permissionState
        self.onSettingsChanged = onSettingsChanged
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 100),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false)
            window.title = "DockLocker"
            window.isReleasedWhenClosed = false
            self.window = window
        }
        // Fresh view each show so state always reflects the stores.
        window?.contentViewController = NSHostingController(rootView: makeView())
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeView() -> SettingsView {
        let displays = screenManager.displays
        let anchor = screenManager.resolveAnchor(
            uuid: settings.anchorDisplayUUID,
            name: settings.anchorDisplayName)
        return SettingsView(
            enabled: settings.enabled,
            permission: permissionState(),
            displays: displays.map { ($0.uuid, $0.name) },
            lockSelection: settings.followDock ? "follow" : anchor.display.uuid,
            modifier: settings.bypassModifier,
            loginEnabled: loginItems.isEnabled,
            showMenuBarIcon: settings.showMenuBarIcon,
            actions: SettingsView.Actions(
                setEnabled: { [weak self] in
                    self?.settings.enabled = $0
                    self?.onSettingsChanged()
                },
                grantAccess: { [weak self] in
                    self?.authorizer.requestIfNeeded()
                    self?.authorizer.openSystemSettings()
                },
                setLockSelection: { [weak self] selection in
                    guard let self else { return }
                    if selection == "follow" {
                        self.settings.followDock = true
                    } else if let display = self.screenManager.displays.first(where: {
                        $0.uuid == selection
                    }) {
                        self.settings.followDock = false
                        self.settings.anchorDisplayUUID = display.uuid
                        self.settings.anchorDisplayName = display.name
                    }
                    self.onSettingsChanged()
                },
                setModifier: { [weak self] in
                    self?.settings.bypassModifier = $0
                    self?.onSettingsChanged()
                },
                toggleLogin: { [weak self] in
                    try? self?.loginItems.toggle()
                },
                setShowMenuBarIcon: { [weak self] in
                    self?.settings.showMenuBarIcon = $0
                    self?.onSettingsChanged()
                },
                showAbout: { AboutPanel.show() }))
    }
}

enum AboutPanel {
    @MainActor static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: "MIT License — github.com/o-oltyan/dock-locker",
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ])
        ])
    }
}

struct SettingsView: View {
    struct Actions {
        let setEnabled: (Bool) -> Void
        let grantAccess: () -> Void
        let setLockSelection: (String) -> Void
        let setModifier: (ModifierKey) -> Void
        let toggleLogin: () -> Void
        let setShowMenuBarIcon: (Bool) -> Void
        let showAbout: () -> Void
    }

    @State var enabled: Bool
    let permission: PermissionState
    let displays: [(uuid: String, name: String)]
    @State var lockSelection: String
    @State var modifier: ModifierKey
    @State var loginEnabled: Bool
    @State var showMenuBarIcon: Bool
    let actions: Actions

    var body: some View {
        Form {
            if permission != .trusted {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(
                            permission == .untrusted
                                ? "DockLocker needs the Accessibility permission to work."
                                : "Accessibility grant is stale — remove and re-add DockLocker.")
                        Spacer()
                        Button("Grant Access…") { actions.grantAccess() }
                    }
                }
            }

            Section {
                Toggle("Enable DockLocker", isOn: $enabled)
                    .onChange(of: enabled) { _, value in actions.setEnabled(value) }
                    .disabled(permission != .trusted)

                Picker("Lock Dock to", selection: $lockSelection) {
                    Text("Follow the Dock").tag("follow")
                    Divider()
                    ForEach(displays, id: \.uuid) { display in
                        Text(display.name).tag(display.uuid)
                    }
                }
                .onChange(of: lockSelection) { _, value in actions.setLockSelection(value) }

                Picker("Hold to move Dock", selection: $modifier) {
                    ForEach(ModifierKey.allCases, id: \.self) { key in
                        Text(key.displayName).tag(key)
                    }
                }
                .onChange(of: modifier) { _, value in actions.setModifier(value) }
            } footer: {
                Text("Hold the key and push the Dock to another display's bottom edge to move it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Start at login", isOn: $loginEnabled)
                    .onChange(of: loginEnabled) { _, _ in actions.toggleLogin() }
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, value in
                        actions.setShowMenuBarIcon(value)
                    }
            } footer: {
                if !showMenuBarIcon {
                    Text("Icon hidden. Open DockLocker again from Applications or Spotlight to see this window.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button("About DockLocker") { actions.showAbout() }
                    Spacer()
                    Button("Quit DockLocker") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize()
    }
}
