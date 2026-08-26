import CoreGraphics
import Testing

@testable import DockLockerCore

// All rects below are in CG global space (top-left origin, y grows downward),
// the same space CGEvent.location reports in.
private let main = DisplayInfo(
    id: 1, uuid: "UUID-MAIN", name: "Built-in Display",
    cgBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080))
private let external = DisplayInfo(
    id: 2, uuid: "UUID-EXT", name: "DELL U2723QE",
    cgBounds: CGRect(x: 1920, y: 0, width: 2560, height: 1440))

@Suite struct ClampZoneComputationTests {
    @Test func singleDisplayProducesNoZones() {
        let zones = ClampZone.zones(displays: [main], anchorID: 1)
        #expect(zones.isEmpty)
    }

    @Test func anchorDisplayBottomEdgeIsNeverClamped() {
        let zones = ClampZone.zones(displays: [main, external], anchorID: 2)
        #expect(zones.count == 1)
        #expect(zones[0].rect.minX == 0)
        #expect(zones[0].rect.maxX == 1920)
    }

    @Test func zoneCoversBottomThresholdStripOfNonAnchorDisplay() {
        let zones = ClampZone.zones(displays: [main, external], anchorID: 1, threshold: 3, nudge: 5)
        #expect(zones.count == 1)
        let zone = zones[0]
        // Bottom strip of the external display: y from maxY - threshold through maxY.
        #expect(zone.rect == CGRect(x: 1920, y: 1437, width: 2560, height: 4))
        #expect(zone.clampedY == 1435)
    }

    @Test func stackedDisplayEdgeIsSubtracted() {
        // B sits directly below A; anchor is B. A's bottom edge borders B, so the
        // cursor must be allowed through — no zones at all.
        let a = DisplayInfo(id: 1, uuid: "A", name: "A", cgBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let b = DisplayInfo(id: 2, uuid: "B", name: "B", cgBounds: CGRect(x: 0, y: 1080, width: 1920, height: 1080))
        let zones = ClampZone.zones(displays: [a, b], anchorID: 2)
        #expect(zones.isEmpty)
    }

    @Test func partialStackSplitsZoneIntoRemainingIntervals() {
        // B (1920 wide) sits below the middle of A (2560 wide): A's strip keeps
        // its left and right shoulders only.
        let a = DisplayInfo(id: 1, uuid: "A", name: "A", cgBounds: CGRect(x: 0, y: 0, width: 2560, height: 1080))
        let b = DisplayInfo(id: 2, uuid: "B", name: "B", cgBounds: CGRect(x: 500, y: 1080, width: 1920, height: 1080))
        // A's strip [0, 2560] minus [500, 2420] -> one zone per remaining interval.
        let zones = ClampZone.zones(displays: [a, b], anchorID: 2, threshold: 3, nudge: 5)
        let sorted = zones.sorted { $0.rect.minX < $1.rect.minX }
        #expect(sorted.count == 2)
        #expect(sorted[0].rect.minX == 0 && sorted[0].rect.maxX == 500)
        #expect(sorted[1].rect.minX == 2420 && sorted[1].rect.maxX == 2560)
    }

    @Test func nudgeMustLandOutsideTheZone() {
        // Otherwise a clamped cursor would still be inside the zone next event.
        let zones = ClampZone.zones(displays: [main, external], anchorID: 1, threshold: 3, nudge: 5)
        for zone in zones {
            #expect(zone.clampedY < zone.rect.minY)
        }
    }
}

@Suite struct ClampZoneHitTestTests {
    let zones = ClampZone.zones(displays: [main, external], anchorID: 1, threshold: 3, nudge: 5)

    @Test func pointInsideZoneIsClamped() {
        let clamped = ClampZone.clampedLocation(for: CGPoint(x: 3000, y: 1439), in: zones)
        #expect(clamped == CGPoint(x: 3000, y: 1435))
    }

    @Test func pointAtExactBottomEdgeIsClamped() {
        let clamped = ClampZone.clampedLocation(for: CGPoint(x: 3000, y: 1440), in: zones)
        #expect(clamped == CGPoint(x: 3000, y: 1435))
    }

    @Test func pointAtThresholdBoundaryIsClamped() {
        let clamped = ClampZone.clampedLocation(for: CGPoint(x: 3000, y: 1437), in: zones)
        #expect(clamped != nil)
    }

    @Test func pointAboveThresholdIsNotClamped() {
        #expect(ClampZone.clampedLocation(for: CGPoint(x: 3000, y: 1436), in: zones) == nil)
    }

    @Test func pointOnAnchorBottomEdgeIsNotClamped() {
        #expect(ClampZone.clampedLocation(for: CGPoint(x: 500, y: 1079), in: zones) == nil)
    }
}
