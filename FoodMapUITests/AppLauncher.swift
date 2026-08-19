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
    /// The grab has to start on the sheet's own grabber — a drag that starts on the map pans the
    /// map, and one that starts inside the list scrolls the list. At the peek detent the grabber
    /// sits just below the sheet's top edge, a little above the bottom sixth of the screen.
    /// - Parameter from: where the grabber is, as a fraction down the screen. The default is the
    ///   peek detent; a sheet already at its reading detent has its grabber around 0.46.
    func raiseSheet(from: CGFloat = 0.84) {
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
            .press(forDuration: 0.2, thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)))
    }
}
