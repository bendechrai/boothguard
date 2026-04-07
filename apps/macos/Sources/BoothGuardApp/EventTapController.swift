import AppKit
import CoreGraphics
import os.log

/// Owns the session-level CGEvent tap that intercepts and (when locked)
/// suppresses keyboard, trackpad, and mouse input. Keystrokes that arrive
/// while the tap is suppressing are forwarded to a `keystrokeHandler` so the
/// PIN entry buffer can be fed without producing visible side effects.
final class EventTapController {

    /// Result returned by the keystroke handler so the controller knows
    /// whether to swallow the event silently or let it through.
    enum KeystrokeDecision {
        case suppress
        case passthrough
    }

    var isSuppressing: Bool = false {
        didSet {
            // No tap-state changes needed; the callback reads the flag live.
        }
    }

    /// Invoked on the main queue with each typed character while suppressing.
    /// Returning `.passthrough` lets the event through unchanged (used for
    /// emergency escape hatches if ever needed). Default behaviour swallows
    /// every event.
    var keystrokeHandler: ((Character) -> KeystrokeDecision)?

    /// Invoked on the main queue when the user presses Return while
    /// suppressing — used to submit the buffered PIN.
    var submitHandler: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let log = Logger(subsystem: "app.boothguard", category: "EventTap")

    private static let interestingMask: CGEventMask = {
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .mouseMoved,
            .leftMouseDragged, .rightMouseDragged,
            .scrollWheel,
            .otherMouseDown, .otherMouseUp
        ]
        return types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    }()

    /// Installs the event tap. Returns false if Accessibility / Input
    /// Monitoring permission has not been granted — the caller is expected
    /// to drive the onboarding flow.
    @discardableResult
    func install() -> Bool {
        guard eventTap == nil else { return true }

        let opaque = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.interestingMask,
            callback: EventTapController.tapCallback,
            userInfo: opaque
        ) else {
            log.error("Failed to create CGEvent tap. Permission denied?")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        return true
    }

    func uninstall() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Re-enables the tap. macOS disables a tap if its callback is too slow
    /// or if a long-press triggers `.tapDisabledByUserInput`.
    private func reenable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        log.notice("Re-enabled CGEvent tap after disable.")
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()

        // Health: re-enable if the system disables us.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { controller.reenable() }
            return Unmanaged.passUnretained(event)
        }

        guard controller.isSuppressing else {
            return Unmanaged.passUnretained(event)
        }

        // Feed digits / Return into the PIN handler. Everything else is
        // dropped wholesale.
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if let character = Self.character(forKeyCode: Int(keyCode)) {
                DispatchQueue.main.async {
                    if character == "\r" {
                        controller.submitHandler?()
                    } else if let handler = controller.keystrokeHandler,
                              case .passthrough = handler(character) {
                        // (Unused today; reserved for future escape hatches.)
                    }
                }
            }
        }
        return nil
    }

    /// Maps the small set of key codes we care about (digits + Return) to
    /// characters without going through the full Carbon translation API.
    private static func character(forKeyCode keyCode: Int) -> Character? {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 82: return "0" // keypad 0
        case 83: return "1"
        case 84: return "2"
        case 85: return "3"
        case 86: return "4"
        case 87: return "5"
        case 88: return "6"
        case 89: return "7"
        case 91: return "8"
        case 92: return "9"
        case 36, 76: return "\r" // Return / keypad enter
        default: return nil
        }
    }
}
