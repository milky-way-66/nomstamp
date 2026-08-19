import XCTest

/// UC-5 — rediscover saved places while travelling.
final class NearMeJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-5-06 (main) — given a seeded city, a place is listed with its distance.
    func test_TC_5_06_nearbyPlacesAreListedWithDistance() {
        let app = AppLauncher.launch(seeded: true)

        app.buttons["nearMeButton"].tapWhenReady()

        XCTAssertTrue(
            app.staticTexts["Phở Thìn"].waitForExistence(timeout: 15),
            "A seeded Hanoi place should be within range of the stubbed Hanoi location"
        )
        // Distances render as "450 m" / "1.2 km" (DistanceFormatter, FR-6.4).
        let distance = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]+([.,][0-9]+)? (m|km)")
        ).firstMatch
        XCTAssertTrue(distance.waitForExistence(timeout: 5), "Each nearby place shows its distance")
    }

    /// TC-5-06 (alternate 2a) — the user has saved places, but none in the city they are in
    /// now: the explicit "nothing saved near here" message is shown rather than a blank list.
    func test_TC_5_06_emptyCityExplainsItself() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-StubLocationFar"])

        app.buttons["nearMeButton"].tapWhenReady()

        XCTAssertTrue(
            app.staticTexts["Nothing saved near here"].waitForExistence(timeout: 15),
            "An empty result must say so explicitly, and never look like a location failure (FR-6.5)"
        )
    }
}
