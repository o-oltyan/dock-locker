import Foundation

/// UserDefaults-backed settings. The suite is injectable for tests.
public final class SettingsStore {
    private enum Key {
        static let enabled = "enabled"
        static let anchorDisplayUUID = "anchorDisplayUUID"
        static let anchorDisplayName = "anchorDisplayName"
        static let bypassModifier = "bypassModifier"
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

    public var bypassModifier: ModifierKey {
        get {
            defaults.string(forKey: Key.bypassModifier).flatMap(ModifierKey.init(rawValue:))
                ?? .default
        }
        set { defaults.set(newValue.rawValue, forKey: Key.bypassModifier) }
    }
}
