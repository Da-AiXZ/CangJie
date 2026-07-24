@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class ProviderAgentRunCoordinatorTests: XCTestCase {
    func testUnknownPricingPausesBeforeTransportAndKeepsExactPreparedRequest() async throws {
        let fixture = try makeFixture(saveCredential: true)
        let service = RecordingProviderGenerationService(events: [])
        let coordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: service,
            budgetEstimator: FailClosedProviderBudgetEstimator(),
            now: { fixture.now }
        )

        do {
            _ = try await coordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected budget approval")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .budgetApprovalRequired
            )
        }

        XCTAssertEqual(service.callCount, 0)
        let request = try XCTUnwrap(
            fixture.database.providerRequest(intentID: fixture.intent.id)
        )
        XCTAssertEqual(request.phase, .prepared)
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        XCTAssertEqual(task.status, .paused)
        let approval = try XCTUnwrap(
            fixture.database.pendingProviderBudgetApproval(taskID: task.id)
        )
        XCTAssertEqual(approval.providerRequestID, request.identity.requestID)
        XCTAssertEqual(approval.status, .pending)
    }

    func testExactBudgetApprovalResumesAndSendsTheSamePreparedRequest() async throws {
        let fixture = try makeFixture(saveCredential: true)
        let estimator = FailClosedProviderBudgetEstimator()
        let pausedService = RecordingProviderGenerationService(events: [])
        let pausedCoordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: pausedService,
            budgetEstimator: estimator,
            now: { fixture.now }
        )
        do {
            _ = try await pausedCoordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected budget approval")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .budgetApprovalRequired
            )
        }

        let prepared = try XCTUnwrap(
            fixture.database.providerRequest(intentID: fixture.intent.id)
        )
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let approval = try XCTUnwrap(
            fixture.database.pendingProviderBudgetApproval(taskID: task.id)
        )
        let prompt = ProviderGenerationPrompt.initial(
            systemPrompt: ProviderAgentRunCoordinator.systemPrompt,
            userPrompt: fixture.intent.userRequest
        )
        let estimate = try estimator.estimate(
            taskScope: ProviderRequestBudgetTaskScope(
                taskID: task.id,
                intentID: task.intentID,
                activeRunID: prepared.identity.runID
            ),
            request: prepared,
            prompt: prompt
        )
        let approved = try fixture.database.approveProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        XCTAssertEqual(approved.status, .approved)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: prepared.identity.requestID)?.phase,
            .prepared
        )

        let service = RecordingProviderGenerationService(events: [
            .textDelta("approved"),
            .finished(reason: "stop"),
            .usage(
                ProviderUsage(
                    inputTokens: 4,
                    outputTokens: 2,
                    totalTokens: 6
                )
            )
        ])
        let coordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: service,
            budgetEstimator: estimator,
            now: { fixture.now.addingTimeInterval(2) }
        )
        let completion = try await coordinator.run(
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(service.callCount, 1)
        XCTAssertEqual(
            completion.request.identity.requestID,
            prepared.identity.requestID
        )
        XCTAssertEqual(completion.request.phase, .responseComplete)
        XCTAssertEqual(
            try fixture.database.providerBudgetApproval(id: approval.id)?.status,
            .consumed
        )
    }

    func testRequestIsDurableAndSendingBeforeTransportStarts() async throws {
        let fixture = try makeFixture(saveCredential: true)
        let service = RecordingProviderGenerationService(
            events: [
                .textDelta("已收到"),
                .finished(reason: "stop"),
                .usage(
                    ProviderUsage(
                        inputTokens: 8,
                        outputTokens: 3,
                        totalTokens: 11
                    )
                )
            ],
            onStart: { request in
                XCTAssertEqual(
                    try fixture.database.providerRequest(
                        id: request.identity.requestID
                    )?.phase,
                    .sending
                )
                XCTAssertEqual(
                    try fixture.database.agentRun(
                        id: request.identity.runID,
                        conversationID: request.identity.conversationID
                    )?.currentStage,
                    "provider.sending"
                )
            }
        )
        let coordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: service,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )
        var projections: [ProviderRunProjection] = []

        let completion = try await coordinator.run(
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection
        ) { projections.append($0) }

        XCTAssertEqual(completion.response.text, "已收到")
        XCTAssertEqual(completion.request.phase, .responseComplete)
        XCTAssertEqual(completion.request.usage?.totalTokens, 11)
        XCTAssertEqual(service.callCount, 1)
        XCTAssertEqual(projections.last?.text, "已收到")
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: completion.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.currentStage,
            "provider.responseComplete"
        )
        XCTAssertNotNil(
            try fixture.database.latestPendingModelIntent(
                conversationID: fixture.intent.conversationID
            )
        )
    }

    func testMissingCredentialFailsBeforeTransportAndPreservesIntent() async throws {
        let fixture = try makeFixture(saveCredential: false)
        let service = RecordingProviderGenerationService(events: [])
        let coordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: service,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )

        do {
            _ = try await coordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected connection invalid")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .connectionInvalid
            )
        }

        XCTAssertEqual(service.callCount, 0)
        let request = try XCTUnwrap(
            fixture.database.providerRequest(intentID: fixture.intent.id)
        )
        XCTAssertEqual(request.phase, .failed)
        XCTAssertEqual(request.failure, .authentication)
        XCTAssertEqual(
            try fixture.database.s2ProviderTaskProjection(
                conversationID: fixture.intent.conversationID
            )?.recoveryState,
            .connectionInvalid
        )
        XCTAssertNotNil(
            try fixture.database.latestPendingModelIntent(
                conversationID: fixture.intent.conversationID
            )
        )
    }

    func testInterruptedStreamPersistsPartialOutputAndUnknownOutcome() async throws {
        let fixture = try makeFixture(saveCredential: true)
        let service = RecordingProviderGenerationService(
            events: [.textDelta("部分")],
            terminalError: ProviderGenerationError.outcomeUnknown(.network)
        )
        let coordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: service,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )

        do {
            _ = try await coordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected unknown outcome")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .outcomeUnknown(.network)
            )
        }

        let request = try XCTUnwrap(
            fixture.database.providerRequest(intentID: fixture.intent.id)
        )
        XCTAssertEqual(request.phase, .outcomeUnknown)
        XCTAssertEqual(request.interruption, .network)
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: request.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.status,
            .reconciling
        )
        let payloadJSON = try XCTUnwrap(
            fixture.database.providerResponsePayload(
                assetID: request.responseAssetID
            )
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                ProviderResponsePayload.self,
                from: Data(payloadJSON.utf8)
            ).text,
            "部分"
        )
    }

    func testExistingSentRequestIsNeverSentAgain() async throws {
        let fixture = try makeFixture(saveCredential: true)
        let prepared = try ProviderAgentRunCoordinator.makePreparedRequest(
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection,
            now: fixture.now
        )
        _ = try fixture.database.persistPreparedProviderRequest(
            prepared,
            verifiedConnection: fixture.verifiedConnection
        )
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: fixture.now
        )
        try fixture.database.updateProviderRequest(sending)
        let service = RecordingProviderGenerationService(events: [])
        let coordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: service,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )

        do {
            _ = try await coordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected reconciliation requirement")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .requiresReconciliation
            )
        }
        XCTAssertEqual(service.callCount, 0)
    }

    func testDefiniteFailureCanRetryAsANewAttemptAndRun() async throws {
        let fixture = try makeFixture(saveCredential: false)
        let firstService = RecordingProviderGenerationService(events: [])
        let firstCoordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: firstService,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )
        do {
            _ = try await firstCoordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected connection invalid")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .connectionInvalid
            )
        }
        let first = try XCTUnwrap(
            fixture.database.providerRequest(intentID: fixture.intent.id)
        )
        let failedTask = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        _ = try fixture.database.retryFailedAgentTask(
            id: failedTask.id,
            expectedRevision: failedTask.revision,
            commandID: UUID(),
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.credentials.save(
            "fixture-secret",
            versionProof: first.identity.credentialVersionProof,
            setupAuthorizationHash: first.identity.setupAuthorizationHash,
            for: fixture.verifiedConnection.connection
        )
        let retryService = RecordingProviderGenerationService(
            events: [
                .textDelta("已恢复"),
                .finished(reason: "stop"),
                .usage(
                    ProviderUsage(
                        inputTokens: 5,
                        outputTokens: 2,
                        totalTokens: 7
                    )
                )
            ]
        )
        let retryCoordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: retryService,
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )

        let completion = try await retryCoordinator.run(
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(completion.request.identity.attemptNumber, 2)
        XCTAssertEqual(completion.request.identity.turnSequence, 1)
        XCTAssertEqual(
            completion.request.identity.previousRequestID,
            first.identity.requestID
        )
        XCTAssertNotEqual(
            completion.request.identity.runID,
            first.identity.runID
        )
        XCTAssertEqual(completion.response.text, "已恢复")
        XCTAssertEqual(firstService.callCount, 0)
        XCTAssertEqual(retryService.callCount, 1)
    }

    func testRetryRejectsAChangedUserRequestWithTheSameIntentID() async throws {
        let fixture = try makeFixture(saveCredential: false)
        let firstCoordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: RecordingProviderGenerationService(events: []),
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )
        do {
            _ = try await firstCoordinator.run(
                intent: fixture.intent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected connection invalid")
        } catch {
            XCTAssertEqual(
                error as? ProviderAgentRunError,
                .connectionInvalid
            )
        }
        let failed = try XCTUnwrap(
            fixture.database.providerRequest(intentID: fixture.intent.id)
        )
        let failedTask = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        _ = try fixture.database.retryFailedAgentTask(
            id: failedTask.id,
            expectedRevision: failedTask.revision,
            commandID: UUID(),
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.credentials.save(
            "fixture-secret",
            versionProof: failed.identity.credentialVersionProof,
            setupAuthorizationHash: failed.identity.setupAuthorizationHash,
            for: fixture.verifiedConnection.connection
        )
        let changedIntent = try PendingModelIntent(
            id: fixture.intent.id,
            conversationID: fixture.intent.conversationID,
            projectID: fixture.intent.projectID,
            branchID: fixture.intent.branchID,
            userRequest: "篡改后的请求",
            createdAt: fixture.intent.createdAt
        )
        let retryCoordinator = ProviderAgentRunCoordinator(
            database: fixture.database,
            credentials: fixture.credentials,
            generation: RecordingProviderGenerationService(events: []),
            budgetEstimator: DeterministicTestProviderBudgetEstimator(),
            now: { fixture.now }
        )

        do {
            _ = try await retryCoordinator.run(
                intent: changedIntent,
                verifiedConnection: fixture.verifiedConnection
            )
            XCTFail("Expected changed intent to fail closed")
        } catch {
            XCTAssertEqual(
                error as? AppDatabaseError,
                .invalidProviderRequest
            )
        }
    }

    private func makeFixture(
        saveCredential: Bool
    ) throws -> (
        database: AppDatabase,
        credentials: RecordingCredentialRepository,
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        now: Date
    ) {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let credentials = RecordingCredentialRepository()
        let now = Date(timeIntervalSince1970: 4_000)
        let conversation = try database.ensureDefaultConversation(now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "创建一本悬疑小说",
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
        if saveCredential {
            try credentials.save(
                "fixture-secret",
                versionProof: versionProof,
                setupAuthorizationHash: nil,
                for: connection
            )
        }
        let verification = try ModelCredentialVerification(
            reference: connection.credential,
            credentialVersionProof: versionProof,
            credentialPayloadHash: payloadHash
        )
        return (
            database,
            credentials,
            intent,
            try VerifiedModelConnection(
                connection: connection,
                credentialVerification: verification
            ),
            now
        )
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-run-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}

private final class RecordingProviderGenerationService:
    ProviderGenerationServing
{
    private let events: [ProviderGenerationEvent]
    private let terminalError: Error?
    private let onStart: ((ProviderRequestSnapshot) throws -> Void)?
    private(set) var callCount = 0

    init(
        events: [ProviderGenerationEvent],
        terminalError: Error? = nil,
        onStart: ((ProviderRequestSnapshot) throws -> Void)? = nil
    ) {
        self.events = events
        self.terminalError = terminalError
        self.onStart = onStart
    }

    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        callCount += 1
        do {
            try onStart?(request)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return AsyncThrowingStream { continuation in
            events.forEach { continuation.yield($0) }
            if let terminalError {
                continuation.finish(throwing: terminalError)
            } else {
                continuation.finish()
            }
        }
    }
}
