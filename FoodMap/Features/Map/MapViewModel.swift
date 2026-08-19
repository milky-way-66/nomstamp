import Foundation
import Observation
import FoodMapDomain

/// Screen state for the map. Holds no business rules — it asks use cases and publishes results.
@MainActor
@Observable
final class MapViewModel {
    private let dependencies: AppDependencies

    var clusters: [PlaceCluster] = []
    var allPlaces: [Place] = []
    var filter: MapFilter = .all { didSet { refresh() } }
    var errorMessage: String?

    /// Hanoi, so a first launch with no fix still opens somewhere meaningful.
    private(set) var bounds = MapBounds(
        center: Coordinate(latitude: 21.0285, longitude: 105.8542),
        latitudeDelta: 0.05,
        longitudeDelta: 0.05
    )

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var isEmpty: Bool { allPlaces.isEmpty }

    func boundsChanged(to newBounds: MapBounds) {
        bounds = newBounds
        refresh()
    }

    /// Called after every mutation. Giving up SwiftData's `@Query` in views was a deliberate
    /// trade for testability, and this explicit refresh is its cost (ADR-002 §7).
    func refresh() {
        do {
            allPlaces = try dependencies.places.allPlaces()
            clusters = try dependencies.buildPins.execute(bounds: bounds, filter: filter)
        } catch {
            errorMessage = "Could not load your map: \(error.localizedDescription)"
        }
    }

    func place(withID id: Place.ID) -> Place? {
        allPlaces.first { $0.id == id }
    }
}
