/// The colour of the paper a stamp was printed on (ADR-005).
///
/// A stamp album is colourful because the stamps came from everywhere, not because anyone chose a
/// palette. Each place is dealt one of these with its cut, and keeps it: it tints the paper edge
/// around the photograph, so a page of pins is a page of different-coloured stamps rather than a
/// page of white ones.
///
/// Like the cut, it means nothing — it is not the kind and it is not the score. That is why it is
/// only ever the *paper*: the rule inside it stays the rating's ink, so the one colour in a stamp
/// that carries information is never the one dealt at random.
///
/// They are properly coloured rather than tinted. A first version was near-white and the map looked
/// exactly as it had before — at pin size a band four points wide has to be a colour, or it is a
/// shade of the paper it sits on. Nothing is printed *over* these but a photograph's own edge.
public enum StampPaper: String, CaseIterable, Sendable {
    case cream
    case blush
    case sky
    case mint
    case butter
    case lilac
    case coral

    public var ink: PaletteColor {
        switch self {
        case .cream: PaletteColor(light: 0xFFE1A8, dark: 0x8A6B33)
        case .blush: PaletteColor(light: 0xFFB2CB, dark: 0x8E3F5B)
        case .sky: PaletteColor(light: 0x9AD4FF, dark: 0x2E6288)
        case .mint: PaletteColor(light: 0x9CE8BE, dark: 0x2C6E4C)
        case .butter: PaletteColor(light: 0xFFDE72, dark: 0x8A6E1F)
        case .lilac: PaletteColor(light: 0xCFBBFF, dark: 0x54428E)
        case .coral: PaletteColor(light: 0xFFB49A, dark: 0x8C4630)
        }
    }

    /// The paper a place was printed on. Salted differently from the cut, so a shape and a colour
    /// are two draws rather than one — otherwise every arch in the app would be pink.
    public static func paper(for id: String) -> StampPaper {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "paper:\(id)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        let all = allCases
        return all[Int(hash % UInt64(all.count))]
    }
}
