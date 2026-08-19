import XCTest

/// UC-4 — save a place someone told you about.
final class SavePlaceJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-4-09 — given the user searches a name and saves it, then a wishlist pin appears
    /// and its note shows when opened.
    func test_TC_4_09_savedPlaceBecomesAWishlistPinCarryingItsNote() {
        let app = AppLauncher.launch(seeded: false)

        app.buttons["savePlaceButton"].tapWhenReady()

        // The stubbed directory answers with fixed Vietnamese results (AppDependencies.StubPlaceSearch).
        let field = app.searchFields.firstMatch
        field.tapWhenReady()
        field.typeText("bun cha")

        app.staticTexts["Bún chả Hương Liên"].tapWhenReady(timeout: 15)

        let note = app.textViews["placeNoteField"].exists
            ? app.textViews["placeNoteField"]
            : app.textFields["placeNoteField"]
        note.tapWhenReady()
        note.typeText("Lan said try the bún chả")

        app.buttons["savePlaceConfirmButton"].tapWhenReady()

        app.staticTexts["Bún chả Hương Liên"].tapWhenReady(timeout: 10)

        XCTAssertEqual(
            app.staticTexts["placeKindLabel"].label,
            "Want to try",
            "A place saved without a meal is a wishlist place (FR-5.1)"
        )
        // The detail screen sets the note in typographic quotes, so match on containment.
        let savedNote = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Lan said try the bún chả")
        ).firstMatch
        XCTAssertTrue(
            savedNote.waitForExistence(timeout: 5),
            "The note the user typed should survive to the detail screen"
        )
    }
}
