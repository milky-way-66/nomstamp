import Testing
import Foundation
@testable import FoodMapDomain

/// UC-6 — the bridge between "I heard about it" and "I ate there".
@Suite("UC-6 Wishlist becomes visited")
struct WishlistTransitionTests {

    private func makeSUT(_ repo: InMemoryPlaceRepository)
        -> (LogMealUseCase, DeleteMealUseCase, FakePhotoStorage) {
        let photos = FakePhotoStorage()
        return (
            LogMealUseCase(places: repo, photos: photos, clock: FixedClock(now: Fixture.epoch)),
            DeleteMealUseCase(places: repo, photos: photos),
            photos
        )
    }

    @Test("TC-6-01 logging a meal at a saved place makes it visited")
    func TC_6_01_becomesVisited() throws {
        let saved = Fixture.place(name: "Bún chả Hương Liên", note: "Lan said try it")
        #expect(saved.kind == .wishlist)
        let repo = InMemoryPlaceRepository([saved])
        let (logMeal, _, _) = makeSUT(repo)

        let place = try logMeal.execute(
            LogMealRequest(target: .existingPlace(saved.id), photoData: [Fixture.imageData])
        )

        #expect(place.kind == .visited)
    }

    @Test("TC-6-02 the recommendation note survives the transition")
    func TC_6_02_notePreserved() throws {
        let saved = Fixture.place(note: "Lan said try the pho")
        let repo = InMemoryPlaceRepository([saved])
        let (logMeal, _, _) = makeSUT(repo)

        let place = try logMeal.execute(
            LogMealRequest(target: .existingPlace(saved.id), photoData: [Fixture.imageData])
        )

        #expect(place.note == "Lan said try the pho")
    }

    @Test("TC-6-03 the place is converted, not replaced")
    func TC_6_03_identityPreserved() throws {
        let saved = Fixture.place()
        let repo = InMemoryPlaceRepository([saved])
        let (logMeal, _, _) = makeSUT(repo)

        let place = try logMeal.execute(
            LogMealRequest(target: .existingPlace(saved.id), photoData: [Fixture.imageData])
        )

        #expect(place.id == saved.id)
        #expect(repo.count == 1)
    }

    @Test("TC-6-04 deleting the last meal reverts the place to wishlist")
    func TC_6_04_revertsWhenLastMealDeleted() throws {
        let meal = Fixture.meal()
        let visited = Fixture.place(note: "Lan said try it", meals: [meal])
        #expect(visited.kind == .visited)
        let repo = InMemoryPlaceRepository([visited])
        let (_, deleteMeal, photos) = makeSUT(repo)

        let place = try deleteMeal.execute(placeID: visited.id, mealID: meal.id)

        #expect(place.kind == .wishlist)
        #expect(place.note == "Lan said try it", "the place must survive, not be deleted")
        #expect(photos.deleted.count == meal.photos.count, "its photo files must be removed")
    }
}
