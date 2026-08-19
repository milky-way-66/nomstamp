import XCTest

/// NFR-2.1 — cold launch to an interactive map.
final class LaunchPerformanceTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// TC-N-06 — NFR-2.1 asks for ≤ 2 s on an iPhone 12 or newer, meaning a release build on
    /// real hardware. Neither is available here, and the XCUITest harness itself adds seconds
    /// of springboard and accessibility setup to any wall-clock reading. So this case does two
    /// separate things:
    ///
    /// 1. `XCTApplicationLaunchMetric` records process-launch-to-first-frame, which is the
    ///    quantity the requirement is about. Xcode keeps it in the result bundle, and it is the
    ///    number to compare against 2 s once run on a device.
    /// 2. A wall-clock median across repeated launches, asserted against a deliberately loose
    ///    budget, so a real regression — an app that starts doing work at launch — fails the
    ///    suite here rather than waiting for a device run.
    func test_TC_N_06_coldLaunchReachesAnInteractiveMap() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-SeedDemoData"]

        // 1. Apple's own launch metric, for the record.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.terminate()
        }

        // 2. Time to a genuinely interactive map, repeated.
        var timings: [TimeInterval] = []
        for _ in 0..<5 {
            let started = Date()
            app.launch()
            XCTAssertTrue(
                app.buttons["addMealButton"].waitForExistence(timeout: 30),
                "the map never became interactive"
            )
            timings.append(Date().timeIntervalSince(started))
            app.terminate()
        }

        let median = timings.sorted()[timings.count / 2]
        print("TC-N-06 launch-to-interactive: \(timings.map { String(format: "%.2f", $0) }) median \(String(format: "%.2f", median))")

        // Measured median on this simulator is ~4.8 s, nearly all of it harness overhead.
        // 8 s catches a doubling without flaking on a busy machine.
        XCTAssertLessThan(
            median, 8.0,
            "median launch-to-interactive was \(String(format: "%.2f", median)) s over \(timings.count) launches"
        )
    }
}
