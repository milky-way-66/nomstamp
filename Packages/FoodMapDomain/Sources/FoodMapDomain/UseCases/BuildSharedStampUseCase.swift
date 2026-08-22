import Foundation

/// The fields a reader may still keep private when place projections are shared automatically.
///
/// Place identity and the coarsened stamp projection are shared for every saved place after a
/// friend is connected. Notes remain a separate opt-in because they are personal writing.
public struct SharingSettings: Equatable, Sendable {
    public var noteOptInPlaceIDs: Set<UUID>

    public init(noteOptInPlaceIDs: Set<UUID> = []) {
        self.noteOptInPlaceIDs = noteOptInPlaceIDs
    }

    public func sharesNote(for placeID: UUID) -> Bool { noteOptInPlaceIDs.contains(placeID) }
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

    /// Projects every saved place into the fields permitted to leave the device.
    ///
    /// ADR-010: a wishlist place travels too. It carries strictly less than a visited one — no
    /// rating, no count, no dish, no month, because none of those exist for somewhere nobody has
    /// been — so the branch here is not a special case bolted on, it is the same projection with
    /// the visit half absent.
    public func execute(place: Place, settings: SharingSettings) -> SharedStamp? {
        let visits = place.mealsNewestFirst
        let latest = visits.first

        // Note the fields that are *not* read: `meal.price`, `meal.rating` individually,
        // `meal.eatenAt` as a date, `photo.coordinate`, `photo.takenAt`, `photo.filename`.
        // The photo's own coordinate in particular is never the stamp's coordinate — that would
        // ship the precise spot a reader stood to take a picture (TC-9-09).
        let month = latest.map { YearMonth($0.eatenAt) }
        let note = settings.sharesNote(for: place.id) ? place.note : nil
        let thumbnailHash = place.pinPhoto.map { digest.digest(Data($0.thumbnailFilename.utf8)) }
        let rating = Self.toHalfStar(place.averageRating)
        let count = latest == nil ? nil : visits.count

        let payload = SharedStamp.canonicalPayload(
            placeID: place.id,
            placeName: place.name,
            coordinate: place.coordinate,
            providerPlaceID: place.providerPlaceID,
            kind: place.kind,
            averageRating: rating,
            visitCount: count,
            latestDish: latest?.dishName,
            lastVisitedMonth: month,
            note: note,
            thumbnailHash: thumbnailHash
        )

        return SharedStamp(
            placeID: place.id,
            placeName: place.name,
            coordinate: place.coordinate,
            providerPlaceID: place.providerPlaceID,
            kind: place.kind,
            averageRating: rating,
            visitCount: count,
            latestDish: latest?.dishName,
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

    /// To the half star. A friend does not need the exact mean of a reader's private scores.
    static func toHalfStar(_ average: Double?) -> Double? {
        average.map { (($0 * 2).rounded()) / 2 }
    }
}
