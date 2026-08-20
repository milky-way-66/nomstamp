/// One colour, in both appearances. The app's `Theme` reads these; nothing else defines a hex.
public struct PaletteColor: Sendable, Equatable {
    public let light: UInt32
    public let dark: UInt32

    public init(light: UInt32, dark: UInt32) {
        self.light = light
        self.dark = dark
    }
}

/// The palette (ADR-003, revised): pandan and bay water on cool paper.
///
/// It started warm — lacquer red and jade on cream — and read as dusty rather than appetising. The
/// inks are now the greens and blues of the food itself and of the water a market sits on: fresher,
/// and with more energy at the same contrast levels.
public enum Palette {
    public static let paper = PaletteColor(light: 0xF1F5F1, dark: 0x0A1210)
    public static let paperRaised = PaletteColor(light: 0xFBFDFA, dark: 0x14201C)
    public static let ink = PaletteColor(light: 0x14201C, dark: 0xEDF4F0)
    public static let inkSecondary = PaletteColor(light: 0x39463F, dark: 0xB2C2BA)
    /// Separators are interface components, so they aim at 3:1 rather than a text level.
    public static let rule = PaletteColor(light: 0x6F817A, dark: 0x6C7C76)

    // The three accents below are the *default* printing. Since ADR-006 the press can be re-inked
    // per day and per sky, so anything that draws should read them from the current `Skin`; these
    // remain for code that has no skin to hand, and they are the pandan skin by construction.

    /// Places you have been, and every action that adds to the map.
    public static let visitedInk = Skin.default.visitedInk
    /// Places you still want to try: somewhere you have not been yet.
    public static let wishlistInk = Skin.default.wishlistInk
    /// The printing ink (ADR-005): the second layer of a misregistration, and the colour of
    /// ornaments, stamp frames and rules. Always quieter than the two accents.
    public static let printingInk = Skin.default.printingInk

    /// The ink the map itself is printed in (ADR-005). Not a text colour: it lends the cartography
    /// its hue and saturation and leaves the map's own luminance alone, which is why it carries no
    /// pairing — and why it can never darken the map it is printed into.
    public static let mapWash = Skin.default.mapWash

    /// What text on an accent fill must be. In dark mode those fills are light, so white text on
    /// them would fail AA — the ink of the surface reads instead.
    public static let onAccent = Skin.default.onAccent

    /// Every pairing the interface actually renders, with the level it has to reach.
    /// `Appearance` exists so a failure message says which mode broke.
    public enum Appearance: String, CaseIterable, Sendable { case light, dark }

    public struct Pairing: Sendable {
        public let name: String
        public let foreground: PaletteColor
        public let background: PaletteColor
        public let minimum: Double
    }

    /// Every pairing the interface renders in a given printing.
    ///
    /// Taking the skin as an argument is the point: TC-N-18 walks all five, so adding a skin with
    /// a pretty but illegible ink fails the suite rather than shipping.
    public static func renderedPairings(for skin: Skin = .default) -> [Pairing] {
        let visited = skin.visitedInk
        let wishlist = skin.wishlistInk
        let printing = skin.printingInk
        let onAccent = skin.onAccent

        return [
            Pairing(name: "ink on paper", foreground: ink, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "ink on raised paper", foreground: ink, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "secondary ink on paper", foreground: inkSecondary, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "secondary ink on raised paper", foreground: inkSecondary, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "visited ink on paper", foreground: visited, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "visited ink on raised paper", foreground: visited, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "wishlist ink on paper", foreground: wishlist, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "wishlist ink on raised paper", foreground: wishlist, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            // Filled controls: "I ate here", "Add meal", "Save a place".
            Pairing(name: "text on a visited fill", foreground: onAccent, background: visited, minimum: Contrast.normalTextMinimum),
            Pairing(name: "text on a wishlist fill", foreground: onAccent, background: wishlist, minimum: Contrast.normalTextMinimum),
            // Pins are graphics, so the large-text level applies (NFR-6.3 covers shape, this covers colour).
            Pairing(name: "visited pin against the map", foreground: visited, background: paper, minimum: Contrast.largeTextMinimum),
            Pairing(name: "wishlist pin against the map", foreground: wishlist, background: paper, minimum: Contrast.largeTextMinimum),
            // The printing ink, on both grounds (TC-N-12).
            Pairing(name: "printing ink on paper", foreground: printing, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "printing ink on raised paper", foreground: printing, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            // The rating ramp: constant across skins, because a score must mean the same thing on
            // every printing (TC-N-17).
            Pairing(name: "one star on paper", foreground: RatingMood.poor.ink, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "two stars on paper", foreground: RatingMood.fair.ink, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "three stars on paper", foreground: RatingMood.good.ink, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "four stars on paper", foreground: RatingMood.great.ink, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "five stars on paper", foreground: RatingMood.best.ink, background: paper, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "five stars on raised paper", foreground: RatingMood.best.ink, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            Pairing(name: "one star on raised paper", foreground: RatingMood.poor.ink, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
            // Separators and hairlines: interface components, not text.
            Pairing(name: "rule against paper", foreground: rule, background: paper, minimum: Contrast.componentMinimum),
        ]
    }

    /// The default printing's pairings, for callers that predate skins.
    public static var renderedPairings: [Pairing] { renderedPairings(for: .default) }

    public static func value(_ color: PaletteColor, in appearance: Appearance) -> UInt32 {
        switch appearance {
        case .light: return color.light
        case .dark: return color.dark
        }
    }
}
