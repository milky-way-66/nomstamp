import Foundation

public enum PlaceKind: String, Equatable, Sendable {
    case visited
    case wishlist
}

/// A restaurant on the user's map.
///
/// `kind` is derived from `meals`, never stored. Logging a meal at a saved place therefore
/// flips the pin with no flag to keep in sync (UC-6), and deleting the last meal reverts it
/// (TC-6-04).
public struct Place: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var address: String?
    public var coordinate: Coordinate
    /// Provider identifier when the place came from search; nil for manually dropped pins.
    public var providerPlaceID: String?
    /// Why the place was saved — "Lan said the pho is great".
    public var note: String?
    public var tags: [String]
    public var createdAt: Date
    public var meals: [Meal]

    public init(
        id: UUID = UUID(),
        name: String,
        address: String? = nil,
        coordinate: Coordinate,
        providerPlaceID: String? = nil,
        note: String? = nil,
        tags: [String] = [],
        createdAt: Date,
        meals: [Meal] = []
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.providerPlaceID = providerPlaceID
        self.note = note
        self.tags = tags
        self.createdAt = createdAt
        self.meals = meals
    }

    public var kind: PlaceKind {
        meals.isEmpty ? .wishlist : .visited
    }

    /// The average of the meals that carry a rating. Unrated meals are ignored rather than
    /// counted as zero, and a place with none has no average at all (FR-9.4).
    public var averageRating: Double? {
        let scores = meals.compactMap(\.rating)
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    public var ratedMealCount: Int {
        meals.compactMap(\.rating).count
    }

    public var mealsNewestFirst: [Meal] {
        meals.sorted { $0.eatenAt > $1.eatenAt }
    }

    /// What the map pin shows: the most recent meal's first photo (TC-2-07).
    public var pinPhoto: Photo? {
        mealsNewestFirst.first?.photos.first
    }

    public func distance(to other: Coordinate) -> Double {
        coordinate.distance(to: other)
    }
}
