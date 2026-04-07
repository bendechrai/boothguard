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

    public static func validate(_ pin: String) -> Result<Void, Error> {
        if pin.count < minLength { return .failure(.tooShort) }
        if pin.count > maxLength { return .failure(.tooLong) }
        if !pin.allSatisfy({ $0.isASCII && $0.isNumber }) { return .failure(.nonDigit) }
        return .success(())
    }
}
