@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

@MainActor
final class ProviderAgentRunCoordinatorTests: XCTestCase {
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
