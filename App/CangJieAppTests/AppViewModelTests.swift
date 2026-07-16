import XCTest
@testable import CangJie

final class AppViewModelTests: XCTestCase {
    private enum StubDatabaseError: Error {
        case openFailed
    }

    private struct StubSecretRepository: SecretRepository {
        func save(_ secret: String, account: String) throws {}
        func contains(account: String) throws -> Bool { false }
        func delete(account: String) throws {}
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

            viewModel.approveOpeningPlan(
                requestID: displayed.id,
                displayedBindingHash: displayed.bindingHash
            )

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
            XCTAssertTrue(viewModel.transientNotice?.message.contains("1 project") == true)
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

            viewModel.approveOpeningPlan(
                requestID: stale.id,
                displayedBindingHash: stale.bindingHash
            )

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
            let firstPlan = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: firstProject.id,
                title: "First opening plan",
                body: "FIRST PROJECT PLAN",
                idempotencyKey: "multi-project.first",
                now: Date(timeIntervalSince1970: 1_003),
                expiresAt: Date(timeIntervalSince1970: 5_000)
            )
            _ = try database.executeOpeningPlanSaveTool(
                conversationID: conversation.id,
                projectID: secondProject.id,
                title: "Second opening plan",
                body: "SECOND PROJECT PLAN",
                idempotencyKey: "multi-project.second",
                now: Date(timeIntervalSince1970: 1_004),
                expiresAt: Date(timeIntervalSince1970: 5_000)
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
