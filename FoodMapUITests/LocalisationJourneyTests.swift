import XCTest

/// NFR-5.1 / NFR-5.2 — the interface follows the device language, and Vietnamese is a
/// first-class one because it is the target market (ADR-003).
final class LocalisationJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-N-01 — given the device language is Vietnamese, when the app launches, then the
    /// interface is Vietnamese rather than English.
    func test_TC_N_01_interfaceFollowsVietnameseDeviceLanguage() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(vi)",
            "-AppleLocale", "vi_VN",
            "-UITestMode", "-SeedDemoData",
        ]
        app.launch()

        // Buttons the map screen always shows, translated.
        XCTAssertTrue(
            app.buttons["Lưu địa điểm"].waitForExistence(timeout: 20),
            "\"Save a place\" should read \"Lưu địa điểm\" on a Vietnamese device"
        )
        XCTAssertTrue(app.buttons["Thêm bữa"].exists, "\"Add meal\" should be translated")

        // The filter control, and the wishlist/visited wording used on every row.
        // The filter sits on the map behind the sheet, so it needs its own wait.
        XCTAssertTrue(
            app.segmentedControls.buttons["Tất cả"].waitForExistence(timeout: 10),
            "The \"All\" filter should be translated"
        )
        XCTAssertTrue(
            app.staticTexts["Muốn thử"].firstMatch.exists || app.staticTexts["Đã đến"].firstMatch.exists,
            "Place rows should say \"Muốn thử\" / \"Đã đến\", not \"Want to try\" / \"Been here\""
        )

        // And nothing English is left on the first screen.
        XCTAssertFalse(app.buttons["Save a place"].exists)
        XCTAssertFalse(app.buttons["Add meal"].exists)
    }

    /// TC-N-01 (English half) — the same screen in English, so the test proves the language is
    /// followed rather than that Vietnamese is hard-coded.
    func test_englishDeviceStillGetsEnglish() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-SeedDemoData", "-AppleLanguages", "(en)"]
        app.launch()

        XCTAssertTrue(app.buttons["Save a place"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["Lưu địa điểm"].exists)
        XCTAssertTrue(
            app.staticTexts["Cà phê Giảng"].waitForExistence(timeout: 10),
            "The seeded places should be listed in either language"
        )
    }
}
