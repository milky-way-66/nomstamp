import Foundation
import FoodMapDomain

/// Converts between storage entities and domain structs.
///
/// This layer is the price of keeping business rules free of SwiftData, and it is paid
/// deliberately (ADR-002 §2): every rule in the domain can be tested without a database.
public enum PlaceMapper {

    // MARK: - Storage → domain

    public static func toDomain(_ entity: PlaceEntity) -> Place {
        Place(
            id: entity.id,
            name: entity.name,
            address: entity.address,
            coordinate: Coordinate(latitude: entity.latitude, longitude: entity.longitude),
            providerPlaceID: entity.providerPlaceID,
            note: entity.note,
            tags: entity.tags,
            createdAt: entity.createdAt,
            meals: entity.meals
                .sorted { $0.eatenAt < $1.eatenAt }
                .map(toDomain)
        )
    }

    public static func toDomain(_ entity: MealEntity) -> Meal {
        Meal(
            id: entity.id,
            eatenAt: entity.eatenAt,
            dishName: entity.dishName,
            rating: entity.rating,
            note: entity.note,
            price: entity.price,
            // Relationship arrays have no guaranteed order, so the stored index restores it.
            photos: entity.photos
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(toDomain)
        )
    }

    public static func toDomain(_ entity: PhotoEntity) -> Photo {
        Photo(
            id: entity.id,
            filename: entity.filename,
            thumbnailFilename: entity.thumbnailFilename,
            width: entity.width,
            height: entity.height,
            takenAt: entity.takenAt,
            coordinate: coordinate(latitude: entity.exifLatitude, longitude: entity.exifLongitude)
        )
    }

    private static func coordinate(latitude: Double?, longitude: Double?) -> Coordinate? {
        guard let latitude, let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    // MARK: - Domain → storage

    static func apply(_ place: Place, to entity: PlaceEntity) {
        entity.name = place.name
        entity.address = place.address
        entity.latitude = place.coordinate.latitude
        entity.longitude = place.coordinate.longitude
        entity.providerPlaceID = place.providerPlaceID
        entity.note = place.note
        entity.tags = place.tags
        entity.createdAt = place.createdAt
    }

    static func apply(_ meal: Meal, to entity: MealEntity) {
        entity.eatenAt = meal.eatenAt
        entity.dishName = meal.dishName
        entity.rating = meal.rating
        entity.note = meal.note
        entity.price = meal.price
    }

    static func apply(_ photo: Photo, index: Int, to entity: PhotoEntity) {
        entity.filename = photo.filename
        entity.thumbnailFilename = photo.thumbnailFilename
        entity.width = photo.width
        entity.height = photo.height
        entity.takenAt = photo.takenAt
        entity.exifLatitude = photo.coordinate?.latitude
        entity.exifLongitude = photo.coordinate?.longitude
        entity.sortIndex = index
    }
}
