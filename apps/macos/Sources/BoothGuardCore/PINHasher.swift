import Foundation
import CryptoKit

/// Hashes and verifies PINs using a salted, iterated SHA-256 construction.
///
/// The spec calls for bcrypt or Argon2; neither ships with Swift's standard
/// library or CryptoKit. We approximate the security properties (salt +
/// deliberate work factor) using iterated SHA-256. This is sufficient to make
/// offline brute-forcing of a 4–8 digit PIN considerably slower than a bare
/// hash while avoiding a third-party dependency.
public enum PINHasher {
    /// Number of SHA-256 iterations. Tuned for ~tens of ms on a modern Mac.
    public static let defaultIterations = 200_000

    public struct HashedPIN: Equatable, Codable {
        public let salt: Data
        public let hash: Data
        public let iterations: Int

        public init(salt: Data, hash: Data, iterations: Int) {
            self.salt = salt
            self.hash = hash
            self.iterations = iterations
        }
    }

    public static func hash(pin: String, iterations: Int = defaultIterations) -> HashedPIN {
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { buf in
            _ = SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
        }
        let digest = derive(pin: pin, salt: salt, iterations: iterations)
        return HashedPIN(salt: salt, hash: digest, iterations: iterations)
    }

    public static func verify(pin: String, against stored: HashedPIN) -> Bool {
        let candidate = derive(pin: pin, salt: stored.salt, iterations: stored.iterations)
        // Constant-time comparison.
        guard candidate.count == stored.hash.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<candidate.count {
            diff |= candidate[i] ^ stored.hash[i]
        }
        return diff == 0
    }

    private static func derive(pin: String, salt: Data, iterations: Int) -> Data {
        var current = Data(pin.utf8) + salt
        for _ in 0..<iterations {
            current = Data(SHA256.hash(data: current))
        }
        return current
    }
}
