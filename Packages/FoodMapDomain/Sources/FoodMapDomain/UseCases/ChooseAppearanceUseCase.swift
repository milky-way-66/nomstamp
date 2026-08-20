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
        return Appearance(skin: .house, isNight: isNight(weather: weather, on: date, in: calendar))
    }

    /// The sky if it said anything, the clock if it did not (ADR-006, revised 20 August).
    ///
    /// `.unknown` is not a sky, it is the absence of one, and its `isDaylight` is a placeholder
    /// rather than a reading — so it falls through here exactly as `nil` does. Reading that
    /// placeholder as a fact is what used to leave a phone with no location permission, no network
    /// or no WeatherKit entitlement printed in daylight at midnight, with no way to reach the night
    /// market at all.
    private func isNight(weather: WeatherSnapshot?, on date: Date, in calendar: Calendar) -> Bool {
        guard let weather, weather.condition != .unknown else {
            return !Self.lampsOut.contains(calendar.component(.hour, from: date))
        }
        return !weather.isDaylight
    }

    /// The hours the app assumes the sun is up when nobody has told it otherwise: six in the
    /// morning to six in the evening, local.
    ///
    /// Deliberately blunt rather than a sunrise calculation. A calculation needs the reader's
    /// coordinate, and a missing coordinate is one of the reasons this fallback is reached in the
    /// first place. A real daylight reading always wins over it.
    static let lampsOut: Range<Int> = 6..<18
}
