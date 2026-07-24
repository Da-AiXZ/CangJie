@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class AppViewModelProviderRetryTests: XCTestCase {
    func testRelaunchDoesNotAutoSendPersistedOfflineIntentBeforeConfirmation() async throws {
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
        let append = try database.appendPendingModelIntentTurn(
            selectedConversationID: nil,
            rawRequest: "离线保存后重启也必须由我确认",
            intentID: UUID(),
            admissionCondition: .networkConfirmationRequired
        )
        let generation = ProviderRetryGenerationService()

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            networkAvailabilityObserver: TestNetworkAvailabilityObserver(
                state: .available
            ),
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        let waiting = try XCTUnwrap(
            database.agentTask(intentID: append.pendingIntent.id)
        )
        XCTAssertEqual(waiting.status, .waitingUser)
        XCTAssertEqual(waiting.waitingReason, .networkConfirmation)
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertTrue(viewModel.canResumeProviderTask)
        XCTAssertEqual(viewModel.providerTaskResumeTitle, "确认发送")

        viewModel.resumeProviderTask()
        await viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(generation.callCount, 1)
    }

    func testTerminalRequestRetriesWithExplicitlySelectedConnection() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 11_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "明确重试这件事",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(intent)
        let originalConnection = try ModelConnectionTestFixture.makeConnection(
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: UUID(),
            selectedModel: "fixture-model",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            originalConnection,
            makeCurrent: true,
            now: now
        )
        credentials.credentialPayloadHash = hash("b")
        try credentials.save(
            "fixture-secret",
            versionProof: hash("a"),
            setupAuthorizationHash: nil,
            for: originalConnection
        )
        let replacementConnection = try ModelConnectionTestFixture.makeConnection(
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat",
            secret: "replacement-secret"
        )
        _ = try database.storeModelConnection(
            replacementConnection,
            makeCurrent: false,
            now: now.addingTimeInterval(0.5)
        )
        try credentials.save(
            "replacement-secret",
            versionProof: hash("c"),
            setupAuthorizationHash: nil,
            for: replacementConnection
        )
        let verified = try XCTUnwrap(
            credentials.verifiedConnection(for: originalConnection)
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
        let failed = try ProviderRequestLifecycle.failBeforeSend(
            prepared,
            failure: .rateLimited,
            now: now.addingTimeInterval(1)
        )
        try database.updateProviderRequest(failed)
        let generation = ProviderRetryGenerationService()
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        XCTAssertEqual(generation.callCount, 0)
        XCTAssertTrue(viewModel.canRetryProviderRun)
        XCTAssertNotNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )

        let replacementVerified = try XCTUnwrap(
            credentials.verifiedConnection(for: replacementConnection)
        )
        let coordinator = ProviderAgentRunCoordinator(
            database: database,
            credentials: credentials,
            generation: generation,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { now.addingTimeInterval(2) }
        )
        XCTAssertThrowsError(
            try coordinator.prepareExplicitRetry(
                intent: intent,
                verifiedConnection: replacementVerified
            )
        )
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.status,
            .failed,
            "A failed retry transaction must not leak a runnable task"
        )

        try viewModel.modelConnectionSetup.selectCurrentConnection(
            replacementConnection.id
        )

        viewModel.retryProviderRun()
        XCTAssertNil(viewModel.providerRunStartBlocker)
        await viewModel.waitForProviderRunToSettle()
        XCTAssertNil(
            viewModel.providerRunFailureDescription,
            viewModel.providerRunFailureDescription ?? ""
        )
        let retried = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(generation.callCount, 1)
        XCTAssertEqual(retried.identity.attemptNumber, 2)
        XCTAssertEqual(
            retried.identity.connectionID,
            replacementConnection.id
        )
        XCTAssertEqual(retried.identity.provider, .deepSeek)
        XCTAssertEqual(retried.identity.modelID, "deepseek-chat")
        XCTAssertEqual(
            retried.identity.credentialID,
            replacementConnection.credential.id
        )
        XCTAssertEqual(
            retried.identity.previousRequestID,
            failed.identity.requestID
        )
        XCTAssertEqual(retried.phase, .continuationCommitted)
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
    }

    func testDurableCompleteResponseRetriesWithoutCurrentConnection() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 11_500)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "恢复已经完整保存的回复",
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
            text: "这条回复不需要再次联网。",
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
                inputTokens: 8,
                outputTokens: 6,
                totalTokens: 14
            ),
            now: now.addingTimeInterval(3)
        )
        try database.completeProviderResponse(complete)
        let failed = try XCTUnwrap(
            database.settleAgentTaskControlAfterProviderExit(
                intentID: intent.id,
                now: now.addingTimeInterval(4)
            )
        )
        XCTAssertEqual(failed.status, .failed)

        credentials.suppressResolve = true
        let generation = ProviderRetryGenerationService()
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        XCTAssertNil(viewModel.modelConnectionSetup.currentConnection)
        XCTAssertTrue(viewModel.canRetryProviderRun)

        viewModel.retryProviderRun()
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .continuationCommitted
        )
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.status,
            .completed
        )
        XCTAssertEqual(
            viewModel.conversationMessages.last,
            "仓颉：这条回复不需要再次联网。"
        )
    }

    func testFailedTaskWithoutAdoptedOutputCanBeDiscarded() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 12_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        _ = try database.selectS1Conversation(conversation.id, now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "这次失败后不再继续",
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
        let failed = try ProviderRequestLifecycle.failBeforeSend(
            prepared,
            failure: .rateLimited,
            now: now.addingTimeInterval(1)
        )
        try database.updateProviderRequest(failed)

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        XCTAssertTrue(viewModel.canDiscardProviderTask)
        viewModel.discardProviderTask()

        let discarded = try XCTUnwrap(
            database.agentTask(intentID: intent.id)
        )
        XCTAssertEqual(discarded.status, .discarded)
        XCTAssertEqual(discarded.outcome, .discarded)
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
        XCTAssertTrue(viewModel.canSubmitModelDependentMessage)
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-retry-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}

private final class ProviderRetryGenerationService: ProviderGenerationServing {
    private(set) var callCount = 0

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        callCount += 1
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("重试后已完成。"))
            continuation.yield(.finished(reason: "stop"))
            continuation.yield(
                .usage(
                    ProviderUsage(
                        inputTokens: 6,
                        outputTokens: 4,
                        totalTokens: 10
                    )
                )
            )
            continuation.finish()
        }
    }
}
