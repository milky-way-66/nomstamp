import XCTest

/// Temporary: a screenshot sweep of every screen, light and dark, for a design review.
final class DesignSweep: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func collapseSheet(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
            .press(forDuration: 0.2, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
    }

    /// The seeded list is newest-first, so a named place may be below the fold: search for it.
    private func open(_ name: String, _ query: String, in app: XCUIApplication) {
        let field = app.textFields["placeSearchField"]
        field.tapWhenReady(timeout: 15)
        if let existing = field.value as? String, !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(query)
        app.staticTexts[name].tapWhenReady(timeout: 10)
        _ = app.staticTexts["placeKindLabel"].waitForExistence(timeout: 10)
    }

    /// A drag that started mid-screen panned the map instead of lifting the sheet, so every
    /// "full" shot was really the peek: grab the sheet's own grabber.
    private func raiseSheet(_ app: XCUIApplication, from: CGFloat = 0.84) {
        app.raiseSheet(from: from)
    }

    func test_lightSweep() {
        XCUIDevice.shared.appearance = .light
        let app = AppLauncher.launch(seeded: true)

        shoot(app, "01-map-and-list")
        collapseSheet(app)
        shoot(app, "02-map-at-peek")

        raiseSheet(app)
        shoot(app, "03-list-full")

        // A visited place: heading, meal cards, ratings.
        open("Phở Thìn", "pho thin", in: app)
        raiseSheet(app, from: 0.46)
        shoot(app, "04-place-visited")

        app.swipeUp()
        shoot(app, "05-place-visited-scrolled")
        app.navigationBars.buttons.firstMatch.tap()

        // A wishlist place: the note is the content.
        open("Cà phê Giảng", "giang", in: app)
        raiseSheet(app, from: 0.46)
        shoot(app, "06-place-wishlist")
        app.navigationBars.buttons.firstMatch.tap()

        // Near me.
        collapseSheet(app)
        app.buttons["nearMeButton"].tapWhenReady(timeout: 10)
        shoot(app, "07-near-me")
        if app.buttons["Close"].exists { app.buttons["Close"].tap() } else { app.swipeDown() }

        // Add a meal: camera, rating, confirm.
        collapseSheet(app)
        app.buttons["addMealButton"].tapWhenReady(timeout: 10)
        shoot(app, "08-camera")
        app.buttons["useTestPhotoButton"].tapWhenReady(timeout: 10)
        shoot(app, "09-rating")
        app.buttons["star4"].tapWhenReady(timeout: 10)
        shoot(app, "10-confirm")
    }

    func test_darkAndEmpty() {
        XCUIDevice.shared.appearance = .dark
        let dark = AppLauncher.launch(seeded: true)
        shoot(dark, "11-dark-map-and-list")
        open("Phở Thìn", "pho thin", in: dark)
        raiseSheet(dark)
        shoot(dark, "12-dark-place")
        dark.terminate()

        XCUIDevice.shared.appearance = .light
        let empty = AppLauncher.launch(seeded: false)
        shoot(empty, "13-empty-state")
    }
}
