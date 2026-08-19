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
