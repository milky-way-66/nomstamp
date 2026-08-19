import Testing
import Foundation
@testable import FoodMapDomain

/// UC-3 — Open a place and see its meals.
@Suite("UC-3 Place detail")
struct PlaceDetailTests {

    @Test("TC-3-01 meals are ordered newest first")
    func TC_3_01_newestFirst() {
        let jan = Fixture.meal(eatenAt: Fixture.epoch)
        let feb = Fixture.meal(eatenAt: Fixture.epoch.addingTimeInterval(31 * 86_400))
        let mar = Fixture.meal(eatenAt: Fixture.epoch.addingTimeInterval(60 * 86_400))
        // Deliberately inserted out of order.
        let place = Fixture.place(meals: [feb, jan, mar])

        #expect(place.mealsNewestFirst.map(\.id) == [mar.id, feb.id, jan.id])
    }

    @Test("TC-3-02 a wishlist place has no meals but keeps its note")
    func TC_3_02_wishlistShowsNote() {
        let place = Fixture.place(note: "Lan said the pho here is great")

        #expect(place.meals.isEmpty)
        #expect(place.kind == .wishlist)
        #expect(place.note == "Lan said the pho here is great")
    }

    @Test("TC-3-03 deleting one meal leaves the others intact")
    func TC_3_03_deleteOneMeal() throws {
        let keep = Fixture.meal(eatenAt: Fixture.epoch)
        let remove = Fixture.meal(eatenAt: Fixture.epoch.addingTimeInterval(86_400))
        let place = Fixture.place(meals: [keep, remove])
        let repo = InMemoryPlaceRepository([place])
        let photos = FakePhotoStorage()
        let sut = DeleteMealUseCase(places: repo, photos: photos)

        let updated = try sut.execute(placeID: place.id, mealID: remove.id)

        #expect(updated.meals.map(\.id) == [keep.id])
        #expect(updated.kind == .visited)
    }

    @Test("deleting a place removes every photo it held")
    func deletePlaceCleansUpPhotos() throws {
        let place = Fixture.place(meals: [
            Fixture.meal(photos: [Fixture.photo(), Fixture.photo()]),
            Fixture.meal(photos: [Fixture.photo()])
        ])
        let repo = InMemoryPlaceRepository([place])
        let photos = FakePhotoStorage()
        let sut = DeletePlaceUseCase(places: repo, photos: photos)

        try sut.execute(placeID: place.id)

        #expect(repo.count == 0)
        #expect(photos.deleted.count == 3, "all three image files must be deleted")
    }
}
