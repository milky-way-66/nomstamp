import Testing
import Foundation
import FoodMapDomain
@testable import FoodMapData

#if canImport(WeatherKit)
import WeatherKit

/// ADR-006 — WeatherKit's vocabulary reduced to the seven conditions the interface can draw.
///
/// Written because the reduction is the one part of the weather path that can rot without anyone
/// noticing: Apple adds a condition, the switch stops being exhaustive, and whoever fixes the
/// build picks a bucket in a hurry. These pin the buckets that are a judgement rather than an
/// obvious synonym.
@Suite("ADR-006 Weather conditions")
struct WeatherKitAdapterTests {

    @Test("Every condition WeatherKit knows lands in a bucket", arguments: WeatherKit.WeatherCondition.allCases)
    func everyConditionMaps(condition: WeatherKit.WeatherCondition) {
        _ = WeatherKitAdapter.condition(for: condition)
    }

    /// Wind is not a sky. Strong wind reads as weather; a breeze does not, and must not be
    /// dressed up as one.
    @Test("Wind splits at the point it becomes weather")
    func windSplits() {
        #expect(WeatherKitAdapter.condition(for: .windy) == .storm)
        #expect(WeatherKitAdapter.condition(for: .breezy) == .unknown)
    }

    @Test("Falling water is rain until it freezes", arguments: [
        (WeatherKit.WeatherCondition.drizzle, FoodMapDomain.WeatherCondition.rain),
        (.freezingRain, .rain),
        (.sleet, .rain),
        (.hail, .rain),
        (.flurries, .snow),
        (.blizzard, .snow),
        (.wintryMix, .snow),
    ])
    func precipitation(condition: WeatherKit.WeatherCondition, expected: FoodMapDomain.WeatherCondition) {
        #expect(WeatherKitAdapter.condition(for: condition) == expected)
    }

    @Test("Anything that hides the view is fog", arguments: [
        WeatherKit.WeatherCondition.foggy, .haze, .smoky, .blowingDust,
    ])
    func visibility(condition: WeatherKit.WeatherCondition) {
        #expect(WeatherKitAdapter.condition(for: condition) == .fog)
    }
}
#endif
