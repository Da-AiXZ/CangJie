@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

@MainActor
final class AppViewModelProviderRunTests: XCTestCase {
    func testBudgetApprovalPausesBeforeSendThenResumesTheExactRequest() async throws {
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
        let generation = AppViewModelProviderGenerationService(events: [
            .textDelta("budget approved"),
            .finished(reason: "stop"),
            .usage(
                ProviderUsage(
                    inputTokens: 7,
                    outputTokens: 3,
                    totalTokens: 10
                )
            )
        ])
        let network = TestNetworkAvailabilityObserver(state: .available)
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            networkAvailabilityObserver: network,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        viewModel.draft = "Please continue this request"

        viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 0)
        let prepared = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(prepared.phase, .prepared)
        XCTAssertEqual(viewModel.providerTaskProjection?.task.status, .paused)
        XCTAssertTrue(viewModel.canApproveProviderBudget)
        XCTAssertFalse(viewModel.canResumeProviderTask)

        let displayedApproval = try XCTUnwrap(
            viewModel.providerTaskProjection?.budgetApproval
        )
        network.updateWithoutNotifying(.unavailable)
        viewModel.approveProviderBudget(
            approvalID: displayedApproval.id,
            displayedBindingHash: displayedApproval.bindingHash
        )
        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            viewModel.providerTaskProjection?.task.waitingReason,
            .networkConfirmation
        )
        XCTAssertEqual(
            viewModel.providerTaskProjection?.budgetApproval?.status,
            .approved
        )
        XCTAssertFalse(viewModel.canResumeProviderTask)

        network.update(.available)
        let resumeIdentity = try XCTUnwrap(
            viewModel.providerTaskProjection?.commandIdentity
        )
        XCTAssertTrue(viewModel.canResumeProviderTask)
        viewModel.resumeProviderTask(displayedIdentity: resumeIdentity)
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 1)
        let completed = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(
            completed.identity.requestID,
            prepared.identity.requestID
        )
        XCTAssertEqual(completed.phase, .continuationCommitted)
        XCTAssertEqual(viewModel.providerTaskProjection?.budgetApproval, nil)
        let usage = try database.providerBudgetUsageSnapshot(
            taskID: try XCTUnwrap(viewModel.providerTaskProjection?.task.id)
        )
        XCTAssertEqual(usage.cumulativeInputTokens, 7)
        XCTAssertEqual(usage.cumulativeOutputTokens, 3)
    }

    func testBudgetApprovalAcrossToolTurnKeepsDurableReceiptVisible() async throws {
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
        let generation = SequencedAppViewModelProviderGenerationService(
            batches: [
                [
                    .toolCallDelta(
                        index: 0,
                        id: "call-budget-create",
                        name: "project_create",
                        argumentsFragment:
                            #"{"title":"星河","premise":"悬疑小说"}"#
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
                    .textDelta("我已经建立《星河》。"),
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
        viewModel.draft = "创建一本叫星河的悬疑小说"

        viewModel.sendModelDependentMessage()
        await viewModel.waitForProviderRunToSettle()
        let firstApproval = try XCTUnwrap(
            viewModel.providerTaskProjection?.budgetApproval
        )
        viewModel.approveProviderBudget(
            approvalID: firstApproval.id,
            displayedBindingHash: firstApproval.bindingHash
        )
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 1)
        let durableReceipt = try XCTUnwrap(
            viewModel.providerTaskProjection?.receipt
        )
        XCTAssertEqual(durableReceipt.toolID, "project.create")
        let secondApproval = try XCTUnwrap(
            viewModel.providerTaskProjection?.budgetApproval
        )
        XCTAssertEqual(
            viewModel.providerTaskProjection?.request.identity.turnSequence,
            2
        )

        viewModel.approveProviderBudget(
            approvalID: secondApproval.id,
            displayedBindingHash: secondApproval.bindingHash
        )
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 2)
        XCTAssertEqual(
            viewModel.providerTaskProjection?.request.phase,
            .continuationCommitted
        )
        XCTAssertEqual(viewModel.lastToolReceipt?.id, durableReceipt.id)
        XCTAssertEqual(
            viewModel.providerTaskProjection?.receipt?.id,
            durableReceipt.id
        )
    }

    func testBudgetPreflightFailureStopsWithoutAutomaticRetryLoop() async throws {
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
        let generation = AppViewModelProviderGenerationService(events: [])
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: ThrowingProviderBudgetEstimator(),
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        viewModel.draft = "budget preflight must fail once"

        viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(generation.callCount, 0)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .cancelled
        )
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.status,
            .failed
        )
        let requestCount = try await database.queue.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM providerRequest WHERE intentID = ?",
                arguments: [intent.id.uuidString]
            ) ?? 0
        }
        XCTAssertEqual(requestCount, 1)
    }

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
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
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
        XCTAssertFalse(
            messages.contains {
                $0.role == .system
                    && $0.content == ModelConnectionSetupConversationCopy.intentSaved
            }
        )
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
        let network = TestNetworkAvailabilityObserver(state: .available)
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            networkAvailabilityObserver: network,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )
        network.updateWithoutNotifying(.unavailable)
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
        XCTAssertFalse(
            viewModel.modelConnectionSetup.isPresented(
                for: intent.conversationID
            )
        )
        XCTAssertTrue(viewModel.isComposerAvailable)
        XCTAssertFalse(viewModel.canSubmitModelDependentMessage)
        XCTAssertEqual(
            viewModel.conversationMessages.last,
            ModelConnectionSetupConversationCopy.networkConfirmationRequired
        )

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
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
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

    func testBackgroundBeforeSendKeepsPreparedRequestForSameAttempt() async throws {
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
                .textDelta("恢复后只发送一次"),
                .finished(reason: "stop"),
                .usage(
                    ProviderUsage(
                        inputTokens: 3,
                        outputTokens: 3,
                        totalTokens: 6
                    )
                )
            ]
        )
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

        viewModel.draft = "进入后台前保存但不要发送"
        viewModel.sendModelDependentMessage()
        let intent = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)

        viewModel.handleScenePhase(.background)
        await viewModel.waitForProviderRunToSettle()

        let suspended = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(suspended.phase, .prepared)
        XCTAssertEqual(suspended.identity.attemptNumber, 1)
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.status,
            .running
        )
        XCTAssertEqual(generation.callCount, 0)

        viewModel.handleScenePhase(.active)
        await viewModel.waitForProviderRunToSettle()

        let completed = try XCTUnwrap(
            database.providerRequest(intentID: intent.id)
        )
        XCTAssertEqual(completed.phase, .continuationCommitted)
        XCTAssertEqual(completed.identity.requestID, suspended.identity.requestID)
        XCTAssertEqual(completed.identity.attemptNumber, 1)
        XCTAssertEqual(generation.callCount, 1)
    }

    func testOfflineSecondConversationQueuesUntilExplicitConfirmationAfterFirstCompletes() async throws {
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
        let network = TestNetworkAvailabilityObserver(state: .available)
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            networkAvailabilityObserver: network,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: 50_000_000
        )

        viewModel.draft = "先处理第一段讨论"
        viewModel.sendModelDependentMessage()
        let firstIntent = try XCTUnwrap(
            viewModel.modelConnectionSetup.pendingIntent
        )
        try await waitUntil { generation.callCount == 1 }

        network.update(.unavailable)
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
        XCTAssertFalse(
            viewModel.modelConnectionSetup.isPresented(
                for: secondConversationID
            )
        )
        XCTAssertTrue(viewModel.isComposerAvailable)
        XCTAssertFalse(viewModel.canSubmitModelDependentMessage)
        XCTAssertEqual(
            viewModel.displayedBusinessStatus,
            "这件事已经排队，尚未发送新的模型请求"
        )
        network.update(.available)
        viewModel.draft = "任务处理期间继续写的下一条草稿"

        generation.finishFirstRequest()
        try await waitUntil {
            (try? database.agentTask(intentID: secondIntent.id)?.status)
                == .waitingUser
        }
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(
            try database.agentTask(intentID: firstIntent.id)?.status,
            .completed
        )
        XCTAssertEqual(
            try database.agentTask(intentID: secondIntent.id)?.status,
            .waitingUser
        )
        XCTAssertEqual(
            try database.agentTask(intentID: secondIntent.id)?.waitingReason,
            .networkConfirmation
        )
        XCTAssertEqual(generation.callCount, 1)
        XCTAssertTrue(viewModel.canResumeProviderTask)
        XCTAssertEqual(viewModel.providerTaskResumeTitle, "确认发送")

        viewModel.resumeProviderTask()
        await viewModel.waitForProviderRunToSettle()

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
        XCTAssertEqual(viewModel.draft, "任务处理期间继续写的下一条草稿")
        try await waitUntil {
            (try? database.restoreS1ConversationWorkspace().draft)
                == "任务处理期间继续写的下一条草稿"
        }
    }

    func testTaskSurfaceKeepsOfflinePrimaryVisibleAcrossConversationQueue() async throws {
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
        let generation = FIFOAppViewModelProviderGenerationService()
        let network = TestNetworkAvailabilityObserver(state: .unavailable)
        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            networkAvailabilityObserver: network,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: UInt64.max
        )

        viewModel.draft = "离线保存第一件事"
        viewModel.sendModelDependentMessage()
        let firstIntent = try XCTUnwrap(
            viewModel.modelConnectionSetup.pendingIntent
        )
        let firstTask = try XCTUnwrap(
            database.agentTask(intentID: firstIntent.id)
        )
        XCTAssertEqual(firstTask.status, .waitingUser)
        XCTAssertEqual(firstTask.waitingReason, .networkConfirmation)

        viewModel.startNewS1Conversation()
        XCTAssertNotEqual(
            viewModel.displayedBusinessStatus,
            "当前只验证界面、导航和本地保存，尚未接入真正的模型任务"
        )
        XCTAssertEqual(
            viewModel.taskSurfaceProviderTaskProjection?.task.id,
            firstTask.id
        )

        viewModel.draft = "第二个对话里的请求"
        viewModel.sendModelDependentMessage()
        let secondIntent = try XCTUnwrap(
            viewModel.modelConnectionSetup.pendingIntent
        )
        XCTAssertEqual(
            try database.agentTask(intentID: secondIntent.id)?.status,
            .queued
        )
        XCTAssertEqual(
            viewModel.taskSurfaceProviderTaskProjection?.task.id,
            firstTask.id
        )

        network.update(.available)
        XCTAssertTrue(viewModel.canResumeTaskSurfaceProviderTask)
        XCTAssertEqual(viewModel.taskSurfaceProviderTaskResumeTitle, "确认发送")
        viewModel.resumeTaskSurfaceProviderTask()
        try await waitUntil {
            generation.callCount == 1
                && (try? database.providerRequest(
                    intentID: firstIntent.id
                )?.phase) == .streaming
        }
        XCTAssertTrue(viewModel.canPauseTaskSurfaceProviderTask)

        viewModel.pauseTaskSurfaceProviderTask()
        await viewModel.waitForProviderRunToSettle()

        XCTAssertEqual(
            try database.providerRequest(intentID: firstIntent.id)?.phase,
            .outcomeUnknown
        )
        XCTAssertEqual(
            try database.agentTask(intentID: firstIntent.id)?.status,
            .reconciling
        )
        XCTAssertFalse(viewModel.canResumeTaskSurfaceProviderTask)
        XCTAssertTrue(viewModel.canStopAndKeepTaskSurfaceProviderTask)

        viewModel.stopAndKeepTaskSurfaceProviderTask()

        XCTAssertEqual(
            try database.agentTask(intentID: firstIntent.id)?.status,
            .completed
        )
        XCTAssertEqual(
            try database.providerRequest(intentID: firstIntent.id)?.phase,
            .outcomeUnknown
        )
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: firstIntent.conversationID
            )
        )
        try await waitUntil {
            (try? database.agentTask(intentID: secondIntent.id)?.status)
                == .waitingUser
        }
        await viewModel.waitForProviderRunToSettle()

        let secondTask = try XCTUnwrap(
            database.agentTask(intentID: secondIntent.id)
        )
        XCTAssertEqual(secondTask.waitingReason, .networkConfirmation)
        XCTAssertEqual(
            viewModel.taskSurfaceProviderTaskProjection?.task.id,
            secondTask.id
        )
        XCTAssertTrue(viewModel.canResumeTaskSurfaceProviderTask)
        XCTAssertEqual(generation.callCount, 1)
        viewModel.resumeTaskSurfaceProviderTask()
        await viewModel.waitForProviderRunToSettle()
        XCTAssertEqual(generation.callCount, 2)
        XCTAssertEqual(generation.intentIDs, [firstIntent.id, secondIntent.id])
        XCTAssertEqual(
            try database.agentTask(intentID: secondIntent.id)?.status,
            .completed
        )
        XCTAssertEqual(
            try database.providerRequest(intentID: secondIntent.id)?.phase,
            .continuationCommitted
        )
    }

    func testStreamingPauseRemainsUnknownAndCannotBeResent() async throws {
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
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
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
        XCTAssertEqual(request.phase, .outcomeUnknown)
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
        XCTAssertFalse(
            viewModel.modelConnectionSetup.isPresented(
                for: intent.conversationID
            )
        )
        XCTAssertTrue(viewModel.isComposerAvailable)
        XCTAssertFalse(viewModel.canSubmitModelDependentMessage)
        XCTAssertEqual(
            try database.agentTask(intentID: intent.id)?.status,
            .reconciling
        )
        XCTAssertFalse(viewModel.canResumeProviderTask)
        XCTAssertTrue(viewModel.canStopAndKeepProviderTask)

        viewModel.handleScenePhase(.inactive)
        viewModel.handleScenePhase(.active)

        XCTAssertEqual(viewModel.latestAgentRun?.status, .reconciling)
        XCTAssertEqual(
            viewModel.displayedBusinessStatus,
            "正在确认刚才的请求是否已经停止"
        )
        XCTAssertFalse(
            viewModel.modelConnectionSetup.isPresented(
                for: intent.conversationID
            )
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
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
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
        XCTAssertTrue(viewModel.canStopAndKeepProviderTask)

        viewModel.stopAndKeepProviderTask()

        let settledTask = try XCTUnwrap(
            database.agentTask(intentID: intent.id)
        )
        XCTAssertEqual(settledTask.status, .completed)
        XCTAssertEqual(settledTask.outcome, .kept)
        XCTAssertEqual(
            try database.providerRequest(intentID: intent.id)?.phase,
            .outcomeUnknown
        )
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
        )
        XCTAssertEqual(
            viewModel.providerTaskProjection?.doingText,
            "这件事已经结束，已收到内容已保留；原模型最终结果仍未知"
        )
        XCTAssertEqual(
            viewModel.providerTaskProjection?.recoveryState,
            .outcomeUnknown
        )
        XCTAssertFalse(viewModel.canRetryProviderRun)
        XCTAssertNil(try database.activeAgentTask())
        XCTAssertTrue(viewModel.canSubmitModelDependentMessage)
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
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
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
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
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
            "连接失效：原请求已保留，等待你重新建立或选择连接"
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
        let network = TestNetworkAvailabilityObserver(state: .unavailable)

        let viewModel = AppViewModel(
            database: database,
            modelCredentialRepository: credentials,
            providerGenerationService: generation,
            providerBudgetEstimator: DeterministicTestProviderBudgetEstimator(),
            networkAvailabilityObserver: network,
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
        let completedTask = try XCTUnwrap(
            database.agentTask(intentID: intent.id)
        )
        XCTAssertEqual(completedTask.status, .completed)
        XCTAssertEqual(completedTask.outcome, .natural)
        XCTAssertNil(completedTask.waitingReason)
        XCTAssertNil(
            try database.latestPendingModelIntent(
                conversationID: conversation.id
            )
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
