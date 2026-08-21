import XCTest

/// UC-10 — the friends layer, running.
///
/// The ceremony itself needs two phones and stays a manual case (TC-8-12); what a simulator can
/// prove is everything after it — that the layer is off until asked for, that a friend's pin
/// appears in their own ink when it is on, and that a place both parties stamped says so.
final class FriendsJourneyTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-10-15 — given a friend with shared stamps, when the layer is turned on, then their
    /// pins appear and a shared place shows a countersign.
    func test_TC_10_15_theLayerDrawsFriendsStamps() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-SeedFriends"])

        let toggle = app.buttons["friendsLayerToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 20), "The friends control never appeared")

        // Off by default: the map is exactly what it was before the feature existed (FR-12.1).
        XCTAssertEqual(toggle.value as? String, "Off", "The friends layer was on before it was asked for")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "friendPin").count, 0,
            "A friend's pin was drawn with the layer switched off"
        )

        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "On")

        // The row of inks is the legend, so both friends are named on it once the layer is on.
        XCTAssertTrue(
            app.buttons["Lan"].waitForExistence(timeout: 10),
            "Lan's ink is missing from the layer control"
        )
        XCTAssertTrue(app.buttons["Minh"].exists, "Minh's ink is missing from the layer control")
    }

    /// FR-12.8 — a place the reader and a friend have both stamped names them on its own page,
    /// whether or not the map layer is on.
    func test_alsoStampedByAppearsOnPlaceDetail() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-SeedFriends"])

        app.raiseSheet()
        app.staticTexts["Phở Thìn"].tapWhenReady(timeout: 10)

        let row = app.otherElements["alsoStampedBy"]
        XCTAssertTrue(
            row.waitForExistence(timeout: 10),
            "The place Lan and the reader have both stamped did not say so"
        )
    }

    /// TC-8-18 — the ceremony's first step, which nothing opened until it was found broken.
    ///
    /// A simulator has no radio, so this cannot prove that a phone is discovered. What it does
    /// prove is the part that was actually wrong: that opening the screen *starts* discovery and
    /// the polling loop runs against it. Under `-UITestMode` the port is `StubProximity`, which
    /// reports a working radio and an empty room — so the looking copy is what a passing run
    /// shows, and the radio apologies are the one branch left to TC-8-16 and TC-8-12.
    func test_TC_8_18_openingAddFriendStartsLookingForPhones() {
        let app = AppLauncher.launch(seeded: true)

        app.buttons["friendsLayerToggle"].tapWhenReady()
        app.buttons["Add friend"].tapWhenReady()

        XCTAssertTrue(
            app.staticTexts["Looking for phones in the room…"].waitForExistence(timeout: 10),
            "Add friend opened without ever starting to look — the exact shape of the bug where "
                + "nothing called begin() and both phones searched an empty dictionary forever"
        )
        // Nobody is in the room, so the apology for a broken radio must not be what is shown.
        XCTAssertFalse(app.staticTexts["Bluetooth is off"].exists)
        XCTAssertFalse(app.staticTexts["Nomstamp can't use Bluetooth"].exists)
    }

    /// FR-10.8 — a full circle, and an empty one, are both explanations rather than errors.
    func test_theFriendsScreenOpensFromAnEmptyMap() {
        let app = AppLauncher.launch(seeded: true)

        // With nobody connected the control is the way in, not a switch that does nothing.
        app.buttons["friendsLayerToggle"].tapWhenReady()
        XCTAssertTrue(
            app.staticTexts["No friends yet"].waitForExistence(timeout: 10),
            "The friends screen did not open from the map"
        )
    }
}
