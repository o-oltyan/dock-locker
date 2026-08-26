import AppKit
import DockLockerCore

/// Snapshots the connected displays in CG global space and re-snapshots
/// (debounced) whenever the display configuration changes.
@MainActor
final class ScreenManager {
    private(set) var displays: [DisplayInfo] = []
    var onChange: (() -> Void)?

    private var debounceWork: DispatchWorkItem?

    init() {
        refresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    /// Resolves the persisted anchor to a connected display.
    /// Order: UUID match, then name match, then the main display.
    func resolveAnchor(uuid: String?, name: String?) -> (display: DisplayInfo, isFallback: Bool) {
        if let uuid, let match = displays.first(where: { $0.uuid == uuid }) {
            return (match, false)
        }
        if let name, let match = displays.first(where: { $0.name == name }) {
            return (match, false)
        }
        let mainID = CGMainDisplayID()
        let main = displays.first { $0.id == mainID } ?? displays[0]
        // Only a fallback if the user had actually picked a display.
        return (main, uuid != nil || name != nil)
    }

    func refresh() {
        displays = Self.snapshot()
    }

    @objc private func screenParametersChanged() {
        // The notification fires in bursts during reconfiguration; debounce.
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.refresh()
            self.onChange?()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private static func snapshot() -> [DisplayInfo] {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        return (0..<Int(count)).map { index in
            let id = ids[index]
            let uuid: String =
                CGDisplayCreateUUIDFromDisplayID(id).map {
                    CFUUIDCreateString(nil, $0.takeRetainedValue()) as String
                } ?? ""
            let name =
                NSScreen.screens.first {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                        .uint32Value == id
                }?.localizedName ?? "Display \(id)"
            return DisplayInfo(id: id, uuid: uuid, name: name, cgBounds: CGDisplayBounds(id))
        }
    }
}
