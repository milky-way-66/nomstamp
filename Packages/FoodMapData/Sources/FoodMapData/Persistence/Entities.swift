import Foundation
import SwiftData

/// SwiftData's storage shapes. Deliberately separate from the domain entities so business
/// rules never depend on a database (ADR-002 §2).
@Model
public final class PlaceEntity {
    public var id: UUID = UUID()
    public var name: String = ""
    public var address: String?
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var providerPlaceID: String?
    public var note: String?
    public var tags: [String] = []
    public var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MealEntity.place)
    public var meals: [MealEntity] = []

    public init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
public final class MealEntity {
    public var id: UUID = UUID()
    public var eatenAt: Date = Date()
    public var dishName: String?
    public var rating: Int?
    public var note: String?
    public var price: Decimal?
    public var place: PlaceEntity?

    @Relationship(deleteRule: .cascade, inverse: \PhotoEntity.meal)
    public var photos: [PhotoEntity] = []

    public init(id: UUID, eatenAt: Date) {
        self.id = id
        self.eatenAt = eatenAt
    }
}

@Model
public final class PhotoEntity {
    public var id: UUID = UUID()
    public var filename: String = ""
    public var thumbnailFilename: String = ""
    public var width: Double = 0
    public var height: Double = 0
    public var takenAt: Date?
    public var exifLatitude: Double?
    public var exifLongitude: Double?
    /// Preserves the order photos were attached in, which array order alone does not guarantee.
    public var sortIndex: Int = 0
    public var meal: MealEntity?

    public init(id: UUID, filename: String, thumbnailFilename: String) {
        self.id = id
        self.filename = filename
        self.thumbnailFilename = thumbnailFilename
    }
}
