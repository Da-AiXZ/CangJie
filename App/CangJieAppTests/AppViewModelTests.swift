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
            XCTAssertTrue(viewModel.status.hasPrefix("SQLite ready"))

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
            XCTAssertTrue(viewModel.status.hasPrefix("SQLite ready"))
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

            XCTAssertTrue(viewModel.planAwaitingApproval)
            XCTAssertFalse(viewModel.planBody.isEmpty)
            XCTAssertEqual(try database.latestArtifact(kind: "openingPlan")?.status, "waitingApproval")

            viewModel.approveOpeningPlan()
            XCTAssertFalse(viewModel.planAwaitingApproval)
            XCTAssertEqual(try database.latestArtifact(kind: "openingPlan")?.status, "approved")
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
            first.approveOpeningPlan()

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertFalse(restored.planAwaitingApproval)
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
            viewModel.approveOpeningPlan()

            viewModel.draft = "What happens next?"
            viewModel.sendAgentMessage()

            XCTAssertFalse(viewModel.planAwaitingApproval)
            XCTAssertEqual(try database.latestArtifact(kind: "openingPlan")?.status, "approved")
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

            let conversation = try XCTUnwrap(try database.listConversations().first)
            let plan = try XCTUnwrap(try database.latestArtifact(
                kind: "openingPlan",
                conversationID: conversation.id
            ))
            let approvalKey = "artifact.openingPlan.approve." + plan.id.uuidString
            let interruptedRun = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .running,
                idempotencyKey: approvalKey,
                currentStage: "openingPlan.approve",
                startedAt: Date(timeIntervalSince1970: 700),
                updatedAt: Date(timeIntervalSince1970: 700)
            )
            try database.saveAgentRun(interruptedRun, conversationID: conversation.id)
            _ = try database.executeArtifactTool(
                conversationID: conversation.id,
                projectID: plan.projectID,
                toolID: "artifact.openingPlan.approve",
                kind: plan.kind,
                title: plan.title,
                body: plan.body,
                status: "approved",
                idempotencyKey: approvalKey,
                now: plan.updatedAt.addingTimeInterval(1)
            )

            let restored = AppViewModel(database: database, keychain: StubSecretRepository())
            restored.approveOpeningPlan()

            XCTAssertEqual(try database.agentRun(idempotencyKey: approvalKey)?.status, .completed)
            XCTAssertFalse(restored.planAwaitingApproval)
            XCTAssertEqual(restored.status, "Verified: opening plan approved")
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
