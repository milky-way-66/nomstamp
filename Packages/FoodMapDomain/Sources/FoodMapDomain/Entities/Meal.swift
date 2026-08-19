import Foundation

/// One sitting at a place. Separate from `Place` so a single pin can hold several distinct
/// visits rather than one undifferentiated pile of photos.
public struct Meal: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var eatenAt: Date
    public var dishName: String?
    public var rating: Int?
    public var note: String?
    public var price: Decimal?
    public var photos: [Photo]

    public init(
        id: UUID = UUID(),
        eatenAt: Date,
        dishName: String? = nil,
        rating: Int? = nil,
        note: String? = nil,
        price: Decimal? = nil,
        photos: [Photo] = []
    ) {
        self.id = id
        self.eatenAt = eatenAt
        self.dishName = dishName
        self.rating = rating
        self.note = note
        self.price = price
        self.photos = photos
    }
}
