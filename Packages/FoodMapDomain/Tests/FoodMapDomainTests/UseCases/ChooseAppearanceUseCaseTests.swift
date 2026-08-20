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

    /// TC-N-20 — an unknown sky leaves the printing alone. It no longer leaves the *light* alone:
    /// see TC-N-29, where the clock answers instead.
    @Test func anUnknownSkyChangesNothing() {
        #expect(choose.execute(weather: nil, on: noon).skin == .house)
    }

    /// TC-N-21 — light and dark follow the sun where the user is standing, not the system setting,
    /// and they do so whatever the sky is doing.
    ///
    /// Every condition but `.unknown`, which is not a sky: it is the absence of one, and its
    /// `isDaylight` is a placeholder rather than a reading. TC-N-29 covers what happens there.
    @Test(arguments: WeatherCondition.allCases.filter { $0 != .unknown })
    func nightIsDecidedByDaylightAlone(condition: WeatherCondition) {
        let day = choose.execute(weather: WeatherSnapshot(condition: condition, isDaylight: true), on: noon)
        let night = choose.execute(weather: WeatherSnapshot(condition: condition, isDaylight: false), on: noon)

        #expect(day.isNight == false)
        #expect(night.isNight == true)
    }

    /// TC-N-29 — with no reading at all, the reader's own clock decides the lights (ADR-006,
    /// revised 20 August). Before this, an unreadable sky meant permanent daylight, so a phone
    /// without location permission, a network or the WeatherKit entitlement could never reach the
    /// night market — which is every simulator and a good many real devices.
    @Test(arguments: [
        (0, true), (5, true), (5, true),
        (6, false), (7, false), (12, false), (17, false),
        (18, true), (21, true), (23, true),
    ])
    func theClockDecidesWhenTheSkyIsUnreadable(hour: Int, isNight: Bool) {
        #expect(choose.execute(weather: nil, on: at(hour), in: calendar).isNight == isNight)
    }

    /// TC-N-29 — a reading that says nothing is the same as no reading. `.unknown` carries
    /// `isDaylight: true` as a placeholder, and reading that placeholder as a fact about the sky
    /// is precisely the bug this revision fixes.
    @Test func anUnknownConditionFallsThroughToTheClock() {
        let midnight = choose.execute(weather: .unknown, on: at(0), in: calendar)
        let noonish = choose.execute(weather: .unknown, on: at(12), in: calendar)

        #expect(midnight.isNight == true)
        #expect(noonish.isNight == false)
    }

    /// TC-N-29 — the clock is only the fallback. WeatherKit knows the real sunset where the reader
    /// is standing; six o'clock is what the app assumes when nobody has told it better, and it
    /// must never overrule someone who has.
    @Test func arealReadingOverrulesTheClock() {
        // Midnight, but the sky says the sun is up — a high-latitude summer, or a reader who
        // crossed a date line since the last fix.
        let brightMidnight = WeatherSnapshot(condition: .clear, isDaylight: true)
        #expect(choose.execute(weather: brightMidnight, on: at(0), in: calendar).isNight == false)

        // And the other way: dark at noon.
        let darkNoon = WeatherSnapshot(condition: .cloudy, isDaylight: false)
        #expect(choose.execute(weather: darkNoon, on: at(12), in: calendar).isNight == true)
    }

    /// TC-N-29 — the boundaries themselves, which are what a reader actually notices: the lights
    /// come on at six in the evening and go off at six in the morning, not a minute either side.
    @Test func theLightsChangeExactlyAtSix() {
        #expect(choose.execute(weather: nil, on: at(5, minute: 59), in: calendar).isNight == true)
        #expect(choose.execute(weather: nil, on: at(6, minute: 0), in: calendar).isNight == false)
        #expect(choose.execute(weather: nil, on: at(17, minute: 59), in: calendar).isNight == false)
        #expect(choose.execute(weather: nil, on: at(18, minute: 0), in: calendar).isNight == true)
    }

    /// A fixed calendar, so the boundary is tested at an instant rather than at whatever hour the
    /// suite happens to run in whatever zone the machine happens to be set to.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    /// A local time on a fixed day.
    private func at(_ hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 20
        components.hour = hour; components.minute = minute
        return calendar.date(from: components)!
    }
}
