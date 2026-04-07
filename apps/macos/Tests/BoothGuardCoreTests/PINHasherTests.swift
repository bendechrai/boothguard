import XCTest
@testable import BoothGuardCore

final class PINHasherTests: XCTestCase {

    func testHashAndVerifyRoundTrip() {
        let hashed = PINHasher.hash(pin: "1234", iterations: 1_000)
        XCTAssertTrue(PINHasher.verify(pin: "1234", against: hashed))
    }

    func testWrongPINFailsVerification() {
        let hashed = PINHasher.hash(pin: "1234", iterations: 1_000)
        XCTAssertFalse(PINHasher.verify(pin: "0000", against: hashed))
        XCTAssertFalse(PINHasher.verify(pin: "12345", against: hashed))
        XCTAssertFalse(PINHasher.verify(pin: "", against: hashed))
    }

    func testTwoHashesOfSamePINUseDifferentSalts() {
        let a = PINHasher.hash(pin: "1234", iterations: 1_000)
        let b = PINHasher.hash(pin: "1234", iterations: 1_000)
        XCTAssertNotEqual(a.salt, b.salt)
        XCTAssertNotEqual(a.hash, b.hash)
        XCTAssertTrue(PINHasher.verify(pin: "1234", against: a))
        XCTAssertTrue(PINHasher.verify(pin: "1234", against: b))
    }

    func testHashedPINCodableRoundTrip() throws {
        let hashed = PINHasher.hash(pin: "9876", iterations: 1_000)
        let data = try JSONEncoder().encode(hashed)
        let decoded = try JSONDecoder().decode(PINHasher.HashedPIN.self, from: data)
        XCTAssertEqual(hashed, decoded)
        XCTAssertTrue(PINHasher.verify(pin: "9876", against: decoded))
    }
}
