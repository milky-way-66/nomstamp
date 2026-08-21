import Testing
import Foundation
@testable import FoodMapDomain

/// UC-10 — See where my friends have eaten.
///
/// Matching, countersign resolution and the manifest diff. All of it pure, so the hardest part of
/// sync is proved without two phones (ADR-009).
@Suite("UC-10 Friends on the map")
struct FriendsLayerTests {

    private let merge = MergeFriendStampsUseCase()
    private let reconcile = ReconcileManifestUseCase()

    private var myPhoThin: Place {
        Fixture.place(
            name: "Phở Thìn",
            at: Fixture.phoThin,
            providerPlaceID: "apple:1234",
            meals: [Fixture.meal()]
        )
    }

    private var circleOfThree: FriendCircle {
        FriendCircle([
            Fixture.friend(Fixture.lanKey, name: "Lan", inkSlot: 2),
            Fixture.friend(Fixture.minhKey, name: "Minh", inkSlot: 5),
            Fixture.friend(Fixture.thuKey, name: "Thu", inkSlot: 7)
        ])
    }

    @Test("TC-10-01 with the layer off the map is exactly what it was before the feature")
    func TC_10_01_layerOffChangesNothing() {
        let places = [myPhoThin, Fixture.place(name: "Bún Chả", at: Fixture.bunChaHuongLien)]
        let stamps = [Fixture.friendStamp(stamp: Fixture.sharedStamp(name: "Phở Thìn", providerPlaceID: "apple:1234"))]

        let groups = merge.execute(
            places: places, friendStamps: stamps, circle: circleOfThree, layerEnabled: false
        )

        #expect(groups.count == places.count)
        #expect(groups.map(\.ownPlace) == places)
        #expect(groups.allSatisfy { $0.friendStamps.isEmpty })
        #expect(groups.allSatisfy { !$0.isCountersigned })
    }

    @Test("TC-10-02 a shared provider id resolves two local ids to one pin")
    func TC_10_02_matchesOnProviderID() {
        let place = myPhoThin
        // A different name and 400 m away: only the provider id can be doing this.
        let stamp = Fixture.friendStamp(stamp: Fixture.sharedStamp(
            name: "Pho Thin Bo Nhung Dam",
            at: Fixture.offset(Fixture.phoThin, metresNorth: 400),
            providerPlaceID: "apple:1234"
        ))

        let groups = merge.execute(
            places: [place], friendStamps: [stamp], circle: circleOfThree, layerEnabled: true
        )

        #expect(groups.count == 1)
        #expect(groups[0].isCountersigned)
    }

    @Test("TC-10-03 a manual pin matches by name and distance, diacritics or not")
    func TC_10_03_matchesOnNameAndDistance() {
        let manualPin = Fixture.place(name: "Phở Thìn", at: Fixture.phoThin, providerPlaceID: nil)
        let stamp = Fixture.friendStamp(stamp: Fixture.sharedStamp(
            name: "pho thin",
            at: Fixture.offset(Fixture.phoThin, metresNorth: 30),
            providerPlaceID: nil
        ))

        let groups = merge.execute(
            places: [manualPin], friendStamps: [stamp], circle: circleOfThree, layerEnabled: true
        )

        #expect(groups.count == 1)
        #expect(groups[0].isCountersigned)
    }

    @Test("TC-10-04 a stamp matching nothing of mine stands as its own pin")
    func TC_10_04_unmatchedStandsAlone() {
        let stamp = Fixture.friendStamp(stamp: Fixture.sharedStamp(
            name: "Bún Chả Hương Liên", at: Fixture.bunChaHuongLien
        ))

        let groups = merge.execute(
            places: [myPhoThin], friendStamps: [stamp], circle: circleOfThree, layerEnabled: true
        )

        #expect(groups.count == 2)
        let friendOnly = groups.filter { $0.ownPlace == nil }
        #expect(friendOnly.count == 1)
        #expect(friendOnly[0].name == "Bún Chả Hương Liên")
        #expect(!friendOnly[0].isCountersigned)
    }

    @Test("TC-10-05 a place we have both stamped is one pin, drawn as mine")
    func TC_10_05_countersign() throws {
        let stamp = Fixture.friendStamp(stamp: Fixture.sharedStamp(
            name: "Phở Thìn", at: Fixture.phoThin, providerPlaceID: "apple:1234"
        ))

        let mine = myPhoThin
        let groups = merge.execute(
            places: [mine], friendStamps: [stamp], circle: circleOfThree, layerEnabled: true
        )

        #expect(groups.count == 1)
        #expect(groups[0].isCountersigned)
        #expect(groups[0].friendStamps.map(\.friend) == [Fixture.lanKey])

        // ADR-010: the pin itself says nothing about Lan. It is my place, drawn as my place.
        let pins = merge.mapPlaces(
            places: [mine], friendStamps: [stamp], circle: circleOfThree, layerEnabled: true
        )
        #expect(pins.count == 1)
        #expect(pins[0].isMine)
        #expect(pins[0].mine == mine)
    }

    @Test("TC-10-06 five friends on one place is still one pin, and all five reach the detail")
    func TC_10_06_fiveFriendsAreOnePin() {
        let keys = (0..<5).map { Fixture.key(UInt8($0 * 8), fill: UInt8(100 + $0)) }
        let circle = FriendCircle(keys.enumerated().map { index, key in
            Fixture.friend(key, name: "Friend \(index)", inkSlot: index)
        })
        let stamps = keys.map { key in
            Fixture.friendStamp(key, stamp: Fixture.sharedStamp(
                name: "Phở Thìn", at: Fixture.phoThin, providerPlaceID: "apple:1234"
            ))
        }

        let groups = merge.execute(
            places: [myPhoThin], friendStamps: stamps, circle: circle, layerEnabled: true
        )

        #expect(groups.count == 1)
        // ADR-010 dropped the numeral: nothing is summarised away, because nothing is drawn on
        // the pin at all. The detail gets the whole list.
        #expect(groups[0].friendStamps.count == 5)

        let pins = merge.mapPlaces(
            places: [myPhoThin], friendStamps: stamps, circle: circle, layerEnabled: true
        )
        #expect(pins.count == 1)
    }

    @Test("TC-10-07 friends are ordered by lowest ink slot, not by newest arrival")
    func TC_10_07_orderIsStable() throws {
        let base = Fixture.sharedStamp(name: "Phở Thìn", at: Fixture.phoThin, providerPlaceID: "apple:1234")
        let lan = Fixture.friendStamp(Fixture.lanKey, stamp: base, receivedAt: Fixture.epoch)          // ink 2
        let thu = Fixture.friendStamp(Fixture.thuKey, stamp: base, receivedAt: Fixture.epoch.addingTimeInterval(9_999)) // ink 7

        let newestFirst = merge.execute(
            places: [myPhoThin], friendStamps: [thu, lan], circle: circleOfThree, layerEnabled: true
        )
        let oldestFirst = merge.execute(
            places: [myPhoThin], friendStamps: [lan, thu], circle: circleOfThree, layerEnabled: true
        )

        #expect(newestFirst[0].friendStamps.first?.friend == Fixture.lanKey)
        #expect(newestFirst[0].friendStamps.map(\.friend) == oldestFirst[0].friendStamps.map(\.friend))
    }

    @Test("TC-10-25 a friend's wishlist place arrives as a wishlist place")
    func TC_10_25_friendWishlistTravels() throws {
        let stamp = Fixture.friendStamp(stamp: Fixture.wishlistStamp())

        let pins = merge.mapPlaces(
            places: [], friendStamps: [stamp], circle: circleOfThree, layerEnabled: true
        )

        let pin = try #require(pins.first)
        #expect(pins.count == 1)
        #expect(pin.kind == .wishlist)
        #expect(pin.name == "Chả Cá Thăng Long")
        #expect(!pin.isMine)
        // Nothing is invented to fill the gap where a visit would be.
        #expect(pin.averageRating == nil)
        #expect(pin.pinPhoto == nil)
    }

    @Test("TC-10-25 one friend who has been outranks one who only means to go")
    func TC_10_25_visitedWinsOverWishlist() throws {
        let coordinate = Fixture.hanoiOldQuarter
        let wants = Fixture.friendStamp(Fixture.lanKey, stamp: Fixture.wishlistStamp(
            name: "Chả Cá Thăng Long", at: coordinate, providerPlaceID: "apple:777"
        ))
        let went = Fixture.friendStamp(Fixture.minhKey, stamp: Fixture.sharedStamp(
            name: "Chả Cá Thăng Long", at: coordinate, providerPlaceID: "apple:777"
        ))

        let pins = merge.mapPlaces(
            places: [], friendStamps: [wants, went], circle: circleOfThree, layerEnabled: true
        )

        #expect(pins.count == 1)
        #expect(try #require(pins.first).kind == .visited)
    }

    @Test("TC-10-24 a friend's pin and my own are the same kind of thing")
    func TC_10_24_pinsAreIndistinguishable() throws {
        let elsewhere = Fixture.friendStamp(stamp: Fixture.sharedStamp(
            name: "Bún Chả Hương Liên", at: Fixture.bunChaHuongLien, providerPlaceID: "apple:9999"
        ))

        let pins = merge.mapPlaces(
            places: [myPhoThin], friendStamps: [elsewhere], circle: circleOfThree, layerEnabled: true
        )

        #expect(pins.count == 2)
        // The drawing takes name, coordinate, kind, rating and photo — and takes them through the
        // same properties for both. There is no branch a renderer could take on provenance
        // without reaching for `origin`, which nothing but the tap handler does.
        #expect(pins.allSatisfy { !$0.name.isEmpty })
        #expect(Set(pins.map(\.kind)) == [.visited])
    }

    @Test("TC-10-26 the kind filter cuts friends' places and the reader's own alike")
    func TC_10_26_kindFilterAppliesToBoth() {
        var myWishlist = Fixture.place(name: "Bánh Mì 25", at: Fixture.hcmcDistrict1)
        myWishlist.meals = []
        let friendWants = Fixture.friendStamp(Fixture.minhKey, stamp: Fixture.wishlistStamp())
        let friendWent = Fixture.friendStamp(Fixture.lanKey, stamp: Fixture.sharedStamp(
            name: "Bún Chả Hương Liên", at: Fixture.bunChaHuongLien, providerPlaceID: "apple:9999"
        ))

        let pins = merge.mapPlaces(
            places: [myPhoThin, myWishlist],
            friendStamps: [friendWants, friendWent],
            circle: circleOfThree,
            layerEnabled: true
        )

        #expect(pins.count == 4)
        #expect(pins.filter(MapFilter.all.matches).count == 4)
        #expect(Set(pins.filter(MapFilter.visited.matches).map(\.name))
            == ["Phở Thìn", "Bún Chả Hương Liên"])
        #expect(Set(pins.filter(MapFilter.wishlist.matches).map(\.name))
            == ["Bánh Mì 25", "Chả Cá Thăng Long"])
    }

    @Test("TC-10-16 a place's own page names every friend who stamped it, layer or no layer")
    func TC_10_16_alsoStampedIsIndependentOfTheLayer() {
        let base = Fixture.sharedStamp(name: "Phở Thìn", at: Fixture.phoThin, providerPlaceID: "apple:1234")
        let thu = Fixture.friendStamp(Fixture.thuKey, stamp: base)   // ink 7
        let lan = Fixture.friendStamp(Fixture.lanKey, stamp: base)   // ink 2
        let elsewhere = Fixture.friendStamp(Fixture.minhKey, stamp: Fixture.sharedStamp(
            name: "Bún Chả Hương Liên", at: Fixture.bunChaHuongLien, providerPlaceID: "apple:9999"
        ))

        let named = merge.alsoStamped(
            myPhoThin, friendStamps: [thu, lan, elsewhere], circle: circleOfThree
        )

        // Ink order, not arrival order — and Minh, who ate somewhere else, is not on this page.
        #expect(named.map(\.friend) == [Fixture.lanKey, Fixture.thuKey])
    }

    @Test("TC-10-08 staleness belongs to the friend, and is the same for every stamp of theirs")
    func TC_10_08_stalenessIsPerFriend() throws {
        let twelfthOfAugust = Date(timeIntervalSince1970: 1_786_492_800)
        let circle = FriendCircle([
            Fixture.friend(Fixture.lanKey, name: "Lan", inkSlot: 2, lastReachedAt: twelfthOfAugust)
        ])
        // Two stamps of Lan's that reached this device at very different moments.
        let june = Fixture.friendStamp(Fixture.lanKey, receivedAt: Fixture.epoch)
        let recent = Fixture.friendStamp(Fixture.lanKey, receivedAt: twelfthOfAugust)

        let asOf = FriendsLayer.asOf(Fixture.lanKey, in: circle)

        #expect(asOf == twelfthOfAugust)
        // The date is a property of the friend; neither stamp carries one of its own to show.
        #expect(june.receivedAt != recent.receivedAt)
        #expect(FriendsLayer.asOf(june.friend, in: circle) == FriendsLayer.asOf(recent.friend, in: circle))
    }

    @Test("TC-10-09 a new stamp arrives freshly pressed and fades to ordinary")
    func TC_10_09_freshInkDecays() {
        let lastLooked = Fixture.epoch
        let arrived = lastLooked.addingTimeInterval(60)

        let justNow = FriendsLayer.freshness(receivedAt: arrived, lastLookedAt: lastLooked, now: arrived)
        let halfway = FriendsLayer.freshness(
            receivedAt: arrived, lastLookedAt: lastLooked,
            now: arrived.addingTimeInterval(FriendsLayer.freshDuration / 2)
        )
        let faded = FriendsLayer.freshness(
            receivedAt: arrived, lastLookedAt: lastLooked,
            now: arrived.addingTimeInterval(FriendsLayer.freshDuration * 2)
        )
        let alreadySeen = FriendsLayer.freshness(
            receivedAt: lastLooked.addingTimeInterval(-60), lastLookedAt: lastLooked, now: arrived
        )

        #expect(justNow == 1)
        #expect(abs(halfway - 0.5) < 0.001)
        #expect(faded == 0)
        #expect(alreadySeen == 0)
    }

    @Test("TC-10-10 a friend who cannot be reached keeps their stamps and raises nothing")
    func TC_10_10_unreachableIsNotAnError() {
        let longAgo = Fixture.epoch
        let circle = FriendCircle([
            Fixture.friend(Fixture.lanKey, name: "Lan", inkSlot: 2, lastReachedAt: longAgo)
        ])
        let stamp = Fixture.friendStamp(Fixture.lanKey, stamp: Fixture.sharedStamp(
            name: "Phở Thìn", at: Fixture.phoThin, providerPlaceID: "apple:1234"
        ))

        let groups = merge.execute(
            places: [myPhoThin], friendStamps: [stamp], circle: circle, layerEnabled: true
        )

        #expect(groups[0].isCountersigned)
        #expect(FriendsLayer.asOf(Fixture.lanKey, in: circle) == longAgo)
    }

    @Test("TC-10-11 only entries whose version differs are requested")
    func TC_10_11_diffRequestsOnlyChanges() {
        let unchanged = UUID(), changed = UUID(), brandNew = UUID()
        let remote = StampManifest([
            ManifestEntry(placeID: unchanged, version: "v1"),
            ManifestEntry(placeID: changed, version: "v2"),
            ManifestEntry(placeID: brandNew, version: "v1")
        ])
        let local = StampManifest([
            ManifestEntry(placeID: unchanged, version: "v1"),
            ManifestEntry(placeID: changed, version: "v1")
        ])

        let diff = reconcile.execute(remote: remote, local: local)

        #expect(diff.needed == [changed, brandNew])
        #expect(diff.retracted.isEmpty)
    }

    @Test("TC-10-12 an entry gone from the remote manifest is dropped here")
    func TC_10_12_retractionTakesEffect() {
        let kept = UUID(), retracted = UUID()
        let remote = StampManifest([ManifestEntry(placeID: kept, version: "v1")])
        let local = StampManifest([
            ManifestEntry(placeID: kept, version: "v1"),
            ManifestEntry(placeID: retracted, version: "v1")
        ])

        let diff = reconcile.execute(remote: remote, local: local)

        #expect(diff.retracted == [retracted])
        #expect(diff.needed.isEmpty)
    }

    @Test("TC-10-13 a thumbnail already held is never fetched again, for anyone")
    func TC_10_13_contentAddressingDeduplicates() {
        let a = UUID(), b = UUID(), c = UUID()
        let remote = StampManifest([
            ManifestEntry(placeID: a, version: "v1", thumbnailHash: "already-held"),
            ManifestEntry(placeID: b, version: "v1", thumbnailHash: "new"),
            // A different place, the same photograph — one fetch, not two.
            ManifestEntry(placeID: c, version: "v1", thumbnailHash: "new")
        ])

        let diff = reconcile.execute(
            remote: remote, local: StampManifest(), heldThumbnailHashes: ["already-held"]
        )

        #expect(diff.needed.count == 3)
        #expect(diff.thumbnailsNeeded == ["new"])
    }

    @Test("TC-10-14 with no friend data at all the map is still the reader's own map")
    func TC_10_14_theFeatureIsOptional() {
        let places = [myPhoThin, Fixture.place(name: "Bún Chả", at: Fixture.bunChaHuongLien)]

        let groups = merge.execute(
            places: places, friendStamps: [], circle: FriendCircle(), layerEnabled: true
        )

        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.friendStamps.isEmpty })
    }

    @Test("two friends who both stamped a place I have not make one pin, not two")
    func friendOnlyPinsCoalesce() {
        let stamp = Fixture.sharedStamp(name: "Bún Chả Hương Liên", at: Fixture.bunChaHuongLien)
        let stamps = [
            Fixture.friendStamp(Fixture.lanKey, stamp: stamp),
            Fixture.friendStamp(Fixture.minhKey, stamp: stamp)
        ]

        let groups = merge.execute(
            places: [], friendStamps: stamps, circle: circleOfThree, layerEnabled: true
        )

        #expect(groups.count == 1)
        #expect(groups[0].friendStamps.count == 2)
    }

    @Test("an identical manifest asks for nothing")
    func nothingToDo() {
        let id = UUID()
        let manifest = StampManifest([ManifestEntry(placeID: id, version: "v1", thumbnailHash: "h")])

        let diff = reconcile.execute(remote: manifest, local: manifest, heldThumbnailHashes: ["h"])

        #expect(diff.isEmpty)
    }
}
