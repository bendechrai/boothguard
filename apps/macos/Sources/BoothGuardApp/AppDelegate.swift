import AppKit
import BoothGuardCore
import os

/// Top-level coordinator. Owns the menu bar item, the lock state machine,
/// the event tap, and the lock overlay, wires their callbacks together, and
/// presents the settings window on demand.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let settings = AppSettings()
    private let pinStore: PINStore = KeychainPINStore()
    private let overlay = LockOverlay()
    private let eventTap = EventTapController()
    private var stateMachine: LockStateMachine!
    private var statusItem: NSStatusItem!
    private var settingsWC: SettingsWindowController?
    private var cooldownTimer: Timer?
    private let log = Logger(subsystem: "app.boothguard", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        stateMachine = LockStateMachine(verify: { [weak self] candidate in
            guard let self else { return false }
            guard let stored = (try? self.pinStore.load()) ?? nil else { return false }
            return PINHasher.verify(pin: candidate, against: stored)
        })

        installStatusItem()
        installEventTap()

        eventTap.submitHandler = { [weak self] in self?.handle(.submit) }
        eventTap.keystrokeHandler = { [weak self] character in
            self?.handle(.digit(character))
            return .suppress
        }

        if !Permissions.hasInputMonitoring() {
            Permissions.requestInputMonitoring()
        }
        if !Permissions.hasAccessibility() {
            Permissions.requestAccessibility()
        }
    }

    // MARK: - Menu bar

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: "BoothGuard")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let lockTitle = stateMachine.state == .unlocked ? "Lock" : "Locked"
        let lockItem = NSMenuItem(title: lockTitle, action: #selector(lockNow), keyEquivalent: "l")
        lockItem.keyEquivalentModifierMask = [.command, .control]
        lockItem.target = self
        lockItem.isEnabled = stateMachine.state == .unlocked
        menu.addItem(lockItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit BoothGuard", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        // The spec says Quit must be disabled while locked.
        quitItem.isEnabled = stateMachine.state == .unlocked
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let name = stateMachine.state == .unlocked ? "lock.open" : "lock.fill"
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "BoothGuard")
    }

    @objc private func lockNow() {
        guard ((try? pinStore.load()) ?? nil) != nil else {
            presentNoPINAlert()
            return
        }
        handle(.lock)
    }

    @objc private func openSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController(settings: settings, pinStore: pinStore)
        }
        settingsWC?.present()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func presentNoPINAlert() {
        let alert = NSAlert()
        alert.messageText = "Set a PIN first"
        alert.informativeText = "BoothGuard needs a PIN before it can lock the device. Open Settings to set one."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    // MARK: - Event tap

    private func installEventTap() {
        if !eventTap.install() {
            log.error("Event tap install failed; check Accessibility/Input Monitoring permissions.")
        }
    }

    // MARK: - State machine plumbing

    private func handle(_ event: LockStateMachine.Event) {
        let effects = stateMachine.handle(event)
        for effect in effects { apply(effect) }
        updateStatusIcon()
        rebuildMenu()
    }

    private func apply(_ effect: LockStateMachine.Effect) {
        switch effect {
        case .entered(let state):
            switch state {
            case .locked:
                overlay.message = settings.lockMessage
                overlay.lockAllScreens = settings.lockAllScreens
                overlay.show()
                eventTap.isSuppressing = true
            case .unlocked:
                overlay.hide()
                eventTap.isSuppressing = false
                stopCooldownTimer()
            case .cooldown:
                // Stay suppressed; overlay text updated by cooldown handler.
                eventTap.isSuppressing = true
            }
        case .unlocked:
            log.notice("Unlocked via PIN.")
        case .rejected(let remaining):
            overlay.shake()
            overlay.showHint("Incorrect PIN — \(remaining) attempt(s) left")
        case .cooldownStarted(let until):
            startCooldownTimer(until: until)
        case .cooldownEnded:
            overlay.showHint("Enter PIN to unlock")
        case .bufferChanged:
            // Intentionally invisible per spec — no buffer indicator.
            break
        case .invalidInput:
            break
        }
    }

    private func startCooldownTimer(until: Date) {
        stopCooldownTimer()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let now = Date()
            if now >= until {
                self.handle(.tick(now))
                self.stopCooldownTimer()
            } else {
                self.overlay.showCooldown(remaining: until.timeIntervalSince(now))
            }
        }
    }

    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }
}
