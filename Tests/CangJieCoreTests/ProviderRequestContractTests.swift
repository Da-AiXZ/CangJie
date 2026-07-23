import Foundation
import XCTest
@_spi(ModelCredentialVerification) @testable import CangJieCore

final class ProviderRequestContractTests: XCTestCase {
    private let preparedAt = Date(timeIntervalSince1970: 1_000)
    private let sentAt = Date(timeIntervalSince1970: 1_001)
    private let streamedAt = Date(timeIntervalSince1970: 1_002)

    func testRequestMustBePersistedPreparedBeforeItCanBeMarkedSending() throws {
        let prepared = try makePreparedRequest()

        XCTAssertEqual(prepared.phase, .prepared)
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: prepared),
            .sendPersistedRequest
        )

        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: sentAt
        )
        XCTAssertEqual(sending.phase, .sending)
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: sending),
            .reconcileUnknownOutcome
        )
    }

    func testLifecycleCanonicalizesFractionalTimestampsForPersistence() throws {
        let preparedInput = Date(
            timeIntervalSinceReferenceDate: 805_149_589.000_000_1
        )
        let sentInput = Date(
            timeIntervalSinceReferenceDate: 805_149_590.000_000_1
        )
        XCTAssertNotEqual(
            preparedInput,
            Date(timeIntervalSince1970: preparedInput.timeIntervalSince1970)
        )

        let prepared = try makePreparedRequest(now: preparedInput)
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: sentInput
        )
        XCTAssertNoThrow(
            try ProviderRequestLifecycle.validateTransition(
                from: prepared,
                to: sending
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        XCTAssertEqual(
            try decoder.decode(
                ProviderRequestSnapshot.self,
                from: encoder.encode(prepared)
            ),
            prepared
        )
        XCTAssertEqual(
            try decoder.decode(
                ProviderRequestSnapshot.self,
                from: encoder.encode(sending)
            ),
            sending
        )
    }

    func testStreamCheckpointRequiresMonotonicCursorAndByteCount() throws {
        let sending = try ProviderRequestLifecycle.markSending(
            makePreparedRequest(),
            now: sentAt
        )
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: 6,
            responseHash: hash("b"),
            now: streamedAt
        )

        XCTAssertEqual(streaming.phase, .streaming)
        XCTAssertEqual(streaming.streamCursor, 1)
        XCTAssertEqual(streaming.receivedUTF8Bytes, 6)
        XCTAssertThrowsError(
            try ProviderRequestLifecycle.checkpointStream(
                streaming,
                cursor: 1,
                receivedUTF8Bytes: 7,
                responseHash: hash("c"),
                now: streamedAt.addingTimeInterval(1)
            )
        ) { error in
            XCTAssertEqual(
                error as? ProviderRequestError,
                .nonMonotonicStreamCheckpoint
            )
        }
    }

    func testCompletionPersistsFinalHashUsageAndRecoveryAction() throws {
        let sending = try ProviderRequestLifecycle.markSending(
            makePreparedRequest(),
            now: sentAt
        )
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: 1,
            responseHash: hash("d"),
            now: streamedAt
        )
        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: hash("d"),
            usage: ProviderUsage(
                inputTokens: 12,
                outputTokens: 7,
                totalTokens: 19
            ),
            now: streamedAt
        )

        XCTAssertEqual(completed.phase, .responseComplete)
        XCTAssertEqual(completed.responseHash, hash("d"))
        XCTAssertEqual(completed.usage?.totalTokens, 19)
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: completed),
            .continueFromDurableResponse
        )

        let committed = try ProviderRequestLifecycle.commitContinuation(
            completed,
            now: streamedAt.addingTimeInterval(1)
        )
        XCTAssertEqual(committed.phase, .continuationCommitted)
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: committed),
            .terminal
        )
    }

    func testInterruptedSentRequestBecomesUnknownAndCannotBeSentAgain() throws {
        let sending = try ProviderRequestLifecycle.markSending(
            makePreparedRequest(),
            now: sentAt
        )
        let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
            sending,
            reason: .lifecycleInterruption,
            now: streamedAt
        )

        XCTAssertEqual(unknown.phase, .outcomeUnknown)
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: unknown),
            .reconcileUnknownOutcome
        )
        XCTAssertThrowsError(
            try ProviderRequestLifecycle.markSending(
                unknown,
                now: streamedAt.addingTimeInterval(1)
            )
        )
    }

    func testOnlyUnsentCancellationAndDefiniteProviderRejectionAreTerminal() throws {
        let prepared = try makePreparedRequest()
        let cancelled = try ProviderRequestLifecycle.cancel(
            prepared,
            now: sentAt
        )
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: cancelled),
            .terminal
        )

        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: sentAt
        )
        let failed = try ProviderRequestLifecycle.reject(
            sending,
            failure: .authentication,
            now: streamedAt
        )
        XCTAssertEqual(failed.failure, .authentication)
        XCTAssertEqual(
            ProviderRequestRecovery.nextAction(for: failed),
            .terminal
        )

        let interrupted = try ProviderRequestLifecycle.markOutcomeUnknown(
            sending,
            reason: .cancelled,
            now: streamedAt
        )
        XCTAssertEqual(interrupted.phase, .outcomeUnknown)
        XCTAssertThrowsError(
            try ProviderRequestLifecycle.cancel(sending, now: streamedAt)
        )
    }

    func testManifestAndResponseHashesMustBeCanonical() throws {
        XCTAssertThrowsError(
            try makePreparedRequest(promptManifestHash: "not-a-hash")
        ) { error in
            XCTAssertEqual(error as? ProviderRequestError, .invalidHash)
        }
    }

    func testPreparedIdentityComesFromPendingIntentAndVerifiedConnection() throws {
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: UUID(),
            projectID: UUID(),
            branchID: UUID(),
            userRequest: "创建一本悬疑小说",
            createdAt: preparedAt
        )
        let connection = try ModelConnection.make(
            id: UUID(),
            name: "DeepSeek",
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            credentialVersionID: UUID(),
            selectedModel: "deepseek-chat"
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

        let request = try ProviderRequestLifecycle.prepare(
            requestID: UUID(),
            runID: UUID(),
            idempotencyKey: "provider.request.\(intent.id.uuidString).1",
            intent: intent,
            verifiedConnection: verified,
            responseAssetID: UUID(),
            promptManifestHash: hash("1"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: hash("3"),
            disclosureScopeHash: hash("4"),
            requestPolicyHash: hash("5"),
            now: preparedAt
        )

        XCTAssertEqual(request.identity.intentID, intent.id)
        XCTAssertEqual(request.identity.branchID, intent.branchID)
        XCTAssertEqual(request.identity.connectionID, connection.id)
        XCTAssertEqual(request.identity.baseURL, connection.baseURL)
        XCTAssertEqual(
            request.identity.credentialVersionProof,
            verification.credentialVersionProof
        )
        XCTAssertEqual(
            request.identity.credentialPayloadHash,
            verification.credentialPayloadHash
        )
        XCTAssertEqual(request.identity.attemptNumber, 1)
        XCTAssertEqual(request.identity.turnSequence, 1)
        XCTAssertNil(request.identity.previousRequestID)
    }

    func testRequestCoordinatesRequireOneLinearPredecessorAfterTheFirstTurn() throws {
        let runID = UUID()
        let previousRequestID = UUID()

        XCTAssertNoThrow(
            try makePreparedRequest(
                attemptNumber: 1,
                turnSequence: 2,
                previousRequestID: previousRequestID,
                runID: runID
            )
        )
        XCTAssertNoThrow(
            try makePreparedRequest(
                attemptNumber: 2,
                turnSequence: 1,
                previousRequestID: previousRequestID,
                runID: UUID()
            )
        )
        for invalid in [
            (0, 1, previousRequestID),
            (1, 0, previousRequestID),
            (1, 1, previousRequestID),
            (1, 2, nil)
        ] as [(Int, Int, UUID?)] {
            XCTAssertThrowsError(
                try makePreparedRequest(
                    attemptNumber: invalid.0,
                    turnSequence: invalid.1,
                    previousRequestID: invalid.2,
                    runID: runID
                )
            ) { error in
                XCTAssertEqual(
                    error as? ProviderRequestError,
                    .invalidIdentity
                )
            }
        }
    }

    func testPublishedV1IdentityDecodesAsFirstAttemptAndFirstTurn() throws {
        let prepared = try makePreparedRequest()
        let data = try JSONEncoder().encode(prepared)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let identity = try XCTUnwrap(object["identity"] as? [String: Any])

        XCTAssertNil(identity["attemptNumber"])
        XCTAssertNil(identity["turnSequence"])
        XCTAssertNil(identity["previousRequestID"])

        let decoded = try JSONDecoder().decode(
            ProviderRequestSnapshot.self,
            from: data
        )
        XCTAssertEqual(decoded.identity.attemptNumber, 1)
        XCTAssertEqual(decoded.identity.turnSequence, 1)
        XCTAssertNil(decoded.identity.previousRequestID)
    }

    func testDecodedSnapshotMustSatisfyLifecycleInvariants() throws {
        let sending = try ProviderRequestLifecycle.markSending(
            makePreparedRequest(),
            now: sentAt
        )
        let data = try JSONEncoder().encode(sending)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["streamCursor"] = -1
        let tampered = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ProviderRequestSnapshot.self,
                from: tampered
            )
        )
    }

    func testDecodedSnapshotRejectsNoncanonicalFractionalTimestamp() throws {
        let prepared = try makePreparedRequest()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: encoder.encode(prepared)
            ) as? [String: Any]
        )
        object["createdAt"] = 1_753_456_789.123_456_7
        object["updatedAt"] = 1_753_456_789.123_456_7
        let tampered = try JSONSerialization.data(withJSONObject: object)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        XCTAssertThrowsError(
            try decoder.decode(
                ProviderRequestSnapshot.self,
                from: tampered
            )
        ) { error in
            XCTAssertEqual(
                error as? ProviderRequestError,
                .invalidSnapshot
            )
        }
    }

    func testUsageOverflowFailsClosed() throws {
        let sending = try ProviderRequestLifecycle.markSending(
            makePreparedRequest(),
            now: sentAt
        )
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: 1,
            responseHash: hash("d"),
            now: streamedAt
        )
        XCTAssertThrowsError(
            try ProviderRequestLifecycle.complete(
                streaming,
                responseHash: hash("d"),
                usage: ProviderUsage(
                    inputTokens: Int.max,
                    outputTokens: 1,
                    totalTokens: Int.max
                ),
                now: streamedAt
            )
        ) { error in
            XCTAssertEqual(error as? ProviderRequestError, .invalidUsage)
        }
    }

    func testTransitionValidationRejectsAValidButUnrelatedTerminalSnapshot() throws {
        let prepared = try makePreparedRequest()
        let sending = try ProviderRequestLifecycle.markSending(
            prepared,
            now: sentAt
        )
        let failedBeforeSend = try ProviderRequestLifecycle.failBeforeSend(
            prepared,
            failure: .providerUnavailable,
            now: streamedAt
        )

        XCTAssertThrowsError(
            try ProviderRequestLifecycle.validateTransition(
                from: sending,
                to: failedBeforeSend
            )
        )
    }

    private func makePreparedRequest(
        promptManifestHash: String? = nil,
        attemptNumber: Int = 1,
        turnSequence: Int = 1,
        previousRequestID: UUID? = nil,
        runID: UUID = UUID(),
        now: Date? = nil
    ) throws -> ProviderRequestSnapshot {
        try ProviderRequestLifecycle.prepare(
            identity: ProviderRequestIdentity(
                requestID: UUID(),
                idempotencyKey: "provider.request.test.1",
                intentID: UUID(),
                conversationID: UUID(),
                projectID: nil,
                branchID: nil,
                runID: runID,
                attemptNumber: attemptNumber,
                turnSequence: turnSequence,
                previousRequestID: previousRequestID,
                connectionID: UUID(),
                credentialID: UUID(),
                credentialVersionID: UUID(),
                credentialVersionProof: hash("a"),
                credentialPayloadHash: hash("b"),
                setupAuthorizationHash: hash("c"),
                provider: .deepSeek,
                baseURL: URL(string: "https://api.deepseek.com")!,
                modelID: "deepseek-chat"
            ),
            responseAssetID: UUID(),
            promptManifestHash: promptManifestHash ?? hash("1"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: hash("3"),
            disclosureScopeHash: hash("4"),
            requestPolicyHash: hash("5"),
            now: now ?? preparedAt
        )
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
