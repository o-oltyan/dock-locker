import CoreGraphics
import Testing

@testable import DockLockerCore

@Suite struct DockLocationTests {
    let displays = [
        DisplayInfo(
            id: 1, uuid: "MAIN", name: "Built-in",
            cgBounds: CGRect(x: 0, y: 0, width: 1512, height: 982)),
        DisplayInfo(
            id: 3, uuid: "ULTRAWIDE", name: "Ultrawide",
            cgBounds: CGRect(x: -987, y: -1440, width: 3440, height: 1440)),
    ]

    @Test func windowCoveringDisplayResolvesToIt() {
        // The Dock's layer-20 window spans its host display exactly.
        let id = DockLocation.hostDisplayID(
            dockWindowBounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
            displays: displays)
        #expect(id == 1)
    }

    @Test func windowOnSecondDisplayResolvesToIt() {
        let id = DockLocation.hostDisplayID(
            dockWindowBounds: CGRect(x: -987, y: -1440, width: 3440, height: 1440),
            displays: displays)
        #expect(id == 3)
    }

    @Test func partialOverlapPicksLargestIntersection() {
        // Window hangs mostly over the ultrawide but clips into main.
        let id = DockLocation.hostDisplayID(
            dockWindowBounds: CGRect(x: 100, y: -600, width: 1000, height: 700),
            displays: displays)
        #expect(id == 3)
    }

    @Test func disjointWindowResolvesToNil() {
        let id = DockLocation.hostDisplayID(
            dockWindowBounds: CGRect(x: 9000, y: 9000, width: 100, height: 100),
            displays: displays)
        #expect(id == nil)
    }

    @Test func emptyDisplayListResolvesToNil() {
        let id = DockLocation.hostDisplayID(
            dockWindowBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            displays: [])
        #expect(id == nil)
    }
}
