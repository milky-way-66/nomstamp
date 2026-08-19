import Testing
import Foundation
import SwiftData
import FoodMapDomain
@testable import FoodMapData

@Suite("Persistence")
struct PersistenceTests {

    /// An in-memory container: real SwiftData behaviour, no file on disk, no simulator.
    private func makeSUT() throws -> (SwiftDataPlaceRepository, ModelContext) {
        let container = try ModelContainer(
            for: PlaceEntity.self, MealEntity.self, PhotoEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        return (SwiftDataPlaceRepository(context: context), context)
    }

    private let hanoi = Coordinate(latitude: 21.0285, longitude: 105.8542)
    private let epoch = Date(timeIntervalSince1970: 1_767_225_600)

    @Test("TC-X-02 a place survives a round trip through storage unchanged")
    func TC_X_02_placeRoundTrip() throws {
        let (sut, _) = try makeSUT()
        let original = Place(
            name: "Phở Thìn",
            address: "13 Lò Đúc",
            coordinate: hanoi,
            providerPlaceID: "apple:123",
            note: "Lan said try the tái lăn",
            tags: ["pho", "Hanoi"],
            createdAt: epoch
        )

        try sut.save(original)
        let loaded = try #require(try sut.place(withID: original.id))

        #expect(loaded.id == original.id)
        #expect(loaded.name == original.name)
        #expect(loaded.address == original.address)
        #expect(loaded.coordinate == original.coordinate)
        #expect(loaded.providerPlaceID == original.providerPlaceID)
        #expect(loaded.note == original.note)
        #expect(loaded.tags == original.tags)
        #expect(loaded.createdAt == original.createdAt)
    }

    @Test("TC-X-03 a meal's photos survive with their order and metadata")
    func TC_X_03_mealAndPhotoRoundTrip() throws {
        let (sut, _) = try makeSUT()
        let first = Photo(
            filename: "a.jpg", thumbnailFilename: "a_t.jpg", width: 1200, height: 900,
            takenAt: epoch, coordinate: hanoi
        )
        let second = Photo(filename: "b.jpg", thumbnailFilename: "b_t.jpg", width: 800, height: 600)
        let third = Photo(filename: "c.jpg", thumbnailFilename: "c_t.jpg", width: 640, height: 480)
        let meal = Meal(
            eatenAt: epoch, dishName: "Phở bò", rating: 5, note: "excellent",
            price: Decimal(60000), photos: [first, second, third]
        )
        let place = Place(name: "Phở Thìn", coordinate: hanoi, createdAt: epoch, meals: [meal])

        try sut.save(place)
        let loaded = try #require(try sut.place(withID: place.id))

        let loadedMeal = try #require(loaded.meals.first)
        #expect(loadedMeal.dishName == "Phở bò")
        #expect(loadedMeal.rating == 5)
        #expect(loadedMeal.price == Decimal(60000))
        #expect(loadedMeal.photos.map(\.filename) == ["a.jpg", "b.jpg", "c.jpg"], "order must survive")
        #expect(loadedMeal.photos[0].takenAt == epoch)
        #expect(loadedMeal.photos[0].coordinate == hanoi)
        #expect(loadedMeal.photos[0].width == 1200)
    }

    @Test("TC-X-04 a whole place graph round trips intact")
    func TC_X_04_fullGraphRoundTrip() throws {
        let (sut, _) = try makeSUT()
        let place = Place(
            name: "Bún chả Hương Liên", coordinate: hanoi, note: "Obama ate here", createdAt: epoch,
            meals: [
                Meal(eatenAt: epoch, photos: [Photo(filename: "1.jpg", thumbnailFilename: "1t.jpg", width: 10, height: 10)]),
                Meal(eatenAt: epoch.addingTimeInterval(86_400), photos: [
                    Photo(filename: "2.jpg", thumbnailFilename: "2t.jpg", width: 10, height: 10),
                    Photo(filename: "3.jpg", thumbnailFilename: "3t.jpg", width: 10, height: 10)
                ])
            ]
        )

        try sut.save(place)
        let loaded = try #require(try sut.place(withID: place.id))

        #expect(loaded.meals.count == 2)
        #expect(loaded.meals.flatMap(\.photos).count == 3)
        #expect(loaded.kind == .visited)
        #expect(loaded.note == "Obama ate here")
    }

    @Test("TC-3-05 deleting a place removes it and its meals")
    func TC_3_05_deleteCascades() throws {
        let (sut, context) = try makeSUT()
        let place = Place(
            name: "Gone", coordinate: hanoi, createdAt: epoch,
            meals: [Meal(eatenAt: epoch, photos: [Photo(filename: "x.jpg", thumbnailFilename: "xt.jpg", width: 1, height: 1)])]
        )
        try sut.save(place)

        try sut.deletePlace(withID: place.id)

        #expect(try sut.place(withID: place.id) == nil)
        #expect(try sut.allPlaces().isEmpty)
        // The cascade must take the children too, or orphaned rows accumulate.
        #expect(try context.fetch(FetchDescriptor<MealEntity>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PhotoEntity>()).isEmpty)
    }

    @Test("saving the same place twice updates it rather than duplicating it")
    func saveIsAnUpsert() throws {
        let (sut, _) = try makeSUT()
        var place = Place(name: "Original", coordinate: hanoi, createdAt: epoch)
        try sut.save(place)

        place.name = "Renamed"
        place.note = "added later"
        try sut.save(place)

        let all = try sut.allPlaces()
        #expect(all.count == 1)
        #expect(all[0].name == "Renamed")
        #expect(all[0].note == "added later")
    }

    @Test("adding a meal to a stored place turns it visited without duplicating it")
    func addingMealUpdatesInPlace() throws {
        let (sut, _) = try makeSUT()
        var place = Place(name: "Wishlist", coordinate: hanoi, note: "heard good things", createdAt: epoch)
        try sut.save(place)
        #expect(try sut.place(withID: place.id)?.kind == .wishlist)

        place.meals.append(Meal(eatenAt: epoch, photos: [Photo(filename: "m.jpg", thumbnailFilename: "mt.jpg", width: 1, height: 1)]))
        try sut.save(place)

        let loaded = try #require(try sut.place(withID: place.id))
        #expect(loaded.kind == .visited)
        #expect(loaded.note == "heard good things")
        #expect(try sut.allPlaces().count == 1)
    }

    @Test("removing a meal from a place deletes its rows")
    func removingMealDeletesRows() throws {
        let (sut, context) = try makeSUT()
        let keep = Meal(eatenAt: epoch, photos: [Photo(filename: "k.jpg", thumbnailFilename: "kt.jpg", width: 1, height: 1)])
        let drop = Meal(eatenAt: epoch, photos: [Photo(filename: "d.jpg", thumbnailFilename: "dt.jpg", width: 1, height: 1)])
        var place = Place(name: "P", coordinate: hanoi, createdAt: epoch, meals: [keep, drop])
        try sut.save(place)

        place.meals = [keep]
        try sut.save(place)

        let loaded = try #require(try sut.place(withID: place.id))
        #expect(loaded.meals.count == 1)
        #expect(try context.fetch(FetchDescriptor<MealEntity>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PhotoEntity>()).count == 1)
    }

    @Test("places outside the visible bounds are excluded")
    func filtersByBounds() throws {
        let (sut, _) = try makeSUT()
        try sut.save(Place(name: "Hanoi", coordinate: hanoi, createdAt: epoch))
        try sut.save(Place(name: "HCMC", coordinate: Coordinate(latitude: 10.7769, longitude: 106.7009), createdAt: epoch))

        let visible = try sut.places(in: MapBounds(center: hanoi, latitudeDelta: 0.5, longitudeDelta: 0.5))

        #expect(visible.map(\.name) == ["Hanoi"])
    }

    @Test("an empty store returns no places")
    func emptyStore() throws {
        let (sut, _) = try makeSUT()
        #expect(try sut.allPlaces().isEmpty)
        #expect(try sut.place(withID: UUID()) == nil)
    }
}
