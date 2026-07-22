import CangJieCore
import CryptoKit
import Foundation
import GRDB

struct StoredModelConnection: Equatable {
    let connection: ModelConnection
    let createdAt: Date
    let updatedAt: Date
}

private struct LegacyModelCredentialReference: Decodable {
    let id: UUID
    let connectionID: UUID
    let provider: ModelProvider
    let allowedHost: String
    let allowedPort: Int?
}

private struct LegacyModelConnectionPayload: Decodable {
    let id: UUID
    let name: String
    let provider: ModelProvider
    let baseURL: URL
    let credential: LegacyModelCredentialReference
    let selectedModel: String
}

extension AppDatabase {
    private enum IdentityTable {
        case conversation
        case modelConnection
        case project
    }

    private static let modelConnectionPayloadVersion = 1
    private static let pendingModelIntentPayloadVersion = 1

    /// Persists immutable connection metadata only. Keychain presence, connection
    /// testing, model discovery, and Provider usability require separate evidence.
    func storeModelConnection(
        _ connection: ModelConnection,
        makeCurrent: Bool,
        now: Date = Date()
    ) throws -> StoredModelConnection {
        try queue.write { db in
            try Self.storeModelConnection(
                connection,
                makeCurrent: makeCurrent,
                now: now,
                in: db
            )
        }
    }

    static func storeModelConnection(
        _ connection: ModelConnection,
        makeCurrent: Bool,
        now: Date,
        in db: Database
    ) throws -> StoredModelConnection {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            throw AppDatabaseError.invalidModelConnection
        }
        if let existingRow = try Row.fetchOne(
            db,
            sql: "SELECT * FROM modelConnection WHERE id = ?",
            arguments: [connection.id.uuidString]
        ) {
            let existing = try Self.decodeStoredModelConnection(existingRow)
            guard existing.connection == connection else {
                throw AppDatabaseError.idempotencyConflict
            }
            // Replaying the immutable save must not overwrite a newer,
            // explicit current-connection selection. Call the dedicated
            // selection method for a new user choice.
            return existing
        }

        let reusedCredentialCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM modelConnection WHERE credentialID = ?",
            arguments: [connection.credential.id.uuidString]
        ) ?? 0
        guard reusedCredentialCount == 0 else {
            throw AppDatabaseError.idempotencyConflict
        }

        let payloadJSON = try Self.encodeModelConnection(connection)
        let payloadHash = Self.payloadHash(payloadJSON)
        try db.execute(
            sql: """
                INSERT INTO modelConnection (
                    id, credentialID, credentialVersionID, credentialProvider,
                    credentialAllowedHost, credentialAllowedPort, payloadVersion,
                    payloadJSON, payloadHash, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                connection.id.uuidString,
                connection.credential.id.uuidString,
                connection.credential.versionID.uuidString,
                connection.credential.provider.rawValue,
                connection.credential.allowedHost,
                connection.credential.allowedPort,
                Self.modelConnectionPayloadVersion,
                payloadJSON,
                payloadHash,
                now.timeIntervalSince1970,
                now.timeIntervalSince1970
            ]
        )
        if makeCurrent {
            try Self.selectCurrentModelConnection(
                id: connection.id,
                now: now,
                in: db
            )
        }
        return StoredModelConnection(
            connection: connection,
            createdAt: now,
            updatedAt: now
        )
    }

    func listModelConnections() throws -> [StoredModelConnection] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM modelConnection ORDER BY updatedAt DESC, rowid DESC"
            ).map(Self.decodeStoredModelConnection)
        }
    }

    /// Returns the explicitly selected metadata record, not proof that its
    /// credential exists or that the Provider is currently usable.
    func currentModelConnection() throws -> StoredModelConnection? {
        try queue.read { db in
            try Self.currentModelConnection(in: db)
        }
    }

    func selectCurrentModelConnection(id: UUID, now: Date = Date()) throws {
        try queue.write { db in
            try Self.selectCurrentModelConnection(id: id, now: now, in: db)
        }
    }

    func storePendingModelIntent(_ intent: PendingModelIntent) throws -> PendingModelIntent {
        try queue.write { db in
            if let existingRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM pendingModelIntent WHERE id = ?",
                arguments: [intent.id.uuidString]
            ) {
                let existing = try Self.decodePendingModelIntent(existingRow)
                guard existing == intent else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return existing
            }

            guard try Self.rowExists(
                table: .conversation,
                id: intent.conversationID,
                in: db
            ) else {
                throw AppDatabaseError.invalidPendingModelIntent
            }
            if let projectID = intent.projectID {
                guard try Self.rowExists(table: .project, id: projectID, in: db) else {
                    throw AppDatabaseError.invalidPendingModelIntent
                }
            }
            guard intent.createdAt.timeIntervalSinceReferenceDate.isFinite else {
                throw AppDatabaseError.invalidPendingModelIntent
            }

            let payloadJSON = try Self.encodePendingModelIntent(intent)
            let payloadHash = Self.payloadHash(payloadJSON)
            try db.execute(
                sql: """
                    INSERT INTO pendingModelIntent (
                        id, conversationID, projectID, branchID,
                        payloadVersion, payloadJSON, payloadHash, createdAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    intent.id.uuidString,
                    intent.conversationID.uuidString,
                    intent.projectID?.uuidString,
                    intent.branchID?.uuidString,
                    Self.pendingModelIntentPayloadVersion,
                    payloadJSON,
                    payloadHash,
                    intent.createdAt.timeIntervalSince1970
                ]
            )
            return intent
        }
    }

    func pendingModelIntent(id: UUID) throws -> PendingModelIntent? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM pendingModelIntent WHERE id = ?",
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try Self.decodePendingModelIntent(row)
        }
    }

    private static func selectCurrentModelConnection(
        id: UUID,
        now: Date,
        in db: Database
    ) throws {
        guard now.timeIntervalSinceReferenceDate.isFinite,
              try rowExists(table: .modelConnection, id: id, in: db) else {
            throw AppDatabaseError.invalidModelConnection
        }
        try db.execute(
            sql: """
                UPDATE modelConnectionState
                SET currentConnectionID = ?, updatedAt = ?
                WHERE id = 'default'
                """,
            arguments: [id.uuidString, now.timeIntervalSince1970]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.invalidModelConnection
        }
    }

    static func encodeModelConnection(_ connection: ModelConnection) throws -> String {
        do {
            return try encodeJSON(connection)
        } catch {
            throw AppDatabaseError.invalidModelConnection
        }
    }

    private static func encodePendingModelIntent(_ intent: PendingModelIntent) throws -> String {
        do {
            return try encodeJSON(intent)
        } catch {
            throw AppDatabaseError.invalidPendingModelIntent
        }
    }

    private static func encodeJSON<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppDatabaseError.invalidModelConnection
        }
        return json
    }

    static func decodeJSON<Value: Decodable>(
        _ type: Value.Type,
        from data: Data
    ) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(type, from: data)
    }

    static func payloadHash(_ payloadJSON: String) -> String {
        SHA256.hash(data: Data(payloadJSON.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func migrateLegacyModelConnection(
        _ row: Row
    ) throws -> (connection: ModelConnection, payloadJSON: String, payloadHash: String) {
        let rowID: String = row["id"]
        let credentialID: String = row["credentialID"]
        let credentialProvider: String = row["credentialProvider"]
        let credentialAllowedHost: String = row["credentialAllowedHost"]
        let credentialAllowedPort: Int? = row["credentialAllowedPort"]
        let payloadVersion: Int = row["payloadVersion"]
        let payloadJSON: String = row["payloadJSON"]
        let storedPayloadHash: String = row["payloadHash"]
        let createdAtValue: Double = row["createdAt"]
        let updatedAtValue: Double = row["updatedAt"]

        guard payloadVersion == modelConnectionPayloadVersion,
              storedPayloadHash == payloadHash(payloadJSON),
              createdAtValue.isFinite,
              updatedAtValue.isFinite,
              let data = payloadJSON.data(using: .utf8),
              let legacy = try? decodeJSON(
                LegacyModelConnectionPayload.self,
                from: data
              ),
              legacy.id.uuidString == rowID,
              legacy.credential.id.uuidString == credentialID,
              legacy.credential.connectionID == legacy.id,
              legacy.credential.provider == legacy.provider,
              legacy.credential.provider.rawValue == credentialProvider,
              legacy.credential.allowedHost == credentialAllowedHost,
              legacy.credential.allowedPort == credentialAllowedPort else {
            throw AppDatabaseError.invalidModelConnection
        }

        guard let rawObject = try? JSONSerialization.jsonObject(with: data),
              var object = rawObject as? [String: Any],
              var credential = object["credential"] as? [String: Any] else {
            throw AppDatabaseError.invalidModelConnection
        }
        credential["versionID"] = legacy.credential.id.uuidString
        object["credential"] = credential
        guard let migratedData = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        ),
              let connection = try? decodeJSON(
                ModelConnection.self,
                from: migratedData
              ),
              connection.id == legacy.id,
              connection.name == legacy.name,
              connection.provider == legacy.provider,
              connection.baseURL == legacy.baseURL,
              connection.selectedModel == legacy.selectedModel,
              connection.credential.allowedHost == legacy.credential.allowedHost,
              connection.credential.allowedPort == legacy.credential.allowedPort else {
            throw AppDatabaseError.invalidModelConnection
        }
        let migratedPayload = try encodeModelConnection(connection)
        return (
            connection: connection,
            payloadJSON: migratedPayload,
            payloadHash: payloadHash(migratedPayload)
        )
    }

    private static func decodeStoredModelConnection(_ row: Row) throws -> StoredModelConnection {
        let rowID: String = row["id"]
        let credentialID: String = row["credentialID"]
        let credentialVersionID: String = row["credentialVersionID"]
        let credentialProvider: String = row["credentialProvider"]
        let credentialAllowedHost: String = row["credentialAllowedHost"]
        let credentialAllowedPort: Int? = row["credentialAllowedPort"]
        let payloadVersion: Int = row["payloadVersion"]
        let payloadJSON: String = row["payloadJSON"]
        let storedPayloadHash: String = row["payloadHash"]
        let createdAtValue: Double = row["createdAt"]
        let updatedAtValue: Double = row["updatedAt"]

        guard payloadVersion == modelConnectionPayloadVersion,
              storedPayloadHash == payloadHash(payloadJSON),
              createdAtValue.isFinite,
              updatedAtValue.isFinite,
              let data = payloadJSON.data(using: .utf8),
              let connection = try? decodeJSON(ModelConnection.self, from: data),
              connection.id.uuidString == rowID,
              connection.credential.id.uuidString == credentialID,
              connection.credential.versionID.uuidString == credentialVersionID,
              connection.credential.provider.rawValue == credentialProvider,
              connection.credential.allowedHost == credentialAllowedHost,
              connection.credential.allowedPort == credentialAllowedPort else {
            throw AppDatabaseError.invalidModelConnection
        }
        return StoredModelConnection(
            connection: connection,
            createdAt: Date(timeIntervalSince1970: createdAtValue),
            updatedAt: Date(timeIntervalSince1970: updatedAtValue)
        )
    }

    private static func decodePendingModelIntent(_ row: Row) throws -> PendingModelIntent {
        let rowID: String = row["id"]
        let conversationID: String = row["conversationID"]
        let projectID: String? = row["projectID"]
        let branchID: String? = row["branchID"]
        let payloadVersion: Int = row["payloadVersion"]
        let payloadJSON: String = row["payloadJSON"]
        let storedPayloadHash: String = row["payloadHash"]
        let createdAtValue: Double = row["createdAt"]

        guard payloadVersion == pendingModelIntentPayloadVersion,
              storedPayloadHash == payloadHash(payloadJSON),
              createdAtValue.isFinite,
              let data = payloadJSON.data(using: .utf8),
              let intent = try? decodeJSON(PendingModelIntent.self, from: data),
              intent.id.uuidString == rowID,
              intent.conversationID.uuidString == conversationID,
              intent.projectID?.uuidString == projectID,
              intent.branchID?.uuidString == branchID,
              intent.createdAt == Date(timeIntervalSince1970: createdAtValue) else {
            throw AppDatabaseError.invalidPendingModelIntent
        }
        return intent
    }

    private static func currentModelConnection(in db: Database) throws -> StoredModelConnection? {
        guard let state = try Row.fetchOne(
            db,
            sql: "SELECT currentConnectionID FROM modelConnectionState WHERE id = 'default'"
        ) else {
            throw AppDatabaseError.invalidModelConnection
        }
        let currentConnectionID: String? = state["currentConnectionID"]
        guard let currentConnectionID else { return nil }
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM modelConnection WHERE id = ?",
            arguments: [currentConnectionID]
        ) else {
            throw AppDatabaseError.invalidModelConnection
        }
        return try decodeStoredModelConnection(row)
    }

    private static func rowExists(
        table: IdentityTable,
        id: UUID,
        in db: Database
    ) throws -> Bool {
        let sql: String
        switch table {
        case .conversation:
            sql = "SELECT COUNT(*) FROM agentConversation WHERE id = ?"
        case .modelConnection:
            sql = "SELECT COUNT(*) FROM modelConnection WHERE id = ?"
        case .project:
            sql = "SELECT COUNT(*) FROM novelProject WHERE id = ?"
        }
        return try Int.fetchOne(
            db,
            sql: sql,
            arguments: [id.uuidString]
        ) == 1
    }
}
