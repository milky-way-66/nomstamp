import Foundation

/// Persistence of the user's map, expressed in domain terms.
///
/// The domain says "save this place"; it does not know SwiftData exists.
public protocol PlaceRepositoryPort: Sendable {
    func allPlaces() throws -> [Place]
    func place(withID id: Place.ID) throws -> Place?
    func save(_ place: Place) throws
    func deletePlace(withID id: Place.ID) throws
}

public extension PlaceRepositoryPort {
    /// Places whose coordinate falls inside the visible map area (TC-2-01).
    func places(in bounds: MapBounds) throws -> [Place] {
        try allPlaces().filter { bounds.contains($0.coordinate) }
    }
}
