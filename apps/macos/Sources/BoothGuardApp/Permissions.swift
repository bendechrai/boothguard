import AppKit
import ApplicationServices

/// Wrappers around the macOS Accessibility / Input Monitoring permission
/// APIs. The CGEvent tap requires both — Accessibility for the tap itself
/// and Input Monitoring for global key listening on macOS 10.15+.
enum Permissions {

    static func hasInputMonitoring() -> Bool {
        // CGPreflight* APIs are present on macOS 10.15+.
        return CGPreflightListenEventAccess()
    }

    static func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
    }

    static func hasAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
