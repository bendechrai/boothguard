import XCTest
@testable import BoothGuardCore

final class PINValidationTests: XCTestCase {

    func testAcceptsValidPINs() {
        for pin in ["1234", "12345", "123456", "1234567", "12345678"] {
            XCTAssertEqual(PINValidation.validate(pin), .success(()))
        }
    }

    func testRejectsTooShort() {
        XCTAssertEqual(PINValidation.validate("123"), .failure(.tooShort))
        XCTAssertEqual(PINValidation.validate(""), .failure(.tooShort))
    }

    func testRejectsTooLong() {
        XCTAssertEqual(PINValidation.validate("123456789"), .failure(.tooLong))
    }

    func testRejectsNonDigits() {
        XCTAssertEqual(PINValidation.validate("12a4"), .failure(.nonDigit))
        XCTAssertEqual(PINValidation.validate("    "), .failure(.nonDigit))
    }
}
