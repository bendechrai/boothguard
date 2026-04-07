import Foundation
import Security
import BoothGuardCore

/// Keychain-backed implementation of `PINStore`. The hash blob is stored as a
/// single generic password item with the service `app.boothguard` and account
/// `pin`.
final class KeychainPINStore: PINStore {

    private let service = "app.boothguard"
    private let account = "pin"

    enum Error: Swift.Error {
        case unexpectedStatus(OSStatus)
    }

    func load() throws -> PINHasher.HashedPIN? {
        var query: [String: Any] = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw Error.unexpectedStatus(status)
        }
        return try JSONDecoder().decode(PINHasher.HashedPIN.self, from: data)
    }

    func save(_ hashed: PINHasher.HashedPIN) throws {
        let data = try JSONEncoder().encode(hashed)
        let query = baseQuery()
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess { throw Error.unexpectedStatus(addStatus) }
            return
        }
        throw Error.unexpectedStatus(updateStatus)
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw Error.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
