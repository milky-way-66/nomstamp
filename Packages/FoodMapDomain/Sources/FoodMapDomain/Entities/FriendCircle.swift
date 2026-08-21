import Foundation

public enum CircleRefusal: Error, Equatable {
    /// Not an error state. The interface explains and offers a removal; there is nothing to buy
    /// and no tier to upgrade to (FR-10.8, TC-8-01).
    case full
    case alreadyConnected
    /// No proof of co-presence, or not close enough. There is no code path that connects without
    /// one, which is what makes distance impossible rather than merely discouraged (TC-8-08).
    case notInPerson
}

/// Evidence that the other phone is in the room, gathered by the radio and handed to the domain
/// as a finding rather than as a device.
public struct ProximityProof: Equatable, Sendable {
    /// Bluetooth signal strength in dBm. Closer is less negative.
    public let signalStrength: Int
    /// Metres, where both devices have UWB. A flourish: iPhone SE has no U1, and requiring one
    /// would exclude those readers silently (ADR-009).
    public let rangedMetres: Double?

    public init(signalStrength: Int, rangedMetres: Double? = nil) {
        self.signalStrength = signalStrength
        self.rangedMetres = rangedMetres
    }

    /// Provisional, and openly so: OPEN-13 is an afternoon's measurement at a real table. It is a
    /// named constant rather than a literal precisely so the spike has one place to land.
    ///
    /// It started at -55, which was wrong in the direction that matters: two iPhones a table's
    /// width apart read in the -60s as soon as a hand, a menu or a body is between them, so the
    /// gate refused the exact gesture it was built for and said *they moved out of range* to two
    /// people sitting together. -70 still sits far above a phone at the other end of a restaurant,
    /// which reads -85 and worse.
    public static let signalFloor = -70
    public static let rangeCeilingMetres = 1.0

    public var isCloseEnough: Bool {
        if let rangedMetres { return rangedMetres <= Self.rangeCeilingMetres }
        return signalStrength >= Self.signalFloor
    }
}

/// The reader's circle, and the cap that keeps it a circle.
///
/// Eight is a product decision before a technical one: a cap forces curation, and a small
/// deliberate circle is a different social object from a following. It also falls out of the art
/// direction — eight is about where a curated set of inks holds before it looks like a box of
/// crayons (ADR-008, carried by ADR-009).
public struct FriendCircle: Equatable, Sendable {
    public static let capacity = 8

    public private(set) var friends: [Friend]

    public init(_ friends: [Friend] = []) {
        self.friends = friends
    }

    public var isFull: Bool { friends.count >= Self.capacity }
    public var count: Int { friends.count }

    public func friend(for key: FriendKey) -> Friend? {
        friends.first { $0.key == key }
    }

    public var occupiedInkSlots: Set<Int> { Set(friends.map(\.inkSlot)) }

    /// Which ink a key wants, before anyone else is considered. Deterministic, so Lan prefers the
    /// same ink on every device that knows her.
    public static func preferredInkSlot(for key: FriendKey) -> Int {
        Int(key.bytes[0]) % capacity
    }

    /// The ink a key actually gets here. Where the preferred one is taken, the next free one is
    /// used: **local uniqueness beats cross-device stability**, because a map where two friends
    /// share a colour fails at the only job the ink has. With the circle capped at eight and the
    /// plate holding eight, a free ink always exists (TC-8-04).
    public func inkSlot(for key: FriendKey) -> Int {
        let taken = occupiedInkSlots
        let preferred = Self.preferredInkSlot(for: key)
        for step in 0..<Self.capacity {
            let slot = (preferred + step) % Self.capacity
            if !taken.contains(slot) { return slot }
        }
        return preferred
    }

    public mutating func insert(_ friend: Friend) {
        friends.append(friend)
    }

    /// Removing frees the slot as well as deleting the connection. The friend's stamps are the
    /// caller's to drop — they live in the cache, not here (FR-10.7, TC-8-10).
    public mutating func remove(_ key: FriendKey) {
        friends.removeAll { $0.key == key }
    }

    public mutating func markReached(_ key: FriendKey, at date: Date) {
        guard let index = friends.firstIndex(where: { $0.key == key }) else { return }
        friends[index].lastReachedAt = date
    }
}
