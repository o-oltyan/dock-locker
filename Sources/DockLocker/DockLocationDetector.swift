import AppKit
import DockLockerCore

/// Finds the display currently hosting the Dock by locating the Dock
/// process's window at the dock window level (its bounds span the host
/// display). Needs no extra permission — window owner, layer, and bounds are
/// readable without screen recording access.
@MainActor
final class DockLocationDetector {
    func currentDockDisplayID(displays: [DisplayInfo]) -> UInt32? {
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        guard
            let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]]
        else { return nil }

        for window in list {
            guard window[kCGWindowOwnerName as String] as? String == "Dock",
                window[kCGWindowLayer as String] as? Int == dockLevel,
                let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"], let y = bounds["Y"],
                let width = bounds["Width"], let height = bounds["Height"]
            else { continue }
            return DockLocation.hostDisplayID(
                dockWindowBounds: CGRect(x: x, y: y, width: width, height: height),
                displays: displays)
        }
        return nil
    }
}
