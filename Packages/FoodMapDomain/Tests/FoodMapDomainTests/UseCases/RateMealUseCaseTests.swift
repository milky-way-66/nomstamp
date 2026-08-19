import Testing
import Foundation
@testable import FoodMapDomain

@Suite("UC-7 Rate a meal")
struct RateMealUseCaseTests {

    private func makeSUT() -> (RateMealUseCase, InMemoryPlaceRepository) {
        let repository = InMemoryPlaceRepository()
        return (RateMealUseCase(places: repository), repository)
    }

    /// A place with one meal at the given rating.
    private func place(rating: Int?, in repository: InMemoryPlaceRepository) throws -> Place {
        let meal = Meal(eatenAt: Fixture.epoch, rating: rating, photos: [Fixture.photo()])
        let place = Place(
            name: "Phở Thìn",
            coordinate: Fixture.phoThin,
            createdAt: Fixture.epoch,
            meals: [meal]
        )
        try repository.save(place)
        return place
    }

    @Test("TC-7-01 a meal logged with a score carries that rating")
    func TC_7_01_logsWithRating() throws {
        let repository = InMemoryPlaceRepository()
        let useCase = LogMealUseCase(
            places: repository,
            photos: FakePhotoStorage(),
            clock: FixedClock(now: Fixture.epoch)
        )

        try useCase.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "Phở Thìn", coordinate: Fixture.phoThin)),
                photoData: [Data([0x1])],
                rating: 4
            )
        )

        let stored = try #require(try repository.allPlaces().first)
        #expect(stored.meals.first?.rating == 4)
    }

    @Test("TC-7-02 rating an already-rated meal replaces the score")
    func TC_7_02_replacesScore() throws {
        let (sut, repository) = makeSUT()
        let place = try place(rating: 3, in: repository)
        let meal = try #require(place.meals.first)

        try sut.execute(placeID: place.id, mealID: meal.id, score: 5)

        let updated = try #require(try repository.allPlaces().first?.meals.first)
        #expect(updated.rating == 5)
        // Nothing else about the meal moves.
        #expect(updated.id == meal.id)
        #expect(updated.eatenAt == meal.eatenAt)
        #expect(updated.photos == meal.photos)
    }

    @Test("TC-7-03 applying the same score again clears the rating")
    func TC_7_03_clearsWhenRepeated() throws {
        let (sut, repository) = makeSUT()
        let place = try place(rating: 4, in: repository)
        let meal = try #require(place.meals.first)

        try sut.execute(placeID: place.id, mealID: meal.id, score: 4)

        #expect(try repository.allPlaces().first?.meals.first?.rating == nil)
    }

    @Test("TC-7-04 a score outside 1...5 is rejected", arguments: [0, 6, -1, 99])
    func TC_7_04_rejectsOutOfRange(score: Int) throws {
        let (sut, repository) = makeSUT()
        let place = try place(rating: 3, in: repository)
        let meal = try #require(place.meals.first)

        #expect(throws: RateMealError.scoreOutOfRange) {
            try sut.execute(placeID: place.id, mealID: meal.id, score: score)
        }
        #expect(try repository.allPlaces().first?.meals.first?.rating == 3)
    }

    @Test("TC-7-05 a place averages its rated meals and ignores the unrated ones")
    func TC_7_05_averageRating() {
        let place = Place(
            name: "Phở Thìn",
            coordinate: Fixture.phoThin,
            createdAt: Fixture.epoch,
            meals: [
                Meal(eatenAt: Fixture.epoch, rating: 5),
                Meal(eatenAt: Fixture.epoch, rating: 4),
                Meal(eatenAt: Fixture.epoch, rating: nil),
            ]
        )

        #expect(place.averageRating == 4.5)
        #expect(place.ratedMealCount == 2)
    }

    @Test("a place with no rated meals has no average, rather than zero")
    func noRatingsMeansNoAverage() {
        let place = Place(
            name: "Quán mới",
            coordinate: Fixture.phoThin,
            createdAt: Fixture.epoch,
            meals: [Meal(eatenAt: Fixture.epoch, rating: nil)]
        )
        #expect(place.averageRating == nil)
        #expect(place.ratedMealCount == 0)
    }

    @Test("rating an unknown meal is an error, not a silent no-op")
    func unknownMealIsAnError() throws {
        let (sut, repository) = makeSUT()
        let place = try place(rating: nil, in: repository)

        #expect(throws: RateMealError.mealNotFound) {
            try sut.execute(placeID: place.id, mealID: UUID(), score: 3)
        }
    }
}
