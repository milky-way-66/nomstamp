import Foundation

/// One pin on the map, and everyone who has stamped it.
///
/// A place both parties have stamped is the moment the feature is *for*: not "a list of what my
/// friends ate" but **"we have both been here"**.
public struct MapStampGroup: Equatable, Sendable, Identifiable {
    /// The reader's own place, where they have one. Nil for a pin that exists only because a
    /// friend put it there.
    public let ownPlace: Place?
    /// Friends who stamped this place, ordered by ink slot so the drawing does not change
    /// between one sync and the next (TC-10-07).
    public let friendStamps: [FriendStamp]
    public let coordinate: Coordinate
    public let name: String

    public init(ownPlace: Place?, friendStamps: [FriendStamp], coordinate: Coordinate, name: String) {
        self.ownPlace = ownPlace
        self.friendStamps = friendStamps
        self.coordinate = coordinate
        self.name = name
    }

    /// Stable across a re-merge, so presenting a sheet for one pin does not follow the pin when
    /// a sync lands and the array is rebuilt.
    public var id: String {
        ownPlace?.id.uuidString ?? friendStamps.first?.stamp.placeID.uuidString ?? name
    }

    public var isCountersigned: Bool { ownPlace != nil && !friendStamps.isEmpty }
}

/// UC-10 — matching, and what the map is handed.
public struct MergeFriendStampsUseCase: Sendable {
    public init() {}

    /// With the layer off the result is exactly the reader's own pins, in their own order, with
    /// no friend attached to any of them. The map is what it was before the feature existed —
    /// which is the default, and what most readers will always see (FR-12.1, TC-10-01).
    public func execute(
        places: [Place],
        friendStamps: [FriendStamp],
        circle: FriendCircle,
        layerEnabled: Bool
    ) -> [MapStampGroup] {
        guard layerEnabled else {
            return places.map {
                MapStampGroup(ownPlace: $0, friendStamps: [], coordinate: $0.coordinate, name: $0.name)
            }
        }

        var attached: [Place.ID: [FriendStamp]] = [:]
        var unmatched: [FriendStamp] = []

        for stamp in friendStamps {
            if let match = places.first(where: { Self.isSamePlace($0, as: stamp.stamp) }) {
                attached[match.id, default: []].append(stamp)
            } else {
                unmatched.append(stamp)
            }
        }

        let own = places.map { place in
            MapStampGroup(
                ownPlace: place,
                friendStamps: Self.orderedByInk(attached[place.id] ?? [], in: circle),
                coordinate: place.coordinate,
                name: place.name
            )
        }

        // A friend's stamp that matches nothing of the reader's stands as its own pin — several
        // friends who have all been somewhere the reader has not still make one pin, not four.
        var friendOnly: [MapStampGroup] = []
        var consumed = Set<Int>()
        for (index, stamp) in unmatched.enumerated() where !consumed.contains(index) {
            var group = [stamp]
            for (otherIndex, other) in unmatched.enumerated()
            where otherIndex > index && !consumed.contains(otherIndex)
                && Self.isSamePlace(stamp.stamp, as: other.stamp) {
                group.append(other)
                consumed.insert(otherIndex)
            }
            friendOnly.append(
                MapStampGroup(
                    ownPlace: nil,
                    friendStamps: Self.orderedByInk(group, in: circle),
                    coordinate: stamp.stamp.coordinate,
                    name: stamp.stamp.placeName
                )
            )
        }

        return own + friendOnly
    }

    /// What the map draws (ADR-010).
    ///
    /// Every pin is a `MapPlace` and they are indistinguishable by construction: a place a friend
    /// stamped and one the reader stamped arrive here as the same type, are clustered by the same
    /// code and are drawn by the same view. Provenance is carried, but only so a tap knows which
    /// sheet to open.
    ///
    /// With the layer off this is the reader's own places, in their own order — the map as it was
    /// before the feature existed (FR-12.1, TC-10-01).
    public func mapPlaces(
        places: [Place],
        friendStamps: [FriendStamp],
        circle: FriendCircle,
        layerEnabled: Bool
    ) -> [MapPlace] {
        execute(
            places: places,
            friendStamps: friendStamps,
            circle: circle,
            layerEnabled: layerEnabled
        ).map { group in
            if let own = group.ownPlace {
                return MapPlace(own)
            }
            return MapPlace(origin: .friends(group.friendStamps))
        }
    }

    /// Everyone who has also stamped this place, in ink order — the *also stamped by* row on a
    /// place's own page (FR-13.3).
    ///
    /// Deliberately independent of the layer switch. The switch governs the **map**, which is the
    /// drawing the reader asked to keep unchanged; a page the reader opened on purpose is a
    /// different question, and hiding a countersign there would mean the one place the feature
    /// exists for stayed invisible to anyone who prefers a quiet map (ADR-009).
    public func alsoStamped(
        _ place: Place,
        friendStamps: [FriendStamp],
        circle: FriendCircle
    ) -> [FriendStamp] {
        Self.orderedByInk(
            friendStamps.filter { Self.isSamePlace(place, as: $0.stamp) },
            in: circle
        )
    }

    /// Lowest occupied ink slot first, rather than most recently received. Recency would mean the
    /// pin changed under the reader every time a sync landed.
    static func orderedByInk(_ stamps: [FriendStamp], in circle: FriendCircle) -> [FriendStamp] {
        stamps.sorted { lhs, rhs in
            let l = circle.friend(for: lhs.friend)?.inkSlot ?? Int.max
            let r = circle.friend(for: rhs.friend)?.inkSlot ?? Int.max
            if l != r { return l < r }
            return lhs.stamp.placeID.uuidString < rhs.stamp.placeID.uuidString
        }
    }

    /// Two readers who ate at the same shop hold two different local ids for it, so matching runs
    /// in the order ADR-009 carries over from ADR-008: the provider's identifier first, then name
    /// and distance. A-2 says much Vietnamese street food is in no database and arrives as a
    /// manual pin, so the second path is the common one here, not the fallback (FR-12.3).
    static func isSamePlace(_ place: Place, as stamp: SharedStamp) -> Bool {
        PlaceMatcher.isSamePlace(
            place,
            as: PlaceDraft(
                name: stamp.placeName,
                coordinate: stamp.coordinate,
                providerPlaceID: stamp.providerPlaceID
            )
        )
    }

    static func isSamePlace(_ lhs: SharedStamp, as rhs: SharedStamp) -> Bool {
        if let l = lhs.providerPlaceID, let r = rhs.providerPlaceID { return l == r }
        guard lhs.coordinate.distance(to: rhs.coordinate) <= PlaceMatcher.duplicateRadius else {
            return false
        }
        return PlaceMatcher.normalized(lhs.placeName) == PlaceMatcher.normalized(rhs.placeName)
    }
}
