import Testing
import Foundation
import MapKit
import FoodMapDomain
@testable import FoodMapData

@Suite("Apple Maps search adapter")
struct SearchAdapterTests {

    /// Live network tests are opt-in, so the suite stays deterministic and works offline
    /// (NFR-7.5). Run them deliberately with `RUN_NETWORK_TESTS=1 swift test`.
    private static var networkEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_NETWORK_TESTS"] != nil
    }

    @Test("TC-4-08 nearby search uses a category filter, never a free-text category word")
    func TC_4_08_usesCategoryFilterNotFreeText() {
        // This is the ADR-001 finding encoded as a rule: "cà phê" as free text returned a
        // result 1,100 km from where it was searched. The guarantee here is structural — the
        // nearby path uses MKLocalPointsOfInterestRequest, which has no query string at all.
        let request = MKLocalPointsOfInterestRequest(
            center: CLLocationCoordinate2D(latitude: 21.0333, longitude: 105.85),
            radius: 500
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(
            including: AppleMapsPlaceSearchAdapter.foodCategories
        )

        #expect(AppleMapsPlaceSearchAdapter.foodCategories.contains(.restaurant))
        #expect(AppleMapsPlaceSearchAdapter.foodCategories.contains(.cafe))
        #expect(request.pointOfInterestFilter != nil)
    }

    @Test("an empty query returns nothing without calling the network")
    func emptyQueryShortCircuits() async throws {
        let results = try await AppleMapsPlaceSearchAdapter().search(matching: "   ", near: nil)
        #expect(results.isEmpty)
    }

    @Test("a result at Null Island is discarded rather than pinned")
    func rejectsUnusableResults() {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        let item = MKMapItem(placemark: placemark)

        #expect(AppleMapsPlaceSearchAdapter.candidate(from: item) == nil)
    }

    @Test(
        "live: Hanoi Old Quarter still returns food places",
        .enabled(if: networkEnabled)
    )
    func liveNearbyHanoi() async throws {
        let results = try await AppleMapsPlaceSearchAdapter()
            .nearbyFoodPlaces(around: Coordinate(latitude: 21.0333, longitude: 105.85), radius: 500)

        #expect(results.count > 10, "ADR-001 measured ~50 here; a collapse would matter")
        #expect(results.allSatisfy { !$0.name.isEmpty })
    }

    @Test(
        "live: a named Vietnamese restaurant is findable",
        .enabled(if: networkEnabled)
    )
    func liveNamedSearch() async throws {
        let results = try await AppleMapsPlaceSearchAdapter()
            .search(matching: "Bún chả Hương Liên", near: Coordinate(latitude: 21.017, longitude: 105.849))

        #expect(!results.isEmpty)
    }
}
