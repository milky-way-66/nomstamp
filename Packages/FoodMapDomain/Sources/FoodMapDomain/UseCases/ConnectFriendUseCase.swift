import Foundation

/// UC-8 — connecting, and the two rules that make it mean something.
///
/// The cap is one: eight, and a full circle is an explanation rather than an error. Proximity is
/// the other, and it is expressed here as a **required argument**. There is no overload that
/// omits the proof, so there is no code path that connects two readers who are not in the room —
/// distance is refused by the shape of the API rather than by a check somebody could forget
/// (FR-10.10, TC-8-08).
public struct ConnectFriendUseCase: Sendable {
    private let clock: any ClockPort

    public init(clock: any ClockPort) {
        self.clock = clock
    }

    /// `assignedName` is the reader's own writing. The name the other person asserted is a
    /// suggestion to start from and is never stored (FR-10.6, TC-8-05).
    public func execute(
        circle: FriendCircle,
        key: FriendKey,
        assignedName: String,
        proof: ProximityProof
    ) throws -> FriendCircle {
        guard proof.isCloseEnough else { throw CircleRefusal.notInPerson }
        guard circle.friend(for: key) == nil else { throw CircleRefusal.alreadyConnected }
        guard !circle.isFull else { throw CircleRefusal.full }

        var updated = circle
        updated.insert(
            Friend(
                key: key,
                assignedName: assignedName,
                inkSlot: circle.inkSlot(for: key),
                connectedAt: clock.now,
                // The first exchange happens in the room, over the radio, before the screen
                // closes — so a friend is reached from the moment they are connected (FR-10.9).
                lastReachedAt: clock.now
            )
        )
        return updated
    }

    /// Removing frees the ink slot as well as revoking the connection. Their stamps are dropped
    /// by the caller; friend data is a disposable cache and never the only copy of anything.
    public func remove(_ key: FriendKey, from circle: FriendCircle) -> FriendCircle {
        var updated = circle
        updated.remove(key)
        return updated
    }
}
