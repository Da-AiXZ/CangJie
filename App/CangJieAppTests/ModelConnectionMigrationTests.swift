import CangJieCore
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

    private func encodePendingIntent(_ intent: PendingModelIntent) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try XCTUnwrap(
            String(data: encoder.encode(intent), encoding: .utf8)
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
