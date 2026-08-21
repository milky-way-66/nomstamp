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

    /// TC-10-17 — the legend teaches the mapping, or it is just a row of colours.
    ///
    /// What a journey can check is that each entry is laid out as a stamp *and* a name: a
    /// stamp-only chip is 24pt across, one carrying a name is far wider. Whether the name is
    /// legible, and whether it is the right one, is a design-sweep judgement and not this test's.
    func test_TC_10_17_theLegendNamesEachFriend() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-SeedFriends"])
        app.buttons["friendsLayerToggle"].tapWhenReady(timeout: 20)

        let lan = app.buttons["Lan"]
        XCTAssertTrue(lan.waitForExistence(timeout: 10), "Lan is missing from the legend")
        XCTAssertGreaterThan(
            lan.frame.width, 48,
            "The legend entry is only wide enough for a stamp — the name is not being drawn, so "
                + "nothing on the map says which ink is Lan's"
        )
    }

    /// TC-10-18 — a friend-only pin says whose it is, not merely where it is.
    func test_TC_10_18_aFriendPinNamesItsFriendToVoiceOver() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-SeedFriends"])
        app.buttons["friendsLayerToggle"].tapWhenReady(timeout: 20)

        let pin = app.descendants(matching: .any).matching(identifier: "friendPin").firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10), "Minh's pin never appeared")
        XCTAssertTrue(
            pin.label.contains("Minh"),
            "A friend's pin told VoiceOver \"\(pin.label)\" — the whole point of the layer is "
                + "whose stamp it is, and hue says that to nobody using VoiceOver"
        )
    }

    /// TC-10-19 — *we have both been here*, said aloud.
    ///
    /// The countersign is the moment the whole feature exists for, and it was drawn on the pin
    /// and mentioned to nobody: the pin's description covered place, kind and meal count and
    /// stopped there.
    func test_TC_10_19_aCountersignedPinNamesTheFriend() {
        // One place on the map, so the countersigned pin is the pin — no cluster to break apart
        // and no zooming, which is where the first version of this case went wrong.
        let app = AppLauncher.launch(
            seeded: true,
            extraArguments: ["-SeedOnePlace", "-SeedFriends"]
        )
        app.buttons["friendsLayerToggle"].tapWhenReady(timeout: 20)

        let pins = app.descendants(matching: .any).matching(identifier: "mapPin")
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 10), "No pin for the reader's own place")

        let labels = (0..<pins.count).map { pins.element(boundBy: $0).label }
        XCTAssertFalse(labels.isEmpty, "The map drew no pin at all — nothing was under test")
        XCTAssertTrue(
            labels.contains { $0.contains("Lan") },
            "No pin mentioned Lan's countersign. Labels were: \(labels)"
        )
    }

    /// TC-10-21 — isolating one friend, and putting everyone back.
    ///
    /// Lan countersigns a place the reader has been; Minh is the only friend-only pin. So
    /// isolating Lan must take Minh's pin off the map, and isolating again must bring it back.
    func test_TC_10_21_isolatingAFriendLeavesOnlyTheirStamps() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-SeedFriends"])
        app.buttons["friendsLayerToggle"].tapWhenReady(timeout: 20)

        let friendPins = app.descendants(matching: .any).matching(identifier: "friendPin")
        XCTAssertTrue(friendPins.firstMatch.waitForExistence(timeout: 10))
        let everyone = friendPins.count
        XCTAssertGreaterThan(everyone, 0, "Nothing to filter — the seed put no friend pins on the map")

        let lan = app.buttons["Lan"]
        XCTAssertTrue(lan.waitForExistence(timeout: 10))
        lan.press(forDuration: 0.8)

        XCTAssertEqual(
            friendPins.count, 0,
            "Isolating Lan left someone else's stamps on the map"
        )

        lan.press(forDuration: 0.8)
        XCTAssertEqual(
            friendPins.count, everyone,
            "Isolating a second time did not put everyone back — the one gesture has to be its "
                + "own undo, or a reader can strand themselves with a map they cannot restore"
        )
    }

    /// TC-10-23 — eight friends, and a strip that still fits on a phone.
    ///
    /// Adding names to the legend made every entry about four times wider. Two friends fit
    /// comfortably and prove nothing; eight cannot fit at all, so the strip has to scroll rather
    /// than run off the edge. This is the case that would have caught it.
    func test_TC_10_23_aFullCircleStaysOnTheScreen() {
        let app = AppLauncher.launch(seeded: true, extraArguments: ["-SeedFullCircle"])
        app.buttons["friendsLayerToggle"].tapWhenReady(timeout: 20)

        let first = app.buttons["Lan"]
        XCTAssertTrue(first.waitForExistence(timeout: 10), "The legend never appeared")

        let screen = app.frame
        let entries = app.descendants(matching: .any).matching(identifier: "friendLegend")
        XCTAssertGreaterThan(entries.count, 0, "No legend entries for a circle of eight")

        // Deliberately *not* asserting that every entry sits inside the screen: a scrolling strip
        // legitimately keeps its later entries beyond the edge, and XCUITest reports their real
        // frames. What must stay on screen is the first entry and the control's own chrome — if
        // the strip has pushed the switch or the overflow button off the phone, the reader has
        // lost the way to turn the layer off at all.
        XCTAssertTrue(
            screen.contains(entries.element(boundBy: 0).frame),
            "The first friend in the legend is not fully on screen"
        )

        let toggle = app.buttons["friendsLayerToggle"]
        XCTAssertTrue(screen.contains(toggle.frame), "Eight friends pushed the layer switch off the screen")
        XCTAssertTrue(toggle.isHittable, "The layer switch can no longer be tapped")

        let overflow = app.buttons["Friends"]
        XCTAssertTrue(overflow.exists, "The way into the friends screen vanished")
        XCTAssertTrue(screen.contains(overflow.frame), "Eight friends pushed the overflow button off the screen")
        XCTAssertTrue(overflow.isHittable, "The overflow button can no longer be tapped")
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
