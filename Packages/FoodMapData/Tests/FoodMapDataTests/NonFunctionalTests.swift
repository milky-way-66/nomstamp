import Testing
import Foundation
import SwiftData
import FoodMapDomain
@testable import FoodMapData

/// Cases that pin the non-functional promises of the storage layer: that data actually
/// survives on disk, that saving is fast enough, and that an unwritable disk fails cleanly.
@Suite("Non-functional — storage")
struct StorageNonFunctionalTests {

    private let hanoi = Coordinate(latitude: 21.0285, longitude: 105.8542)

    /// TC-N-02 / NFR-3.1 — every other persistence test uses an in-memory store, which cannot
    /// prove anything survives relaunching. This one writes a real file, drops the container,
    /// and opens it again.
    @Test("TC-N-02 the whole graph survives closing and reopening an on-disk store")
    func TC_N_02_survivesReopening() throws {
        let directory = TemporaryDirectory()
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        let storeURL = directory.url.appendingPathComponent("FoodMap.store")

        let photo = Photo(
            filename: "meal.jpg",
            thumbnailFilename: "meal-thumb.jpg",
            width: 2048,
            height: 1536,
            takenAt: Date(timeIntervalSince1970: 1_767_225_600),
            coordinate: hanoi
        )
        let meal = Meal(
            eatenAt: Date(timeIntervalSince1970: 1_767_225_600),
            dishName: "Phở bò",
            rating: 5,
            note: "Đậm đà",
            photos: [photo]
        )
        let place = Place(
            name: "Phở Thìn",
            address: "13 Lò Đúc",
            coordinate: hanoi,
            note: "Lan giới thiệu",
            tags: ["phở", "hà nội"],
            createdAt: Date(timeIntervalSince1970: 1_767_225_600),
            meals: [meal]
        )

        // Write, then let the container go out of scope entirely.
        do {
            let repository = try makeRepository(at: storeURL)
            try repository.save(place)
        }

        // A brand-new container over the same file — this is what a relaunch does.
        let reopened = try makeRepository(at: storeURL)
        let loaded = try reopened.allPlaces()

        try #require(loaded.count == 1, "the place should still be there after reopening")
        let restored = try #require(loaded.first)
        #expect(restored.id == place.id)
        #expect(restored.name == "Phở Thìn")
        #expect(restored.note == "Lan giới thiệu")
        #expect(restored.tags.sorted() == ["hà nội", "phở"])
        #expect(restored.kind == .visited)

        let restoredMeal = try #require(restored.meals.first)
        #expect(restoredMeal.dishName == "Phở bò")
        #expect(restoredMeal.rating == 5)
        #expect(restoredMeal.note == "Đậm đà")
        #expect(restoredMeal.photos.map(\.filename) == ["meal.jpg"])
        #expect(restoredMeal.photos.first?.coordinate == hanoi)
    }

    /// TC-N-05 / NFR-2.3 — saving a meal with one photograph must take at most a second, which
    /// is the slowest step in the app: full-size re-encode, thumbnail, then the record.
    @Test("TC-N-05 saving a meal with one photo stays within one second")
    func TC_N_05_savingIsFastEnough() throws {
        let directory = TemporaryDirectory()
        let storage = try FileSystemPhotoStorage(directory: directory.url)
        let repository = try makeRepository(at: directory.url.appendingPathComponent("s.store"))
        // A 12 MP frame, larger than anything an iPhone camera hands over for a single shot.
        let data = JPEGFactory.make(width: 4032, height: 3024)

        let elapsed = ContinuousClock().measure {
            let stored = try? storage.store(imageData: data)
            let meal = Meal(eatenAt: Date(), photos: stored.map { [$0] } ?? [])
            try? repository.save(
                Place(name: "Quán mới", coordinate: hanoi, createdAt: Date(), meals: [meal])
            )
        }

        #expect(
            elapsed < .seconds(1),
            "storing image, thumbnail and record took \(elapsed), budget is 1 s (NFR-2.3)"
        )
    }

    /// TC-N-09 / NFR-3.3 + FR-1.8 — a disk that cannot be written must surface an error rather
    /// than crash or leave half a meal behind.
    @Test("TC-N-09 an unwritable photo directory fails cleanly")
    func TC_N_09_unwritableDirectoryFailsCleanly() throws {
        let parent = TemporaryDirectory()
        try FileManager.default.createDirectory(at: parent.url, withIntermediateDirectories: true)
        let photos = parent.url.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        // Read and execute only: the directory exists, so creating storage succeeds, but
        // nothing can be written into it.
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: photos.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: photos.path
            )
        }

        let storage = try FileSystemPhotoStorage(directory: photos)
        let repository = try makeRepository(at: parent.url.appendingPathComponent("s.store"))
        let useCase = LogMealUseCase(places: repository, photos: storage, clock: SystemClock())

        #expect(throws: (any Error).self) {
            try useCase.execute(
                LogMealRequest(
                    target: .newPlace(PlaceDraft(name: "Quán mới", coordinate: hanoi)),
                    photoData: [JPEGFactory.make()]
                )
            )
        }

        // FR-1.8: nothing partial. No place, and no stray files in the directory.
        #expect(try repository.allPlaces().isEmpty)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: photos.path)
        #expect(leftovers.isEmpty, "a failed save left files behind: \(leftovers)")
    }

    private func makeRepository(at url: URL) throws -> SwiftDataPlaceRepository {
        let container = try ModelContainer(
            for: PlaceEntity.self, MealEntity.self, PhotoEntity.self,
            configurations: ModelConfiguration(url: url)
        )
        return SwiftDataPlaceRepository(context: ModelContext(container))
    }
}
