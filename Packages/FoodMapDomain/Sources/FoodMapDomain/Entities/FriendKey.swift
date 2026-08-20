import Foundation

/// A reader's identity: the public half of the ed25519 keypair the device generates on first
/// launch (FR-10.1).
///
/// The domain holds the bytes and nothing else. Generating the pair, keeping the private half in
/// the Keychain and signing with it are all `PeerIdentityPort`'s business — CryptoKit is an Apple
/// framework, and CON-5 keeps those out of here so these rules stay provable in milliseconds.
public struct FriendKey: Equatable, Hashable, Sendable, Comparable {
    public static let byteCount = 32

    public let bytes: [UInt8]

    /// Fails rather than truncates: a key of the wrong length is a bug somewhere upstream, and
    /// silently padding it would make two different readers look like one.
    public init?(bytes: [UInt8]) {
        guard bytes.count == Self.byteCount else { return nil }
        self.bytes = bytes
    }

    /// What the interface shows on a friend's own screen when the key itself matters. Short
    /// enough to read aloud, grouped so the eye can compare it (FR-10.6).
    public var fingerprint: String {
        let hex = bytes.prefix(8).map { String(format: "%02X", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let end = hex.index(start, offsetBy: min(4, hex.count - offset))
            return String(hex[start..<end])
        }.joined(separator: " ")
    }

    /// Ordering exists so that two devices can agree on which key comes first without talking
    /// about it. That is what makes the verification word identical on both phones (TC-8-06).
    public static func < (lhs: FriendKey, rhs: FriendKey) -> Bool {
        for (l, r) in zip(lhs.bytes, rhs.bytes) where l != r { return l < r }
        return false
    }
}
