import Foundation

public struct PlaceCluster: Identifiable, Equatable, Sendable {
    public let id: String
    public let coordinate: Coordinate
    public let places: [MapPlace]

    public init(id: String, coordinate: Coordinate, places: [MapPlace]) {
        self.id = id
        self.coordinate = coordinate
        self.places = places
    }

    public var count: Int { places.count }
    public var isSingle: Bool { places.count == 1 }
    public var containsVisited: Bool { places.contains { $0.kind == .visited } }

    /// Prefer a place that has a photo, so a collapsed pin still shows food.
    public var representative: MapPlace? {
        places.first(where: { $0.pinPhoto != nil }) ?? places.first
    }
}

/// Collapses nearby pins so a dense city stays readable (UC-2 step 4).
///
/// Grid-based rather than distance-based: it is O(n), stable while panning, and at map zoom
/// levels indistinguishable from proper k-means. SwiftUI's `Map` has no built-in clustering.
public enum PlaceClusterer {

    /// Roughly how many cluster cells span the visible width. Higher means finer grouping.
    private static let cellsAcrossViewport: Double = 7

    /// Below this cell size, pins cannot visually overlap, so grouping stops.
    private static let minimumCellSize: Double = 0.00005

    /// Convenience for the reader's own places alone — the map before the friends layer, and
    /// what most of the suite exercises.
    public static func cluster(places: [Place], in bounds: MapBounds) -> [PlaceCluster] {
        cluster(places: places.map { MapPlace($0) }, in: bounds)
    }

    public static func cluster(places: [MapPlace], in bounds: MapBounds) -> [PlaceCluster] {
        guard !places.isEmpty else { return [] }

        let latCell = bounds.latitudeDelta / cellsAcrossViewport
        let lonCell = bounds.longitudeDelta / cellsAcrossViewport

        guard latCell > minimumCellSize, lonCell > minimumCellSize else {
            return places.map(single)
        }

        var buckets: [String: [MapPlace]] = [:]
        var order: [String] = []
        for place in places {
            let row = (place.coordinate.latitude / latCell).rounded(.down)
            let column = (place.coordinate.longitude / lonCell).rounded(.down)
            let key = "\(row):\(column)"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(place)
        }

        // Iterating `order` rather than the dictionary keeps output stable across runs, so the
        // map does not reshuffle its pins when nothing changed.
        return order.map { key in
            let grouped = buckets[key]!
            guard grouped.count > 1 else { return single(grouped[0]) }
            // Only real groups get an averaged centre; a lone pin must stay on its doorway.
            let center = Coordinate(
                latitude: grouped.map(\.coordinate.latitude).reduce(0, +) / Double(grouped.count),
                longitude: grouped.map(\.coordinate.longitude).reduce(0, +) / Double(grouped.count)
            )
            return PlaceCluster(id: key, coordinate: center, places: grouped)
        }
    }

    private static func single(_ place: MapPlace) -> PlaceCluster {
        PlaceCluster(id: place.id, coordinate: place.coordinate, places: [place])
    }
}
