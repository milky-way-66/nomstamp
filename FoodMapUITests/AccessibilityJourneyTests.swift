import XCTest

/// NFR-6 — the app has to stay usable at accessibility text sizes and under VoiceOver.
final class AccessibilityJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-N-10 — given the largest accessibility text size, when the map opens, then the
    /// primary actions are still present and hittable rather than pushed off screen.
    func test_TC_N_10_primaryActionsSurviveTheLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-SeedDemoData"]
        // The five accessibility sizes above the standard range (NFR-6.1).
        app.launchEnvironment["UIPreferredContentSizeCategoryName"] =
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        app.launch()

        for identifier in ["savePlaceButton", "addMealButton", "nearMeButton"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(
                button.waitForExistence(timeout: 20),
                "\(identifier) disappeared at the largest text size"
            )
            XCTAssertTrue(
                button.isHittable,
                "\(identifier) exists but cannot be tapped at the largest text size"
            )
        }
    }

    /// TC-N-11 — given the map screen, then every control carries a VoiceOver label rather
    /// than falling back to an SF Symbol name.
    func test_TC_N_11_everyControlHasAVoiceOverLabel() {
        let app = AppLauncher.launch(seeded: true)

        // SF Symbol names are dotted and lower-case: "location.magnifyingglass" reaching
        // VoiceOver means a label is missing.
        let symbolish = try! NSRegularExpression(pattern: "^[a-z0-9]+(\\.[a-z0-9]+)+$")
        var unlabelled: [String] = []
        for button in app.buttons.allElementsBoundByIndex where button.exists {
            let label = button.label
            if label.isEmpty {
                unlabelled.append("(empty, id: \(button.identifier))")
            } else if symbolish.firstMatch(
                in: label, range: NSRange(label.startIndex..., in: label)
            ) != nil {
                unlabelled.append(label)
            }
        }
        XCTAssertTrue(
            unlabelled.isEmpty,
            "Controls without a VoiceOver label: \(unlabelled.joined(separator: ", "))"
        )
    }
}
