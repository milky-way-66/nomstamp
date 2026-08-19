import Foundation

/// A device fix: where we are, and how well we know it.
///
/// Accuracy travels with the coordinate because a coordinate alone cannot be judged. A fix good
/// to 15 m picks a restaurant; a fix good to 800 m only picks a district, and preselecting from
/// it would be a confident wrong answer (FR-1.13).
public struct LocationFix: Equatable, Sendable {
    public let coordinate: Coordinate
    /// Metres of horizontal uncertainty, as reported by the device. Never negative — an invalid
    /// fix is no fix, and is dropped before it reaches the domain.
    public let accuracy: Double

    public init(coordinate: Coordinate, accuracy: Double) {
        self.coordinate = coordinate
        self.accuracy = accuracy
    }
}

/// Where the user is. Returns nil rather than throwing when unavailable: a denied permission
/// must degrade the experience, never block logging a meal (UC-1 / E1).
public protocol LocationPort: Sendable {
    func currentFix() async -> LocationFix?
}

public extension LocationPort {
    /// For callers that only place a dot on a map or measure a distance for a list, where a
    /// coarse fix is still useful. Anything that *chooses a place* must weigh the accuracy.
    func currentCoordinate() async -> Coordinate? {
        await currentFix()?.coordinate
    }
}
