import XCTest

/// Shared launch helper. Every journey runs against stubbed adapters (`-UITestMode`), so the
/// tests never touch the network, real GPS, the camera or the user's photo library
/// (ADR-002 §5.3). `-SeedDemoData` decides whether the map starts populated.
enum AppLauncher {
    static func launch(
        seeded: Bool,
        extraArguments: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"] + (seeded ? ["-SeedDemoData"] : []) + extraArguments
        app.launch()
        XCTAssertTrue(
            app.buttons["addMealButton"].waitForExistence(timeout: 20),
            "The map never appeared",
            file: file, line: line
        )
        return app
    }
}

extension XCUIElement {
    /// Fails the test with a readable message instead of the default "Failed to tap" noise.
    func tapWhenReady(
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForExistence(timeout: timeout),
            "\(self) never appeared",
            file: file, line: line
        )
        tap()
    }
}

extension XCUIApplication {
    /// Drags the bottom sheet from its peek up to full height.
    ///
    /// The grab has to start on something that is not scrollable: a drag beginning on the list
    /// scrolls the list, and one beginning on the map pans the map. The search field is part of the
    /// sheet's fixed header, so pulling from there always moves the sheet itself.
    ///
    /// - Parameter from: fallback grab point, as a fraction down the screen, for the screens with
    ///   no search field (an empty map, or a place already open).
    func raiseSheet(from: CGFloat = 0.84) {
        let target = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06))
        let field = textFields["placeSearchField"]
        if field.waitForExistence(timeout: 5) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.2, thenDragTo: target)
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
                .press(forDuration: 0.2, thenDragTo: target)
        }
    }
}
