import AppKit
import ApplicationServices

/// Tracks Accessibility trust: prompts once, then polls until granted.
@MainActor
final class AccessibilityAuthorizer {
    var onTrusted: (() -> Void)?
    private var pollTimer: Timer?

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestIfNeeded() {
        if isTrusted {
            onTrusted?()
            return
        }
        // Literal instead of kAXTrustedCheckOptionPrompt: the global var isn't
        // concurrency-safe under Swift 6. Its value is the key string itself.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    func openSystemSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isTrusted else { return }
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                self.onTrusted?()
            }
        }
    }
}
