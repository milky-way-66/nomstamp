import Foundation

/// A digest of some bytes, as a stable string.
///
/// A port rather than a call to CryptoKit, because CryptoKit is an Apple framework and CON-5
/// keeps the domain free of those. What matters here is not which hash — it is that the *rule*
/// about when a version changes is provable without one (FR-13.3a).
public protocol DigestPort: Sendable {
    func digest(_ data: Data) -> String
}

/// This device's own identity, and the sealing that keeps a stamp readable only by the friends
/// it was written for (FR-13.3c).
///
/// The domain never sees a private key, never seals anything itself, and never learns which
/// cipher was used. It knows only that sealing is something that happens before bytes leave.
public protocol PeerIdentityPort: Sendable {
    var publicKey: FriendKey { get }
    /// Seals a payload so that exactly these recipients can open it. A record written to a
    /// shared zone is ciphertext by the time CloudKit sees it.
    func seal(_ payload: Data, for recipients: [FriendKey]) throws -> Data
    func open(_ sealed: Data) throws -> Data
}

/// Where a friend's stamps come from and where a reader's go. Deliberately says nothing about
/// CloudKit: replacing the transport was a data-layer change once already (ADR-008 → ADR-009),
/// and this port is why the domain did not notice.
public protocol StampSyncPort: Sendable {
    func remoteManifest(for friend: FriendKey) async throws -> StampManifest
    func fetchStamps(_ placeIDs: [UUID], from friend: FriendKey) async throws -> [SharedStamp]
    func publish(_ outgoing: OutgoingShare) async throws
}

/// Thumbnails, addressed by the hash of their content, so an image already held is never fetched
/// twice — by anyone, ever (FR-13.3).
public protocol BlobStorePort: Sendable {
    func heldHashes() -> Set<String>
    func fetch(_ hash: String, from friend: FriendKey) async throws -> Data
}

/// Who is in the room. The connect ceremony's only input to the domain, expressed as findings
/// rather than as radios (FR-10.10, FR-10.11).
public protocol ProximityPort: Sendable {
    /// Readers currently advertising nearby, while the *Add friend* screen is open.
    func nearbyReaders() async throws -> [NearbyReader]
}

/// Someone advertising nearby, before any connection exists. Carries an **ephemeral** id rather
/// than a public key: broadcasting a stable identifier in the clear would let anyone track a
/// phone (FR-10.11).
public struct NearbyReader: Equatable, Sendable {
    public let ephemeralID: UUID
    public let assertedName: String
    public let proof: ProximityProof

    public init(ephemeralID: UUID, assertedName: String, proof: ProximityProof) {
        self.ephemeralID = ephemeralID
        self.assertedName = assertedName
        self.proof = proof
    }
}
