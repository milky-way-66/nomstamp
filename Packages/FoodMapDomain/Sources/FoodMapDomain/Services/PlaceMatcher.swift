import Foundation

/// Decides whether two places are really the same restaurant (UC-4 / 3a).
public enum PlaceMatcher {
    /// Vietnamese street stalls sit very close together, so the radius stays tight: two
    /// different places 60 m apart is common, the same place recorded twice 60 m apart is not.
    public static let duplicateRadius: Double = 50

    public static func isSamePlace(_ place: Place, as draft: PlaceDraft) -> Bool {
        // The provider's own identifier is the strongest signal available.
        if let draftID = draft.providerPlaceID,
           let existingID = place.providerPlaceID,
           draftID == existingID {
            return true
        }

        // Otherwise: same name, close enough to be the same doorway.
        guard place.distance(to: draft.coordinate) <= duplicateRadius else { return false }
        return normalized(place.name) == normalized(draft.name)
    }

    /// Vietnamese users routinely type without diacritics, so `pho thin` must match `Phở Thìn`
    /// (TC-4-05). `đ` needs explicit handling: Unicode folding does not reduce it to `d`.
    public static func normalized(_ name: String) -> String {
        name
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
