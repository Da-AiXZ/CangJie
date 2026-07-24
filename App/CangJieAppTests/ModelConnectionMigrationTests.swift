@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ModelConnectionMigrationTests: XCTestCase {
    func testCredentialVersionMigrationUpgradesLegacyConnectionRows() throws {
        try withTemporaryDatabasePath { path in
            let expected = try makeLegacyModelConnectionDatabase(at: path)

            let database = try AppDatabase(path: path)
            let stored = try XCTUnwrap(database.listModelConnections().first)

            XCTAssertEqual(stored.connection, expected)
            XCTAssertEqual(try database.currentModelConnection(), stored)
            let migrated = try database.queue.read { db -> (String, String, Int) in
                let row = try XCTUnwrap(Row.fetchOne(
                    db,
                    sql: "SELECT credentialVersionID, payloadJSON FROM modelConnection WHERE id = ?",
                    arguments: [expected.id.uuidString]
                ))
                let migrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-model-connection-credential-version-v2"]
                ) ?? 0
                return (row["credentialVersionID"], row["payloadJSON"], migrationCount)
            }
            XCTAssertEqual(migrated.0, expected.credential.versionID.uuidString)
            XCTAssertTrue(migrated.1.contains(expected.credential.versionID.uuidString))
            XCTAssertEqual(migrated.2, 1)
        }
    }

    func testCredentialVersionMigrationRejectsTamperedLegacyPayload() throws {
        try withTemporaryDatabasePath { path in
            _ = try makeLegacyModelConnectionDatabase(
                at: path,
                corruptPayloadHash: true
            )

            XCTAssertThrowsError(try AppDatabase(path: path)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }

            let queue = try DatabaseQueue(path: path)
            let migrationCount = try queue.read { db in
                try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-model-connection-credential-version-v2"]
                ) ?? 0
            }
            XCTAssertEqual(migrationCount, 0)
        }
    }

    func testPendingIntentConversationMigrationCreatesUnconsumedUniqueConstraint() throws {
        try withTemporaryDatabasePath { path in
            let database = try AppDatabase(path: path)
            let state = try database.queue.read { db -> (Int, String, Int, Int) in
                let uniqueFlag = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT \"unique\"
                        FROM pragma_index_list('pendingModelIntent')
                        WHERE name = 'pendingModelIntent_conversation_unconsumed'
                        """
                ) ?? 0
                let indexSQL = try String.fetchOne(
                    db,
                    sql: """
                        SELECT sql
                        FROM sqlite_master
                        WHERE type = 'index'
                          AND name = 'pendingModelIntent_conversation_unconsumed'
                        """
                ) ?? ""
                let originalMigrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-pending-model-intent-conversation-unique-v1"]
                ) ?? 0
                let providerMigrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-provider-request-runtime-v1"]
                ) ?? 0
                return (
                    uniqueFlag,
                    indexSQL,
                    originalMigrationCount,
                    providerMigrationCount
                )
            }
            XCTAssertEqual(state.0, 1)
            XCTAssertTrue(state.1.contains("WHERE consumedAt IS NULL"))
            XCTAssertEqual(state.2, 1)
            XCTAssertEqual(state.3, 1)
        }
    }

    func testPendingIntentConversationMigrationRejectsAmbiguousLegacyRows() throws {
        try withTemporaryDatabasePath { path in
            let conversationID = UUID()
            do {
                var configuration = Configuration()
                configuration.foreignKeysEnabled = true
                let queue = try DatabaseQueue(path: path, configuration: configuration)
                try AppDatabase.migrator.migrate(
                    queue,
                    upTo: "s2-model-connection-setup-journal-v1"
                )
                try queue.write { db in
                    try db.execute(
                        sql: "INSERT INTO agentConversation (id, title, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
                        arguments: [conversationID.uuidString, "Legacy pending", 2_100.0, 2_100.0]
                    )
                    for (offset, request) in ["first", "second"].enumerated() {
                        let intent = try PendingModelIntent(
                            id: UUID(),
                            conversationID: conversationID,
                            projectID: nil,
                            branchID: nil,
                            userRequest: request,
                            createdAt: Date(timeIntervalSince1970: 2_101.0 + Double(offset))
                        )
                        let payload = try encodePendingIntent(intent)
                        try db.execute(
                            sql: """
                                INSERT INTO pendingModelIntent (
                                    id, conversationID, projectID, branchID,
                                    payloadVersion, payloadJSON, payloadHash, createdAt
                                ) VALUES (?, ?, NULL, NULL, 1, ?, ?, ?)
                                """,
                            arguments: [
                                intent.id.uuidString,
                                conversationID.uuidString,
                                payload,
                                AppDatabase.payloadHash(payload),
                                intent.createdAt.timeIntervalSince1970
                            ]
                        )
                    }
                }
            }

            XCTAssertThrowsError(try AppDatabase(path: path)) { error in
                XCTAssertEqual(
                    error as? AppDatabaseError,
                    .pendingModelIntentAlreadyExists
                )
            }

            let queue = try DatabaseQueue(path: path)
            let migrationCount = try queue.read { db in
                try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-pending-model-intent-conversation-unique-v1"]
                ) ?? 0
            }
            XCTAssertEqual(migrationCount, 0)
        }
    }

    func testProviderRequestLinearMigrationCreatesBoundedChainIndexes() throws {
        try withTemporaryDatabasePath { path in
            let database = try AppDatabase(path: path)
            let state = try database.queue.read { db -> (String, [String], Int, String, Int) in
                let tableSQL = try String.fetchOne(
                    db,
                    sql: """
                        SELECT sql FROM sqlite_master
                        WHERE type = 'table' AND name = 'providerRequest'
                        """
                ) ?? ""
                let indexes = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT name FROM pragma_index_list('providerRequest')
                        WHERE name LIKE 'providerRequest_%'
                        ORDER BY name
                        """
                ).map { row -> String in row["name"] }
                let migrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-provider-request-linear-v2"]
                ) ?? 0
                let previousRequestTarget = try String.fetchOne(
                    db,
                    sql: """
                        SELECT "table"
                        FROM pragma_foreign_key_list('providerRequest')
                        WHERE "from" = 'previousRequestID'
                        """
                ) ?? ""
                let legacyTableCount = try Int.fetchOne(
                    db,
                    sql: """
                        SELECT COUNT(*)
                        FROM sqlite_master
                        WHERE type = 'table' AND name = 'providerRequest_v1'
                        """
                ) ?? 0
                return (
                    tableSQL,
                    indexes,
                    migrationCount,
                    previousRequestTarget,
                    legacyTableCount
                )
            }

            XCTAssertTrue(state.0.contains("attemptNumber INTEGER NOT NULL"))
            XCTAssertTrue(state.0.contains("turnSequence INTEGER NOT NULL"))
            XCTAssertTrue(state.0.contains("previousRequestID TEXT"))
            XCTAssertFalse(state.0.contains("intentID TEXT NOT NULL UNIQUE"))
            XCTAssertFalse(state.0.contains("runID TEXT NOT NULL UNIQUE"))
            XCTAssertEqual(
                state.1,
                [
                    "providerRequest_conversation_updated",
                    "providerRequest_intent_active",
                    "providerRequest_intent_attempt_turn",
                    "providerRequest_previous_unique",
                    "providerRequest_run_sequence"
                ]
            )
            XCTAssertEqual(state.2, 1)
            XCTAssertEqual(state.3, "providerRequest")
            XCTAssertEqual(state.4, 0)
        }
    }

    func testProviderRequestTerminationMigrationPreservesBindingsAndTransition() throws {
        try withTemporaryDatabasePath { path in
            let legacy = try makePublishedV1ProviderRequestDatabase(at: path)
            let receiptID = UUID()
            do {
                var configuration = Configuration()
                configuration.foreignKeysEnabled = true
                let queue = try DatabaseQueue(
                    path: path,
                    configuration: configuration
                )
                try AppDatabase.migrator.migrate(
                    queue,
                    upTo: "s2-pending-model-intent-admission-v3"
                )
                try queue.write { db in
                    for phase in ["sending", "streaming", "responseComplete"] {
                        try db.execute(
                            sql: "UPDATE providerRequest SET phase = ? WHERE id = ?",
                            arguments: [
                                phase,
                                legacy.request.identity.requestID.uuidString
                            ]
                        )
                    }
                    try db.execute(
                        sql: """
                            INSERT INTO toolReceipt (
                                id, toolID, toolVersion, inputSummary, inputHash,
                                outcome, conversationID, projectID, originRunID,
                                idempotencyKey, providerRequestID,
                                providerCallID, providerCallIndex, createdAt
                            ) VALUES (?, 'project.status', '1', 'project.status', ?,
                                      'completed', ?, NULL, ?, ?, ?, 'call-1', 0, ?)
                            """,
                        arguments: [
                            receiptID.uuidString,
                            String(repeating: "a", count: 64),
                            legacy.request.identity.conversationID.uuidString,
                            legacy.request.identity.runID.uuidString,
                            "provider.tool.migration-fixture",
                            legacy.request.identity.requestID.uuidString,
                            legacy.request.createdAt.timeIntervalSince1970
                        ]
                    )
                }
            }
            let database = try AppDatabase(path: path)

            let state = try database.queue.write { db -> (String, String, Int, Int, Int, String, String) in
                try db.execute(
                    sql: "UPDATE providerRequest SET phase = 'terminated' WHERE id = ?",
                    arguments: [legacy.request.identity.requestID.uuidString]
                )
                let tableSQL = try String.fetchOne(
                    db,
                    sql: """
                        SELECT sql FROM sqlite_master
                        WHERE type = 'table' AND name = 'providerRequest'
                        """
                ) ?? ""
                let triggerSQL = try String.fetchOne(
                    db,
                    sql: """
                        SELECT sql FROM sqlite_master
                        WHERE type = 'trigger'
                          AND name = 'providerRequest_phase_transition_guard'
                        """
                ) ?? ""
                let migrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-provider-request-termination-v4"]
                ) ?? 0
                let foreignKeyViolations = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM pragma_foreign_key_check"
                ) ?? 0
                let receiptCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM toolReceipt WHERE id = ?",
                    arguments: [receiptID.uuidString]
                ) ?? 0
                let selfReferenceTable = try String.fetchOne(
                    db,
                    sql: """
                        SELECT "table"
                        FROM pragma_foreign_key_list('providerRequest')
                        WHERE "from" = 'previousRequestID'
                        """
                ) ?? ""
                let consumptionTriggerSQL = try String.fetchOne(
                    db,
                    sql: """
                        SELECT sql FROM sqlite_master
                        WHERE type = 'trigger'
                          AND name = 'pendingModelIntent_consumption_guard'
                        """
                ) ?? ""
                return (
                    tableSQL,
                    triggerSQL,
                    migrationCount,
                    foreignKeyViolations,
                    receiptCount,
                    selfReferenceTable,
                    consumptionTriggerSQL
                )
            }

            XCTAssertTrue(state.0.contains("'terminated'"))
            XCTAssertTrue(state.1.contains("'continuationCommitted', 'terminated'"))
            XCTAssertEqual(state.2, 1)
            XCTAssertEqual(state.3, 0)
            XCTAssertEqual(state.4, 1)
            XCTAssertEqual(state.5, "providerRequest")
            XCTAssertTrue(state.6.contains("resolvedTaskID"))
            XCTAssertTrue(state.6.contains("pending intent requires settled task"))
        }
    }

    func testProviderRequestLinearMigrationPreservesPublishedV1Payload() throws {
        try withTemporaryDatabasePath { path in
            let legacy = try makePublishedV1ProviderRequestDatabase(at: path)

            let database = try AppDatabase(path: path)
            let restored = try XCTUnwrap(
                database.providerRequest(
                    id: legacy.request.identity.requestID
                )
            )
            let stored = try database.queue.read { db -> (String, String, Int, Int) in
                let row = try XCTUnwrap(Row.fetchOne(
                    db,
                    sql: """
                        SELECT payloadJSON, payloadHash, attemptNumber, turnSequence
                        FROM providerRequest WHERE id = ?
                        """,
                    arguments: [legacy.request.identity.requestID.uuidString]
                ))
                return (
                    row["payloadJSON"],
                    row["payloadHash"],
                    row["attemptNumber"],
                    row["turnSequence"]
                )
            }

            XCTAssertEqual(restored, legacy.request)
            XCTAssertEqual(stored.0, legacy.payloadJSON)
            XCTAssertEqual(stored.1, legacy.payloadHash)
            XCTAssertEqual(stored.2, 1)
            XCTAssertEqual(stored.3, 1)
            XCTAssertNil(restored.identity.previousRequestID)
        }
    }

    func testAgentTaskMigrationBackfillsPublishedProviderRunIdentity() throws {
        try withTemporaryDatabasePath { path in
            let legacy = try makePublishedV1ProviderRequestDatabase(at: path)

            let database = try AppDatabase(path: path)
            let task = try XCTUnwrap(
                database.agentTask(intentID: legacy.request.identity.intentID)
            )
            let stored = try database.queue.read { db -> (String?, Int, Int) in
                let taskID = try String.fetchOne(
                    db,
                    sql: "SELECT taskID FROM agentRun WHERE id = ?",
                    arguments: [legacy.request.identity.runID.uuidString]
                )
                let eventCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM agentTaskEvent WHERE taskID = ?",
                    arguments: [task.id.uuidString]
                ) ?? 0
                let migrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-agent-task-control-v1"]
                ) ?? 0
                return (taskID, eventCount, migrationCount)
            }

            XCTAssertEqual(task.status, .running)
            XCTAssertNil(task.outcome)
            XCTAssertEqual(task.activeRunID, legacy.request.identity.runID)
            XCTAssertEqual(stored.0, task.id.uuidString)
            XCTAssertEqual(stored.1, 1)
            XCTAssertEqual(stored.2, 1)
        }
    }

    func testPendingIntentAdmissionMigrationFailsClosedForLegacyQueuedTask() throws {
        try withTemporaryDatabasePath { path in
            let legacy = try makePublishedV1ProviderRequestDatabase(at: path)
            let orphanConversationID = UUID()
            let orphan = try PendingModelIntent(
                id: UUID(),
                conversationID: orphanConversationID,
                projectID: nil,
                branchID: nil,
                userRequest: "无法证明原始网络状态的旧请求",
                createdAt: Date(timeIntervalSince1970: 2_201)
            )
            let orphanPayload = try encodePendingIntent(orphan)
            var configuration = Configuration()
            configuration.foreignKeysEnabled = true
            let legacyQueue = try DatabaseQueue(
                path: path,
                configuration: configuration
            )
            try AppDatabase.migrator.migrate(
                legacyQueue,
                upTo: "s2-agent-task-waiting-reason-v2"
            )
            try legacyQueue.write { db in
                try db.execute(
                    sql: """
                        UPDATE agentTask
                        SET status = 'queued', primarySlot = NULL
                        WHERE intentID = ?
                        """,
                    arguments: [legacy.request.identity.intentID.uuidString]
                )
                XCTAssertEqual(db.changesCount, 1)
                try db.execute(
                    sql: """
                        INSERT INTO agentConversation (
                            id, title, createdAt, updatedAt
                        ) VALUES (?, 'Legacy orphan', ?, ?)
                        """,
                    arguments: [
                        orphanConversationID.uuidString,
                        orphan.createdAt.timeIntervalSince1970,
                        orphan.createdAt.timeIntervalSince1970
                    ]
                )
                try db.execute(
                    sql: """
                        INSERT INTO pendingModelIntent (
                            id, conversationID, projectID, branchID,
                            payloadVersion, payloadJSON, payloadHash, createdAt,
                            consumedAt, continuationRequestID
                        ) VALUES (?, ?, NULL, NULL, 1, ?, ?, ?, NULL, NULL)
                        """,
                    arguments: [
                        orphan.id.uuidString,
                        orphanConversationID.uuidString,
                        orphanPayload,
                        AppDatabase.payloadHash(orphanPayload),
                        orphan.createdAt.timeIntervalSince1970
                    ]
                )
            }

            let database = try AppDatabase(path: path)
            let migrated = try database.queue.read { db -> (String, String, Int) in
                let condition = try String.fetchOne(
                    db,
                    sql: "SELECT admissionCondition FROM pendingModelIntent WHERE id = ?",
                    arguments: [legacy.request.identity.intentID.uuidString]
                )
                let orphanCondition = try String.fetchOne(
                    db,
                    sql: "SELECT admissionCondition FROM pendingModelIntent WHERE id = ?",
                    arguments: [orphan.id.uuidString]
                )
                let migrationCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-pending-model-intent-admission-v3"]
                ) ?? 0
                return (
                    try XCTUnwrap(condition),
                    try XCTUnwrap(orphanCondition),
                    migrationCount
                )
            }

            XCTAssertEqual(
                migrated.0,
                PendingModelIntentAdmissionCondition
                    .networkConfirmationRequired.rawValue
            )
            XCTAssertEqual(
                migrated.1,
                PendingModelIntentAdmissionCondition
                    .networkConfirmationRequired.rawValue
            )
            XCTAssertEqual(migrated.2, 1)
            XCTAssertThrowsError(
                try database.queue.write { db in
                    try db.execute(
                        sql: "UPDATE pendingModelIntent SET admissionCondition = 'ready' WHERE id = ?",
                        arguments: [legacy.request.identity.intentID.uuidString]
                    )
                }
            )
        }
    }

    func testProviderToolReceiptMigrationPreservesLegacyReceipt() throws {
        try withTemporaryDatabasePath { path in
            let receiptID = UUID()
            let createdAt = Date(timeIntervalSince1970: 2_300)
            do {
                var configuration = Configuration()
                configuration.foreignKeysEnabled = true
                let queue = try DatabaseQueue(
                    path: path,
                    configuration: configuration
                )
                try AppDatabase.migrator.migrate(
                    queue,
                    upTo: "s2-provider-request-linear-v2"
                )
                try queue.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO toolReceipt (
                                id, toolID, toolVersion, inputSummary, inputHash,
                                outcome, conversationID, projectID,
                                approvalRequestID, approvalBindingHash,
                                originRunID, idempotencyKey, outputReference,
                                createdAt
                            ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL,
                                      NULL, ?, NULL, ?)
                            """,
                        arguments: [
                            receiptID.uuidString,
                            "legacy.tool",
                            "1",
                            "legacy",
                            String(repeating: "a", count: 64),
                            "completed",
                            "legacy.tool.receipt",
                            createdAt.timeIntervalSince1970
                        ]
                    )
                }
            }

            let database = try AppDatabase(path: path)
            let receipt = try XCTUnwrap(
                database.toolReceipt(
                    idempotencyKey: "legacy.tool.receipt"
                )
            )

            XCTAssertEqual(receipt.id, receiptID)
            XCTAssertNil(receipt.providerRequestID)
            XCTAssertNil(receipt.providerCallID)
            XCTAssertNil(receipt.providerCallIndex)
            let migrationCount = try database.queue.read { db in
                try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM grdb_migrations WHERE identifier = ?",
                    arguments: ["s2-provider-tool-receipt-v1"]
                ) ?? 0
            }
            XCTAssertEqual(migrationCount, 1)
        }
    }

    private func makeLegacyModelConnectionDatabase(
        at path: String,
        corruptPayloadHash: Bool = false
    ) throws -> ModelConnection {
        let connectionID = UUID(
            uuidString: "71000000-0000-0000-0000-000000000001"
        )!
        let credentialID = UUID(
            uuidString: "72000000-0000-0000-0000-000000000002"
        )!
        let expected = try ModelConnectionTestFixture.makeConnection(
            id: connectionID,
            name: "Legacy OpenAI",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            credentialVersionID: credentialID,
            selectedModel: "gpt-legacy"
        )
        let currentPayload = try AppDatabase.encodeModelConnection(expected)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(currentPayload.utf8)
            ) as? [String: Any]
        )
        var credential = try XCTUnwrap(object["credential"] as? [String: Any])
        credential.removeValue(forKey: "versionID")
        object["credential"] = credential
        let legacyPayload = try XCTUnwrap(
            String(
                data: JSONSerialization.data(
                    withJSONObject: object,
                    options: [.sortedKeys, .withoutEscapingSlashes]
                ),
                encoding: .utf8
            )
        )
        let legacyHash = corruptPayloadHash
            ? String(repeating: "0", count: 64)
            : AppDatabase.payloadHash(legacyPayload)

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: path, configuration: configuration)
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "s2-model-connection-v1"
        )
        try queue.write { db in
            let connectionColumns = try Row.fetchAll(
                db,
                sql: "PRAGMA table_info(modelConnection)"
            ).map { row -> String in
                row["name"]
            }
            XCTAssertEqual(
                connectionColumns,
                [
                    "id",
                    "credentialID",
                    "credentialProvider",
                    "credentialAllowedHost",
                    "credentialAllowedPort",
                    "payloadVersion",
                    "payloadJSON",
                    "payloadHash",
                    "createdAt",
                    "updatedAt"
                ]
            )
            XCTAssertFalse(connectionColumns.contains("credentialVersionID"))
            let stateForeignKeys = try Row.fetchAll(
                db,
                sql: "PRAGMA foreign_key_list(modelConnectionState)"
            )
            XCTAssertEqual(stateForeignKeys.count, 1)
            let destinationTable: String = stateForeignKeys[0]["table"]
            let deleteAction: String = stateForeignKeys[0]["on_delete"]
            XCTAssertEqual(destinationTable, "modelConnection")
            XCTAssertEqual(deleteAction, "RESTRICT")
            try db.execute(
                sql: """
                    INSERT INTO modelConnection (
                        id, credentialID, credentialProvider, credentialAllowedHost,
                        credentialAllowedPort, payloadVersion, payloadJSON, payloadHash,
                        createdAt, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?)
                    """,
                arguments: [
                    expected.id.uuidString,
                    expected.credential.id.uuidString,
                    expected.credential.provider.rawValue,
                    expected.credential.allowedHost,
                    expected.credential.allowedPort,
                    legacyPayload,
                    legacyHash,
                    2_000.0,
                    2_000.0
                ]
            )
            try db.execute(
                sql: "UPDATE modelConnectionState SET currentConnectionID = ?, updatedAt = ? WHERE id = 'default'",
                arguments: [expected.id.uuidString, 2_000.0]
            )
            XCTAssertEqual(db.changesCount, 1)
        }
        return expected
    }

    private func makePublishedV1ProviderRequestDatabase(
        at path: String
    ) throws -> (
        request: ProviderRequestSnapshot,
        payloadJSON: String,
        payloadHash: String
    ) {
        let now = Date(timeIntervalSince1970: 2_200)
        let conversationID = UUID()
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversationID,
            projectID: nil,
            branchID: nil,
            userRequest: "创建一本迁移测试小说",
            createdAt: now
        )
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat",
            secret: "fixture-secret"
        )
        let verification = try ModelCredentialVerification(
            reference: connection.credential,
            credentialVersionProof: String(repeating: "a", count: 64),
            credentialPayloadHash: String(repeating: "b", count: 64)
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
            promptManifestHash: String(repeating: "1", count: 64),
            contextManifestHash: String(repeating: "2", count: 64),
            toolCatalogManifestHash: String(repeating: "3", count: 64),
            disclosureScopeHash: String(repeating: "4", count: 64),
            requestPolicyHash: String(repeating: "5", count: 64),
            now: now
        )
        let requestPayload = try encodeProviderRequest(request)
        let requestHash = AppDatabase.payloadHash(requestPayload)
        let intentPayload = try encodePendingIntent(intent)
        let connectionPayload = try AppDatabase.encodeModelConnection(connection)

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(path: path, configuration: configuration)
        try AppDatabase.migrator.migrate(
            queue,
            upTo: "s2-provider-request-runtime-v1"
        )
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO agentConversation (id, title, createdAt, updatedAt)
                    VALUES (?, ?, ?, ?)
                    """,
                arguments: [
                    conversationID.uuidString,
                    "Published v1 request",
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO pendingModelIntent (
                        id, conversationID, projectID, branchID, payloadVersion,
                        payloadJSON, payloadHash, createdAt, consumedAt,
                        continuationRequestID
                    ) VALUES (?, ?, NULL, NULL, 1, ?, ?, ?, NULL, NULL)
                    """,
                arguments: [
                    intent.id.uuidString,
                    conversationID.uuidString,
                    intentPayload,
                    AppDatabase.payloadHash(intentPayload),
                    now.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO modelConnection (
                        id, credentialID, credentialProvider,
                        credentialAllowedHost, credentialAllowedPort,
                        payloadVersion, payloadJSON, payloadHash, createdAt,
                        updatedAt, credentialVersionID
                    ) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    connection.id.uuidString,
                    connection.credential.id.uuidString,
                    connection.credential.provider.rawValue,
                    connection.credential.allowedHost,
                    connection.credential.allowedPort,
                    connectionPayload,
                    AppDatabase.payloadHash(connectionPayload),
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    connection.credential.versionID.uuidString
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO agentRun (
                        id, conversationID, projectID, kind, status,
                        idempotencyKey, currentStage, startedAt, updatedAt
                    ) VALUES (?, ?, NULL, 'providerTurn', 'running', ?, ?, ?, ?)
                    """,
                arguments: [
                    request.identity.runID.uuidString,
                    conversationID.uuidString,
                    "agent.run.\(intent.id.uuidString)",
                    "provider.prepared",
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO providerResponseAsset (
                        id, payloadVersion, payloadJSON, payloadHash,
                        createdAt, updatedAt
                    ) VALUES (?, 1, ?, ?, ?, ?)
                    """,
                arguments: [
                    request.responseAssetID.uuidString,
                    ProviderResponsePayload.emptyJSON,
                    AppDatabase.payloadHash(ProviderResponsePayload.emptyJSON),
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO providerRequest (
                        id, idempotencyKey, intentID, conversationID, projectID,
                        runID, connectionID, responseAssetID, phase,
                        payloadVersion, payloadJSON, payloadHash, createdAt,
                        updatedAt
                    ) VALUES (?, ?, ?, ?, NULL, ?, ?, ?, 'prepared', 1, ?, ?, ?, ?)
                    """,
                arguments: [
                    request.identity.requestID.uuidString,
                    request.identity.idempotencyKey,
                    intent.id.uuidString,
                    conversationID.uuidString,
                    request.identity.runID.uuidString,
                    connection.id.uuidString,
                    request.responseAssetID.uuidString,
                    requestPayload,
                    requestHash,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970
                ]
            )
        }
        return (request, requestPayload, requestHash)
    }

    private func encodePendingIntent(_ intent: PendingModelIntent) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try XCTUnwrap(
            String(data: encoder.encode(intent), encoding: .utf8)
        )
    }

    private func encodeProviderRequest(
        _ request: ProviderRequestSnapshot
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try XCTUnwrap(
            String(data: encoder.encode(request), encoding: .utf8)
        )
    }

    private func withTemporaryDatabasePath(
        _ body: (String) throws -> Void
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("test.sqlite").path)
    }
}
