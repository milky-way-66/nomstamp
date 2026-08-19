import Foundation

/// What the sky is doing, in the only detail the app needs (ADR-006).
///
/// Deliberately coarse: the interface has five skins and four effects, so a forecast's hundred
/// condition codes collapse to these seven before they cross the port.
public enum WeatherCondition: String, Sendable, CaseIterable {
    case clear
    case cloudy
    case fog
    case rain
    case snow
    case storm
    /// Nothing worth drawing — no permission, no network, no entitlement, or a forecast that
    /// describes something other than the sky. Not an error: the app falls back to the daily
    /// rotation.
    case unknown
}

public struct WeatherSnapshot: Equatable, Sendable {
    public let condition: WeatherCondition
    /// Whether the sun is up where the user is. The app's light and dark follow this rather than
    /// the system setting, because night is a fact about where someone is standing.
    public let isDaylight: Bool

    public init(condition: WeatherCondition, isDaylight: Bool) {
        self.condition = condition
        self.isDaylight = isDaylight
    }

    public static let unknown = WeatherSnapshot(condition: .unknown, isDaylight: true)
}

/// Reading the sky at a coordinate. Returns nil for anything it cannot answer.
public protocol WeatherPort: Sendable {
    func snapshot(at coordinate: Coordinate) async -> WeatherSnapshot?
}
