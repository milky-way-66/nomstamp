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
    public static let paper = PaletteColor(light: 0xF1F5F1, dark: 0x0D1513)
    public static let paperRaised = PaletteColor(light: 0xFBFDFA, dark: 0x17201E)
    public static let ink = PaletteColor(light: 0x14201C, dark: 0xEDF4F0)
    public static let inkSecondary = PaletteColor(light: 0x39463F, dark: 0xB2C2BA)
    /// Separators are interface components, so they aim at 3:1 rather than a text level.
    public static let rule = PaletteColor(light: 0x6F817A, dark: 0x6C7C76)

    /// Pandan — the green of the leaf everything sweet is cooked in. Places you have been, and
    /// every action that adds to the map.
    public static let pandan = PaletteColor(light: 0x0B5E45, dark: 0x74D3AA)
    /// Bay water — places you still want to try: somewhere you have not been yet.
    public static let bay = PaletteColor(light: 0x15496F, dark: 0x8CC6EC)
    /// The printing ink (ADR-005): the second layer of a misregistration, and the colour of
    /// ornaments, stamp frames and rules. Dark mode deepens rather than brightens it, so it stays
    /// the ink and never competes with the two accents.
    public static let indigo = PaletteColor(light: 0x1E3A4A, dark: 0x9FBECC)

    /// The ink the map itself is printed in (ADR-005). Not a text colour: it is blended over the
    /// cartography, taking its hue and leaving its luminance, which is why it carries no pairing.
    public static let mapWash = PaletteColor(light: 0x4E7C72, dark: 0x14313A)

    /// What text on a pandan or bay fill must be. In dark mode those fills are light, so white
    /// text on them would fail AA — the ink of the surface reads instead.
    public static let onPandan = PaletteColor(light: 0xFFFFFF, dark: 0x0D1513)
    public static let onBay = PaletteColor(light: 0xFFFFFF, dark: 0x0D1513)

    /// Every pairing the interface actually renders, with the level it has to reach.
    /// `Appearance` exists so a failure message says which mode broke.
    public enum Appearance: String, CaseIterable, Sendable { case light, dark }

    public struct Pairing: Sendable {
        public let name: String
        public let foreground: PaletteColor
        public let background: PaletteColor
        public let minimum: Double
    }

    public static let renderedPairings: [Pairing] = [
        Pairing(name: "ink on paper", foreground: ink, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "ink on raised paper", foreground: ink, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "secondary ink on paper", foreground: inkSecondary, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "secondary ink on raised paper", foreground: inkSecondary, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "pandan on paper", foreground: pandan, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "pandan on raised paper", foreground: pandan, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "bay on paper", foreground: bay, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "bay on raised paper", foreground: bay, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        // Filled controls: "I ate here", "Add meal", "Save a place".
        Pairing(name: "text on a pandan fill", foreground: onPandan, background: pandan, minimum: Contrast.normalTextMinimum),
        Pairing(name: "text on a bay fill", foreground: onBay, background: bay, minimum: Contrast.normalTextMinimum),
        // Pins are graphics, so the large-text level applies (NFR-6.3 covers shape, this covers colour).
        Pairing(name: "pandan pin against the map", foreground: pandan, background: paper, minimum: Contrast.largeTextMinimum),
        Pairing(name: "bay pin against the map", foreground: bay, background: paper, minimum: Contrast.largeTextMinimum),
        // The printing ink, on both grounds (TC-N-12).
        Pairing(name: "indigo on paper", foreground: indigo, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "indigo on raised paper", foreground: indigo, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        // The rating ramp: each mood is a text colour on both grounds (TC-N-17).
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

    public static func value(_ color: PaletteColor, in appearance: Appearance) -> UInt32 {
        switch appearance {
        case .light: return color.light
        case .dark: return color.dark
        }
    }
}
