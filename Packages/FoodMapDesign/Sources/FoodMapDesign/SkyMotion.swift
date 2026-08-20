import Foundation

/// How fast the sky moves inside its window (ADR-006).
///
/// The weather is the only thing in the app that moves on its own, and it keeps that privilege by
/// being slow: these are cycles you notice on the second look, not the first. A drift, not an
/// animation — anything eye-catching would be competing with the pins for attention it has not
/// earned.
///
/// The numbers live here rather than in the view so the cadence is one decision, asserted by
/// TC-N-23, rather than a literal typed into four drawing routines.
public enum SkyMotion {
    /// The slowest a cycle may be and still read as movement rather than as a stuck frame.
    public static let slowest: Double = 14
    /// The fastest anything in the window may move. Rain is the busiest sky there is, and even
    /// rain is kept to this: past it the corner of the map starts to twitch.
    public static let fastest: Double = 2.5

    /// How long one cycle of an effect takes, in seconds. Zero where nothing is drawn at all.
    public static func period(for effect: SkyEffectKind) -> Double {
        switch effect {
        case .none: return 0
        // Falling water is the one thing that would look wrong slowed down.
        case .rain: return 2.6
        // Fog does not fall, it leans: the slowest thing in the window.
        case .haze: return 12
        // A sun does not travel across a card. It breathes.
        case .bloom: return 9
        // Lamps on a wire, each coming up a little after the one before it.
        case .lanterns: return 6
        }
    }

    /// How far a drawing wanders from where it was printed, as a fraction of the window. Small
    /// enough that the composition never actually changes — only the light in it does.
    public static func amplitude(for effect: SkyEffectKind) -> Double {
        switch effect {
        case .none: return 0
        case .rain: return 1
        case .haze: return 0.18
        case .bloom: return 0.1
        case .lanterns: return 0.06
        }
    }
}

/// The design package's own name for what the sky is doing.
///
/// A separate type from the domain's `SkyEffect` for the reason ADR-006 gives for `Skin` being two
/// types: the domain decides what the weather *is*, this package decides what it looks like, and
/// neither depends on the other. The composition root maps one to the other.
public enum SkyEffectKind: String, CaseIterable, Sendable {
    case none
    case rain
    case haze
    case bloom
    case lanterns
}
