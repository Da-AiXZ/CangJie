import XCTest

final class CangJieSmokeUITests: XCTestCase {
    func testAgentFirstWorkspaceLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["agent-control-plane-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews["agent-composer"].exists)
        XCTAssertTrue(app.buttons["novel-projects-link"].exists || app.staticTexts["Novel Projects"].exists)
    }

    func testProjectRefreshShowsVisibleAcknowledgement() {
        let app = XCUIApplication()
        app.launch()

        let businessStatus = app.staticTexts["agent-business-status"]
        XCTAssertTrue(businessStatus.waitForExistence(timeout: 10))
        let businessStatusBeforeRefresh = businessStatus.label

        let projectsLink = app.buttons["novel-projects-link"]
        if projectsLink.waitForExistence(timeout: 3) {
            projectsLink.tap()
        } else {
            let projectsLabel = app.staticTexts["Novel Projects"]
            XCTAssertTrue(projectsLabel.waitForExistence(timeout: 10))
            projectsLabel.tap()
        }

        let refreshButton = app.buttons["projects-refresh-button"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 10))
        refreshButton.tap()

        XCTAssertTrue(app.staticTexts["project-refresh-feedback"].waitForExistence(timeout: 3))
        XCTAssertEqual(businessStatus.label, businessStatusBeforeRefresh)
    }

    func testOpeningPlanApprovalCardDisplaysExactBindingMetadata() {
        let app = XCUIApplication()
        app.launch()

        let composer = app.textViews["agent-composer"]
        let sendButton = app.buttons["agent-send-button"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(sendButton.waitForExistence(timeout: 10))

        for message in [
            "create a cultivation novel",
            "A forbidden inheritance changes every victory",
            "The courier must save his sister",
            "Each use erases one memory"
        ] {
            composer.tap()
            composer.typeText(message)
            sendButton.tap()
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["opening-plan-approval-card"]
                .waitForExistence(timeout: 10)
        )
        for identifier in [
            "opening-plan-approval-request-id",
            "opening-plan-approval-revision",
            "opening-plan-approval-artifact-hash",
            "opening-plan-approval-tool",
            "opening-plan-approval-budget",
            "opening-plan-approval-expiration",
            "opening-plan-approval-expected-diff",
            "opening-plan-approval-binding-hash",
            "opening-plan-approval-status",
            "opening-plan-approve-button"
        ] {
            XCTAssertTrue(
                app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5),
                "Missing exact approval UI field: \(identifier)"
            )
        }
    }

}
