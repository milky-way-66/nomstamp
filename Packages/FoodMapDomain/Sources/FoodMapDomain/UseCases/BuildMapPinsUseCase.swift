import Foundation

public enum MapFilter: String, CaseIterable, Sendable {
    case all, visited, wishlist

    public func matches(_ place: Place) -> Bool {
        switch self {
        case .all: return true
        case .visited: return place.kind == .visited
        case .wishlist: return place.kind == .wishlist
        }
    }
}

/// UC-2 — what the map should draw for the area currently on screen.
public struct BuildMapPinsUseCase: Sendable {
    private let places: any PlaceRepositoryPort

    public init(places: any PlaceRepositoryPort) {
        self.places = places
    }

    public func execute(bounds: MapBounds, filter: MapFilter) throws -> [PlaceCluster] {
        let visible = try places.places(in: bounds).filter(filter.matches)
        return PlaceClusterer.cluster(places: visible, in: bounds)
    }
}
