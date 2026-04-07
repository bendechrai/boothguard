import XCTest
@testable import BoothGuardCore

final class PINValidationTests: XCTestCase {

    func testAcceptsValidPINs() {
        for pin in ["1234", "12345", "123456", "1234567", "12345678"] {
            XCTAssertNil(PINValidation.validate(pin), "expected \(pin) to validate")
        }
    }

    func testRejectsTooShort() {
        XCTAssertEqual(PINValidation.validate("123"), .tooShort)
        XCTAssertEqual(PINValidation.validate(""), .tooShort)
    }

    func testRejectsTooLong() {
        XCTAssertEqual(PINValidation.validate("123456789"), .tooLong)
    }

    func testRejectsNonDigits() {
        XCTAssertEqual(PINValidation.validate("12a4"), .nonDigit)
        XCTAssertEqual(PINValidation.validate("    "), .nonDigit)
    }
}
