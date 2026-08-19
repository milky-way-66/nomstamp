/// One colour, in both appearances. The app's `Theme` reads these; nothing else defines a hex.
public struct PaletteColor: Sendable, Equatable {
    public let light: UInt32
    public let dark: UInt32

    public init(light: UInt32, dark: UInt32) {
        self.light = light
        self.dark = dark
    }
}

/// The palette from ADR-003 — Vietnamese lacquer and jade on warm paper.
public enum Palette {
    public static let paper = PaletteColor(light: 0xF7F2E6, dark: 0x141110)
    public static let paperRaised = PaletteColor(light: 0xFFFDF7, dark: 0x201B17)
    public static let ink = PaletteColor(light: 0x1F1A16, dark: 0xF7F1E6)
    public static let inkSecondary = PaletteColor(light: 0x4A423A, dark: 0xC3B8A6)
    /// Separators are interface components, so they aim at 3:1 rather than a text level.
    public static let rule = PaletteColor(light: 0x8F836E, dark: 0x776B5F)

    /// Vietnamese lacquerware rather than an arbitrary red — places you have been.
    public static let lacquer = PaletteColor(light: 0x8C2A1B, dark: 0xF0937C)
    /// Jade — places you still want to try.
    public static let jade = PaletteColor(light: 0x1F5244, dark: 0x8FCDB4)

    /// What text on a lacquer or jade fill must be. In dark mode those fills are light, so
    /// white text on them would fail AA — the ink of the surface reads instead.
    public static let onLacquer = PaletteColor(light: 0xFFFFFF, dark: 0x141110)
    public static let onJade = PaletteColor(light: 0xFFFFFF, dark: 0x141110)

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
        Pairing(name: "lacquer on paper", foreground: lacquer, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "lacquer on raised paper", foreground: lacquer, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "jade on paper", foreground: jade, background: paper, minimum: Contrast.enhancedTextMinimum),
        Pairing(name: "jade on raised paper", foreground: jade, background: paperRaised, minimum: Contrast.enhancedTextMinimum),
        // Filled controls: "I ate here", "Add meal", "Save a place".
        Pairing(name: "text on a lacquer fill", foreground: onLacquer, background: lacquer, minimum: Contrast.normalTextMinimum),
        Pairing(name: "text on a jade fill", foreground: onJade, background: jade, minimum: Contrast.normalTextMinimum),
        // Pins are graphics, so the large-text level applies (NFR-6.3 covers shape, this covers colour).
        Pairing(name: "lacquer pin against the map", foreground: lacquer, background: paper, minimum: Contrast.largeTextMinimum),
        Pairing(name: "jade pin against the map", foreground: jade, background: paper, minimum: Contrast.largeTextMinimum),
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
