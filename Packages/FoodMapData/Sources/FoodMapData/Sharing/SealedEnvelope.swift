import Foundation
import CryptoKit
import FoodMapDomain

public enum SealingError: Error, Equatable {
    case unknownRecipient
    case notARecipient
    case malformed
}

/// What CloudKit actually stores: ciphertext, and one wrapped key per friend.
///
/// The scheme is the ordinary one. Each stamp gets a fresh symmetric content key; the payload is
/// sealed with it once; the content key is then wrapped separately for each recipient. Eight
/// friends costs eight wrapped keys — a few hundred bytes — rather than eight copies of the
/// photograph.
///
/// It is also the per-recipient encryption ADR-008 said a friend-of-friend mesh would need in v2.
/// Building it now means that option stays open instead of requiring a format change to
/// connections people have already made.
struct SealedEnvelope: Codable, Equatable {
    /// The sender's X25519 public key. Present so a recipient can complete the agreement without
    /// having to have already learned it.
    let senderAgreementKey: Data
    let nonce: Data
    let ciphertext: Data
    let tag: Data
    /// Recipient fingerprint → the content key, wrapped to that recipient.
    let wrappedKeys: [String: WrappedKey]

    struct WrappedKey: Codable, Equatable {
        let nonce: Data
        let ciphertext: Data
        let tag: Data
    }
}

/// Sealing and opening, with the keys the device already holds.
///
/// Apple stores what this produces and cannot open it, whether or not the reader has Advanced
/// Data Protection switched on. That is what keeps ADR-009's privacy claim standing after the
/// transport moved to someone else's servers: *no third party can read it* replaces ADR-008's
/// *no third party holds a copy*, and the difference is this file.
enum StampSealing {
    /// A short, stable label for a public key, used to find one's own wrapped key in an envelope
    /// without revealing anything the record does not already carry.
    static func label(for key: FriendKey) -> String {
        SHA256.hash(data: Data(key.bytes)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    static func seal(
        _ payload: Data,
        from sender: Curve25519.KeyAgreement.PrivateKey,
        to recipients: [(key: FriendKey, agreementKey: Curve25519.KeyAgreement.PublicKey)]
    ) throws -> Data {
        let contentKey = SymmetricKey(size: .bits256)
        let sealed = try AES.GCM.seal(payload, using: contentKey)

        var wrapped: [String: SealedEnvelope.WrappedKey] = [:]
        for recipient in recipients {
            let wrappingKey = try sharedKey(sender: sender, recipient: recipient.agreementKey)
            let box = try AES.GCM.seal(contentKey.rawBytes, using: wrappingKey)
            wrapped[label(for: recipient.key)] = SealedEnvelope.WrappedKey(
                nonce: Data(box.nonce), ciphertext: box.ciphertext, tag: box.tag
            )
        }

        let envelope = SealedEnvelope(
            senderAgreementKey: sender.publicKey.rawRepresentation,
            nonce: Data(sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag,
            wrappedKeys: wrapped
        )
        return try JSONEncoder().encode(envelope)
    }

    static func open(
        _ data: Data,
        as reader: FriendKey,
        using agreement: Curve25519.KeyAgreement.PrivateKey
    ) throws -> Data {
        guard let envelope = try? JSONDecoder().decode(SealedEnvelope.self, from: data) else {
            throw SealingError.malformed
        }
        guard let mine = envelope.wrappedKeys[label(for: reader)] else {
            throw SealingError.notARecipient
        }
        let senderKey = try Curve25519.KeyAgreement.PublicKey(
            rawRepresentation: envelope.senderAgreementKey
        )
        let wrappingKey = try sharedKey(sender: agreement, recipient: senderKey)

        let wrappedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: mine.nonce), ciphertext: mine.ciphertext, tag: mine.tag
        )
        let contentKey = SymmetricKey(data: try AES.GCM.open(wrappedBox, using: wrappingKey))

        let payloadBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: envelope.nonce),
            ciphertext: envelope.ciphertext,
            tag: envelope.tag
        )
        return try AES.GCM.open(payloadBox, using: contentKey)
    }

    /// X25519 agreement, then HKDF. The salt is a constant rather than random because both sides
    /// must derive the same key from nothing but their two keypairs.
    private static func sharedKey(
        sender: Curve25519.KeyAgreement.PrivateKey,
        recipient: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        try sender.sharedSecretFromKeyAgreement(with: recipient)
            .hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: Data("nomstamp.stamp.v1".utf8),
                sharedInfo: Data(),
                outputByteCount: 32
            )
    }
}

extension SymmetricKey {
    var rawBytes: Data { withUnsafeBytes { Data($0) } }
}
