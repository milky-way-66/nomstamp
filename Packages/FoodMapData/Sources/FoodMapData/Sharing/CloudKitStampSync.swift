import Foundation
import FoodMapDomain
#if canImport(CloudKit)
import CloudKit
#endif

public enum SharingUnavailable: Error, Equatable {
    /// A reader signed out of iCloud. Not an error state: the friends screen explains it and
    /// offers a way forward, and every other screen behaves exactly as before (UC-8/1b).
    case noAccount
    case zoneUnavailable
    case notBuilt
}

/// The record types the shared zone holds. Deliberately few, and deliberately opaque: a stamp is
/// one sealed blob plus the two fields reconciliation needs before anything is opened.
public enum StampRecord {
    public static let type = "Stamp"
    public static let zone = "NomstampFriends"

    /// The place id, so a manifest can be diffed without decrypting anything.
    public static let placeID = "placeID"
    /// The content-hash version, likewise (FR-13.3a).
    public static let version = "version"
    public static let thumbnailHash = "thumbnailHash"
    /// The stamp itself, sealed. CloudKit sees ciphertext and nothing else.
    public static let sealed = "sealed"
    /// The author's signature over the sealed bytes, so a stamp stays verifiable if a friend's
    /// device ever carries it onward (ADR-009's escape hatch, kept open rather than built).
    public static let signature = "signature"
}

/// `StampSyncPort` over a CloudKit shared zone.
///
/// Each reader owns **one custom zone**, shared once with up to eight participants. Adding a
/// friend adds a participant, which maps cleanly onto the cap. Records count against the owner's
/// own iCloud quota — a 500-place map is about 5 MB against a 5 GB free tier — so this costs
/// nobody anything and there is nothing for us to operate (ADR-009).
///
/// Note what is *not* here: retry policy, conflict resolution, merge logic. Friend data is
/// read-only and single-author, so per-place records versioned by their author with
/// last-write-wins is correct, and the diff that decides what to fetch is
/// `ReconcileManifestUseCase` in the domain. This adapter has nothing left to decide.
public final class CloudKitStampSync: StampSyncPort, @unchecked Sendable {

    private let identity: PeerIdentityStore
    private let containerIdentifier: String
    /// Who a published stamp is sealed for, asked at publish time rather than held.
    ///
    /// A closure because the circle changes — a friend added at the table this evening must
    /// receive tomorrow's stamps, and a friend removed must not. Holding a snapshot taken at
    /// construction would seal for yesterday's circle and nobody would notice.
    private let recipients: @Sendable () -> [FriendKey]

    public init(
        identity: PeerIdentityStore,
        containerIdentifier: String,
        recipients: @escaping @Sendable () -> [FriendKey]
    ) {
        self.identity = identity
        self.containerIdentifier = containerIdentifier
        self.recipients = recipients
    }

    #if canImport(CloudKit)
    private var container: CKContainer { CKContainer(identifier: containerIdentifier) }
    private var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: StampRecord.zone) }

    /// Whether the friends feature can run at all. Asked before the screen is shown, so a reader
    /// signed out of iCloud meets an explanation rather than a failure (UC-8/1b, TC-8-13).
    public func accountIsAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    public func remoteManifest(for friend: FriendKey) async throws -> StampManifest {
        try await requireAccount()
        let query = CKQuery(recordType: StampRecord.type, predicate: NSPredicate(value: true))
        let (matches, _) = try await container.sharedCloudDatabase.records(
            matching: query,
            inZoneWith: sharedZoneID(for: friend),
            // Only the three fields a diff needs. The sealed blob stays on the server until the
            // diff says it is wanted, which is what makes a manifest exchange a couple of
            // kilobytes rather than a download.
            desiredKeys: [StampRecord.placeID, StampRecord.version, StampRecord.thumbnailHash]
        )

        let entries: [ManifestEntry] = matches.compactMap { _, result in
            guard let record = try? result.get(),
                  let idString = record[StampRecord.placeID] as? String,
                  let placeID = UUID(uuidString: idString),
                  let version = record[StampRecord.version] as? String
            else { return nil }
            return ManifestEntry(
                placeID: placeID,
                version: version,
                thumbnailHash: record[StampRecord.thumbnailHash] as? String
            )
        }
        return StampManifest(entries)
    }

    public func fetchStamps(_ placeIDs: [UUID], from friend: FriendKey) async throws -> [SharedStamp] {
        try await requireAccount()
        guard !placeIDs.isEmpty else { return [] }

        let query = CKQuery(
            recordType: StampRecord.type,
            predicate: NSPredicate(format: "%K IN %@", StampRecord.placeID, placeIDs.map(\.uuidString))
        )
        let (matches, _) = try await container.sharedCloudDatabase.records(
            matching: query, inZoneWith: sharedZoneID(for: friend)
        )

        return matches.compactMap { _, result in
            guard let record = try? result.get(),
                  let sealed = record[StampRecord.sealed] as? Data,
                  let opened = try? identity.open(sealed),
                  let stamp = try? JSONDecoder().decode(WireStamp.self, from: opened)
            else { return nil }

            // A stamp that does not verify against the key of the friend whose zone it came from
            // is dropped rather than shown. Nothing here is important enough to display on doubt.
            if let signature = record[StampRecord.signature] as? Data,
               !identity.isSignature(signature, validFor: sealed, from: friend) {
                return nil
            }
            return stamp.domain
        }
    }

    public func publish(_ outgoing: OutgoingShare) async throws {
        try await requireAccount()
        // Written to the reader's own private database; the zone is what is shared, so a
        // participant reads it through their shared database without anything being copied.
        let database = container.privateCloudDatabase
        try await ensureZone(in: database)

        let audience = recipients()
        var toSave: [CKRecord] = []
        for stamp in outgoing.stamps {
            let record = CKRecord(
                recordType: StampRecord.type,
                recordID: CKRecord.ID(recordName: stamp.placeID.uuidString, zoneID: zoneID)
            )
            let payload = try JSONEncoder().encode(WireStamp(stamp))
            let sealed = try identity.seal(payload, for: audience)

            record[StampRecord.placeID] = stamp.placeID.uuidString as CKRecordValue
            record[StampRecord.version] = stamp.version as CKRecordValue
            record[StampRecord.thumbnailHash] = stamp.thumbnailHash as CKRecordValue?
            record[StampRecord.sealed] = sealed as CKRecordValue
            record[StampRecord.signature] = try identity.sign(sealed) as CKRecordValue
            toSave.append(record)
        }

        let toDelete = outgoing.retractions.map {
            CKRecord.ID(recordName: $0.uuidString, zoneID: zoneID)
        }
        _ = try await database.modifyRecords(saving: toSave, deleting: toDelete)
    }

    /// The subscription that makes all of this worth doing: a change in the zone fires a silent
    /// push, the receiving device wakes in the background, and the stamp is on the map before the
    /// reader ever opens the app. It is the one wake mechanism iOS grants that does not need the
    /// other person's phone to be awake at the same moment (FR-13.1).
    public func subscribeToChanges() async throws {
        try await requireAccount()
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: StampRecord.zone)
        let notification = CKSubscription.NotificationInfo()
        // Silent: it wakes the application, never the reader. A visible alert would sell an
        // immediacy this design does not promise and turn a slow journal into a feed (FR-13.1a).
        notification.shouldSendContentAvailable = true
        notification.alertBody = nil
        notification.soundName = nil
        subscription.notificationInfo = notification
        _ = try await container.sharedCloudDatabase.save(subscription)
    }

    private func requireAccount() async throws {
        guard await accountIsAvailable() else { throw SharingUnavailable.noAccount }
    }

    private func ensureZone(in database: CKDatabase) async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try? await database.save(zone)
    }

    private func sharedZoneID(for friend: FriendKey) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: StampRecord.zone, ownerName: StampSealing.label(for: friend))
    }

    #else
    public func remoteManifest(for friend: FriendKey) async throws -> StampManifest {
        throw SharingUnavailable.notBuilt
    }
    public func fetchStamps(_ placeIDs: [UUID], from friend: FriendKey) async throws -> [SharedStamp] {
        throw SharingUnavailable.notBuilt
    }
    public func publish(_ outgoing: OutgoingShare) async throws {
        throw SharingUnavailable.notBuilt
    }
    #endif
}

/// The stamp as it travels: a flat, versioned encoding, independent of the domain's Swift types
/// so a later field addition cannot break a friend still running an older build.
///
/// It is also the only place a stamp is turned into bytes, which makes it the natural place to
/// check that nothing has crept into the wire format that ADR-009's table does not permit.
struct WireStamp: Codable, Equatable {
    let placeID: UUID
    let placeName: String
    let latitude: Double
    let longitude: Double
    let providerPlaceID: String?
    let averageRating: Double?
    let visitCount: Int
    let latestDish: String?
    let lastVisitedMonth: String
    let note: String?
    let thumbnailHash: String?
    let version: String

    init(_ stamp: SharedStamp) {
        placeID = stamp.placeID
        placeName = stamp.placeName
        latitude = stamp.coordinate.latitude
        longitude = stamp.coordinate.longitude
        providerPlaceID = stamp.providerPlaceID
        averageRating = stamp.averageRating
        visitCount = stamp.visitCount
        latestDish = stamp.latestDish
        lastVisitedMonth = stamp.lastVisitedMonth.description
        note = stamp.note
        thumbnailHash = stamp.thumbnailHash
        version = stamp.version
    }

    var domain: SharedStamp? {
        let parts = lastVisitedMonth.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return nil }
        return SharedStamp(
            placeID: placeID,
            placeName: placeName,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            providerPlaceID: providerPlaceID,
            averageRating: averageRating,
            visitCount: visitCount,
            latestDish: latestDish,
            lastVisitedMonth: YearMonth(year: year, month: month),
            note: note,
            thumbnailHash: thumbnailHash,
            version: version
        )
    }
}
