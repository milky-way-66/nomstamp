import Foundation

public enum RateMealError: Error, Equatable, Sendable {
    case placeNotFound
    case mealNotFound
    /// A rating is one to five stars. Anything else is a bug in the caller, not a user choice.
    case scoreOutOfRange
}

/// UC-7 — rate a meal, change the score, or take it back.
///
/// Tapping the score a meal already has clears it (UC-7 / 1b): a wrong rating is worse than
/// no rating, and there is nowhere else in the interface to undo one.
public struct RateMealUseCase: Sendable {
    public static let range = 1...5

    private let places: any PlaceRepositoryPort

    public init(places: any PlaceRepositoryPort) {
        self.places = places
    }

    public func execute(placeID: Place.ID, mealID: Meal.ID, score: Int) throws {
        guard Self.range.contains(score) else { throw RateMealError.scoreOutOfRange }

        guard var place = try places.allPlaces().first(where: { $0.id == placeID }) else {
            throw RateMealError.placeNotFound
        }
        guard let index = place.meals.firstIndex(where: { $0.id == mealID }) else {
            throw RateMealError.mealNotFound
        }

        place.meals[index].rating = place.meals[index].rating == score ? nil : score
        try places.save(place)
    }
}
