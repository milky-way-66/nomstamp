import Foundation

/// A place the app picked on the user's behalf, and the name to show while they confirm it.
public struct PlaceSuggestion: Equatable, Sendable {
    public let target: MealTarget
    public let name: String

    public init(target: MealTarget, name: String) {
        self.target = target
        self.name = name
    }
}

/// UC-1 / 3 — answer "which place is this?" before the user is asked (FR-1.11).
///
/// Saved places outrank directory candidates: logging a second meal at a favourite must not
/// create a second pin (UC-1 / 4b). Anything beyond `radius` is not a guess worth making — the
/// user would rather type a name than un-pick a wrong restaurant.
public struct SuggestMealPlaceUseCase: Sendable {
    /// Metres. Wide enough for a GPS fix indoors, tight enough that the neighbouring shop
    /// does not win.
    public static let radius: Double = 120

    private let places: any PlaceRepositoryPort
    private let search: any PlaceSearchPort

    public init(places: any PlaceRepositoryPort, search: any PlaceSearchPort) {
        self.places = places
        self.search = search
    }

    /// - Parameter accuracy: metres of uncertainty in `coordinate`, or nil when it was
    ///   photographed and so needs no allowance.
    public func execute(around coordinate: Coordinate?, accuracy: Double? = nil) async -> PlaceSuggestion? {
        guard let coordinate else { return nil }

        // A fix known only to more than the radius cannot tell two neighbouring shops apart, so
        // it makes no guess at all: the user would rather search than un-pick a wrong one
        // (FR-1.13).
        if let accuracy, accuracy < 0 || accuracy > Self.radius { return nil }

        let saved = ((try? places.allPlaces()) ?? [])
            .map { (place: $0, distance: $0.distance(to: coordinate)) }
            .filter { $0.distance <= Self.radius }
            .min { $0.distance < $1.distance }

        if let saved {
            return PlaceSuggestion(target: .existingPlace(saved.place.id), name: saved.place.name)
        }

        // No network is not a failure here: the confirm step still opens, just without a guess.
        let candidates = (try? await search.nearbyFoodPlaces(around: coordinate, radius: Self.radius)) ?? []
        guard let nearest = candidates
            .map({ (candidate: $0, distance: $0.coordinate.distance(to: coordinate)) })
            .filter({ $0.distance <= Self.radius })
            .min(by: { $0.distance < $1.distance })
        else { return nil }

        return PlaceSuggestion(
            target: .newPlace(PlaceDraft(candidate: nearest.candidate)),
            name: nearest.candidate.name
        )
    }
}
