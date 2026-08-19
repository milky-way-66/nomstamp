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
        app.buttons["useTestPhotoButton"].tapWhenReady()

        app.buttons["Choose the place"].tapWhenReady()
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
}
