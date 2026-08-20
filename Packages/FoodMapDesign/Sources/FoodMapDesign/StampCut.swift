import Foundation

/// Which frame a place's stamp was cut with (ADR-005).
///
/// A page of identical frames reads as a table with pictures in it. An album reads as an album
/// because the stamps on it came from everywhere, so a place is dealt one of these from its own id
/// and keeps it for good — the same reason `StampTilt` is a hash rather than a random number.
///
/// Each one is a *thing*, not a rounding of a rectangle: an old stamp, the moulding round an oil
/// painting, a lego brick, a tube television, a comic burst. The difference has to survive being
/// shrunk to pin size and filled with a photograph, which means it has to be in the silhouette —
/// abstract cuts (a chamfer, a lean, an octagon) were tried first and read as the same square with
/// its corners done differently. Nothing may ever be *read* off a cut: it is not the kind, not the
/// score, and carries no meaning at all.
public enum StampCut: String, CaseIterable, Sendable {
    /// An old postage stamp: perforated teeth the whole way round.
    case classic
    /// The art issue: an arched top on square shoulders, like a canvas.
    case gallery
    /// A lego brick, studs and all.
    case lego
    /// The rural issue: four torn deckle edges, none of them straight.
    case country
    /// The metropolitan issue: hard corners and a stepped skyline along the top.
    case city
    /// The transport issue: a bite out of both sides, where it was torn off the roll.
    case ticket
    /// The holiday issue: scalloped waves along the top and the bottom.
    case seaside
    /// The festival issue: a flag, with a V cut out of its bottom edge.
    case pennant
    /// The comic issue: a burst, spiked the whole way round like a panel that says BOOM.
    case comic
    /// The arcade issue: corners built out of square pixels, 8-bit.
    case arcade
    /// An old painting frame: scooped sides and blocked corners, the moulding round an oil.
    case painting
    /// The street-party issue: triangular bunting hanging off the bottom edge.
    case bunting
    /// An old television: a screen that bulges, the way a tube does.
    case television

    /// The cut a place is dealt. Deterministic, so a place is the same stamp in the list as on the
    /// map, and the same stamp tomorrow.
    public static func cut(for id: String) -> StampCut {
        // Salted so the cut and the tilt are not two readings of one hash — otherwise every
        // gallery stamp on the page would lean the same way.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "cut:\(id)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        let all = allCases
        return all[Int(hash % UInt64(all.count))]
    }
}
