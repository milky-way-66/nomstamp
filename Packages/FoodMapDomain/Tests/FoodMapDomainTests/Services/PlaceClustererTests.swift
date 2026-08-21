import Testing
import Foundation
@testable import FoodMapDomain

/// UC-2 step 4 — clustering.
@Suite("Clustering")
struct PlaceClustererTests {

    /// About 10 m apart.
    private let a = Coordinate(latitude: 21.03330, longitude: 105.85000)
    private let b = Coordinate(latitude: 21.03339, longitude: 105.85000)

    private func bounds(delta: Double) -> MapBounds {
        MapBounds(center: Fixture.hanoiOldQuarter, latitudeDelta: delta, longitudeDelta: delta)
    }

    @Test("TC-2-04 two places 10 m apart collapse into one cluster at city zoom")
    func TC_2_04_collapsesAtCityZoom() {
        let places = [Fixture.place(name: "A", at: a), Fixture.place(name: "B", at: b)]

        let clusters = PlaceClusterer.cluster(places: places, in: bounds(delta: 0.05))

        #expect(clusters.count == 1)
        #expect(clusters[0].count == 2)
    }

    @Test("TC-2-05 the same two places stay separate at street zoom")
    func TC_2_05_separatesAtStreetZoom() {
        let places = [Fixture.place(name: "A", at: a), Fixture.place(name: "B", at: b)]

        let clusters = PlaceClusterer.cluster(places: places, in: bounds(delta: 0.0005))

        #expect(clusters.count == 2)
    }

    @Test("TC-2-06 a lone place keeps its exact coordinate, with no averaging drift")
    func TC_2_06_singlePlaceKeepsExactCoordinate() {
        // Averaging a one-element group would move the pin off the restaurant's door.
        let place = Fixture.place(at: a)

        let clusters = PlaceClusterer.cluster(places: [place], in: bounds(delta: 0.05))

        #expect(clusters.count == 1)
        #expect(clusters[0].coordinate == a)
    }

    @Test("TC-2-09 clustering never drops or duplicates a place")
    func TC_2_09_conservesEveryPlace() {
        // The real clustering bug is losing pins, not making ugly groups.
        var places: [Place] = []
        for i in 0..<200 {
            places.append(
                Fixture.place(
                    name: "P\(i)",
                    at: Coordinate(
                        latitude: 21.02 + Double(i % 20) * 0.001,
                        longitude: 105.84 + Double(i / 20) * 0.001
                    )
                )
            )
        }

        let clusters = PlaceClusterer.cluster(places: places, in: bounds(delta: 0.05))

        let clustered = clusters.flatMap { $0.places.map(\.id) }
        #expect(clustered.count == 200, "no place may be dropped or duplicated")
        #expect(Set(clustered).count == 200)
        #expect(clusters.count < 200, "dense places should actually group")
    }

    @Test("an empty map produces no clusters")
    func emptyProducesNothing() {
        #expect(PlaceClusterer.cluster(places: [Place](), in: bounds(delta: 0.05)).isEmpty)
    }
}
