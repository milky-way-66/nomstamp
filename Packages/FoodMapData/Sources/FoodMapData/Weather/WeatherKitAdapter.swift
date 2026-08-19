import Foundation
import FoodMapDomain
#if canImport(WeatherKit)
import WeatherKit
import CoreLocation
#endif

/// Reads the sky through WeatherKit (ADR-006).
///
/// Every failure is the same failure: no entitlement, no network, no forecast for that patch of
/// ocean — all of them return nil, and the app falls back to the daily rotation. Weather is
/// decoration here, so it is never worth an error message.
public struct WeatherKitAdapter: WeatherPort {
    public init() {}

    public func snapshot(at coordinate: Coordinate) async -> WeatherSnapshot? {
        #if canImport(WeatherKit)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            return WeatherSnapshot(
                condition: Self.condition(for: weather.currentWeather.condition),
                isDaylight: weather.currentWeather.isDaylight
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

#if canImport(WeatherKit)
extension WeatherKitAdapter {
    /// WeatherKit's forty-odd conditions collapsed to the seven the interface can draw.
    ///
    /// The mapping is deliberately blunt: anything falling out of the sky that is not frozen is
    /// rain, anything that reduces visibility is fog, and anything violent is a storm.
    static func condition(for condition: WeatherKit.WeatherCondition) -> FoodMapDomain.WeatherCondition {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .clear
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            return .cloudy
        case .foggy, .haze, .smoky, .blowingDust:
            return .fog
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain, .sleet, .hail:
            return .rain
        case .flurries, .snow, .heavySnow, .sunFlurries, .wintryMix, .blizzard, .blowingSnow, .frigid:
            return .snow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .hurricane, .tropicalStorm, .windy:
            return .storm
        @unknown default:
            return .unknown
        }
    }
}
#endif
