import Testing
import Foundation
@testable import FoodMapDomain

/// UC-8 — Connect a friend.
///
/// The radio is not simulated. What is tested is that a connection cannot be formed without proof
/// of proximity, that the cap holds, and that the name a reader sees is the one the reader wrote.
@Suite("UC-8 Connect a friend")
struct ConnectFriendTests {

    private let clock = FixedClock(now: Fixture.epoch)
    private let inTheRoom = ProximityProof(signalStrength: -40)

    private var sut: ConnectFriendUseCase { ConnectFriendUseCase(clock: clock) }

    @Test("TC-8-01 a ninth friend is refused, and the eight are untouched")
    func TC_8_01_capHolds() throws {
        let full = Fixture.circle(of: 8)

        #expect(throws: CircleRefusal.full) {
            try sut.execute(circle: full, key: Fixture.thuKey, assignedName: "Thu", proof: inTheRoom)
        }
        #expect(full.count == 8)
    }

    @Test("TC-8-02 fullness is a state the interface can ask about before any ceremony")
    func TC_8_02_fullnessIsAState() {
        #expect(Fixture.circle(of: 8).isFull)
        #expect(!Fixture.circle(of: 7).isFull)
    }

    @Test("TC-8-03 an ink slot is derived from the key, identically on every device")
    func TC_8_03_inkIsDerivedFromTheKey() throws {
        let hereFirst = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: inTheRoom
        )
        let elsewhere = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan from work", proof: inTheRoom
        )

        #expect(hereFirst.friend(for: Fixture.lanKey)?.inkSlot
            == elsewhere.friend(for: Fixture.lanKey)?.inkSlot)
        #expect(hereFirst.friend(for: Fixture.lanKey)?.inkSlot
            == FriendCircle.preferredInkSlot(for: Fixture.lanKey))
    }

    @Test("TC-8-04 two keys wanting one ink do not get the same ink")
    func TC_8_04_inkCollisionTakesTheNextFree() throws {
        // 3 and 11 both prefer slot 3 — 11 % 8 == 3.
        #expect(FriendCircle.preferredInkSlot(for: Fixture.lanKey)
            == FriendCircle.preferredInkSlot(for: Fixture.thuKey))

        var circle = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: inTheRoom
        )
        circle = try sut.execute(
            circle: circle, key: Fixture.thuKey, assignedName: "Thu", proof: inTheRoom
        )

        let inks = circle.friends.map(\.inkSlot)
        #expect(Set(inks).count == inks.count)
    }

    @Test("TC-8-04 a full circle still hands every friend a distinct ink")
    func TC_8_04_eightDistinctInks() throws {
        var circle = FriendCircle()
        for byte in stride(from: UInt8(0), through: UInt8(56), by: 8) {
            circle = try sut.execute(
                circle: circle,
                key: Fixture.key(byte, fill: byte),
                assignedName: "Friend \(byte)",
                proof: inTheRoom
            )
        }

        #expect(circle.count == 8)
        #expect(circle.occupiedInkSlots == Set(0..<8))
    }

    @Test("TC-8-05 the name stored is the reader's, never the one the friend asserted")
    func TC_8_05_namesAreAssignedLocally() throws {
        let circle = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan from work", proof: inTheRoom
        )

        #expect(circle.friend(for: Fixture.lanKey)?.assignedName == "Lan from work")
        // There is nowhere for an asserted name to live: `Friend` has one name field and the
        // reader wrote it.
        let fields = Mirror(reflecting: circle.friends[0]).children.compactMap(\.label)
        #expect(!fields.contains("assertedName"))
        #expect(!fields.contains("displayName"))
    }

    @Test("TC-8-06 both phones derive the same word, whichever order the keys arrive in")
    func TC_8_06_verificationWordIsSymmetric() {
        let digest = FNVDigest()

        let onLansPhone = VerificationWord.derive(Fixture.lanKey, Fixture.minhKey, using: digest)
        let onMinhsPhone = VerificationWord.derive(Fixture.minhKey, Fixture.lanKey, using: digest)

        #expect(onLansPhone == onMinhsPhone)
        #expect(onLansPhone.count == VerificationWord.length)
    }

    @Test("TC-8-07 different pairs give different words")
    func TC_8_07_differentPairsDiffer() {
        let digest = FNVDigest()

        let lanAndMinh = VerificationWord.derive(Fixture.lanKey, Fixture.minhKey, using: digest)
        let lanAndThu = VerificationWord.derive(Fixture.lanKey, Fixture.thuKey, using: digest)

        #expect(lanAndMinh != lanAndThu)
    }

    @Test("TC-8-08 a request with no proof of the room cannot be expressed, let alone accepted")
    func TC_8_08_proximityIsRequired() {
        // The proof is a required argument: there is no overload without one, so the compiler
        // refuses a remote connection before any check does. What remains testable is that a
        // proof which fails the floor is refused.
        let acrossTheRestaurant = ProximityProof(signalStrength: -80)

        #expect(throws: CircleRefusal.notInPerson) {
            try sut.execute(
                circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: acrossTheRestaurant
            )
        }
    }

    @Test("TC-8-09 UWB range, where both phones have it, overrules a strong signal")
    func TC_8_09_rangeBeatsSignal() {
        let strongSignalButFarAway = ProximityProof(signalStrength: -30, rangedMetres: 6)

        #expect(throws: CircleRefusal.notInPerson) {
            try sut.execute(
                circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: strongSignalButFarAway
            )
        }
        #expect(ProximityProof(signalStrength: -30, rangedMetres: 0.4).isCloseEnough)
    }

    @Test("TC-8-10 removing frees the ink slot as well as the connection")
    func TC_8_10_removalFreesTheSlot() throws {
        var circle = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: inTheRoom
        )
        let lansInk = try #require(circle.friend(for: Fixture.lanKey)?.inkSlot)

        circle = sut.remove(Fixture.lanKey, from: circle)

        #expect(circle.friend(for: Fixture.lanKey) == nil)
        #expect(!circle.occupiedInkSlots.contains(lansInk))
    }

    @Test("TC-8-11 a friend is reached from the moment they are connected")
    func TC_8_11_firstSyncHappensAtTheTable() throws {
        let circle = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: inTheRoom
        )

        #expect(circle.friend(for: Fixture.lanKey)?.lastReachedAt == Fixture.epoch)
    }

    @Test("connecting the same key twice is refused rather than duplicated")
    func alreadyConnected() throws {
        let circle = try sut.execute(
            circle: FriendCircle(), key: Fixture.lanKey, assignedName: "Lan", proof: inTheRoom
        )

        #expect(throws: CircleRefusal.alreadyConnected) {
            try sut.execute(circle: circle, key: Fixture.lanKey, assignedName: "Lan again", proof: inTheRoom)
        }
    }

    @Test("a fingerprint is short, grouped, and different for different keys")
    func fingerprintReadsAloud() {
        #expect(Fixture.lanKey.fingerprint == "0311 1111 1111 1111")
        #expect(Fixture.lanKey.fingerprint != Fixture.minhKey.fingerprint)
    }

    @Test("a key of the wrong length is refused rather than padded")
    func keyLengthIsChecked() {
        #expect(FriendKey(bytes: [1, 2, 3]) == nil)
        #expect(FriendKey(bytes: Array(repeating: 0, count: 32)) != nil)
    }
}
