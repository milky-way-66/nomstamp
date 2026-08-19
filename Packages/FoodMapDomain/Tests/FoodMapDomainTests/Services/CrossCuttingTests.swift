import Testing
import Foundation
@testable import FoodMapDomain

@Suite("Cross-cutting")
struct CrossCuttingTests {

    @Test("TC-X-01 the injected clock decides the meal time")
    func TC_X_01_clockIsInjected() throws {
        let fixed = Date(timeIntervalSince1970: 1_767_225_600)
        let sut = LogMealUseCase(
            places: InMemoryPlaceRepository(),
            photos: FakePhotoStorage(),
            clock: FixedClock(now: fixed)
        )

        let place = try sut.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "X", coordinate: Fixture.phoThin)),
                photoData: [Fixture.imageData]
            )
        )

        #expect(place.meals[0].eatenAt == fixed)
    }

    @Test("TC-X-05 distances read as metres below a kilometre and kilometres above")
    func TC_X_05_formatsDistance() {
        #expect(DistanceFormatter.string(fromMeters: 850) == "850 m")
        #expect(DistanceFormatter.string(fromMeters: 2400) == "2.4 km")
        #expect(DistanceFormatter.string(fromMeters: 0) == "0 m")
        #expect(DistanceFormatter.string(fromMeters: 999) == "999 m")
        #expect(DistanceFormatter.string(fromMeters: 1000) == "1.0 km")
    }

    @Test("TC-X-06 distance between two known Hanoi points is right to within 1%")
    func TC_X_06_haversineAccuracy() {
        // Phở Thìn (Lò Đúc) to Bún chả Hương Liên: ~135 m by great-circle.
        let measured = Fixture.phoThin.distance(to: Fixture.bunChaHuongLien)
        #expect(measured > 130 && measured < 145, "got \(measured) m")

        // Hanoi to HCMC, a known ~1,140 km separation.
        let longHaul = Fixture.hanoiOldQuarter.distance(to: Fixture.hcmcDistrict1)
        #expect(longHaul > 1_130_000 && longHaul < 1_150_000, "got \(longHaul) m")
    }

    @Test("a coordinate outside the valid range is rejected")
    func rejectsInvalidCoordinate() {
        #expect(Coordinate(latitude: 21, longitude: 105).isValid)
        #expect(!Coordinate(latitude: 91, longitude: 105).isValid)
        #expect(!Coordinate(latitude: 21, longitude: 181).isValid)
    }

    @Test("map bounds contain what is inside and exclude what is outside")
    func boundsContainment() {
        let bounds = MapBounds(center: Fixture.hanoiOldQuarter, latitudeDelta: 0.01, longitudeDelta: 0.01)

        #expect(bounds.contains(Fixture.hanoiOldQuarter))
        #expect(!bounds.contains(Fixture.hcmcDistrict1))
    }
}
