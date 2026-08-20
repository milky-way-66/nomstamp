import Foundation

/// Which places the reader has chosen to share, and where they opted a note in as well.
///
/// Nothing is shared by default and nothing is shared as a side effect of any other action
/// (FR-11.1, TC-9-01). An empty settings object therefore produces an empty manifest, which is
/// the state every reader starts in and most readers stay in.
public struct SharingSettings: Equatable, Sendable {
    public var sharedPlaceIDs: Set<UUID>
    public var noteOptInPlaceIDs: Set<UUID>

    public init(sharedPlaceIDs: Set<UUID> = [], noteOptInPlaceIDs: Set<UUID> = []) {
        self.sharedPlaceIDs = sharedPlaceIDs
        self.noteOptInPlaceIDs = noteOptInPlaceIDs
    }

    public func shares(_ placeID: UUID) -> Bool { sharedPlaceIDs.contains(placeID) }
    public func sharesNote(for placeID: UUID) -> Bool { noteOptInPlaceIDs.contains(placeID) }
}

/// What a bulk share would do, stated before it does it.
///
/// The count comes first because "share all my visited places" is the one action in the app that
/// can move a lot of private material at once, and a reader deserves to know how much (FR-11.7,
/// TC-9-15).
public struct BulkSharePlan: Equatable, Sendable {
    public let placeIDs: [UUID]
    public var count: Int { placeIDs.count }

    public init(placeIDs: [UUID]) { self.placeIDs = placeIDs }
}

/// UC-9 — the projection, and the redaction rules.
///
/// This is the file that decides what may leave the device. It lives in the domain, is unit
/// tested on macOS in under five seconds with no simulator and no network, and is why the rule
/// is provable rather than merely intended (NFR-7.2, ADR-009).
public struct BuildSharedStampUseCase: Sendable {
    private let digest: any DigestPort

    public init(digest: any DigestPort) {
        self.digest = digest
    }

    /// Returns nil for a place the reader has not shared, and for one with no visits — a wishlist
    /// place has nothing to say about a meal nobody has eaten.
    public func execute(place: Place, settings: SharingSettings) -> SharedStamp? {
        guard settings.shares(place.id) else { return nil }
        let visits = place.mealsNewestFirst
        guard let latest = visits.first else { return nil }

        // Note the fields that are *not* read: `meal.price`, `meal.rating` individually,
        // `meal.eatenAt` as a date, `photo.coordinate`, `photo.takenAt`, `photo.filename`.
        // The photo's own coordinate in particular is never the stamp's coordinate — that would
        // ship the precise spot a reader stood to take a picture (TC-9-09).
        let month = YearMonth(latest.eatenAt)
        let note = settings.sharesNote(for: place.id) ? place.note : nil
        let thumbnailHash = place.pinPhoto.map { digest.digest(Data($0.thumbnailFilename.utf8)) }

        let payload = SharedStamp.canonicalPayload(
            placeID: place.id,
            placeName: place.name,
            coordinate: place.coordinate,
            providerPlaceID: place.providerPlaceID,
            averageRating: Self.toHalfStar(place.averageRating),
            visitCount: visits.count,
            latestDish: latest.dishName,
            lastVisitedMonth: month,
            note: note,
            thumbnailHash: thumbnailHash
        )

        return SharedStamp(
            placeID: place.id,
            placeName: place.name,
            coordinate: place.coordinate,
            providerPlaceID: place.providerPlaceID,
            averageRating: Self.toHalfStar(place.averageRating),
            visitCount: visits.count,
            latestDish: latest.dishName,
            lastVisitedMonth: month,
            note: note,
            thumbnailHash: thumbnailHash,
            version: digest.digest(payload)
        )
    }

    /// Everything this device currently offers, plus a tombstone for anything it used to.
    ///
    /// `previouslyShared` is what the caller last published, so unsharing produces a retraction
    /// rather than a silence (TC-9-14).
    public func outgoingShare(
        places: [Place],
        settings: SharingSettings,
        previouslyShared: Set<UUID> = []
    ) -> OutgoingShare {
        let stamps = places.compactMap { execute(place: $0, settings: settings) }
        let stillShared = Set(stamps.map(\.placeID))
        let retractions = previouslyShared.subtracting(stillShared).sorted { $0.uuidString < $1.uuidString }
        return OutgoingShare(stamps: stamps, retractions: retractions)
    }

    /// Visited places not already shared — what "share all my visited places" would actually add.
    public func planBulkShare(places: [Place], settings: SharingSettings) -> BulkSharePlan {
        BulkSharePlan(
            placeIDs: places
                .filter { $0.kind == .visited && !settings.shares($0.id) }
                .map(\.id)
        )
    }

    /// To the half star. A friend does not need the exact mean of a reader's private scores.
    static func toHalfStar(_ average: Double?) -> Double? {
        average.map { (($0 * 2).rounded()) / 2 }
    }
}
