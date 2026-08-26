import AppKit
import DockLockerCore

@preconcurrency import CoreGraphics

/// Owns the modifying CGEvent tap. The callback runs on the main run loop
/// (the tap's source is added to the main run loop), so all state here is
/// MainActor-isolated with no extra synchronization.
@MainActor
final class EventTapManager {
    /// Immutable array swapped wholesale on the main thread; read in the callback.
    var zones: [ClampZone] = []
    /// Holding these flags bypasses clamping so the Dock can be moved normally.
    var bypassFlags: CGEventFlags = ModifierKey.default.flags

    /// Some keyboards deliver Fn only on flagsChanged, not on mouse events —
    /// the bypass check unions the mouse event's flags with this cache.
    private var lastKnownFlags: CGEventFlags = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    /// Guards against re-enabling in the callback after an intentional disable.
    private var intendedEnabled = false

    var isRunning: Bool { tap != nil }

    /// Creates and enables the tap. Returns false if creation failed
    /// (Accessibility not granted, or a stale TCC grant).
    func start() -> Bool {
        if tap != nil {
            setEnabled(true)
            return true
        }
        let mask: CGEventMask =
            (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
            | (1 << CGEventType.rightMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: eventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        intendedEnabled = true
        return true
    }

    /// Toggling uses CGEvent.tapEnable so a disabled tap adds zero input
    /// latency; the port and run-loop source stay alive until stop().
    func setEnabled(_ enabled: Bool) {
        intendedEnabled = enabled
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: enabled)
    }

    func stop() {
        intendedEnabled = false
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if intendedEnabled, let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            lastKnownFlags = event.flags
            return Unmanaged.passUnretained(event)
        default:
            if event.flags.union(lastKnownFlags).contains(bypassFlags) {
                return Unmanaged.passUnretained(event)
            }
            if let clamped = ClampZone.clampedLocation(for: event.location, in: zones) {
                // mouseMoved: swallow the event entirely — the Dock never
                // learns the cursor reached the edge (DockAnchor-proven at
                // this tap location). Drags: clamp the location instead so
                // an in-flight drag keeps tracking (docklock-proven).
                if type == .mouseMoved { return nil }
                event.location = clamped
            }
            return Unmanaged.passUnretained(event)
        }
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    // The tap's run-loop source lives on the main run loop, so this is safe.
    return MainActor.assumeIsolated {
        manager.handle(type: type, event: event)
    }
}
