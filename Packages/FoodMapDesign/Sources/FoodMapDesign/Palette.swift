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
    public static let paper = PaletteColor(light: 0xF5EFE3, dark: 0x1A1714)
    public static let paperRaised = PaletteColor(light: 0xFDFAF3, dark: 0x241F1B)
    public static let ink = PaletteColor(light: 0x2A2521, dark: 0xF0E9DC)
    public static let inkSecondary = PaletteColor(light: 0x6B6259, dark: 0xA79C8D)
    public static let rule = PaletteColor(light: 0xDCD2C0, dark: 0x3A332C)

    /// Vietnamese lacquerware rather than an arbitrary red — places you have been.
    public static let lacquer = PaletteColor(light: 0xA8402F, dark: 0xD97A66)
    /// Jade — places you still want to try.
    public static let jade = PaletteColor(light: 0x2F6152, dark: 0x6FAF97)

    /// What text on a lacquer or jade fill must be. In dark mode those fills are light, so
    /// white text on them fails AA (3.03:1 and 2.54:1) — the ink of the surface reads instead.
    public static let onLacquer = PaletteColor(light: 0xFFFFFF, dark: 0x1A1714)
    public static let onJade = PaletteColor(light: 0xFFFFFF, dark: 0x1A1714)

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
        Pairing(name: "ink on paper", foreground: ink, background: paper, minimum: Contrast.normalTextMinimum),
        Pairing(name: "ink on raised paper", foreground: ink, background: paperRaised, minimum: Contrast.normalTextMinimum),
        Pairing(name: "secondary ink on paper", foreground: inkSecondary, background: paper, minimum: Contrast.normalTextMinimum),
        Pairing(name: "secondary ink on raised paper", foreground: inkSecondary, background: paperRaised, minimum: Contrast.normalTextMinimum),
        Pairing(name: "lacquer on paper", foreground: lacquer, background: paper, minimum: Contrast.normalTextMinimum),
        Pairing(name: "lacquer on raised paper", foreground: lacquer, background: paperRaised, minimum: Contrast.normalTextMinimum),
        Pairing(name: "jade on paper", foreground: jade, background: paper, minimum: Contrast.normalTextMinimum),
        Pairing(name: "jade on raised paper", foreground: jade, background: paperRaised, minimum: Contrast.normalTextMinimum),
        // Filled controls: "I ate here", "Add meal", "Save a place".
        Pairing(name: "text on a lacquer fill", foreground: onLacquer, background: lacquer, minimum: Contrast.normalTextMinimum),
        Pairing(name: "text on a jade fill", foreground: onJade, background: jade, minimum: Contrast.normalTextMinimum),
        // Pins are graphics, so the large-text level applies (NFR-6.3 covers shape, this covers colour).
        Pairing(name: "lacquer pin against the map", foreground: lacquer, background: paper, minimum: Contrast.largeTextMinimum),
        Pairing(name: "jade pin against the map", foreground: jade, background: paper, minimum: Contrast.largeTextMinimum),
    ]

    public static func value(_ color: PaletteColor, in appearance: Appearance) -> UInt32 {
        switch appearance {
        case .light: return color.light
        case .dark: return color.dark
        }
    }
}
