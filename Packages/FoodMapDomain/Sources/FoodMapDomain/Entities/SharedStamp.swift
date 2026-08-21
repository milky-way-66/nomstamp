import Foundation

/// The whole of what may leave the device about one place (ADR-009, amended by ADR-010).
///
/// **One record per place, never per visit.** A per-meal feed would export a movement history —
/// where this person is, on which evenings, for years. A per-place stamp says *Lan has eaten here
/// three times and rates it 4.5*, which is the entire emotional payload at a fraction of the
/// exposure.
///
/// The redaction is enforced by the type having nowhere to put anything else. There is no field
/// for a price, for a per-meal rating, for an exact date or for a full-size photograph, so no
/// call site can add one without changing this file — and changing this file means changing
/// ADR-009 first.
///
/// ADR-010 added `kind`. A wishlist place now travels, because *where are you thinking of going*
/// is the half of a friend's map that was missing, and it costs strictly less to share than a
/// visit does: there is no rating, no count and no month, so the three fields that carry the
/// history are optional and are nil for every wishlist stamp by construction.
public struct SharedStamp: Equatable, Sendable {
    public let placeID: UUID
    public let placeName: String
    public let coordinate: Coordinate
    public let providerPlaceID: String?
    /// Somewhere they have eaten, or somewhere they mean to.
    public let kind: PlaceKind
    /// Rounded to the half star, because the exact mean of a reader's private scores is more
    /// than a friend needs to know. Always nil for a wishlist stamp.
    public let averageRating: Double?
    /// Nil for a wishlist stamp — nobody has been yet, and "0 visits" is a different claim from
    /// "not that kind of place".
    public let visitCount: Int?
    public let latestDish: String?
    public let lastVisitedMonth: YearMonth?
    /// Travels only where the reader opted in for this place (FR-11.4). A note is the most
    /// personal field in the model and is frequently about a third party who agreed to nothing.
    public let note: String?
    public let thumbnailHash: String?
    /// A digest of `canonicalPayload`, so a change that alters nothing shareable costs nothing
    /// to sync (FR-13.3a, TC-9-12).
    public let version: String

    public init(
        placeID: UUID,
        placeName: String,
        coordinate: Coordinate,
        providerPlaceID: String? = nil,
        kind: PlaceKind = .visited,
        averageRating: Double? = nil,
        visitCount: Int? = nil,
        latestDish: String? = nil,
        lastVisitedMonth: YearMonth? = nil,
        note: String? = nil,
        thumbnailHash: String? = nil,
        version: String
    ) {
        self.placeID = placeID
        self.placeName = placeName
        self.coordinate = coordinate
        self.providerPlaceID = providerPlaceID
        self.kind = kind
        self.averageRating = averageRating
        self.visitCount = visitCount
        self.latestDish = latestDish
        self.lastVisitedMonth = lastVisitedMonth
        self.note = note
        self.thumbnailHash = thumbnailHash
        self.version = version
    }

    /// Every shareable field, in a fixed order, as bytes. Hashing this is what gives the version
    /// its property: identical content means an identical version, whatever else changed on the
    /// place it was projected from.
    ///
    /// The unit separator is a control character so that a name ending in one field's text and a
    /// neighbouring field beginning with it cannot produce the same joined string.
    ///
    /// `kind` is in here, and it is not decoration: the same place moving from a friend's wishlist
    /// to their visited list must produce a new version even in the impossible case where nothing
    /// else about it changed, or the move would never sync (FR-13.3a).
    public static func canonicalPayload(
        placeID: UUID,
        placeName: String,
        coordinate: Coordinate,
        providerPlaceID: String?,
        kind: PlaceKind,
        averageRating: Double?,
        visitCount: Int?,
        latestDish: String?,
        lastVisitedMonth: YearMonth?,
        note: String?,
        thumbnailHash: String?
    ) -> Data {
        let fields: [String] = [
            placeID.uuidString,
            placeName,
            String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude),
            providerPlaceID ?? "",
            kind.rawValue,
            averageRating.map { String(format: "%.1f", $0) } ?? "",
            visitCount.map(String.init) ?? "",
            latestDish ?? "",
            lastVisitedMonth?.description ?? "",
            note ?? "",
            thumbnailHash ?? ""
        ]
        return Data(fields.joined(separator: "\u{1F}").utf8)
    }

    public var canonicalPayload: Data {
        Self.canonicalPayload(
            placeID: placeID,
            placeName: placeName,
            coordinate: coordinate,
            providerPlaceID: providerPlaceID,
            kind: kind,
            averageRating: averageRating,
            visitCount: visitCount,
            latestDish: latestDish,
            lastVisitedMonth: lastVisitedMonth,
            note: note,
            thumbnailHash: thumbnailHash
        )
    }
}

/// A stamp that arrived from someone else, with the key of whoever wrote it.
///
/// `receivedAt` is when this device got it, which is **not** what the interface shows. Staleness
/// is reported per friend, from `Friend.lastReachedAt`, because a stamp untouched since June is
/// no less current than one that changed yesterday (TC-10-08).
public struct FriendStamp: Equatable, Sendable {
    public let friend: FriendKey
    public let stamp: SharedStamp
    public let receivedAt: Date

    public init(friend: FriendKey, stamp: SharedStamp, receivedAt: Date) {
        self.friend = friend
        self.stamp = stamp
        self.receivedAt = receivedAt
    }
}
