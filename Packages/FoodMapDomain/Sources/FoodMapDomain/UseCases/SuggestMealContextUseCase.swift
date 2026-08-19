import Foundation

public struct MealContext: Equatable, Sendable {
    public let eatenAt: Date
    public let coordinate: Coordinate?
    /// Metres of uncertainty in `coordinate`, or nil when the photograph supplied it — a
    /// photographed coordinate is the best answer available and is not second-guessed.
    public let accuracy: Double?
    /// True when the photo's own metadata supplied the answer, meaning the user can log a meal
    /// they photographed hours ago somewhere else and still get the right pin.
    public let derivedFromPhoto: Bool

    public init(eatenAt: Date, coordinate: Coordinate?, accuracy: Double?, derivedFromPhoto: Bool) {
        self.eatenAt = eatenAt
        self.coordinate = coordinate
        self.accuracy = accuracy
        self.derivedFromPhoto = derivedFromPhoto
    }
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

        // A meal's time and its place must agree with each other, so both come from one
        // photograph: the earliest that carries a coordinate. Taking the time from one photo and
        // the coordinate from another can pin yesterday's lunch at tonight's restaurant
        // (FR-1.16).
        let located = metadata
            .filter { $0.coordinate != nil }
            .min { ($0.takenAt ?? .distantFuture) < ($1.takenAt ?? .distantFuture) }
        let capturedAtCoordinate = located?.coordinate
        let capturedAt = located?.takenAt ?? metadata.compactMap(\.takenAt).min()

        // A photo taken at lunch and logged that evening at home must still pin the
        // restaurant, not the sofa — so the photo's own metadata outranks the current fix.
        guard capturedAt != nil || capturedAtCoordinate != nil else {
            let fix = await location.currentFix()
            return MealContext(
                eatenAt: clock.now,
                coordinate: fix?.coordinate,
                accuracy: fix?.accuracy,
                derivedFromPhoto: false
            )
        }

        // `??` cannot wrap an async call, so the fallback fix is resolved explicitly.
        var coordinate = capturedAtCoordinate
        var accuracy: Double?
        if coordinate == nil {
            let fix = await location.currentFix()
            coordinate = fix?.coordinate
            accuracy = fix?.accuracy
        }

        return MealContext(
            eatenAt: capturedAt ?? clock.now,
            coordinate: coordinate,
            accuracy: accuracy,
            derivedFromPhoto: true
        )
    }
}
