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
