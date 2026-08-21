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

    /// ADR-010: the friends layer enters here rather than being drawn over the top. One merge,
    /// one filter, one clusterer — which is what makes "a friend's place is drawn as my own" a
    /// fact about the code rather than a promise about the renderer.
    ///
    /// Friend stamps are cut to the viewport first. A stamp matching a place of the reader's that
    /// is off screen is off screen itself, since matching requires the two to be metres apart.
    public func execute(
        bounds: MapBounds,
        filter: MapFilter,
        friendStamps: [FriendStamp] = [],
        circle: FriendCircle = FriendCircle(),
        layerEnabled: Bool = false
    ) throws -> [PlaceCluster] {
        let mine = try places.places(in: bounds)
        let theirs = friendStamps.filter { bounds.contains($0.stamp.coordinate) }
        let pins = MergeFriendStampsUseCase()
            .mapPlaces(places: mine, friendStamps: theirs, circle: circle, layerEnabled: layerEnabled)
            .filter(filter.matches)
        return PlaceClusterer.cluster(places: pins, in: bounds)
    }
}
