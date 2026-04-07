import XCTest
@testable import BoothGuardCore

final class LockStateMachineTests: XCTestCase {

    private func makeMachine(
        correctPIN: String = "1234",
        now: @escaping () -> Date = Date.init
    ) -> LockStateMachine {
        let config = LockStateMachine.Config(
            attemptsBeforeCooldown: 5,
            baseCooldown: 30,
            now: now
        )
        return LockStateMachine(config: config) { $0 == correctPIN }
    }

    func testStartsUnlocked() {
        let m = makeMachine()
        XCTAssertEqual(m.state, .unlocked)
    }

    func testLockTransitionsToLocked() {
        let m = makeMachine()
        let effects = m.handle(.lock)
        XCTAssertEqual(m.state, .locked)
        XCTAssertEqual(effects, [.entered(.locked)])
    }

    func testCorrectPINUnlocks() {
        let m = makeMachine()
        m.handle(.lock)
        m.handle(.digit("1"))
        m.handle(.digit("2"))
        m.handle(.digit("3"))
        m.handle(.digit("4"))
        let effects = m.handle(.submit)
        XCTAssertEqual(m.state, .unlocked)
        XCTAssertTrue(effects.contains(.unlocked))
    }

    func testIncorrectPINStaysLocked() {
        let m = makeMachine()
        m.handle(.lock)
        for ch in "9999" { m.handle(.digit(ch)) }
        let effects = m.handle(.submit)
        XCTAssertEqual(m.state, .locked)
        XCTAssertTrue(effects.contains(.rejected(remainingAttempts: 4)))
    }

    func testFiveFailedAttemptsTriggerCooldown() {
        var current = Date(timeIntervalSince1970: 1_000)
        let m = makeMachine(now: { current })
        m.handle(.lock)
        for _ in 0..<5 {
            for ch in "0000" { m.handle(.digit(ch)) }
            m.handle(.submit)
        }
        if case .cooldown(let until) = m.state {
            XCTAssertEqual(until.timeIntervalSince1970, 1_030)
        } else {
            XCTFail("Expected cooldown state, got \(m.state)")
        }

        // Tick before expiry: still cooling.
        m.handle(.tick(Date(timeIntervalSince1970: 1_010)))
        if case .cooldown = m.state {} else { XCTFail("Should still be cooling") }

        // Tick after expiry: back to locked.
        current = Date(timeIntervalSince1970: 1_031)
        m.handle(.tick(current))
        XCTAssertEqual(m.state, .locked)
    }

    func testCooldownDoublesEachCycle() {
        var current = Date(timeIntervalSince1970: 0)
        let m = makeMachine(now: { current })
        m.handle(.lock)

        // First cycle: 30s
        for _ in 0..<5 {
            for ch in "0000" { m.handle(.digit(ch)) }
            m.handle(.submit)
        }
        guard case .cooldown(let firstUntil) = m.state else {
            return XCTFail("Expected cooldown")
        }
        XCTAssertEqual(firstUntil.timeIntervalSince1970, 30)

        // Wait it out.
        current = Date(timeIntervalSince1970: 31)
        m.handle(.tick(current))

        // Second cycle: 60s
        for _ in 0..<5 {
            for ch in "0000" { m.handle(.digit(ch)) }
            m.handle(.submit)
        }
        guard case .cooldown(let secondUntil) = m.state else {
            return XCTFail("Expected cooldown")
        }
        XCTAssertEqual(secondUntil.timeIntervalSince1970 - 31, 60)
    }

    func testCorrectPINResetsAttemptCounters() {
        let m = makeMachine()
        m.handle(.lock)
        // Two failures, then success.
        for ch in "0000" { m.handle(.digit(ch)) }
        m.handle(.submit)
        for ch in "0000" { m.handle(.digit(ch)) }
        m.handle(.submit)
        for ch in "1234" { m.handle(.digit(ch)) }
        m.handle(.submit)
        XCTAssertEqual(m.state, .unlocked)
        XCTAssertEqual(m.failedAttemptsInWindow, 0)
        XCTAssertEqual(m.cooldownLevel, 0)
    }

    func testNonDigitsAreIgnored() {
        let m = makeMachine()
        m.handle(.lock)
        let effects = m.handle(.digit("a"))
        XCTAssertEqual(effects, [.invalidInput])
        XCTAssertEqual(m.buffer, "")
    }

    func testBufferRespectsMaxLength() {
        let m = makeMachine()
        m.handle(.lock)
        for _ in 0..<20 { m.handle(.digit("1")) }
        XCTAssertEqual(m.buffer.count, PINValidation.maxLength)
    }

    func testCancelEntryClearsBuffer() {
        let m = makeMachine()
        m.handle(.lock)
        m.handle(.digit("1"))
        m.handle(.digit("2"))
        XCTAssertEqual(m.buffer, "12")
        m.handle(.cancelEntry)
        XCTAssertEqual(m.buffer, "")
    }

    func testEventsBeforeLockAreNoOps() {
        let m = makeMachine()
        XCTAssertEqual(m.handle(.digit("1")), [])
        XCTAssertEqual(m.handle(.submit), [])
        XCTAssertEqual(m.state, .unlocked)
    }

    func testShortBufferIsRejectedOnSubmit() {
        let m = makeMachine()
        m.handle(.lock)
        m.handle(.digit("1"))
        let effects = m.handle(.submit)
        XCTAssertTrue(effects.contains(where: {
            if case .rejected = $0 { return true } else { return false }
        }))
        XCTAssertEqual(m.state, .locked)
    }
}
