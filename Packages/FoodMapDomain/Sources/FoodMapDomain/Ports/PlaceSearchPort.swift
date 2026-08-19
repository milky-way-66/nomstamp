import Foundation

/// A restaurant offered by a search provider, before the user commits to saving it.
public struct PlaceCandidate: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let address: String?
    public let coordinate: Coordinate
    public let providerPlaceID: String?

    public init(
        id: String,
        name: String,
        address: String? = nil,
        coordinate: Coordinate,
        providerPlaceID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.providerPlaceID = providerPlaceID
    }
}

/// Place lookup, kept swappable by explicit decision (ADR-001).
///
/// Apple Maps today; a Google Places or OSM adapter can replace it without the domain or any
/// view changing.
public protocol PlaceSearchPort: Sendable {
    /// Food places near a coordinate — the zero-typing path for someone sitting in a restaurant.
    func nearbyFoodPlaces(around coordinate: Coordinate, radius: Double) async throws -> [PlaceCandidate]

    /// Places matching a typed name, for somewhere the user only heard about.
    func search(matching query: String, near coordinate: Coordinate?) async throws -> [PlaceCandidate]
}
