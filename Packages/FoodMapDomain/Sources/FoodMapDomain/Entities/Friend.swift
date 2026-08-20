import Foundation

/// Someone whose stamps appear on this reader's map.
///
/// `assignedName` is written by **this** reader, never by the friend. ADR-009 makes naming the
/// moment a connection completes, which closes the impersonation surface entirely: no string
/// anyone else chose is ever rendered on this device, so there is nothing to spoof and nothing
/// for a fingerprint to defend in everyday use (FR-10.6).
public struct Friend: Identifiable, Equatable, Sendable {
    public let key: FriendKey
    public var assignedName: String
    /// Which of the eight inks this friend is printed in, on this device.
    public var inkSlot: Int
    public let connectedAt: Date
    /// The last time an exchange with this friend completed. Everything of theirs on the map is
    /// *as of* this moment, and the interface may never say otherwise (FR-12.6, FR-12.7).
    public var lastReachedAt: Date?

    public var id: FriendKey { key }

    public init(
        key: FriendKey,
        assignedName: String,
        inkSlot: Int,
        connectedAt: Date,
        lastReachedAt: Date? = nil
    ) {
        self.key = key
        self.assignedName = assignedName
        self.inkSlot = inkSlot
        self.connectedAt = connectedAt
        self.lastReachedAt = lastReachedAt
    }
}
