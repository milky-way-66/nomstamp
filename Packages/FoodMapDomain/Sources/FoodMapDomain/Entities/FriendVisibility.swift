import Foundation

/// Which friends are being drawn, and which are switched off.
///
/// A value type in the domain rather than a `Set` held in a view, because *show only Lan* is a
/// rule and not a gesture: isolating means every other friend goes dark, restoring means everyone
/// comes back, and both have to be true however the interface chooses to spell them (FR-12.11).
///
/// Restoring shows **everyone**, deliberately — including friends who were hidden before the
/// isolation began. The alternative is remembering a previous state and putting it back, which
/// means a reader who isolates Lan, looks around, and taps again can land somewhere they did not
/// choose and cannot see. One rule the reader can predict beats a clever one they cannot.
public struct FriendVisibility: Equatable, Sendable {
    public private(set) var hidden: Set<FriendKey>

    public init(hidden: Set<FriendKey> = []) {
        self.hidden = hidden
    }

    public func isHidden(_ key: FriendKey) -> Bool { hidden.contains(key) }

    public mutating func toggle(_ key: FriendKey) {
        if hidden.contains(key) { hidden.remove(key) } else { hidden.insert(key) }
    }

    /// Everyone but this one goes dark.
    public mutating func isolate(_ key: FriendKey, within circle: FriendCircle) {
        hidden = Set(circle.friends.map(\.key)).subtracting([key])
    }

    public mutating func showEveryone() {
        hidden.removeAll()
    }

    /// True when this friend is the only one being drawn — which is what lets one control both
    /// isolate and restore without the reader having to remember which state they are in.
    public func isIsolated(_ key: FriendKey, within circle: FriendCircle) -> Bool {
        guard circle.friends.contains(where: { $0.key == key }), !hidden.contains(key) else {
            return false
        }
        return circle.friends.allSatisfy { $0.key == key || hidden.contains($0.key) }
    }

    /// Forgets anyone no longer in the circle, so a removed friend cannot leave a key behind that
    /// silently hides a later friend who lands on the same slot.
    public mutating func forget(_ key: FriendKey) {
        hidden.remove(key)
    }
}
