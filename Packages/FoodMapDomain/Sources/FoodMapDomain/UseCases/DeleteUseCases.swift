import Foundation

/// UC-3 — removing a meal must also remove its image files, or the device slowly fills with
/// photos belonging to nothing (TC-3-04).
public struct DeleteMealUseCase: Sendable {
    private let places: any PlaceRepositoryPort
    private let photos: any PhotoStoragePort

    public init(places: any PlaceRepositoryPort, photos: any PhotoStoragePort) {
        self.places = places
        self.photos = photos
    }

    @discardableResult
    public func execute(placeID: Place.ID, mealID: Meal.ID) throws -> Place {
        guard var place = try places.place(withID: placeID) else {
            throw DomainError.placeNotFound
        }
        guard let index = place.meals.firstIndex(where: { $0.id == mealID }) else {
            throw DomainError.mealNotFound
        }

        let removed = place.meals.remove(at: index)
        try places.save(place)
        // After the save, so a failed write never orphans the meal from its files.
        removed.photos.forEach(photos.delete)

        // The place itself survives even when its last meal goes: it simply becomes a
        // wishlist place again, keeping whatever note explained why it was saved (TC-6-04).
        return place
    }
}

public struct DeletePlaceUseCase: Sendable {
    private let places: any PlaceRepositoryPort
    private let photos: any PhotoStoragePort

    public init(places: any PlaceRepositoryPort, photos: any PhotoStoragePort) {
        self.places = places
        self.photos = photos
    }

    public func execute(placeID: Place.ID) throws {
        guard let place = try places.place(withID: placeID) else {
            throw DomainError.placeNotFound
        }
        try places.deletePlace(withID: placeID)
        for meal in place.meals {
            meal.photos.forEach(photos.delete)
        }
    }
}
