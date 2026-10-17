import XCTest

/// App Store screenshots. Skipped in normal test runs: `scripts/screenshots.sh`
/// turns them on with `TEST_RUNNER_HINGELING_SCREENSHOTS=1` and exports the
/// attachments. Each shot launches the app in a fixed scene with a sample pet
/// through the `-fold` and `-pet` launch arguments (see `DebugLaunchOptions`).
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HINGELING_SCREENSHOTS"] == "1",
            "Screenshots only run from scripts/screenshots.sh"
        )
    }

    @MainActor
    private func launch(fold: String, pet: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", fold, "-pet", pet]
        app.launch()
        return app
    }

    @MainActor
    private func snap(_ name: String) {
        // Let the sprite settle on a frame and any transition finish.
        Thread.sleep(forTimeInterval: 1.2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func test1Glance() {
        let app = launch(fold: "closed", pet: "asleep,young")
        XCTAssertTrue(app.descendants(matching: .any)["glance"].waitForExistence(timeout: 10))
        snap("1-glance")
    }

    @MainActor
    func test2HomeMidFeed() {
        let app = launch(fold: "open", pet: "hungry,young")
        let feed = app.buttons["Feed"].firstMatch
        XCTAssertTrue(feed.waitForExistence(timeout: 10))
        feed.tap()
        // The feed reaction runs for about a second; catch it part way.
        Thread.sleep(forTimeInterval: 0.3)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "2-home-feed"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func test3Stage() {
        let app = launch(fold: "half:110", pet: "joyful,grown")
        XCTAssertTrue(app.descendants(matching: .any)["stage"].waitForExistence(timeout: 10))
        snap("3-stage")
    }

    @MainActor
    func test4StandardHome() {
        let app = launch(fold: "unavailable", pet: "content,young")
        XCTAssertTrue(app.descendants(matching: .any)["glanceHeader"].waitForExistence(timeout: 10))
        snap("4-standard-home")
    }

    @MainActor
    func test5Elder() {
        let app = launch(fold: "open", pet: "joyful,elder,Old Bip")
        XCTAssertTrue(app.buttons["Feed"].firstMatch.waitForExistence(timeout: 10))
        snap("5-elder")
    }
}
