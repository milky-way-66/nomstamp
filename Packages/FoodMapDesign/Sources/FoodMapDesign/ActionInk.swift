/// The colours the map's three actions are painted in (ADR-005).
///
/// The rest of the app is printed in a journal's inks — deep, slightly dusty, chosen so type sits on
/// them. These three are not type, they are the toys on the map, so they get their own small
/// palette: lighter and friendlier than anything else on the screen, and deliberately not the house
/// accents, because the house accents also *mean* things (visited, wishlist) and a button is not a
/// place.
///
/// Soft, though, not loud. A first version used full-strength yellow, hot pink and a signal green;
/// three saturated discs sitting on Apple's pale cartography were the loudest thing on the map by a
/// distance, and the map is what the screen is for. These are the same three hues with the volume
/// down — still unmistakably paint, no longer shouting over the city.
///
/// Every one of them carries the same near-black glyph in both appearances rather than white. That
/// is what lets the yellow be genuinely yellow: white on it fails contrast at any weight, and dimming
/// the yellow until white worked would have produced mustard. Asserted by TC-N-24.
public enum ActionInk: String, CaseIterable, Sendable {
    /// Soft yellow, for finding yourself.
    case sun
    /// Soft rose, for keeping a place for later.
    case berry
    /// Soft leaf, for the camera — the one action the app is really for.
    case leaf

    public var fill: PaletteColor {
        switch self {
        case .sun: PaletteColor(light: 0xF7D172, dark: 0xEFC868)
        case .berry: PaletteColor(light: 0xF294B4, dark: 0xE98FAF)
        case .leaf: PaletteColor(light: 0x8ED4A8, dark: 0x82CC9E)
        }
    }

    /// What is drawn on top of the fill: the same near-black in light and dark, because a bright
    /// paint stays bright in both and a glyph that flipped to white would vanish on the yellow.
    public var glyph: PaletteColor { PaletteColor(light: 0x0F1A16, dark: 0x0F1A16) }
}
