import Testing
import Foundation
@testable import FoodMapDomain

/// UC-1 / 1a — working out when and where a meal happened.
@Suite("UC-1 Meal context")
struct SuggestMealContextTests {

    @Test("TC-1-04 a photo's own metadata wins over the current position and clock")
    func TC_1_04_prefersPhotoMetadata() async {
        // The user photographs lunch, then logs it that evening at home. Without this, the
        // pin would land on their house.
        let photos = FakePhotoStorage()
        let lunchtime = Fixture.epoch.addingTimeInterval(-6 * 3600)
        photos.metadata = PhotoMetadata(takenAt: lunchtime, coordinate: Fixture.phoThin)
        let sut = SuggestMealContextUseCase(
            photos: photos,
            location: FakeLocation(Fixture.hcmcDistrict1), // somewhere else entirely
            clock: FixedClock(now: Fixture.epoch)
        )

        let context = await sut.execute(photoData: [Fixture.imageData])

        #expect(context.eatenAt == lunchtime)
        #expect(context.coordinate == Fixture.phoThin)
        #expect(context.derivedFromPhoto == true)
    }

    @Test("TC-1-05 with no photo metadata the clock and current position are used")
    func TC_1_05_fallsBackToNowAndHere() async {
        let sut = SuggestMealContextUseCase(
            photos: FakePhotoStorage(),
            location: FakeLocation(Fixture.hanoiOldQuarter),
            clock: FixedClock(now: Fixture.epoch)
        )

        let context = await sut.execute(photoData: [Fixture.imageData])

        #expect(context.eatenAt == Fixture.epoch)
        #expect(context.coordinate == Fixture.hanoiOldQuarter)
        #expect(context.derivedFromPhoto == false)
    }

    @Test("with neither metadata nor a location fix, the time still resolves")
    func stillResolvesTimeWithoutLocation() async {
        let sut = SuggestMealContextUseCase(
            photos: FakePhotoStorage(),
            location: FakeLocation(nil),
            clock: FixedClock(now: Fixture.epoch)
        )

        let context = await sut.execute(photoData: [Fixture.imageData])

        #expect(context.eatenAt == Fixture.epoch)
        #expect(context.coordinate == nil)
    }
}

/// UC-1 / 1a — a meal's time and place must come from the same photograph (FR-1.16).
@Suite("UC-1 Meal context from several photos")
struct MealContextFromSeveralPhotosTests {

    @Test("TC-1-25 time and coordinate both come from the earliest located photo")
    func TC_1_25_timeAndPlaceAgree() async {
        // Two courses, photographed at the restaurant and then at home: the second shot has the
        // later time and the sofa's coordinate. Reading the time from one and the place from the
        // other would pin the meal at home.
        let photos = FakePhotoStorage()
        let lunch = Data("lunch".utf8)
        let sofa = Data("sofa".utf8)
        let lunchtime = Fixture.epoch.addingTimeInterval(-6 * 3600)
        photos.metadataByImage = [
            sofa: PhotoMetadata(takenAt: Fixture.epoch, coordinate: Fixture.hcmcDistrict1),
            lunch: PhotoMetadata(takenAt: lunchtime, coordinate: Fixture.phoThin),
        ]
        let sut = SuggestMealContextUseCase(
            photos: photos,
            location: FakeLocation(Fixture.hanoiOldQuarter),
            clock: FixedClock(now: Fixture.epoch)
        )

        // Deliberately in the wrong order: the earliest photo, not the first one, decides.
        let context = await sut.execute(photoData: [sofa, lunch])

        #expect(context.eatenAt == lunchtime)
        #expect(context.coordinate == Fixture.phoThin)
        #expect(context.accuracy == nil, "a photographed coordinate needs no accuracy allowance")
    }

    @Test("a photo with a time but no coordinate falls back to the current fix, with its accuracy")
    func timeWithoutCoordinateUsesTheFix() async {
        let photos = FakePhotoStorage()
        photos.metadata = PhotoMetadata(takenAt: Fixture.epoch, coordinate: nil)
        let sut = SuggestMealContextUseCase(
            photos: photos,
            location: FakeLocation(Fixture.hanoiOldQuarter, accuracy: 35),
            clock: FixedClock(now: Fixture.epoch)
        )

        let context = await sut.execute(photoData: [Fixture.imageData])

        #expect(context.coordinate == Fixture.hanoiOldQuarter)
        #expect(context.accuracy == 35)
    }
}
