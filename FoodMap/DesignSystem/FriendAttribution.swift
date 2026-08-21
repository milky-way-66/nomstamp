import SwiftUI
import FoodMapDomain
import FoodMapDesign

/// Whose stamp this is, said out loud.
///
/// The map draws attribution in hue, which is a decision (FR-12.5a) and not an oversight — but it
/// is a decision that hands nothing at all to a reader using VoiceOver, or one who cannot separate
/// rust from gold. Everything here exists so that the sentence a pin speaks carries the same
/// information the colour carries, including the name of the ink itself: *rust* is not decoration
/// in that sentence, it is the thing the legend is keyed on (FR-12.10, NFR-6.2).
enum FriendAttribution {

    /// The inks, in the reader's own language.
    ///
    /// `FriendInk.names` holds them as identifiers, which is right for a package that must not
    /// depend on a string catalogue and wrong for anything a person hears. The switch keeps every
    /// key a literal so the catalogue can still find them.
    static func inkName(forSlot slot: Int) -> String {
        switch FriendInk.name(forSlot: slot) {
        case "rust": return String(localized: "rust")
        case "gold": return String(localized: "gold")
        case "leaf": return String(localized: "leaf")
        case "jade": return String(localized: "jade")
        case "teal": return String(localized: "teal")
        case "harbour": return String(localized: "harbour")
        case "violet": return String(localized: "violet")
        case "rose": return String(localized: "rose")
        default: return ""
        }
    }

    /// *stamped by Lan, rust ink* — for a place only friends have been to.
    static func stampedBy(_ name: String, inkSlot: Int, others: Int) -> String {
        let ink = inkName(forSlot: inkSlot)
        switch others {
        case 0:
            return String(localized: "stamped by \(name), \(ink) ink")
        case 1:
            return String(localized: "stamped by \(name) and one other, \(ink) ink")
        default:
            // Spelled out rather than left as a numeral: the badge on screen is "+3", which is a
            // drawing, and a drawing read aloud as "plus three" tells nobody anything.
            return String(localized: "stamped by \(name) and \(others) others, \(ink) ink")
        }
    }

    /// *also stamped by Lan, rust ink* — appended to the reader's own pin, where the countersign
    /// is the whole point of the feature and the pin previously never mentioned it at all.
    static func alsoStampedBy(_ name: String, inkSlot: Int, others: Int) -> String {
        let ink = inkName(forSlot: inkSlot)
        switch others {
        case 0:
            return String(localized: "also stamped by \(name), \(ink) ink")
        case 1:
            return String(localized: "also stamped by \(name) and one other, \(ink) ink")
        default:
            return String(localized: "also stamped by \(name) and \(others) others, \(ink) ink")
        }
    }

    /// The sentence for a map group, or nil where no friend is involved. Shared by the friend-only
    /// pin and the countersigned one so the two can never drift apart.
    @MainActor
    static func sentence(for group: MapStampGroup, store: FriendsStore, isOwnPin: Bool) -> String? {
        guard let countersign = group.countersign,
              let friend = store.friend(for: countersign.friend) else { return nil }
        return isOwnPin
            ? alsoStampedBy(friend.assignedName, inkSlot: friend.inkSlot, others: group.additionalSignatureCount)
            : stampedBy(friend.assignedName, inkSlot: friend.inkSlot, others: group.additionalSignatureCount)
    }
}
