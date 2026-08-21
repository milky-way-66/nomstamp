import Foundation

/// One place as the map draws it, whoever put it there (ADR-010).
///
/// ADR-009 gave a friend's place its own pin type, its own perforated cut and a countersign
/// badge, and the map became a legend to be decoded. ADR-010 reverses that: **a friend's place
/// is drawn exactly as the reader's own**, so the map answers *where is there food* and the
/// detail sheet answers *whose*. This type is what makes that literal rather than aspirational —
/// there is one unit of drawing, and both sources project into it.
///
/// It carries only what a pin needs. Whose it is survives in `origin`, which the map reads for
/// nothing except deciding which sheet a tap opens.
public struct MapPlace: Identifiable, Equatable, Sendable {
    public enum Origin: Equatable, Sendable {
        case mine(Place)
        /// Everyone who stamped it, in ink order. Never empty.
        case friends([FriendStamp])
    }

    public let origin: Origin

    public init(origin: Origin) {
        self.origin = origin
    }

    public init(_ place: Place) {
        self.init(origin: .mine(place))
    }

    /// Stable across a re-merge, so a sheet does not follow a different pin when a sync lands.
    public var id: String {
        switch origin {
        case .mine(let place): return place.id.uuidString
        case .friends(let stamps):
            return stamps.first.map { "friend:\($0.stamp.placeID.uuidString)" } ?? "friend:?"
        }
    }

    public var isMine: Bool {
        if case .mine = origin { return true }
        return false
    }

    /// The reader's own place, where this pin is one. Nil for a place only a friend has stamped.
    public var mine: Place? {
        if case .mine(let place) = origin { return place }
        return nil
    }

    public var friendStamps: [FriendStamp] {
        if case .friends(let stamps) = origin { return stamps }
        return []
    }

    public var name: String {
        switch origin {
        case .mine(let place): return place.name
        case .friends(let stamps): return stamps.first?.stamp.placeName ?? ""
        }
    }

    public var coordinate: Coordinate {
        switch origin {
        case .mine(let place): return place.coordinate
        case .friends(let stamps):
            return stamps.first?.stamp.coordinate ?? Coordinate(latitude: 0, longitude: 0)
        }
    }

    /// A friend's wishlist place is a wishlist place. That it came over the radio does not change
    /// what it is, and drawing it as anything else would be the distinction ADR-010 removed
    /// reappearing under another name.
    ///
    /// Where several friends have stamped one spot and they disagree — one has been, one means to
    /// go — the pin reads as visited: somebody has eaten there, which is the stronger claim and
    /// the one the reader is looking for.
    public var kind: PlaceKind {
        switch origin {
        case .mine(let place): return place.kind
        case .friends(let stamps):
            return stamps.contains { $0.stamp.kind == .visited } ? .visited : .wishlist
        }
    }

    /// No photograph ever travels between phones (ADR-009), so a friend's pin has none. It is
    /// drawn as the reader's own photoless pins are — which is the point.
    public var pinPhoto: Photo? { mine?.pinPhoto }

    /// How many visits the pin should own up to, so the repeat-visit numeral is drawn on a
    /// friend's place exactly as it is on the reader's. Nil where there is nothing to count.
    public var visitCount: Int? {
        switch origin {
        case .mine(let place): return place.meals.isEmpty ? nil : place.meals.count
        case .friends(let stamps): return stamps.compactMap(\.stamp.visitCount).max()
        }
    }

    public var averageRating: Double? {
        switch origin {
        case .mine(let place): return place.averageRating
        case .friends(let stamps):
            let scores = stamps.compactMap(\.stamp.averageRating)
            guard !scores.isEmpty else { return nil }
            return scores.reduce(0, +) / Double(scores.count)
        }
    }
}
