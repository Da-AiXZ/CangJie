@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ProviderRequestPersistenceTests: XCTestCase {
    func testCompletedResponseRequiresFinishReasonMatchingToolShape() throws {
        let call = ProviderToolCallPayload(
            index: 0,
            id: "call-1",
            name: "project_status",
            argumentsJSON: "{}"
        )
        let valid = [
            ProviderResponsePayload(
                text: "完成",
                toolCalls: [],
                finishReason: "stop"
            ),
            ProviderResponsePayload(
                text: "",
                toolCalls: [call],
                finishReason: "tool_calls"
            )
        ]
        for payload in valid {
            XCTAssertNoThrow(
                try payload.validate(allowIncompleteToolCalls: false)
            )
        }

        let invalid = [
            ProviderResponsePayload(
                text: "截断",
                toolCalls: [],
                finishReason: "length"
            ),
            ProviderResponsePayload(
                text: "过滤",
                toolCalls: [],
                finishReason: "content_filter"
            ),
            ProviderResponsePayload(
                text: "未知",
                toolCalls: [],
                finishReason: "vendor_specific"
            ),
            ProviderResponsePayload(
                text: "",
                toolCalls: [call],
                finishReason: "stop"
            ),
            ProviderResponsePayload(
                text: "完成",
                toolCalls: [],
                finishReason: "tool_calls"
            ),
            ProviderResponsePayload(
                text: "   ",
                toolCalls: [],
                finishReason: "stop"
            )
        ]
        for payload in invalid {
            XCTAssertThrowsError(
                try payload.validate(allowIncompleteToolCalls: false)
            )
        }
    }

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

    func testOfflinePreparedRequestCommitsAsWaitingForNetworkConfirmation() throws {
        let fixture = try makeFixture(
            admissionCondition: .networkConfirmationRequired
        )

        let stored = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(stored, fixture.request)
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        XCTAssertEqual(task.status, .waitingUser)
        XCTAssertEqual(task.waitingReason, .networkConfirmation)
        XCTAssertEqual(task.activeRunID, fixture.request.identity.runID)
        let run = try XCTUnwrap(
            fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )
        )
        XCTAssertEqual(run.status, .waitingUser)
        XCTAssertEqual(run.currentStage, "provider.prepared")
    }

    func testConnectionInvalidTaskCannotBindPreparedProviderRequest() throws {
        let fixture = try makeFixture()
        let running = try fixture.database.enqueueAgentTask(
            for: fixture.intent,
            commandID: fixture.intent.id,
            now: fixture.now
        )
        let waiting = try fixture.database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .waitingUser,
            waitingReason: .connectionInvalid,
            now: fixture.now.addingTimeInterval(1)
        ).task
        XCTAssertEqual(waiting.waitingReason, .connectionInvalid)

        XCTAssertThrowsError(
            try fixture.database.persistPreparedProviderRequest(
                fixture.request,
                verifiedConnection: fixture.verifiedConnection
            )
        ) { error in
            XCTAssertEqual(error as? AppDatabaseError, .invalidAgentTask)
        }
        XCTAssertNil(
            try fixture.database.providerRequest(
                id: fixture.request.identity.requestID
            )
        )
        XCTAssertNil(
            try fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )
        )
    }

    func testBoundPreparedRequestProjectsConnectionInvalidAndResumeStates() throws {
        let fixture = try makeFixture()
        _ = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )
        let running = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )

        let waiting = try fixture.database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .waitingUser,
            waitingReason: .connectionInvalid,
            now: fixture.now.addingTimeInterval(1)
        ).task

        XCTAssertEqual(waiting.waitingReason, .connectionInvalid)
        XCTAssertEqual(
            try fixture.database.providerRequest(intentID: fixture.intent.id)?.phase,
            .prepared
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.status,
            .waitingUser
        )

        let resumed = try fixture.database.transitionAgentTask(
            id: waiting.id,
            expectedRevision: waiting.revision,
            commandID: UUID(),
            to: .running,
            now: fixture.now.addingTimeInterval(2)
        ).task
        XCTAssertEqual(resumed.status, .running)
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: fixture.request.identity.runID,
                conversationID: fixture.intent.conversationID
            )?.status,
            .running
        )
    }

    func testQueuedOfflinePromotionAndReplayKeepTaskAndRunWaiting() throws {
        let fixture = try makeFixture()
        let primary = try fixture.database.enqueueAgentTask(
            for: fixture.intent,
            commandID: fixture.intent.id,
            now: fixture.now
        )
        let secondNow = fixture.now.addingTimeInterval(1)
        _ = try fixture.database.selectNewS1Conversation(now: secondNow)
        let secondConversation = try fixture.database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: "offline queued request"),
            now: secondNow
        ).conversation
        let secondIntent = try PendingModelIntent(
            id: UUID(),
            conversationID: secondConversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "offline queued request",
            createdAt: secondNow
        )
        _ = try fixture.database.storePendingModelIntent(
            secondIntent,
            admissionCondition: .networkConfirmationRequired
        )
        let secondRequest = try makeRequest(
            intent: secondIntent,
            verifiedConnection: fixture.verifiedConnection,
            requestID: UUID(),
            runID: UUID(),
            responseAssetID: UUID(),
            now: secondNow
        )
        _ = try fixture.database.persistPreparedProviderRequest(
            secondRequest,
            verifiedConnection: fixture.verifiedConnection
        )
        let queued = try XCTUnwrap(
            fixture.database.agentTask(intentID: secondIntent.id)
        )
        XCTAssertEqual(queued.status, .queued)

        let completionCommandID = UUID()
        let completed = try fixture.database.transitionAgentTask(
            id: primary.id,
            expectedRevision: primary.revision,
            commandID: completionCommandID,
            to: .completed,
            outcome: .natural,
            now: secondNow.addingTimeInterval(1)
        )
        let promoted = try XCTUnwrap(completed.promotedTask)
        XCTAssertEqual(promoted.id, queued.id)
        XCTAssertEqual(promoted.status, .waitingUser)
        XCTAssertEqual(promoted.waitingReason, .networkConfirmation)
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: secondRequest.identity.runID,
                conversationID: secondIntent.conversationID
            )?.status,
            .waitingUser
        )

        let replay = try fixture.database.transitionAgentTask(
            id: primary.id,
            expectedRevision: primary.revision,
            commandID: completionCommandID,
            to: .completed,
            outcome: .natural,
            now: secondNow.addingTimeInterval(2)
        )
        XCTAssertEqual(replay.promotedTask, promoted)
    }

    func testFractionalTimestampIsCanonicalizedBeforePersistence() throws {
        let fixture = try makeFixture(
            now: Date(
                timeIntervalSinceReferenceDate: 805_149_589.000_000_1
            )
        )

        let stored = try fixture.database.persistPreparedProviderRequest(
            fixture.request,
            verifiedConnection: fixture.verifiedConnection
        )

        XCTAssertEqual(stored, fixture.request)
        XCTAssertEqual(
            stored,
            try fixture.database.providerRequest(
                id: fixture.request.identity.requestID
            )
        )
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

    func testProviderExitFailsRunningTaskAfterDurableResponse() throws {
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
        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            usage: ProviderUsage(
                inputTokens: 10,
                outputTokens: 2,
                totalTokens: 12
            ),
            now: fixture.now.addingTimeInterval(3)
        )
        try fixture.database.completeProviderResponse(completed)

        let settled = try XCTUnwrap(
            fixture.database.settleAgentTaskControlAfterProviderExit(
                intentID: fixture.intent.id,
                now: fixture.now.addingTimeInterval(4)
            )
        )

        XCTAssertEqual(settled.status, .failed)
        XCTAssertNil(settled.outcome)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: completed.identity.requestID),
            completed
        )
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: completed.identity.runID,
                conversationID: completed.identity.conversationID
            )?.status,
            .waitingUser
        )

        let rebound = try fixture.database.retryFailedAgentTask(
            id: settled.id,
            expectedRevision: settled.revision,
            commandID: UUID(),
            now: fixture.now.addingTimeInterval(5)
        )
        XCTAssertEqual(rebound.status, .running)
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: completed.identity.runID,
                conversationID: completed.identity.conversationID
            )?.currentStage,
            "provider.responseCompleteRecovery"
        )
    }

    func testProviderExitPreservesCreatedProjectForLocalContinuationRetry() throws {
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
        let payloadJSON = #"{"finishReason":"tool_calls","text":"","toolCalls":[{"index":0,"id":"call-1","name":"project_create","argumentsJSON":"{\"premise\":\"悬疑小说\",\"title\":\"星河\"}"}]}"#
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
                outputTokens: 2,
                totalTokens: 12
            ),
            now: fixture.now.addingTimeInterval(3)
        )
        try fixture.database.completeProviderResponse(completed)
        let invocation = try ProjectToolInvocation.parse(
            providerFunctionName: "project_create",
            argumentsJSON: #"{"premise":"悬疑小说","title":"星河"}"#,
            providerCallID: "call-1",
            providerCallIndex: 0,
            providerRequestID: completed.identity.requestID,
            runID: completed.identity.runID,
            conversationID: completed.identity.conversationID,
            projectID: nil
        )
        _ = try fixture.database.executeProviderTool(
            invocation,
            now: fixture.now.addingTimeInterval(4)
        )

        let settled = try XCTUnwrap(
            fixture.database.settleAgentTaskControlAfterProviderExit(
                intentID: fixture.intent.id,
                now: fixture.now.addingTimeInterval(5)
            )
        )
        let storedRequest = try XCTUnwrap(
            fixture.database.providerRequest(id: completed.identity.requestID)
        )
        let run = try XCTUnwrap(
            fixture.database.agentRun(
                id: completed.identity.runID,
                conversationID: completed.identity.conversationID
            )
        )

        XCTAssertEqual(settled.status, .failed)
        XCTAssertNil(settled.outcome)
        XCTAssertEqual(storedRequest, completed)
        XCTAssertEqual(run.status, .waitingUser)
        XCTAssertEqual(run.currentStage, "provider.hostContinuationFailed")
        XCTAssertEqual(try fixture.database.listProjects().map(\.title), ["星河"])

        let rebound = try fixture.database.retryFailedAgentTask(
            id: settled.id,
            expectedRevision: settled.revision,
            commandID: UUID(),
            now: fixture.now.addingTimeInterval(6)
        )
        XCTAssertEqual(rebound.status, .running)
        XCTAssertEqual(
            try fixture.database.agentRun(
                id: completed.identity.runID,
                conversationID: completed.identity.conversationID
            )?.currentStage,
            "provider.responseCompleteRecovery"
        )
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
        let failedTask = try XCTUnwrap(
            retryFixture.database.agentTask(intentID: retryFixture.intent.id)
        )
        _ = try retryFixture.database.retryFailedAgentTask(
            id: failedTask.id,
            expectedRevision: failedTask.revision,
            commandID: UUID(),
            now: retryFixture.now.addingTimeInterval(1.5)
        )
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
                  .invalidAgentTask
              )
          }
          XCTAssertEqual(
              try unknownFixture.database.providerRequest(
                  intentID: unknownFixture.intent.id
              ),
              unknown
          )
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

    private func makeFixture(
        now: Date = Date(timeIntervalSince1970: 2_000),
        admissionCondition: PendingModelIntentAdmissionCondition = .ready
    ) throws -> (
        database: AppDatabase,
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        request: ProviderRequestSnapshot,
        now: Date
    ) {
        let database = try AppDatabase(path: temporaryDatabasePath())
        let conversation = try database.ensureDefaultConversation(now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "创建一本悬疑小说",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(
            intent,
            admissionCondition: admissionCondition
        )
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
