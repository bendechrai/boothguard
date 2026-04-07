import Foundation

/// Rules for acceptable PINs per the spec: 4–8 digits, digits only.
public enum PINValidation {
    public static let minLength = 4
    public static let maxLength = 8

    public enum Error: Swift.Error, Equatable {
        case tooShort
        case tooLong
        case nonDigit
    }

    /// Returns `nil` if `pin` is a valid BoothGuard PIN, or the specific
    /// reason it isn't.
    public static func validate(_ pin: String) -> Error? {
        if pin.count < minLength { return .tooShort }
        if pin.count > maxLength { return .tooLong }
        if !pin.allSatisfy({ $0.isASCII && $0.isNumber }) { return .nonDigit }
        return nil
    }
}
