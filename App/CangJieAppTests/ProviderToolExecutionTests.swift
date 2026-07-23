@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class ProviderToolExecutionTests: XCTestCase {
    func testProjectCreateCommitsExactReceiptAndReplaysWithoutDuplication() throws {
        let fixture = try makeFixture(
            functionName: "project_create",
            argumentsJSON: #"{"title":"星河","premise":"凡人追查失踪真相"}"#
        )

        let first = try fixture.database.executeProviderTool(
            fixture.invocation,
            now: fixture.now.addingTimeInterval(4)
        )
        let replay = try fixture.database.executeProviderTool(
            fixture.invocation,
            now: fixture.now.addingTimeInterval(5)
        )

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.project?.title, "星河")
        XCTAssertEqual(first.project?.premise, "凡人追查失踪真相")
        XCTAssertEqual(first.receipt.toolID, "project.create")
        XCTAssertEqual(first.receipt.toolVersion, "1")
        XCTAssertEqual(first.receipt.inputHash, fixture.invocation.inputHash)
        XCTAssertEqual(
            first.receipt.providerRequestID,
            fixture.request.identity.requestID
        )
        XCTAssertEqual(first.receipt.providerCallID, "call-1")
        XCTAssertEqual(first.receipt.providerCallIndex, 0)
        XCTAssertEqual(first.receipt.originRunID, fixture.request.identity.runID)
        XCTAssertEqual(first.receipt.conversationID, fixture.intent.conversationID)
        XCTAssertEqual(try fixture.database.listProjects().count, 1)
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.currentStage,
            "provider.toolExecuted"
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.projectID,
            first.project?.id
        )
    }

    func testInvocationMustMatchTheDurableProviderResponseExactly() throws {
        let fixture = try makeFixture(
            functionName: "project_create",
            argumentsJSON: #"{"title":"星河","premise":"原始故事"}"#
        )
        let tampered = try ProjectToolInvocation.parse(
            providerFunctionName: "project_create",
            argumentsJSON: #"{"title":"星河","premise":"被替换的故事"}"#,
            providerCallID: "call-1",
            providerCallIndex: 0,
            providerRequestID: fixture.request.identity.requestID,
            runID: fixture.request.identity.runID,
            conversationID: fixture.intent.conversationID,
            projectID: nil
        )

        XCTAssertThrowsError(
            try fixture.database.executeProviderTool(tampered)
        ) { error in
            XCTAssertEqual(
                error as? AppDatabaseError,
                .invalidProviderToolInvocation
            )
        }
        XCTAssertTrue(try fixture.database.listProjects().isEmpty)
        XCTAssertNil(
            try fixture.database.toolReceipt(
                idempotencyKey: tampered.idempotencyKey
            )
        )
    }

    func testProjectStatusWithoutCurrentProjectReturnsExactNoProjectReceipt() throws {
        let fixture = try makeFixture(
            functionName: "project_status",
            argumentsJSON: "{}"
        )

        let result = try fixture.database.executeProviderTool(
            fixture.invocation,
            now: fixture.now.addingTimeInterval(4)
        )

        XCTAssertEqual(result.status, "noCurrentProject")
        XCTAssertNil(result.project)
        XCTAssertEqual(result.receipt.toolID, "project.status")
        XCTAssertNil(result.receipt.projectID)
        XCTAssertNil(result.receipt.outputReference)
    }

    func testProjectListReturnsRealProjectsAndReplaysExactly() throws {
        let fixture = try makeFixture(
            functionName: "project_list",
            argumentsJSON: "{}"
        )
        _ = try fixture.database.createProject(
            title: "甲",
            premise: "第一本",
            now: fixture.now
        )
        _ = try fixture.database.createProject(
            title: "乙",
            premise: "第二本",
            now: fixture.now.addingTimeInterval(1)
        )

        let first = try fixture.database.executeProviderTool(fixture.invocation)
        let replay = try fixture.database.executeProviderTool(fixture.invocation)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.status, "listed")
        XCTAssertEqual(first.projects.map(\.title), ["乙", "甲"])
        XCTAssertNil(first.receipt.outputReference)
        XCTAssertEqual(try fixture.database.latestToolReceipt()?.id, first.receipt.id)
    }

    func testProjectSwitchChangesConversationFocusAndReplaysExactly() throws {
        let targetID = UUID(
            uuidString: "85000000-0000-0000-0000-000000000005"
        )!
        let fixture = try makeFixture(
            functionName: "project_switch",
            argumentsJSON: "{\"projectID\":\""
                + targetID.uuidString
                + "\"}"
        )
        let project = NovelProject(
            id: targetID,
            title: "目标",
            premise: "切换到这里",
            createdAt: fixture.now,
            updatedAt: fixture.now
        )
        try fixture.database.queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO novelProject (id, title, premise, createdAt, updatedAt)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    project.id.uuidString,
                    project.title,
                    project.premise,
                    fixture.now.timeIntervalSince1970,
                    fixture.now.timeIntervalSince1970
                ]
            )
        }
        let first = try fixture.database.executeProviderTool(fixture.invocation)
        let replay = try fixture.database.executeProviderTool(fixture.invocation)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.status, "switched")
        XCTAssertEqual(first.project?.id, project.id)
        XCTAssertEqual(
            try fixture.database.focusedProjectID(
                conversationID: fixture.intent.conversationID
            ),
            project.id
        )
    }

    func testSaveDiscussionCreatesScopedArtifactAndExactReplay() throws {
        let fixture = try makeFixture(
            functionName: "project_save_discussion",
            argumentsJSON: #"{"title":"起点","body":"保留这次讨论"}"#
        )

        let first = try fixture.database.executeProviderTool(fixture.invocation)
        let replay = try fixture.database.executeProviderTool(fixture.invocation)

        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.status, "saved")
        XCTAssertEqual(first.artifact?.kind, "discussion")
        XCTAssertEqual(first.artifact?.title, "起点")
        XCTAssertEqual(first.artifact?.body, "保留这次讨论")
        XCTAssertEqual(
            first.artifact?.conversationID,
            fixture.intent.conversationID
        )
        XCTAssertEqual(first.receipt.outputReference, first.artifact?.id.uuidString)
    }

    private func makeFixture(
        functionName: String,
        argumentsJSON: String
    ) throws -> (
        database: AppDatabase,
        intent: PendingModelIntent,
        request: ProviderRequestSnapshot,
        invocation: ProjectToolInvocation,
        now: Date
    ) {
        let now = Date(timeIntervalSince1970: 5_000)
        let database = try AppDatabase(path: temporaryDatabasePath())
        let conversation = try database.ensureDefaultConversation(now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "创建并查看一本小说",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: ModelCredentialVerification(
                reference: connection.credential,
                credentialVersionProof: hash("a"),
                credentialPayloadHash: hash("b")
            )
        )
        let prepared = try ProviderAgentRunCoordinator.makePreparedRequest(
            intent: intent,
            verifiedConnection: verified,
            now: now
        )
        let stored = try database.persistPreparedProviderRequest(
            prepared,
            verifiedConnection: verified
        )
        let sending = try ProviderRequestLifecycle.markSending(
            stored,
            now: now.addingTimeInterval(1)
        )
        try database.updateProviderRequest(sending)
        let payload = ProviderResponsePayload(
            text: "",
            toolCalls: [
                ProviderToolCallPayload(
                    index: 0,
                    id: "call-1",
                    name: functionName,
                    argumentsJSON: argumentsJSON
                )
            ],
            finishReason: "tool_calls"
        )
        let payloadJSON = try encode(payload)
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            now: now.addingTimeInterval(2)
        )
        try database.checkpointProviderResponse(
            streaming,
            responsePayloadJSON: payloadJSON
        )
        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            usage: ProviderUsage(
                inputTokens: 8,
                outputTokens: 4,
                totalTokens: 12
            ),
            now: now.addingTimeInterval(3)
        )
        try database.completeProviderResponse(completed)
        let invocation = try ProjectToolInvocation.parse(
            providerFunctionName: functionName,
            argumentsJSON: argumentsJSON,
            providerCallID: "call-1",
            providerCallIndex: 0,
            providerRequestID: completed.identity.requestID,
            runID: completed.identity.runID,
            conversationID: completed.identity.conversationID,
            projectID: completed.identity.projectID
        )
        return (database, intent, completed, invocation, now)
    }

    private func encode(_ payload: ProviderResponsePayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try XCTUnwrap(
            String(data: encoder.encode(payload), encoding: .utf8)
        )
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-tool-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
