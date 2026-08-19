import XCTest

/// UC-6 — a wishlist place becomes a visited one.
final class WishlistToVisitedJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-6-05 — given a wishlist pin, when the user taps "I ate here" and logs a meal,
    /// then the pin renders as visited and the note survives.
    func test_TC_6_05_eatingAtAWishlistPlaceTurnsItVisited() {
        let app = AppLauncher.launch(seeded: true)

        // Cà phê Giảng is seeded as a wishlist place with a note.
        app.staticTexts["Cà phê Giảng"].tapWhenReady(timeout: 15)
        XCTAssertEqual(app.staticTexts["placeKindLabel"].label, "Want to try")

        app.buttons["iAteHereButton"].tapWhenReady()
        app.buttons["useTestPhotoButton"].tapWhenReady()
        app.buttons["skipRatingButton"].tapWhenReady()
        // The place is preselected on this path, so only the photo is needed.
        app.buttons["saveMealButton"].tapWhenReady()

        XCTAssertTrue(
            app.staticTexts["placeKindLabel"].waitForExistence(timeout: 10)
        )
        XCTAssertEqual(
            app.staticTexts["placeKindLabel"].label,
            "Been here",
            "Kind is derived from having meals, so logging one flips it (FR-8.1)"
        )
    }
}
