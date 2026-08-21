import Testing
import Foundation
@testable import FoodMapDomain

/// UC-2 — Browse my food map.
@Suite("UC-2 Browse the map")
struct BuildMapPinsUseCaseTests {

    private let cityBounds = MapBounds(
        center: Fixture.hanoiOldQuarter,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05
    )

    @Test("TC-2-01 only places inside the visible area are returned")
    func TC_2_01_filtersToVisibleBounds() throws {
        let repo = InMemoryPlaceRepository([
            Fixture.place(name: "In view", at: Fixture.hanoiOldQuarter),
            Fixture.place(name: "Other city", at: Fixture.hcmcDistrict1)
        ])
        let sut = BuildMapPinsUseCase(places: repo)

        let clusters = try sut.execute(bounds: cityBounds, filter: .all)

        let names = clusters.flatMap { $0.places.map(\.name) }
        #expect(names == ["In view"])
    }

    @Test("TC-2-02 two meals at one restaurant make one pin, not two")
    func TC_2_02_onePinPerPlace() throws {
        let place = Fixture.place(
            name: "Phở Thìn",
            at: Fixture.hanoiOldQuarter,
            meals: [
                Fixture.meal(eatenAt: Fixture.epoch),
                Fixture.meal(eatenAt: Fixture.epoch.addingTimeInterval(86_400))
            ]
        )
        let sut = BuildMapPinsUseCase(places: InMemoryPlaceRepository([place]))

        let clusters = try sut.execute(bounds: cityBounds, filter: .all)

        #expect(clusters.count == 1)
        #expect(clusters[0].places.count == 1)
        #expect(clusters[0].places[0].mine?.meals.count == 2)
    }

    @Test("TC-2-03 visited and wishlist places are distinguishable")
    func TC_2_03_kindsDiffer() throws {
        let repo = InMemoryPlaceRepository([
            Fixture.place(name: "Wishlist", at: Fixture.hanoiOldQuarter),
            Fixture.place(name: "Visited", at: Fixture.phoThin, meals: [Fixture.meal()])
        ])
        let sut = BuildMapPinsUseCase(places: repo)

        let places = try sut.execute(bounds: cityBounds, filter: .all).flatMap(\.places)

        #expect(places.first { $0.name == "Wishlist" }?.kind == .wishlist)
        #expect(places.first { $0.name == "Visited" }?.kind == .visited)
    }

    @Test("TC-2-07 a pin shows the most recent meal's first photo")
    func TC_2_07_pinShowsNewestPhoto() throws {
        let oldPhoto = Fixture.photo()
        let newPhoto = Fixture.photo()
        let place = Fixture.place(
            meals: [
                Fixture.meal(eatenAt: Fixture.epoch, photos: [oldPhoto]),
                Fixture.meal(eatenAt: Fixture.epoch.addingTimeInterval(86_400), photos: [newPhoto])
            ]
        )

        #expect(place.pinPhoto?.id == newPhoto.id)
    }

    @Test("TC-2-08 filtering by wishlist hides visited places")
    func TC_2_08_filtersByKind() throws {
        let repo = InMemoryPlaceRepository([
            Fixture.place(name: "Wishlist", at: Fixture.hanoiOldQuarter),
            Fixture.place(name: "Visited", at: Fixture.phoThin, meals: [Fixture.meal()])
        ])
        let sut = BuildMapPinsUseCase(places: repo)

        let names = try sut.execute(bounds: cityBounds, filter: .wishlist).flatMap { $0.places.map(\.name) }

        #expect(names == ["Wishlist"])
    }
}
