import Testing
import Foundation
@testable import FoodMapDomain

/// ADR-006 — the app is printed in the weather the reader is standing in.
struct ChooseAppearanceUseCaseTests {
    private let choose = ChooseAppearanceUseCase()
    /// A fixed date, so the rotation cases are about the rule and not about today.
    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// TC-N-19 — every documented sky maps to its documented effect.
    @Test(arguments: [
        (WeatherCondition.clear, true, SkyEffect.bloom),
        (.clear, false, .lanterns),
        (.cloudy, true, .haze),
        (.fog, true, .haze),
        (.rain, true, .rain),
        (.storm, true, .rain),
        (.snow, true, .haze),
    ])
    func skyChoosesTheEffect(condition: WeatherCondition, isDaylight: Bool, effect: SkyEffect) {
        let appearance = choose.execute(
            weather: WeatherSnapshot(condition: condition, isDaylight: isDaylight),
            on: noon
        )

        #expect(appearance.effect == effect)
    }

    /// TC-N-19 (second half) — a clear sky is the one condition that reads differently after dark.
    @Test func aClearNightIsNotAClearDay() {
        let day = choose.execute(weather: WeatherSnapshot(condition: .clear, isDaylight: true), on: noon)
        let night = choose.execute(weather: WeatherSnapshot(condition: .clear, isDaylight: false), on: noon)

        #expect(day.effect != night.effect)
    }

    /// TC-N-20 — the rule that replaced the skin rotation (ADR-006, revised 20 August). The app is
    /// printed in one set of inks; the weather may draw a sky and it may turn the lights out, and
    /// that is the whole of its authority.
    @Test func theWeatherNeverChangesThePrinting() {
        let readings: [WeatherSnapshot?] = [nil] + WeatherCondition.allCases.flatMap { condition in
            [WeatherSnapshot(condition: condition, isDaylight: true),
             WeatherSnapshot(condition: condition, isDaylight: false)]
        }

        for reading in readings {
            #expect(choose.execute(weather: reading, on: noon).skin == .house)
        }

        // …and not by the date either, which is what used to decide when the sky was unknown.
        let week = (0..<7).map { noon.addingTimeInterval(Double($0) * 24 * 3_600) }
        #expect(Set(week.map { choose.execute(weather: nil, on: $0).skin }) == [Skin.house])
    }

    /// TC-N-20 — an unknown sky draws nothing: an effect would be a claim about the weather.
    @Test func anUnknownSkyIsLeftEmpty() {
        #expect(choose.execute(weather: nil, on: noon).effect == .none)
    }

    /// TC-N-21 — light and dark follow the sun where the user is standing, not the system setting,
    /// and they do so whatever the sky is doing.
    @Test(arguments: WeatherCondition.allCases)
    func nightIsDecidedByDaylightAlone(condition: WeatherCondition) {
        let day = choose.execute(weather: WeatherSnapshot(condition: condition, isDaylight: true), on: noon)
        let night = choose.execute(weather: WeatherSnapshot(condition: condition, isDaylight: false), on: noon)

        #expect(day.isNight == false)
        #expect(night.isNight == true)
    }

    /// TC-N-21 — an unreadable sky is not a dark sky: the default assumes daylight rather than
    /// dropping a reader into a night market at noon.
    @Test func anAbsentReadingIsNotNight() {
        #expect(choose.execute(weather: nil, on: noon).isNight == false)
    }
}
