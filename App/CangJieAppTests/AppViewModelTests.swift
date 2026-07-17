import XCTest
@testable import CangJie

final class AppViewModelTests: XCTestCase {
    private enum StubDatabaseError: Error {
        case openFailed
    }

    private struct StubSecretRepository: SecretRepository {
        func save(_ secret: String, account: String) throws {}
        func read(account: String) throws -> String? { nil }
        func contains(account: String) throws -> Bool { false }
        func delete(account: String) throws {}
    }

    private final class InMemorySecretRepository: SecretRepository {
        private var values: [String: String] = [:]

        func save(_ secret: String, account: String) throws {
            values[account] = secret
        }

        func read(account: String) throws -> String? {
            values[account]
        }

        func contains(account: String) throws -> Bool {
            values[account] != nil
        }

        func delete(account: String) throws {
            values = values.filter { $0.key != account }
        }
    }

    @MainActor
    func testProvidedDatabaseSkipsDefaultFactoryAndRemainsUsable() throws {
        try withDatabase { database in
            try database.saveDraft("existing draft", now: Date(timeIntervalSince1970: 1_000))
            var factoryCalls = 0

            let viewModel = AppViewModel(
                database: database,
                databaseFactory: {
                    factoryCalls += 1
                    XCTFail("Default database factory must not run when a database is provided")
                    return database
                },
                keychain: StubSecretRepository()
            )

            XCTAssertEqual(factoryCalls, 0)
            XCTAssertEqual(viewModel.draft, "existing draft")
            XCTAssertEqual(viewModel.businessStatus, "Waiting for a novel idea")
            XCTAssertTrue(viewModel.transientNotice?.message.hasPrefix("SQLite ready") == true)

            viewModel.draft = "updated draft"
            viewModel.saveDraft()

            XCTAssertEqual(try database.loadDraft()?.content, "updated draft")
            let saveMessage = try XCTUnwrap(viewModel.transientNotice?.message)
            XCTAssertTrue(saveMessage.hasPrefix("Draft saved | "))
            XCTAssertEqual(saveMessage.filter { $0 == "|" }.count, 1)
            XCTAssertFalse(saveMessage.contains("?"))
        }
    }

    @MainActor
    func testKeychainProbeVerifiesCreateReadUpdateAndDeleteWithoutPublishingSecret() throws {
        try withDatabase { database in
            let keychain = InMemorySecretRepository()
            let viewModel = AppViewModel(database: database, keychain: keychain)

            XCTAssertFalse(viewModel.hasStoredKey)
            XCTAssertNil(viewModel.keychainProbeDigest)

            viewModel.apiKeyInput = "first-sensitive-probe"
            viewModel.saveProbeKey()

            XCTAssertTrue(viewModel.hasStoredKey)
            let firstDigest = try XCTUnwrap(viewModel.keychainProbeDigest)
            XCTAssertEqual(firstDigest.count, 12)
            XCTAssertFalse(viewModel.transientNotice?.message.contains("first-sensitive-probe") == true)
            XCTAssertEqual(try keychain.read(account: "m0-probe"), "first-sensitive-probe")

            viewModel.apiKeyInput = "updated-sensitive-probe"
            viewModel.saveProbeKey()

            let updatedDigest = try XCTUnwrap(viewModel.keychainProbeDigest)
            XCTAssertNotEqual(updatedDigest, firstDigest)
            XCTAssertEqual(try keychain.read(account: "m0-probe"), "updated-sensitive-probe")

            viewModel.readProbeKey()
            XCTAssertEqual(viewModel.keychainProbeDigest, updatedDigest)
            XCTAssertFalse(viewModel.transientNotice?.message.contains("updated-sensitive-probe") == true)

            viewModel.deleteProbeKey()

            XCTAssertFalse(viewModel.hasStoredKey)
            XCTAssertNil(viewModel.keychainProbeDigest)
            XCTAssertNil(try keychain.read(account: "m0-probe"))
        }
    }

    @MainActor
    func testMissingDatabaseInvokesDefaultFactoryExactlyOnce() throws {
        try withDatabase { database in
            var factoryCalls = 0

            let viewModel = AppViewModel(
                databaseFactory: {
                    factoryCalls += 1
                    return database
                },
                keychain: StubSecretRepository()
            )

            XCTAssertEqual(factoryCalls, 1)
            XCTAssertEqual(viewModel.draft, "")
            XCTAssertEqual(viewModel.businessStatus, "Waiting for a novel idea")
            XCTAssertTrue(viewModel.transientNotice?.message.hasPrefix("SQLite ready") == true)
        }
    }

    @MainActor
    func testDefaultDatabaseFailureFailsClosedWithoutRetry() {
        var factoryCalls = 0
        let viewModel = AppViewModel(
            databaseFactory: {
                factoryCalls += 1
                throw StubDatabaseError.openFailed
            },
            keychain: StubSecretRepository()
        )

        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(viewModel.status.contains("DB-INIT"))
        XCTAssertEqual(viewModel.draft, "")

        viewModel.saveDraft()
        viewModel.createCheckpoint(reason: "test")

        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(viewModel.status.contains("DB-INIT"))
    }


    @MainActor
    func testAgentCreationMessageExecutesProjectToolAndClearsComposer() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())

            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()

            XCTAssertEqual(viewModel.draft, "")
            XCTAssertEqual(viewModel.projects.count, 1)
            XCTAssertEqual(viewModel.projects.first?.premise, "create a cultivation novel")
            XCTAssertEqual(viewModel.status, "Verified: project.create")
            XCTAssertTrue(viewModel.conversationMessages.contains { $0.contains("Project created") })
        }
    }


    @MainActor
    func testStrategicInterviewProducesAndApprovesPersistentPlan() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())

            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            viewModel.draft = "A disgraced courier discovers a forbidden inheritance"
            viewModel.sendAgentMessage()
            viewModel.draft = "He wants to save his sister before the sect trial"
            viewModel.sendAgentMessage()
            viewModel.draft = "Every use of the inheritance erases one memory"
            viewModel.sendAgentMessage()

            let displayed = try XCTUnwrap(viewModel.openingPlanApproval)
            XCTAssertTrue(viewModel.planAwaitingApproval)
            XCTAssertFalse(viewModel.planBody.isEmpty)
            XCTAssertEqual(displayed.status, .pending)
            XCTAssertEqual(try database.countArtifacts(kind: "openingPlan"), 1)

            let approved = viewModel.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )

            XCTAssertTrue(approved)
            XCTAssertFalse(viewModel.planAwaitingApproval)
            XCTAssertEqual(viewModel.openingPlanApproval?.status, .approved)
            XCTAssertEqual(try database.approvalRequest(id: displayed.id)?.status, .approved)
            XCTAssertEqual(try database.countArtifacts(kind: "openingPlan"), 1)
            XCTAssertEqual(
                try database.latestArtifact(kind: "openingPlan")?.id,
                displayed.artifactID
            )
        }
    }


    @MainActor
    func testApproveOpeningPlanRejectsWrongRequestAndPublishesVisibleError() throws {
        try withDatabase { database in
            let (viewModel, displayed) = try makeOpeningPlanApprovalViewModel(database: database)

            let approved = viewModel.approveOpeningPlan(
                requestID: UUID(),
                displayedBindingHash: displayed.bindingHash
            )

            XCTAssertFalse(approved)
            XCTAssertEqual(viewModel.openingPlanApproval, displayed)
            XCTAssertTrue(viewModel.planAwaitingApproval)
            XCTAssertTrue(viewModel.errorMessage?.contains("AGENT-APPROVAL-STALE") == true)
        }
    }

    @MainActor
    func testApproveOpeningPlanRejectsBindingMismatchAndPublishesVisibleError() throws {
        try withDatabase { database in
            let (viewModel, displayed) = try makeOpeningPlanApprovalViewModel(database: database)

            let approved = viewModel.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash + "-mismatch"
            )

            XCTAssertFalse(approved)
            XCTAssertEqual(viewModel.openingPlanApproval, displayed)
            XCTAssertTrue(viewModel.planAwaitingApproval)
            XCTAssertTrue(viewModel.errorMessage?.contains("AGENT-APPROVAL-STALE") == true)
        }
    }

    @MainActor
    func testApproveOpeningPlanRejectsExpiredRequestAndPublishesVisibleError() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Expiring plan", premise: "P")
            let savedAt = Date()
            let saved = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: project.id,
                title: "Opening plan",
                body: "A plan whose displayed approval expires before the action.",
                idempotencyKey: "opening.save.expiring-view-model",
                now: savedAt,
                expiresAt: savedAt.addingTimeInterval(2)
            )
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: project.id,
                    interviewStep: AgentRuntime.interviewQuestions.count,
                    currentQuestion: "",
                    interviewAnswers: ["Hook", "Goal", "Cost"],
                    updatedAt: savedAt
                ),
                conversationID: conversation.id
            )

            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            let displayed = try XCTUnwrap(viewModel.openingPlanApproval)
            XCTAssertEqual(displayed.id, saved.approval.id)

            let wait = displayed.expiresAt.timeIntervalSinceNow + 0.1
            XCTAssertGreaterThan(wait, 0)
            XCTAssertLessThan(wait, 3)
            guard wait > 0, wait < 3 else { return }
            Thread.sleep(forTimeInterval: wait)

            let approved = viewModel.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )

            XCTAssertFalse(approved)
            XCTAssertTrue(viewModel.planAwaitingApproval)
            XCTAssertNotEqual(viewModel.openingPlanApproval?.id, displayed.id)
            XCTAssertEqual(viewModel.openingPlanApproval?.status, .pending)
            XCTAssertTrue(viewModel.errorMessage?.contains("AGENT-APPROVAL-EXPIRED") == true)
        }
    }

    @MainActor
    func testApprovalDetailDismissDecisionRequiresSuccessfulMatchingApproval() throws {
        try withDatabase { database in
            let (viewModel, reviewedApproval) = try makeOpeningPlanApprovalViewModel(database: database)
            let approved = viewModel.approveOpeningPlan(
                requestID: reviewedApproval.id,
                displayedBindingHash: reviewedApproval.bindingHash
            )
            let projectedApproval = try XCTUnwrap(viewModel.openingPlanApproval)

            XCTAssertTrue(approved)
            XCTAssertFalse(
                OpeningPlanApprovalDetailView.shouldDismiss(
                    approvalSucceeded: false,
                    projectedApproval: projectedApproval,
                    reviewedApproval: reviewedApproval
                ),
                "A failed action must keep the exact review visible even if projection changes"
            )
            XCTAssertFalse(
                OpeningPlanApprovalDetailView.shouldDismiss(
                    approvalSucceeded: true,
                    projectedApproval: reviewedApproval,
                    reviewedApproval: reviewedApproval
                ),
                "A still-pending projection must not dismiss"
            )
            XCTAssertTrue(
                OpeningPlanApprovalDetailView.shouldDismiss(
                    approvalSucceeded: true,
                    projectedApproval: projectedApproval,
                    reviewedApproval: reviewedApproval
                ),
                "A successful exact approval should dismiss"
            )
        }
    }

    @MainActor
    func testAgentConversationAndInterviewResumeAfterRestart() throws {
        try withDatabase { database in
            let first = AppViewModel(database: database, keychain: StubSecretRepository())
            first.draft = "create a cultivation novel"
            first.sendAgentMessage()
            first.draft = "A disgraced courier inherits a forbidden seal"
            first.sendAgentMessage()
            first.draft = "He must save his sister before the sect trial"
            first.sendAgentMessage()
            first.draft = "Each victory erases one treasured memory"
            first.sendAgentMessage()

            XCTAssertTrue(first.planAwaitingApproval)
            XCTAssertEqual(first.interviewStep, 3)
            let persistedMessages = first.conversationMessages

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertEqual(restored.conversationMessages, persistedMessages)
            XCTAssertEqual(restored.interviewStep, 3)
            XCTAssertTrue(restored.planAwaitingApproval)
            XCTAssertEqual(restored.planBody, first.planBody)
            XCTAssertEqual(restored.lastToolReceipt?.toolID, "artifact.openingPlan.save")
        }
    }

    @MainActor
    func testOpeningPlanApprovalPersistsConversationAndReceiptAcrossRestart() throws {
        try withDatabase { database in
            let first = AppViewModel(database: database, keychain: StubSecretRepository())
            first.draft = "create a cultivation novel"
            first.sendAgentMessage()
            for answer in ["Forbidden seal", "Save his sister", "Lose a memory"] {
                first.draft = answer
                first.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(first.openingPlanApproval)
            first.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertFalse(restored.planAwaitingApproval)
            XCTAssertEqual(restored.openingPlanApproval?.status, .approved)
            XCTAssertEqual(restored.openingPlanApproval?.id, displayed.id)
            XCTAssertEqual(restored.openingPlanApproval?.bindingHash, displayed.bindingHash)
            XCTAssertEqual(restored.lastToolReceipt?.toolID, "artifact.openingPlan.approve")
            XCTAssertTrue(restored.conversationMessages.last?.contains("approved") == true)
        }
    }


    @MainActor
    func testApprovedOpeningPlanIsNotReopenedByTheNextMessage() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            for answer in ["Forbidden seal", "Save his sister", "Lose a memory"] {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(viewModel.openingPlanApproval)
            viewModel.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )

            viewModel.draft = "What happens next?"
            viewModel.sendAgentMessage()

            XCTAssertFalse(viewModel.planAwaitingApproval)
            XCTAssertEqual(viewModel.openingPlanApproval?.status, .approved)
            XCTAssertEqual(try database.countArtifacts(kind: "openingPlan"), 1)
            XCTAssertEqual(viewModel.lastToolReceipt?.toolID, "artifact.openingPlan.approve")
            XCTAssertTrue(viewModel.conversationMessages.last?.contains("Chapter planning") == true)
        }
    }


    @MainActor
    func testApprovedPlanReconcilesAnInterruptedApprovalRun() throws {
        try withDatabase { database in
            let first = AppViewModel(database: database, keychain: StubSecretRepository())
            first.draft = "create a cultivation novel"
            first.sendAgentMessage()
            for answer in ["Forbidden seal", "Save his sister", "Lose a memory"] {
                first.draft = answer
                first.sendAgentMessage()
            }

            let displayed = try XCTUnwrap(first.openingPlanApproval)
            let approvalKey = [
                "artifact.openingPlan.approve",
                displayed.id.uuidString,
                displayed.bindingHash
            ].joined(separator: ".")
            let interruptedRun = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .running,
                idempotencyKey: approvalKey,
                currentStage: "openingPlan.approve",
                startedAt: Date(timeIntervalSince1970: 700),
                updatedAt: Date(timeIntervalSince1970: 700)
            )
            try database.saveAgentRun(interruptedRun, conversationID: displayed.conversationID)
            _ = try database.executeOpeningPlanApprovalTool(
                conversationID: displayed.conversationID,
                approvalRequestID: displayed.id,
                displayedBindingHash: displayed.bindingHash,
                idempotencyKey: approvalKey,
                now: Date(timeIntervalSince1970: 800)
            )
            _ = try database.executeArtifactTool(
                conversationID: displayed.conversationID,
                projectID: displayed.projectID,
                toolID: "artifact.note.save",
                kind: "note",
                title: "Unrelated",
                body: "Later receipt",
                status: "saved",
                idempotencyKey: "artifact.note.save.after-approval",
                now: Date(timeIntervalSince1970: 900)
            )

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(try database.agentRun(idempotencyKey: approvalKey)?.status, .completed)
            XCTAssertFalse(restored.planAwaitingApproval)
            XCTAssertEqual(restored.openingPlanApproval?.status, .approved)
            XCTAssertEqual(restored.businessStatus, "Opening plan approved; chapter planning pending")
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 1)
        }
    }


    @MainActor
    func testSceneInactiveCheckpointsDraftWithoutReplacingBusinessStatus() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            for answer in ["Forbidden seal", "Save his sister", "Lose a memory"] {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(viewModel.openingPlanApproval)
            viewModel.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )
            let businessStatus = viewModel.businessStatus

            viewModel.draft = "unsent scene note"
            viewModel.handleScenePhase(.inactive)

            XCTAssertEqual(viewModel.businessStatus, businessStatus)
            XCTAssertEqual(viewModel.transientNotice?.kind, .lifecycle)
            XCTAssertTrue(viewModel.transientNotice?.message.contains("checkpoint") == true)
            XCTAssertNil(viewModel.errorMessage)
            XCTAssertEqual(try database.loadDraft()?.content, "unsent scene note")
        }
    }

    @MainActor
    func testActiveAndBackgroundPhasesKeepAgentBusinessStatus() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            let businessStatus = viewModel.businessStatus

            viewModel.handleScenePhase(.inactive)
            viewModel.handleScenePhase(.background)
            viewModel.handleScenePhase(.active)

            XCTAssertEqual(viewModel.businessStatus, businessStatus)
            XCTAssertEqual(viewModel.transientNotice?.kind, .lifecycle)
            XCTAssertNil(viewModel.errorMessage)
        }
    }

    @MainActor
    func testActivePhaseRestoresApprovedProjectionWithoutRepeatingToolOrMessage() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            for answer in ["Forbidden seal", "Save his sister", "Lose a memory"] {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(viewModel.openingPlanApproval)
            let approvalKey = [
                "artifact.openingPlan.approve",
                displayed.id.uuidString,
                displayed.bindingHash
            ].joined(separator: ".")

            _ = try database.executeOpeningPlanApprovalTool(
                conversationID: displayed.conversationID,
                approvalRequestID: displayed.id,
                displayedBindingHash: displayed.bindingHash,
                idempotencyKey: approvalKey
            )
            let messageCountBeforeRestore = try database.listAgentMessages(
                conversationID: displayed.conversationID
            ).count
            let latestReceiptBeforeRestore = try database.latestToolReceipt(
                conversationID: displayed.conversationID
            )
            XCTAssertEqual(viewModel.openingPlanApproval?.status, .pending)

            viewModel.handleScenePhase(.active)

            XCTAssertEqual(viewModel.openingPlanApproval?.status, .approved)
            XCTAssertFalse(viewModel.planAwaitingApproval)
            XCTAssertEqual(viewModel.businessStatus, "Opening plan approved; chapter planning pending")
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 1)
            XCTAssertEqual(
                try database.latestToolReceipt(conversationID: displayed.conversationID),
                latestReceiptBeforeRestore
            )
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: displayed.conversationID).count,
                messageCountBeforeRestore + 1
            )

            viewModel.handleScenePhase(.active)

            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 1)
            XCTAssertEqual(
                try database.latestToolReceipt(conversationID: displayed.conversationID),
                latestReceiptBeforeRestore
            )
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: displayed.conversationID).count,
                messageCountBeforeRestore + 1
            )
        }
    }

    @MainActor
    func testBuildIdentityReadsBundleInfoWithSafeFallbacks() throws {
        try withDatabase { database in
            let identified = AppViewModel(
                database: database,
                keychain: StubSecretRepository(),
                bundleInfo: [
                    "CFBundleShortVersionString": "1.2.3",
                    "CFBundleVersion": "456",
                    "CangJieGitCommit": "0123456789abcdef"
                ]
            )

            XCTAssertEqual(identified.buildIdentity.version, "1.2.3")
            XCTAssertEqual(identified.buildIdentity.build, "456")
            XCTAssertEqual(identified.buildIdentity.commit, "0123456789ab")
            XCTAssertEqual(
                identified.buildIdentity.displayText,
                "Version 1.2.3 | Build 456 | Commit 0123456789ab"
            )

            let fallback = AppViewModel(
                database: database,
                keychain: StubSecretRepository(),
                bundleInfo: nil
            )
            XCTAssertEqual(
                fallback.buildIdentity.displayText,
                "Version unavailable | Build unavailable | Commit unavailable"
            )
        }
    }

    @MainActor
    func testRestoredApprovedPlanProjectsDurableBusinessStatus() throws {
        try withDatabase { database in
            let first = AppViewModel(database: database, keychain: StubSecretRepository())
            first.draft = "create a cultivation novel"
            first.sendAgentMessage()
            for answer in ["Forbidden seal", "Save his sister", "Lose a memory"] {
                first.draft = answer
                first.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(first.openingPlanApproval)
            first.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )
            first.draft = "unsent note"
            first.handleScenePhase(.inactive)

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(restored.businessStatus, "Opening plan approved; chapter planning pending")
            XCTAssertNil(restored.errorMessage)
        }
    }

    @MainActor
    func testUnchangedProjectRefreshPublishesFeedbackWithoutChangingConversationState() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            viewModel.draft = "keep this unsent"
            let projects = viewModel.projects
            let messages = viewModel.conversationMessages
            let businessStatus = viewModel.businessStatus

            viewModel.reloadProjects()

            XCTAssertEqual(viewModel.projects, projects)
            XCTAssertEqual(viewModel.conversationMessages, messages)
            XCTAssertEqual(viewModel.draft, "keep this unsent")
            XCTAssertEqual(viewModel.businessStatus, businessStatus)
            XCTAssertEqual(viewModel.transientNotice?.kind, .projectRefresh)
            let refreshMessage = try XCTUnwrap(viewModel.transientNotice?.message)
            XCTAssertTrue(refreshMessage.hasPrefix("Projects refreshed | 1 project | "))
            XCTAssertEqual(refreshMessage.filter { $0 == "|" }.count, 2)
            XCTAssertFalse(refreshMessage.contains("?"))
            XCTAssertNil(viewModel.errorMessage)
        }
    }

    @MainActor
    func testDatabaseFailureUsesIndependentErrorChannel() {
        let viewModel = AppViewModel(
            databaseFactory: { throw StubDatabaseError.openFailed },
            keychain: StubSecretRepository()
        )
        let businessStatus = viewModel.businessStatus

        viewModel.reloadProjects()
        viewModel.createCheckpoint(reason: "test")

        XCTAssertEqual(viewModel.businessStatus, businessStatus)
        XCTAssertTrue(viewModel.errorMessage?.contains("DB-") == true)
        XCTAssertNil(viewModel.transientNotice)
    }

    @MainActor
    func testApproveRejectsWhenDisplayedPlanRevisionBecameStale() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            for answer in ["First hook", "First goal", "First cost"] {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let stale = try XCTUnwrap(viewModel.openingPlanApproval)
            let replacement = try database.executeOpeningPlanSaveTool(
                conversationID: stale.conversationID,
                projectID: stale.projectID,
                title: "Opening plan",
                body: "A materially different revision",
                idempotencyKey: "opening.save.replacement",
                expiresAt: Date(timeIntervalSinceNow: 3_600)
            )

            let approved = viewModel.approveOpeningPlan(
                requestID: stale.id,
                displayedBindingHash: stale.bindingHash
            )

            XCTAssertFalse(approved)
            XCTAssertEqual(try database.approvalRequest(id: stale.id)?.status, .invalidated)
            XCTAssertEqual(try database.approvalRequest(id: replacement.approval.id)?.status, .pending)
            XCTAssertEqual(viewModel.openingPlanApproval?.id, replacement.approval.id)
            XCTAssertTrue(viewModel.planAwaitingApproval)
            XCTAssertTrue(viewModel.errorMessage?.contains("STALE") == true)
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 0)
        }
    }

    @MainActor
    func testRepeatedApprovalIsIdempotentWithoutDuplicateMessageOrReceipt() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            viewModel.draft = "create a cultivation novel"
            viewModel.sendAgentMessage()
            for answer in ["One hook", "One goal", "One cost"] {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(viewModel.openingPlanApproval)
            let runtime = try AgentRuntime(database: database)

            _ = try runtime.approveOpeningPlan(
                approvalRequestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )
            _ = try runtime.approveOpeningPlan(
                approvalRequestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )

            let messages = try database.listAgentMessages(conversationID: displayed.conversationID)
            XCTAssertEqual(
                messages.filter { $0.content == "Opening plan approved and persisted. Chapter planning is now unlocked." }.count,
                1
            )
            XCTAssertEqual(try database.countToolReceipts(toolID: "artifact.openingPlan.approve"), 1)
            XCTAssertEqual(try database.countArtifacts(kind: "openingPlan"), 1)
        }
    }

    @MainActor
    func testFocusedProjectRestoresItsPairedOpeningPlanInsteadOfLatestConversationArtifact() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 1_000))
            let firstProject = try database.createProject(
                title: "First project",
                premise: "First premise",
                now: Date(timeIntervalSince1970: 1_001)
            )
            let secondProject = try database.createProject(
                title: "Second project",
                premise: "Second premise",
                now: Date(timeIntervalSince1970: 1_002)
            )
            let approvalExpiration = Date().addingTimeInterval(60 * 60)
            let firstPlan = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: firstProject.id,
                title: "First opening plan",
                body: "FIRST PROJECT PLAN",
                idempotencyKey: "multi-project.first",
                now: Date(timeIntervalSince1970: 1_003),
                expiresAt: approvalExpiration
            )
            _ = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: secondProject.id,
                title: "Second opening plan",
                body: "SECOND PROJECT PLAN",
                idempotencyKey: "multi-project.second",
                now: Date(timeIntervalSince1970: 1_004),
                expiresAt: approvalExpiration
            )
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: firstProject.id,
                    interviewStep: AgentRuntime.interviewQuestions.count,
                    currentQuestion: "",
                    interviewAnswers: ["A", "B", "C"],
                    updatedAt: Date(timeIntervalSince1970: 1_005)
                ),
                conversationID: conversation.id
            )

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(restored.openingPlanApproval?.id, firstPlan.approval.id)
            XCTAssertEqual(restored.openingPlanApproval?.projectID, firstProject.id)
            XCTAssertEqual(restored.planBody, "FIRST PROJECT PLAN")
            XCTAssertFalse(restored.planBody.contains("SECOND PROJECT PLAN"))
        }
    }

    @MainActor
    func testRestoreRecreatesMissingApprovalSuccessMessageExactlyOnce() throws {
        try withDatabase { database in
            let first = AppViewModel(database: database, keychain: StubSecretRepository())
            first.draft = "create a cultivation novel"
            first.sendAgentMessage()
            for answer in ["One hook", "One goal", "One cost"] {
                first.draft = answer
                first.sendAgentMessage()
            }
            let displayed = try XCTUnwrap(first.openingPlanApproval)
            let approvalKey = [
                "artifact.openingPlan.approve",
                displayed.id.uuidString,
                displayed.bindingHash
            ].joined(separator: ".")
            _ = try database.executeOpeningPlanApprovalTool(
                conversationID: displayed.conversationID,
                approvalRequestID: displayed.id,
                displayedBindingHash: displayed.bindingHash,
                idempotencyKey: approvalKey
            )

            _ = AppViewModel(database: database, keychain: StubSecretRepository())
            _ = AppViewModel(database: database, keychain: StubSecretRepository())

            let messages = try database.listAgentMessages(conversationID: displayed.conversationID)
            XCTAssertEqual(
                messages.filter {
                    $0.content == "Opening plan approved and persisted. Chapter planning is now unlocked."
                }.count,
                1
            )
        }
    }

    @MainActor
    func testRestoreDoesNotOverwriteFailedOrCancelledApprovalRuns() throws {
        for terminalStatus in [AgentRunStatus.failed, .cancelled] {
            try withDatabase { database in
                let first = AppViewModel(database: database, keychain: StubSecretRepository())
                first.draft = "create a cultivation novel"
                first.sendAgentMessage()
                for answer in ["One hook", "One goal", "One cost"] {
                    first.draft = answer
                    first.sendAgentMessage()
                }
                let displayed = try XCTUnwrap(first.openingPlanApproval)
                let approvalKey = [
                    "artifact.openingPlan.approve",
                    displayed.id.uuidString,
                    displayed.bindingHash
                ].joined(separator: ".")
                _ = try database.executeOpeningPlanApprovalTool(
                    conversationID: displayed.conversationID,
                    approvalRequestID: displayed.id,
                    displayedBindingHash: displayed.bindingHash,
                    idempotencyKey: approvalKey
                )
                try database.saveAgentRun(
                    AgentRunSnapshot(
                        id: UUID(),
                        kind: "approval",
                        status: terminalStatus,
                        idempotencyKey: approvalKey,
                        currentStage: "openingPlan.approve.interrupted",
                        startedAt: Date(timeIntervalSince1970: 2_000),
                        updatedAt: Date(timeIntervalSince1970: 2_001)
                    ),
                    conversationID: displayed.conversationID
                )

                let restored = AppViewModel(database: database, keychain: StubSecretRepository())

                XCTAssertEqual(try database.agentRun(idempotencyKey: approvalKey)?.status, terminalStatus)
                XCTAssertEqual(restored.openingPlanApproval?.status, .approved)
                XCTAssertEqual(restored.businessStatus, "Opening plan approved; chapter planning pending")
            }
        }
    }

    @MainActor
    func testProjectVersionChangeInvalidatesPendingApprovalAndCreatesNewBinding() throws {
        try withDatabase { database in
            let first = AppViewModel(database: database, keychain: StubSecretRepository())
            first.draft = "create a cultivation novel"
            first.sendAgentMessage()
            for answer in ["One hook", "One goal", "One cost"] {
                first.draft = answer
                first.sendAgentMessage()
            }
            let stale = try XCTUnwrap(first.openingPlanApproval)
            try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE novelProject SET version = version + 1 WHERE id = ?",
                    arguments: [stale.projectID.uuidString]
                )
            }

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            let replacement = try XCTUnwrap(restored.openingPlanApproval)

            XCTAssertNotEqual(replacement.id, stale.id)
            XCTAssertNotEqual(replacement.bindingHash, stale.bindingHash)
            XCTAssertEqual(replacement.status, .pending)
            XCTAssertEqual(replacement.targetVersions.first(where: { $0.type == "novelProject" })?.version, 2)
            XCTAssertEqual(try database.approvalRequest(id: stale.id)?.status, .invalidated)
            XCTAssertTrue(restored.planAwaitingApproval)
        }
    }

    @MainActor
    func testLegacyApprovedArtifactRequiresExactReapproval() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Legacy", premise: "Imported")
            _ = try database.executeArtifactTool(
                conversationID: conversation.id,
                projectID: project.id,
                toolID: "legacy.openingPlan.approve",
                kind: "openingPlan",
                title: "Legacy plan",
                body: "Previously approved without an exact binding",
                status: "approved",
                idempotencyKey: "legacy.openingPlan.approved"
            )
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: project.id,
                    interviewStep: AgentRuntime.interviewQuestions.count,
                    currentQuestion: "",
                    interviewAnswers: ["A", "B", "C"],
                    updatedAt: Date()
                ),
                conversationID: conversation.id
            )

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(restored.openingPlanApproval?.status, .pending)
            XCTAssertTrue(restored.planAwaitingApproval)
            XCTAssertEqual(restored.businessStatus, "Waiting for opening plan approval")
        }
    }

    @MainActor
    func testOversizedAgentInputPreservesDraftWithoutPersistingMessageOrRun() throws {
        try withDatabase { database in
            let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
            let conversation = try database.ensureDefaultConversation()
            let oversized = String(
                repeating: "\u{754C}",
                count: AgentRuntime.maximumInputUTF8Bytes / 3 + 1
            )
            let messagesBefore = try database.listAgentMessages(conversationID: conversation.id)

            XCTAssertGreaterThan(oversized.utf8.count, 32_768)
            XCTAssertNil(try database.latestAgentRun(conversationID: conversation.id))

            viewModel.draft = oversized
            viewModel.sendAgentMessage()

            XCTAssertEqual(viewModel.draft, oversized)
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: conversation.id),
                messagesBefore
            )
            XCTAssertNil(try database.latestAgentRun(conversationID: conversation.id))
            XCTAssertEqual(viewModel.conversationMessages, messagesBefore.map(\.displayText))
            XCTAssertTrue(viewModel.errorMessage?.contains("AGENT-INPUT-LIMIT") == true)
            XCTAssertFalse(viewModel.isAgentWorking)
        }
    }

    @MainActor
    func testAgentTurnFailureAfterRunCreationPersistsFailedRunStage() throws {
        try withDatabase { database in
            let runtime = try AgentRuntime(database: database)
            let project = try database.createProject(title: "Broken session", premise: "P")
            let now = Date(timeIntervalSince1970: 3_000)
            try database.queue.write { db in
                try db.execute(
                    sql: """
                    INSERT INTO agentSession (
                        conversationID, focusedProjectID, interviewStep,
                        currentQuestion, interviewAnswersJSON, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        runtime.conversation.id.uuidString,
                        project.id.uuidString,
                        0,
                        AgentRuntime.interviewQuestions[0],
                        "not-json",
                        now.timeIntervalSince1970
                    ]
                )
            }

            XCTAssertThrowsError(try runtime.handleUserMessage("continue", now: now))

            let failedRun = try XCTUnwrap(
                database.latestAgentRun(conversationID: runtime.conversation.id)
            )
            XCTAssertEqual(failedRun.kind, "agentTurn")
            XCTAssertEqual(failedRun.status, .failed)
            XCTAssertEqual(failedRun.currentStage, "agentTurn.failed")
            let messages = try database.listAgentMessages(conversationID: runtime.conversation.id)
            XCTAssertEqual(messages.last?.role, .user)
            XCTAssertEqual(messages.last?.content, "continue")
        }
    }

    @MainActor
    func testRestoreReconcilesCommittedChapterReceiptOnceAndOnlyFinishesBoundRun() throws {
        try withDatabase { database in
            let fixture = try makeCommittedChapterGenerateFixture(
                database: database,
                keyPrefix: "chapter.restore.committed"
            )
            let decoyRun = AgentRunSnapshot(
                id: UUID(),
                kind: "agentTurn",
                status: .running,
                idempotencyKey: "agent.turn.decoy",
                currentStage: "interpret",
                startedAt: Date(timeIntervalSince1970: 3_100),
                updatedAt: Date(timeIntervalSince1970: 3_100)
            )
            try database.saveAgentRun(decoyRun, conversationID: fixture.conversationID)

            let firstRestore = AppViewModel(database: database, keychain: StubSecretRepository())
            let secondRestore = AppViewModel(database: database, keychain: StubSecretRepository())

            let settled = try XCTUnwrap(
                database.agentRun(id: fixture.run.id, conversationID: fixture.conversationID)
            )
            XCTAssertEqual(settled.status, .waitingUser)
            XCTAssertEqual(settled.currentStage, "chapter.1.reviewingV1")
            XCTAssertEqual(
                try database.agentRun(id: decoyRun.id, conversationID: fixture.conversationID),
                decoyRun
            )
            let messages = try database.listAgentMessages(conversationID: fixture.conversationID)
            XCTAssertEqual(
                messages.filter { $0.content == Self.chapterGeneratedMessage }.count,
                1
            )
            XCTAssertEqual(firstRestore.chapter?.activeVersion.id, fixture.result.version.id)
            XCTAssertEqual(secondRestore.chapter?.activeVersion.id, fixture.result.version.id)
        }
    }

    @MainActor
    func testRestoreDoesNotOverwriteProtectedCommittedChapterRunStatuses() throws {
        for status in [
            AgentRunStatus.paused,
            .failed,
            .cancelled,
            .completed
        ] {
            try withDatabase { database in
                let fixture = try makeCommittedChapterGenerateFixture(
                    database: database,
                    runStatus: status,
                    runStage: "preserve.\(status.rawValue)",
                    keyPrefix: "chapter.restore.\(status.rawValue)"
                )
                let storedBefore = try XCTUnwrap(
                    database.agentRun(id: fixture.run.id, conversationID: fixture.conversationID)
                )

                _ = AppViewModel(database: database, keychain: StubSecretRepository())
                _ = AppViewModel(database: database, keychain: StubSecretRepository())

                XCTAssertEqual(
                    try database.agentRun(id: fixture.run.id, conversationID: fixture.conversationID),
                    storedBefore
                )
            }
        }
    }

    @MainActor
    func testParagraphLockReceiptDoesNotGenerateAgentMessageDuringRestore() throws {
        try withDatabase { database in
            let fixture = try makeCommittedChapterGenerateFixture(
                database: database,
                keyPrefix: "chapter.restore.lock"
            )
            _ = AppViewModel(database: database, keychain: StubSecretRepository())
            let messagesBeforeLock = try database.listAgentMessages(conversationID: fixture.conversationID)
            let lockRun = AgentRunSnapshot(
                id: UUID(),
                projectID: fixture.projectID,
                kind: "agentTurn",
                status: .running,
                idempotencyKey: "agent.turn.chapter.lock",
                currentStage: "interpret",
                startedAt: Date(timeIntervalSince1970: 3_200),
                updatedAt: Date(timeIntervalSince1970: 3_200)
            )
            try database.saveAgentRun(lockRun, conversationID: fixture.conversationID)
            _ = try database.executeChapterLockParagraphSetTool(
                conversationID: fixture.conversationID,
                projectID: fixture.projectID,
                versionID: fixture.result.version.id,
                displayedContentHash: fixture.result.version.contentHash,
                lockedParagraphIndexes: [0],
                idempotencyKey: "chapter.restore.lock.receipt",
                originRunID: lockRun.id,
                now: Date(timeIntervalSince1970: 3_201)
            )

            _ = AppViewModel(database: database, keychain: StubSecretRepository())
            _ = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(
                try database.listAgentMessages(conversationID: fixture.conversationID),
                messagesBeforeLock
            )
            XCTAssertEqual(
                try database.agentRun(id: lockRun.id, conversationID: fixture.conversationID),
                lockRun
            )
        }
    }

    @MainActor
    func testGeneratedChapterProjectsExactReviewAndRestoresAfterRestart() throws {
        try withDatabase { database in
            let viewModel = try makeChapterReviewViewModel(database: database)
            let chapter = try XCTUnwrap(viewModel.chapter)

            XCTAssertEqual(chapter.stage, .reviewingV1)
            XCTAssertEqual(chapter.activeVersion.revision, 1)
            XCTAssertTrue(viewModel.chapterNeedsReview)
            XCTAssertFalse(viewModel.chapterNeedsRewriteScopeApproval)
            XCTAssertGreaterThan(viewModel.chapterParagraphs.count, 1)
            XCTAssertEqual(viewModel.lastToolReceipt?.toolID, "chapter.generate")

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertEqual(restored.chapter?.activeVersion.id, chapter.activeVersion.id)
            XCTAssertEqual(restored.chapter?.activeVersion.contentHash, chapter.activeVersion.contentHash)
            XCTAssertEqual(restored.chapter?.stage, .reviewingV1)
            XCTAssertTrue(restored.chapterNeedsReview)
            XCTAssertEqual(restored.businessStatus, "Chapter 1 revision 1 awaiting review")
        }
    }

    @MainActor
    func testParagraphLockUsesGovernedExactBindingAndPersists() throws {
        try withDatabase { database in
            let viewModel = try makeChapterReviewViewModel(database: database)
            let displayed = try XCTUnwrap(viewModel.chapter)

            viewModel.setChapterParagraphLocked(
                1,
                locked: true,
                versionID: displayed.activeVersion.id,
                displayedContentHash: displayed.activeVersion.contentHash
            )

            XCTAssertEqual(viewModel.chapter?.calibration.lockedParagraphIndexes, [1])
            XCTAssertEqual(viewModel.lastToolReceipt?.toolID, "chapter.lockParagraph.set")
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.lockParagraph.set"), 1)

            viewModel.setChapterParagraphLocked(
                1,
                locked: true,
                versionID: displayed.activeVersion.id,
                displayedContentHash: displayed.activeVersion.contentHash
            )
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.lockParagraph.set"), 1)

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertEqual(restored.chapter?.calibration.lockedParagraphIndexes, [1])
            XCTAssertEqual(restored.lastToolReceipt?.toolID, "chapter.lockParagraph.set")
        }
    }

    @MainActor
    func testStaleDisplayedChapterCannotLockOrAcceptNewerState() throws {
        try withDatabase { database in
            let viewModel = try makeChapterReviewViewModel(database: database)
            let displayed = try XCTUnwrap(viewModel.chapter)

            viewModel.setChapterParagraphLocked(
                0,
                locked: true,
                versionID: displayed.activeVersion.id,
                displayedContentHash: "stale-hash"
            )
            let rejected = viewModel.rejectChapter(
                reason: "The displayed revision is stale.",
                versionID: displayed.activeVersion.id,
                displayedContentHash: "stale-hash"
            )
            let accepted = viewModel.acceptChapter(
                versionID: displayed.activeVersion.id,
                displayedContentHash: "stale-hash"
            )

            XCTAssertFalse(rejected)
            XCTAssertFalse(accepted)
            XCTAssertEqual(viewModel.chapter?.stage, .reviewingV1)
            XCTAssertEqual(viewModel.chapter?.calibration.lockedParagraphIndexes, [])
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.lockParagraph.set"), 0)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.accept"), 0)
            XCTAssertTrue(viewModel.errorMessage?.contains("CHAPTER-STALE") == true)
        }
    }

    @MainActor
    func testConfirmRewriteReturnsFalseForStaleDisplayedSourceHash() throws {
        try withDatabase { database in
            let viewModel = try makeChapterReviewViewModel(database: database)
            let v1 = try XCTUnwrap(viewModel.chapter?.activeVersion)
            XCTAssertTrue(
                viewModel.rejectChapter(
                    reason: "The protagonist reacts instead of choosing.",
                    versionID: v1.id,
                    displayedContentHash: v1.contentHash
                )
            )
            for answer in Self.diagnosisAnswers {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let scoped = try XCTUnwrap(viewModel.chapter)
            let scopeHash = try XCTUnwrap(scoped.calibration.rewriteScopeHash)

            let confirmed = viewModel.confirmChapterRewrite(
                sourceVersionID: scoped.activeVersion.id,
                displayedSourceHash: "stale-hash",
                rewriteScopeHash: scopeHash
            )

            XCTAssertFalse(confirmed)
            XCTAssertEqual(viewModel.chapter?.stage, .awaitingRewriteConfirmation)
            XCTAssertEqual(try database.countToolReceipts(toolID: "chapter.rewrite"), 0)
            XCTAssertTrue(viewModel.errorMessage?.contains("CHAPTER-STALE") == true)
        }
    }

    @MainActor
    func testRejectingV2ReturnsFalseWithoutChangingProjection() throws {
        try withDatabase { database in
            let viewModel = try makeChapterReviewViewModel(database: database)
            let v1 = try XCTUnwrap(viewModel.chapter?.activeVersion)
            XCTAssertTrue(
                viewModel.rejectChapter(
                    reason: "The protagonist reacts instead of choosing.",
                    versionID: v1.id,
                    displayedContentHash: v1.contentHash
                )
            )
            for answer in Self.diagnosisAnswers {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }
            let scoped = try XCTUnwrap(viewModel.chapter)
            XCTAssertTrue(
                viewModel.confirmChapterRewrite(
                    sourceVersionID: scoped.activeVersion.id,
                    displayedSourceHash: scoped.activeVersion.contentHash,
                    rewriteScopeHash: try XCTUnwrap(scoped.calibration.rewriteScopeHash)
                )
            )
            let v2 = try XCTUnwrap(viewModel.chapter)
            let rejectReceiptCount = try database.countToolReceipts(toolID: "chapter.reject")

            let rejected = viewModel.rejectChapter(
                reason: "Rejecting revision 2 is outside the calibration protocol.",
                versionID: v2.activeVersion.id,
                displayedContentHash: v2.activeVersion.contentHash
            )

            XCTAssertFalse(rejected)
            XCTAssertEqual(viewModel.chapter, v2)
            XCTAssertEqual(
                try database.countToolReceipts(toolID: "chapter.reject"),
                rejectReceiptCount
            )
        }
    }

    @MainActor
    func testRejectDiagnosisRewriteAndFreezePreserveHistoryLocksAndReceipts() throws {
        try withDatabase { database in
            let viewModel = try makeChapterReviewViewModel(database: database)
            let v1 = try XCTUnwrap(viewModel.chapter?.activeVersion)

            viewModel.setChapterParagraphLocked(
                1,
                locked: true,
                versionID: v1.id,
                displayedContentHash: v1.contentHash
            )
            let rejected = viewModel.rejectChapter(
                reason: "The protagonist reacts passively and the cost arrives too late.",
                versionID: v1.id,
                displayedContentHash: v1.contentHash
            )
            XCTAssertTrue(rejected)
            XCTAssertEqual(viewModel.chapter?.stage, .diagnosing)
            XCTAssertEqual(viewModel.lastToolReceipt?.toolID, "chapter.reject")

            for answer in [
                "The point of view explains the danger before the protagonist chooses.",
                "Keep the inheritance cost and the second paragraph exactly as displayed.",
                "End with the protagonist voluntarily entering the sect trial."
            ] {
                viewModel.draft = answer
                viewModel.sendAgentMessage()
            }

            let scoped = try XCTUnwrap(viewModel.chapter)
            let scopeHash = try XCTUnwrap(scoped.calibration.rewriteScopeHash)
            XCTAssertEqual(scoped.stage, .awaitingRewriteConfirmation)
            XCTAssertTrue(viewModel.chapterNeedsRewriteScopeApproval)
            XCTAssertFalse(scoped.calibration.rewriteScope?.isEmpty ?? true)

            let rewriteConfirmed = viewModel.confirmChapterRewrite(
                sourceVersionID: scoped.activeVersion.id,
                displayedSourceHash: scoped.activeVersion.contentHash,
                rewriteScopeHash: scopeHash
            )

            XCTAssertTrue(rewriteConfirmed)
            let v2Review = try XCTUnwrap(viewModel.chapter)
            XCTAssertEqual(v2Review.stage, .reviewingV2)
            XCTAssertEqual(v2Review.versions.map(\.revision), [1, 2])
            XCTAssertEqual(v2Review.calibration.lockedParagraphIndexes, [1])
            XCTAssertNotNil(v2Review.activeVersion.diffSummary)
            XCTAssertEqual(viewModel.lastToolReceipt?.toolID, "chapter.rewrite")

            let accepted = viewModel.acceptChapter(
                versionID: v2Review.activeVersion.id,
                displayedContentHash: v2Review.activeVersion.contentHash
            )

            XCTAssertTrue(accepted)
            XCTAssertEqual(viewModel.chapter?.stage, .approvedFrozen)
            XCTAssertFalse(viewModel.chapterNeedsReview)
            XCTAssertFalse(viewModel.chapterNeedsRewriteScopeApproval)
            XCTAssertEqual(viewModel.lastToolReceipt?.toolID, "chapter.accept")
            XCTAssertEqual(try database.countChapterVersions(projectID: v1.projectID, chapterNumber: 1), 2)

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertEqual(restored.chapter?.stage, .approvedFrozen)
            XCTAssertEqual(restored.chapter?.versions.map(\.revision), [1, 2])
            XCTAssertEqual(restored.chapter?.calibration.lockedParagraphIndexes, [1])
            XCTAssertEqual(restored.lastToolReceipt?.toolID, "chapter.accept")
            XCTAssertEqual(restored.businessStatus, "Chapter 1 approved and frozen")
        }
    }

    private static let diagnosisAnswers = [
        "The point of view explains the danger before the protagonist chooses.",
        "Keep the inheritance cost and the second paragraph exactly as displayed.",
        "End with the protagonist voluntarily entering the sect trial."
    ]

    private static let chapterGeneratedMessage =
        "Chapter 1 revision 1 has been generated and evidence-reviewed. Review the exact revision, then accept and freeze it or reject it for diagnosis."

    @MainActor
    private func makeCommittedChapterGenerateFixture(
        database: AppDatabase,
        runStatus: AgentRunStatus = .running,
        runStage: String = "interpret",
        keyPrefix: String
    ) throws -> (
        conversationID: UUID,
        projectID: UUID,
        run: AgentRunSnapshot,
        result: ChapterToolResult
    ) {
        let conversation = try database.ensureDefaultConversation()
        let project = try database.createProject(title: "Recovery project", premise: "P")
        let saved = try database.executeOpeningPlanSaveTool(
            conversationID: conversation.id,
            projectID: project.id,
            title: "Opening plan",
            body: "Approved recovery plan",
            idempotencyKey: keyPrefix + ".opening.save",
            expiresAt: Date(timeIntervalSinceNow: 3_600)
        )
        let approvalKey = [
            "artifact.openingPlan.approve",
            saved.approval.id.uuidString,
            saved.approval.bindingHash
        ].joined(separator: ".")
        let approved = try database.executeOpeningPlanApprovalTool(
            conversationID: conversation.id,
            approvalRequestID: saved.approval.id,
            displayedBindingHash: saved.approval.bindingHash,
            idempotencyKey: approvalKey
        )
        try database.saveAgentSession(
            AgentSessionState(
                focusedProjectID: project.id,
                interviewStep: AgentRuntime.interviewQuestions.count,
                currentQuestion: "",
                interviewAnswers: ["Hook", "Goal", "Cost"],
                updatedAt: Date(timeIntervalSince1970: 3_000)
            ),
            conversationID: conversation.id
        )
        let run = AgentRunSnapshot(
            id: UUID(),
            projectID: project.id,
            kind: "agentTurn",
            status: runStatus,
            idempotencyKey: keyPrefix + ".run",
            currentStage: runStage,
            startedAt: Date(timeIntervalSince1970: 3_001),
            updatedAt: Date(timeIntervalSince1970: 3_001)
        )
        try database.saveAgentRun(run, conversationID: conversation.id)
        let result = try database.executeChapterGenerateTool(
            conversationID: conversation.id,
            projectID: project.id,
            chapterNumber: 1,
            title: "Chapter 1",
            body: "Locked paragraph.\n\nRewrite paragraph.",
            evidenceReview: "Evidence reviewed.",
            openingPlanArtifactID: approved.artifact.id,
            openingPlanHash: approved.artifact.contentHash,
            idempotencyKey: keyPrefix + ".chapter.generate",
            originRunID: run.id,
            now: Date(timeIntervalSince1970: 3_002)
        )
        return (conversation.id, project.id, run, result)
    }

    func testChineseChapterIntentAndDiagnosisTemplatesRemainReadable() {
        XCTAssertEqual(
            ChapterAgentTemplates.intent(for: "确认重写", stage: .awaitingRewriteConfirmation),
            .confirmRewrite
        )
        XCTAssertEqual(
            ChapterAgentTemplates.intent(for: "接受并冻结", stage: .reviewingV2),
            .accept
        )
        XCTAssertEqual(
            ChapterAgentTemplates.intent(for: "生成第一章", stage: .notStarted),
            .generate
        )
        XCTAssertTrue(ChapterDiagnosisProtocol.orderedQuestions.allSatisfy { !$0.contains("???") })
        let summary = ChapterAgentTemplates.diagnosisSummary(
            answers: ["节奏拖沓", "保留师徒冲突", "期待主角反击"],
            lockedParagraphIndexes: [0]
        )
        XCTAssertTrue(summary.contains("节奏拖沓"))
        XCTAssertTrue(summary.contains("保留师徒冲突"))
        XCTAssertTrue(summary.contains("期待主角反击"))
    }
    @MainActor
    private func makeOpeningPlanApprovalViewModel(
        database: AppDatabase
    ) throws -> (viewModel: AppViewModel, approval: ApprovalRequest) {
        let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
        viewModel.draft = "create a cultivation novel"
        viewModel.sendAgentMessage()
        for answer in ["Forbidden inheritance", "Save his sister", "Lose one memory"] {
            viewModel.draft = answer
            viewModel.sendAgentMessage()
        }
        return (viewModel, try XCTUnwrap(viewModel.openingPlanApproval))
    }

    @MainActor
    private func makeChapterReviewViewModel(database: AppDatabase) throws -> AppViewModel {
        let viewModel = AppViewModel(database: database, keychain: StubSecretRepository())
        viewModel.draft = "create a cultivation novel"
        viewModel.sendAgentMessage()
        for answer in ["Forbidden inheritance", "Save his sister", "Lose one memory"] {
            viewModel.draft = answer
            viewModel.sendAgentMessage()
        }
        let approval = try XCTUnwrap(viewModel.openingPlanApproval)
        viewModel.approveOpeningPlan(
            requestID: approval.id,
            displayedBindingHash: approval.bindingHash
        )
        viewModel.draft = "generate chapter"
        viewModel.sendAgentMessage()
        return viewModel
    }

    @MainActor
    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            XCTAssertNoThrow(try FileManager.default.removeItem(at: directory))
        }
        try Self.withOpenDatabase(
            at: directory.appendingPathComponent("test.sqlite").path,
            body
        )
    }

    @MainActor
    private static func withOpenDatabase(
        at path: String,
        _ body: (AppDatabase) throws -> Void
    ) throws {
        let database = try AppDatabase(path: path)
        try body(database)
    }
}
