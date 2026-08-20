import Foundation

/// Which frame a place's stamp was cut with (ADR-005).
///
/// A page of identical frames reads as a table with pictures in it. An album reads as an album
/// because the stamps on it came from everywhere, so a place is dealt one of these from its own id
/// and keeps it for good — the same reason `StampTilt` is a hash rather than a random number.
///
/// The five are five different imaginary post offices, not five roundings of one rectangle: the
/// difference has to survive being shrunk to pin size and filled with a photograph, which means it
/// has to be in the silhouette. Nothing may ever be *read* off a cut: it is not the kind, not the
/// score, and carries no meaning at all.
public enum StampCut: String, CaseIterable, Sendable {
    /// The old-fashioned issue: perforated teeth the whole way round.
    case classic
    /// The art issue: an arched top on square shoulders, like a canvas.
    case gallery
    /// The future issue: two opposite corners cut clean off, every line straight.
    case modern
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
    /// The travel issue: all four corners taken off, the shape of a stamped document.
    case passport
    /// The street-party issue: triangular bunting hanging off the bottom edge.
    case bunting
    /// The airmail issue: the whole stamp leaning, as though it were already moving.
    case airmail

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
