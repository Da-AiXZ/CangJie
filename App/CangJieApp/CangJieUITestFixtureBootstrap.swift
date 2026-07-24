#if DEBUG
import CangJieCore
import Foundation
import GRDB

@MainActor
enum CangJieUITestFixtureBootstrap {
    private static let fixtureEnvironmentKey = "CANGJIE_UI_TEST_FIXTURE"
    private static let databaseScopeEnvironmentKey = "CANGJIE_UI_TEST_DATABASE_SCOPE"
    private static let persistedNovelShelfFixture = "persisted-novel-shelf"
    private static let persistedReadableTwoBooksFixture = "persisted-readable-two-books"
    private static let persistedScaleAndRestoreFixture = "persisted-scale-and-restore"
    private static let modelConnectionSetupFixture = "model-connection-setup"
    private static let s2TaskLifecycleFixture = "s2-task-lifecycle"
    private static let s2BudgetApprovalFixture = "s2-budget-approval"

    private enum FixtureBootstrapError: Error {
        case seedFailed
    }

    static func makeViewModelIfRequested(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleIdentityLoader: any BundleBuildIdentityLoading = MainBundleBuildIdentityLoader()
    ) -> AppViewModel? {
        guard let fixture = environment[fixtureEnvironmentKey] else {
            return nil
        }

        let identityLoader = bundleIdentityLoader
        guard let rawScope = environment[databaseScopeEnvironmentKey],
              UUID(uuidString: rawScope) != nil else {
            return AppViewModel(
                databaseFactory: { throw FixtureBootstrapError.seedFailed },
                bundleIdentityLoader: identityLoader
            )
        }
        do {
            let database = try AppDatabase.makeDefault(environment: environment)
            let secrets = KeychainSecretRepository()
            let modelCredentials = KeychainModelCredentialRepository(
                secrets: secrets
            )
            var providerGeneration: any ProviderGenerationServing =
                ProviderGenerationNetworkClient()
            var networkAvailability: any NetworkAvailabilityObserving =
                AssumedAvailableNetworkAvailabilityObserver()
            var notificationConsent:
                (any AgentTaskNotificationConsentStoring)?
            switch fixture {
            case persistedNovelShelfFixture:
                try seedPersistedNovelShelf(in: database)
            case persistedReadableTwoBooksFixture:
                try seedPersistedReadableTwoBooks(in: database)
            case persistedScaleAndRestoreFixture:
                try seedPersistedScaleAndRestore(in: database)
            case modelConnectionSetupFixture:
                break
            case s2TaskLifecycleFixture:
                try seedS2TaskLifecycle(
                    in: database,
                    credentials: modelCredentials
                )
                providerGeneration = CangJieUITestProviderGenerationService()
                networkAvailability =
                    CangJieUITestNetworkAvailabilityObserver(
                        state: .unavailable
                    )
                notificationConsent =
                    CangJieUITestNotificationConsentStore()
            case s2BudgetApprovalFixture:
                try seedS2TaskLifecycle(
                    in: database,
                    credentials: modelCredentials
                )
                providerGeneration = CangJieUITestProviderGenerationService()
                networkAvailability =
                    CangJieUITestNetworkAvailabilityObserver(
                        state: .available
                    )
                notificationConsent =
                    CangJieUITestNotificationConsentStore()
            default:
                throw FixtureBootstrapError.seedFailed
            }
            let discoveryClient: any ModelDiscoveryServing
            if fixture == modelConnectionSetupFixture {
                discoveryClient = ModelDiscoveryNetworkClient(
                    transport: ModelConnectionSetupUITestTransport()
                )
            } else {
                discoveryClient = ModelDiscoveryNetworkClient()
            }
            return AppViewModel(
                database: database,
                keychain: secrets,
                modelCredentialRepository: modelCredentials,
                modelDiscoveryClient: discoveryClient,
                providerGenerationService: providerGeneration,
                providerBudgetEstimator:
                    fixture == s2TaskLifecycleFixture
                        ? DeterministicTestProviderBudgetEstimator()
                        : FailClosedProviderBudgetEstimator(),
                networkAvailabilityObserver: networkAvailability,
                notificationConsentStore: notificationConsent,
                bundleIdentityLoader: identityLoader
            )
        } catch {
            return AppViewModel(
                databaseFactory: { throw FixtureBootstrapError.seedFailed },
                bundleIdentityLoader: identityLoader
            )
        }
    }

    private static func seedS2TaskLifecycle(
        in database: AppDatabase,
        credentials: any ModelCredentialRepository
    ) throws {
        try requireFreshFixtureScope(in: database)
        let secret = String(repeating: "x", count: 32)
        let candidate = try CangJieUITestModelConnectionFixture.makeSetupCandidate(
            name: "S2 UI fixture",
            modelID: "gpt-s2-fixture",
            secret: secret
        )
        _ = try ModelConnectionSetupService(
            database: database,
            credentials: credentials
        ).persist(
            candidate,
            expectedCredentialBinding: candidate.credentialBinding,
            makeCurrent: true
        )
    }

    private static func seedPersistedNovelShelf(in database: AppDatabase) throws {
        try requireFreshFixtureScope(in: database)
        let seedDate = Date(timeIntervalSince1970: 1_784_462_400)
        let workspace = try database.restoreS1ConversationWorkspace()

        if workspace.conversations.isEmpty {
            let turn = try S1ConversationPreview.makeTurn(
                from: "雨夜里，有人敲响了封闭十年的山门"
            )
            let appended = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: turn,
                now: seedDate
            )
            try database.saveS1ConversationDraft(
                "下一步想让主角先不开门",
                selectedConversationID: appended.conversation.id,
                now: seedDate.addingTimeInterval(1)
            )
        }

        if try database.listProjects().isEmpty {
            _ = try database.createProject(
                title: "雾城守夜人",
                premise: "封闭十年的山门在雨夜重新响起",
                now: seedDate.addingTimeInterval(2)
            )
        }
    }

    private static func seedPersistedReadableTwoBooks(in database: AppDatabase) throws {
        let seedDate = Date(timeIntervalSince1970: 1_784_462_400)
        let primaryConversationID = try fixtureUUIDValue(namespace: "30", index: 1)
        let secondaryConversationID = try fixtureUUIDValue(namespace: "30", index: 2)
        let primaryProjectID = try fixtureUUIDValue(namespace: "32", index: 1)
        let secondaryProjectID = try fixtureUUIDValue(namespace: "32", index: 2)
        let primaryChapterVersionID = try fixtureUUIDValue(namespace: "34", index: 1)
        let secondaryChapterVersionID = try fixtureUUIDValue(namespace: "34", index: 2)
        let primaryChapterLogicalID = primaryChapterVersionID
        let secondaryChapterLogicalID = secondaryChapterVersionID
        let primaryDraft = "下一步想让主角先不开门"
        let primaryChapterTitle = "第一章 山门夜响"
        let primaryChapterBody = "雨落在石阶上。\n\n封闭十年的山门忽然响了三声。"
        let secondaryChapterTitle = "第三章 雾港来信"
        let secondaryChapterBody = "潮声越过旧城墙，一封没有署名的信落在灯下。"
        let primaryTurn = try S1ConversationPreview.makeTurn(
            from: "雨夜里，有人敲响了封闭十年的山门"
        )
        let secondaryTurn = try S1ConversationPreview.makeTurn(
            from: "记下另一座城里那封没有署名的来信"
        )

        // This DEBUG-only compatibility fixture intentionally constructs a complete database graph.
        // The fresh-scope check and seed share one transaction so a failed launch cannot leave a partial graph.
        try database.queue.write { db in
            try requireFreshFixtureScope(in: db)
            try insertFixtureConversation(
                in: db,
                id: primaryConversationID,
                title: S1ConversationPreview.makeHistoryTitle(
                    fromValidatedUserText: primaryTurn.userText
                ),
                createdAt: seedDate,
                updatedAt: seedDate
            )
            try insertFixturePreviewTurn(
                in: db,
                conversationID: primaryConversationID,
                messageNamespace: "31",
                firstMessageIndex: 1,
                turn: primaryTurn,
                timestamp: seedDate
            )
            try insertFixtureDraft(
                in: db,
                conversationID: primaryConversationID,
                content: primaryDraft,
                updatedAt: seedDate.addingTimeInterval(1)
            )
            try insertFixtureProject(
                in: db,
                id: primaryProjectID,
                title: "雾城守夜人",
                premise: "封闭十年的山门在雨夜重新响起",
                timestamp: seedDate.addingTimeInterval(2)
            )
            try insertFixtureAgentSession(
                in: db,
                conversationID: primaryConversationID,
                focusedProjectID: primaryProjectID,
                updatedAt: seedDate.addingTimeInterval(3)
            )

            try insertFixtureConversation(
                in: db,
                id: secondaryConversationID,
                title: S1ConversationPreview.makeHistoryTitle(
                    fromValidatedUserText: secondaryTurn.userText
                ),
                createdAt: seedDate.addingTimeInterval(5),
                updatedAt: seedDate.addingTimeInterval(5)
            )
            try insertFixturePreviewTurn(
                in: db,
                conversationID: secondaryConversationID,
                messageNamespace: "31",
                firstMessageIndex: 3,
                turn: secondaryTurn,
                timestamp: seedDate.addingTimeInterval(5)
            )
            try insertFixtureProject(
                in: db,
                id: secondaryProjectID,
                title: "另一座城",
                premise: "书架里用于验证只浏览、不偷换创作上下文的另一本书",
                timestamp: seedDate.addingTimeInterval(6)
            )
            try insertFixtureAgentSession(
                in: db,
                conversationID: secondaryConversationID,
                focusedProjectID: secondaryProjectID,
                updatedAt: seedDate.addingTimeInterval(7)
            )

            try seedReadableChapter(
                in: db,
                logicalID: primaryChapterLogicalID,
                versionID: primaryChapterVersionID,
                conversationID: primaryConversationID,
                projectID: primaryProjectID,
                chapterNumber: 1,
                title: primaryChapterTitle,
                body: primaryChapterBody,
                now: seedDate.addingTimeInterval(9)
            )
            try seedReadableChapter(
                in: db,
                logicalID: secondaryChapterLogicalID,
                versionID: secondaryChapterVersionID,
                conversationID: secondaryConversationID,
                projectID: secondaryProjectID,
                chapterNumber: 3,
                title: secondaryChapterTitle,
                body: secondaryChapterBody,
                now: seedDate.addingTimeInterval(11)
            )
            try selectWorkspaceConversation(
                in: db,
                conversationID: primaryConversationID,
                updatedAt: seedDate.addingTimeInterval(12)
            )
        }

        try validatePersistedReadableTwoBooks(
            in: database,
            primaryConversationID: primaryConversationID,
            secondaryConversationID: secondaryConversationID,
            primaryProjectID: primaryProjectID,
            secondaryProjectID: secondaryProjectID,
            primaryDraft: primaryDraft,
            primaryTurn: primaryTurn,
            secondaryTurn: secondaryTurn,
            primaryChapterTitle: primaryChapterTitle,
            primaryChapterBody: primaryChapterBody,
            secondaryChapterTitle: secondaryChapterTitle,
            secondaryChapterBody: secondaryChapterBody
        )
    }

    private static func validatePersistedReadableTwoBooks(
        in database: AppDatabase,
        primaryConversationID: UUID,
        secondaryConversationID: UUID,
        primaryProjectID: UUID,
        secondaryProjectID: UUID,
        primaryDraft: String,
        primaryTurn: S1ConversationPreviewTurn,
        secondaryTurn: S1ConversationPreviewTurn,
        primaryChapterTitle: String,
        primaryChapterBody: String,
        secondaryChapterTitle: String,
        secondaryChapterBody: String
    ) throws {
        let expectedConversationIDs = [primaryConversationID, secondaryConversationID].map(\.uuidString)
        let expectedConversationTitles = [primaryTurn, secondaryTurn].map {
            S1ConversationPreview.makeHistoryTitle(fromValidatedUserText: $0.userText)
        }
        let expectedMessageIDs = (1...4).map { fixtureUUID(namespace: "31", index: $0) }
        let expectedMessageContents = [
            primaryTurn.userText, primaryTurn.systemReceipt,
            secondaryTurn.userText, secondaryTurn.systemReceipt
        ]
        let expectedMessageRoles = [
            AgentMessageRole.user.rawValue, AgentMessageRole.system.rawValue,
            AgentMessageRole.user.rawValue, AgentMessageRole.system.rawValue
        ]
        let expectedSessionScopes = [
            "\(primaryConversationID.uuidString)|\(primaryProjectID.uuidString)",
            "\(secondaryConversationID.uuidString)|\(secondaryProjectID.uuidString)"
        ]
        let isValid = try database.queue.read { db in
            let selectedID = try String.fetchOne(db, sql: "SELECT selectedConversationID FROM s1WorkspaceState WHERE id = 'default'")
            let draft = try String.fetchOne(db, sql: "SELECT content FROM s1ConversationDraft WHERE conversationID = ?", arguments: [primaryConversationID.uuidString])
            let conversationIDs = try String.fetchAll(db, sql: "SELECT id FROM agentConversation ORDER BY id ASC")
            let conversationTitles = try String.fetchAll(db, sql: "SELECT title FROM agentConversation ORDER BY id ASC")
            let messageIDs = try String.fetchAll(db, sql: "SELECT id FROM agentMessage ORDER BY id ASC")
            let messageContents = try String.fetchAll(db, sql: "SELECT content FROM agentMessage ORDER BY id ASC")
            let messageRoles = try String.fetchAll(db, sql: "SELECT role FROM agentMessage ORDER BY id ASC")
            let sessionScopes = try String.fetchAll(db, sql: "SELECT conversationID || '|' || focusedProjectID FROM agentSession ORDER BY conversationID ASC")
            let projectIDs = try String.fetchAll(db, sql: "SELECT id FROM novelProject ORDER BY updatedAt DESC, id ASC")
            let projectTitles = try String.fetchAll(db, sql: "SELECT title FROM novelProject ORDER BY updatedAt DESC, id ASC")
            let relationshipCount = try readableRelationshipCount(
                in: db,
                scopes: [(primaryConversationID, primaryProjectID), (secondaryConversationID, secondaryProjectID)]
            )
            return try fixtureTableCounts(in: db) == FixtureTableCounts(
                projects: 2, conversations: 2, messages: 4, sessions: 2,
                drafts: 1, chapters: 2, calibrations: 2
            )
                && selectedID == primaryConversationID.uuidString
                && draft == primaryDraft
                && conversationIDs == expectedConversationIDs
                && conversationTitles == expectedConversationTitles
                && messageIDs == expectedMessageIDs
                && messageContents == expectedMessageContents
                && messageRoles == expectedMessageRoles
                && sessionScopes == expectedSessionScopes
                && projectIDs == [secondaryProjectID.uuidString, primaryProjectID.uuidString]
                && projectTitles == ["另一座城", "雾城守夜人"]
                && relationshipCount == 2
        }
        let primary = try database.restoreS1ReadableContent(selectedConversationID: primaryConversationID)
        let secondary = try database.restoreS1ReadableContent(selectedConversationID: secondaryConversationID)
        guard isValid,
              primary?.conversationID == primaryConversationID,
              primary?.projectID == primaryProjectID,
              primary?.projectTitle == "雾城守夜人",
              primary?.chapterTitle == primaryChapterTitle,
              primary?.body == primaryChapterBody,
              secondary?.conversationID == secondaryConversationID,
              secondary?.projectID == secondaryProjectID,
              secondary?.projectTitle == "另一座城",
              secondary?.chapterTitle == secondaryChapterTitle,
              secondary?.body == secondaryChapterBody else {
            throw FixtureBootstrapError.seedFailed
        }
    }

    private static func seedPersistedScaleAndRestore(in database: AppDatabase) throws {
        let seedDate = Date(timeIntervalSince1970: 1_784_462_400)
        let conversationID = try fixtureUUIDValue(namespace: "40", index: 1)
        let focusedProjectID = try fixtureUUIDValue(namespace: "42", index: 1)
        let chapterVersionID = try fixtureUUIDValue(namespace: "44", index: 1)
        let chapterLogicalID = chapterVersionID
        let draft = "规模测试中仍然保留的草稿"
        let chapterTitle = "第一章 灯塔来信"
        let chapterBody = "夜潮拍打着旧码头，灯塔顶端亮起一封等待多年的回信。"

        // Direct SQL is confined to this DEBUG compatibility fixture. A fresh-scope transaction
        // deterministically inserts fixture-owned rows and updates only the migration-created workspace singleton.
        try database.queue.write { db in
            try requireFreshFixtureScope(in: db)
            try insertFixtureConversation(
                in: db,
                id: conversationID,
                title: "长篇对话恢复验证",
                createdAt: seedDate,
                updatedAt: seedDate.addingTimeInterval(240)
            )

            for index in 1...240 {
                let timestamp = seedDate.addingTimeInterval(Double(index))
                try insertFixtureMessage(
                    in: db,
                    id: try fixtureUUIDValue(namespace: "41", index: index),
                    conversationID: conversationID,
                    role: .user,
                    content: String(format: "长对话消息 %03d", index),
                    idempotencyKey: "ui-fixture-scale-message-\(index)",
                    createdAt: timestamp
                )
            }

            try insertFixtureDraft(
                in: db,
                conversationID: conversationID,
                content: draft,
                updatedAt: seedDate.addingTimeInterval(241)
            )

            for index in 1...80 {
                let projectID = try fixtureUUIDValue(namespace: "42", index: index)
                let timestamp = seedDate.addingTimeInterval(Double(80 - index))
                try insertFixtureProject(
                    in: db,
                    id: projectID,
                    title: String(format: "规模书籍 %03d", index),
                    premise: "用于验证长书架顺序、返回位置和重启恢复的固定测试项目。",
                    timestamp: timestamp
                )
            }

            try insertFixtureAgentSession(
                in: db,
                conversationID: conversationID,
                focusedProjectID: focusedProjectID,
                updatedAt: seedDate.addingTimeInterval(242)
            )
            try seedReadableChapter(
                in: db,
                logicalID: chapterLogicalID,
                versionID: chapterVersionID,
                conversationID: conversationID,
                projectID: focusedProjectID,
                chapterNumber: 1,
                title: chapterTitle,
                body: chapterBody,
                now: seedDate.addingTimeInterval(243)
            )
            try selectWorkspaceConversation(
                in: db,
                conversationID: conversationID,
                updatedAt: seedDate.addingTimeInterval(244)
            )
        }

        try validatePersistedScaleAndRestore(
            in: database,
            conversationID: conversationID,
            focusedProjectID: focusedProjectID,
            draft: draft,
            chapterTitle: chapterTitle,
            chapterBody: chapterBody
        )
    }

    private static func validatePersistedScaleAndRestore(
        in database: AppDatabase,
        conversationID: UUID,
        focusedProjectID: UUID,
        draft: String,
        chapterTitle: String,
        chapterBody: String
    ) throws {
        let expectedMessageIDs = (1...240).map { fixtureUUID(namespace: "41", index: $0) }
        let expectedMessageContents = (1...240).map { String(format: "长对话消息 %03d", $0) }
        let expectedProjectIDs = (1...80).map { fixtureUUID(namespace: "42", index: $0) }
        let expectedProjectTitles = (1...80).map { String(format: "规模书籍 %03d", $0) }
        let isValid = try database.queue.read { db in
            let selectedID = try String.fetchOne(db, sql: "SELECT selectedConversationID FROM s1WorkspaceState WHERE id = 'default'")
            let storedDraft = try String.fetchOne(db, sql: "SELECT content FROM s1ConversationDraft WHERE conversationID = ?", arguments: [conversationID.uuidString])
            let title = try String.fetchOne(db, sql: "SELECT title FROM agentConversation WHERE id = ?", arguments: [conversationID.uuidString])
            let focusedID = try String.fetchOne(db, sql: "SELECT focusedProjectID FROM agentSession WHERE conversationID = ?", arguments: [conversationID.uuidString])
            let messageIDs = try String.fetchAll(db, sql: "SELECT id FROM agentMessage ORDER BY createdAt ASC, id ASC")
            let messageContents = try String.fetchAll(db, sql: "SELECT content FROM agentMessage ORDER BY createdAt ASC, id ASC")
            let projectIDs = try String.fetchAll(db, sql: "SELECT id FROM novelProject ORDER BY updatedAt DESC, id ASC")
            let projectTitles = try String.fetchAll(db, sql: "SELECT title FROM novelProject ORDER BY updatedAt DESC, id ASC")
            let relationshipCount = try readableRelationshipCount(in: db, scopes: [(conversationID, focusedProjectID)])
            return try fixtureTableCounts(in: db) == FixtureTableCounts(
                projects: 80, conversations: 1, messages: 240, sessions: 1,
                drafts: 1, chapters: 1, calibrations: 1
            )
                && selectedID == conversationID.uuidString
                && storedDraft == draft
                && title == "长篇对话恢复验证"
                && focusedID == focusedProjectID.uuidString
                && messageIDs == expectedMessageIDs
                && messageContents == expectedMessageContents
                && projectIDs == expectedProjectIDs
                && projectTitles == expectedProjectTitles
                && relationshipCount == 1
        }
        let readable = try database.restoreS1ReadableContent(selectedConversationID: conversationID)
        guard isValid,
              readable?.conversationID == conversationID,
              readable?.projectID == focusedProjectID,
              readable?.projectTitle == "规模书籍 001",
              readable?.chapterTitle == chapterTitle,
              readable?.body == chapterBody else {
            throw FixtureBootstrapError.seedFailed
        }
    }

    private static func readableRelationshipCount(
        in db: Database,
        scopes: [(conversationID: UUID, projectID: UUID)]
    ) throws -> Int {
        var count = 0
        for scope in scopes {
            count += try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*)
                    FROM chapterCalibration AS calibration
                    JOIN chapterVersion AS version
                      ON version.id = calibration.activeVersionID
                     AND version.logicalID = calibration.chapterLogicalID
                     AND version.conversationID = calibration.conversationID
                     AND version.projectID = calibration.projectID
                     AND version.chapterNumber = calibration.chapterNumber
                    JOIN agentSession AS session
                      ON session.conversationID = calibration.conversationID
                     AND session.focusedProjectID = calibration.projectID
                    WHERE calibration.conversationID = ?
                      AND calibration.projectID = ?
                    """,
                arguments: [scope.conversationID.uuidString, scope.projectID.uuidString]
            ) ?? 0
        }
        return count
    }

    private static func requireFreshFixtureScope(in database: AppDatabase) throws {
        try database.queue.read { db in
            try requireFreshFixtureScope(in: db)
        }
    }

    private static func requireFreshFixtureScope(in db: Database) throws {
        let dataTables = [
            "draft", "checkpoint", "novelProject", "toolReceipt", "agentArtifact",
            "agentConversation", "agentMessage", "agentSession", "agentRun",
            "approvalRequest", "chapterVersion", "chapterCalibration",
            "chapterToolResultSnapshot", "s1ConversationDraft", "modelConnection",
            "pendingModelIntent", "modelConnectionSetupJournal"
        ]
        for table in dataTables {
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
            guard count == 0 else {
                throw FixtureBootstrapError.seedFailed
            }
        }
        let workspaceCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM s1WorkspaceState"
        ) ?? 0
        let pristineWorkspaceCount = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*)
                FROM s1WorkspaceState
                WHERE id = 'default'
                  AND selectedConversationID IS NULL
                  AND unboundDraft = ''
                """
        ) ?? 0
        guard workspaceCount == 1, pristineWorkspaceCount == 1 else {
            throw FixtureBootstrapError.seedFailed
        }
    }
    private struct FixtureTableCounts: Equatable {
        let projects: Int
        let conversations: Int
        let messages: Int
        let sessions: Int
        let drafts: Int
        let chapters: Int
        let calibrations: Int
    }

    private static func fixtureTableCounts(in db: Database) throws -> FixtureTableCounts {
        FixtureTableCounts(
            projects: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM novelProject") ?? 0,
            conversations: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentConversation") ?? 0,
            messages: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentMessage") ?? 0,
            sessions: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentSession") ?? 0,
            drafts: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM s1ConversationDraft") ?? 0,
            chapters: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chapterVersion") ?? 0,
            calibrations: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM chapterCalibration") ?? 0
        )
    }

    private static func insertFixtureConversation(
        in db: Database,
        id: UUID,
        title: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO agentConversation (id, title, createdAt, updatedAt)
                VALUES (?, ?, ?, ?)
                """,
            arguments: [
                id.uuidString,
                title,
                createdAt.timeIntervalSince1970,
                updatedAt.timeIntervalSince1970
            ]
        )
    }

    private static func insertFixturePreviewTurn(
        in db: Database,
        conversationID: UUID,
        messageNamespace: String,
        firstMessageIndex: Int,
        turn: S1ConversationPreviewTurn,
        timestamp: Date
    ) throws {
        try insertFixtureMessage(
            in: db,
            id: try fixtureUUIDValue(namespace: messageNamespace, index: firstMessageIndex),
            conversationID: conversationID,
            role: .user,
            content: turn.userText,
            idempotencyKey: "ui-fixture-preview-message-\(messageNamespace)-\(firstMessageIndex)",
            createdAt: timestamp
        )
        try insertFixtureMessage(
            in: db,
            id: try fixtureUUIDValue(namespace: messageNamespace, index: firstMessageIndex + 1),
            conversationID: conversationID,
            role: .system,
            content: turn.systemReceipt,
            idempotencyKey: "ui-fixture-preview-message-\(messageNamespace)-\(firstMessageIndex + 1)",
            createdAt: timestamp
        )
    }

    private static func insertFixtureMessage(
        in db: Database,
        id: UUID,
        conversationID: UUID,
        role: AgentMessageRole,
        content: String,
        idempotencyKey: String,
        createdAt: Date
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO agentMessage (
                    id, conversationID, role, content, idempotencyKey, createdAt
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                id.uuidString,
                conversationID.uuidString,
                role.rawValue,
                content,
                idempotencyKey,
                createdAt.timeIntervalSince1970
            ]
        )
    }

    private static func insertFixtureDraft(
        in db: Database,
        conversationID: UUID,
        content: String,
        updatedAt: Date
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO s1ConversationDraft (conversationID, content, updatedAt)
                VALUES (?, ?, ?)
                """,
            arguments: [conversationID.uuidString, content, updatedAt.timeIntervalSince1970]
        )
    }

    private static func insertFixtureProject(
        in db: Database,
        id: UUID,
        title: String,
        premise: String,
        timestamp: Date
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO novelProject (id, title, premise, version, createdAt, updatedAt)
                VALUES (?, ?, ?, 1, ?, ?)
                """,
            arguments: [
                id.uuidString,
                title,
                premise,
                timestamp.timeIntervalSince1970,
                timestamp.timeIntervalSince1970
            ]
        )
    }

    private static func insertFixtureAgentSession(
        in db: Database,
        conversationID: UUID,
        focusedProjectID: UUID,
        updatedAt: Date
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO agentSession (
                    conversationID, focusedProjectID, interviewStep,
                    currentQuestion, interviewAnswersJSON, updatedAt
                ) VALUES (?, ?, 0, '', '[]', ?)
                """,
            arguments: [
                conversationID.uuidString,
                focusedProjectID.uuidString,
                updatedAt.timeIntervalSince1970
            ]
        )
    }

    private static func selectWorkspaceConversation(
        in db: Database,
        conversationID: UUID,
        updatedAt: Date
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO s1WorkspaceState (
                    id, selectedConversationID, unboundDraft, updatedAt
                ) VALUES ('default', ?, '', ?)
                ON CONFLICT(id) DO UPDATE SET
                    selectedConversationID = excluded.selectedConversationID,
                    unboundDraft = excluded.unboundDraft,
                    updatedAt = excluded.updatedAt
                """,
            arguments: [conversationID.uuidString, updatedAt.timeIntervalSince1970]
        )
    }

    private static func fixtureUUID(namespace: String, index: Int) -> String {
        precondition(namespace.count == 2 && index >= 0)
        return "\(namespace)000000-0000-0000-0000-\(String(format: "%012d", index))"
    }

    private static func fixtureUUIDValue(namespace: String, index: Int) throws -> UUID {
        guard let value = UUID(uuidString: fixtureUUID(namespace: namespace, index: index)) else {
            throw FixtureBootstrapError.seedFailed
        }
        return value
    }

    private static func seedReadableChapter(
        in db: Database,
        logicalID: UUID,
        versionID: UUID,
        conversationID: UUID,
        projectID: UUID,
        chapterNumber: Int,
        title: String,
        body: String,
        now: Date
    ) throws {
        let contentHash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: logicalID,
            conversationID: conversationID,
            projectID: projectID,
            chapterNumber: chapterNumber,
            revision: 1,
            parentVersionID: nil,
            title: title,
            body: body
        )
        try db.execute(
            sql: """
                INSERT INTO chapterVersion (
                    id, logicalID, conversationID, projectID, chapterNumber, revision,
                    parentVersionID, title, body, contentHash, creationStatus,
                    evidenceReview, diffSummary, createdAt
                ) VALUES (?, ?, ?, ?, ?, 1, NULL, ?, ?, ?, ?, ?, NULL, ?)
                """,
            arguments: [
                versionID.uuidString,
                logicalID.uuidString,
                conversationID.uuidString,
                projectID.uuidString,
                chapterNumber,
                title,
                body,
                contentHash,
                ChapterVersionCreationStatus.calibrationReview.rawValue,
                "已完成证据检查",
                now.timeIntervalSince1970
            ]
        )
        let matchingVersionCount = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*)
                FROM chapterVersion
                WHERE id = ?
                  AND logicalID = ?
                  AND conversationID = ?
                  AND projectID = ?
                  AND chapterNumber = ?
                  AND revision = 1
                  AND parentVersionID IS NULL
                  AND title = ?
                  AND body = ?
                  AND contentHash = ?
                  AND creationStatus = ?
                  AND evidenceReview = ?
                  AND diffSummary IS NULL
                  AND createdAt = ?
                """,
            arguments: [
                versionID.uuidString,
                logicalID.uuidString,
                conversationID.uuidString,
                projectID.uuidString,
                chapterNumber,
                title,
                body,
                contentHash,
                ChapterVersionCreationStatus.calibrationReview.rawValue,
                "已完成证据检查",
                now.timeIntervalSince1970
            ]
        ) ?? 0
        guard matchingVersionCount == 1 else {
            throw FixtureBootstrapError.seedFailed
        }
        try db.execute(
            sql: """
                INSERT INTO chapterCalibration (
                    chapterLogicalID, conversationID, projectID, chapterNumber,
                    activeVersionID, stage, diagnosisEntriesJSON, diagnosisHash,
                    rejectionHistoryJSON, lockedParagraphIndexesJSON, rewriteScope,
                    rewriteScopeHash, acceptedVersionID, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, '[]', ?, '[]', '[]', NULL, NULL, NULL, ?)
                """,
            arguments: [
                logicalID.uuidString,
                conversationID.uuidString,
                projectID.uuidString,
                chapterNumber,
                versionID.uuidString,
                ChapterCalibrationStage.reviewingV1.rawValue,
                ChapterFingerprint.diagnosisHash([]),
                now.addingTimeInterval(1).timeIntervalSince1970
            ]
        )
    }
}

private actor ModelConnectionSetupUITestTransport: ModelDiscoveryHTTPTransport {
    nonisolated let customDestinationCapability: ModelDiscoveryCustomDestinationCapability = .unavailable

    func authenticateCustomConnection(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination
    ) async throws -> ModelDiscoveryAuthenticatedConnectionEvidence? {
        nil
    }

    func send(
        _ request: URLRequest,
        requestIdentity: ModelDiscoveryRequestIdentity,
        maximumResponseBytes: Int,
        verifiedDestination: ModelDiscoveryVerifiedDestination?
    ) async throws -> ModelDiscoveryTransportResponse {
        guard let url = request.url else {
            throw ModelDiscoveryNetworkError.invalidResponse
        }
        let modelIDs = ["gpt-fixture"]
            + (1...40).map { "gpt-fixture-\($0)" }
            + ["gpt-fixture-tail"]
        let body = try JSONSerialization.data(
            withJSONObject: ["data": modelIDs.map { ["id": $0] }]
        )
        return ModelDiscoveryTransportResponse(
            requestIdentity: requestIdentity,
            requestURL: url,
            statusCode: 200,
            body: body
        )
    }
}

@MainActor
final class CangJieUITestNetworkAvailabilityObserver:
    NetworkAvailabilityObserving
{
    private(set) var state: NetworkAvailabilityState
    private var handler: ((NetworkAvailabilityState) -> Void)?

    init(state: NetworkAvailabilityState) {
        self.state = state
    }

    func start(
        _ handler: @escaping (NetworkAvailabilityState) -> Void
    ) {
        self.handler = handler
    }

    func stop() {
        handler = nil
    }

    func update(_ state: NetworkAvailabilityState) {
        self.state = state
        handler?(state)
    }
}

@MainActor
private final class CangJieUITestNotificationConsentStore:
    AgentTaskNotificationConsentStoring
{
    private(set) var decision = AgentTaskNotificationConsentDecision.declined

    func setDecision(_ decision: AgentTaskNotificationConsentDecision) {
        self.decision = decision
    }
}

private final class CangJieUITestProviderGenerationService:
    ProviderGenerationServing
{
    func stream(
        request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection,
        secret: String,
        systemPrompt: String,
        userPrompt: String
    ) -> AsyncThrowingStream<ProviderGenerationEvent, Error> {
        if (userPrompt.contains("ui-streaming-pause")
                || userPrompt.contains("ui-offline-primary")),
           request.identity.attemptNumber == 1 {
            return AsyncThrowingStream { continuation in
                continuation.yield(.textDelta("可暂停任务正在流式返回"))
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
        return AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(.textDelta("S2 UI 任务已处理"))
                do {
                    try await Task.sleep(nanoseconds: 200_000_000)
                } catch {
                    continuation.finish(throwing: CancellationError())
                    return
                }
                continuation.yield(.finished(reason: "stop"))
                continuation.yield(
                    .usage(
                        ProviderUsage(
                            inputTokens: 4,
                            outputTokens: 4,
                            totalTokens: 8
                        )
                    )
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

#endif
