import AppKit
import ApplicationServices

/// Tracks Accessibility trust for the app's whole lifetime: the grant can
/// appear, be revoked, or stop matching (after an update) at any time.
@MainActor
final class AccessibilityAuthorizer {
    /// Fired on every check; the owner compares against what it last saw.
    var onPoll: (() -> Void)?
    private var pollTimer: Timer?
    private var observer: NSObjectProtocol?

    var isTrusted: Bool { AXIsProcessTrusted() }

    func startMonitoring() {
        guard pollTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.onPoll?() }
        }
        timer.tolerance = 1
        pollTimer = timer
        // Posted when the Accessibility list changes. Undocumented, so the
        // timer stays as the fallback. TCC settles slightly after the post.
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated { self?.onPoll?() }
            }
        }
    }

    /// Shows the system prompt (and lists the app in Settings) unless already
    /// trusted, in which case the call is a no-op.
    func requestIfNeeded() {
        // Literal instead of kAXTrustedCheckOptionPrompt: the global var isn't
        // concurrency-safe under Swift 6. Its value is the key string itself.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Drops the existing (stale) grant so macOS will accept a fresh one for
    /// this build, then asks again. Same effect as `make reset-tcc`.
    func resetAndRequest(completion: @escaping @MainActor () -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = [
            "reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.octa.DockLocker",
        ]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completion()
                    self.requestIfNeeded()
                    self.openSystemSettings()
                }
            }
        }
        do {
            try process.run()
        } catch {
            openSystemSettings()
        }
    }

    func openSystemSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}
