import XCTest

final class CangJieSmokeUITests: XCTestCase {
    func testAgentFirstWorkspaceLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["agent-control-plane-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textViews["agent-composer"].exists)
        XCTAssertTrue(app.buttons["novel-projects-link"].exists || app.staticTexts["Novel Projects"].exists)
        let identity = app.descendants(matching: .any)["build-identity"]
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        XCTAssertTrue(identity.label.contains("Executable Version"))
        XCTAssertTrue(identity.label.contains("Active"))
        XCTAssertTrue(app.staticTexts["build-activation-status"].exists)
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
        let diagnosticsList = app.descendants(matching: .any)["device-diagnostics-list"]
        XCTAssertTrue(diagnosticsList.waitForExistence(timeout: 5))

        let inputHeading = app.staticTexts["keychain-probe-input-heading"]
        let input = app.secureTextFields["keychain-probe-input"]
        let actionHeading = app.staticTexts["keychain-probe-action-heading"]
        let actionHelp = app.staticTexts["keychain-probe-action-help"]
        let save = app.buttons["keychain-probe-save"]
        let read = app.buttons["keychain-probe-read"]
        let delete = app.buttons["keychain-probe-delete"]
        let status = app.staticTexts["keychain-probe-status"]
        let guidance = app.staticTexts["keychain-probe-guidance"]
        reveal(inputHeading, in: diagnosticsList, swiping: .up)
        XCTAssertEqual(inputHeading.label, "1. Disposable value input")
        XCTAssertTrue(input.exists)
        XCTAssertEqual(input.placeholderValue, "Type disposable value here")

        reveal(actionHeading, in: diagnosticsList, swiping: .up)
        XCTAssertEqual(actionHeading.label, "2. Create or update and verify")
        XCTAssertTrue(actionHelp.exists)
        XCTAssertTrue(actionHelp.label.contains("secure field above"))
        XCTAssertTrue(save.exists)

        reveal(status, in: diagnosticsList, swiping: .down)
        XCTAssertTrue(guidance.exists)
        if status.label == "Stored" {
            reveal(delete, in: diagnosticsList, swiping: .up)
            delete.tap()
            reveal(status, in: diagnosticsList, swiping: .down)
        }
        assertEventually(status, hasLabel: "Absent")
        XCTAssertTrue(guidance.label.contains("tap Create and verify"))

        reveal(input, in: diagnosticsList, swiping: .up)
        let firstValue = "ui-keychain-probe-one"
        input.tap()
        input.typeText(firstValue)
        reveal(save, in: diagnosticsList, swiping: .up)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        assertEventually(save, hasLabel: "Update and verify")
        XCTAssertFalse(save.isEnabled)

        reveal(status, in: diagnosticsList, swiping: .down)
        assertEventually(status, hasLabel: "Stored")
        XCTAssertTrue(guidance.label.contains("same secure field below"))
        XCTAssertTrue(guidance.label.contains("tap Update and verify"))
        let firstDigest = app.staticTexts["keychain-probe-digest"]
        reveal(firstDigest, in: diagnosticsList, swiping: .down)
        let firstDigestLabel = firstDigest.label
        XCTAssertEqual(firstDigestLabel.count, 12)
        assertNoAccessiblePlaintext(firstValue, in: app)

        reveal(read, in: diagnosticsList, swiping: .up)
        read.tap()
        reveal(firstDigest, in: diagnosticsList, swiping: .down)

        reveal(input, in: diagnosticsList, swiping: .up)
        let updatedValue = "ui-keychain-probe-two"
        input.tap()
        input.typeText(updatedValue)
        reveal(save, in: diagnosticsList, swiping: .up)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        assertEventually(save, hasLabel: "Update and verify")

        let updatedDigest = app.staticTexts["keychain-probe-digest"]
        reveal(updatedDigest, in: diagnosticsList, swiping: .down)
        assertEventually(updatedDigest, changesFromLabel: firstDigestLabel)
        XCTAssertEqual(updatedDigest.label.count, 12)
        assertNoAccessiblePlaintext(updatedValue, in: app)

        reveal(delete, in: diagnosticsList, swiping: .up)
        delete.tap()
        reveal(status, in: diagnosticsList, swiping: .down)
        assertEventually(status, hasLabel: "Absent")
        XCTAssertFalse(delete.isEnabled)
        XCTAssertTrue(guidance.label.contains("tap Create and verify"))
        assertEventuallyDisappears(app.staticTexts["keychain-probe-digest"])
        reveal(save, in: diagnosticsList, swiping: .up)
        assertEventually(save, hasLabel: "Create and verify")
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

    private enum SwipeDirection {
        case up
        case down
    }

    @discardableResult
    private func reveal(
        _ element: XCUIElement,
        in scrollContainer: XCUIElement,
        swiping direction: SwipeDirection,
        maxSwipes: Int = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable {
                return true
            }
            switch direction {
            case .up:
                scrollContainer.swipeUp()
            case .down:
                scrollContainer.swipeDown()
            }
        }

        let isVisible = element.exists && element.isHittable
        XCTAssertTrue(
            isVisible,
            "Expected \(element) to become hittable after scrolling \(direction)",
            file: file,
            line: line
        )
        return isVisible
    }

    private func assertEventually(
        _ element: XCUIElement,
        hasLabel expectedLabel: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expectedLabel),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected label \(expectedLabel), got \(element.label)",
            file: file,
            line: line
        )
    }

    private func assertEventually(
        _ element: XCUIElement,
        changesFromLabel previousLabel: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label != %@", previousLabel),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected label to change from \(previousLabel)",
            file: file,
            line: line
        )
    }

    private func assertEventuallyDisappears(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected element to disappear",
            file: file,
            line: line
        )
    }

    private func assertNoAccessiblePlaintext(
        _ plaintext: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let leakedElements = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS %@ OR value CONTAINS %@",
                plaintext,
                plaintext
            )
        )
        XCTAssertEqual(leakedElements.count, 0, "Plaintext leaked through accessibility", file: file, line: line)
    }

}
