import Foundation

public struct MealContext: Equatable, Sendable {
    public let eatenAt: Date
    public let coordinate: Coordinate?
    /// True when the photo's own metadata supplied the answer, meaning the user can log a meal
    /// they photographed hours ago somewhere else and still get the right pin.
    public let derivedFromPhoto: Bool
}

/// UC-1 / 1a — decide when and where a meal happened, before asking the user to confirm.
public struct SuggestMealContextUseCase: Sendable {
    private let photos: any PhotoStoragePort
    private let location: any LocationPort
    private let clock: any ClockPort

    public init(photos: any PhotoStoragePort, location: any LocationPort, clock: any ClockPort) {
        self.photos = photos
        self.location = location
        self.clock = clock
    }

    public func execute(photoData: [Data]) async -> MealContext {
        let metadata = photoData.map(photos.readMetadata(from:))
        let capturedAt = metadata.compactMap(\.takenAt).min()
        let capturedAtCoordinate = metadata.compactMap(\.coordinate).first

        // A photo taken at lunch and logged that evening at home must still pin the
        // restaurant, not the sofa — so the photo's own metadata outranks the current fix.
        guard capturedAt != nil || capturedAtCoordinate != nil else {
            return MealContext(
                eatenAt: clock.now,
                coordinate: await location.currentCoordinate(),
                derivedFromPhoto: false
            )
        }

        // `??` cannot wrap an async call, so the fallback fix is resolved explicitly.
        var coordinate = capturedAtCoordinate
        if coordinate == nil {
            coordinate = await location.currentCoordinate()
        }

        return MealContext(
            eatenAt: capturedAt ?? clock.now,
            coordinate: coordinate,
            derivedFromPhoto: true
        )
    }
}
