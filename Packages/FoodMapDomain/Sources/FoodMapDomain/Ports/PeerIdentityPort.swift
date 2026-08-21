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
    /// Starts advertising and scanning. Nothing is discoverable, and nothing is discovered, until
    /// this is called — which is how FR-10.11's "only while the screen is open" is enforced by
    /// construction rather than by a promise. A screen that reads `nearbyReaders()` without ever
    /// beginning is reading an empty room (FR-10.12, TC-8-14).
    func begin()

    /// Stops both and forgets what was seen. Called when the screen leaves (FR-10.12, TC-8-15).
    func end()

    /// Readers currently advertising nearby, while the *Add friend* screen is open.
    func nearbyReaders() async throws -> [NearbyReader]

    /// Whether there is any point waiting. A radio that is off or unauthorised looks exactly like
    /// an empty room from `nearbyReaders()`, and a reader left staring at a spinner has no way to
    /// tell the difference (FR-10.13, TC-8-16).
    func availability() async -> ProximityAvailability
}

/// Why the room looks empty.
public enum ProximityAvailability: Equatable, Sendable {
    /// The radio is on and listening. An empty list here really does mean nobody is there.
    case searching
    /// Bluetooth is switched off on this device.
    case poweredOff
    /// The reader has refused Bluetooth to this app, or has never been asked.
    case unauthorized
    /// No radio at all — the simulator, chiefly.
    case unsupported
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

/// The exchange that happens over the local link once both readers have tapped each other's row.
///
/// Separate from `ProximityPort` because they are different claims. Proximity says *someone is in
/// the room*; the handshake says *this key belongs to the person sitting there*, and only the
/// second one may create a friend. The transport carries no infrastructure networking — same
/// subnet is not the same room — which is what makes a distant connection impossible rather than
/// merely refused (ADR-009, FR-10.10).
public protocol PeerHandshakePort: Sendable {
    /// Exchanges public keys with the chosen nearby reader and returns theirs, alongside the
    /// proof gathered while the link was open. The name they assert travels too, as a suggestion
    /// for the reader to overwrite — it is never stored as given (FR-10.6).
    func exchange(with reader: NearbyReader) async throws -> HandshakeResult
}

public struct HandshakeResult: Equatable, Sendable {
    public let key: FriendKey
    public let assertedName: String
    /// Re-measured at the moment of the exchange, not carried over from the scan. A row can sit
    /// on screen while its owner walks away.
    public let proof: ProximityProof

    public init(key: FriendKey, assertedName: String, proof: ProximityProof) {
        self.key = key
        self.assertedName = assertedName
        self.proof = proof
    }
}
