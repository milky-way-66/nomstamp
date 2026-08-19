import Testing
import Foundation
@testable import FoodMapDomain

/// UC-5 — Find saved places near me while travelling.
@Suite("UC-5 Near me")
struct FindPlacesNearbyUseCaseTests {

    /// Roughly 100 m, 2 km and 50 km from the Old Quarter reference point.
    private let hundredMetres = Coordinate(latitude: 21.03420, longitude: 105.85000)
    private let twoKilometres = Coordinate(latitude: 21.05130, longitude: 105.85000)
    private let fiftyKilometres = Coordinate(latitude: 21.48330, longitude: 105.85000)

    @Test("TC-5-01 places within the radius come back nearest first")
    func TC_5_01_sortsByDistance() async throws {
        let repo = InMemoryPlaceRepository([
            Fixture.place(name: "Far", at: twoKilometres),
            Fixture.place(name: "Near", at: hundredMetres)
        ])
        let sut = FindPlacesNearbyUseCase(places: repo, location: FakeLocation(Fixture.hanoiOldQuarter))

        let outcome = try await sut.execute(radius: 5000)

        guard case .located(let results) = outcome else {
            Issue.record("expected located outcome, got \(outcome)")
            return
        }
        #expect(results.map(\.place.name) == ["Near", "Far"])
        #expect(results[0].distance < results[1].distance)
    }

    @Test("TC-5-02 places beyond the radius are excluded")
    func TC_5_02_excludesBeyondRadius() async throws {
        let repo = InMemoryPlaceRepository([
            Fixture.place(name: "Near", at: hundredMetres),
            Fixture.place(name: "Another city", at: fiftyKilometres)
        ])
        let sut = FindPlacesNearbyUseCase(places: repo, location: FakeLocation(Fixture.hanoiOldQuarter))

        let outcome = try await sut.execute(radius: 5000)

        guard case .located(let results) = outcome else {
            Issue.record("expected located outcome")
            return
        }
        #expect(results.map(\.place.name) == ["Near"])
    }

    @Test("TC-5-03 nothing saved nearby is an empty success, not an error")
    func TC_5_03_emptyIsSuccess() async throws {
        let repo = InMemoryPlaceRepository([Fixture.place(name: "Hanoi place", at: Fixture.hanoiOldQuarter)])
        let sut = FindPlacesNearbyUseCase(places: repo, location: FakeLocation(Fixture.hcmcDistrict1))

        let outcome = try await sut.execute(radius: 5000)

        #expect(outcome == .located([]))
    }

    @Test("TC-5-04 an unknown location is reported distinctly from nothing nearby")
    func TC_5_04_locationUnavailableIsDistinct() async throws {
        // The user must never be told "you saved nothing here" when the truth is
        // "I could not work out where you are".
        let repo = InMemoryPlaceRepository([Fixture.place(at: Fixture.hanoiOldQuarter)])
        let sut = FindPlacesNearbyUseCase(places: repo, location: FakeLocation(nil))

        let outcome = try await sut.execute(radius: 5000)

        #expect(outcome == .locationUnavailable)
    }

    @Test("TC-5-05 both visited and wishlist places are returned")
    func TC_5_05_includesBothKinds() async throws {
        let repo = InMemoryPlaceRepository([
            Fixture.place(name: "Wishlist", at: hundredMetres),
            Fixture.place(name: "Visited", at: hundredMetres, meals: [Fixture.meal()])
        ])
        let sut = FindPlacesNearbyUseCase(places: repo, location: FakeLocation(Fixture.hanoiOldQuarter))

        let outcome = try await sut.execute(radius: 5000)

        guard case .located(let results) = outcome else {
            Issue.record("expected located outcome")
            return
        }
        #expect(Set(results.map(\.place.name)) == ["Wishlist", "Visited"])
    }
}
