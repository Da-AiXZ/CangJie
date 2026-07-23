@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class AppViewModelProviderRunTests: XCTestCase {
    func testVerifiedCurrentConnectionRunsPendingIntentOnceAndCommitsResponse() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 7_000)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let generation = AppViewModelProviderGenerationService(
            events: [
                .textDelta("我已经接着处理这件事。"),
                .finished(reason: "stop"),
                .usage(
                    ProviderUsage(
                        inputTokens: 8,
                        outputTokens: 6,
                        totalTokens: 14
                    )
                )
            ]
        )
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        viewModel.draft = "请继续处理这个故事念头"

        viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
        XCTAssertNil(viewModel.providerRunStartBlocker)
        await viewModel.waitForProviderRunToSettle()
        XCTAssertNil(
            viewModel.providerRunFailureDescription,
            viewModel.providerRunFailureDescription ?? ""
        )
        let conversationID = try XCTUnwrap(viewModel.selectedConversationID)
        let messages = try database.listAgentMessages(
            conversationID: conversationID
        )
        XCTAssertEqual(generation.callCount, 1)
        XCTAssertEqual(messages.last?.role, .assistant)
        XCTAssertEqual(messages.last?.content, "我已经接着处理这件事。")
        XCTAssertEqual(viewModel.conversationMessages.last, "仓颉：我已经接着处理这件事。")
        let request = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(request.phase, .continuationCommitted)
        XCTAssertEqual(
            try database.agentRun(
                id: request.identity.runID,
                conversationID: conversationID
            )?.status,
            .completed
        )
        XCTAssertFalse(viewModel.isAgentWorking)
        XCTAssertTrue(viewModel.providerStreamText.isEmpty)
    }

    func testOfflineRequestWaitsForConnectivityAndExplicitConfirmation() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(connection, makeCurrent: true)
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let generation = AppViewModelProviderGenerationService(
            events: [
                .textDelta("联网确认后只发送一次。"),
                .finished(reason: "stop"),
                .usage(
                    ProviderUsage(
                        inputTokens: 6,
                        outputTokens: 4,
                        totalTokens: 10
                    )
                )
            ]
        )
        let network = TestNetworkAvailabilityObserver(state: .unavailable)
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            networkAvailabilityObserver: network,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        viewModel.draft = "离线保存这条模型请求"

        viewModel.sendModelDependentMessage()

        let intent = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
        let request = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        let waiting = try XCTUnwrap(
            database.agentTask(intentID: intent.id)
        )
        XCTAssertEqual(request.phase, .prepared)
        XCTAssertEqual(waiting.status, .waitingUser)
        XCTAssertEqual(waiting.waitingReason, .networkConfirmation)
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertFalse(viewModel.canResumeProviderTask)

        network.update(.available)

        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.waitingReason,
            .networkConfirmation
        )
        XCTAssertTrue(viewModel.canResumeProviderTask)
        XCTAssertEqual(viewModel.providerTaskResumeTitle, "确认发送")

        viewModel.handleScenePhase(.inactive)
        viewModel.handleScenePhase(.active)
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.waitingReason,
            .networkConfirmation
        )

        let restored = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            networkAvailabilityObserver: TestNetworkAvailabilityObserver(
                state: .available
            ),
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertTrue(restored.canResumeProviderTask)
        XCTAssertEqual(restored.providerTaskResumeTitle, "确认发送")

        restored.resumeProviderTask()
        await restored.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 1)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .continuationCommitted
        )
    }

    func testSecondConversationQueuesAndRunsAfterTheFirstCompletes() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let generation = FIFOAppViewModelProviderGenerationService()
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        viewModel.draft = "先处理第一段讨论"
        viewModel.sendModelDependentMessage()
        let firstIntent = try XCTUnwrap(
            viewModel.modelConnectionSetup.pendingIntent
        )
        try await waitUntil { generation.callCount == 1 }

        viewModel.startNewS1Conversation()
        XCTAssertNil(viewModel.selectedConversationID)
        viewModel.draft = "再处理第二段讨论"
        viewModel.sendModelDependentMessage()
        let secondConversationID = try XCTUnwrap(
            viewModel.selectedConversationID
        )
        let secondIntent = try XCTUnwrap(
            viewModel.modelConnectionSetup.pendingIntent
        )
        let queued = try XCTUnwrap(
            database.agentTask(intentID: secondIntent.id)
        )
        XCTAssertEqual(queued.status, .queued)
        XCTAssertEqual(generation.callCount, 1)

        generation.finishFirstRequest()
        try await waitUntil { generation.callCount == 2 }
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(
            try database.agentTask(intentID: firstIntent.id)?.status,
            .completed
        )
        XCTAssertEqual(
            try database.agentTask(intentID: secondIntent.id)?.status,
            .completed
        )
        XCTAssertEqual(
            try database.listAgentMessages(
                conversationID: secondConversationID
            ).last?.content,
            "第二件事已经处理。"
        )
        XCTAssertEqual(generation.callCount, 2)
    }

    func testCancelPersistsUnknownOutcomeAndKeepsPendingIntent() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let generation = AppViewModelProviderGenerationService(
            events: [.textDelta("尚未完成")],
            hangsAfterEvents: true
        )
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        viewModel.draft = "请处理后允许我停止"

        viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
        XCTAssertNil(viewModel.providerRunStartBlocker)
        try await waitUntil {
            try database.providerRequest(intentID: intent.id)?.phase == .streaming
                || viewModel.providerRunFailureDescription != nil
        }
        XCTAssertNil(
            viewModel.providerRunFailureDescription,
            viewModel.providerRunFailureDescription ?? ""
        )
        XCTAssertEqual(viewModel.displayedProviderStreamText, "尚未完成")

        viewModel.startNewS1Conversation()

        XCTAssertNotEqual(viewModel.selectedConversationID, intent.conversationID)
        XCTAssertNil(viewModel.displayedProviderStreamText)
        XCTAssertFalse(viewModel.isProviderRunVisible)

        viewModel.selectS1Conversation(intent.conversationID)

        XCTAssertEqual(viewModel.displayedProviderStreamText, "尚未完成")
        XCTAssertTrue(viewModel.isProviderRunVisible)

        viewModel.cancelProviderRun()
        await viewModel.waitForProviderRunToSettle()
        let request = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(request.identity.attemptNumber, 1)
        XCTAssertEqual(request.interruption, .cancelled)
        XCTAssertEqual(generation.callCount, 1)
        XCTAssertNotNil(
            try database.latestPendingModelIntent(
                conversationID: intent.conversationID
            )
        )
        XCTAssertFalse(
            try database.listAgentMessages(
                conversationID: intent.conversationID
            ).contains { $0.role == .assistant }
        )
        XCTAssertFalse(viewModel.isProviderRunActive)
        XCTAssertTrue(viewModel.providerStreamText.isEmpty)

        viewModel.handleScenePhase(.inactive)
        viewModel.handleScenePhase(.active)

        XCTAssertEqual(viewModel.latestAgentRun?.status, .reconciling)
        XCTAssertEqual(
            viewModel.displayedBusinessStatus,
            "正在确认刚才的请求是否已经停止"
        )
    }

    func testRelaunchReconcilesSentRequestLocallyWithoutResending() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 9_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "恢复后不要重复发送",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let verified = try XCTUnwrap(
            credentials.verifiedConnection(for: connection)
        )
        let prepared = try ProviderAgentRunCoordinator.makePreparedRequest(
            intent: intent,
            verifiedConnection: verified,
            now: now
        )
        _ = try database.persistPreparedProviderRequest(
            prepared,
            intent: intent,
            verifiedConnection: verified
        )
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: now.addingTimeInterval(1)
        )
        try database.updateProviderRequest(sending)
        let generation = AppViewModelProviderGenerationService(events: [])

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        XCTAssertNil(
            viewModel.providerRecoveryFailureDescription,
            viewModel.providerRecoveryFailureDescription ?? ""
        )

        let reconciled = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(reconciled.phase, .outcomeUnknown)
        XCTAssertEqual(reconciled.interruption, .lifecycleInterruption)
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertNotNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
        XCTAssertFalse(viewModel.isProviderRunActive)
        XCTAssertEqual(
            viewModel.displayedBusinessStatus,
            "正在核对上次请求的真实结果"
        )
    }

    func testRelaunchReconcilesANonCurrentConversationWithoutResending() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 9_500)
        let firstConversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(firstConversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: firstConversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "恢复非当前对话且不要重发",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let verified = try XCTUnwrap(
            credentials.verifiedConnection(for: connection)
        )
        let prepared = try ProviderAgentRunCoordinator.makePreparedRequest(
            intent: intent,
            verifiedConnection: verified,
            now: now
        )
        _ = try database.persistPreparedProviderRequest(
            prepared,
            intent: intent,
            verifiedConnection: verified
        )
        try database.updateProviderRequest(
            try ProviderRequestLifecycle.markSending(
                prepared,
                now: now.addingTimeInterval(1)
            )
        )
        _ = try database.selectNewS1Conversation(
            now: now.addingTimeInterval(2)
        )
        let second = try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: "这是另一段当前对话"),
            now: now.addingTimeInterval(3)
        ).conversation
        let generation = AppViewModelProviderGenerationService(events: [])

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        XCTAssertEqual(viewModel.selectedConversationID, second.id)
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .outcomeUnknown
        )
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.status,
            .reconciling
        )
    }

    func testPreparedRequestWithMissingExactCredentialWaitsAsConnectionInvalid() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 9_750)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "原连接失效后保留请求",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let verified = try XCTUnwrap(
            credentials.verifiedConnection(for: connection)
        )
        _ = try database.persistPreparedProviderRequest(
            ProviderAgentRunCoordinator.makePreparedRequest(
                intent: intent,
                verifiedConnection: verified,
                now: now
            ),
            intent: intent,
            verifiedConnection: verified
        )
        try credentials.delete(for: connection)
        let generation = AppViewModelProviderGenerationService(events: [])

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        let waiting = try XCTUnwrap(
            database.agentTask(intentID: intent.id)
        )
        XCTAssertEqual(waiting.status, .waitingUser)
        XCTAssertEqual(waiting.waitingReason, .connectionInvalid)
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            viewModel.providerTaskProjection?.recoveryState,
            .connectionInvalid
        )
        XCTAssertEqual(
            viewModel.providerTaskProjection?.recoveryText,
            "连接失效：原请求已保留，等待你修复连接"
        )
    }

    func testRelaunchCommitsDurableCompleteResponseWithoutTransport() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 10_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "恢复已经完成的回复",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: connection
        )
        let verified = try XCTUnwrap(
            credentials.verifiedConnection(for: connection)
        )
        let prepared = try ProviderAgentRunCoordinator.makePreparedRequest(
            intent: intent,
            verifiedConnection: verified,
            now: now
        )
        _ = try database.persistPreparedProviderRequest(
            prepared,
            intent: intent,
            verifiedConnection: verified
        )
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: now.addingTimeInterval(1)
        )
        try database.updateProviderRequest(sending)
        let payload = ProviderResponsePayload(
            text: "恢复后直接显示这条完成回复。",
            toolCalls: [],
            finishReason: "stop"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadJSON = try XCTUnwrap(
            String(data: encoder.encode(payload), encoding: .utf8)
        )
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
        let complete = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            usage: ProviderUsage(
                inputTokens: 9,
                outputTokens: 7,
                totalTokens: 16
            ),
            now: now.addingTimeInterval(3)
        )
        try database.completeProviderResponse(complete)
        let generation = AppViewModelProviderGenerationService(events: [])

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        await viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .continuationCommitted
        )
        XCTAssertEqual(
            try database.listAgentMessages(
                conversationID: conversation.id
            ).last?.content,
            "恢复后直接显示这条完成回复。"
        )
        XCTAssertEqual(
            viewModel.conversationMessages.last,
            "仓颉：恢复后直接显示这条完成回复。"
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () throws -> Bool
    ) async throws {
        for _ in 0..<1_000 {
            if try condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for Provider run")
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("app-view-model-provider-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
