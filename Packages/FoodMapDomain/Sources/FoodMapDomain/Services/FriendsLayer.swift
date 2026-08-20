import Foundation

/// How a friend's stamps are dated, and how a new one announces itself.
public enum FriendsLayer {
    /// **Staleness belongs to the friend, not to the stamp.** If Lan was last reached on 12
    /// August then every stamp of hers is as of 12 August, including ones untouched since June.
    /// A per-stamp date would imply a recency this design does not have, and cannot get without
    /// asking Lan's phone something it was never asked (FR-12.6, TC-10-08).
    public static func asOf(_ key: FriendKey, in circle: FriendCircle) -> Date? {
        circle.friend(for: key)?.lastReachedAt
    }

    /// A stamp arrives freshly pressed and fades to ordinary over three days.
    ///
    /// This is what replaces a notification. A local alert would sell an immediacy the feature
    /// does not want to promise and would turn a slow journal into a feed; silence would waste
    /// the only moment of pleasure the feature has. Decay also degrades correctly: a reader who
    /// stays away for a month comes back to a page of ordinary stamps rather than two hundred
    /// unread badges (ADR-009, TC-10-09).
    public static let freshDuration: TimeInterval = 3 * 86_400

    /// 1 for something that has just landed, 0 for anything the reader has already seen or that
    /// has finished fading.
    public static func freshness(receivedAt: Date, lastLookedAt: Date, now: Date) -> Double {
        guard receivedAt > lastLookedAt else { return 0 }
        let age = now.timeIntervalSince(receivedAt)
        guard age < freshDuration else { return 0 }
        return max(0, min(1, 1 - age / freshDuration))
    }
}
