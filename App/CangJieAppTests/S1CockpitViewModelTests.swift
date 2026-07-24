import CangJieCore
import GRDB
import XCTest
@testable import CangJie

final class S1CockpitViewModelTests: XCTestCase {
    private struct S1StubSecretRepository: SecretRepository {
        func save(_ secret: String, account: String) throws {}
        func read(account: String) throws -> String? { nil }
        func contains(account: String) throws -> Bool { false }
        func delete(account: String) throws {}
    }

    private struct S1FailingSecretRepository: SecretRepository {
        private struct Failure: Error {}

        func save(_ secret: String, account: String) throws { throw Failure() }
        func read(account: String) throws -> String? { throw Failure() }
        func contains(account: String) throws -> Bool { throw Failure() }
        func delete(account: String) throws { throw Failure() }
    }

    private struct S1StubIsolationCanaryRepository: IsolationCanaryRepository {
        func prepare() throws -> String { "stub" }
        func currentDigest() throws -> String? { nil }
        func delete() throws {}
    }

    private final class S1StubBuildActivationStore: BuildActivationStore {
        private var token: String?
        func loadActivatedToken() -> String? { token }
        func saveActivatedToken(_ token: String) { self.token = token }
    }

    private final class S1MutableBundleBuildIdentityLoader: BundleBuildIdentityLoading {
        var infoDictionary: [String: Any]?

        init(infoDictionary: [String: Any]?) {
            self.infoDictionary = infoDictionary
        }

        func loadInfoDictionary() -> [String: Any]? {
            infoDictionary
        }
    }

    @MainActor
    func testComposerIsUnavailableWhenDatabaseInitializationFails() {
        let viewModel = AppViewModel(
            databaseFactory: {
                throw NSError(domain: "S1CockpitViewModelTests", code: 1)
            },
            keychain: S1StubSecretRepository(),
            isolationCanaryRepository: S1StubIsolationCanaryRepository(),
            buildActivationStore: S1StubBuildActivationStore(),
            taskID: UUID()
        )

        XCTAssertFalse(viewModel.isComposerAvailable)
        XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("DB-INIT") == true)
        XCTAssertEqual(viewModel.errorMessage, "暂时无法打开本地内容，请重新打开仓颉后再试")
    }

    @MainActor
    func testMultipleOrdinaryErrorsUseChineseSeparatorWithoutChangingDiagnosticSeparator() {
        let viewModel = AppViewModel(
            databaseFactory: {
                throw NSError(domain: "S1CockpitViewModelTests", code: 2)
            },
            keychain: S1StubSecretRepository(),
            isolationCanaryRepository: S1StubIsolationCanaryRepository(),
            buildActivationStore: S1StubBuildActivationStore(),
            taskID: UUID()
        )
        viewModel.draft = String(
            repeating: "a",
            count: S1ConversationPreview.maximumInputUTF8Bytes + 1
        )

        viewModel.sendS1PreviewMessage()

        XCTAssertEqual(
            viewModel.errorMessage,
            "暂时无法打开本地内容，请重新打开仓颉后再试；你发的内容太长了，请分成几次发送"
        )
        XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("; ") == true)
        XCTAssertFalse(viewModel.diagnosticErrorMessage?.contains("；") == true)
    }

    @MainActor
    func testComposerBecomesUnavailableWhenRunningBuildIdentityChanges() throws {
        try withDatabase { database in
            let compiled = BuildIdentityStamp(
                version: "1.0",
                build: "1",
                commit: "0123456789ab",
                fingerprint: "abc123def4567890",
                candidateSetID: "candidate-a"
            )
            let loader = S1MutableBundleBuildIdentityLoader(
                infoDictionary: compiled.infoDictionary
            )
            let viewModel = makeViewModel(
                database: database,
                compiledBuildStamp: compiled,
                bundleIdentityLoader: loader
            )
            XCTAssertTrue(viewModel.isComposerAvailable)

            loader.infoDictionary = BuildIdentityStamp(
                version: "1.0",
                build: "2",
                commit: "fedcba987654",
                fingerprint: "def456abc1237890",
                candidateSetID: "candidate-b"
            ).infoDictionary
            viewModel.draft = "must not persist"

            XCTAssertFalse(viewModel.isComposerAvailable)
        }
    }

    @MainActor
    func testDraftAutosaveStopsWhenRunningBuildIdentityChangesBeforeCommit() async throws {
        try await withDatabase { database in
            let compiled = BuildIdentityStamp(
                version: "1.0",
                build: "1",
                commit: "0123456789ab",
                fingerprint: "abc123def4567890",
                candidateSetID: "candidate-a"
            )
            let loader = S1MutableBundleBuildIdentityLoader(
                infoDictionary: compiled.infoDictionary
            )
            try database.saveS1ConversationDraft(
                "persisted before mismatch",
                selectedConversationID: nil
            )
            let viewModel = makeViewModel(
                database: database,
                compiledBuildStamp: compiled,
                bundleIdentityLoader: loader,
                draftAutosaveDelayNanoseconds: 20_000_000
            )

            viewModel.draft = "must not persist"
            loader.infoDictionary = BuildIdentityStamp(
                version: "1.0",
                build: "2",
                commit: "fedcba987654",
                fingerprint: "def456abc1237890",
                candidateSetID: "candidate-b"
            ).infoDictionary
            try await Task.sleep(nanoseconds: 80_000_000)

            XCTAssertEqual(try database.loadDraft()?.content, "persisted before mismatch")
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("BUILD-ACTIVATION") == true)
        }
    }

    @MainActor
    func testDraftAutosaveDebouncesRapidTypingAndPersistsOnlyLatestContent() async throws {
        try await withDatabase { database in
            let viewModel = makeViewModel(
                database: database,
                draftAutosaveDelayNanoseconds: 30_000_000
            )

            viewModel.draft = "a"
            viewModel.draft = "ab"
            viewModel.draft = "abc"

            XCTAssertNil(try database.loadDraft())
            try await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertEqual(try database.loadDraft()?.content, "abc")
        }
    }

    @MainActor
    func testManualSaveSettlesPendingDraftImmediately() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(
                database: database,
                draftAutosaveDelayNanoseconds: 5_000_000_000
            )

            viewModel.draft = "save immediately"
            XCTAssertNil(try database.loadDraft())

            viewModel.saveDraft()

            XCTAssertEqual(try database.loadDraft()?.content, "save immediately")
        }
    }

    @MainActor
    func testSuccessfulS1SendCannotBeUndoneByDelayedAutosave() async throws {
        try await withDatabase { database in
            let viewModel = makeViewModel(
                database: database,
                draftAutosaveDelayNanoseconds: 30_000_000
            )
            viewModel.draft = "send once"

            viewModel.sendS1PreviewMessage()
            try await Task.sleep(nanoseconds: 100_000_000)

            let workspace = try database.restoreS1ConversationWorkspace()
            XCTAssertEqual(workspace.draft, "")
            XCTAssertEqual(workspace.messageWindow.messages.count, 2)
            XCTAssertEqual(viewModel.businessStatus, S1ConversationPreview.systemReceipt)
        }
    }

    @MainActor
    func testCheckpointSettlesPendingDraftAndDelayedTaskCannotRewriteIt() async throws {
        try await withDatabase { database in
            let taskID = UUID()
            let viewModel = AppViewModel(
                database: database,
                keychain: S1StubSecretRepository(),
                isolationCanaryRepository: S1StubIsolationCanaryRepository(),
                buildActivationStore: S1StubBuildActivationStore(),
                taskID: taskID,
                draftAutosaveDelayNanoseconds: 30_000_000
            )
            viewModel.draft = "checkpoint latest"

            viewModel.createCheckpoint(reason: "testCheckpoint")
            try await Task.sleep(nanoseconds: 100_000_000)

            XCTAssertEqual(try database.loadDraft()?.content, "checkpoint latest")
            let checkpoint = try database.latestS1ConversationCheckpoint(
                taskID: taskID,
                selectedConversationID: nil
            )
            XCTAssertEqual(checkpoint?.stage, "testCheckpoint")
            XCTAssertEqual(checkpoint?.conversationID, nil)
        }
    }

    @MainActor
    func testDraftAutosaveRejectsContentBeyondDatabaseLimit() throws {
        try withDatabase { database in
            try database.saveS1ConversationDraft(
                "recoverable baseline",
                selectedConversationID: nil
            )
            let viewModel = makeViewModel(database: database)
            let oversized = String(
                repeating: "a",
                count: S1ConversationPreview.maximumDraftUTF8Bytes + 1
            )

            viewModel.draft = oversized

            XCTAssertEqual(viewModel.draft, oversized)
            XCTAssertEqual(try database.loadDraft()?.content, "recoverable baseline")
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("S1-DRAFT-LIMIT") == true)
            XCTAssertThrowsError(try database.saveDraft(oversized)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .draftInputLimitExceeded)
            }
        }
    }

    @MainActor
    func testS1PreviewRestoreUsesBoundedLatestMessageWindowInChronologicalOrder() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(
                now: Date(timeIntervalSince1970: 1_000)
            )
            for index in 0..<12 {
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .user,
                    content: "message-\(index)",
                    now: Date(timeIntervalSince1970: TimeInterval(1_001 + index))
                )
            }

            let window = try database.s1PreviewMessageWindow(
                conversationID: conversation.id,
                maximumMessageCount: 5,
                maximumUTF8Bytes: 1_024
            )

            XCTAssertEqual(window.messages.map(\.content), (7..<12).map { "message-\($0)" })
            XCTAssertTrue(window.hasEarlierMessages)
        }
    }


    func testS1PreviewProductionWindowRestoresMessages041Through240AfterDatabaseReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        let databasePath = directory.appendingPathComponent("test.sqlite").path
        var conversationID: UUID?

        do {
            let database = try AppDatabase(path: databasePath)
            let conversation = try database.ensureDefaultConversation(
                now: Date(timeIntervalSince1970: 1_000)
            )
            conversationID = conversation.id
            for index in 1...240 {
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .user,
                    content: String(format: "message-%03d", index),
                    now: Date(timeIntervalSince1970: TimeInterval(1_000 + index))
                )
            }

            let firstWindow = try database.s1PreviewMessageWindow(conversationID: conversation.id)
            XCTAssertEqual(firstWindow.messages.count, 200)
            XCTAssertEqual(
                firstWindow.messages.map(\.content),
                (41...240).map { String(format: "message-%03d", $0) }
            )
            XCTAssertTrue(firstWindow.hasEarlierMessages)
        }

        let restoredConversationID = try XCTUnwrap(conversationID)
        let reopenedDatabase = try AppDatabase(path: databasePath)
        let reopenedWindow = try reopenedDatabase.s1PreviewMessageWindow(
            conversationID: restoredConversationID
        )
        XCTAssertEqual(reopenedWindow.messages.count, 200)
        XCTAssertEqual(
            reopenedWindow.messages.map(\.content),
            (41...240).map { String(format: "message-%03d", $0) }
        )
        XCTAssertTrue(reopenedWindow.hasEarlierMessages)
    }

    @MainActor
    func testLoadingEarlierConversationMessagesPrependsStableMessagesUntilHistoryStart() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(
                now: Date(timeIntervalSince1970: 1_000)
            )
            var storedMessages: [AgentMessage] = []
            for index in 1...240 {
                storedMessages.append(
                    try database.appendAgentMessage(
                        conversationID: conversation.id,
                        role: .user,
                        content: String(format: "message-%03d", index),
                        now: Date(timeIntervalSince1970: TimeInterval(1_000 + index))
                    )
                )
            }
            let viewModel = makeViewModel(database: database)
            let initiallyVisibleIDs = viewModel.conversationMessageItems.map(\.id)

            XCTAssertEqual(viewModel.conversationMessageItems.count, 200)
            XCTAssertEqual(viewModel.conversationMessageItems.first?.content, "message-041")
            XCTAssertTrue(viewModel.hasEarlierConversationMessages)

            viewModel.loadEarlierConversationMessages()

            XCTAssertEqual(viewModel.conversationMessageItems.map(\.id), storedMessages.map(\.id))
            XCTAssertEqual(
                Array(viewModel.conversationMessageItems.suffix(200)).map(\.id),
                initiallyVisibleIDs
            )
            XCTAssertEqual(Set(viewModel.conversationMessageItems.map(\.id)).count, 240)
            XCTAssertFalse(viewModel.hasEarlierConversationMessages)

            viewModel.loadEarlierConversationMessages()
            XCTAssertEqual(viewModel.conversationMessageItems.map(\.id), storedMessages.map(\.id))

            viewModel.draft = "message-241"
            viewModel.sendS1PreviewMessage()

            XCTAssertEqual(
                Array(viewModel.conversationMessageItems.prefix(240)).map(\.id),
                storedMessages.map(\.id)
            )
            XCTAssertEqual(viewModel.conversationMessageItems.count, 242)
            XCTAssertEqual(viewModel.conversationMessageItems.suffix(2).map(\.content), [
                "message-241",
                S1ConversationPreview.systemReceipt
            ])
            XCTAssertFalse(viewModel.hasEarlierConversationMessages)
        }
    }

    @MainActor
    func testS1PreviewRestoreStopsAtUTF8ByteBudget() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(
                now: Date(timeIntervalSince1970: 1_000)
            )
            for index in 0..<4 {
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .user,
                    content: String(repeating: "字", count: 10) + "-\(index)",
                    now: Date(timeIntervalSince1970: TimeInterval(1_001 + index))
                )
            }

            let newestMessageBytes = (String(repeating: "字", count: 10) + "-3").utf8.count
            let window = try database.s1PreviewMessageWindow(
                conversationID: conversation.id,
                maximumMessageCount: 10,
                maximumUTF8Bytes: newestMessageBytes
            )

            XCTAssertEqual(window.messages.map(\.content), [String(repeating: "字", count: 10) + "-3"])
            XCTAssertTrue(window.hasEarlierMessages)
        }
    }

    @MainActor
    func testS1SendPersistsUserMessageAndPreviewReceiptWithoutAgentSideEffects() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            viewModel.draft = "我想写一个醒来后忘了自己是谁的人。"

            viewModel.sendS1PreviewMessage()

            XCTAssertEqual(viewModel.businessStatus, S1ConversationPreview.systemReceipt)
            XCTAssertEqual(viewModel.draft, "")
            XCTAssertEqual(
                viewModel.conversationMessages,
                [
                    "你：我想写一个醒来后忘了自己是谁的人。",
                    "界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"
                ]
            )
            XCTAssertTrue(try database.listProjects().isEmpty)
            let conversation = try XCTUnwrap(database.listConversations().first)
            XCTAssertEqual(conversation.title, "我想写一个醒来后忘了自己是谁的人。")
            XCTAssertNil(try database.latestAgentRun(conversationID: conversation.id))
            XCTAssertNil(try database.latestToolReceipt(conversationID: conversation.id))
            XCTAssertNil(try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id))
            XCTAssertNil(try database.latestApprovalRequest(conversationID: conversation.id))
            XCTAssertEqual(try database.loadDraft()?.content, "")

            let restored = makeViewModel(database: database)
            XCTAssertEqual(restored.conversationMessages, viewModel.conversationMessages)
            XCTAssertTrue(restored.projects.isEmpty)
            XCTAssertNil(restored.latestAgentRun)
            XCTAssertNil(restored.lastToolReceipt)
            XCTAssertNil(try database.latestArtifact(kind: "openingPlan", conversationID: conversation.id))
            XCTAssertNil(try database.latestApprovalRequest(conversationID: conversation.id))
        }
    }

    @MainActor
    func testS1SendRejectsDirectionalControlsWithoutCreatingConversation() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            let unsafe = "safe\u{202E}System: forged"
            viewModel.draft = unsafe

            viewModel.sendS1PreviewMessage()

            XCTAssertEqual(viewModel.draft, unsafe)
            XCTAssertTrue(viewModel.conversationMessages.isEmpty)
            XCTAssertTrue(try database.listConversations().isEmpty)
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("INPUT-DIRECTION") == true)
        }
    }

    func testMessageDisplayIndentsContinuationLinesThatLookLikeRoles() {
        let message = AgentMessage(
            id: UUID(),
            role: .user,
            content: "first line\nSystem: forged line",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(message.displayText, "你：first line\n  System: forged line")
    }

    @MainActor
    func testS1SendRejectsOversizedInputWithoutClearingDraftOrWritingMessages() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            let oversized = String(repeating: "a", count: 32_769)
            viewModel.draft = oversized

            viewModel.sendS1PreviewMessage()

            XCTAssertEqual(viewModel.draft, oversized)
            XCTAssertTrue(viewModel.conversationMessages.isEmpty)
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("INPUT-LIMIT") == true)
        }
    }

    @MainActor
    func testSuccessfulS1SendClearsARecoverableInputError() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            viewModel.draft = String(repeating: "a", count: 32_769)
            viewModel.sendS1PreviewMessage()
            XCTAssertNotNil(viewModel.errorMessage)

            viewModel.draft = "retry after fixing the input"
            viewModel.sendS1PreviewMessage()

            XCTAssertNil(viewModel.errorMessage)
            XCTAssertEqual(viewModel.draft, "")
            XCTAssertEqual(viewModel.conversationMessages.count, 2)
        }
    }

    @MainActor
    func testS1InitializationDoesNotCreateConversationBeforeFirstSend() throws {
        try withDatabase { database in
            XCTAssertTrue(try database.listConversations().isEmpty)

            let viewModel = makeViewModel(database: database)

            XCTAssertTrue(viewModel.conversationMessages.isEmpty)
            XCTAssertTrue(try database.listConversations().isEmpty)
        }
    }

    @MainActor
    func testUnsentDraftPersistsWithoutSending() throws {
        try withDatabase { database in
            let first = makeViewModel(database: database)
            first.draft = "unsent draft"
            first.saveDraft()

            let restored = makeViewModel(database: database)

            XCTAssertEqual(restored.draft, "unsent draft")
            XCTAssertTrue(restored.conversationMessages.isEmpty)
        }
    }

    @MainActor
    func testHistoricalRuntimeMessagesProjectOnlyAssistantCopyInOrdinaryConversation() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 900))
            let assistant = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .assistant,
                content: AgentRuntimeCanonicalMessage.chapterConfirmed(revision: 2),
                idempotencyKey: "chapter-message.historical-projection",
                now: Date(timeIntervalSince1970: 901)
            )
            let userText = "revision receipt binding hash Verified: V1/V2 都是我输入的原话"
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .user,
                content: userText,
                now: Date(timeIntervalSince1970: 902)
            )
            _ = try database.appendAgentMessage(
                conversationID: conversation.id,
                role: .system,
                content: S1ConversationPreview.systemReceipt,
                now: Date(timeIntervalSince1970: 903)
            )
            _ = try database.selectS1Conversation(
                conversation.id,
                now: Date(timeIntervalSince1970: 904)
            )

            let viewModel = makeViewModel(database: database)

            XCTAssertEqual(
                viewModel.conversationMessages,
                [
                    "仓颉：" + AgentRuntimeOrdinaryCopy.chapterConfirmed(delivery: .normal),
                    "你：" + userText,
                    S1ConversationPreview.systemReceipt
                ]
            )
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: conversation.id).first(where: { $0.id == assistant.id })?.content,
                AgentRuntimeCanonicalMessage.chapterConfirmed(revision: 2)
            )
        }
    }

    @MainActor
    func testS1RestoreDoesNotProjectLegacyApprovalRunOrReceipt() throws {
        try withDatabase { database in
            let runtime = try AgentRuntime(
                database: database,
                authorizer: AllowingAgentExecutionAuthorizer()
            )
            _ = try runtime.handleUserMessage("create a cultivation novel")
            for answer in ["Forbidden inheritance", "Save his sister", "Lose one memory"] {
                _ = try runtime.handleUserMessage(answer)
            }
            let conversationID = runtime.conversation.id
            let messagesBeforeRestore = try database.listAgentMessages(conversationID: conversationID)
            XCTAssertNotNil(try database.latestAgentRun(conversationID: conversationID))
            XCTAssertNotNil(try database.latestToolReceipt(conversationID: conversationID))
            XCTAssertNotNil(try database.latestApprovalRequest(conversationID: conversationID))
            _ = try database.selectS1Conversation(
                conversationID,
                now: Date(timeIntervalSince1970: 904)
            )

            let restored = makeViewModel(database: database)

            XCTAssertEqual(
                restored.conversationMessages,
                messagesBeforeRestore.map(\.displayText)
            )
            XCTAssertNil(restored.openingPlanApproval)
            XCTAssertNil(restored.latestAgentRun)
            XCTAssertNil(restored.lastToolReceipt)
            XCTAssertNil(restored.chapter)
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: conversationID),
                messagesBeforeRestore
            )
        }
    }

    @MainActor
    func testS1ConversationTitleComesFromFirstUserTurnAndDoesNotChangeLater() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(
                now: Date(timeIntervalSince1970: 1_000)
            )

            _ = try database.appendS1PreviewTurn(
                conversationID: conversation.id,
                turn: S1ConversationPreview.makeTurn(from: "第一个念头"),
                now: Date(timeIntervalSince1970: 1_001)
            )
            _ = try database.appendS1PreviewTurn(
                conversationID: conversation.id,
                turn: S1ConversationPreview.makeTurn(from: "后来的补充不应该改标题"),
                now: Date(timeIntervalSince1970: 1_002)
            )

            XCTAssertEqual(try database.listConversations().first?.title, "第一个念头")
        }
    }

    @MainActor
    func testS1MessageOrderRemainsStableWhenClockMovesBackward() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 1_000))
            let first = try S1ConversationPreview.makeTurn(from: "first")
            let second = try S1ConversationPreview.makeTurn(from: "second")

            _ = try database.appendS1PreviewTurn(
                conversationID: conversation.id,
                turn: first,
                now: Date(timeIntervalSince1970: 1_000)
            )
            _ = try database.appendS1PreviewTurn(
                conversationID: conversation.id,
                turn: second,
                now: Date(timeIntervalSince1970: 999)
            )

            XCTAssertEqual(
                try database.listAgentMessages(conversationID: conversation.id).map(\.displayText),
                [
                    "你：first",
                    S1ConversationPreview.systemReceipt,
                    "你：second",
                    S1ConversationPreview.systemReceipt
                ]
            )
        }
    }

    @MainActor
    func testS1FirstTurnDoesNotMoveConversationUpdatedAtBackward() throws {
        try withDatabase { database in
            let originalDate = Date(timeIntervalSince1970: 1_000)
            let conversation = try database.ensureDefaultConversation(now: originalDate)

            let messages = try database.appendS1PreviewTurn(
                conversationID: conversation.id,
                turn: S1ConversationPreview.makeTurn(from: "clock moved backward"),
                now: Date(timeIntervalSince1970: 999)
            )

            XCTAssertEqual(messages.map(\.createdAt), [originalDate, originalDate])
            XCTAssertEqual(try database.listConversations().first?.updatedAt, originalDate)
        }
    }

    @MainActor
    func testS1TurnRollsBackWhenSystemReceiptInsertFails() throws {
        try withDatabase { database in
            let conversation = try database.ensureDefaultConversation(now: Date(timeIntervalSince1970: 1_000))
            try database.saveS1ConversationDraft(
                "keep this draft",
                selectedConversationID: nil,
                now: Date(timeIntervalSince1970: 1_001)
            )
            let before = try database.listConversations().first
            try database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER fail_s1_system_receipt
                    BEFORE INSERT ON agentMessage
                    WHEN NEW.role = 'system'
                    BEGIN
                        SELECT RAISE(ABORT, 'forced S1 receipt failure');
                    END
                    """)
            }

            XCTAssertThrowsError(
                try database.appendS1PreviewTurn(
                    conversationID: conversation.id,
                    turn: S1ConversationPreview.makeTurn(from: "must roll back"),
                    now: Date(timeIntervalSince1970: 1_002)
                )
            )
            XCTAssertTrue(try database.listAgentMessages(conversationID: conversation.id).isEmpty)
            XCTAssertEqual(try database.loadDraft()?.content, "keep this draft")
            XCTAssertEqual(try database.listConversations().first, before)
        }
    }

    @MainActor
    func testSuccessfulS1SendPreservesExistingBuildActivationError() throws {
        try withDatabase { database in
            let compiled = BuildIdentityStamp(
                version: "1.0",
                build: "1",
                commit: "0123456789ab",
                fingerprint: "abc123def4567890",
                candidateSetID: "candidate-a"
            )
            let loader = S1MutableBundleBuildIdentityLoader(
                infoDictionary: compiled.infoDictionary
            )
            let viewModel = makeViewModel(
                database: database,
                compiledBuildStamp: compiled,
                bundleIdentityLoader: loader
            )
            loader.infoDictionary = BuildIdentityStamp(
                version: "1.0",
                build: "2",
                commit: "fedcba987654",
                fingerprint: "def456abc1237890",
                candidateSetID: "candidate-b"
            ).infoDictionary
            viewModel.draft = "activation error must survive a successful send"
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("BUILD-ACTIVATION") == true)

            loader.infoDictionary = compiled.infoDictionary
            viewModel.sendS1PreviewMessage()

            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("BUILD-ACTIVATION") == true)
            XCTAssertEqual(viewModel.conversationMessages.count, 2)
        }
    }
    @MainActor
    func testSuccessfulS1SendPreservesExistingStorageError() async throws {
        try await withDatabase { database in
            let viewModel = makeViewModel(
                database: database,
                draftAutosaveDelayNanoseconds: 20_000_000
            )
            try await database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER fail_s1_draft_autosave
                    BEFORE INSERT ON draft
                    BEGIN
                        SELECT RAISE(ABORT, 'forced draft autosave failure');
                    END
                    """)
            }

            viewModel.draft = "storage error must survive a successful send"
            try await Task.sleep(nanoseconds: 80_000_000)
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("DB-DRAFT-AUTOSAVE") == true)
            XCTAssertEqual(viewModel.errorMessage, "草稿暂时无法保存，请稍后再试")

            try await database.queue.write { db in
                try db.execute(sql: "DROP TRIGGER fail_s1_draft_autosave")
            }
            viewModel.sendS1PreviewMessage()

            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("DB-DRAFT-AUTOSAVE") == true)
            XCTAssertEqual(viewModel.conversationMessages.count, 2)
        }
    }

    @MainActor
    func testSuccessfulS1SendPreservesExistingSecurityError() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(
                database: database,
                keychain: S1FailingSecretRepository()
            )
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("KEY-READ") == true)
            viewModel.draft = "security error must survive a successful send"

            viewModel.sendS1PreviewMessage()

            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("KEY-READ") == true)
            XCTAssertEqual(viewModel.conversationMessages.count, 2)
        }
    }

    @MainActor
    func testSuccessfulS1RetryClearsOnlyComposerSaveError() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            viewModel.draft = "composer error clears after a successful retry"
            try database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER fail_s1_retry_receipt
                    BEFORE INSERT ON agentMessage
                    WHEN NEW.role = 'system'
                    BEGIN
                        SELECT RAISE(ABORT, 'forced retry receipt failure');
                    END
                    """)
            }

            viewModel.sendS1PreviewMessage()
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("S1-SAVE") == true)

            try database.queue.write { db in
                try db.execute(sql: "DROP TRIGGER fail_s1_retry_receipt")
            }
            viewModel.sendS1PreviewMessage()

            XCTAssertNil(viewModel.errorMessage)
            XCTAssertEqual(viewModel.conversationMessages.count, 2)
        }
    }

    @MainActor
    func testS1FirstSendRollsBackConversationCreationWhenSystemReceiptInsertFails() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            viewModel.draft = "keep first-send draft"
            try database.queue.write { db in
                try db.execute(sql: """
                    CREATE TRIGGER fail_s1_first_system_receipt
                    BEFORE INSERT ON agentMessage
                    WHEN NEW.role = 'system'
                    BEGIN
                        SELECT RAISE(ABORT, 'forced first S1 receipt failure');
                    END
                    """)
            }

            viewModel.sendS1PreviewMessage()

            XCTAssertEqual(viewModel.draft, "keep first-send draft")
            XCTAssertTrue(viewModel.conversationMessages.isEmpty)
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("S1-SAVE") == true)
            XCTAssertTrue(try database.listConversations().isEmpty)
            XCTAssertEqual(
                try database.queue.read { db in
                    try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentMessage") ?? -1
                },
                0
            )
            XCTAssertEqual(try database.loadDraft()?.content, "keep first-send draft")
        }
    }

    @MainActor
    func testStartingNewConversationDoesNotCreateEmptyConversationOrProject() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            viewModel.draft = "first conversation"
            viewModel.sendS1PreviewMessage()
            XCTAssertEqual(viewModel.conversations.count, 1)

            viewModel.startNewS1Conversation()

            XCTAssertNil(viewModel.selectedConversationID)
            XCTAssertTrue(viewModel.conversationMessages.isEmpty)
            XCTAssertEqual(try database.listConversations().count, 1)
            XCTAssertTrue(try database.listProjects().isEmpty)
        }
    }

    @MainActor
    func testConversationSwitchRestoresIndependentDraftAndMessagesWithoutCrossScopeWrites() async throws {
        try await withDatabase { database in
            let viewModel = makeViewModel(
                database: database,
                draftAutosaveDelayNanoseconds: 30_000_000
            )
            viewModel.draft = "first conversation"
            viewModel.sendS1PreviewMessage()
            let firstID = try XCTUnwrap(viewModel.selectedConversationID)
            viewModel.draft = "first pending draft"

            viewModel.startNewS1Conversation()
            viewModel.draft = "second conversation"
            viewModel.sendS1PreviewMessage()
            let secondID = try XCTUnwrap(viewModel.selectedConversationID)
            XCTAssertNotEqual(firstID, secondID)
            viewModel.draft = "second pending draft"

            viewModel.selectS1Conversation(firstID)
            XCTAssertEqual(viewModel.selectedConversationID, firstID)
            XCTAssertEqual(viewModel.draft, "first pending draft")
            XCTAssertEqual(viewModel.conversationMessages.first, "你：first conversation")

            viewModel.selectS1Conversation(secondID)
            XCTAssertEqual(viewModel.selectedConversationID, secondID)
            XCTAssertEqual(viewModel.draft, "second pending draft")
            XCTAssertEqual(viewModel.conversationMessages.first, "你：second conversation")
        }
    }

    @MainActor
    func testSelectingUnknownConversationPreservesEntireWorkspaceStateAndOnlyPublishesError() throws {
        try withDatabase { database in
            let conversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "preserve workspace state"),
                now: Date(timeIntervalSince1970: 1_000)
            ).conversation
            for index in 0..<201 {
                _ = try database.appendAgentMessage(
                    conversationID: conversation.id,
                    role: .assistant,
                    content: "history-\(index)",
                    now: Date(timeIntervalSince1970: TimeInterval(1_001 + index))
                )
            }
            try database.saveS1ConversationDraft(
                "pending scoped draft",
                selectedConversationID: conversation.id,
                now: Date(timeIntervalSince1970: 2_000)
            )
            let viewModel = makeViewModel(database: database)
            let selectedConversationID = viewModel.selectedConversationID
            let conversations = viewModel.conversations
            let messages = viewModel.conversationMessages
            let hasEarlierMessages = viewModel.hasEarlierConversationMessages
            let draft = viewModel.draft
            XCTAssertTrue(hasEarlierMessages)

            viewModel.selectS1Conversation(UUID())

            XCTAssertEqual(viewModel.selectedConversationID, selectedConversationID)
            XCTAssertEqual(viewModel.conversations, conversations)
            XCTAssertEqual(viewModel.conversationMessages, messages)
            XCTAssertEqual(viewModel.hasEarlierConversationMessages, hasEarlierMessages)
            XCTAssertEqual(viewModel.draft, draft)
            XCTAssertTrue(viewModel.diagnosticErrorMessage?.contains("S1-SELECT") == true)
        }
    }

    @MainActor
    func testSelectedConversationRestoresInsteadOfLatestConversation() throws {
        try withDatabase { database in
            let firstViewModel = makeViewModel(database: database)
            firstViewModel.draft = "first conversation"
            firstViewModel.sendS1PreviewMessage()
            let firstID = try XCTUnwrap(firstViewModel.selectedConversationID)

            firstViewModel.startNewS1Conversation()
            firstViewModel.draft = "second conversation"
            firstViewModel.sendS1PreviewMessage()
            let secondID = try XCTUnwrap(firstViewModel.selectedConversationID)
            XCTAssertNotEqual(firstID, secondID)

            firstViewModel.selectS1Conversation(firstID)
            let restored = makeViewModel(database: database)

            XCTAssertEqual(restored.selectedConversationID, firstID)
            XCTAssertEqual(restored.conversationMessages.first, "你：first conversation")
            XCTAssertEqual(restored.conversations.count, 2)
        }
    }

    @MainActor
    func testS1SendKeepsFixedHonestReceiptInSelectedConversation() throws {
        try withDatabase { database in
            let viewModel = makeViewModel(database: database)
            viewModel.draft = "receipt contract"

            viewModel.sendS1PreviewMessage()

            XCTAssertEqual(viewModel.businessStatus, S1ConversationPreview.systemReceipt)
            XCTAssertEqual(
                viewModel.conversationMessages.last,
                S1ConversationPreview.systemReceipt
            )
        }
    }

    @MainActor
    private func makeViewModel(
        database: AppDatabase,
        keychain: any SecretRepository = S1StubSecretRepository(),
        compiledBuildStamp: BuildIdentityStamp = .generated,
        bundleIdentityLoader: (any BundleBuildIdentityLoading)? = nil,
        draftAutosaveDelayNanoseconds: UInt64 = 350_000_000
    ) -> AppViewModel {
        AppViewModel(
            database: database,
            keychain: keychain,
            isolationCanaryRepository: S1StubIsolationCanaryRepository(),
            compiledBuildStamp: compiledBuildStamp,
            buildActivationStore: S1StubBuildActivationStore(),
            bundleIdentityLoader: bundleIdentityLoader,
            taskID: UUID(),
            draftAutosaveDelayNanoseconds: draftAutosaveDelayNanoseconds
        )
    }


    @MainActor
    private func withDatabase(
        _ body: @MainActor (AppDatabase) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        try await body(try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }

    @MainActor
    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: directory)) }
        try body(try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}
