import Foundation
import SwiftData
import FoodMapDomain

/// The domain's `PlaceRepositoryPort`, backed by SwiftData on the device.
///
/// `save` is an upsert over the whole place graph: the caller hands back a `Place` struct it
/// mutated, and this reconciles the stored rows to match — updating what changed, inserting
/// what is new, and deleting what the caller removed.
public final class SwiftDataPlaceRepository: PlaceRepositoryPort, @unchecked Sendable {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Reading

    public func allPlaces() throws -> [Place] {
        try context
            .fetch(FetchDescriptor<PlaceEntity>(sortBy: [SortDescriptor(\.createdAt)]))
            .map(PlaceMapper.toDomain)
    }

    public func place(withID id: Place.ID) throws -> Place? {
        try entity(withID: id).map(PlaceMapper.toDomain)
    }

    // MARK: - Writing

    public func save(_ place: Place) throws {
        let entity: PlaceEntity
        if let existing = try self.entity(withID: place.id) {
            entity = existing
        } else {
            entity = PlaceEntity(id: place.id, name: place.name, createdAt: place.createdAt)
            context.insert(entity)
        }

        PlaceMapper.apply(place, to: entity)
        try reconcileMeals(place.meals, on: entity)
        try context.save()
    }

    public func deletePlace(withID id: Place.ID) throws {
        guard let entity = try entity(withID: id) else { return }
        context.delete(entity)
        try context.save()
    }

    // MARK: - Reconciliation

    private func reconcileMeals(_ meals: [Meal], on placeEntity: PlaceEntity) throws {
        let wanted = Set(meals.map(\.id))

        // Removing a meal from the array is not itself a delete; the row must go explicitly,
        // otherwise it lingers detached and reappears in later fetches.
        for stored in placeEntity.meals where !wanted.contains(stored.id) {
            context.delete(stored)
        }

        var byID = Dictionary(
            placeEntity.meals.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for meal in meals {
            let entity: MealEntity
            if let existing = byID[meal.id] {
                entity = existing
            } else {
                entity = MealEntity(id: meal.id, eatenAt: meal.eatenAt)
                context.insert(entity)
                entity.place = placeEntity
                byID[meal.id] = entity
            }
            PlaceMapper.apply(meal, to: entity)
            reconcilePhotos(meal.photos, on: entity)
        }
    }

    private func reconcilePhotos(_ photos: [Photo], on mealEntity: MealEntity) {
        let wanted = Set(photos.map(\.id))
        for stored in mealEntity.photos where !wanted.contains(stored.id) {
            context.delete(stored)
        }

        var byID = Dictionary(
            mealEntity.photos.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for (index, photo) in photos.enumerated() {
            let entity: PhotoEntity
            if let existing = byID[photo.id] {
                entity = existing
            } else {
                entity = PhotoEntity(
                    id: photo.id,
                    filename: photo.filename,
                    thumbnailFilename: photo.thumbnailFilename
                )
                context.insert(entity)
                entity.meal = mealEntity
                byID[photo.id] = entity
            }
            PlaceMapper.apply(photo, index: index, to: entity)
        }
    }

    private func entity(withID id: Place.ID) throws -> PlaceEntity? {
        var descriptor = FetchDescriptor<PlaceEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
