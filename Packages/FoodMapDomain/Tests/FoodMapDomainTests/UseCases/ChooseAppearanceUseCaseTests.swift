import Testing
import Foundation
@testable import FoodMapDomain

/// ADR-006 — the app is printed in the weather the reader is standing in.
struct ChooseAppearanceUseCaseTests {
    private let choose = ChooseAppearanceUseCase()
    /// A fixed date, so the rotation cases are about the rule and not about today.
    private let noon = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// TC-N-19 — every documented sky maps to its documented skin and effect.
    @Test(arguments: [
        (WeatherCondition.clear, true, Skin.tamarind, SkyEffect.bloom),
        (.clear, false, .sim, .lanterns),
        (.cloudy, true, .pandan, .haze),
        (.fog, true, .sim, .haze),
        (.rain, true, .bay, .rain),
        (.storm, true, .bay, .rain),
        (.snow, true, .bay, .haze),
    ])
    func skyChoosesSkinAndEffect(
        condition: WeatherCondition,
        isDaylight: Bool,
        skin: Skin,
        effect: SkyEffect
    ) {
        let appearance = choose.execute(
            weather: WeatherSnapshot(condition: condition, isDaylight: isDaylight),
            on: noon
        )

        #expect(appearance.skin == skin)
        #expect(appearance.effect == effect)
    }

    /// TC-N-19 (second half) — a clear sky is the one condition that reads differently after dark,
    /// so day and night must not land on the same skin.
    @Test func aClearNightIsNotAClearDay() {
        let day = choose.execute(weather: WeatherSnapshot(condition: .clear, isDaylight: true), on: noon)
        let night = choose.execute(weather: WeatherSnapshot(condition: .clear, isDaylight: false), on: noon)

        #expect(day.skin != night.skin)
        #expect(day.effect != night.effect)
    }

    /// TC-N-20 — with no reading at all the date decides: one skin per day, the same all day,
    /// a different one tomorrow, and every skin used across a cycle.
    @Test func withoutAReadingTheDateChoosesTheSkin() {
        let morning = noon
        let evening = noon.addingTimeInterval(8 * 3_600)
        let tomorrow = noon.addingTimeInterval(24 * 3_600)

        #expect(choose.execute(weather: nil, on: morning).skin == choose.execute(weather: nil, on: evening).skin)
        #expect(choose.execute(weather: nil, on: morning).skin != choose.execute(weather: nil, on: tomorrow).skin)
        // Nothing is drawn over the map when the sky is unknown: an effect would be a claim.
        #expect(choose.execute(weather: nil, on: morning).effect == .none)
    }

    /// TC-N-20 — a reader who opens the app every day should see all five skins, not a favourite.
    @Test func theRotationReachesEverySkin() {
        let week = (0..<Skin.allCases.count).map { noon.addingTimeInterval(Double($0) * 24 * 3_600) }
        let skins = Set(week.map { choose.execute(weather: nil, on: $0).skin })

        #expect(skins == Set(Skin.allCases))
    }

    /// TC-N-20 — dates before the reference date must still index a skin rather than trap.
    @Test func theRotationSurvivesDatesBeforeTheReferenceDate() {
        let longAgo = Date(timeIntervalSinceReferenceDate: -900_000_000)

        #expect(Skin.allCases.contains(ChooseAppearanceUseCase.rotation(on: longAgo)))
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
