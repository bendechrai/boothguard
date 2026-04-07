import Foundation

/// Lightweight `UserDefaults`-backed bag for the user-tweakable knobs from
/// the spec's Phase 1 settings list. Each property writes through on set so
/// the menu bar handlers always see the latest value.
final class AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let lockMessage = "lockMessage"
        static let lockAllScreens = "lockAllScreens"
        static let launchAtLogin = "launchAtLogin"
        static let imagePath = "lockImagePath"
    }

    var lockMessage: String {
        get { defaults.string(forKey: Key.lockMessage) ?? "This device is locked" }
        set { defaults.set(newValue, forKey: Key.lockMessage) }
    }

    var lockAllScreens: Bool {
        get { defaults.bool(forKey: Key.lockAllScreens) }
        set { defaults.set(newValue, forKey: Key.lockAllScreens) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    var lockImagePath: String? {
        get { defaults.string(forKey: Key.imagePath) }
        set { defaults.set(newValue, forKey: Key.imagePath) }
    }
}
