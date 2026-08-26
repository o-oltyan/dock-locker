import Foundation
import Testing

@testable import DockLockerCore

@Suite struct SettingsStoreTests {
    private func freshStore() -> SettingsStore {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsStore(defaults: defaults)
    }

    @Test func defaults() {
        let store = freshStore()
        #expect(store.enabled == true)
        #expect(store.anchorDisplayUUID == nil)
        #expect(store.anchorDisplayName == nil)
        #expect(store.bypassModifier == .fn)
        #expect(store.followDock == true)
    }

    @Test func followDockPersists() {
        let store = freshStore()
        store.followDock = false
        #expect(store.followDock == false)
    }

    @Test func persistsValues() {
        let store = freshStore()
        store.enabled = false
        store.anchorDisplayUUID = "SOME-UUID"
        store.anchorDisplayName = "DELL U2723QE"
        store.bypassModifier = .option
        #expect(store.enabled == false)
        #expect(store.anchorDisplayUUID == "SOME-UUID")
        #expect(store.anchorDisplayName == "DELL U2723QE")
        #expect(store.bypassModifier == .option)
    }

    @Test func unknownModifierRawValueFallsBackToDefault() {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("hyper", forKey: "bypassModifier")
        let store = SettingsStore(defaults: defaults)
        #expect(store.bypassModifier == .fn)
    }
}
