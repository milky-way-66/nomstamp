import Testing
import Foundation
@testable import FoodMapDomain

/// UC-1 — Log a meal with a photo.
@Suite("UC-1 Log a meal")
struct LogMealUseCaseTests {

    private func makeSUT(
        places: InMemoryPlaceRepository = .init(),
        photos: FakePhotoStorage = .init(),
        now: Date = Fixture.epoch
    ) -> (LogMealUseCase, InMemoryPlaceRepository, FakePhotoStorage) {
        let sut = LogMealUseCase(places: places, photos: photos, clock: FixedClock(now: now))
        return (sut, places, photos)
    }

    @Test("TC-1-01 a photo and a chosen place produce a meal with photo, time and place")
    func TC_1_01_logsMealAtNewPlace() throws {
        let (sut, repo, _) = makeSUT()
        let draft = PlaceDraft(name: "Phở Thìn", coordinate: Fixture.phoThin)

        let place = try sut.execute(
            LogMealRequest(target: .newPlace(draft), photoData: [Fixture.imageData])
        )

        #expect(place.name == "Phở Thìn")
        #expect(place.meals.count == 1)
        #expect(place.meals[0].photos.count == 1)
        #expect(place.meals[0].eatenAt == Fixture.epoch)
        #expect(repo.count == 1)
    }

    @Test("TC-1-02 the first meal turns a place from wishlist into visited")
    func TC_1_02_firstMealMakesPlaceVisited() throws {
        let (sut, _, _) = makeSUT()
        let draft = PlaceDraft(name: "Bún chả Hương Liên", coordinate: Fixture.bunChaHuongLien)

        let place = try sut.execute(
            LogMealRequest(target: .newPlace(draft), photoData: [Fixture.imageData])
        )

        #expect(place.kind == .visited)
    }

    @Test("TC-1-03 a denied location never blocks logging a meal")
    func TC_1_03_worksWithoutLocation() throws {
        // The use case takes an explicit coordinate, so no LocationPort is involved at all.
        // A denied permission changes how the place is *chosen*, never whether it can be saved.
        let (sut, repo, _) = makeSUT()
        let draft = PlaceDraft(name: "Found by search", coordinate: Fixture.hcmcDistrict1)

        let place = try sut.execute(
            LogMealRequest(target: .newPlace(draft), photoData: [Fixture.imageData])
        )

        #expect(place.meals.count == 1)
        #expect(repo.count == 1)
    }

    @Test("TC-1-04 a photo's own capture time wins over the clock")
    func TC_1_04_usesExifTimeNotNow() throws {
        let photos = FakePhotoStorage()
        let yesterday = Fixture.epoch.addingTimeInterval(-86_400)
        photos.metadata = PhotoMetadata(takenAt: yesterday, coordinate: Fixture.phoThin)
        let (sut, _, _) = makeSUT(photos: photos, now: Fixture.epoch)

        let place = try sut.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "Phở Thìn", coordinate: Fixture.phoThin)),
                photoData: [Fixture.imageData]
            )
        )

        #expect(place.meals[0].eatenAt == yesterday)
    }

    @Test("TC-1-05 with no photo metadata the injected clock is used")
    func TC_1_05_fallsBackToClock() throws {
        let (sut, _, _) = makeSUT(now: Fixture.epoch)

        let place = try sut.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "Quán ăn", coordinate: Fixture.hanoiOldQuarter)),
                photoData: [Fixture.imageData]
            )
        )

        #expect(place.meals[0].eatenAt == Fixture.epoch)
    }

    @Test("TC-1-06 logging at an existing wishlist place creates no second place")
    func TC_1_06_reusesExistingPlace() throws {
        let existing = Fixture.place(name: "Phở Thìn", note: "Lan said try the pho")
        let repo = InMemoryPlaceRepository([existing])
        let (sut, _, _) = makeSUT(places: repo)

        let place = try sut.execute(
            LogMealRequest(target: .existingPlace(existing.id), photoData: [Fixture.imageData])
        )

        #expect(repo.count == 1)
        #expect(place.id == existing.id)
        #expect(place.kind == .visited)
    }

    @Test("TC-1-07 a manually dropped pin keeps the exact coordinate the user chose")
    func TC_1_07_manualPinKeepsCoordinate() throws {
        let (sut, _, _) = makeSUT()
        let stall = Coordinate(latitude: 21.031234, longitude: 105.851234)

        let place = try sut.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "Bánh mì cô Ba", coordinate: stall)),
                photoData: [Fixture.imageData]
            )
        )

        #expect(place.coordinate == stall)
        #expect(place.providerPlaceID == nil)
    }

    @Test("TC-1-08 a failed photo write saves no meal and leaves no orphaned file")
    func TC_1_08_rollsBackOnStorageFailure() throws {
        let photos = FakePhotoStorage()
        photos.failStoreAtIndex = 1 // first photo succeeds, second fails
        let (sut, repo, _) = makeSUT(photos: photos)

        #expect(throws: DomainError.photoStorageFailed) {
            try sut.execute(
                LogMealRequest(
                    target: .newPlace(PlaceDraft(name: "Phở Thìn", coordinate: Fixture.phoThin)),
                    photoData: [Fixture.imageData, Fixture.imageData]
                )
            )
        }

        #expect(repo.count == 0, "no place should be persisted when the save failed")
        #expect(photos.leaked.isEmpty, "the already-written photo must be cleaned up")
    }

    @Test("TC-1-09 every supplied photo is attached, in order")
    func TC_1_09_attachesAllPhotosInOrder() throws {
        let (sut, _, photos) = makeSUT()

        let place = try sut.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "Phở Thìn", coordinate: Fixture.phoThin)),
                photoData: [Fixture.imageData, Fixture.imageData, Fixture.imageData]
            )
        )

        #expect(place.meals[0].photos.count == 3)
        #expect(place.meals[0].photos.map(\.id) == photos.stored.map(\.id))
    }

    @Test("TC-1-10 a meal saves even when place search is unavailable")
    func TC_1_10_savesWithoutSearch() throws {
        // No PlaceSearchPort is a dependency of this use case, which is the design point:
        // losing the network cannot cost the user a meal.
        let (sut, repo, _) = makeSUT()

        try sut.execute(
            LogMealRequest(
                target: .newPlace(PlaceDraft(name: "Typed by hand", coordinate: Fixture.hanoiOldQuarter)),
                photoData: [Fixture.imageData]
            )
        )

        #expect(repo.count == 1)
    }

    @Test("a meal with no photos is rejected")
    func rejectsEmptyPhotoList() throws {
        let (sut, repo, _) = makeSUT()

        #expect(throws: DomainError.noPhotosProvided) {
            try sut.execute(
                LogMealRequest(
                    target: .newPlace(PlaceDraft(name: "X", coordinate: Fixture.phoThin)),
                    photoData: []
                )
            )
        }
        #expect(repo.count == 0)
    }

    @Test("logging against a place id that does not exist fails")
    func rejectsUnknownPlace() throws {
        let (sut, _, _) = makeSUT()

        #expect(throws: DomainError.placeNotFound) {
            try sut.execute(
                LogMealRequest(target: .existingPlace(UUID()), photoData: [Fixture.imageData])
            )
        }
    }
}
