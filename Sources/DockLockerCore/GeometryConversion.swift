import CoreGraphics

/// Conversions between the two global coordinate spaces on macOS.
///
/// Cocoa (`NSScreen`, `NSEvent.mouseLocation`) uses a bottom-left origin with y
/// growing upward. CoreGraphics (`CGEvent.location`, `CGDisplayBounds`) uses a
/// top-left origin with y growing downward. Both share the main display as the
/// reference: the flip axis is the main display's height, so the conversion is
/// its own inverse.
public enum GeometryConversion {
    public static func cgPoint(fromCocoa point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: mainDisplayHeight - point.y)
    }

    public static func cocoaPoint(fromCG point: CGPoint, mainDisplayHeight: CGFloat) -> CGPoint {
        cgPoint(fromCocoa: point, mainDisplayHeight: mainDisplayHeight)
    }

    public static func cgRect(fromCocoa rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: mainDisplayHeight - (rect.origin.y + rect.height),
            width: rect.width,
            height: rect.height)
    }

    public static func cocoaRect(fromCG rect: CGRect, mainDisplayHeight: CGFloat) -> CGRect {
        cgRect(fromCocoa: rect, mainDisplayHeight: mainDisplayHeight)
    }
}
