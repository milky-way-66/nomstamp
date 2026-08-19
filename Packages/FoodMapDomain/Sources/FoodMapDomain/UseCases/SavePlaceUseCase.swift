import Foundation

public struct SavePlaceResult: Equatable, Sendable {
    public let place: Place
    /// True when the place was already on the map, so the caller can say so rather than
    /// silently doing nothing (UC-4 / 3a).
    public let wasExisting: Bool
}

/// UC-4 — save a place the user heard about, as a wishlist pin.
public struct SavePlaceUseCase: Sendable {
    private let places: any PlaceRepositoryPort
    private let clock: any ClockPort

    public init(places: any PlaceRepositoryPort, clock: any ClockPort) {
        self.places = places
        self.clock = clock
    }

    @discardableResult
    public func execute(_ draft: PlaceDraft) throws -> SavePlaceResult {
        if var existing = try places.allPlaces().first(where: { PlaceMatcher.isSamePlace($0, as: draft) }) {
            // The pin already exists, but a note or tags typed just now are still worth keeping.
            var changed = false
            if let note = draft.note, !note.isEmpty, note != existing.note {
                existing.note = note
                changed = true
            }
            let newTags = draft.tags.filter { !existing.tags.contains($0) }
            if !newTags.isEmpty {
                existing.tags.append(contentsOf: newTags)
                changed = true
            }
            if changed {
                try places.save(existing)
            }
            return SavePlaceResult(place: existing, wasExisting: true)
        }

        let place = Place(
            name: draft.name,
            address: draft.address,
            coordinate: draft.coordinate,
            providerPlaceID: draft.providerPlaceID,
            note: draft.note,
            tags: draft.tags,
            createdAt: clock.now
        )
        try places.save(place)
        return SavePlaceResult(place: place, wasExisting: false)
    }
}
