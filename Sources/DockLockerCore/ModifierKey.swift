import CoreGraphics

/// The key the user holds to temporarily let the Dock move between displays.
public enum ModifierKey: String, CaseIterable, Sendable {
    case fn
    case control
    case option
    case command
    case shift

    public static let `default`: ModifierKey = .fn

    public var flags: CGEventFlags {
        switch self {
        case .fn: .maskSecondaryFn
        case .control: .maskControl
        case .option: .maskAlternate
        case .command: .maskCommand
        case .shift: .maskShift
        }
    }

    public var displayName: String {
        switch self {
        case .fn: "Fn (Globe 🌐)"
        case .control: "Control (⌃)"
        case .option: "Option (⌥)"
        case .command: "Command (⌘)"
        case .shift: "Shift (⇧)"
        }
    }
}
