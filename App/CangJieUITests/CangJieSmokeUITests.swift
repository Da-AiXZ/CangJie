import XCTest

final class CangJieSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    func testAgentFirstWorkspaceLaunches() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let title = app.staticTexts["agent-control-plane-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "仓颉")
        XCTAssertTrue(app.textViews["agent-composer"].exists)

        let destinations = ["conversation", "novels", "tasks", "settings"]
        for destination in destinations {
            XCTAssertTrue(app.buttons["activity-bar-\(destination)"].exists)
        }
        XCTAssertEqual(app.buttons["activity-bar-conversation"].value as? String, "当前页面")

        XCTAssertFalse(app.buttons["novel-projects-link"].exists)
        XCTAssertFalse(app.buttons["device-diagnostics-link"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["build-identity"].exists)
        XCTAssertFalse(app.staticTexts["build-activation-status"].exists)
        XCTAssertFalse(app.buttons["artifact-drawer-toggle"].exists)
        let resultButton = app.buttons["result-drawer-toggle"]
        XCTAssertTrue(resultButton.exists)
        resultButton.tap()
        let resultsEmptyState = app.staticTexts["results-empty-state"]
        XCTAssertTrue(resultsEmptyState.waitForExistence(timeout: 5))
        XCTAssertEqual(
            resultsEmptyState.label,
            "当前对话还没有可查看的真实工具结果。普通回复仍留在对话里。"
        )
        XCTAssertFalse(app.staticTexts["last-tool-receipt"].exists)
        XCTAssertFalse(app.staticTexts["Conversation artifacts"].exists)
    }

    func testLandscapeResultDrawerAndNavigationReleaseComposerFocusAndHideBackgroundAccessibility() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let composer = app.textViews["agent-composer"]
        let resultButton = app.buttons["result-drawer-toggle"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(resultButton.waitForExistence(timeout: 5))

        composer.tap()
        composer.typeText("focus-contract")
        assertEventually(composer, hasKeyboardFocus: true)

        resultButton.tap()
        assertEventually(composer, hasKeyboardFocus: false)

        resultButton.tap()
        composer.tap()
        assertEventually(composer, hasKeyboardFocus: true)

        app.buttons["activity-bar-novels"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["landscape-left-page-overlay"]
                .waitForExistence(timeout: 5)
        )
        assertEventually(composer, hasKeyboardFocus: false)
        XCTAssertFalse(composer.exists)
        XCTAssertFalse(resultButton.exists)
        XCTAssertFalse(app.buttons["activity-bar-conversation"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["landscape-conversation-rail"].exists)
        XCTAssertTrue(app.buttons["novel-projects-back-button"].exists)
    }

    func testPortraitNavigationOverlayIsModalAndUsesAccurateCloseLabels() {
        XCUIDevice.shared.orientation = .portrait
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-portrait-single-focus"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.textViews["agent-composer"].exists)

        app.buttons["portrait-navigation-open"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["portrait-left-page-overlay"]
                .waitForExistence(timeout: 5)
        )
        let dismissButton = app.buttons["portrait-navigation-dismiss"]
        let closeButton = app.buttons["portrait-navigation-close"]
        XCTAssertTrue(dismissButton.exists)
        XCTAssertTrue(closeButton.exists)
        XCTAssertEqual(dismissButton.label, "关闭导航")
        XCTAssertEqual(closeButton.label, "关闭导航")

        XCTAssertFalse(app.textViews["agent-composer"].exists)
        XCTAssertFalse(app.buttons["portrait-navigation-open"].exists)
        XCTAssertFalse(app.buttons["portrait-focus-conversation"].exists)
        XCTAssertFalse(app.buttons["portrait-focus-results"].exists)
        XCTAssertTrue(app.buttons["portrait-activity-conversation"].exists)
    }

    func testWorkspaceRotatesToPortraitSingleFocusWithoutLosingDraftOrShowingReader() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-landscape-columns"]
                .waitForExistence(timeout: 10)
        )
        let composer = app.textViews["agent-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("旋转后仍然保留的念头")

        XCUIDevice.shared.orientation = .portrait

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-portrait-single-focus"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.buttons["portrait-focus-conversation"].exists)
        XCTAssertTrue(app.buttons["portrait-focus-results"].exists)
        XCTAssertFalse(app.buttons["portrait-focus-reader"].exists)
        XCTAssertFalse(app.buttons["activity-bar-novels"].exists)
        XCTAssertEqual(composer.value as? String, "旋转后仍然保留的念头")

        app.buttons["portrait-focus-results"].tap()
        XCTAssertTrue(app.staticTexts["results-empty-state"].waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.buttons["portrait-focus-results"].value as? String,
            "当前页面"
        )

        app.buttons["portrait-navigation-open"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["portrait-left-page-overlay"]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.buttons["portrait-activity-novels"].exists)
        app.buttons["portrait-activity-novels"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["novel-projects-page"]
                .waitForExistence(timeout: 5)
        )

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(
            app.descendants(matching: .any)["landscape-left-page-overlay"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["novel-projects-page"].exists)
        XCTAssertFalse(composer.exists)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(
            app.descendants(matching: .any)["portrait-left-page-overlay"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.descendants(matching: .any)["novel-projects-page"].exists)

        app.buttons["novel-projects-back-button"].tap()
        XCTAssertEqual(
            app.buttons["portrait-activity-conversation"].value as? String,
            "当前页面"
        )
        app.buttons["portrait-navigation-close"].tap()
        app.buttons["portrait-focus-conversation"].tap()
        let restoredPortraitComposer = app.textViews["agent-composer"]
        XCTAssertTrue(restoredPortraitComposer.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredPortraitComposer.value as? String, "旋转后仍然保留的念头")

        XCUIDevice.shared.orientation = .landscapeLeft

        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-landscape-columns"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.buttons["activity-bar-conversation"].exists)
        let restoredLandscapeComposer = app.textViews["agent-composer"]
        XCTAssertTrue(restoredLandscapeComposer.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredLandscapeComposer.value as? String, "旋转后仍然保留的念头")
    }

    func testFirstLaunchShowsExactWelcomePageAndHidesUnavailableEntrypoints() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let welcomePage = app.descendants(matching: .any)["welcome-page"]
        XCTAssertTrue(welcomePage.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["welcome-brand"].label, "仓颉")
        XCTAssertEqual(
            app.staticTexts["welcome-question"].label,
            "有什么想写成小说的念头吗？"
        )
        XCTAssertEqual(
            app.staticTexts["welcome-guidance"].label,
            "你不用会写，也不用先想好主线、人物和世界。\n"
                + "可以告诉我一句话、一幅画面、一种感觉，\n"
                + "甚至只说你最近喜欢看什么。"
        )
        XCTAssertEqual(
            app.staticTexts["welcome-promise"].label,
            "剩下的，我来陪你想清楚。"
        )
        XCTAssertTrue(app.buttons["welcome-idea-button"].exists)
        XCTAssertTrue(app.buttons["welcome-no-idea-button"].exists)
        XCTAssertTrue(app.staticTexts["agent-composer-placeholder"].exists)
        XCTAssertFalse(app.buttons["接着上次继续"].exists)
        XCTAssertFalse(app.staticTexts["接着上次继续"].exists)
        XCTAssertFalse(app.buttons["导入已有资料"].exists)
        XCTAssertFalse(app.staticTexts["导入已有资料"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["opening-plan-approval-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["last-tool-receipt"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["chapter-review-card"].exists)
    }

    func testWelcomeIdeaShortcutOnlyFocusesComposer() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let composer = app.textViews["agent-composer"]
        let shortcut = app.buttons["welcome-idea-button"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))

        shortcut.tap()
        app.typeText("雨夜里有人敲门")

        XCTAssertEqual(composer.value as? String, "雨夜里有人敲门")
        XCTAssertTrue(app.descendants(matching: .any)["welcome-page"].exists)
        XCTAssertFalse(app.staticTexts["界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["opening-plan-approval-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["last-tool-receipt"].exists)
    }

    func testWelcomeNoIdeaShortcutOnlyPrefillsComposer() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let composer = app.textViews["agent-composer"]
        let shortcut = app.buttons["welcome-no-idea-button"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))

        shortcut.tap()

        XCTAssertEqual(composer.value as? String, "我还没想法")
        XCTAssertTrue(app.descendants(matching: .any)["welcome-page"].exists)
        XCTAssertFalse(app.staticTexts["界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["opening-plan-approval-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["last-tool-receipt"].exists)
    }

    func testOrdinarySurfaceHidesEngineeringDiagnosticsAndLongPressExplainsActivityItem() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        XCTAssertTrue(app.buttons["activity-bar-tasks"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["device-diagnostics-link"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["device-diagnostics-list"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["build-identity"].exists)
        XCTAssertFalse(app.staticTexts["build-activation-status"].exists)
        XCTAssertFalse(app.staticTexts["Workbenches"].exists)
        XCTAssertFalse(app.staticTexts["Research"].exists)
        XCTAssertFalse(app.staticTexts["Device Diagnostics"].exists)

        app.buttons["activity-bar-tasks"].press(forDuration: 1.2)

        let help = app.descendants(matching: .any)["activity-help-tasks"]
        let purpose = app.staticTexts["查看真实任务状态；没有任务时显示诚实空状态"]
        XCTAssertTrue(help.waitForExistence(timeout: 5) || purpose.waitForExistence(timeout: 2))
    }

    func testSettingsExposesDeviceDiagnosticsOnlyThroughAdvancedPath() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        XCTAssertTrue(app.buttons["activity-bar-settings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["device-diagnostics-link"].exists)

        app.buttons["activity-bar-settings"].tap()
        let diagnosticsLink = app.buttons["device-diagnostics-link"]
        XCTAssertTrue(diagnosticsLink.waitForExistence(timeout: 5))
        diagnosticsLink.tap()

        let diagnosticsList = app.descendants(matching: .any)["device-diagnostics-list"]
        XCTAssertTrue(diagnosticsList.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["diagnostics-candidate-set"].exists)

        let prepareCanaryButton = app.buttons["isolation-canary-prepare"]
        reveal(prepareCanaryButton, in: diagnosticsList, swiping: .up, maxSwipes: 3)
        XCTAssertTrue(prepareCanaryButton.isEnabled)
    }

    func testProjectRefreshShowsVisibleAcknowledgement() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let businessStatus = app.staticTexts["agent-business-status"]
        XCTAssertTrue(businessStatus.waitForExistence(timeout: 10))
        let businessStatusBeforeRefresh = businessStatus.label

        let projectsLink = app.buttons["activity-bar-novels"]
        XCTAssertTrue(projectsLink.waitForExistence(timeout: 10))
        projectsLink.tap()

        let refreshButton = app.buttons["projects-refresh-button"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 10))
        refreshButton.tap()

        let feedback = app.staticTexts["project-refresh-feedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 3))
        XCTAssertTrue(feedback.label.contains("书架已刷新 |"))
        XCTAssertEqual(feedback.label.filter { $0 == "|" }.count, 2)
        XCTAssertFalse(feedback.label.contains("?"))
        XCTAssertFalse(businessStatus.exists)

        let backButton = app.buttons["novel-projects-back-button"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        XCTAssertTrue(businessStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(businessStatus.label, businessStatusBeforeRefresh)
    }

    func testEmptyNovelShelfPushAndBackPreserveUnboundDraftWithoutCreatingProject() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        let composer = app.textViews["agent-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))

        let draftText = "只保存在当前新对话里的念头"
        composer.tap()
        composer.typeText(draftText)
        XCTAssertEqual(composer.value as? String, draftText)

        let projectsLink = app.buttons["activity-bar-novels"]
        XCTAssertTrue(projectsLink.waitForExistence(timeout: 5))
        projectsLink.tap()

        XCTAssertTrue(app.descendants(matching: .any)["novel-projects-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["novel-projects-empty-state"].exists)
        XCTAssertFalse(app.buttons["novel-project-row-0"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["welcome-page"].exists)
        XCTAssertFalse(app.buttons["conversation-row-0"].exists)

        let backButton = app.buttons["novel-projects-back-button"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        XCTAssertEqual(app.buttons["activity-bar-conversation"].value as? String, "当前页面")
        XCTAssertEqual(composer.value as? String, draftText)
        XCTAssertTrue(app.descendants(matching: .any)["welcome-page"].exists)
        XCTAssertFalse(app.buttons["conversation-row-0"].exists)
        XCTAssertFalse(app.staticTexts["界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"].exists)
    }

    func testPersistedNovelShelfPushesToDetailAndBackWithoutChangingConversationWorkspace() {
        let app = makeIsolatedApp(fixture: "persisted-novel-shelf")
        launchWithDeterministicTimestampSetting(app)

        let fixtureMessage = "雨夜里，有人敲响了封闭十年的山门"
        let fixtureDraft = "下一步想让主角先不开门"
        let composer = app.textViews["agent-composer"]
        let conversationRow = app.buttons["conversation-row-0"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(conversationRow.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, fixtureDraft)
        XCTAssertEqual(conversationRow.value as? String, "当前对话")
        XCTAssertTrue(app.staticTexts["你：\(fixtureMessage)"].exists)

        let projectsLink = app.buttons["activity-bar-novels"]
        XCTAssertTrue(projectsLink.waitForExistence(timeout: 5))
        projectsLink.tap()

        XCTAssertTrue(app.descendants(matching: .any)["novel-projects-page"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["novel-projects-empty-state"].exists)
        let projectRow = app.buttons["novel-project-row-0"]
        XCTAssertTrue(projectRow.waitForExistence(timeout: 5))
        XCTAssertTrue(projectRow.label.contains("雾城守夜人"))
        XCTAssertTrue(projectRow.label.contains("刚保存了故事念头，还没有开始正文"))
        XCTAssertFalse(projectRow.label.contains("封闭十年的山门在雨夜重新响起"))
        XCTAssertFalse(app.staticTexts["你：\(fixtureMessage)"].exists)

        projectRow.tap()

        XCTAssertTrue(app.descendants(matching: .any)["novel-project-detail-page"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["novel-project-detail-title"].label, "雾城守夜人")
        XCTAssertEqual(
            app.staticTexts["novel-project-detail-premise"].label,
            "封闭十年的山门在雨夜重新响起"
        )
        XCTAssertEqual(
            app.staticTexts["novel-project-detail-progress"].label,
            "刚保存了故事念头，还没有开始正文"
        )
        XCTAssertTrue(app.staticTexts["novel-project-detail-stage-note"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["novel-project-detail-entry-continue"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["novel-project-detail-entry-materials-tasks"].exists)
        XCTAssertFalse(app.staticTexts["你：\(fixtureMessage)"].exists)

        let detailBackButton = app.buttons["novel-project-detail-back-button"]
        XCTAssertTrue(detailBackButton.waitForExistence(timeout: 5))
        detailBackButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["novel-projects-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["novel-project-row-0"].exists)

        let shelfBackButton = app.buttons["novel-projects-back-button"]
        XCTAssertTrue(shelfBackButton.waitForExistence(timeout: 5))
        shelfBackButton.tap()

        XCTAssertEqual(app.buttons["activity-bar-conversation"].value as? String, "当前页面")
        XCTAssertEqual(composer.value as? String, fixtureDraft)
        XCTAssertEqual(conversationRow.value as? String, "当前对话")
        XCTAssertTrue(app.staticTexts["你：\(fixtureMessage)"].exists)
    }

    func testS1ConversationRailCreatesListsHighlightsAndSwitchesWithoutReplacingCenter() {
        let app = makeIsolatedApp()
        launchWithDeterministicTimestampSetting(app)

        XCTAssertTrue(app.staticTexts["conversations-heading"].waitForExistence(timeout: 10))
        let newConversationButton = app.buttons["new-conversation-button"]
        XCTAssertTrue(newConversationButton.waitForExistence(timeout: 5))

        let composer = app.textViews["agent-composer"]
        let sendButton = app.buttons["agent-send-button"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))

        let firstText = "雨夜里有人敲门"
        composer.tap()
        composer.typeText(firstText)
        sendButton.tap()

        let firstOnlyRow = app.buttons["conversation-row-0"]
        XCTAssertTrue(firstOnlyRow.waitForExistence(timeout: 5))
        XCTAssertTrue(firstOnlyRow.label.contains(firstText))
        XCTAssertTrue(firstOnlyRow.label.contains("更新时间"))
        XCTAssertEqual(firstOnlyRow.value as? String, "当前对话")

        newConversationButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["welcome-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["conversation-row-0"].label.contains(firstText))
        XCTAssertEqual(app.buttons["conversation-row-0"].value as? String, "未选择")
        XCTAssertFalse(app.staticTexts["你：" + firstText].exists)

        let secondText = "醒来后发现所有人都忘了我"
        composer.tap()
        composer.typeText(secondText)
        sendButton.tap()

        let newestRow = app.buttons["conversation-row-0"]
        let olderRow = app.buttons["conversation-row-1"]
        XCTAssertTrue(newestRow.waitForExistence(timeout: 5))
        XCTAssertTrue(olderRow.waitForExistence(timeout: 5))
        XCTAssertTrue(newestRow.label.contains(secondText))
        XCTAssertTrue(olderRow.label.contains(firstText))
        XCTAssertTrue(newestRow.label.contains("更新时间"))
        XCTAssertTrue(olderRow.label.contains("更新时间"))
        XCTAssertEqual(newestRow.value as? String, "当前对话")
        XCTAssertEqual(olderRow.value as? String, "未选择")

        olderRow.tap()

        XCTAssertTrue(app.staticTexts["你：" + firstText].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["你：" + secondText].exists)
        XCTAssertEqual(olderRow.value as? String, "当前对话")
        XCTAssertEqual(newestRow.value as? String, "未选择")

        newestRow.tap()

        XCTAssertTrue(app.staticTexts["你：" + secondText].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["你：" + firstText].exists)
        XCTAssertEqual(newestRow.value as? String, "当前对话")
        XCTAssertEqual(olderRow.value as? String, "未选择")

        let projectsLink = app.buttons["activity-bar-novels"]
        XCTAssertTrue(projectsLink.waitForExistence(timeout: 5))
        projectsLink.tap()

        XCTAssertTrue(app.descendants(matching: .any)["novel-projects-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["projects-refresh-button"].exists)
        XCTAssertFalse(app.staticTexts["你：" + secondText].exists)

        let projectsBackButton = app.buttons["novel-projects-back-button"]
        XCTAssertTrue(projectsBackButton.waitForExistence(timeout: 5))
        projectsBackButton.tap()

        XCTAssertEqual(app.buttons["activity-bar-conversation"].value as? String, "当前页面")
        XCTAssertTrue(app.staticTexts["你：" + secondText].exists)
        XCTAssertEqual(app.buttons["conversation-row-0"].value as? String, "当前对话")
    }

    func testTasksAndSettingsPreserveConversationAndTimestampSettingReallyApplies() {
        let app = makeIsolatedApp(fixture: "persisted-novel-shelf")
        launchWithDeterministicTimestampSetting(app)

        let fixtureMessage = "雨夜里，有人敲响了封闭十年的山门"
        let fixtureDraft = "下一步想让主角先不开门"
        let composer = app.textViews["agent-composer"]
        let conversationRow = app.buttons["conversation-row-0"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(conversationRow.waitForExistence(timeout: 5))

        XCTAssertEqual(composer.value as? String, fixtureDraft)

        app.buttons["activity-bar-tasks"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["ai-tasks-page"].waitForExistence(timeout: 5))
        let tasksEmptyState = app.staticTexts["ai-tasks-empty-state"]
        XCTAssertTrue(tasksEmptyState.exists)
        XCTAssertEqual(
            tasksEmptyState.label,
            "当前没有需要处理的 AI 任务。你在对话里交给仓颉的真实工作会显示在这里。"
        )
        XCTAssertFalse(app.staticTexts["你：\(fixtureMessage)"].exists)
        app.buttons["ai-tasks-back-button"].tap()
        XCTAssertEqual(app.buttons["activity-bar-conversation"].value as? String, "当前页面")
        XCTAssertEqual(conversationRow.value as? String, "当前对话")
        XCTAssertEqual(composer.value as? String, fixtureDraft)
        XCTAssertTrue(app.staticTexts["你：\(fixtureMessage)"].exists)

        app.buttons["activity-bar-settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings-page"].waitForExistence(timeout: 5))
        let injectedTimestampSwitch = app.switches["settings-conversation-time-toggle"]
        XCTAssertTrue(injectedTimestampSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(injectedTimestampSwitch.value as? String, "1")
        app.buttons["settings-back-button"].tap()
        XCTAssertTrue(app.staticTexts["conversation-time-0"].waitForExistence(timeout: 5))

        relaunchWithoutFixturePreservingDatabaseScope(app)

        let writableTimestampSwitch = app.switches["settings-conversation-time-toggle"]
        XCTAssertTrue(app.buttons["conversation-row-0"].waitForExistence(timeout: 10))
        app.buttons["activity-bar-settings"].tap()
        XCTAssertTrue(writableTimestampSwitch.waitForExistence(timeout: 5))
        if writableTimestampSwitch.value as? String == "0" {
            tapSwitchControl(writableTimestampSwitch)
        }
        app.buttons["settings-back-button"].tap()
        XCTAssertTrue(app.staticTexts["conversation-time-0"].waitForExistence(timeout: 5))

        relaunchWithoutFixturePreservingDatabaseScope(app)

        let restoredConversationRowWithTimestamp = app.buttons["conversation-row-0"]
        XCTAssertTrue(restoredConversationRowWithTimestamp.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["conversation-time-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(restoredConversationRowWithTimestamp.label.contains("更新时间"))

        app.buttons["activity-bar-settings"].tap()
        let restoredTimestampSwitch = app.switches["settings-conversation-time-toggle"]
        XCTAssertTrue(restoredTimestampSwitch.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredTimestampSwitch.value as? String, "1")
        tapSwitchControl(restoredTimestampSwitch)
        assertEventually(restoredTimestampSwitch, hasValue: "0")
        app.buttons["settings-back-button"].tap()
        assertEventuallyDisappears(app.staticTexts["conversation-time-0"])
        let conversationRowWithoutTimestamp = app.buttons["conversation-row-0"]
        XCTAssertTrue(conversationRowWithoutTimestamp.waitForExistence(timeout: 5))
        XCTAssertFalse(conversationRowWithoutTimestamp.label.contains("更新时间"))

        relaunchWithoutFixturePreservingDatabaseScope(app)

        let restoredConversationRowWithoutTimestamp = app.buttons["conversation-row-0"]
        XCTAssertTrue(restoredConversationRowWithoutTimestamp.waitForExistence(timeout: 10))
        assertEventuallyDisappears(app.staticTexts["conversation-time-0"])
        XCTAssertFalse(restoredConversationRowWithoutTimestamp.label.contains("更新时间"))
        XCTAssertEqual(restoredConversationRowWithoutTimestamp.value as? String, "当前对话")
        XCTAssertEqual(app.textViews["agent-composer"].value as? String, fixtureDraft)
        XCTAssertTrue(app.staticTexts["你：\(fixtureMessage)"].exists)
    }

    func testS2FirstModelRequestOpensExplicitConnectionFlowAndKeepsOriginalIntent() {
        let app = makeIsolatedApp(fixture: "model-connection-setup")
        launchWithDeterministicTimestampSetting(app)

        let composer = app.textViews["agent-composer"]
        let sendButton = app.buttons["agent-send-button"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(sendButton.waitForExistence(timeout: 10))

        let userText = "s2-model-request-" + UUID().uuidString
        composer.tap()
        composer.typeText(userText)
        sendButton.tap()

        let userMessage = app.staticTexts["你：" + userText]
        XCTAssertTrue(userMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["model-connection-setup-card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["model-provider-openAI"].exists)
        app.buttons["model-provider-openAI"].tap()

        let endpoint = app.staticTexts["model-connection-base-url"]
        XCTAssertTrue(endpoint.waitForExistence(timeout: 5))
        XCTAssertEqual(endpoint.label, "https://api.openai.com/v1")
        let secret = "ui-test-secret-value"
        let secretField = app.secureTextFields["model-connection-secret"]
        XCTAssertTrue(secretField.waitForExistence(timeout: 5))
        secretField.tap()
        secretField.typeText(secret)
        app.buttons["model-connection-discover"].tap()

        let modelScroll = app.scrollViews["model-choice-scroll"]
        XCTAssertTrue(modelScroll.waitForExistence(timeout: 5))
        let tailModel = app.buttons["model-choice-gpt-fixture-tail"]
        reveal(tailModel, in: modelScroll, swiping: .up, maxSwipes: 30)
        XCTAssertEqual(tailModel.value as? String, "未选择")
        tailModel.tap()
        let nameField = app.textFields["model-connection-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("我的测试连接")
        app.buttons["model-connection-save-current"].tap()

        let currentHeader = app.staticTexts["current-model-connection-header"]
        XCTAssertTrue(currentHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(currentHeader.label.contains("我的测试连接"))
        XCTAssertTrue(currentHeader.label.contains("gpt-fixture-tail"))
        assertEventuallyDisappears(
            app.descendants(matching: .any)["model-connection-setup-card"]
        )
        XCTAssertTrue(app.staticTexts["你：" + userText].exists)
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", secret)).count,
            0
        )
        XCTAssertFalse(sendButton.isEnabled)
        XCTAssertTrue(composer.isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["welcome-page"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["opening-plan-approval-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["last-tool-receipt"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["chapter-review-card"].exists)

        relaunchWithoutFixturePreservingDatabaseScope(app)

        XCTAssertTrue(app.staticTexts["你：" + userText].waitForExistence(timeout: 10))
        let restoredCurrent = app.staticTexts["current-model-connection-header"]
        XCTAssertTrue(restoredCurrent.waitForExistence(timeout: 5))
        XCTAssertTrue(restoredCurrent.label.contains("我的测试连接"))
        XCTAssertTrue(restoredCurrent.label.contains("gpt-fixture-tail"))
        XCTAssertFalse(app.staticTexts["model-connection-resume-notice"].exists)
        XCTAssertFalse(
            app.descendants(matching: .any)["model-connection-setup-card"].exists
        )
        XCTAssertFalse(app.buttons["agent-send-button"].isEnabled)
        XCTAssertTrue(app.textViews["agent-composer"].isEnabled)
        XCTAssertFalse(app.descendants(matching: .any)["welcome-page"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["opening-plan-approval-card"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["last-tool-receipt"].exists)
    }

    func testS2OfflineQueueAndStreamingPauseRemainControllableAcrossConversations() {
        let app = makeIsolatedApp(fixture: "s2-task-lifecycle")
        launchWithDeterministicTimestampSetting(app)

        let composer = app.textViews["agent-composer"]
        let sendButton = app.buttons["agent-send-button"]
        let newConversationButton = app.buttons["new-conversation-button"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(sendButton.exists)
        XCTAssertTrue(newConversationButton.exists)
        XCTAssertTrue(app.buttons["ui-test-network-available"].isEnabled)

        composer.tap()
        composer.typeText("ui-offline-primary")
        sendButton.tap()
        XCTAssertTrue(
            app.staticTexts["你：ui-offline-primary"]
                .waitForExistence(timeout: 5)
        )

        newConversationButton.tap()
        let status = app.staticTexts["agent-business-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertNotEqual(
            status.label,
            "当前只验证界面、导航和本地保存，尚未接入真正的模型任务"
        )
        composer.tap()
        composer.typeText("ui-offline-queued")
        sendButton.tap()

        app.buttons["activity-bar-tasks"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["ai-tasks-page"]
                .waitForExistence(timeout: 5)
        )
        assertEventually(
            app.staticTexts["ai-task-doing"],
            hasLabel: "这条请求已经保存，尚未发送"
        )
        XCTAssertEqual(
            app.staticTexts["ai-task-needs-user"].label,
            "需要你确认是否发送"
        )
        XCTAssertFalse(app.buttons["ai-task-resume-button"].exists)

        app.buttons["ai-tasks-back-button"].tap()
        app.buttons["ui-test-network-available"].tap()
        app.buttons["activity-bar-tasks"].tap()

        let confirm = app.buttons["ai-task-resume-button"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "确认发送")
        confirm.tap()
        assertEventually(
            app.staticTexts["ai-task-doing"],
            hasLabel: "仓颉正在处理并返回结果"
        )

        let pause = app.buttons["ai-task-pause-button"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        assertEventually(
            app.staticTexts["ai-task-doing"],
            hasLabel: "正在确认刚才的请求是否已经停止"
        )
        XCTAssertFalse(app.buttons["ai-task-resume-button"].exists)
        XCTAssertFalse(app.buttons["ai-task-discard-button"].exists)
        let keep = app.buttons["ai-task-keep-button"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()

        assertEventually(
            app.staticTexts["ai-task-doing"],
            hasLabel: "这条请求已经保存，尚未发送"
        )
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        assertEventually(
            app.staticTexts["ai-task-doing"],
            hasLabel: "这件事已经处理完成"
        )
    }

    func testS2BackgroundUnknownCanEndKeepingEvidenceWithoutResend() {
        let app = makeIsolatedApp(fixture: "s2-task-lifecycle")
        launchWithDeterministicTimestampSetting(app)
        app.buttons["ui-test-network-available"].tap()

        let composer = app.textViews["agent-composer"]
        composer.tap()
        composer.typeText("ui-streaming-pause-background")
        app.buttons["agent-send-button"].tap()
        XCTAssertTrue(
            app.staticTexts["仓颉：可暂停任务正在流式返回"]
                .waitForExistence(timeout: 5)
        )

        XCUIDevice.shared.press(.home)
        assertEventuallyEntersBackground(app)
        relaunchWithoutFixturePreservingDatabaseScope(app)
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-landscape-columns"]
                .waitForExistence(timeout: 10)
        )
        app.buttons["activity-bar-tasks"].tap()

        let recovery = app.staticTexts["ai-task-recovery-state"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 5))
        XCTAssertEqual(
            recovery.label,
            "结果未知：正在按原请求身份安全对账"
        )
        let keep = app.buttons["ai-task-keep-button"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["ai-task-resume-button"].exists)
        keep.tap()

        assertEventually(
            app.staticTexts["ai-task-doing"],
            hasLabel: "这件事已经结束，已收到内容已保留；原模型最终结果仍未知"
        )
        app.buttons["ai-tasks-back-button"].tap()
        composer.tap()
        composer.typeText("结束未知任务后可以继续输入")
        XCTAssertTrue(app.buttons["agent-send-button"].isEnabled)
    }

    func testScaleFixtureKeepsMidShelfBookVisibleAfterDetailPushAndBack() {
        let app = makeIsolatedApp(fixture: "persisted-scale-and-restore")
        launchWithDeterministicTimestampSetting(app)

        let expectedDraft = "规模测试中仍然保留的草稿"
        let expectedReader = ReadableWorkspaceSnapshot(
            projectTitle: "规模书籍 001",
            chapterTitle: "第一章 灯塔来信",
            body: "夜潮拍打着旧码头，灯塔顶端亮起一封等待多年的回信。"
        )
        let composer = app.textViews["agent-composer"]
        let readerTitle = app.staticTexts["reader-project-title"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 10))
        let selectedConversationBeforeBrowsing = selectedConversationSnapshot(in: app)
        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversationBeforeBrowsing,
            expectedReader: expectedReader
        )
        assertScaleConversationProjection(
            in: app,
            expectedDraft: expectedDraft
        )

        let projectsButton = app.buttons["activity-bar-novels"]
        XCTAssertTrue(projectsButton.exists)
        projectsButton.tap()

        let shelf = app.descendants(matching: .any)["novel-projects-page"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        let expectedBookTitle = "规模书籍 056"
        let targetRow = app.buttons["novel-project-row-55"]
        reveal(targetRow, in: shelf, swiping: .up, maxSwipes: 30)
        XCTAssertTrue(targetRow.label.contains(expectedBookTitle))
        XCTAssertFalse(app.buttons["novel-project-row-0"].isHittable)

        targetRow.tap()
        let detailTitle = app.staticTexts["novel-project-detail-title"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(detailTitle.label, expectedBookTitle)
        app.buttons["novel-project-detail-back-button"].tap()

        let restoredTargetRow = app.buttons["novel-project-row-55"]
        XCTAssertTrue(restoredTargetRow.waitForExistence(timeout: 5))
        XCTAssertTrue(
            restoredTargetRow.isHittable,
            "Returning from detail must preserve the mid-shelf viewport instead of jumping to the top"
        )
        XCTAssertTrue(restoredTargetRow.label.contains(expectedBookTitle))
        XCTAssertFalse(app.buttons["novel-project-row-0"].isHittable)

        restoredTargetRow.tap()
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(detailTitle.label, expectedBookTitle)
        app.buttons["novel-project-detail-back-button"].tap()
        let secondRestoredTargetRow = app.buttons["novel-project-row-55"]
        XCTAssertTrue(secondRestoredTargetRow.waitForExistence(timeout: 5))
        XCTAssertTrue(secondRestoredTargetRow.isHittable)

        app.buttons["novel-projects-back-button"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 5))
        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversationBeforeBrowsing,
            expectedReader: expectedReader
        )
    }

    func testScaleFixtureProjectsOnlyNewestTwoHundredMessagesAndPreservesWorkspaceState() {
        let app = makeIsolatedApp(fixture: "persisted-scale-and-restore")
        launchWithDeterministicTimestampSetting(app)

        let expectedDraft = "规模测试中仍然保留的草稿"
        let expectedReader = ReadableWorkspaceSnapshot(
            projectTitle: "规模书籍 001",
            chapterTitle: "第一章 灯塔来信",
            body: "夜潮拍打着旧码头，灯塔顶端亮起一封等待多年的回信。"
        )
        let composer = app.textViews["agent-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        let selectedConversation = selectedConversationSnapshot(in: app)

        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversation,
            expectedReader: expectedReader
        )
        assertScaleConversationProjection(
            in: app,
            expectedDraft: expectedDraft
        )
        assertScaleConversationWindowEnd(in: app)

        let resultsTab = app.buttons["reader-companion-results-tab"]
        let conversationTab = app.buttons["reader-companion-conversation-tab"]
        XCTAssertTrue(resultsTab.exists)
        resultsTab.tap()
        XCTAssertTrue(app.staticTexts["results-empty-state"].waitForExistence(timeout: 5))
        conversationTab.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversation,
            expectedReader: expectedReader
        )

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(
            app.descendants(matching: .any)["workspace-portrait-single-focus"]
                .waitForExistence(timeout: 5)
        )
        assertPortraitPrimaryFocus(in: app, selected: "conversation")
        XCTAssertEqual(
            app.textViews["agent-composer"].value as? String,
            expectedDraft
        )

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(
            app.descendants(matching: .any)["reader-companion-conversation"]
                .waitForExistence(timeout: 5)
        )
        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversation,
            expectedReader: expectedReader
        )

        app.buttons["activity-bar-novels"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["novel-projects-page"]
                .waitForExistence(timeout: 5)
        )
        app.buttons["novel-projects-back-button"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversation,
            expectedReader: expectedReader
        )

        relaunchWithoutFixturePreservingDatabaseScope(app)

        XCTAssertTrue(app.staticTexts["reader-project-title"].waitForExistence(timeout: 10))
        assertScaleWorkspaceState(
            in: app,
            expectedDraft: expectedDraft,
            selectedConversation: selectedConversation,
            expectedReader: expectedReader
        )
        assertScaleConversationProjection(
            in: app,
            expectedDraft: expectedDraft
        )
        assertScaleConversationWindowEnd(in: app)
    }

    func testReadableFixtureRelaunchRestoresReaderDraftConversationAndActiveContentWithoutReseeding() {
        let app = makeIsolatedApp(fixture: "persisted-readable-two-books")
        launchWithDeterministicTimestampSetting(app)

        let expectedDraft = "下一步想让主角先不开门"
        let expectedReaderTitle = "雾城守夜人"
        let expectedChapterTitle = "第一章 山门夜响"
        let expectedBody = "雨落在石阶上。\n\n封闭十年的山门忽然响了三声。"
        XCTAssertTrue(app.staticTexts["reader-project-title"].waitForExistence(timeout: 10))

        let messagesBeforeRelaunch = conversationMessageLabels(in: app)
        let selectedBeforeRelaunch = selectedConversationSnapshot(in: app)
        let readerBeforeRelaunch = readableWorkspaceSnapshot(in: app)

        assertReadableWorkspace(
            in: app,
            draft: expectedDraft,
            projectTitle: expectedReaderTitle,
            chapterTitle: expectedChapterTitle,
            body: expectedBody
        )
        assertTwoBookFixtureCardinality(in: app)

        relaunchWithoutFixturePreservingDatabaseScope(app)

        XCTAssertTrue(app.staticTexts["reader-project-title"].waitForExistence(timeout: 10))
        assertReadableWorkspace(
            in: app,
            draft: expectedDraft,
            projectTitle: expectedReaderTitle,
            chapterTitle: expectedChapterTitle,
            body: expectedBody
        )
        XCTAssertEqual(conversationMessageLabels(in: app), messagesBeforeRelaunch)
        XCTAssertEqual(selectedConversationSnapshot(in: app), selectedBeforeRelaunch)
        XCTAssertEqual(readableWorkspaceSnapshot(in: app), readerBeforeRelaunch)
        assertTwoBookFixtureCardinality(in: app)
    }

    private let conversationTimestampDefaultsKey = "s1.showsConversationTimestamps"

    func testReadableChapterUsesTwoRegionWorkspaceAndBrowsingAnotherBookDoesNotStealFocus() {
        let app = makeIsolatedApp(fixture: "persisted-readable-two-books")
        launchWithDeterministicTimestampSetting(app)

        let primaryDraft = "下一步想让主角先不开门"
        let readerTitle = app.staticTexts["reader-project-title"]
        let readerChapterTitle = app.staticTexts["reader-chapter-title"]
        let readerBody = app.staticTexts["reader-body"]
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 10))
        XCTAssertEqual(readerTitle.label, "雾城守夜人")
        XCTAssertTrue(readerChapterTitle.exists)
        XCTAssertTrue(readerBody.exists)
        let primaryChapterTitle = readerChapterTitle.label
        let primaryBody = readerBody.label

        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "workspace-landscape-columns").count,
            1
        )
        let landscapeReaderRegion = app.descendants(matching: .any)["landscape-reader-region"]
        let companionRegion = app.descendants(matching: .any)["reader-companion-region"]
        XCTAssertTrue(landscapeReaderRegion.exists)
        XCTAssertTrue(companionRegion.exists)
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "landscape-reader-region").count,
            1
        )
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "reader-companion-region").count,
            1
        )
        let readableWorkspaceWidth = landscapeReaderRegion.frame.width + companionRegion.frame.width
        XCTAssertGreaterThan(readableWorkspaceWidth, 0)
        XCTAssertEqual(
            landscapeReaderRegion.frame.width / readableWorkspaceWidth,
            0.66,
            accuracy: 0.03
        )
        XCTAssertEqual(
            companionRegion.frame.width / readableWorkspaceWidth,
            0.34,
            accuracy: 0.03
        )
        XCTAssertFalse(app.descendants(matching: .any)["landscape-conversation-region"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["landscape-results-region"].exists)

        let composer = app.textViews["agent-composer"]
        XCTAssertEqual(composer.value as? String, primaryDraft)
        let messagesBeforeResults = conversationMessageLabels(in: app)
        let selectedConversationBeforeResults = selectedConversationSnapshot(in: app)
        assertReaderCompanionSelection(in: app, showingResults: false)

        app.buttons["reader-companion-results-tab"].tap()
        XCTAssertTrue(app.staticTexts["results-empty-state"].waitForExistence(timeout: 5))
        assertReaderCompanionSelection(in: app, showingResults: true)
        app.buttons["reader-companion-conversation-tab"].tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        assertReaderCompanionSelection(in: app, showingResults: false)

        XCTAssertEqual(composer.value as? String, primaryDraft)
        XCTAssertEqual(conversationMessageLabels(in: app), messagesBeforeResults)
        XCTAssertEqual(selectedConversationSnapshot(in: app), selectedConversationBeforeResults)
        XCTAssertEqual(readerTitle.label, "雾城守夜人")
        XCTAssertEqual(readerChapterTitle.label, primaryChapterTitle)
        XCTAssertEqual(readerBody.label, primaryBody)

        app.buttons["activity-bar-novels"].tap()
        let browsedBook = app.buttons["novel-project-row-0"]
        XCTAssertTrue(browsedBook.waitForExistence(timeout: 5))
        XCTAssertTrue(browsedBook.label.contains("另一座城"))
        browsedBook.tap()
        XCTAssertEqual(app.staticTexts["novel-project-detail-title"].label, "另一座城")

        let openReader = app.buttons["novel-project-detail-open-reader"]
        XCTAssertTrue(openReader.waitForExistence(timeout: 5))
        openReader.tap()

        let browserReader = app.descendants(matching: .any)["novel-project-browser-reader"]
        XCTAssertTrue(browserReader.waitForExistence(timeout: 5))
        let browsedProjectTitle = browserReader.staticTexts[
            "novel-project-browser-reader-project-title"
        ]
        let browsedChapterTitle = browserReader.staticTexts[
            "novel-project-browser-reader-chapter-title"
        ]
        let browsedStatus = browserReader.staticTexts[
            "novel-project-browser-reader-status"
        ]
        let browsedBody = browserReader.staticTexts[
            "novel-project-browser-reader-body"
        ]
        XCTAssertTrue(browsedProjectTitle.exists)
        XCTAssertEqual(browsedProjectTitle.label, "另一座城")
        XCTAssertTrue(browsedChapterTitle.exists)
        XCTAssertEqual(browsedChapterTitle.label, "第三章 雾港来信")
        XCTAssertTrue(browsedStatus.exists)
        XCTAssertEqual(browsedStatus.label, "这一章正在等你阅读")
        XCTAssertTrue(browsedBody.exists)
        XCTAssertEqual(browsedBody.label, "潮声越过旧城墙，一封没有署名的信落在灯下。")
        XCTAssertFalse(app.descendants(matching: .any)["landscape-conversation-region"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["landscape-results-region"].exists)

        let browserReaderBackButton = app.buttons["novel-project-browser-reader-back-button"]
        XCTAssertTrue(browserReaderBackButton.waitForExistence(timeout: 5))
        browserReaderBackButton.tap()
        XCTAssertEqual(app.staticTexts["novel-project-detail-title"].label, "另一座城")
        app.buttons["novel-project-detail-back-button"].tap()
        app.buttons["novel-projects-back-button"].tap()

        XCTAssertTrue(readerTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(readerTitle.label, "雾城守夜人")
        XCTAssertEqual(readerChapterTitle.label, primaryChapterTitle)
        XCTAssertEqual(readerBody.label, primaryBody)
        XCTAssertEqual(composer.value as? String, primaryDraft)
        XCTAssertEqual(conversationMessageLabels(in: app), messagesBeforeResults)
        XCTAssertEqual(selectedConversationSnapshot(in: app), selectedConversationBeforeResults)
        XCTAssertFalse(browserReader.exists)
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "landscape-reader-region").count,
            1
        )
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(identifier: "reader-companion-region").count,
            1
        )
        XCTAssertFalse(app.descendants(matching: .any)["landscape-conversation-region"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["landscape-results-region"].exists)
    }

    func testPortraitReadableWorkspaceOffersReadingConversationAndResultsWithoutLosingDraft() {
        XCUIDevice.shared.orientation = .portrait
        let app = makeIsolatedApp(fixture: "persisted-readable-two-books")
        launchWithDeterministicTimestampSetting(app)

        let readerTab = app.buttons["portrait-focus-reader"]
        let conversationTab = app.buttons["portrait-focus-conversation"]
        let resultsTab = app.buttons["portrait-focus-results"]
        XCTAssertTrue(readerTab.waitForExistence(timeout: 10))
        XCTAssertTrue(conversationTab.exists)
        XCTAssertTrue(resultsTab.exists)
        assertPortraitPrimaryFocus(in: app, selected: "conversation")

        let composer = app.textViews["agent-composer"]
        let draftBeforeResults = composer.value as? String
        let messagesBeforeResults = conversationMessageLabels(in: app)
        readerTab.tap()
        assertPortraitPrimaryFocus(in: app, selected: "reader")
        let readerTitle = app.staticTexts["reader-project-title"]
        let readerChapterTitle = app.staticTexts["reader-chapter-title"]
        let readerBody = app.staticTexts["reader-body"]
        XCTAssertTrue(readerTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(readerTitle.label, "雾城守夜人")
        let titleBeforeResults = readerTitle.label
        let chapterTitleBeforeResults = readerChapterTitle.label
        let bodyBeforeResults = readerBody.label

        resultsTab.tap()
        assertPortraitPrimaryFocus(in: app, selected: "results")
        XCTAssertTrue(app.staticTexts["results-empty-state"].waitForExistence(timeout: 5))

        conversationTab.tap()
        assertPortraitPrimaryFocus(in: app, selected: "conversation")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertEqual(composer.value as? String, draftBeforeResults)
        XCTAssertEqual(conversationMessageLabels(in: app), messagesBeforeResults)

        readerTab.tap()
        assertPortraitPrimaryFocus(in: app, selected: "reader")
        XCTAssertEqual(readerTitle.label, titleBeforeResults)
        XCTAssertEqual(readerChapterTitle.label, chapterTitleBeforeResults)
        XCTAssertEqual(readerBody.label, bodyBeforeResults)

        conversationTab.tap()
        assertPortraitPrimaryFocus(in: app, selected: "conversation")
        XCTAssertEqual(composer.value as? String, "下一步想让主角先不开门")
    }

    private struct SelectedConversationSnapshot: Equatable {
        let count: Int
        let label: String
    }

    private struct ReadableWorkspaceSnapshot: Equatable {
        let projectTitle: String
        let chapterTitle: String
        let body: String
    }

    private func conversationMessageLabels(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [String] {
        XCTAssertTrue(
            app.staticTexts["conversation-message-0"].waitForExistence(timeout: 5),
            "Expected the first projected conversation message",
            file: file,
            line: line
        )
        let messages = app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "conversation-message-")
        )
        let count = messages.count
        XCTAssertGreaterThan(count, 0, "Expected visible conversation messages", file: file, line: line)

        return (0..<count).map { index in
            let message = app.staticTexts["conversation-message-\(index)"]
            XCTAssertTrue(
                message.exists,
                "Expected conversation-message-\(index) to exist",
                file: file,
                line: line
            )
            return message.label
        }
    }

    private func selectedConversationSnapshot(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SelectedConversationSnapshot {
        let selectedConversations = app.buttons.matching(
            NSPredicate(format: "value == %@", "当前对话")
        )
        XCTAssertEqual(
            selectedConversations.count,
            1,
            "Expected exactly one visible selected conversation",
            file: file,
            line: line
        )
        return SelectedConversationSnapshot(
            count: selectedConversations.count,
            label: selectedConversations.firstMatch.label
        )
    }

    private func readableWorkspaceSnapshot(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> ReadableWorkspaceSnapshot {
        let projectTitle = app.staticTexts["reader-project-title"]
        let chapterTitle = app.staticTexts["reader-chapter-title"]
        let body = app.staticTexts["reader-body"]
        XCTAssertTrue(projectTitle.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(chapterTitle.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(body.waitForExistence(timeout: 5), file: file, line: line)
        return ReadableWorkspaceSnapshot(
            projectTitle: projectTitle.label,
            chapterTitle: chapterTitle.label,
            body: body.label
        )
    }

    private func assertScaleWorkspaceState(
        in app: XCUIApplication,
        expectedDraft: String,
        selectedConversation: SelectedConversationSnapshot,
        expectedReader: ReadableWorkspaceSnapshot,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            app.textViews["agent-composer"].value as? String,
            expectedDraft,
            file: file,
            line: line
        )
        XCTAssertEqual(
            selectedConversationSnapshot(in: app, file: file, line: line),
            selectedConversation,
            file: file,
            line: line
        )
        XCTAssertEqual(
            readableWorkspaceSnapshot(in: app, file: file, line: line),
            expectedReader,
            file: file,
            line: line
        )
    }

    private func assertScaleConversationProjection(
        in app: XCUIApplication,
        expectedDraft: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            app.textViews["agent-composer"].value as? String,
            expectedDraft,
            file: file,
            line: line
        )
        let historyNotice = app.staticTexts["conversation-history-window-notice"]
        XCTAssertTrue(historyNotice.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(
            historyNotice.label,
            "已显示最近的对话，更早内容会在后续滚动加载。",
            file: file,
            line: line
        )
        let firstMessage = app.staticTexts["conversation-message-0"]
        XCTAssertTrue(firstMessage.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(
            firstMessage.label,
            "你：长对话消息 041",
            file: file,
            line: line
        )
    }

    private func assertScaleConversationWindowEnd(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let conversationRegion = app.descendants(matching: .any)["reader-companion-conversation"]
        XCTAssertTrue(conversationRegion.waitForExistence(timeout: 5), file: file, line: line)
        let messageScroll = conversationRegion.scrollViews.firstMatch
        XCTAssertTrue(messageScroll.exists, file: file, line: line)

        let newestMessage = app.staticTexts["conversation-message-199"]
        reveal(
            newestMessage,
            in: messageScroll,
            swiping: .up,
            maxSwipes: 40,
            file: file,
            line: line
        )
        XCTAssertEqual(
            app.staticTexts["conversation-message-198"].label,
            "你：长对话消息 239",
            file: file,
            line: line
        )
        XCTAssertEqual(
            newestMessage.label,
            "你：长对话消息 240",
            file: file,
            line: line
        )
        XCTAssertFalse(
            app.staticTexts["conversation-message-200"].exists,
            "The projected conversation window must not expose index 200",
            file: file,
            line: line
        )
    }

    private func assertReadableWorkspace(
        in app: XCUIApplication,
        draft: String,
        projectTitle: String,
        chapterTitle: String,
        body: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(app.textViews["agent-composer"].value as? String, draft, file: file, line: line)
        XCTAssertEqual(app.staticTexts["reader-project-title"].label, projectTitle, file: file, line: line)
        XCTAssertEqual(app.staticTexts["reader-chapter-title"].label, chapterTitle, file: file, line: line)
        XCTAssertEqual(app.staticTexts["reader-body"].label, body, file: file, line: line)
    }

    private func assertTwoBookFixtureCardinality(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.buttons["conversation-row-0"].exists, file: file, line: line)
        XCTAssertTrue(app.buttons["conversation-row-1"].exists, file: file, line: line)
        XCTAssertFalse(app.buttons["conversation-row-2"].exists, file: file, line: line)

        app.buttons["activity-bar-novels"].tap()
        let secondaryBook = app.buttons["novel-project-row-0"]
        let primaryBook = app.buttons["novel-project-row-1"]
        XCTAssertTrue(secondaryBook.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(primaryBook.exists, file: file, line: line)
        XCTAssertTrue(secondaryBook.label.contains("另一座城"), file: file, line: line)
        XCTAssertTrue(primaryBook.label.contains("雾城守夜人"), file: file, line: line)
        XCTAssertFalse(app.buttons["novel-project-row-2"].exists, file: file, line: line)
        app.buttons["novel-projects-back-button"].tap()
        XCTAssertTrue(app.textViews["agent-composer"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func assertReaderCompanionSelection(
        in app: XCUIApplication,
        showingResults: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let conversationContent = app.descendants(matching: .any)[
            "reader-companion-conversation"
        ]
        let resultsContent = app.descendants(matching: .any)["reader-companion-results"]
        let conversationTab = app.buttons["reader-companion-conversation-tab"]
        let resultsTab = app.buttons["reader-companion-results-tab"]

        XCTAssertEqual(conversationContent.exists, !showingResults, file: file, line: line)
        XCTAssertEqual(resultsContent.exists, showingResults, file: file, line: line)
        XCTAssertEqual(
            conversationTab.value as? String,
            showingResults ? "未选择" : "当前页面",
            file: file,
            line: line
        )
        XCTAssertEqual(
            resultsTab.value as? String,
            showingResults ? "当前页面" : "未选择",
            file: file,
            line: line
        )
    }

    private func assertPortraitPrimaryFocus(
        in app: XCUIApplication,
        selected selectedFocus: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let focuses = ["reader", "conversation", "results"]
        for focus in focuses {
            let shouldBeVisible = focus == selectedFocus
            XCTAssertEqual(
                app.descendants(matching: .any)["portrait-\(focus)-region"].exists,
                shouldBeVisible,
                "Expected portrait-\(focus)-region visibility to be \(shouldBeVisible)",
                file: file,
                line: line
            )
            XCTAssertEqual(
                app.buttons["portrait-focus-\(focus)"].value as? String,
                shouldBeVisible ? "当前页面" : "未选择",
                file: file,
                line: line
            )
        }

        let selectedTabs = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "portrait-focus-", "当前页面")
        )
        XCTAssertEqual(selectedTabs.count, 1, file: file, line: line)
    }

    private func makeIsolatedApp(fixture: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CANGJIE_UI_TEST_DATABASE_SCOPE"] = UUID().uuidString
        if let fixture {
            app.launchEnvironment["CANGJIE_UI_TEST_FIXTURE"] = fixture
        }
        return app
    }

    private func launchWithDeterministicTimestampSetting(
        _ app: XCUIApplication,
        showsTimestamps: Bool = true
    ) {
        configureTimestampLaunchOverride(on: app, value: showsTimestamps)
        app.launch()
    }

    private func launchPreservingTimestampSetting(_ app: XCUIApplication) {
        configureTimestampLaunchOverride(on: app, value: nil)
        app.launch()
    }

    private func relaunchWithoutFixturePreservingDatabaseScope(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let databaseScope = app.launchEnvironment["CANGJIE_UI_TEST_DATABASE_SCOPE"] else {
            XCTFail("Fixture relaunch requires an existing isolated database scope", file: file, line: line)
            return
        }

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "CANGJIE_UI_TEST_FIXTURE")
        XCTAssertNil(
            app.launchEnvironment["CANGJIE_UI_TEST_FIXTURE"],
            file: file,
            line: line
        )
        XCTAssertEqual(
            app.launchEnvironment["CANGJIE_UI_TEST_DATABASE_SCOPE"],
            databaseScope,
            "Relaunch must reuse the original database scope",
            file: file,
            line: line
        )
        launchPreservingTimestampSetting(app)
    }

    private func configureTimestampLaunchOverride(
        on app: XCUIApplication,
        value: Bool?
    ) {
        let keyArgument = "-\(conversationTimestampDefaultsKey)"
        var arguments = app.launchArguments

        while let keyIndex = arguments.firstIndex(of: keyArgument) {
            arguments.remove(at: keyIndex)
            if keyIndex < arguments.endIndex {
                arguments.remove(at: keyIndex)
            }
        }

        if let value {
            arguments.append(contentsOf: [keyArgument, value ? "YES" : "NO"])
        }
        app.launchArguments = arguments
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

    private func assertEventuallyEntersBackground(
        _ app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let application = object as? XCUIApplication else {
                    return false
                }
                return application.state == .runningBackground
                    || application.state == .runningBackgroundSuspended
            },
            object: app
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected the app to enter background, got \(app.state)",
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

    private func assertEventually(
        _ element: XCUIElement,
        hasKeyboardFocus expectedValue: Bool,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "hasKeyboardFocus == %@",
                NSNumber(value: expectedValue)
            ),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected keyboard focus to become \(expectedValue)",
            file: file,
            line: line
        )
    }

    private func assertEventually(
        _ element: XCUIElement,
        hasValue expectedValue: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Expected value \(expectedValue), got \(String(describing: element.value))",
            file: file,
            line: line
        )
    }

    private func tapSwitchControl(_ element: XCUIElement) {
        // SwiftUI List toggles can expose the row as the switch frame; target the trailing control.
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
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
