import Testing
import Foundation
@testable import FoodMapDomain

/// ADR-006 — the app is printed in the weather the reader is standing in.
struct ChooseAppearanceUseCaseTests {
    private let choose = ChooseAppearanceUseCase()
    /// A fixed date, so the rotation cases are about the rule and not about today.
    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// TC-N-19 — the sun, and nothing else. Every version of drawn weather was tried and taken
    /// out again (ADR-006, revised twice on 20 August): what survives is whether the lights are on.
    @Test(arguments: [
        (WeatherCondition.clear, true, false),
        (.clear, false, true),
        (.cloudy, true, false),
        (.fog, false, true),
        (.rain, true, false),
        (.storm, false, true),
        (.snow, true, false),
    ])
    func theSkyOnlyDecidesTheLights(condition: WeatherCondition, isDaylight: Bool, isNight: Bool) {
        let appearance = choose.execute(
            weather: WeatherSnapshot(condition: condition, isDaylight: isDaylight),
            on: noon
        )

        #expect(appearance.isNight == isNight)
        // Whatever the sky is doing, the app is printed in the same inks.
        #expect(appearance.skin == .house)
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

    /// TC-N-20 — an unknown sky changes nothing at all: with no reading there is no claim to make
    /// about either the printing or the light.
    @Test func anUnknownSkyChangesNothing() {
        let unknown = choose.execute(weather: nil, on: noon)
        #expect(unknown == Appearance(skin: .house, isNight: false))
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
