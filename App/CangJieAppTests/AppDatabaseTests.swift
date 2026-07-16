import XCTest
@testable import CangJie

final class AppDatabaseTests: XCTestCase {
    func testDraftAndCheckpointRoundTripUsesWAL() throws {
        try withDatabase { database in
            XCTAssertEqual(try database.journalMode().lowercased(), "wal")

            let date = Date(timeIntervalSince1970: 1_000)
            let taskID = UUID()
            let checkpoint = try database.checkpointDraft(
                content: "第一章草稿",
                taskID: taskID,
                reason: "manual",
                payloadHash: "abc",
                now: date
            )

            XCTAssertEqual(checkpoint.sequence, 1)
            XCTAssertEqual(
                try database.loadDraft(),
                DraftSnapshot(content: "第一章草稿", updatedAt: date)
            )
            XCTAssertEqual(try database.latestCheckpoint(taskID: taskID), checkpoint)
        }
    }

    func testSamePayloadReusesCheckpointWithoutAdvancingSequence() throws {
        try withDatabase { database in
            let taskID = UUID()
            let first = try database.checkpointDraft(
                content: "未变化草稿",
                taskID: taskID,
                reason: "inactive",
                payloadHash: "same",
                now: Date(timeIntervalSince1970: 1_000)
            )
            let second = try database.checkpointDraft(
                content: "未变化草稿",
                taskID: taskID,
                reason: "background",
                payloadHash: "same",
                now: Date(timeIntervalSince1970: 2_000)
            )

            XCTAssertEqual(second, first)
            XCTAssertEqual(try database.latestCheckpoint(taskID: taskID)?.sequence, 1)
        }
    }

    func testCreateAndListNovelProjectsPersistsNewestFirst() throws {
        try withDatabase { database in
            let first = try database.createProject(title: "First", premise: "A", now: Date(timeIntervalSince1970: 100))
            let second = try database.createProject(title: "Second", premise: "B", now: Date(timeIntervalSince1970: 200))
            let projects = try database.listProjects()

            XCTAssertEqual(projects.map(\.id), [second.id, first.id])
            XCTAssertEqual(projects.map(\.title), ["Second", "First"])
        }
    }


    func testPlanningArtifactRoundTripKeepsApprovalStatus() throws {
        try withDatabase { database in
            let saved = try database.saveArtifact(kind: "openingPlan", title: "Plan", body: "Body", status: "waitingApproval", now: Date(timeIntervalSince1970: 300))
            let restored = try database.latestArtifact(kind: "openingPlan")

            XCTAssertEqual(restored, saved)
        }
    }


    func testToolReceiptRoundTripIsAuditable() throws {
        try withDatabase { database in
            let receipt = try database.recordToolReceipt(toolID: "project.create", inputSummary: "premise", outcome: "completed", now: Date(timeIntervalSince1970: 400))
            XCTAssertEqual(try database.latestToolReceipt(), receipt)
        }
    }


    func testAgentConversationSessionAndRunRoundTrip() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 499))
            let user = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .user,
                content: "A forbidden inheritance",
                now: Date(timeIntervalSince1970: 500)
            )
            let assistant = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: "What does the protagonist want?",
                now: Date(timeIntervalSince1970: 501)
            )
            let session = AgentSessionState(
                focusedProjectID: UUID(),
                interviewStep: 1,
                currentQuestion: "What does the protagonist want?",
                interviewAnswers: ["A forbidden inheritance"],
                updatedAt: Date(timeIntervalSince1970: 502)
            )
            try database.saveAgentSession(session, conversationID: conversation.id)
            let run = AgentRunSnapshot(
                id: UUID(),
                kind: "strategicInterview",
                status: .waitingUser,
                idempotencyKey: "agent.turn.test",
                currentStage: "question.2",
                startedAt: Date(timeIntervalSince1970: 503),
                updatedAt: Date(timeIntervalSince1970: 504)
            )
            try database.saveAgentRun(run, conversationID: conversation.id)

            XCTAssertEqual(try database.listAgentMessages(conversationID: conversation.id), [user, assistant])
            XCTAssertEqual(try database.loadAgentSession(conversationID: conversation.id), session)
            XCTAssertEqual(try database.latestAgentRun(conversationID: conversation.id), run)
        }
    }

    func testProjectCreateToolIsIdempotentAndReturnsSameReceipt() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 599))
            let first = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel",
                premise: "A mortal challenges heaven",
                idempotencyKey: "project.create.message-1",
                now: Date(timeIntervalSince1970: 600)
            )
            let second = try database.executeProjectCreateTool(
                conversationID: conversation.id,
                title: "Untitled Novel",
                premise: "A mortal challenges heaven",
                idempotencyKey: "project.create.message-1",
                now: Date(timeIntervalSince1970: 700)
            )

            XCTAssertEqual(first.project, second.project)
            XCTAssertEqual(first.receipt, second.receipt)
            XCTAssertEqual(try database.listProjects().count, 1)
            XCTAssertEqual(first.receipt.outputReference, first.project.id.uuidString)
        }
    }

    func testAgentRunRetryReusesIdempotencyKeyWithoutUniqueConstraintFailure() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let key = "agent.approval.plan-1"
            let first = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .running,
                idempotencyKey: key,
                currentStage: "openingPlan.approve",
                startedAt: Date(timeIntervalSince1970: 600),
                updatedAt: Date(timeIntervalSince1970: 600)
            )
            let retry = AgentRunSnapshot(
                id: UUID(),
                kind: "approval",
                status: .completed,
                idempotencyKey: key,
                currentStage: "openingPlan.approved",
                startedAt: Date(timeIntervalSince1970: 601),
                updatedAt: Date(timeIntervalSince1970: 602)
            )

            try database.saveAgentRun(first, conversationID: conversation.id)
            try database.saveAgentRun(retry, conversationID: conversation.id)

            let restored = try database.agentRun(idempotencyKey: key)
            XCTAssertEqual(restored?.id, first.id)
            XCTAssertEqual(restored?.status, .completed)
            XCTAssertEqual(restored?.currentStage, "openingPlan.approved")
        }
    }

    func testDefaultConversationAdoptsLegacyUnscopedArtifactsAndReceipts() throws {
        try withDatabase { database in
            let artifact = try database.saveArtifact(
                kind: "openingPlan",
                title: "Legacy plan",
                body: "Legacy body",
                status: "waitingApproval"
            )
            let receipt = try database.recordToolReceipt(
                toolID: "artifact.openingPlan.save",
                inputSummary: "legacy",
                outcome: "completed"
            )

            let conversation = try database.ensureDefaultConversation()

            XCTAssertEqual(try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id)?.id, artifact.id)
            XCTAssertEqual(try database.latestToolReceipt(conversationID: conversation.id)?.id, receipt.id)
        }
    }

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

    private static func withOpenDatabase(
        at path: String,
        _ body: (AppDatabase) throws -> Void
    ) throws {
        let database = try AppDatabase(path: path)
        try body(database)
    }

}
