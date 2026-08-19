import Foundation

public struct PlaceDistance: Equatable, Sendable {
    public let place: Place
    public let distance: Double

    public init(place: Place, distance: Double) {
        self.place = place
        self.distance = distance
    }
}

/// "Nothing saved here" and "I don't know where you are" are different answers and must never
/// look the same to the user (TC-5-03 vs TC-5-04).
public enum NearbyPlacesOutcome: Equatable, Sendable {
    case located([PlaceDistance])
    case locationUnavailable
}

/// UC-5 — the payoff half of "save a place I heard about".
public struct FindPlacesNearbyUseCase: Sendable {
    private let places: any PlaceRepositoryPort
    private let location: any LocationPort

    public init(places: any PlaceRepositoryPort, location: any LocationPort) {
        self.places = places
        self.location = location
    }

    public func execute(radius: Double) async throws -> NearbyPlacesOutcome {
        // No fix means we genuinely do not know — which is a different answer from
        // "you saved nothing here", and the user must be told the difference (TC-5-04).
        guard let origin = await location.currentCoordinate() else {
            return .locationUnavailable
        }

        let nearby = try places.allPlaces()
            .map { PlaceDistance(place: $0, distance: $0.distance(to: origin)) }
            .filter { $0.distance <= radius }
            .sorted { $0.distance < $1.distance }

        return .located(nearby)
    }
}
