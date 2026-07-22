import CangJieCore
import Foundation
import GRDB

struct PendingModelConnectionSetup: Equatable {
    let connection: ModelConnection
    let credentialVersionID: UUID
    // Independent random activation evidence; never derived from the secret.
    let credentialVersionProof: String
    let makeCurrent: Bool
    let createdAt: Date
    let setupAuthorizationHash: String

    func matches(_ binding: ModelDiscoveryCredentialBinding) -> Bool {
        connection.credential.versionID == credentialVersionID
            && binding.connectionID == connection.id
            && binding.credentialID == connection.credential.id
            && binding.provider == connection.provider
            && binding.baseURL == connection.baseURL
            && binding.versionID == credentialVersionID
            && binding.versionProof == credentialVersionProof
    }

    func matches(_ verifiedConnection: VerifiedModelConnection) -> Bool {
        let verification = verifiedConnection.credentialVerification
        return verifiedConnection.connection == connection
            && verification.versionID == credentialVersionID
            && verification.credentialVersionProof == credentialVersionProof
            && verification.setupAuthorizationHash == setupAuthorizationHash
    }
}

enum ModelConnectionSetupStage: Equatable {
    case inserted(PendingModelConnectionSetup)
    case replayed(PendingModelConnectionSetup)

    var pending: PendingModelConnectionSetup {
        switch self {
        case let .inserted(pending), let .replayed(pending):
            return pending
        }
    }
}

extension AppDatabase {
    private static let modelConnectionSetupJournalPayloadVersion = 1

    func stageModelConnectionSetup(
        _ connection: ModelConnection,
        credentialBinding: ModelDiscoveryCredentialBinding,
        makeCurrent: Bool,
        now: Date = Date()
    ) throws -> ModelConnectionSetupStage {
        try queue.write { db in
            let createdAtValue = now.timeIntervalSince1970
            guard createdAtValue.isFinite else {
                throw AppDatabaseError.invalidModelConnectionSetupJournal
            }

            if let existingRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM modelConnectionSetupJournal WHERE connectionID = ?",
                arguments: [connection.id.uuidString]
            ) {
                let existing = try Self.decodePendingModelConnectionSetup(existingRow)
                guard existing.connection == connection,
                      existing.matches(credentialBinding),
                      existing.makeCurrent == makeCurrent else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return .replayed(existing)
            }

            let existingConnectionCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM modelConnection WHERE id = ? OR credentialID = ?",
                arguments: [
                    connection.id.uuidString,
                    connection.credential.id.uuidString
                ]
            ) ?? 0
            let reusedJournalCredentialCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM modelConnectionSetupJournal WHERE credentialID = ?",
                arguments: [connection.credential.id.uuidString]
            ) ?? 0
            guard existingConnectionCount == 0,
                  reusedJournalCredentialCount == 0 else {
                throw AppDatabaseError.idempotencyConflict
            }

            let payloadJSON = try Self.encodeModelConnection(connection)
            let setupAuthorizationHash = Self.modelConnectionSetupJournalHash(
                connectionID: connection.id.uuidString,
                credentialID: connection.credential.id.uuidString,
                credentialVersionID: credentialBinding.versionID.uuidString,
                credentialVersionProof: credentialBinding.versionProof,
                makeCurrent: makeCurrent,
                payloadJSON: payloadJSON,
                createdAt: createdAtValue
            )
            let pending = PendingModelConnectionSetup(
                connection: connection,
                credentialVersionID: credentialBinding.versionID,
                credentialVersionProof: credentialBinding.versionProof,
                makeCurrent: makeCurrent,
                createdAt: Date(timeIntervalSince1970: createdAtValue),
                setupAuthorizationHash: setupAuthorizationHash
            )
            guard pending.matches(credentialBinding) else {
                throw AppDatabaseError.invalidModelConnectionSetupJournal
            }
            try db.execute(
                sql: """
                    INSERT INTO modelConnectionSetupJournal (
                        connectionID, credentialID, credentialVersionID, credentialVersionProof,
                        makeCurrent, payloadVersion, payloadJSON, payloadHash, createdAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    connection.id.uuidString,
                    connection.credential.id.uuidString,
                    credentialBinding.versionID.uuidString,
                    credentialBinding.versionProof,
                    makeCurrent,
                    Self.modelConnectionSetupJournalPayloadVersion,
                    payloadJSON,
                    setupAuthorizationHash,
                    createdAtValue
                ]
            )
            return .inserted(pending)
        }
    }

    func commitModelConnectionSetup(
        _ connection: ModelConnection,
        credentialBinding: ModelDiscoveryCredentialBinding,
        expectedMakeCurrent: Bool,
        now: Date = Date()
    ) throws -> StoredModelConnection {
        try queue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM modelConnectionSetupJournal WHERE connectionID = ?",
                arguments: [connection.id.uuidString]
            ) else {
                throw AppDatabaseError.invalidModelConnectionSetupJournal
            }
            let pending = try Self.decodePendingModelConnectionSetup(row)
            guard pending.connection == connection,
                  pending.matches(credentialBinding),
                  pending.makeCurrent == expectedMakeCurrent else {
                throw AppDatabaseError.invalidModelConnectionSetupJournal
            }
            return try Self.commitPendingModelConnectionSetup(
                pending,
                now: now,
                in: db
            )
        }
    }

    func commitModelConnectionSetup(
        _ pending: PendingModelConnectionSetup,
        now: Date = Date()
    ) throws -> StoredModelConnection {
        try queue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM modelConnectionSetupJournal WHERE connectionID = ?",
                arguments: [pending.connection.id.uuidString]
            ) else {
                throw AppDatabaseError.invalidModelConnectionSetupJournal
            }
            let storedPending = try Self.decodePendingModelConnectionSetup(row)
            guard storedPending.setupAuthorizationHash
                    == pending.setupAuthorizationHash else {
                throw AppDatabaseError.idempotencyConflict
            }
            return try Self.commitPendingModelConnectionSetup(
                storedPending,
                now: now,
                in: db
            )
        }
    }

    func pendingModelConnectionSetups() throws -> [PendingModelConnectionSetup] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM modelConnectionSetupJournal ORDER BY createdAt, rowid"
            ).map(Self.decodePendingModelConnectionSetup)
        }
    }

    func discardModelConnectionSetup(
        _ pending: PendingModelConnectionSetup
    ) throws {
        try queue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM modelConnectionSetupJournal WHERE connectionID = ?",
                arguments: [pending.connection.id.uuidString]
            ) else {
                return
            }
            let stored = try Self.decodePendingModelConnectionSetup(row)
            guard stored.setupAuthorizationHash
                    == pending.setupAuthorizationHash else {
                throw AppDatabaseError.idempotencyConflict
            }
            try db.execute(
                sql: "DELETE FROM modelConnectionSetupJournal WHERE connectionID = ?",
                arguments: [pending.connection.id.uuidString]
            )
            guard db.changesCount == 1 else {
                throw AppDatabaseError.invalidModelConnectionSetupJournal
            }
        }
    }

    private static func decodePendingModelConnectionSetup(
        _ row: Row
    ) throws -> PendingModelConnectionSetup {
        let connectionID: String = row["connectionID"]
        let credentialID: String = row["credentialID"]
        let credentialVersionID: String = row["credentialVersionID"]
        let credentialVersionProof: String = row["credentialVersionProof"]
        let makeCurrentValue: Int = row["makeCurrent"]
        let payloadVersion: Int = row["payloadVersion"]
        let payloadJSON: String = row["payloadJSON"]
        let storedPayloadHash: String = row["payloadHash"]
        let createdAtValue: Double = row["createdAt"]

        guard payloadVersion == modelConnectionSetupJournalPayloadVersion,
              storedPayloadHash == modelConnectionSetupJournalHash(
                connectionID: connectionID,
                credentialID: credentialID,
                credentialVersionID: credentialVersionID,
                credentialVersionProof: credentialVersionProof,
                makeCurrent: makeCurrentValue == 1,
                payloadJSON: payloadJSON,
                createdAt: createdAtValue
              ),
              (makeCurrentValue == 0 || makeCurrentValue == 1),
              createdAtValue.isFinite,
              isCanonicalCredentialVersionProof(credentialVersionProof),
              let versionID = UUID(uuidString: credentialVersionID),
              let data = payloadJSON.data(using: .utf8),
              let connection = try? decodeJSON(ModelConnection.self, from: data),
              connection.id.uuidString == connectionID,
              connection.credential.id.uuidString == credentialID,
              connection.credential.versionID == versionID else {
            throw AppDatabaseError.invalidModelConnectionSetupJournal
        }
        return PendingModelConnectionSetup(
            connection: connection,
            credentialVersionID: versionID,
            credentialVersionProof: credentialVersionProof,
            makeCurrent: makeCurrentValue == 1,
            createdAt: Date(timeIntervalSince1970: createdAtValue),
            setupAuthorizationHash: storedPayloadHash
        )
    }

    private static func commitPendingModelConnectionSetup(
        _ pending: PendingModelConnectionSetup,
        now: Date,
        in db: Database
    ) throws -> StoredModelConnection {
        let stored = try storeModelConnection(
            pending.connection,
            makeCurrent: pending.makeCurrent,
            now: now,
            in: db
        )
        try db.execute(
            sql: "DELETE FROM modelConnectionSetupJournal WHERE connectionID = ?",
            arguments: [pending.connection.id.uuidString]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.invalidModelConnectionSetupJournal
        }
        return stored
    }

    private static func modelConnectionSetupJournalHash(
        connectionID: String,
        credentialID: String,
        credentialVersionID: String,
        credentialVersionProof: String,
        makeCurrent: Bool,
        payloadJSON: String,
        createdAt: Double
    ) -> String {
        payloadHash(
            [
                "cangjie-model-connection-setup-journal-v1",
                connectionID,
                credentialID,
                credentialVersionID,
                credentialVersionProof,
                makeCurrent ? "1" : "0",
                String(modelConnectionSetupJournalPayloadVersion),
                String(createdAt.bitPattern, radix: 16),
                payloadJSON
            ].joined(separator: "\u{0}")
        )
    }

    private static func isCanonicalCredentialVersionProof(
        _ proof: String
    ) -> Bool {
        proof.utf8.count == 64 && proof.utf8.allSatisfy { byte in
            switch byte {
            case 0x30...0x39, 0x61...0x66:
                return true
            default:
                return false
            }
        }
    }
}
