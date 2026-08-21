import Foundation

public enum MapFilter: String, CaseIterable, Sendable {
    case all, visited, wishlist

    public func matches(_ place: Place) -> Bool {
        matches(place.kind)
    }

    /// The same question asked of a pin whoever put it there. ADR-010 makes *stamps or wishlist*
    /// a property of the place rather than of whose it is, so one filter answers both halves.
    public func matches(_ place: MapPlace) -> Bool {
        matches(place.kind)
    }

    public func matches(_ kind: PlaceKind) -> Bool {
        switch self {
        case .all: return true
        case .visited: return kind == .visited
        case .wishlist: return kind == .wishlist
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
