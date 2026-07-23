import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

private final class ThrowingVerificationCredentialRepository: ModelCredentialRepository {
    private struct Failure: Error {}

    func save(
        _ secret: String,
        versionProof: String,
        setupAuthorizationHash: String?,
        for connection: ModelConnection
    ) throws {}

    func resolve(for connection: ModelConnection) throws -> KeychainBoundModelCredential? {
        throw Failure()
    }

    func delete(for connection: ModelConnection) throws {}
}

@MainActor
final class ModelConnectionSetupFlowTests: XCTestCase, ModelConnectionSetupServiceTestSupport {
    func testPendingIntentTurnAtomicallyCreatesConversationMessagesAndIntent() throws {
        try withTemporaryDatabase { database in
            let intentID = UUID()
            let result = try database.appendPendingModelIntentTurn(
                selectedConversationID: nil,
                rawRequest: "帮我把这个雨夜山门的念头继续想下去",
                intentID: intentID,
                now: Date(timeIntervalSince1970: 1_000)
            )

            XCTAssertEqual(result.pendingIntent.id, intentID)
            XCTAssertEqual(result.pendingIntent.conversationID, result.conversation.id)
            XCTAssertEqual(result.pendingIntent.userRequest, "帮我把这个雨夜山门的念头继续想下去")
            XCTAssertEqual(result.workspace.selectedConversation?.id, result.conversation.id)
            XCTAssertEqual(result.workspace.draft, "")
            XCTAssertEqual(
                result.workspace.messageWindow.messages.map(\.displayText),
                [
                    "你：帮我把这个雨夜山门的念头继续想下去",
                    ModelConnectionSetupConversationCopy.intentSaved
                ]
            )
            XCTAssertEqual(try database.pendingModelIntent(id: intentID), result.pendingIntent)
        }
    }

    func testPendingIntentInsertFailureRollsBackFirstConversationAndPreservesDraft() throws {
        try withTemporaryDatabase { database in
            try database.saveS1ConversationDraft(
                "不能丢的原始请求",
                selectedConversationID: nil,
                now: Date(timeIntervalSince1970: 1_000)
            )
            try database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER fail_pending_model_intent_insert
                    BEFORE INSERT ON pendingModelIntent
                    BEGIN
                        SELECT RAISE(ABORT, 'injected pending intent failure');
                    END
                    """)
            }

            XCTAssertThrowsError(
                try database.appendPendingModelIntentTurn(
                    selectedConversationID: nil,
                    rawRequest: "不能丢的原始请求",
                    intentID: UUID(),
                    now: Date(timeIntervalSince1970: 1_001)
                )
            )

            let workspace = try database.restoreS1ConversationWorkspace()
            XCTAssertNil(workspace.selectedConversation)
            XCTAssertEqual(workspace.draft, "不能丢的原始请求")
            XCTAssertTrue(workspace.conversations.isEmpty)
            XCTAssertTrue(workspace.messageWindow.messages.isEmpty)
            let pendingCount = try database.queue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pendingModelIntent") ?? 0
            }
            XCTAssertEqual(pendingCount, 0)
        }
    }

    func testPendingIntentBindsTheExistingConversationFocusedProject() throws {
        try withTemporaryDatabase { database in
            let initial = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "先保存这个故事"),
                now: Date(timeIntervalSince1970: 1_500)
            )
            let project = try database.createProject(
                title: "雾城守夜人",
                premise: "雨夜山门",
                now: Date(timeIntervalSince1970: 1_501)
            )
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: project.id,
                    interviewStep: 0,
                    currentQuestion: "",
                    interviewAnswers: [],
                    updatedAt: Date(timeIntervalSince1970: 1_502)
                ),
                conversationID: initial.conversation.id
            )

            let result = try database.appendPendingModelIntentTurn(
                selectedConversationID: initial.conversation.id,
                rawRequest: "继续这本书",
                intentID: UUID(),
                now: Date(timeIntervalSince1970: 1_503)
            )

            XCTAssertEqual(result.pendingIntent.conversationID, initial.conversation.id)
            XCTAssertEqual(result.pendingIntent.projectID, project.id)
            XCTAssertNil(result.pendingIntent.branchID)
        }
    }

    func testPendingIntentReplayReturnsTheOriginalTurnWithoutDuplicatingMessages() throws {
        try withTemporaryDatabase { database in
            let intentID = UUID()
            let first = try database.appendPendingModelIntentTurn(
                selectedConversationID: nil,
                rawRequest: "同一个请求只保存一次",
                intentID: intentID,
                now: Date(timeIntervalSince1970: 1_700)
            )
            let replay = try database.appendPendingModelIntentTurn(
                selectedConversationID: nil,
                rawRequest: "同一个请求只保存一次",
                intentID: intentID,
                now: Date(timeIntervalSince1970: 1_701)
            )

            XCTAssertEqual(replay.pendingIntent, first.pendingIntent)
            XCTAssertEqual(replay.conversation.id, first.conversation.id)
            XCTAssertEqual(
                replay.workspace.messageWindow.messages.map(\.displayText),
                first.workspace.messageWindow.messages.map(\.displayText)
            )
            let messageCount = try database.queue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentMessage") ?? 0
            }
            XCTAssertEqual(messageCount, 2)
        }
    }

    func testPendingIntentReplayRejectsDifferentAdmissionCondition() throws {
        try withTemporaryDatabase { database in
            let intentID = UUID()
            _ = try database.appendPendingModelIntentTurn(
                selectedConversationID: nil,
                rawRequest: "同一请求的准入条件必须保持一致",
                intentID: intentID,
                admissionCondition: .ready,
                now: Date(timeIntervalSince1970: 1_750)
            )

            XCTAssertThrowsError(
                try database.appendPendingModelIntentTurn(
                    selectedConversationID: nil,
                    rawRequest: "同一请求的准入条件必须保持一致",
                    intentID: intentID,
                    admissionCondition: .networkConfirmationRequired,
                    now: Date(timeIntervalSince1970: 1_751)
                )
            ) { error in
                XCTAssertEqual(
                    error as? AppDatabaseError,
                    .idempotencyConflict
                )
            }
        }
    }

    func testSecondPendingIntentForTheSameConversationFailsWithoutAppendingMessages() throws {
        try withTemporaryDatabase { database in
            let first = try database.appendPendingModelIntentTurn(
                selectedConversationID: nil,
                rawRequest: "先保存这一条模型请求",
                intentID: UUID(),
                now: Date(timeIntervalSince1970: 1_800)
            )

            XCTAssertThrowsError(
                try database.appendPendingModelIntentTurn(
                    selectedConversationID: first.conversation.id,
                    rawRequest: "不能静默搁置的第二条请求",
                    intentID: UUID(),
                    now: Date(timeIntervalSince1970: 1_801)
                )
            ) { error in
                XCTAssertEqual(
                    error as? AppDatabaseError,
                    .pendingModelIntentAlreadyExists
                )
            }

            XCTAssertEqual(
                try database.listAgentMessages(conversationID: first.conversation.id)
                    .map(\.displayText),
                first.workspace.messageWindow.messages.map(\.displayText)
            )
            XCTAssertEqual(
                try database.latestPendingModelIntent(conversationID: first.conversation.id),
                first.pendingIntent
            )
        }
    }

    func testOfficialDiscoveryRequiresExplicitModelThenPersistsNamedCurrentConnectionAndResumesIntent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase(
            path: directory.appendingPathComponent("test.sqlite").path
        )
        let append = try database.appendPendingModelIntentTurn(
            selectedConversationID: nil,
            rawRequest: "继续刚才的小说想法",
            intentID: UUID(),
            now: Date(timeIntervalSince1970: 2_000)
        )
        let transport = RecordingTransport(
            responses: [
                QueuedResponse(200, #"{"data":[{"id":"gpt-test"},{"id":"gpt-other"}]}"#)
            ]
        )
        let credentials = RecordingCredentialRepository()
        let controller = ModelConnectionSetupController(
            database: database,
            credentials: credentials,
            discoveryClient: ModelDiscoveryNetworkClient(transport: transport)
        )

        controller.begin(pendingIntent: append.pendingIntent)
        controller.selectProvider(.openAI)
        XCTAssertEqual(controller.baseURLText, "https://api.openai.com/v1")
        controller.secretInput = "sk-test-only-not-a-real-key"

        try await controller.discoverModels()

        XCTAssertEqual(controller.availableModelIDs, ["gpt-test", "gpt-other"])
        XCTAssertNil(controller.selectedModelID)
        controller.selectModel("gpt-test")
        controller.connectionNameInput = "我的 GPT"
        try controller.saveCurrentConnection()

        let stored = try XCTUnwrap(database.currentModelConnection())
        XCTAssertEqual(stored.connection.name, "我的 GPT")
        XCTAssertEqual(stored.connection.selectedModel, "gpt-test")
        XCTAssertEqual(stored.connection.baseURL, URL(string: "https://api.openai.com/v1")!)
        XCTAssertNotNil(try credentials.verifiedConnection(for: stored.connection))
        guard case let .prepareProviderRequest(intent, verifiedConnection)? = controller.resumeDecision else {
            return XCTFail("Expected the exact pending intent to be ready for Provider preparation")
        }
        XCTAssertEqual(intent, append.pendingIntent)
        XCTAssertEqual(verifiedConnection.connection, stored.connection)
        XCTAssertEqual(controller.step, .idle)
        XCTAssertFalse(
            controller.isPresented(for: append.pendingIntent.conversationID)
        )
        XCTAssertEqual(controller.secretInput, "")
        XCTAssertFalse(controller.hasSensitiveDiscoveryState)
        XCTAssertTrue(controller.availableModelIDs.isEmpty)
        XCTAssertNil(controller.selectedModelID)
        XCTAssertThrowsError(try controller.saveCurrentConnection()) { error in
            XCTAssertEqual(
                error as? ModelConnectionSetupFlowError,
                .discoveryRequired
            )
        }

        let restoredController = ModelConnectionSetupController(
            database: database,
            credentials: credentials,
            discoveryClient: ModelDiscoveryNetworkClient(transport: transport)
        )
        restoredController.restorePendingIntent(for: append.pendingIntent.conversationID)
        XCTAssertEqual(restoredController.pendingIntent, append.pendingIntent)
        XCTAssertEqual(restoredController.resumeDecision, controller.resumeDecision)
        XCTAssertEqual(restoredController.step, .idle)
        XCTAssertFalse(
            restoredController.isPresented(
                for: append.pendingIntent.conversationID
            )
        )
    }

    func testShippingCustomSetupFailsClosedBeforeSendingOrPersistingCredential() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase(
            path: directory.appendingPathComponent("test.sqlite").path
        )
        let transport = RecordingTransport(responses: [])
        let credentials = RecordingCredentialRepository()
        let controller = ModelConnectionSetupController(
            database: database,
            credentials: credentials,
            discoveryClient: ModelDiscoveryNetworkClient(transport: transport)
        )
        controller.openManagement()
        controller.selectProvider(.custom)
        controller.customBaseURLInput = "https://models.example/v1"
        controller.secretInput = "custom-test-secret"

        do {
            try await controller.discoverModels()
            XCTFail("Shipping Custom setup must remain unavailable without pinned transport")
        } catch ModelDiscoveryNetworkError.customDestinationPinningUnavailable {
            XCTAssertEqual(
                controller.errorMessage,
                "当前版本还不能安全连接自定义服务，请先使用官方服务"
            )
        }

        let requests = await transport.requests()
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(credentials.events.isEmpty)
        XCTAssertTrue(try database.listModelConnections().isEmpty)
    }

    func testExplicitManagementNeverResumesAnotherConversationsPendingIntent() throws {
        try withTemporaryDatabase { database in
            let pending = try database.appendPendingModelIntentTurn(
                selectedConversationID: nil,
                rawRequest: "A 会话等待连接的请求",
                intentID: UUID(),
                now: Date(timeIntervalSince1970: 2_300)
            )
            let credentials = RecordingCredentialRepository()
            let candidate = try ModelConnectionTestFixture.makeSetupCandidate(
                selectedModel: "gpt-management",
                secret: "management-test-secret"
            )
            let stored = try ModelConnectionSetupService(
                database: database,
                credentials: credentials
            ).persist(
                candidate,
                expectedCredentialBinding: candidate.credentialBinding,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_301)
            )
            let controller = ModelConnectionSetupController(
                database: database,
                credentials: credentials,
                discoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                )
            )

            controller.restorePendingIntent(for: pending.conversation.id)
            XCTAssertEqual(controller.pendingIntent, pending.pendingIntent)

            controller.openManagement()
            XCTAssertNil(controller.pendingIntent)
            XCTAssertNil(controller.resumeDecision)
            try controller.selectCurrentConnection(stored.connection.id)

            XCTAssertNil(controller.pendingIntent)
            XCTAssertNil(controller.resumeDecision)
            XCTAssertFalse(controller.hasSensitiveDiscoveryState)
        }
    }

    func testCredentialVerificationFailureKeepsSavedConnectionMetadataVisible() throws {
        try withTemporaryDatabase { database in
            let first = try ModelConnectionTestFixture.makeConnection(
                name: "连接一",
                selectedModel: "gpt-one"
            )
            let second = try ModelConnectionTestFixture.makeConnection(
                name: "连接二",
                selectedModel: "gpt-two"
            )
            _ = try database.storeModelConnection(first, makeCurrent: true)
            _ = try database.storeModelConnection(second, makeCurrent: false)

            let controller = ModelConnectionSetupController(
                database: database,
                credentials: ThrowingVerificationCredentialRepository(),
                discoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                )
            )

            XCTAssertEqual(
                Set(controller.savedConnections.map(\.connection.id)),
                Set([first.id, second.id])
            )
            XCTAssertEqual(controller.currentMetadata?.connection, first)
            XCTAssertNil(controller.currentConnection)
        }
    }

    func testSelectingSavedConnectionClearsTransientDiscoveryState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let database = try AppDatabase(
                path: directory.appendingPathComponent("test.sqlite").path
            )
            let credentials = RecordingCredentialRepository()
            let savedCandidate = try ModelConnectionTestFixture.makeSetupCandidate(
                name: "可切换连接",
                selectedModel: "gpt-saved",
                secret: "saved-connection-secret"
            )
            let stored = try ModelConnectionSetupService(
                database: database,
                credentials: credentials
            ).persist(
                savedCandidate,
                expectedCredentialBinding: savedCandidate.credentialBinding,
                makeCurrent: true
            )
            let controller = ModelConnectionSetupController(
                database: database,
                credentials: credentials,
                discoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(
                        responses: [QueuedResponse(200, #"{"data":[{"id":"gpt-new"}]}"#)]
                    )
                )
            )
            controller.openManagement()
            controller.selectProvider(.openAI)
            controller.secretInput = "temporary-discovery-secret"
            try await controller.discoverModels()
            XCTAssertTrue(controller.hasSensitiveDiscoveryState)
            XCTAssertEqual(controller.availableModelIDs, ["gpt-new"])

            try controller.selectCurrentConnection(stored.connection.id)

            XCTAssertFalse(controller.hasSensitiveDiscoveryState)
            XCTAssertTrue(controller.availableModelIDs.isEmpty)
            XCTAssertNil(controller.selectedModelID)
            XCTAssertNil(controller.resumeDecision)
            XCTAssertEqual(controller.step, .chooseProvider)
        }
        XCTAssertNoThrow(try FileManager.default.removeItem(at: directory))
    }

    func testLifecycleResumePreservesInProgressSetupForTheSamePendingIntent() throws {
        try withTemporaryDatabase { database in
            let viewModel = AppViewModel(
                database: database,
                modelCredentialRepository: RecordingCredentialRepository(),
                modelDiscoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                ),
                taskID: UUID(),
                draftAutosaveDelayNanoseconds: UInt64.max
            )
            viewModel.draft = "切去密码管理器前保存这条请求"
            viewModel.sendModelDependentMessage()
            let pending = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
            viewModel.modelConnectionSetup.selectProvider(.custom)
            viewModel.modelConnectionSetup.customBaseURLInput = "https://models.example/v1"
            viewModel.modelConnectionSetup.secretInput = "transient-password-manager-key"
            viewModel.modelConnectionSetup.connectionNameInput = "仍在填写"

            viewModel.handleScenePhase(.inactive)
            viewModel.handleScenePhase(.active)

            XCTAssertEqual(viewModel.modelConnectionSetup.pendingIntent, pending)
            XCTAssertEqual(viewModel.modelConnectionSetup.selectedProvider, .custom)
            XCTAssertEqual(
                viewModel.modelConnectionSetup.customBaseURLInput,
                "https://models.example/v1"
            )
            XCTAssertEqual(
                viewModel.modelConnectionSetup.secretInput,
                "transient-password-manager-key"
            )
            XCTAssertEqual(viewModel.modelConnectionSetup.connectionNameInput, "仍在填写")
            XCTAssertEqual(viewModel.modelConnectionSetup.step, .enterCredentials)
        }
    }

    func testLifecycleResumeDoesNotReplaceExplicitManagementWithConversationPendingFlow() throws {
        try withTemporaryDatabase { database in
            let viewModel = AppViewModel(
                database: database,
                modelCredentialRepository: RecordingCredentialRepository(),
                modelDiscoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                ),
                taskID: UUID(),
                draftAutosaveDelayNanoseconds: UInt64.max
            )
            viewModel.draft = "当前会话仍有等待连接的请求"
            viewModel.sendModelDependentMessage()
            let pending = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)

            viewModel.modelConnectionSetup.openManagement()
            viewModel.modelConnectionSetup.selectProvider(.custom)
            viewModel.modelConnectionSetup.customBaseURLInput = "https://management.example/v1"
            viewModel.modelConnectionSetup.secretInput = "management-password-manager-key"
            viewModel.modelConnectionSetup.connectionNameInput = "管理页正在填写"

            viewModel.handleScenePhase(.inactive)
            viewModel.handleScenePhase(.active)

            XCTAssertTrue(viewModel.modelConnectionSetup.isExplicitManagement)
            XCTAssertNil(viewModel.modelConnectionSetup.pendingIntent)
            XCTAssertEqual(viewModel.modelConnectionSetup.selectedProvider, .custom)
            XCTAssertEqual(
                viewModel.modelConnectionSetup.customBaseURLInput,
                "https://management.example/v1"
            )
            XCTAssertEqual(
                viewModel.modelConnectionSetup.secretInput,
                "management-password-manager-key"
            )
            XCTAssertEqual(
                viewModel.modelConnectionSetup.connectionNameInput,
                "管理页正在填写"
            )

            viewModel.closeModelConnectionManagement()

            XCTAssertFalse(viewModel.modelConnectionSetup.isExplicitManagement)
            XCTAssertEqual(viewModel.modelConnectionSetup.pendingIntent, pending)
            XCTAssertTrue(
                viewModel.modelConnectionSetup.isPresented(
                    for: pending.conversationID
                )
            )
        }
    }

    func testConversationSwitchRehydratesEachConversationsPendingSetup() throws {
        try withTemporaryDatabase { database in
            let viewModel = AppViewModel(
                database: database,
                modelCredentialRepository: RecordingCredentialRepository(),
                modelDiscoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                ),
                taskID: UUID(),
                draftAutosaveDelayNanoseconds: UInt64.max
            )
            viewModel.draft = "A 会话的请求"
            viewModel.sendModelDependentMessage()
            let conversationA = try XCTUnwrap(viewModel.selectedConversationID)
            let pendingA = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)

            viewModel.startNewS1Conversation()
            XCTAssertNil(viewModel.selectedConversationID)
            XCTAssertEqual(
                viewModel.displayedBusinessStatus,
                "当前只验证界面、导航和本地保存，尚未接入真正的模型任务"
            )
            viewModel.draft = "B 会话的请求"
            viewModel.sendModelDependentMessage()
            let conversationB = try XCTUnwrap(viewModel.selectedConversationID)
            XCTAssertNotEqual(conversationB, conversationA)
            let pendingB = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
            XCTAssertEqual(pendingB.conversationID, conversationB)

            viewModel.selectS1Conversation(conversationA)

            XCTAssertEqual(viewModel.modelConnectionSetup.pendingIntent, pendingA)
            XCTAssertTrue(viewModel.modelConnectionSetup.isPresented(for: conversationA))
            XCTAssertTrue(viewModel.modelConnectionSetup.blocksComposer(for: conversationA))

            viewModel.selectS1Conversation(conversationB)

            XCTAssertEqual(viewModel.modelConnectionSetup.pendingIntent, pendingB)
            XCTAssertTrue(viewModel.modelConnectionSetup.isPresented(for: conversationB))
            XCTAssertTrue(viewModel.modelConnectionSetup.blocksComposer(for: conversationB))
            XCTAssertFalse(viewModel.modelConnectionSetup.isPresented(for: conversationA))
        }
    }

    func testViewModelRejectedSecondIntentPreservesDraftAndExistingHistory() throws {
        try withTemporaryDatabase { database in
            let viewModel = AppViewModel(
                database: database,
                modelCredentialRepository: RecordingCredentialRepository(),
                modelDiscoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                ),
                taskID: UUID(),
                draftAutosaveDelayNanoseconds: UInt64.max
            )
            viewModel.draft = "第一条仍待模型处理"
            viewModel.sendModelDependentMessage()
            let conversationID = try XCTUnwrap(viewModel.selectedConversationID)
            let firstPending = try XCTUnwrap(viewModel.modelConnectionSetup.pendingIntent)
            let messagesBefore = viewModel.conversationMessages

            viewModel.draft = "第二条必须保留在草稿里"
            viewModel.sendModelDependentMessage()

            XCTAssertEqual(viewModel.draft, "第二条必须保留在草稿里")
            XCTAssertEqual(viewModel.conversationMessages, messagesBefore)
            XCTAssertEqual(
                try database.latestPendingModelIntent(conversationID: conversationID),
                firstPending
            )
            XCTAssertTrue(viewModel.modelConnectionSetup.blocksComposer(for: conversationID))
        }
    }

    func testViewModelPersistenceFailurePreservesExistingConversationDraftAndHistory() throws {
        try withTemporaryDatabase { database in
            let initial = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "已经存在的对话历史"),
                now: Date(timeIntervalSince1970: 2_400)
            )
            try database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER fail_view_model_pending_intent_insert
                    BEFORE INSERT ON pendingModelIntent
                    BEGIN
                        SELECT RAISE(ABORT, 'injected view model pending intent failure');
                    END
                    """)
            }
            let viewModel = AppViewModel(
                database: database,
                modelCredentialRepository: RecordingCredentialRepository(),
                modelDiscoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                ),
                taskID: UUID(),
                draftAutosaveDelayNanoseconds: UInt64.max
            )
            let messagesBefore = viewModel.conversationMessages
            viewModel.draft = "写入失败也不能丢的草稿"

            viewModel.sendModelDependentMessage()

            XCTAssertEqual(viewModel.selectedConversationID, initial.conversation.id)
            XCTAssertEqual(viewModel.draft, "写入失败也不能丢的草稿")
            XCTAssertEqual(viewModel.conversationMessages, messagesBefore)
            XCTAssertNil(
                try database.latestPendingModelIntent(
                    conversationID: initial.conversation.id
                )
            )
        }
    }

    func testViewModelNoConnectionSendPersistsIntentWithoutProviderOrReceiptSideEffects() throws {
        try withTemporaryDatabase { database in
            let credentials = RecordingCredentialRepository()
            let viewModel = AppViewModel(
                database: database,
                modelCredentialRepository: credentials,
                modelDiscoveryClient: ModelDiscoveryNetworkClient(
                    transport: RecordingTransport(responses: [])
                ),
                taskID: UUID(),
                draftAutosaveDelayNanoseconds: UInt64.max
            )
            viewModel.draft = "请帮我继续这个故事"

            viewModel.sendModelDependentMessage()

            let conversationID = try XCTUnwrap(viewModel.selectedConversationID)
            XCTAssertEqual(viewModel.draft, "")
            XCTAssertEqual(viewModel.conversationMessages.first, "你：请帮我继续这个故事")
            XCTAssertEqual(
                viewModel.conversationMessages.last,
                ModelConnectionSetupConversationCopy.intentSaved
            )
            XCTAssertEqual(
                viewModel.modelConnectionSetup.pendingIntent?.conversationID,
                conversationID
            )
            XCTAssertTrue(viewModel.modelConnectionSetup.isPresented)
            XCTAssertTrue(viewModel.modelConnectionSetup.blocksComposer(for: conversationID))
            XCTAssertTrue(viewModel.isComposerAvailable)
            XCTAssertFalse(viewModel.canSubmitModelDependentMessage)
            XCTAssertNil(viewModel.modelConnectionSetup.resumeDecision)
            XCTAssertNil(viewModel.lastToolReceipt)
            XCTAssertNil(viewModel.latestAgentRun)
            let sideEffectCounts = try database.queue.read { db in
                (
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM toolReceipt") ?? 0,
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentArtifact") ?? 0,
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentRun") ?? 0
                )
            }
            XCTAssertEqual(sideEffectCounts.0, 0)
            XCTAssertEqual(sideEffectCounts.1, 0)
            XCTAssertEqual(sideEffectCounts.2, 0)
        }
    }
}
