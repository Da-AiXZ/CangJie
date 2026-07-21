import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ModelConnectionPersistenceTests: XCTestCase {
    func testNamedConnectionAndCurrentSelectionSurviveReopenWithoutCredentialPlaintextColumns() throws {
        try withTemporaryDatabasePath { path in
            let database = try AppDatabase(path: path)
            let connection = try makeConnection(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                credentialID: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
            )
            let now = Date(timeIntervalSince1970: 2_000)

            let stored = try database.storeModelConnection(
                connection,
                makeCurrent: true,
                now: now
            )

            XCTAssertEqual(stored.connection, connection)
            XCTAssertEqual(stored.createdAt, now)
            XCTAssertEqual(stored.updatedAt, now)
            XCTAssertEqual(try database.currentModelConnection(), stored)

            let columns: [String] = try database.queue.read { db in
                try Row.fetchAll(db, sql: "PRAGMA table_info(modelConnection)").map { row in
                    row["name"]
                }
            }
            XCTAssertFalse(columns.contains { column in
                let normalized = column.lowercased()
                return normalized.contains("apikey")
                    || normalized.contains("secret")
                    || normalized.contains("password")
                    || normalized.contains("authorization")
            })

            let reopened = try AppDatabase(path: path)
            XCTAssertEqual(try reopened.currentModelConnection(), stored)
            XCTAssertEqual(try reopened.listModelConnections(), [stored])
        }
    }

    func testConnectionReplayIsIdempotentButChangedPayloadOrReusedCredentialFailsClosed() throws {
        try withTemporaryDatabase { database in
            let connectionID = UUID()
            let credentialID = UUID()
            let original = try makeConnection(id: connectionID, credentialID: credentialID)

            let first = try database.storeModelConnection(
                original,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 2_010)
            )
            let replay = try database.storeModelConnection(
                original,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 2_011)
            )
            XCTAssertEqual(replay, first)

            let changed = try ModelConnection.make(
                id: connectionID,
                name: "OpenAI changed",
                provider: .openAI,
                baseURL: URL(string: "https://api.openai.com/v1")!,
                credentialID: credentialID,
                selectedModel: "gpt-changed"
            )
            XCTAssertThrowsError(
                try database.storeModelConnection(
                    changed,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 2_012)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }

            let reusedCredential = try makeConnection(id: UUID(), credentialID: credentialID)
            XCTAssertThrowsError(
                try database.storeModelConnection(
                    reusedCredential,
                    makeCurrent: false,
                    now: Date(timeIntervalSince1970: 2_013)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }
        }
    }

    func testConnectionReplayCannotOverrideALaterExplicitCurrentSelection() throws {
        try withTemporaryDatabase { database in
            let first = try makeConnection(id: UUID(), credentialID: UUID())
            let second = try makeConnection(id: UUID(), credentialID: UUID())
            _ = try database.storeModelConnection(
                first,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_014)
            )
            let selected = try database.storeModelConnection(
                second,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_015)
            )

            let replay = try database.storeModelConnection(
                first,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_016)
            )

            XCTAssertEqual(replay.connection, first)
            XCTAssertEqual(try database.currentModelConnection(), selected)
        }
    }

    func testTamperedConnectionPayloadCannotRetargetStoredCredential() throws {
        try withTemporaryDatabase { database in
            let connection = try makeConnection(id: UUID(), credentialID: UUID())
            _ = try database.storeModelConnection(
                connection,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_020)
            )

            try database.queue.write { db in
                let payload = try XCTUnwrap(
                    String.fetchOne(
                        db,
                        sql: "SELECT payloadJSON FROM modelConnection WHERE id = ?",
                        arguments: [connection.id.uuidString]
                    )
                )
                var object = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any]
                )
                object["provider"] = ModelProvider.deepSeek.rawValue
                object["baseURL"] = "https://api.deepseek.com"
                let tampered = try XCTUnwrap(
                    String(
                        data: JSONSerialization.data(withJSONObject: object),
                        encoding: .utf8
                    )
                )
                try db.execute(
                    sql: "UPDATE modelConnection SET payloadJSON = ? WHERE id = ?",
                    arguments: [tampered, connection.id.uuidString]
                )
            }

            XCTAssertThrowsError(try database.currentModelConnection()) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }
        }
    }

    func testTamperedConnectionPayloadCannotReplaceTheSelectedModel() throws {
        try withTemporaryDatabase { database in
            let connection = try makeConnection(id: UUID(), credentialID: UUID())
            _ = try database.storeModelConnection(
                connection,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_025)
            )

            try mutateJSONPayload(
                table: "modelConnection",
                id: connection.id,
                in: database
            ) { object in
                object["selectedModel"] = "gpt-other"
            }

            XCTAssertThrowsError(try database.currentModelConnection()) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }
        }
    }

    func testTamperedCustomConnectionPayloadCannotReplaceTheBaseURLPath() throws {
        try withTemporaryDatabase { database in
            let connection = try ModelConnection.make(
                id: UUID(),
                name: "Custom",
                provider: .custom,
                baseURL: URL(string: "https://models.example.com/openai/v1")!,
                credentialID: UUID(),
                selectedModel: "writer-model"
            )
            _ = try database.storeModelConnection(
                connection,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_026)
            )

            try mutateJSONPayload(
                table: "modelConnection",
                id: connection.id,
                in: database
            ) { object in
                object["baseURL"] = "https://models.example.com/retargeted/v1"
            }

            XCTAssertThrowsError(try database.currentModelConnection()) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }
        }
    }

    func testPendingIntentAndCurrentConnectionRoundTripWithoutProviderOrToolSideEffects() throws {
        try withTemporaryDatabasePath { path in
            let database = try AppDatabase(path: path)
            let conversation = try database.ensureDefaultConversation(
                now: Date(timeIntervalSince1970: 2_030)
            )
            let project = try database.createProject(
                title: "Pending intent project",
                premise: "",
                now: Date(timeIntervalSince1970: 2_031)
            )
            let intent = try PendingModelIntent(
                id: UUID(),
                conversationID: conversation.id,
                projectID: project.id,
                branchID: UUID(),
                userRequest: "继续最初的请求",
                createdAt: Date(timeIntervalSince1970: 2_032)
            )
            let connection = try makeConnection(id: UUID(), credentialID: UUID())

            XCTAssertEqual(try database.storePendingModelIntent(intent), intent)
            _ = try database.storeModelConnection(
                connection,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_033)
            )

            XCTAssertEqual(try database.pendingModelIntent(id: intent.id), intent)
            XCTAssertEqual(try database.currentModelConnection()?.connection, connection)
            XCTAssertNil(try database.latestToolReceipt())
            XCTAssertTrue(try database.listAgentMessages(conversationID: conversation.id).isEmpty)

            let reopened = try AppDatabase(path: path)
            XCTAssertEqual(try reopened.pendingModelIntent(id: intent.id), intent)
            XCTAssertEqual(try reopened.currentModelConnection()?.connection, connection)
            XCTAssertNil(try reopened.latestToolReceipt())
        }
    }

    func testPendingIntentWithFractionalTimestampRoundTripsExactly() throws {
        try withTemporaryDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let intent = try PendingModelIntent(
                id: UUID(),
                conversationID: conversation.id,
                projectID: nil,
                branchID: nil,
                userRequest: "fractional timestamp",
                createdAt: Date(timeIntervalSince1970: 2_035.123_456_789)
            )

            XCTAssertEqual(try database.storePendingModelIntent(intent), intent)
            XCTAssertEqual(try database.pendingModelIntent(id: intent.id), intent)
        }
    }

    func testPendingIntentReplayConflictAndScopeTamperingFailClosed() throws {
        try withTemporaryDatabase { database in
            let firstConversation = try database.ensureDefaultConversation()
            _ = try database.selectNewS1Conversation(
                now: Date(timeIntervalSince1970: 2_040)
            )
            let secondConversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "second scope"),
                now: Date(timeIntervalSince1970: 2_041)
            ).conversation
            let intentID = UUID()
            let original = try PendingModelIntent(
                id: intentID,
                conversationID: firstConversation.id,
                projectID: nil,
                branchID: nil,
                userRequest: "original",
                createdAt: Date(timeIntervalSince1970: 2_042)
            )
            XCTAssertEqual(try database.storePendingModelIntent(original), original)
            XCTAssertEqual(try database.storePendingModelIntent(original), original)

            let conflicting = try PendingModelIntent(
                id: intentID,
                conversationID: firstConversation.id,
                projectID: nil,
                branchID: nil,
                userRequest: "changed",
                createdAt: original.createdAt
            )
            XCTAssertThrowsError(try database.storePendingModelIntent(conflicting)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .idempotencyConflict)
            }

            try database.queue.write { db in
                try db.execute(
                    sql: "UPDATE pendingModelIntent SET conversationID = ? WHERE id = ?",
                    arguments: [secondConversation.id.uuidString, intentID.uuidString]
                )
            }
            XCTAssertThrowsError(try database.pendingModelIntent(id: intentID)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidPendingModelIntent)
            }
        }
    }

    func testPendingIntentPayloadCannotReplaceTheOriginalUserRequest() throws {
        try withTemporaryDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let intent = try PendingModelIntent(
                id: UUID(),
                conversationID: conversation.id,
                projectID: nil,
                branchID: nil,
                userRequest: "original request",
                createdAt: Date(timeIntervalSince1970: 2_044)
            )
            _ = try database.storePendingModelIntent(intent)

            try mutateJSONPayload(
                table: "pendingModelIntent",
                id: intent.id,
                in: database
            ) { object in
                object["userRequest"] = "different valid request"
            }

            XCTAssertThrowsError(try database.pendingModelIntent(id: intent.id)) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidPendingModelIntent)
            }
        }
    }

    func testCurrentConnectionSelectionIsExplicitAndDoesNotMutatePendingIntent() throws {
        try withTemporaryDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let intent = try PendingModelIntent(
                id: UUID(),
                conversationID: conversation.id,
                projectID: nil,
                branchID: nil,
                userRequest: "resume only after explicit selection",
                createdAt: Date(timeIntervalSince1970: 2_045)
            )
            let connection = try makeConnection(id: UUID(), credentialID: UUID())
            _ = try database.storePendingModelIntent(intent)
            _ = try database.storeModelConnection(
                connection,
                makeCurrent: false,
                now: Date(timeIntervalSince1970: 2_046)
            )

            XCTAssertNil(try database.currentModelConnection())
            XCTAssertEqual(try database.pendingModelIntent(id: intent.id), intent)

            try database.selectCurrentModelConnection(
                id: connection.id,
                now: Date(timeIntervalSince1970: 2_047)
            )
            XCTAssertEqual(try database.currentModelConnection()?.connection, connection)
            XCTAssertEqual(try database.pendingModelIntent(id: intent.id), intent)
        }
    }

    func testPendingIntentRetainsItsConversationAndProjectBindings() throws {
        try withTemporaryDatabase { database in
            let conversation = try database.ensureDefaultConversation()
            let project = try database.createProject(title: "Retained", premise: "")
            let intent = try PendingModelIntent(
                id: UUID(),
                conversationID: conversation.id,
                projectID: project.id,
                branchID: UUID(),
                userRequest: "retain scope",
                createdAt: Date(timeIntervalSince1970: 2_048)
            )
            _ = try database.storePendingModelIntent(intent)

            XCTAssertThrowsError(
                try database.queue.write { db in
                    try db.execute(
                        sql: "DELETE FROM agentConversation WHERE id = ?",
                        arguments: [conversation.id.uuidString]
                    )
                }
            )
            XCTAssertThrowsError(
                try database.queue.write { db in
                    try db.execute(
                        sql: "DELETE FROM novelProject WHERE id = ?",
                        arguments: [project.id.uuidString]
                    )
                }
            )
            XCTAssertEqual(try database.pendingModelIntent(id: intent.id), intent)
        }
    }

    func testCurrentConnectionSelectionRequiresAnExistingStoredConnection() throws {
        try withTemporaryDatabase { database in
            XCTAssertNil(try database.currentModelConnection())
            XCTAssertThrowsError(
                try database.selectCurrentModelConnection(
                    id: UUID(),
                    now: Date(timeIntervalSince1970: 2_050)
                )
            ) { error in
                XCTAssertEqual(error as? AppDatabaseError, .invalidModelConnection)
            }
            XCTAssertNil(try database.currentModelConnection())
        }
    }

    func testCurrentSelectionRetainsItsConnectionUntilExplicitlySwitched() throws {
        try withTemporaryDatabase { database in
            let connection = try makeConnection(id: UUID(), credentialID: UUID())
            let stored = try database.storeModelConnection(
                connection,
                makeCurrent: true,
                now: Date(timeIntervalSince1970: 2_051)
            )

            XCTAssertThrowsError(
                try database.queue.write { db in
                    try db.execute(
                        sql: "DELETE FROM modelConnection WHERE id = ?",
                        arguments: [connection.id.uuidString]
                    )
                }
            )
            XCTAssertEqual(try database.currentModelConnection(), stored)
        }
    }

    private func makeConnection(id: UUID, credentialID: UUID) throws -> ModelConnection {
        try ModelConnection.make(
            id: id,
            name: "OpenAI",
            provider: .openAI,
            baseURL: URL(string: "https://api.openai.com/v1")!,
            credentialID: credentialID,
            selectedModel: "gpt-test"
        )
    }

    private func mutateJSONPayload(
        table: String,
        id: UUID,
        in database: AppDatabase,
        mutation: (inout [String: Any]) -> Void
    ) throws {
        try database.queue.write { db in
            let payload = try XCTUnwrap(
                String.fetchOne(
                    db,
                    sql: "SELECT payloadJSON FROM \(table) WHERE id = ?",
                    arguments: [id.uuidString]
                )
            )
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any]
            )
            mutation(&object)
            let tampered = try XCTUnwrap(
                String(
                    data: JSONSerialization.data(withJSONObject: object),
                    encoding: .utf8
                )
            )
            try db.execute(
                sql: "UPDATE \(table) SET payloadJSON = ? WHERE id = ?",
                arguments: [tampered, id.uuidString]
            )
        }
    }

    private func withTemporaryDatabase(_ body: (AppDatabase) throws -> Void) throws {
        try withTemporaryDatabasePath { path in
            try body(AppDatabase(path: path))
        }
    }

    private func withTemporaryDatabasePath(_ body: (String) throws -> Void) throws {
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
