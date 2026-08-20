import Foundation
import Security

/// The reader's identity seed, in the Keychain.
///
/// This is the whole of the account: 32 bytes nobody registered and nothing can look up. Losing
/// the phone loses the connections, and friends must re-add — an identity transfer during device
/// migration is a known gap (ADR-009).
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` rather than the default: sync must be able
/// to run in the background after a silent push, which means the seed has to be readable while
/// the phone is locked, and *this device only* keeps the identity from being copied into an
/// iCloud Keychain backup where it would become two devices claiming one identity.
public struct KeychainSeedStore: IdentitySeedStore {
    private let service: String
    private let account = "identity-seed"

    public init(service: String = "com.nomstamp.identity") {
        self.service = service
    }

    public func loadSeed() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError.unexpected(status)
        }
    }

    public func saveSeed(_ seed: Data) throws {
        var attributes = baseQuery
        attributes[kSecValueData as String] = seed
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw KeychainError.unexpected(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public enum KeychainError: Error, Equatable {
    case unexpected(OSStatus)
}
