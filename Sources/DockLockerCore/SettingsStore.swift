import Foundation

/// UserDefaults-backed settings. The suite is injectable for tests.
public final class SettingsStore {
    private enum Key {
        static let enabled = "enabled"
        static let anchorDisplayUUID = "anchorDisplayUUID"
        static let anchorDisplayName = "anchorDisplayName"
        static let bypassModifier = "bypassModifier"
        static let followDock = "followDock"
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var enabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    public var anchorDisplayUUID: String? {
        get { defaults.string(forKey: Key.anchorDisplayUUID) }
        set { defaults.set(newValue, forKey: Key.anchorDisplayUUID) }
    }

    public var anchorDisplayName: String? {
        get { defaults.string(forKey: Key.anchorDisplayName) }
        set { defaults.set(newValue, forKey: Key.anchorDisplayName) }
    }

    /// When true, the protected display is wherever the Dock currently lives
    /// (re-detected after each bypass move); when false, it's the fixed
    /// display picked via anchorDisplayUUID/Name.
    public var followDock: Bool {
        get { defaults.object(forKey: Key.followDock) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.followDock) }
    }

    /// The settings window remains reachable when hidden: opening the app
    /// again from Finder/Spotlight shows it.
    public var showMenuBarIcon: Bool {
        get { defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.showMenuBarIcon) }
    }

    public var bypassModifier: ModifierKey {
        get {
            defaults.string(forKey: Key.bypassModifier).flatMap(ModifierKey.init(rawValue:))
                ?? .default
        }
        set { defaults.set(newValue.rawValue, forKey: Key.bypassModifier) }
    }
}
