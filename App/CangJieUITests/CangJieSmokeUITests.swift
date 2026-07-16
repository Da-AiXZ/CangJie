import XCTest

final class CangJieSmokeUITests: XCTestCase {
    func testAgentFirstWorkspaceLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["agent-control-plane-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews["agent-composer"].exists)
        XCTAssertTrue(app.buttons["novel-projects-link"].exists || app.staticTexts["Novel Projects"].exists)
    }
}
