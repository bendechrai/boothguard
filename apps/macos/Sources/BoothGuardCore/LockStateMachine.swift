import Foundation

/// Pure, platform-agnostic lock/unlock state machine with brute-force cooldown.
///
/// The state machine owns the PIN-entry buffer, attempt counter, and cooldown
/// schedule. It is driven by events (`lock`, `keystroke`, `tick`) and emits
/// effects (`unlocked`, `rejected`, `cooldownStarted`, …) for a host layer to
/// react to — e.g. tearing down the lock overlay or playing a shake animation.
public final class LockStateMachine {

    public enum State: Equatable {
        case unlocked
        case locked
        case cooldown(until: Date)
    }

    public enum Event {
        case lock
        case digit(Character)
        case submit
        case cancelEntry
        /// Called periodically so the machine can leave cooldown.
        case tick(Date)
    }

    public enum Effect: Equatable {
        case entered(State)
        case unlocked
        case rejected(remainingAttempts: Int)
        case cooldownStarted(until: Date)
        case cooldownEnded
        case bufferChanged(length: Int)
        case invalidInput
    }

    public struct Config {
        public var attemptsBeforeCooldown: Int
        public var baseCooldown: TimeInterval
        public var maxBufferLength: Int
        public var now: () -> Date

        public init(
            attemptsBeforeCooldown: Int = 5,
            baseCooldown: TimeInterval = 30,
            maxBufferLength: Int = PINValidation.maxLength,
            now: @escaping () -> Date = Date.init
        ) {
            self.attemptsBeforeCooldown = attemptsBeforeCooldown
            self.baseCooldown = baseCooldown
            self.maxBufferLength = maxBufferLength
            self.now = now
        }
    }

    public private(set) var state: State = .unlocked
    public private(set) var buffer: String = ""
    /// Number of failed attempts in the current 5-attempt window.
    public private(set) var failedAttemptsInWindow: Int = 0
    /// Number of completed cooldown cycles — used to double the penalty.
    public private(set) var cooldownLevel: Int = 0

    private let config: Config
    private let verify: (String) -> Bool

    /// - Parameter verify: callback that returns true iff the supplied PIN is
    ///   correct. Implementations typically delegate to `PINHasher.verify`.
    public init(config: Config = .init(), verify: @escaping (String) -> Bool) {
        self.config = config
        self.verify = verify
    }

    @discardableResult
    public func handle(_ event: Event) -> [Effect] {
        switch event {
        case .lock:
            return lock()
        case .digit(let c):
            return appendDigit(c)
        case .submit:
            return submit()
        case .cancelEntry:
            return clearBuffer()
        case .tick(let date):
            return tick(date)
        }
    }

    // MARK: - Handlers

    private func lock() -> [Effect] {
        guard state == .unlocked else { return [] }
        state = .locked
        buffer = ""
        return [.entered(.locked)]
    }

    private func appendDigit(_ c: Character) -> [Effect] {
        guard case .locked = state else { return [] }
        guard c.isASCII, c.isNumber else { return [.invalidInput] }
        guard buffer.count < config.maxBufferLength else { return [] }
        buffer.append(c)
        return [.bufferChanged(length: buffer.count)]
    }

    private func submit() -> [Effect] {
        guard case .locked = state else { return [] }
        let candidate = buffer
        buffer = ""
        // Always clear the buffer, whether or not it was a valid length.
        guard candidate.count >= PINValidation.minLength else {
            return [.bufferChanged(length: 0), .rejected(remainingAttempts: remainingAttempts())]
        }
        if verify(candidate) {
            state = .unlocked
            failedAttemptsInWindow = 0
            cooldownLevel = 0
            return [.bufferChanged(length: 0), .unlocked, .entered(.unlocked)]
        }
        failedAttemptsInWindow += 1
        var effects: [Effect] = [.bufferChanged(length: 0)]
        if failedAttemptsInWindow >= config.attemptsBeforeCooldown {
            let penalty = config.baseCooldown * pow(2.0, Double(cooldownLevel))
            let until = config.now().addingTimeInterval(penalty)
            state = .cooldown(until: until)
            failedAttemptsInWindow = 0
            cooldownLevel += 1
            effects.append(.cooldownStarted(until: until))
            effects.append(.entered(.cooldown(until: until)))
        } else {
            effects.append(.rejected(remainingAttempts: remainingAttempts()))
        }
        return effects
    }

    private func clearBuffer() -> [Effect] {
        guard case .locked = state, !buffer.isEmpty else { return [] }
        buffer = ""
        return [.bufferChanged(length: 0)]
    }

    private func tick(_ now: Date) -> [Effect] {
        guard case .cooldown(let until) = state else { return [] }
        if now >= until {
            state = .locked
            return [.cooldownEnded, .entered(.locked)]
        }
        return []
    }

    private func remainingAttempts() -> Int {
        max(0, config.attemptsBeforeCooldown - failedAttemptsInWindow)
    }
}
