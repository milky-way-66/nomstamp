import XCTest

/// UC-1 — photograph the food and store it.
final class LogMealJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-1-14 — given an empty app, when the user adds a meal from the fixture photo,
    /// then a pin appears on the map.
    func test_TC_1_14_loggingAMealPutsItOnTheMap() {
        let app = AppLauncher.launch(seeded: false)

        XCTAssertTrue(
            app.staticTexts["Your food map is empty"].exists,
            "A fresh install should show the empty state"
        )

        app.buttons["addMealButton"].tapWhenReady()
        // Step 1 is the camera itself; the simulator has none, so the library/test path stands
        // in for the shutter (FR-1.10).
        app.buttons["useTestPhotoButton"].tapWhenReady()
        app.buttons["skipRatingButton"].tapWhenReady()

        // The app guessed a place from the stub fix; this journey overrides it by hand.
        app.buttons["placeRow"].tapWhenReady()
        let name = app.textFields["manualPlaceNameField"]
        name.tapWhenReady()
        name.typeText("Phở Thìn")
        app.buttons["useMySpotButton"].tapWhenReady()

        app.buttons["saveMealButton"].tapWhenReady()

        // The place now exists, so the empty state is gone and the meal is findable.
        XCTAssertTrue(
            app.staticTexts["Phở Thìn"].waitForExistence(timeout: 10),
            "The logged meal's place should appear in the sheet"
        )
        XCTAssertFalse(app.staticTexts["Your food map is empty"].exists)
    }

    /// TC-1-19 — the whole point of the rework: `+`, a photo, one star, Save. The place is
    /// never chosen by hand (FR-1.10, FR-1.11).
    func test_TC_1_19_cameraFirstFlowNeedsOnlyAPhotoAndAStar() {
        let app = AppLauncher.launch(seeded: false)

        app.buttons["addMealButton"].tapWhenReady()
        app.buttons["useTestPhotoButton"].tapWhenReady()

        // The rating step is next, not a form.
        app.buttons["star4"].tapWhenReady()

        // The confirm step already names the place the stub provider put under the user.
        XCTAssertTrue(
            app.staticTexts["Cà phê Giảng"].waitForExistence(timeout: 10),
            "The place should be preselected from the coordinate"
        )

        app.buttons["saveMealButton"].tapWhenReady()

        XCTAssertTrue(
            app.staticTexts["Cà phê Giảng"].waitForExistence(timeout: 10),
            "The meal's place should appear on the map"
        )
        XCTAssertFalse(app.staticTexts["Your food map is empty"].exists)
    }

    /// TC-7-06 — scoring a meal already logged, from the place screen, with no edit screen.
    func test_TC_7_06_ratingALoggedMealFromThePlaceScreen() {
        let app = AppLauncher.launch(seeded: true)

        // The sheet lists newest-first, so Phở Thìn is below the fold; search brings it up.
        let field = app.textFields["placeSearchField"]
        field.tapWhenReady(timeout: 15)
        field.typeText("pho thin")
        app.staticTexts["Phở Thìn"].tapWhenReady(timeout: 10)

        let stars = app.descendants(matching: .any).matching(identifier: "starRating")
        XCTAssertTrue(stars.firstMatch.waitForExistence(timeout: 10), "The meal card should carry stars")

        app.buttons["star5"].firstMatch.tapWhenReady()
        XCTAssertTrue(
            app.buttons["star5"].firstMatch.waitForExistence(timeout: 5),
            "Rating happens in place — the screen must not be replaced"
        )

        // Tapping the same star again clears the score (UC-7 / 1b), still without leaving.
        app.buttons["star5"].firstMatch.tap()
        XCTAssertTrue(app.buttons["star1"].firstMatch.exists)
    }
}
