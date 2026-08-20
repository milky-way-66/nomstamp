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

public struct Appearance: Equatable, Sendable {
    public let skin: Skin
    /// True when the sun is down where the user is: the app goes to its night-market appearance.
    public let isNight: Bool

    public init(skin: Skin, isNight: Bool) {
        self.skin = skin
        self.isNight = isNight
    }
}

/// Turns a reading of the sky into the day's appearance.
///
/// Pure and synchronous: everything uncertain — permission, network, the forecast itself — has
/// already happened by the time this is called, and arrives as `nil` or `.unknown`.
///
/// It decides one thing: whether the sun is up where the reader is standing. The printing is
/// constant (ADR-006, revised 20 August) and the weather itself is no longer drawn at all (revised
/// again, same day) — every version of it, over the map and around it, bought atmosphere with
/// attention the map needed, for no information the reader did not already have by looking out of
/// the window.
public struct ChooseAppearanceUseCase: Sendable {
    public init() {}

    public func execute(weather: WeatherSnapshot?, on date: Date, in calendar: Calendar = .current) -> Appearance {
        let reading = weather ?? .unknown
        return Appearance(skin: .house, isNight: !reading.isDaylight)
    }
}
