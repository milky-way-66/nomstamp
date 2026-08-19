import Foundation

/// Where a meal is being logged: at a place already on the map, or at a new one.
public enum MealTarget: Equatable, Sendable {
    case existingPlace(Place.ID)
    case newPlace(PlaceDraft)
}

public struct LogMealRequest: Sendable {
    public var target: MealTarget
    public var photoData: [Data]
    public var dishName: String?
    public var rating: Int?
    public var note: String?
    public var price: Decimal?
    /// Overrides the derived time when the user edits it by hand.
    public var eatenAt: Date?

    public init(
        target: MealTarget,
        photoData: [Data],
        dishName: String? = nil,
        rating: Int? = nil,
        note: String? = nil,
        price: Decimal? = nil,
        eatenAt: Date? = nil
    ) {
        self.target = target
        self.photoData = photoData
        self.dishName = dishName
        self.rating = rating
        self.note = note
        self.price = price
        self.eatenAt = eatenAt
    }
}

/// UC-1 — store a photographed meal against a place.
public struct LogMealUseCase: Sendable {
    private let places: any PlaceRepositoryPort
    private let photos: any PhotoStoragePort
    private let clock: any ClockPort

    public init(places: any PlaceRepositoryPort, photos: any PhotoStoragePort, clock: any ClockPort) {
        self.places = places
        self.photos = photos
        self.clock = clock
    }

    @discardableResult
    public func execute(_ request: LogMealRequest) throws -> Place {
        guard !request.photoData.isEmpty else { throw DomainError.noPhotosProvided }

        var place = try resolvePlace(for: request.target)

        // Photos are written before the meal is persisted, and any that made it to disk are
        // removed if a later step fails. Without this a failed save leaves image files behind
        // that nothing references (TC-1-08).
        let stored = try storePhotosWithRollback(request.photoData)

        let meal = Meal(
            eatenAt: resolveEatenAt(explicit: request.eatenAt, photos: stored),
            dishName: request.dishName,
            rating: request.rating,
            note: request.note,
            price: request.price,
            photos: stored
        )
        place.meals.append(meal)

        do {
            try places.save(place)
        } catch {
            stored.forEach(photos.delete)
            throw error
        }
        return place
    }

    private func resolvePlace(for target: MealTarget) throws -> Place {
        switch target {
        case .existingPlace(let id):
            guard let place = try places.place(withID: id) else {
                throw DomainError.placeNotFound
            }
            return place
        case .newPlace(let draft):
            return Place(
                name: draft.name,
                address: draft.address,
                coordinate: draft.coordinate,
                providerPlaceID: draft.providerPlaceID,
                note: draft.note,
                tags: draft.tags,
                createdAt: clock.now
            )
        }
    }

    private func storePhotosWithRollback(_ data: [Data]) throws -> [Photo] {
        var stored: [Photo] = []
        do {
            for item in data {
                stored.append(try photos.store(imageData: item))
            }
        } catch {
            stored.forEach(photos.delete)
            throw error
        }
        return stored
    }

    /// An explicit time wins; otherwise the earliest capture time the photos carry; otherwise
    /// now. The photo's own time is what lets a meal be logged hours later, elsewhere (UC-1/1a).
    private func resolveEatenAt(explicit: Date?, photos stored: [Photo]) -> Date {
        explicit ?? stored.compactMap(\.takenAt).min() ?? clock.now
    }
}
