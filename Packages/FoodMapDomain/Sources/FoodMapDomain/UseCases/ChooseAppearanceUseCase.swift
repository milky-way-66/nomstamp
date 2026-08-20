import Foundation

/// Which set of inks the app is printed in today (ADR-006).
///
/// The names are semantic, not colours: the domain decides *which* skin, and the design package
/// decides what a skin looks like. That keeps this rule a unit test rather than a screenshot.
/// The five printings the design package can draw. Since ADR-006 was revised the running app only
/// ever uses `house`; the rest stay reachable through `-ForceSkin` so a design review can still
/// photograph them.
public enum Skin: String, Sendable, CaseIterable {
    /// What the app is always printed in.
    public static let house: Skin = .pandan

    case pandan
    case bay
    case tamarind
    case sim
    case lotus
}

/// What the sky over the map is doing. Drawn in a band at the top of the map, never over a
/// photograph, a paragraph or the streets a reader is trying to read.
public enum SkyEffect: String, Sendable, CaseIterable {
    case none
    case rain
    case haze
    case bloom
    case lanterns
}

public struct Appearance: Equatable, Sendable {
    public let skin: Skin
    public let effect: SkyEffect
    /// True when the sun is down where the user is: the app goes to its night-market appearance.
    public let isNight: Bool

    public init(skin: Skin, effect: SkyEffect, isNight: Bool) {
        self.skin = skin
        self.effect = effect
        self.isNight = isNight
    }
}

/// Turns a reading of the sky into the day's appearance.
///
/// Pure and synchronous: everything uncertain — permission, network, the forecast itself — has
/// already happened by the time this is called, and arrives as `nil` or `.unknown`.
///
/// It chooses the *sky*, and nothing else. The printing is constant (ADR-006, revised 20 August):
/// letting the weather pick the inks turned the whole app a different colour from one day to the
/// next and made the map hard to read, for no information the reader did not already have by
/// looking out of the window.
public struct ChooseAppearanceUseCase: Sendable {
    public init() {}

    public func execute(weather: WeatherSnapshot?, on date: Date, in calendar: Calendar = .current) -> Appearance {
        let reading = weather ?? .unknown
        let isNight = !reading.isDaylight

        return Appearance(skin: .house, effect: Self.effect(for: reading), isNight: isNight)
    }

    private static func effect(for reading: WeatherSnapshot) -> SkyEffect {
        switch reading.condition {
        // The one condition that reads differently by day and by night: sun, then lanterns.
        case .clear: return reading.isDaylight ? .bloom : .lanterns
        case .cloudy, .fog, .snow: return .haze
        case .rain, .storm: return .rain
        // Nothing is drawn when the sky is unknown: an effect would be a claim.
        case .unknown: return .none
        }
    }


}
