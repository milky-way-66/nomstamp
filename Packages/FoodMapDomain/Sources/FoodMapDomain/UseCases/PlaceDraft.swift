import Foundation

/// A place the user intends to save, before it exists on the map.
///
/// Carries a coordinate directly rather than a search result, because a manually dropped pin
/// with a typed name is a first-class path — much Vietnamese street food is in no database
/// at all (ADR-001).
public struct PlaceDraft: Equatable, Sendable {
    public var name: String
    public var address: String?
    public var coordinate: Coordinate
    public var providerPlaceID: String?
    public var note: String?
    public var tags: [String]

    public init(
        name: String,
        address: String? = nil,
        coordinate: Coordinate,
        providerPlaceID: String? = nil,
        note: String? = nil,
        tags: [String] = []
    ) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.providerPlaceID = providerPlaceID
        self.note = note
        self.tags = tags
    }

    public init(candidate: PlaceCandidate, note: String? = nil, tags: [String] = []) {
        self.init(
            name: candidate.name,
            address: candidate.address,
            coordinate: candidate.coordinate,
            providerPlaceID: candidate.providerPlaceID,
            note: note,
            tags: tags
        )
    }
}
