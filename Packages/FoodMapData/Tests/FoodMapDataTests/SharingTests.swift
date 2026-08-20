import Testing
import Foundation
import CryptoKit
import ImageIO
@testable import FoodMapData
import FoodMapDomain

/// UC-9 at the transport boundary — what the bytes actually look like once they leave.
@Suite("UC-9 Sharing adapters")
struct SharingTests {

    private func identity(seed: UInt8) throws -> (PeerIdentityStore, InMemoryAgreementKeyDirectory) {
        let directory = InMemoryAgreementKeyDirectory()
        let store = try PeerIdentityStore(
            seedStore: InMemorySeedStore(seed: Data(repeating: seed, count: 32)),
            directory: directory
        )
        return (store, directory)
    }

    /// Two readers who have met: each has recorded the other's agreement key, as the radio leg
    /// does at the table.
    private func connectedPair() throws -> (PeerIdentityStore, PeerIdentityStore) {
        let (lan, lansDirectory) = try identity(seed: 1)
        let (minh, minhsDirectory) = try identity(seed: 2)
        lansDirectory.record(agreementKey: minh.agreementPublicKey, for: minh.publicKey)
        minhsDirectory.record(agreementKey: lan.agreementPublicKey, for: lan.publicKey)
        return (lan, minh)
    }

    // MARK: - TC-9-16 EXIF

    @Test("TC-9-16 a shared thumbnail carries no metadata at all")
    func TC_9_16_exifIsStripped() throws {
        let original = JPEGFactory.make(
            takenAt: Date(timeIntervalSince1970: 1_787_097_600),
            latitude: 21.0181,
            longitude: 105.8554
        )
        // The fixture really does carry what we are about to remove, or the test proves nothing.
        #expect(ShareableThumbnail.carriesIdentifyingMetadata(original))

        let shared = try ShareableThumbnail.redacted(original)

        #expect(!ShareableThumbnail.carriesIdentifyingMetadata(shared))
        let source = try #require(CGImageSourceCreateWithData(shared as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        #expect(ShareableThumbnail.carriesIdentifyingMetadata(shared) == false)
    }

    @Test("TC-9-16 a redacted thumbnail is still a decodable 240 px image")
    func TC_9_16_stillAnImage() throws {
        let original = JPEGFactory.make(width: 1600, height: 1200, latitude: 21.0, longitude: 105.0)

        let shared = try ShareableThumbnail.redacted(original)

        let source = try #require(CGImageSourceCreateWithData(shared as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(max(image.width, image.height) == ShareableThumbnail.side)
        // NFR-8.2: small enough that a whole map is a few megabytes.
        #expect(shared.count < 30_000)
    }

    @Test("TC-9-16 the GPS block cannot survive by being re-inserted under another key")
    func TC_9_16_noResidualBytes() throws {
        let original = JPEGFactory.make(latitude: -33.8688, longitude: 151.2093)

        let shared = try ShareableThumbnail.redacted(original)

        // Belt and braces: the coordinate is not hiding in the file as text either.
        let text = String(decoding: shared, as: UTF8.self)
        #expect(!text.contains("33.8688"))
        #expect(!text.contains("151.2093"))
    }

    // MARK: - TC-9-17 sealing

    @Test("TC-9-17 a recipient can open a stamp and a stranger cannot")
    func TC_9_17_sealedForFriendsOnly() throws {
        let (lan, minh) = try connectedPair()
        let (stranger, _) = try identity(seed: 9)
        let stamp = Data("Phở Thìn · 4.5 · 2026-08".utf8)

        let sealed = try lan.seal(stamp, for: [minh.publicKey])

        #expect(try minh.open(sealed) == stamp)
        #expect(throws: SealingError.notARecipient) { try stranger.open(sealed) }
    }

    @Test("TC-9-17 the record a third party holds reveals no field of the stamp")
    func TC_9_17_ciphertextRevealsNothing() throws {
        let (lan, minh) = try connectedPair()
        let stamp = Data("Bún Chả Hương Liên|4.5|3 visits|2026-08|Phở bò".utf8)

        let sealed = try lan.seal(stamp, for: [minh.publicKey])

        let asText = String(decoding: sealed, as: UTF8.self)
        #expect(!asText.contains("Bún Chả"))
        #expect(!asText.contains("2026-08"))
        #expect(!asText.contains("Phở bò"))
        #expect(sealed.range(of: stamp) == nil)
    }

    @Test("TC-9-17 one content key is wrapped once per friend, not one copy of the stamp each")
    func TC_9_17_wrappingScalesWithFriendsNotBytes() throws {
        let (lan, lansDirectory) = try identity(seed: 1)
        var friends: [FriendKey] = []
        for seed in UInt8(2)...UInt8(9) {
            let (friend, _) = try identity(seed: seed)
            lansDirectory.record(agreementKey: friend.agreementPublicKey, for: friend.publicKey)
            friends.append(friend.publicKey)
        }
        let stamp = Data(repeating: 0xAB, count: 8_000)

        let forOne = try lan.seal(stamp, for: [friends[0]])
        let forEight = try lan.seal(stamp, for: friends)

        // Eight recipients cost eight wrapped keys, not eight ciphertexts.
        #expect(forEight.count - forOne.count < 2_000)
        #expect(forEight.count < stamp.count * 2)
    }

    @Test("TC-9-17 sealing for someone never met is refused rather than silently skipped")
    func TC_9_17_unknownRecipientIsAnError() throws {
        let (lan, _) = try identity(seed: 1)
        let (nobody, _) = try identity(seed: 7)

        #expect(throws: SealingError.unknownRecipient) {
            try lan.seal(Data("x".utf8), for: [nobody.publicKey])
        }
    }

    @Test("TC-9-17 a tampered envelope fails to open rather than opening wrong")
    func TC_9_17_tamperingIsDetected() throws {
        let (lan, minh) = try connectedPair()
        var sealed = try lan.seal(Data("Phở Thìn".utf8), for: [minh.publicKey])

        // Flip a byte in the middle of the encoded envelope.
        sealed[sealed.count / 2] ^= 0xFF

        #expect(throws: (any Error).self) { try minh.open(sealed) }
    }

    // MARK: - identity

    @Test("the identity is stable across launches and unique across devices")
    func identityIsTheAccount() throws {
        let seed = InMemorySeedStore(seed: Data(repeating: 42, count: 32))
        let first = try PeerIdentityStore(seedStore: seed, directory: InMemoryAgreementKeyDirectory())
        let relaunched = try PeerIdentityStore(seedStore: seed, directory: InMemoryAgreementKeyDirectory())
        let (other, _) = try identity(seed: 43)

        #expect(first.publicKey == relaunched.publicKey)
        #expect(first.publicKey != other.publicKey)
        #expect(first.publicKey.bytes.count == FriendKey.byteCount)
    }

    @Test("a first launch generates a seed and keeps it")
    func firstLaunchGeneratesAnIdentity() throws {
        let store = InMemorySeedStore()

        let identity = try PeerIdentityStore(seedStore: store, directory: InMemoryAgreementKeyDirectory())

        #expect(try store.loadSeed() != nil)
        let relaunched = try PeerIdentityStore(seedStore: store, directory: InMemoryAgreementKeyDirectory())
        #expect(identity.publicKey == relaunched.publicKey)
    }

    @Test("the signing and agreement keys are different keys")
    func twoKeypairsFromOneSeed() throws {
        let (lan, _) = try identity(seed: 5)

        #expect(Data(lan.publicKey.bytes) != lan.agreementPublicKey)
    }

    @Test("a stamp signed by its author is verifiable, and a forgery is not")
    func signaturesSurviveACarrier() throws {
        let (lan, _) = try identity(seed: 1)
        let (minh, _) = try identity(seed: 2)
        let stamp = Data("Phở Thìn · 4.5".utf8)

        let signature = try lan.sign(stamp)

        // Anyone can check it, which is what would let a friend carry a bundle onward intact.
        #expect(minh.isSignature(signature, validFor: stamp, from: lan.publicKey))
        #expect(!minh.isSignature(signature, validFor: Data("Phở Thìn · 1.0".utf8), from: lan.publicKey))
        #expect(!minh.isSignature(signature, validFor: stamp, from: minh.publicKey))
    }

    @Test("the digest is stable, and different content digests differently")
    func digestIsAContentHash() {
        let digest = StampDigest()

        #expect(digest.digest(Data("a".utf8)) == digest.digest(Data("a".utf8)))
        #expect(digest.digest(Data("a".utf8)) != digest.digest(Data("b".utf8)))
        #expect(digest.digest(Data()).count == 64)
    }
}

/// The wire format — the one place a stamp becomes bytes, and therefore the place to check that
/// nothing has crept into it that ADR-009's table does not permit.
@Suite("The wire format")
struct WireStampTests {

    private var stamp: SharedStamp {
        SharedStamp(
            placeID: UUID(),
            placeName: "Phở Thìn",
            coordinate: Coordinate(latitude: 21.0181, longitude: 105.8554),
            providerPlaceID: "apple:1234",
            averageRating: 4.5,
            visitCount: 3,
            latestDish: "Phở bò",
            lastVisitedMonth: YearMonth(year: 2026, month: 8),
            note: nil,
            thumbnailHash: "abc123",
            version: "v1"
        )
    }

    /// Every key ADR-009's stamp table permits. A field absent because it is nil is fine; a field
    /// present that is not on this list is the failure this test exists to catch.
    private let permittedKeys: Set<String> = [
        "placeID", "placeName", "latitude", "longitude", "providerPlaceID",
        "averageRating", "visitCount", "latestDish", "lastVisitedMonth", "note",
        "thumbnailHash", "version"
    ]

    @Test("nothing travels that the stamp table does not permit")
    func wireFormatMatchesTheTable() throws {
        let encoded = try JSONEncoder().encode(WireStamp(stamp))
        let keys = Set(try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        ).keys)

        #expect(keys.isSubset(of: permittedKeys), "unexpected: \(keys.subtracting(permittedKeys))")
        // No price, no per-meal ratings, no exact dates, no full-size photograph — not omitted
        // by an encoder's whim, but absent from the type.
        #expect(!keys.contains("price"))
        #expect(!keys.contains("meals"))
        #expect(!keys.contains("eatenAt"))
        #expect(!keys.contains("photos"))
    }

    @Test("an opted-in note travels, and every permitted field can appear")
    func aFullStampUsesTheWholeTable() throws {
        var full = stamp
        full = SharedStamp(
            placeID: full.placeID, placeName: full.placeName, coordinate: full.coordinate,
            providerPlaceID: full.providerPlaceID, averageRating: full.averageRating,
            visitCount: full.visitCount, latestDish: full.latestDish,
            lastVisitedMonth: full.lastVisitedMonth, note: "Lan said the pho is great",
            thumbnailHash: full.thumbnailHash, version: full.version
        )

        let keys = Set(try #require(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(WireStamp(full))) as? [String: Any]
        ).keys)

        #expect(keys == permittedKeys)
    }

    @Test("a stamp survives the round trip unchanged")
    func roundTrip() throws {
        let original = stamp

        let encoded = try JSONEncoder().encode(WireStamp(original))
        let decoded = try #require(JSONDecoder().decode(WireStamp.self, from: encoded).domain)

        #expect(decoded == original)
    }

    @Test("the month travels as a month, and no day can be read out of the bytes")
    func monthStaysCoarse() throws {
        let encoded = try JSONEncoder().encode(WireStamp(stamp))
        let text = String(decoding: encoded, as: UTF8.self)

        #expect(text.contains("\"lastVisitedMonth\":\"2026-08\""))
        // No epoch seconds, no ISO date, nothing a day could be recovered from.
        #expect(!text.contains("T00:00"))
        #expect(!text.contains("1787"))
    }

    @Test("a malformed month is refused rather than guessed at")
    func malformedMonthIsRejected() throws {
        var wire = try JSONDecoder().decode(
            WireStamp.self, from: try JSONEncoder().encode(WireStamp(stamp))
        )
        let broken = """
        {"placeID":"\(wire.placeID.uuidString)","placeName":"x","latitude":0,"longitude":0,
         "visitCount":1,"lastVisitedMonth":"whenever","version":"v1"}
        """
        wire = try JSONDecoder().decode(WireStamp.self, from: Data(broken.utf8))

        #expect(wire.domain == nil)
    }
}
