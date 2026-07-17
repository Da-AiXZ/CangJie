import XCTest

final class CangJieSmokeUITests: XCTestCase {
    func testAgentFirstWorkspaceLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["agent-control-plane-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews["agent-composer"].exists)
        XCTAssertTrue(app.buttons["novel-projects-link"].exists || app.staticTexts["Novel Projects"].exists)
        XCTAssertTrue(
            app.descendants(matching: .any)["build-identity"].waitForExistence(timeout: 5)
        )
    }

    func testDeviceDiagnosticsVerifiesKeychainCreateReadUpdateAndDelete() {
        let app = XCUIApplication()
        app.launch()

        let diagnosticsLink = app.buttons["device-diagnostics-link"]
        if diagnosticsLink.waitForExistence(timeout: 3) {
            diagnosticsLink.tap()
        } else {
            let diagnosticsLabel = app.staticTexts["Device Diagnostics"]
            XCTAssertTrue(diagnosticsLabel.waitForExistence(timeout: 10))
            diagnosticsLabel.tap()
        }

        XCTAssertTrue(app.staticTexts["device-diagnostics-heading"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["diagnostics-build-identity"].exists)

        let input = app.secureTextFields["keychain-probe-input"]
        let save = app.buttons["keychain-probe-save"]
        let read = app.buttons["keychain-probe-read"]
        let delete = app.buttons["keychain-probe-delete"]
        let status = app.staticTexts["keychain-probe-status"]
        XCTAssertTrue(input.exists)
        XCTAssertTrue(save.exists)
        XCTAssertTrue(read.exists)
        XCTAssertTrue(delete.exists)
        XCTAssertTrue(status.exists)

        if delete.isEnabled {
            delete.tap()
        }

        let firstValue = "ui-keychain-probe-one"
        input.tap()
        input.typeText(firstValue)
        save.tap()
        XCTAssertTrue(status.label.contains("Stored"))
        let firstDigest = app.staticTexts["keychain-probe-digest"]
        XCTAssertTrue(firstDigest.waitForExistence(timeout: 5))
        let firstDigestLabel = firstDigest.label
        XCTAssertEqual(firstDigestLabel.count, 12)
        XCTAssertFalse(app.staticTexts[firstValue].exists)

        read.tap()
        XCTAssertTrue(firstDigest.exists)

        let updatedValue = "ui-keychain-probe-two"
        input.tap()
        input.typeText(updatedValue)
        save.tap()
        let updatedDigest = app.staticTexts["keychain-probe-digest"]
        XCTAssertTrue(updatedDigest.waitForExistence(timeout: 5))
        XCTAssertNotEqual(updatedDigest.label, firstDigestLabel)
        XCTAssertFalse(app.staticTexts[updatedValue].exists)

        delete.tap()
        XCTAssertTrue(status.label.contains("Absent"))
        XCTAssertFalse(app.staticTexts["keychain-probe-digest"].exists)
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

        let feedback = app.staticTexts["project-refresh-feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 3))
        XCTAssertTrue(feedback.label.contains("Projects refreshed |"))
        XCTAssertEqual(feedback.label.filter { $0 == "|" }.count, 2)
        XCTAssertFalse(feedback.label.contains("?"))
        XCTAssertEqual(businessStatus.label, businessStatusBeforeRefresh)
    }

    func testOpeningPlanApprovalReviewIsScrollableAndApprovedHistoryRemainsVisible() {
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }

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

        let approvalCard = app.descendants(matching: .any)["opening-plan-approval-card"]
        XCTAssertTrue(approvalCard.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["opening-plan-approval-card-status"].exists)
        let compactSummary = app.staticTexts["opening-plan-approval-card-summary"]
        XCTAssertTrue(compactSummary.waitForExistence(timeout: 5))
        XCTAssertTrue(compactSummary.label.contains("Revision"))
        XCTAssertTrue(compactSummary.label.contains("Cost"))

        let reviewButton = app.buttons["opening-plan-review-button"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 5))
        XCTAssertTrue(reviewButton.isHittable, "The compact landscape card must keep review reachable")
        reviewButton.tap()

        let detailHeading = app.staticTexts["opening-plan-approval-detail-heading"]
        XCTAssertTrue(detailHeading.waitForExistence(timeout: 5))
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
            "opening-plan-approval-plan-body"
        ] {
            XCTAssertTrue(
                app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5),
                "Missing exact approval detail field: \(identifier)"
            )
        }

        let bindingHash = app.staticTexts["opening-plan-approval-binding-hash"]
        for _ in 0..<8 where !bindingHash.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(bindingHash.isHittable, "Exact binding details must be reachable by scrolling")

        let planBody = app.staticTexts["opening-plan-approval-plan-body"]
        for _ in 0..<8 where !planBody.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(planBody.isHittable, "The complete opening plan must be reachable by scrolling")

        let approveButton = app.buttons["opening-plan-approve-button"]
        for _ in 0..<8 where !approveButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(approveButton.isHittable)
        approveButton.tap()
        XCTAssertFalse(
            detailHeading.waitForExistence(timeout: 3),
            "A successful exact approval must dismiss the review"
        )

        let deadline = Date().addingTimeInterval(5)
        while approvalCard.exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertFalse(approvalCard.exists, "Approved work must leave the central pending queue")

        let drawerButton = app.buttons["artifact-drawer-toggle"]
        XCTAssertTrue(drawerButton.waitForExistence(timeout: 5))
        drawerButton.tap()

        let historyStatus = app.staticTexts["opening-plan-history-status"]
        XCTAssertTrue(historyStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(historyStatus.label, "Status: approved")
        XCTAssertTrue(app.staticTexts["opening-plan-history-binding-hash"].exists)
        XCTAssertTrue(app.staticTexts["last-tool-receipt"].exists)
    }

}
