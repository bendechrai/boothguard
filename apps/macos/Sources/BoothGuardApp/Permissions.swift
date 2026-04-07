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
        // `kAXTrustedCheckOptionPrompt` is imported as `Unmanaged<CFString>`
        // by the macOS 14 SDK, so we have to unwrap it before bridging to
        // String for the options dictionary key.
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
