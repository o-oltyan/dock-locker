import CoreGraphics

/// A strip along the bottom edge of a non-anchor display. While the cursor is
/// inside `rect`, DockLocker denies macOS the sustained bottom-edge contact
/// that triggers Dock migration: mouseMoved events are swallowed, drag events
/// get their y rewritten to `clampedY`.
public struct ClampZone: Equatable, Sendable {
    /// Hit-test rect in CG global space (top-left origin).
    public let rect: CGRect
    /// Where to move the cursor's y; always above (less than) `rect.minY` so a
    /// clamped cursor lands outside the zone.
    public let clampedY: CGFloat

    public init(rect: CGRect, clampedY: CGFloat) {
        self.rect = rect
        self.clampedY = clampedY
    }

    /// Computes clamp zones for every display except the anchor.
    ///
    /// Where another display sits directly below a strip, that x-interval is
    /// cut out — otherwise vertically stacked arrangements would trap the
    /// cursor at the internal boundary instead of letting it cross.
    public static func zones(
        displays: [DisplayInfo],
        anchorID: UInt32,
        threshold: CGFloat = 3,
        nudge: CGFloat = 5
    ) -> [ClampZone] {
        var result: [ClampZone] = []
        for display in displays where display.id != anchorID {
            let bounds = display.cgBounds
            let adjacentBelow = displays
                .filter { $0.id != display.id && abs($0.cgBounds.minY - bounds.maxY) <= 1 }
                .map { (max($0.cgBounds.minX, bounds.minX), min($0.cgBounds.maxX, bounds.maxX)) }
                .filter { $0.0 < $0.1 }
            let intervals = subtract(from: (bounds.minX, bounds.maxX), removing: adjacentBelow)
            for (start, end) in intervals {
                result.append(
                    ClampZone(
                        rect: CGRect(
                            x: start,
                            y: bounds.maxY - threshold,
                            width: end - start,
                            height: threshold + 1),
                        clampedY: bounds.maxY - nudge))
            }
        }
        return result
    }

    /// Returns the corrected location if `point` falls inside a zone, nil otherwise.
    public static func clampedLocation(for point: CGPoint, in zones: [ClampZone]) -> CGPoint? {
        for zone in zones {
            if point.x >= zone.rect.minX, point.x < zone.rect.maxX,
                point.y >= zone.rect.minY, point.y <= zone.rect.maxY
            {
                return CGPoint(x: point.x, y: zone.clampedY)
            }
        }
        return nil
    }

    /// Subtracts a list of intervals from `base`, returning the remaining intervals.
    private static func subtract(
        from base: (CGFloat, CGFloat),
        removing holes: [(CGFloat, CGFloat)]
    ) -> [(CGFloat, CGFloat)] {
        var remaining = [base]
        for hole in holes {
            var next: [(CGFloat, CGFloat)] = []
            for interval in remaining {
                if hole.1 <= interval.0 || hole.0 >= interval.1 {
                    next.append(interval)
                    continue
                }
                if hole.0 > interval.0 { next.append((interval.0, hole.0)) }
                if hole.1 < interval.1 { next.append((hole.1, interval.1)) }
            }
            remaining = next
        }
        return remaining.filter { $0.1 - $0.0 > 0 }
    }
}
