import CoreGraphics

/// A snapshot of one connected display.
///
/// `cgBounds` is in CG global space (top-left origin, y grows downward) — the
/// same space `CGEvent.location` reports in, so clamp zones built from it need
/// no coordinate conversion in the event-tap hot path.
public struct DisplayInfo: Equatable, Sendable {
    public let id: UInt32
    public let uuid: String
    public let name: String
    public let cgBounds: CGRect

    public init(id: UInt32, uuid: String, name: String, cgBounds: CGRect) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.cgBounds = cgBounds
    }
}
