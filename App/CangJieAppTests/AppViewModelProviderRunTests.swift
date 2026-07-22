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

        try await waitUntil {
            try database.latestPendingModelIntent(
                conversationID: intent.conversationID
            ) == nil
        }
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
        try await waitUntil {
            try database.providerRequest(intentID: intent.id)?.phase == .streaming
        }
        XCTAssertEqual(viewModel.displayedProviderStreamText, "尚未完成")

        viewModel.startNewS1Conversation()

        XCTAssertNotEqual(viewModel.selectedConversationID, intent.conversationID)
        XCTAssertNil(viewModel.displayedProviderStreamText)
        XCTAssertFalse(viewModel.isProviderRunVisible)

        viewModel.selectS1Conversation(intent.conversationID)

        XCTAssertEqual(viewModel.displayedProviderStreamText, "尚未完成")
        XCTAssertTrue(viewModel.isProviderRunVisible)

        viewModel.cancelProviderRun()

        try await waitUntil {
            try database.providerRequest(intentID: intent.id)?.phase == .outcomeUnknown
        }
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
            "本地安全对账已完成，这次请求的结果仍不能确认"
        )
    }

    func testRelaunchReconcilesSentRequestLocallyWithoutResending() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 9_000)
        let conversation = try database.ensureDefaultConversation(now: now)
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
            "本地安全对账已完成，这次请求的结果仍不能确认"
        )
    }

    func testRelaunchCommitsDurableCompleteResponseWithoutTransport() async throws {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 10_000)
        let conversation = try database.ensureDefaultConversation(now: now)
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

        try await waitUntil {
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            ) == nil
        }
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
        for _ in 0..<200 {
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

private final class AppViewModelProviderGenerationService:
    ProviderGenerationServing
{
    private let events: [ProviderGenerationEvent]
    private let hangsAfterEvents: Bool
    private(set) var callCount = 0

    init(
        events: [ProviderGenerationEvent],
        hangsAfterEvents: Bool = false
    ) {
        self.events = events
        self.hangsAfterEvents = hangsAfterEvents
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        callCount += 1
        return AsyncThrowingStream { continuation in
            events.forEach { continuation.yield($0) }
            guard hangsAfterEvents else {
                continuation.finish()
                return
            }
            let task = Task {
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: 10_000_000)
                    }
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: CancellationError())
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
