import Foundation

/// Which set of inks the app is printed in today (ADR-006).
///
/// The names are semantic, not colours: the domain decides *which* skin, and the design package
/// decides what a skin looks like. That keeps this rule a unit test rather than a screenshot.
public enum Skin: String, Sendable, CaseIterable {
    case pandan
    case bay
    case tamarind
    case sim
    case lotus
}

/// What is drawn over the map on top of the skin. Never over a photograph or a paragraph.
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
public struct ChooseAppearanceUseCase: Sendable {
    public init() {}

    public func execute(weather: WeatherSnapshot?, on date: Date, in calendar: Calendar = .current) -> Appearance {
        let reading = weather ?? .unknown
        let isNight = !reading.isDaylight

        switch reading.condition {
        case .clear:
            // The one condition that reads differently by day and by night: sun, then dusk.
            return Appearance(
                skin: isNight ? .sim : .tamarind,
                effect: isNight ? .lanterns : .bloom,
                isNight: isNight
            )
        case .cloudy:
            return Appearance(skin: .pandan, effect: .haze, isNight: isNight)
        case .fog:
            return Appearance(skin: .sim, effect: .haze, isNight: isNight)
        case .rain, .storm:
            return Appearance(skin: .bay, effect: .rain, isNight: isNight)
        case .snow:
            return Appearance(skin: .bay, effect: .haze, isNight: isNight)
        case .unknown:
            // No reading at all: the date decides, so the app still changes — one skin per day,
            // never mid-look. Random per launch was rejected: an app that changes colour while you
            // watch reads as broken rather than alive (ADR-006).
            return Appearance(skin: Self.rotation(on: date, in: calendar), effect: .none, isNight: isNight)
        }
    }

    /// The skin for a given day. Days since the reference date, modulo the skins, so it is stable
    /// within a day, different tomorrow, and covers every skin over five days.
    public static func rotation(on date: Date, in calendar: Calendar = .current) -> Skin {
        let days = calendar.startOfDay(for: date).timeIntervalSinceReferenceDate / 86_400
        let count = Skin.allCases.count
        // Dates before the reference date give a negative remainder, which is not an index.
        let index = ((Int(days.rounded(.down)) % count) + count) % count
        return Skin.allCases[index]
    }
}
