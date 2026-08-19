import Foundation

/// A point on Earth.
///
/// Deliberately not `CLLocationCoordinate2D`: Core Location is a framework dependency, and
/// keeping the domain free of it is what lets these tests run without a simulator.
public struct Coordinate: Equatable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }

    /// Great-circle distance in metres (haversine).
    ///
    /// Implemented here rather than delegating to Core Location so distance rules stay
    /// testable in the domain. Accurate to well within the 1% that TC-X-06 requires.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = (other.latitude - latitude) * .pi / 180
        let deltaLon = (other.longitude - longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// A rectangular map area, used to ask for only the pins currently on screen.
public struct MapBounds: Equatable, Sendable {
    public let center: Coordinate
    public let latitudeDelta: Double
    public let longitudeDelta: Double

    public init(center: Coordinate, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    public func contains(_ coordinate: Coordinate) -> Bool {
        abs(coordinate.latitude - center.latitude) <= latitudeDelta / 2
            && abs(coordinate.longitude - center.longitude) <= longitudeDelta / 2
    }
}
