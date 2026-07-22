@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ProviderRequestPersistenceTests: XCTestCase {
    func testPreparedRequestAndProviderBackedRunCommitTogether() throws {
        let fixture = try makeFixture()

        let stored = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(stored, fixture.request)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID),
            fixture.request
        )
        let run = try XCTUnwrap(
            fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )
        )
        XCTAssertEqual(run.kind, "providerTurn")
        XCTAssertEqual(run.status, .running)
        XCTAssertEqual(run.currentStage, "provider.prepared")
    }

    func testPreparedRequestReplayRequiresExactIdentity() throws {
        let fixture = try makeFixture()
        _ = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(
            try fixture.database.persistPreparedProviderRequest(
                fixture.request,
                verifiedConnection: fixture.verifiedConnection
            ),
            fixture.request
        )

        let conflicting = try makeRequest(
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection,
            requestID: UUID(),
            runID: UUID(),
            responseAssetID: UUID()
        )
        XCTAssertThrowsError(
            try fixture.database.persistPreparedProviderRequest(
                conflicting,
                verifiedConnection: fixture.verifiedConnection
            )
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
        }
    }

    func testCredentialVerificationMismatchFailsBeforeAnyRequestIsStored() throws {
        let fixture = try makeFixture()
        let otherConnection = try ModelConnectionTestFixture.makeConnection(
            credentialID: UUID(),
            secret: "other-secret"
        )
        let otherVerification = try ModelCredentialVerification(
            reference: otherConnection.credential,
            credentialVersionProof: hash("d"),
            credentialPayloadHash: hash("e")
        )
        let otherVerified = try VerifiedModelConnection(
            connection: otherConnection,
            credentialVerification: otherVerification
        )

        XCTAssertThrowsError(
            try fixture.database.persistPreparedProviderRequest(
                fixture.request,
                verifiedConnection: otherVerified
            )
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .invalidProviderRequest)
        }
        XCTAssertNil(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)
        )
        XCTAssertNil(
            try fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )
        )
    }

    func testStreamPayloadAndCheckpointCommitAtomically() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)

        let payloadJSON = #"{"finishReason":null,"text":"你","toolCalls":[]}"#
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            now: fixture.now.addingTimeInterval(2)
        )
        try fixture.database.checkpointProviderResponse(
            streaming,
            responsePayloadJSON: payloadJSON
        )

        XCTAssertEqual(
            try fixture.database.providerRequest(id: streaming.identity.requestID),
            streaming
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: streaming.identity.runID,
                conversationID: streaming.identity.conversationID
            )?.currentStage,
            "provider.streaming"
        )
        XCTAssertEqual(
            try fixture.database.providerResponsePayload(
                assetID: streaming.responseAssetID
            ),
            payloadJSON
        )
    }

    func testCheckpointHashMismatchRollsBackRequestAndResponseAsset() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)
        let payloadJSON = #"{"finishReason":null,"text":"你","toolCalls":[]}"#
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: hash("f"),
            now: fixture.now.addingTimeInterval(2)
        )

        XCTAssertThrowsError(
            try fixture.database.checkpointProviderResponse(
                streaming,
                responsePayloadJSON: payloadJSON
            )
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .invalidProviderResponseAsset)
        }
        XCTAssertEqual(
            try fixture.database.providerRequest(id: sending.identity.requestID),
            sending
        )
        XCTAssertEqual(
            try fixture.database.providerResponsePayload(
                assetID: sending.responseAssetID
            ),
            ProviderResponsePayload.emptyJSON
        )
    }

    func testResponseCompletionRequiresTheExactDurableAsset() throws {
        let fixture = try makeFixture()
        let prepared = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)
        let payloadJSON = #"{"finishReason":"stop","text":"完成","toolCalls":[]}"#
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            now: fixture.now.addingTimeInterval(2)
        )
        try fixture.database.checkpointProviderResponse(
            streaming,
            responsePayloadJSON: payloadJSON
        )
        let usage = ProviderUsage(
            inputTokens: 10,
            outputTokens: 2,
            totalTokens: 12
        )
        let mismatched = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: hash("f"),
            usage: usage,
            now: fixture.now.addingTimeInterval(3)
        )
        XCTAssertThrowsError(
            try fixture.database.completeProviderResponse(mismatched)
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .invalidProviderResponseAsset)
        }
        XCTAssertThrowsError(
            try fixture.database.updateProviderRequest(mismatched)
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .invalidProviderRequest)
        }

        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            usage: usage,
            now: fixture.now.addingTimeInterval(3)
        )
        try fixture.database.completeProviderResponse(completed)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: completed.identity.requestID),
            completed
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: completed.identity.runID,
                conversationID: completed.identity.conversationID
            )?.currentStage,
            "provider.responseComplete"
        )
        let committedResult = try fixture.database.commitProviderContinuation(
            completed,
            now: fixture.now.addingTimeInterval(4)
        )
        XCTAssertEqual(committedResult.request.phase, .continuationCommitted)
        XCTAssertEqual(committedResult.message.role, .assistant)
        XCTAssertEqual(committedResult.message.content, "完成")
        XCTAssertNil(
            try fixture.database.latestPendingModelIntent(
                conversationID: fixture.intent.conversationID
            )
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: completed.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.status,
            .completed
        )
        let replay = try fixture.database.commitProviderContinuation(
            committedResult.request,
            now: fixture.now.addingTimeInterval(5)
        )
        XCTAssertEqual(replay, committedResult)

        let committed = try ProviderRequestLifecycle.commitContinuation(
            completed,
            now: fixture.now.addingTimeInterval(4)
        )
        XCTAssertThrowsError(
            try fixture.database.updateProviderRequest(committed)
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .invalidProviderRequest)
        }
    }

    func testDefiniteFailureAllowsANewAttemptButUnknownOutcomeDoesNot() throws {
        let retryFixture = try makeFixture()
        let first = try retryFixture.database.persistPreparedProviderRequest(
            retryFixture.request,
            verifiedConnection: retryFixture.verifiedConnection
        )
        let failed = try ProviderRequestLifecycle.failBeforeSend(
            first,
            failure: .authentication,
            now: retryFixture.now.addingTimeInterval(1)
        )
        try retryFixture.database.updateProviderRequest(failed)
        let retry = try makeRequest(
            intent: retryFixture.intent,
            verifiedConnection: retryFixture.verifiedConnection,
            requestID: UUID(),
            runID: UUID(),
            responseAssetID: UUID(),
            attemptNumber: 2,
            turnSequence: 1,
            previousRequestID: first.identity.requestID,
            now: retryFixture.now.addingTimeInterval(2)
        )

        XCTAssertEqual(
            try retryFixture.database.persistPreparedProviderRequest(
                retry,
                verifiedConnection: retryFixture.verifiedConnection
            ),
            retry
        )
        XCTAssertEqual(
            try retryFixture.database.providerRequest(
                intentID: retryFixture.intent.id
            ),
            retry
        )

        let unknownFixture = try makeFixture()
        let unknownFirst = try unknownFixture.database.persistPreparedProviderRequest(
            unknownFixture.request,
            verifiedConnection: unknownFixture.verifiedConnection
        )
        let sending = try ProviderRequestLifecycle.markSending(
            unknownFirst,
            now: unknownFixture.now.addingTimeInterval(1)
        )
        try unknownFixture.database.updateProviderRequest(sending)
        let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
            sending,
            reason: .network,
            now: unknownFixture.now.addingTimeInterval(2)
        )
        try unknownFixture.database.updateProviderRequest(unknown)
        let forbiddenRetry = try makeRequest(
            intent: unknownFixture.intent,
            verifiedConnection: unknownFixture.verifiedConnection,
            requestID: UUID(),
            runID: UUID(),
            responseAssetID: UUID(),
            attemptNumber: 2,
            turnSequence: 1,
            previousRequestID: unknownFirst.identity.requestID,
            now: unknownFixture.now.addingTimeInterval(3)
        )
        XCTAssertThrowsError(
            try unknownFixture.database.persistPreparedProviderRequest(
                forbiddenRetry,
                verifiedConnection: unknownFixture.verifiedConnection
            )
        ) { error in
            XCTAssertEqual(
                error as? AppDatabaseError,
                .invalidProviderRequest
            )
        }
    }

    func testToolResultContinuationReusesRunAndAdvancesLinearTurn() throws {
        let fixture = try makeFixture()
        let first = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )
        let sending = try ProviderRequestLifecycle.markSending(
            first,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)
        let payloadJSON = #"{"finishReason":"tool_calls","text":"","toolCalls":[{"argumentsJSON":"{}","id":"call-1","index":0,"name":"project_status"}]}"#
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            now: fixture.now.addingTimeInterval(2)
        )
        try fixture.database.checkpointProviderResponse(
            streaming,
            responsePayloadJSON: payloadJSON
        )
        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            usage: ProviderUsage(
                inputTokens: 10,
                outputTokens: 3,
                totalTokens: 13
            ),
            now: fixture.now.addingTimeInterval(3)
        )
        try fixture.database.completeProviderResponse(completed)
        let continuation = try makeRequest(
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection,
            requestID: UUID(),
            runID: first.identity.runID,
            responseAssetID: UUID(),
            attemptNumber: 1,
            turnSequence: 2,
            previousRequestID: first.identity.requestID,
            now: fixture.now.addingTimeInterval(4)
        )

        _ = try fixture.database.persistPreparedProviderRequest(
            continuation,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(
            try fixture.database.providerRequest(intentID: fixture.intent.id),
            continuation
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: first.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.currentStage,
            "provider.prepared"
        )
    }

    private func makeFixture() throws -> (
        database: AppDatabase,
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        request: ProviderRequestSnapshot,
        now: Date
    ) {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let now = Date(timeIntervalSince1970: 2_000)
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
        let verification = try ModelCredentialVerification(
            reference: connection.credential,
            credentialVersionProof: hash("a"),
            credentialPayloadHash: hash("b"),
            setupAuthorizationHash: hash("c")
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: verification
        )
        return (
            database,
            intent,
            verified,
            try makeRequest(
                intent: intent,
                verifiedConnection: verified,
                requestID: UUID(),
                runID: UUID(),
                responseAssetID: UUID(),
                now: now
            ),
            now
        )
    }

    private func makeRequest(
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        requestID: UUID,
        runID: UUID,
        responseAssetID: UUID,
        attemptNumber: Int = 1,
        turnSequence: Int = 1,
        previousRequestID: UUID? = nil,
        now: Date = Date(timeIntervalSince1970: 2_000)
    ) throws -> ProviderRequestSnapshot {
        try ProviderRequestLifecycle.prepare(
            requestID: requestID,
            runID: runID,
            idempotencyKey: "provider.request.\(intent.id.uuidString).\(attemptNumber).\(turnSequence)",
            attemptNumber: attemptNumber,
            turnSequence: turnSequence,
            previousRequestID: previousRequestID,
            intent: intent,
            verifiedConnection: verifiedConnection,
            responseAssetID: responseAssetID,
            promptManifestHash: hash("1"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: hash("3"),
            disclosureScopeHash: hash("4"),
            requestPolicyHash: hash("5"),
            now: now
        )
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-request-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
