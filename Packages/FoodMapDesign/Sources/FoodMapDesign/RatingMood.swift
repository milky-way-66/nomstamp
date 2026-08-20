/// What a score feels like (ADR-005).
///
/// A rating is the one moment in the app where the user makes a judgement, so the page answers it:
/// the ink shifts along a ramp from a flat slate at one star to the most saturated leaf green at
/// five. The mapping lives here, next to the palette, so the ink a score paints is decided once and
/// contrast-checked like every other pairing (TC-N-17) rather than picked per screen.
public enum RatingMood: Int, CaseIterable, Sendable {
    case poor = 1
    case fair = 2
    case good = 3
    case great = 4
    case best = 5

    /// Nil for an unrated meal and for anything outside the scale: the absence of a score is not a
    /// low score, and must never be painted as one.
    public static func mood(for score: Int?) -> RatingMood? {
        guard let score else { return nil }
        return RatingMood(rawValue: score)
    }

    public var ink: PaletteColor {
        switch self {
        case .poor: return PaletteColor(light: 0x414C56, dark: 0xB6C0C7)
        case .fair: return PaletteColor(light: 0x2C5670, dark: 0xA2C3D8)
        case .good: return PaletteColor(light: 0x0F5A66, dark: 0x86CBD4)
        case .great: return PaletteColor(light: 0x0B5E45, dark: 0x5FE4A6)
        case .best: return PaletteColor(light: 0x235509, dark: 0xA6D97A)
        }
    }

    /// How far the mood tints the page behind the stars. Deliberately barely there: the page should
    /// warm, not change colour, and a photograph sits on it.
    public static let groundTint: Double = 0.09
}
