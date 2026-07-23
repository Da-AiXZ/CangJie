@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class ProviderAgentLoopCoordinatorTests: XCTestCase {
    func testProjectCreateReceiptFeedsContinuationAndConsumesIntentOnce() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 6_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "创建一本叫星河的悬疑小说",
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
        let versionProof = hash("a")
        let payloadHash = hash("b")
        credentials.credentialPayloadHash = payloadHash
        try credentials.save(
            "fixture-secret",
            versionProof: versionProof,
            setupAuthorizationHash: nil,
            for: connection
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: ModelCredentialVerification(
                reference: connection.credential,
                credentialVersionProof: versionProof,
                credentialPayloadHash: payloadHash
            )
        )
        let generation = SequencedProviderGenerationService(
            batches: [
                [
                    .toolCallDelta(
                        index: 0,
                        id: "call-create",
                        name: "project_create",
                        argumentsFragment: #"{"title":"星河","premise":"追查失踪真相"}"#
                    ),
                    .finished(reason: "tool_calls"),
                    .usage(
                        ProviderUsage(
                            inputTokens: 12,
                            outputTokens: 8,
                            totalTokens: 20
                        )
                    )
                ],
                [
                    .textDelta("我已经建立《星河》，并保存了刚才的方向。"),
                    .finished(reason: "stop"),
                    .usage(
                        ProviderUsage(
                            inputTokens: 24,
                            outputTokens: 10,
                            totalTokens: 34
                        )
                    )
                ]
            ]
        )
        let coordinator = ProviderAgentRunCoordinator(
            database: database,
            credentials: credentials,
            generation: generation,
            now: { now }
        )

        let completion = try await coordinator.runToCompletion(
            intent: intent,
            verifiedConnection: verified
        )

        XCTAssertEqual(completion.message.content, "我已经建立《星河》，并保存了刚才的方向。")
        XCTAssertEqual(completion.receipts.count, 1)
        XCTAssertEqual(completion.receipts.first?.toolID, "project.create")
        XCTAssertEqual(completion.receipts.first?.projectID, completion.projects.first?.id)
        XCTAssertEqual(completion.projects.map(\.title), ["星河"])
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
        XCTAssertEqual(generation.prompts.count, 2)
        XCTAssertTrue(generation.prompts[0].toolResults.isEmpty)
        XCTAssertEqual(
            generation.prompts[1].assistantResponse?.toolCalls.first?.id,
            "call-create"
        )
        XCTAssertEqual(generation.prompts[1].toolResults.first?.callID, "call-create")
        XCTAssertTrue(
            generation.prompts[1].toolResults.first?.contentJSON.contains(
                try XCTUnwrap(completion.receipts.first?.id.uuidString.lowercased())
            ) == true
        )
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .continuationCommitted
        )
        XCTAssertEqual(
            try database.agentRun(
                id: completion.request.identity.runID,
                conversationID: conversation.id
            )?.status,
            .completed
        )

        let projection = try XCTUnwrap(
            database.s2ProviderTaskProjection(
                conversationID: conversation.id
            )
        )
        XCTAssertEqual(projection.run.id, completion.request.identity.runID)
        XCTAssertEqual(projection.request.phase, .continuationCommitted)
        XCTAssertEqual(
            projection.usage,
            ProviderUsage(
                inputTokens: 36,
                outputTokens: 18,
                totalTokens: 54
            )
        )
        XCTAssertEqual(projection.receipt, completion.receipts.first)
        XCTAssertEqual(projection.projectTitle, "星河")
        XCTAssertEqual(projection.conversationStatus, "这件事已经处理完成")
        XCTAssertEqual(projection.doingText, "已建立小说《星河》")
        XCTAssertEqual(projection.nextText, "可以回到当前对话继续安排下一步")
        XCTAssertEqual(projection.needsUserText, "目前不需要你操作")
        XCTAssertEqual(
            projection.usageText,
            "实际用量：输入 36 · 输出 18 · 合计 54 tokens"
        )
        XCTAssertEqual(projection.resultTitle, "小说已经建立")
        XCTAssertEqual(
            projection.resultSummary,
            "已经建立《星河》，并保存了这次真实执行回执。"
        )
        XCTAssertEqual(projection.receiptToolName, "创建小说")

        let restored = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        XCTAssertEqual(restored.providerTaskProjection, projection)
        XCTAssertEqual(restored.latestAgentRun, projection.run)
        XCTAssertEqual(restored.lastToolReceipt, projection.receipt)
        XCTAssertEqual(restored.displayedBusinessStatus, "这件事已经处理完成")
    }

    func testCancellationAfterDurableResponseDoesNotConsumeIntent() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 6_100)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "完成响应后立即取消",
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
        let versionProof = hash("c")
        let payloadHash = hash("d")
        credentials.credentialPayloadHash = payloadHash
        try credentials.save(
            "fixture-secret",
            versionProof: versionProof,
            setupAuthorizationHash: nil,
            for: connection
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: ModelCredentialVerification(
                reference: connection.credential,
                credentialVersionProof: versionProof,
                credentialPayloadHash: payloadHash
            )
        )
        let generation = SequencedProviderGenerationService(
            batches: [
                [
                    .textDelta("响应已持久化，但尚未提交继续点。"),
                    .finished(reason: "stop"),
                    .usage(
                        ProviderUsage(
                            inputTokens: 9,
                            outputTokens: 8,
                            totalTokens: 17
                        )
                    )
                ]
            ]
        )
        let coordinator = ProviderAgentRunCoordinator(
            database: database,
            credentials: credentials,
            generation: generation,
            now: { now }
        )
        var cancelledAtDurableResponse = false

        do {
            _ = try await coordinator.runToCompletion(
                intent: intent,
                verifiedConnection: verified
            ) { projection in
                guard projection.phase == .responseComplete else { return }
                cancelledAtDurableResponse = true
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
            }
            XCTFail("Expected cancellation before continuation commit")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .cancelled
            )
        }

        XCTAssertTrue(cancelledAtDurableResponse)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .responseComplete
        )
        XCTAssertNotNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
        XCTAssertFalse(
            try database.listAgentMessages(
                conversationID: conversation.id
            ).contains { $0.role == .assistant }
        )

        let resumed = try await Task { @MainActor in
            try await coordinator.runToCompletion(
                intent: intent,
                verifiedConnection: verified
            )
        }.value
        XCTAssertEqual(resumed.request.phase, .continuationCommitted)
        XCTAssertEqual(generation.prompts.count, 1)
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
        XCTAssertEqual(
            try database.listAgentMessages(
                conversationID: conversation.id
            ).filter { $0.role == .assistant }.count,
            1
        )
        XCTAssertEqual(
            try database.listAgentMessages(
                conversationID: conversation.id
            ).last?.content,
            "响应已持久化，但尚未提交继续点。"
        )
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-loop-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}

private final class SequencedProviderGenerationService:
    ProviderGenerationServing
{
    private var batches: [[ProviderGenerationEvent]]
    private(set) var prompts: [ProviderGenerationPrompt] = []

    init(batches: [[ProviderGenerationEvent]]) {
        self.batches = batches
    }

    func validate(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) throws {
        try prompt.validate()
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        stream(
            request: request,
            verifiedConnection: verifiedConnection,
            secret: secret,
            prompt: .initial(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        )
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        prompt: ProviderGenerationPrompt
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        prompts.append(prompt)
        guard !batches.isEmpty else {
            return AsyncThrowingStream {
                $0.finish(throwing: ProviderGenerationError.invalidPreparedRequest)
            }
        }
        let events = batches.removeFirst()
        return AsyncThrowingStream { continuation in
            events.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
