import Foundation

/// Abstract persistence for the stored PIN hash. The production implementation
/// lives in the app target (backed by the macOS Keychain); tests supply an
/// in-memory stub.
public protocol PINStore: AnyObject {
    func load() throws -> PINHasher.HashedPIN?
    func save(_ hashed: PINHasher.HashedPIN) throws
    func clear() throws
}

public final class InMemoryPINStore: PINStore {
    private var stored: PINHasher.HashedPIN?

    public init(initial: PINHasher.HashedPIN? = nil) {
        self.stored = initial
    }

    public func load() throws -> PINHasher.HashedPIN? { stored }
    public func save(_ hashed: PINHasher.HashedPIN) throws { stored = hashed }
    public func clear() throws { stored = nil }
}
