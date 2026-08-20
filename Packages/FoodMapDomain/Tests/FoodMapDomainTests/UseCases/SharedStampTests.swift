import Testing
import Foundation
@testable import FoodMapDomain

/// UC-9 — Share a place with my friends.
///
/// What may leave the device is decided in the domain, so it can be proved here in milliseconds
/// rather than inferred from a transport adapter nobody reads (ADR-009).
@Suite("UC-9 Share a place")
struct SharedStampTests {

    private let sut = BuildSharedStampUseCase(digest: FNVDigest())

    /// A place carrying every field that must not travel.
    private func richPlace(id: UUID = UUID(), note: String? = "Lan said the pho is great") -> Place {
        Place(
            id: id,
            name: "Phở Thìn",
            coordinate: Fixture.phoThin,
            providerPlaceID: "apple:1234",
            note: note,
            createdAt: Fixture.epoch,
            meals: [
                Fixture.privateMeal(
                    eatenAt: Date(timeIntervalSince1970: 1_755_561_600), // 2025-08-19
                    dishName: "Phở tái",
                    rating: 4
                ),
                Fixture.privateMeal(
                    eatenAt: Date(timeIntervalSince1970: 1_787_097_600), // 2026-08-19
                    dishName: "Phở bò",
                    rating: 5
                )
            ]
        )
    }

    private func shared(_ place: Place, notes: Bool = false) -> SharingSettings {
        SharingSettings(
            sharedPlaceIDs: [place.id],
            noteOptInPlaceIDs: notes ? [place.id] : []
        )
    }

    @Test("TC-9-01 nothing is shared by default, so the outgoing manifest is empty")
    func TC_9_01_nothingSharedByDefault() {
        let places = [richPlace(), richPlace(), richPlace()]

        let outgoing = sut.outgoingShare(places: places, settings: SharingSettings())

        #expect(outgoing.stamps.isEmpty)
        #expect(outgoing.manifest.isEmpty)
        #expect(outgoing.retractions.isEmpty)
    }

    @Test("TC-9-02 a stamp carries exactly the permitted fields and has nowhere to put more")
    func TC_9_02_theStampIsTheWholeContract() throws {
        let place = richPlace()
        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        let fields = Set(Mirror(reflecting: stamp).children.compactMap(\.label))

        #expect(fields == [
            "placeID", "placeName", "coordinate", "providerPlaceID", "averageRating",
            "visitCount", "latestDish", "lastVisitedMonth", "note", "thumbnailHash", "version"
        ])
    }

    @Test("TC-9-03 price and per-meal ratings appear nowhere in a stamp")
    func TC_9_03_priceNeverTravels() throws {
        let place = richPlace()
        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        let rendered = Mirror(reflecting: stamp).children.map { "\($0.value)" }.joined(separator: " ")
        #expect(!rendered.contains("65000"))
        #expect(!rendered.contains("65,000"))
        // The average is a projection of the ratings, not a list of them.
        #expect(stamp.averageRating == 4.5)
        #expect(!rendered.contains("[4, 5]"))
        #expect(String(data: stamp.canonicalPayload, encoding: .utf8)?.contains("65000") == false)
    }

    @Test("TC-9-04 the month travels and the day cannot be recovered")
    func TC_9_04_monthPrecisionOnly() throws {
        let place = richPlace()
        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        #expect(stamp.lastVisitedMonth.description == "2026-08")
        // Structural, not incidental: there is no `Date` anywhere in a stamp, so no future edit
        // can put a day back in.
        let dates = Mirror(reflecting: stamp).children.filter { $0.value is Date }
        #expect(dates.isEmpty)
    }

    @Test("TC-9-05 the average is to the half star, and unrated meals are ignored")
    func TC_9_05_averageToTheHalfStar() throws {
        var place = richPlace()
        place.meals.append(Fixture.privateMeal(eatenAt: Fixture.epoch, rating: nil))

        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        #expect(stamp.averageRating == 4.5)
        #expect(BuildSharedStampUseCase.toHalfStar(4.34) == 4.5)
        #expect(BuildSharedStampUseCase.toHalfStar(4.1) == 4.0)
        #expect(BuildSharedStampUseCase.toHalfStar(nil) == nil)
    }

    @Test("TC-9-06 the visit count is the number of visits, including unrated ones")
    func TC_9_06_visitCount() throws {
        var place = richPlace()
        place.meals.append(Fixture.privateMeal(eatenAt: Fixture.epoch, rating: nil))

        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        #expect(stamp.visitCount == 3)
    }

    @Test("TC-9-07 the dish is the most recent one, not the first")
    func TC_9_07_latestDish() throws {
        let place = richPlace()
        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        #expect(stamp.latestDish == "Phở bò")
    }

    @Test("TC-9-08 the thumbnail is the pin photo and nothing else")
    func TC_9_08_thumbnailIsThePinPhoto() throws {
        let place = richPlace()
        let pinPhoto = try #require(place.pinPhoto)
        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        #expect(stamp.thumbnailHash == FNVDigest().digest(Data(pinPhoto.thumbnailFilename.utf8)))

        let olderPhoto = try #require(place.mealsNewestFirst.last?.photos.first)
        #expect(stamp.thumbnailHash != FNVDigest().digest(Data(olderPhoto.thumbnailFilename.utf8)))
    }

    @Test("TC-9-09 a photograph's own time and coordinate never reach the stamp")
    func TC_9_09_exifNeverTravels() throws {
        let exifCoordinate = Coordinate(latitude: 21.5, longitude: 105.9)
        let exifTime = Date(timeIntervalSince1970: 1_700_000_000)
        var place = richPlace()
        place.meals[1].photos = [
            Photo(
                filename: "a.jpg",
                thumbnailFilename: "a_t.jpg",
                width: 100,
                height: 100,
                takenAt: exifTime,
                coordinate: exifCoordinate
            )
        ]

        let stamp = try #require(sut.execute(place: place, settings: shared(place)))

        // The place's coordinate, never the spot the reader stood to take a picture.
        #expect(stamp.coordinate == Fixture.phoThin)
        #expect(stamp.coordinate != exifCoordinate)
        let rendered = Mirror(reflecting: stamp).children.map { "\($0.value)" }.joined(separator: " ")
        #expect(!rendered.contains("21.5"))
    }

    @Test("TC-9-10 a note travels only where the reader opted in for that place")
    func TC_9_10_notesAreOptIn() throws {
        let place = richPlace()

        let withoutOptIn = try #require(sut.execute(place: place, settings: shared(place)))
        let withOptIn = try #require(sut.execute(place: place, settings: shared(place, notes: true)))

        #expect(withoutOptIn.note == nil)
        #expect(withOptIn.note == "Lan said the pho is great")
        #expect(withoutOptIn.version != withOptIn.version)
    }

    @Test("TC-9-11 a shareable change moves the version")
    func TC_9_11_shareableChangeBumpsVersion() throws {
        let place = richPlace()
        let before = try #require(sut.execute(place: place, settings: shared(place)))

        var visitedAgain = place
        visitedAgain.meals.append(
            Fixture.privateMeal(eatenAt: Date(timeIntervalSince1970: 1_789_689_600), dishName: "Phở gà", rating: 5)
        )
        let after = try #require(sut.execute(place: visitedAgain, settings: shared(place)))

        #expect(before.version != after.version)
        #expect(after.visitCount == 3)
        #expect(after.latestDish == "Phở gà")
    }

    @Test("TC-9-12 an edit that changes nothing shareable costs nothing to sync")
    func TC_9_12_unshareableChangeIsSilent() throws {
        let place = richPlace()
        let before = try #require(sut.execute(place: place, settings: shared(place)))

        var edited = place
        edited.meals[1].price = 999_000                       // never travels
        edited.meals[1].note = "corrected a typo"             // a meal note never travels
        edited.note = "an unshared place note"                // not opted in
        edited.meals[1].photos.append(Fixture.photo())        // not the pin photo
        edited.tags = ["breakfast"]                           // no field on the stamp

        let after = try #require(sut.execute(place: edited, settings: shared(place)))

        #expect(before.version == after.version)
        #expect(before == after)
    }

    @Test("TC-9-13 the projection is rebuilt from the place as it now is")
    func TC_9_13_projectionFollowsThePlace() throws {
        let place = richPlace()
        let settings = shared(place)
        let atShareTime = try #require(sut.execute(place: place, settings: settings))

        var laterVisit = place
        laterVisit.meals[1].rating = 1

        let now = try #require(sut.execute(place: laterVisit, settings: settings))

        #expect(atShareTime.averageRating == 4.5)
        #expect(now.averageRating == 2.5)
        #expect(now.version != atShareTime.version)
    }

    @Test("TC-9-14 unsharing writes a retraction rather than falling silent")
    func TC_9_14_unsharingRetracts() {
        let place = richPlace()

        let outgoing = sut.outgoingShare(
            places: [place],
            settings: SharingSettings(),
            previouslyShared: [place.id]
        )

        #expect(outgoing.stamps.isEmpty)
        #expect(outgoing.retractions == [place.id])
    }

    @Test("TC-9-15 a bulk share states its count before it acts")
    func TC_9_15_bulkShareCountsFirst() {
        let visited = (0..<62).map { _ in richPlace() }
        let wishlist = Fixture.place(name: "Somewhere I heard about", meals: [])
        let alreadyShared = visited[0]

        let plan = sut.planBulkShare(
            places: visited + [wishlist],
            settings: SharingSettings(sharedPlaceIDs: [alreadyShared.id])
        )

        #expect(plan.count == 61)
        #expect(!plan.placeIDs.contains(wishlist.id))
        #expect(!plan.placeIDs.contains(alreadyShared.id))
    }

    @Test("a wishlist place has no stamp — there is no meal to describe")
    func wishlistPlacesAreNotStamps() {
        let wishlist = Fixture.place(meals: [])

        #expect(sut.execute(
            place: wishlist,
            settings: SharingSettings(sharedPlaceIDs: [wishlist.id])
        ) == nil)
    }

    @Test("two places with identical content still have distinct stamps")
    func identityIsPartOfTheContent() throws {
        let one = richPlace()
        var two = richPlace(id: UUID())
        two.meals = one.meals

        let a = try #require(sut.execute(place: one, settings: shared(one)))
        let b = try #require(sut.execute(place: two, settings: shared(two)))

        #expect(a.version != b.version)
    }

    @Test("the canonical payload cannot be confused by a field boundary")
    func canonicalPayloadIsUnambiguous() {
        let id = UUID()
        let month = YearMonth(year: 2026, month: 8)
        let a = SharedStamp.canonicalPayload(
            placeID: id, placeName: "Phở", coordinate: Fixture.phoThin, providerPlaceID: "Thìn",
            averageRating: nil, visitCount: 1, latestDish: nil, lastVisitedMonth: month,
            note: nil, thumbnailHash: nil
        )
        let b = SharedStamp.canonicalPayload(
            placeID: id, placeName: "PhởThìn", coordinate: Fixture.phoThin, providerPlaceID: "",
            averageRating: nil, visitCount: 1, latestDish: nil, lastVisitedMonth: month,
            note: nil, thumbnailHash: nil
        )

        #expect(a != b)
    }
}
