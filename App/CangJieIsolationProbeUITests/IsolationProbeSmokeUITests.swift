import XCTest

final class IsolationProbeSmokeUITests: XCTestCase {
    func testIsolationProbeExplainsAndRunsFailClosedVerification() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["isolation-probe-heading"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["isolation-probe-privacy-notice"].exists)

        let runButton = app.buttons["isolation-probe-run-button"]
        XCTAssertTrue(runButton.exists)
        XCTAssertTrue(runButton.isEnabled)
        runButton.tap()

        let overall = app.staticTexts["isolation-probe-overall-status"]
        XCTAssertTrue(overall.waitForExistence(timeout: 10))
        XCTAssertFalse(overall.label.contains("Running"))
        XCTAssertTrue(app.staticTexts["isolation-probe-own-group-status"].exists)

        let defaultGroupStatus = app.staticTexts["isolation-probe-default-group-status"]
        let forbiddenGroupStatus = app.staticTexts["isolation-probe-forbidden-group-status"]
        for _ in 0..<3 where !defaultGroupStatus.exists || !forbiddenGroupStatus.exists {
            app.swipeUp()
        }
        XCTAssertTrue(defaultGroupStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(forbiddenGroupStatus.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["isolation-probe-main-canary-value"].exists)
    }
}
