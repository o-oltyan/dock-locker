public enum PermissionState: Sendable {
    case trusted
    case untrusted
    /// A grant exists but macOS doesn't honour it for this build — typical
    /// after an update: the grant is pinned to the old signature, so the
    /// toggle in System Settings still looks on.
    case stale

    /// - Parameters:
    ///   - axTrusted: what `AXIsProcessTrusted()` reports right now.
    ///   - tapFailed: the last event-tap creation attempt failed.
    ///   - wasGrantedBefore: a previous launch ran with a working grant.
    public static func resolve(
        axTrusted: Bool, tapFailed: Bool, wasGrantedBefore: Bool
    ) -> PermissionState {
        if axTrusted { return tapFailed ? .stale : .trusted }
        return wasGrantedBefore ? .stale : .untrusted
    }
}
