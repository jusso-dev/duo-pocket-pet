import XCTest

/// The standard iPhone layout end to end: feed, bedtime, wake.
/// Launch arguments are read by `DebugLaunchOptions` in simulator builds.
final class StandardLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFeedBedtimeAndWake() {
        let app = XCUIApplication()
        app.launchArguments = ["-fold", "unavailable", "-pet", "hungry,young"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["glanceHeader"].waitForExistence(timeout: 10))

        let fullness = app.descendants(matching: .any)["Fullness"].firstMatch
        XCTAssertTrue(fullness.waitForExistence(timeout: 5))
        let before = fullness.value as? String

        app.buttons["Feed"].firstMatch.tap()
        let fed = NSPredicate(format: "value != %@", before ?? "")
        expectation(for: fed, evaluatedWith: fullness)
        waitForExpectations(timeout: 5)

        app.buttons["Bedtime"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Wake"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bip is asleep"].exists)

        app.buttons["Wake"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Bedtime"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Bip is asleep"].exists)
    }
}
