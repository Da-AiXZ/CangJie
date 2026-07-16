import XCTest

final class CangJieSmokeUITests: XCTestCase {
    func testM0WorkbenchLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["m0-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews["draft-editor"].exists)
    }
}
