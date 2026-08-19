import Testing
import Foundation
@testable import FoodMapDomain

/// UC-4 — Save a place I heard about.
@Suite("UC-4 Save a place")
struct SavePlaceUseCaseTests {

    private func makeSUT(_ places: InMemoryPlaceRepository = .init())
        -> (SavePlaceUseCase, InMemoryPlaceRepository) {
        (SavePlaceUseCase(places: places, clock: FixedClock(now: Fixture.epoch)), places)
    }

    @Test("TC-4-01 a saved recommendation becomes a wishlist place carrying its note")
    func TC_4_01_savesWishlistPlaceWithNote() throws {
        let (sut, repo) = makeSUT()
        let draft = PlaceDraft(
            name: "Bún chả Hương Liên",
            coordinate: Fixture.bunChaHuongLien,
            note: "Lan said try the bun cha"
        )

        let result = try sut.execute(draft)

        #expect(result.wasExisting == false)
        #expect(result.place.kind == .wishlist)
        #expect(result.place.note == "Lan said try the bun cha")
        #expect(repo.count == 1)
    }

    @Test("TC-4-02 saving the same provider place twice does not duplicate it")
    func TC_4_02_dedupesByProviderID() throws {
        let existing = Fixture.place(name: "Phở Thìn", providerPlaceID: "apple:123")
        let (sut, repo) = makeSUT(InMemoryPlaceRepository([existing]))

        let result = try sut.execute(
            PlaceDraft(name: "Phở Thìn", coordinate: Fixture.phoThin, providerPlaceID: "apple:123")
        )

        #expect(result.wasExisting == true)
        #expect(result.place.id == existing.id)
        #expect(repo.count == 1)
    }

    @Test("TC-4-03 the same name 30 m away is the same place")
    func TC_4_03_dedupesByNameWhenClose() throws {
        let existing = Fixture.place(name: "Phở Thìn", at: Fixture.phoThin)
        let (sut, repo) = makeSUT(InMemoryPlaceRepository([existing]))
        // ~30 m north
        let nearby = Coordinate(latitude: Fixture.phoThin.latitude + 0.00027, longitude: Fixture.phoThin.longitude)

        let result = try sut.execute(PlaceDraft(name: "Phở Thìn", coordinate: nearby))

        #expect(result.wasExisting == true)
        #expect(repo.count == 1)
    }

    @Test("TC-4-04 the same name 300 m away is a different branch")
    func TC_4_04_doesNotDedupeWhenFar() throws {
        let existing = Fixture.place(name: "Phở Thìn", at: Fixture.phoThin)
        let (sut, repo) = makeSUT(InMemoryPlaceRepository([existing]))
        // ~300 m north
        let farther = Coordinate(latitude: Fixture.phoThin.latitude + 0.0027, longitude: Fixture.phoThin.longitude)

        let result = try sut.execute(PlaceDraft(name: "Phở Thìn", coordinate: farther))

        #expect(result.wasExisting == false)
        #expect(repo.count == 2)
    }

    @Test("TC-4-05 'pho thin' and 'Phở Thìn' at one spot are the same place")
    func TC_4_05_ignoresDiacriticsAndCase() throws {
        // Vietnamese users routinely type without diacritics; treating these as different
        // places would quietly fill the map with duplicates.
        let existing = Fixture.place(name: "Phở Thìn", at: Fixture.phoThin)
        let (sut, repo) = makeSUT(InMemoryPlaceRepository([existing]))

        let result = try sut.execute(PlaceDraft(name: "pho thin", coordinate: Fixture.phoThin))

        #expect(result.wasExisting == true)
        #expect(repo.count == 1)
    }

    @Test("TC-4-06 a place that search cannot find can still be dropped by hand")
    func TC_4_06_manualPin() throws {
        let (sut, repo) = makeSUT()
        let cart = Coordinate(latitude: 21.030111, longitude: 105.849222)

        let result = try sut.execute(
            PlaceDraft(name: "Bánh mì xe đẩy góc phố", coordinate: cart, note: "no signboard")
        )

        #expect(result.place.coordinate == cart)
        #expect(result.place.providerPlaceID == nil)
        #expect(repo.count == 1)
    }

    @Test("TC-4-07 tags are persisted")
    func TC_4_07_persistsTags() throws {
        let (sut, _) = makeSUT()

        let result = try sut.execute(
            PlaceDraft(name: "Ramen", coordinate: Fixture.hcmcDistrict1, tags: ["ramen", "Tokyo"])
        )

        #expect(result.place.tags == ["ramen", "Tokyo"])
    }

    @Test("a note added to an already-saved place is not lost")
    func keepsNoteWhenPlaceExisted() throws {
        let existing = Fixture.place(name: "Phở Thìn", providerPlaceID: "apple:1", note: nil)
        let (sut, repo) = makeSUT(InMemoryPlaceRepository([existing]))

        let result = try sut.execute(
            PlaceDraft(
                name: "Phở Thìn",
                coordinate: Fixture.phoThin,
                providerPlaceID: "apple:1",
                note: "Hùng recommends the tái lăn"
            )
        )

        #expect(result.place.note == "Hùng recommends the tái lăn")
        #expect(repo.count == 1)
    }
}
