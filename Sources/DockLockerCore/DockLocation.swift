import CoreGraphics

/// Maps the Dock's on-screen window to the display hosting it.
///
/// The Dock process owns exactly one window at the dock window level, and its
/// bounds span the full display the Dock currently lives on — so the host is
/// the display with the largest intersection area.
public enum DockLocation {
    public static func hostDisplayID(
        dockWindowBounds: CGRect,
        displays: [DisplayInfo]
    ) -> UInt32? {
        var best: (id: UInt32, area: CGFloat)?
        for display in displays {
            let overlap = display.cgBounds.intersection(dockWindowBounds)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > 0, area > (best?.area ?? 0) {
                best = (display.id, area)
            }
        }
        return best?.id
    }
}
