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

    func testTerminalRequestRetriesOnlyAfterExplicitUserAction() async throws {
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
        let generation = ProviderRetryGenerationService()
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
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
