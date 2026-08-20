import Foundation
import CryptoKit
import FoodMapDomain

/// Where the private half of a reader's identity lives.
///
/// A protocol rather than a direct Keychain call so the sealing can be tested on macOS without a
/// keychain entitlement. The shipped app uses `KeychainSeedStore`; the tests use an in-memory one
/// and exercise exactly the same crypto.
public protocol IdentitySeedStore: Sendable {
    func loadSeed() throws -> Data?
    func saveSeed(_ seed: Data) throws
}

/// This device's identity, and the sealing that keeps a stamp readable only by the friends it was
/// written for.
///
/// One 32-byte seed is stored, and both keypairs are derived from it:
///
/// - an **ed25519** pair, whose public half is the `FriendKey` — the identity ADR-009 keeps from
///   ADR-008, and what a stamp is signed with so a carrier could never forge one;
/// - an **X25519** pair for key agreement, because a signing key cannot do agreement and sealing
///   needs one.
///
/// Deriving both from a single seed rather than storing two keys means device migration has one
/// secret to carry, not two.
public final class PeerIdentityStore: PeerIdentityPort, @unchecked Sendable {
    private let seedStore: any IdentitySeedStore
    private let directory: any FriendAgreementKeyDirectory

    private let signing: Curve25519.Signing.PrivateKey
    private let agreement: Curve25519.KeyAgreement.PrivateKey

    public init(seedStore: any IdentitySeedStore, directory: any FriendAgreementKeyDirectory) throws {
        self.seedStore = seedStore
        self.directory = directory

        let seed: Data
        if let existing = try seedStore.loadSeed() {
            seed = existing
        } else {
            // First launch. Nothing is registered anywhere: this is the whole of the account.
            seed = SymmetricKey(size: .bits256).rawBytes
            try seedStore.saveSeed(seed)
        }

        let material = SymmetricKey(data: seed)
        signing = try Curve25519.Signing.PrivateKey(rawRepresentation: Self.derive(material, "signing"))
        agreement = try Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: Self.derive(material, "agreement")
        )
    }

    public var publicKey: FriendKey {
        FriendKey(bytes: Array(signing.publicKey.rawRepresentation))!
    }

    /// The half a friend needs in order to seal something for this device. Exchanged over the
    /// radio at the table, alongside the identity key.
    public var agreementPublicKey: Data { agreement.publicKey.rawRepresentation }

    public func seal(_ payload: Data, for recipients: [FriendKey]) throws -> Data {
        let resolved = try recipients.map { key -> (key: FriendKey, agreementKey: Curve25519.KeyAgreement.PublicKey) in
            guard let raw = directory.agreementKey(for: key),
                  let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)
            else { throw SealingError.unknownRecipient }
            return (key, publicKey)
        }
        // Sealed for the reader as well, so a device that re-downloads its own zone can still
        // read it — friend data is a disposable cache, and so is this.
        let all = resolved + [(publicKey, agreement.publicKey)]
        return try StampSealing.seal(payload, from: agreement, to: all)
    }

    public func open(_ sealed: Data) throws -> Data {
        try StampSealing.open(sealed, as: publicKey, using: agreement)
    }

    public func sign(_ payload: Data) throws -> Data {
        try signing.signature(for: payload)
    }

    public func isSignature(_ signature: Data, validFor payload: Data, from author: FriendKey) -> Bool {
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: Data(author.bytes)) else {
            return false
        }
        return key.isValidSignature(signature, for: payload)
    }

    /// HKDF with a per-purpose label, so the two keypairs cannot be derived from one another.
    private static func derive(_ material: SymmetricKey, _ purpose: String) -> Data {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: material,
            salt: Data("nomstamp.identity.v1".utf8),
            info: Data(purpose.utf8),
            outputByteCount: 32
        ).rawBytes
    }
}

/// Which X25519 key belongs to which friend, learned at the table when they were connected.
///
/// Kept out of the domain deliberately: `Friend` carries the identity a reader thinks in — a key,
/// a name, an ink — and not the second key that only the sealing needs.
public protocol FriendAgreementKeyDirectory: Sendable {
    func agreementKey(for friend: FriendKey) -> Data?
    func record(agreementKey: Data, for friend: FriendKey)
}

/// The default directory: a plist beside the rest of the friend cache. Losing it costs a re-add,
/// which is the same cost as losing any other friend data.
public final class FileAgreementKeyDirectory: FriendAgreementKeyDirectory, @unchecked Sendable {
    private let url: URL
    private var keys: [String: Data]
    private let lock = NSLock()

    public init(url: URL) {
        self.url = url
        let stored = (try? Data(contentsOf: url)).flatMap {
            try? JSONDecoder().decode([String: Data].self, from: $0)
        }
        keys = stored ?? [:]
    }

    public func agreementKey(for friend: FriendKey) -> Data? {
        lock.withLock { keys[StampSealing.label(for: friend)] }
    }

    public func record(agreementKey: Data, for friend: FriendKey) {
        lock.withLock {
            keys[StampSealing.label(for: friend)] = agreementKey
            try? JSONEncoder().encode(keys).write(to: url, options: .atomic)
        }
    }
}

/// An in-memory seed store. Used by the tests, and by nothing that ships.
public final class InMemorySeedStore: IdentitySeedStore, @unchecked Sendable {
    private var seed: Data?
    public init(seed: Data? = nil) { self.seed = seed }
    public func loadSeed() throws -> Data? { seed }
    public func saveSeed(_ seed: Data) throws { self.seed = seed }
}

public final class InMemoryAgreementKeyDirectory: FriendAgreementKeyDirectory, @unchecked Sendable {
    private var keys: [String: Data] = [:]
    public init() {}
    public func agreementKey(for friend: FriendKey) -> Data? { keys[StampSealing.label(for: friend)] }
    public func record(agreementKey: Data, for friend: FriendKey) {
        keys[StampSealing.label(for: friend)] = agreementKey
    }
}
