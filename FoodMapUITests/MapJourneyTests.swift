import XCTest

/// UC-2 — see the food on the map.
final class MapJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-2-10 — given no places, when the map opens, then the empty state and its two
    /// actions are shown (UC-2 alternate flow 1a).
    func test_TC_2_10_emptyMapOffersBothWaysIn() {
        let app = AppLauncher.launch(seeded: false)

        XCTAssertTrue(app.staticTexts["Your food map is empty"].exists)
        XCTAssertTrue(app.buttons["addMealButton"].exists, "The empty map must offer logging a meal")
        XCTAssertTrue(app.buttons["savePlaceButton"].exists, "The empty map must offer saving a place")
    }

    /// TC-2-10 (seeded half) — a populated map lists the saved places, and searching narrows
    /// them without diacritics being typed.
    func test_seededMapListsPlacesAndSearchIgnoresDiacritics() {
        let app = AppLauncher.launch(seeded: true)

        // The sheet lists the most recent first, so this is the row on screen at rest.
        XCTAssertTrue(
            app.staticTexts["Cà phê Giảng"].waitForExistence(timeout: 10),
            "A seeded map should list its places"
        )

        let field = app.textFields["placeSearchField"]
        field.tapWhenReady()
        field.typeText("pho thin")

        XCTAssertTrue(
            app.staticTexts["Phở Thìn"].waitForExistence(timeout: 5),
            "Unaccented typing should still match the accented name (FR-3.4)"
        )
        XCTAssertFalse(
            app.staticTexts["Cà phê Giảng"].exists,
            "Non-matching places should be filtered out"
        )
    }

    /// TC-3-07 — opening a place moves the map to its pin and stays beside it (FR-4.6).
    func test_TC_3_07_openingAPlaceKeepsTheMapInView() {
        let app = AppLauncher.launch(seeded: true)

        app.staticTexts["Cà phê Giảng"].tapWhenReady(timeout: 15)

        // The place is open...
        XCTAssertTrue(
            app.staticTexts["placeKindLabel"].waitForExistence(timeout: 10),
            "The place should be open"
        )
        // ...and the map is still on screen behind it, which is the point: the pin the map just
        // centred on has to be visible. The map's own actions are the proof — they float on it.
        XCTAssertTrue(
            app.buttons["addMealButton"].exists,
            "The sheet must not cover the map when a place is open"
        )

        // Going back returns the sheet to its peek, where the search field is the header.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(
            app.textFields["placeSearchField"].waitForExistence(timeout: 10),
            "Going back should return to the list at its peek"
        )
    }

    /// TC-2-11 — a pin is a way in, not decoration (FR-3.10).
    func test_TC_2_11_tappingAPinOpensThePlace() {
        let app = AppLauncher.launch(seeded: true)

        // The simulator sits in San Francisco while the seeded places are in Hanoi, so the map
        // is first moved to a place — opening one does that (FR-4.6) — and then dismissed,
        // which leaves its pin on screen to tap.
        let field = app.textFields["placeSearchField"]
        field.tapWhenReady(timeout: 15)
        field.typeText("pho thin")
        app.staticTexts["Phở Thìn"].tapWhenReady(timeout: 10)
        XCTAssertTrue(app.staticTexts["placeKindLabel"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        // Searching left the sheet raised with the keyboard up, which covers the pin: drag the
        // sheet back to its peek so the map is on screen, the way a reader would.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
            .press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))

        // The pin carries the place's name in its accessibility label (TC-N-11).
        let pin = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Phở Thìn,"))
            .firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10), "The focused place's pin should be on screen")
        pin.tap()

        XCTAssertTrue(
            app.staticTexts["placeKindLabel"].waitForExistence(timeout: 10),
            "Tapping the pin should open the place"
        )
        XCTAssertEqual(app.staticTexts["placeKindLabel"].label, "Been here")
    }
}
