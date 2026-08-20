/// The colours the map's three actions are painted in (ADR-005).
///
/// The rest of the app is printed in a journal's inks — deep, slightly dusty, chosen so type sits on
/// them. These three are not type, they are the toys on the map, and a cartoon paints its buttons in
/// primaries. So they get their own small palette: brighter than anything else on the screen, and
/// deliberately not the house accents, because the house accents also *mean* things (visited,
/// wishlist) and a button is not a place.
///
/// Every one of them carries the same near-black glyph in both appearances rather than white. That
/// is what lets the yellow be genuinely yellow: white on it fails contrast at any weight, and dimming
/// the yellow until white worked would have produced mustard. Asserted by TC-N-24.
public enum ActionInk: String, CaseIterable, Sendable {
    /// Yellow, for finding yourself.
    case sun
    /// Hot pink, for keeping a place for later.
    case berry
    /// Bright leaf, for the camera — the one action the app is really for.
    case leaf

    public var fill: PaletteColor {
        switch self {
        case .sun: PaletteColor(light: 0xFFC53D, dark: 0xFFCE55)
        case .berry: PaletteColor(light: 0xFF4F92, dark: 0xFF6EA6)
        case .leaf: PaletteColor(light: 0x2BC46F, dark: 0x46D687)
        }
    }

    /// What is drawn on top of the fill: the same near-black in light and dark, because a bright
    /// paint stays bright in both and a glyph that flipped to white would vanish on the yellow.
    public var glyph: PaletteColor { PaletteColor(light: 0x0F1A16, dark: 0x0F1A16) }
}
