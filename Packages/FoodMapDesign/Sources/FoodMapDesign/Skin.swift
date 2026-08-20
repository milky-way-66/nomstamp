/// The inks the app is printed in today (ADR-006).
///
/// A skin re-inks the *press*, not the paper: the page, the body ink and the rating ramp are
/// constant, so what a reader reads never moves, and only the accents, the printing ink and the
/// map wash change. That is why a skin cannot break body-text contrast, and why the five of them
/// read as five printings of one journal rather than five apps.
///
/// The names are berries and leaves rather than "green" and "blue" because the roles they fill —
/// visited, wishlist, printing — are what the interface asks for; the hue is this type's business.
public enum Skin: String, CaseIterable, Sendable {
    /// Pandan leaf on cool paper: the house colours, and what an unknown sky falls back to.
    case pandan
    /// Bay water — the rain skin, deeper and colder.
    case bay
    /// Tamarind and turmeric: the sun skin, worn on a clear day.
    case tamarind
    /// Sim berry, the fruit that grows on the hills: dusk, fog and clear nights.
    case sim
    /// Lotus: the warm pink one, kept for the daily rotation so it is a surprise rather than a
    /// weather report.
    case lotus

    /// Places you have been, and every action that adds to the map.
    public var visitedInk: PaletteColor {
        switch self {
        case .pandan: PaletteColor(light: 0x0B5E45, dark: 0x5FE4A6)
        case .bay: PaletteColor(light: 0x134A72, dark: 0x82D0FF)
        case .tamarind: PaletteColor(light: 0x813807, dark: 0xF2A25C)
        case .sim: PaletteColor(light: 0x5B2A78, dark: 0xC9A0F0)
        case .lotus: PaletteColor(light: 0x9B1B4A, dark: 0xFF9DBE)
        }
    }

    /// Places you still want to try. Always a different family from `visitedInk`, so the two kinds
    /// of pin stay legible as colours as well as shapes.
    public var wishlistInk: PaletteColor {
        switch self {
        case .pandan: PaletteColor(light: 0x15496F, dark: 0x79CEFF)
        case .bay: PaletteColor(light: 0x0F5B3E, dark: 0x74E0A6)
        case .tamarind: PaletteColor(light: 0x1F5560, dark: 0x86CEDC)
        case .sim: PaletteColor(light: 0x2F3E86, dark: 0xA8B6F5)
        case .lotus: PaletteColor(light: 0x1F5A63, dark: 0x86D8DE)
        }
    }

    /// The second layer of a misregistration, and the colour of ornaments, stamp frames and rules.
    /// Always the quietest of the three, so it never competes with the accents it sits under.
    public var printingInk: PaletteColor {
        switch self {
        case .pandan: PaletteColor(light: 0x1E3A4A, dark: 0x86C6DE)
        case .bay: PaletteColor(light: 0x1B3550, dark: 0x8FC4E8)
        case .tamarind: PaletteColor(light: 0x5A3418, dark: 0xD7A98A)
        case .sim: PaletteColor(light: 0x3B2A55, dark: 0xB9A5D8)
        case .lotus: PaletteColor(light: 0x63304A, dark: 0xE0A8C0)
        }
    }

    /// What the cartography is printed in. Not a text colour, and it carries no pairing: it is
    /// blended into the map rather than drawn on top of it.
    ///
    /// Only the hue and the saturation of these are ever used — the map keeps its own light — so
    /// the light values are chosen for how clearly they read as an ink, not for how bright they
    /// are. They are more saturated than the old ones on purpose: a desaturated wash does not
    /// re-ink a map, it greys it, and a greyed map reads as a sheet laid over the city rather than
    /// as a city printed in colour.
    public var mapWash: PaletteColor {
        switch self {
        case .pandan: PaletteColor(light: 0x2E8B67, dark: 0x0E2C36)
        case .bay: PaletteColor(light: 0x2C6D96, dark: 0x0B2436)
        case .tamarind: PaletteColor(light: 0xC07A22, dark: 0x2A1B0C)
        case .sim: PaletteColor(light: 0x6A4E9E, dark: 0x1B1330)
        case .lotus: PaletteColor(light: 0xC33F6C, dark: 0x2C1220)
        }
    }

    /// Text on a `visitedInk` or `wishlistInk` fill. In dark mode those fills are the light ones,
    /// so the page's own ground reads back instead of white.
    public var onAccent: PaletteColor { PaletteColor(light: 0xFFFFFF, dark: 0x0A1210) }

    /// The skin the app is printed in when nothing has said otherwise.
    public static let `default`: Skin = .pandan
}
