import Foundation
import CryptoKit
import FoodMapDomain

/// SHA-256, as a lower-case hex string.
///
/// The domain decides *when* a version changes; this decides only what the version looks like.
/// A cryptographic hash rather than a cheap one because two different stamps colliding would
/// mean a friend silently never receiving an update (FR-13.3a).
public struct StampDigest: DigestPort {
    public init() {}

    public func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
