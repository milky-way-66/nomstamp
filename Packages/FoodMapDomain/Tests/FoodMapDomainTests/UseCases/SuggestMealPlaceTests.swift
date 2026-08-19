import Testing
import Foundation
@testable import FoodMapDomain

/// TC-1-16 … TC-1-18 — the place the user never has to choose (FR-1.11, FR-1.12).
@Suite("Suggest a place from the coordinate")
struct SuggestMealPlaceTests {

    private func makeUseCase(
        places: [Place] = [],
        nearby: [PlaceCandidate] = [],
        searchError: Error? = nil
    ) -> SuggestMealPlaceUseCase {
        let search = FakePlaceSearch()
        search.nearby = nearby
        search.error = searchError
        return SuggestMealPlaceUseCase(
            places: InMemoryPlaceRepository(places),
            search: search
        )
    }

    /// TC-1-16 — a place already saved wins, so a second meal never doubles the pin.
    @Test("Nearest saved place inside the radius is reused")
    func reusesNearestSavedPlace() async throws {
        // ~40 m north of Phở Thìn, and one place on the far side of the Old Quarter.
        let near = Fixture.place(name: "Phở Thìn", at: Coordinate(latitude: 21.01846, longitude: 105.8554))
        let far = Fixture.place(name: "Cà phê Giảng", at: Fixture.hanoiOldQuarter, createdAt: Fixture.epoch.addingTimeInterval(1))

        let suggestion = await makeUseCase(
            places: [far, near],
            nearby: [PlaceCandidate(id: "c1", name: "Something else", coordinate: Fixture.phoThin)]
        ).execute(around: Fixture.phoThin)

        #expect(suggestion?.target == .existingPlace(near.id))
        #expect(suggestion?.name == "Phở Thìn")
    }

    /// TC-1-17 — otherwise the nearest candidate from the directory, and only if it is close.
    @Test("Nearest candidate inside the radius becomes a new place draft")
    func usesNearestCandidate() async throws {
        let close = PlaceCandidate(
            id: "c1",
            name: "Bún chả Hương Liên",
            address: "24 Lê Văn Hưu",
            coordinate: Fixture.bunChaHuongLien
        )
        let closer = PlaceCandidate(id: "c2", name: "Phở Thìn", coordinate: Fixture.phoThin)

        let suggestion = await makeUseCase(nearby: [close, closer]).execute(around: Fixture.phoThin)

        guard case let .newPlace(draft) = try #require(suggestion?.target) else {
            Issue.record("Expected a new place draft")
            return
        }
        #expect(draft.name == "Phở Thìn")
        #expect(draft.coordinate == Fixture.phoThin)
        #expect(suggestion?.name == "Phở Thìn")
    }

    /// TC-1-17 — a candidate beyond the radius is not a guess worth making.
    @Test("A candidate beyond the radius is never chosen")
    func ignoresDistantCandidates() async {
        let distant = PlaceCandidate(id: "c1", name: "Cà phê Giảng", coordinate: Fixture.hanoiOldQuarter)

        let suggestion = await makeUseCase(nearby: [distant]).execute(around: Fixture.phoThin)

        #expect(suggestion == nil)
    }

    /// TC-1-18 — no coordinate at all (location denied): nothing to suggest, nothing to report.
    @Test("No coordinate yields no suggestion")
    func noCoordinate() async {
        let suggestion = await makeUseCase(
            places: [Fixture.place()],
            nearby: [PlaceCandidate(id: "c1", name: "Phở Thìn", coordinate: Fixture.phoThin)]
        ).execute(around: nil)

        #expect(suggestion == nil)
    }

    /// TC-1-18 — the directory being unreachable must not surface as an error here; the user
    /// still gets the confirm step and can type the name (FR-1.7).
    @Test("A failing place directory is not an error")
    func searchFailureIsSilent() async {
        let suggestion = await makeUseCase(searchError: DomainError.photoStorageFailed)
            .execute(around: Fixture.phoThin)

        #expect(suggestion == nil)
    }

    /// TC-1-18 — a saved place is still suggested when the directory is down.
    @Test("A saved place is suggested even when the directory is down")
    func savedPlaceSurvivesSearchFailure() async {
        let near = Fixture.place(at: Fixture.phoThin)

        let suggestion = await makeUseCase(
            places: [near],
            searchError: DomainError.photoStorageFailed
        ).execute(around: Fixture.phoThin)

        #expect(suggestion?.target == .existingPlace(near.id))
    }
}
