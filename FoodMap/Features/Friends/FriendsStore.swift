import Foundation
import Observation
import FoodMapDomain
import FoodMapData

/// Everything the friends layer knows, and the only thing that writes it.
///
/// All of it is a **disposable cache**. If it is wrong, delete it and re-sync; no friend data is
/// ever the only copy of anything (FR-13.4). That is why it is a JSON file rather than a
/// SwiftData store: the reader's own map deserves a database, and a copy of someone else's
/// stamps does not.
@Observable
@MainActor
final class FriendsStore {

    private(set) var circle = FriendCircle()
    private(set) var stamps: [FriendStamp] = []
    private(set) var settings = SharingSettings()

    /// Off by default, and the map is exactly what it was before the feature existed while it is
    /// (FR-12.1).
    var layerEnabled = false
    /// Which friends are showing. Nothing hidden means all of them — the row of inks is a filter,
    /// not a requirement to choose. The rules live in the domain because *show only Lan* is one
    /// (FR-12.11).
    var visibility = FriendVisibility()

    /// When the reader last looked at the map, so an arriving stamp can be marked fresh and then
    /// fade (FR-13.1a). Deliberately coarse: it is a feeling, not a read receipt.
    private(set) var lastLookedAt: Date

    private let clock: any ClockPort
    private let buildStamp: BuildSharedStampUseCase
    private let connect: ConnectFriendUseCase
    private let merge = MergeFriendStampsUseCase()
    private let url: URL

    init(clock: any ClockPort, digest: any DigestPort, directory: URL) {
        self.clock = clock
        self.buildStamp = BuildSharedStampUseCase(digest: digest)
        self.connect = ConnectFriendUseCase(clock: clock)
        self.url = directory.appendingPathComponent("friends.json")
        self.lastLookedAt = clock.now
        load()
    }

    // MARK: - The map

    var visibleStamps: [FriendStamp] {
        guard layerEnabled else { return [] }
        return stamps.filter { !visibility.isHidden($0.friend) }
    }

    func groups(for places: [Place]) -> [MapStampGroup] {
        merge.execute(
            places: places,
            friendStamps: visibleStamps,
            circle: circle,
            layerEnabled: layerEnabled
        )
    }

    /// Everyone who has also stamped this place, in ink order — the *also stamped by* row.
    /// Independent of the layer switch, which governs the map and not a page opened on purpose
    /// (FR-12.8).
    func alsoStamped(_ place: Place) -> [FriendStamp] {
        merge.alsoStamped(place, friendStamps: stamps, circle: circle)
    }

    func friend(for key: FriendKey) -> Friend? { circle.friend(for: key) }

    /// How recently this stamp landed, for the fresh-ink decay. Per stamp, unlike the *as of*
    /// date, which belongs to the friend.
    func freshness(of stamp: FriendStamp) -> Double {
        FriendsLayer.freshness(receivedAt: stamp.receivedAt, lastLookedAt: lastLookedAt, now: clock.now)
    }

    /// Countersignatures are the event worth surfacing — *you and Lan have both eaten at Bún Chả
    /// Hương Liên* — rather than a count of new stamps. Same data, and the only version of it a
    /// person would repeat to someone else (ADR-009).
    func countersignedPlaces(among places: [Place]) -> [(place: Place, friends: [FriendStamp])] {
        places.compactMap { place in
            let friends = alsoStamped(place)
            return friends.isEmpty ? nil : (place, friends)
        }
    }

    // MARK: - Connecting

    func connectFriend(key: FriendKey, named name: String, proof: ProximityProof) throws {
        circle = try connect.execute(circle: circle, key: key, assignedName: name, proof: proof)
        save()
    }

    /// Removing deletes their stamps as well as the connection, and frees their ink (FR-10.7).
    func remove(_ key: FriendKey) {
        circle = connect.remove(key, from: circle)
        stamps.removeAll { $0.friend == key }
        visibility.forget(key)
        save()
    }

    // MARK: - Filtering the layer (FR-12.11)

    func isHidden(_ key: FriendKey) -> Bool { visibility.isHidden(key) }

    func toggleHidden(_ key: FriendKey) { visibility.toggle(key) }

    /// True when this friend is the only one drawn, which is what lets one control both isolate
    /// and restore.
    func isIsolated(_ key: FriendKey) -> Bool { visibility.isIsolated(key, within: circle) }

    /// *Show only Lan* — and, when Lan is already the only one, everybody back.
    func toggleIsolation(_ key: FriendKey) {
        if visibility.isIsolated(key, within: circle) {
            visibility.showEveryone()
        } else {
            visibility.isolate(key, within: circle)
        }
    }

    func stampCount(for key: FriendKey) -> Int {
        stamps.filter { $0.friend == key }.count
    }

    // MARK: - Sharing

    func isShared(_ place: Place) -> Bool { settings.shares(place.id) }
    func sharesNote(for place: Place) -> Bool { settings.sharesNote(for: place.id) }

    func setShared(_ shared: Bool, for place: Place) {
        if shared {
            settings.sharedPlaceIDs.insert(place.id)
        } else {
            settings.sharedPlaceIDs.remove(place.id)
            // Unsharing a place also withdraws its note. Leaving the opt-in behind would mean a
            // note quietly travelling again the day the place was re-shared.
            settings.noteOptInPlaceIDs.remove(place.id)
        }
        save()
    }

    func setSharesNote(_ shares: Bool, for place: Place) {
        if shares { settings.noteOptInPlaceIDs.insert(place.id) }
        else { settings.noteOptInPlaceIDs.remove(place.id) }
        save()
    }

    /// The count comes first, always: this is the one action that can move a lot of private
    /// material at once (FR-11.7).
    func bulkSharePlan(_ places: [Place]) -> BulkSharePlan {
        buildStamp.planBulkShare(places: places, settings: settings)
    }

    func applyBulkShare(_ plan: BulkSharePlan) {
        settings.sharedPlaceIDs.formUnion(plan.placeIDs)
        save()
    }

    func outgoingShare(for places: [Place]) -> OutgoingShare {
        buildStamp.outgoingShare(
            places: places,
            settings: settings,
            previouslyShared: publishedPlaceIDs
        )
    }

    // MARK: - Receiving

    func receive(_ incoming: [SharedStamp], from friend: FriendKey) {
        let now = clock.now
        for stamp in incoming {
            stamps.removeAll { $0.friend == friend && $0.stamp.placeID == stamp.placeID }
            stamps.append(FriendStamp(friend: friend, stamp: stamp, receivedAt: now))
        }
        circle.markReached(friend, at: now)
        save()
    }

    func drop(_ placeIDs: [UUID], from friend: FriendKey) {
        stamps.removeAll { $0.friend == friend && placeIDs.contains($0.stamp.placeID) }
        save()
    }

    func localManifest(for friend: FriendKey) -> StampManifest {
        StampManifest(
            stamps.filter { $0.friend == friend }.map {
                ManifestEntry(
                    placeID: $0.stamp.placeID,
                    version: $0.stamp.version,
                    thumbnailHash: $0.stamp.thumbnailHash
                )
            }
        )
    }

    func markLooked() { lastLookedAt = clock.now }

    // MARK: - Persistence

    private var publishedPlaceIDs: Set<UUID> = []

    private func save() {
        let snapshot = Snapshot(
            friends: circle.friends.map(Snapshot.StoredFriend.init),
            stamps: stamps.map(Snapshot.StoredStamp.init),
            shared: Array(settings.sharedPlaceIDs),
            noteOptIn: Array(settings.noteOptInPlaceIDs),
            published: Array(publishedPlaceIDs)
        )
        try? JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return }
        circle = FriendCircle(snapshot.friends.compactMap(\.domain))
        stamps = snapshot.stamps.compactMap(\.domain)
        settings = SharingSettings(
            sharedPlaceIDs: Set(snapshot.shared),
            noteOptInPlaceIDs: Set(snapshot.noteOptIn)
        )
        publishedPlaceIDs = Set(snapshot.published)
    }
}

/// The on-disk shape, kept separate from the domain types so a cache written by an older build
/// is discarded rather than crashing a newer one — it is only a cache.
private struct Snapshot: Codable {
    var friends: [StoredFriend]
    var stamps: [StoredStamp]
    var shared: [UUID]
    var noteOptIn: [UUID]
    var published: [UUID]

    struct StoredFriend: Codable {
        var key: Data
        var name: String
        var inkSlot: Int
        var connectedAt: Date
        var lastReachedAt: Date?

        init(_ friend: Friend) {
            key = Data(friend.key.bytes)
            name = friend.assignedName
            inkSlot = friend.inkSlot
            connectedAt = friend.connectedAt
            lastReachedAt = friend.lastReachedAt
        }

        var domain: Friend? {
            guard let key = FriendKey(bytes: Array(key)) else { return nil }
            return Friend(
                key: key, assignedName: name, inkSlot: inkSlot,
                connectedAt: connectedAt, lastReachedAt: lastReachedAt
            )
        }
    }

    struct StoredStamp: Codable {
        var friend: Data
        var placeID: UUID
        var placeName: String
        var latitude: Double
        var longitude: Double
        var providerPlaceID: String?
        var averageRating: Double?
        var visitCount: Int
        var latestDish: String?
        var month: String
        var note: String?
        var thumbnailHash: String?
        var version: String
        var receivedAt: Date

        init(_ stamp: FriendStamp) {
            friend = Data(stamp.friend.bytes)
            placeID = stamp.stamp.placeID
            placeName = stamp.stamp.placeName
            latitude = stamp.stamp.coordinate.latitude
            longitude = stamp.stamp.coordinate.longitude
            providerPlaceID = stamp.stamp.providerPlaceID
            averageRating = stamp.stamp.averageRating
            visitCount = stamp.stamp.visitCount
            latestDish = stamp.stamp.latestDish
            month = stamp.stamp.lastVisitedMonth.description
            note = stamp.stamp.note
            thumbnailHash = stamp.stamp.thumbnailHash
            version = stamp.stamp.version
            receivedAt = stamp.receivedAt
        }

        var domain: FriendStamp? {
            let parts = month.split(separator: "-")
            guard let key = FriendKey(bytes: Array(friend)),
                  parts.count == 2, let year = Int(parts[0]), let monthNumber = Int(parts[1])
            else { return nil }
            return FriendStamp(
                friend: key,
                stamp: SharedStamp(
                    placeID: placeID,
                    placeName: placeName,
                    coordinate: Coordinate(latitude: latitude, longitude: longitude),
                    providerPlaceID: providerPlaceID,
                    averageRating: averageRating,
                    visitCount: visitCount,
                    latestDish: latestDish,
                    lastVisitedMonth: YearMonth(year: year, month: monthNumber),
                    note: note,
                    thumbnailHash: thumbnailHash,
                    version: version
                ),
                receivedAt: receivedAt
            )
        }
    }
}
