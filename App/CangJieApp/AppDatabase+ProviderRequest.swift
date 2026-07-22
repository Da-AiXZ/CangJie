import CangJieCore
import Foundation
import GRDB

struct ProviderToolCallPayload: Codable, Equatable {
    let index: Int
    let id: String
    let name: String
    let argumentsJSON: String
}

struct ProviderResponsePayload: Codable, Equatable {
    static let emptyJSON = #"{"finishReason":null,"text":"","toolCalls":[]}"#
    static let maximumUTF8Bytes = 256 * 1_024
    static let maximumToolCalls = 8
    static let maximumToolArgumentsUTF8Bytes = 64 * 1_024

    let text: String
    let toolCalls: [ProviderToolCallPayload]
    let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case finishReason
        case text
        case toolCalls
    }

    init(
        text: String,
        toolCalls: [ProviderToolCallPayload],
        finishReason: String?
    ) {
        self.text = text
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let finishReason {
            try container.encode(finishReason, forKey: .finishReason)
        } else {
            try container.encodeNil(forKey: .finishReason)
        }
        try container.encode(text, forKey: .text)
        try container.encode(toolCalls, forKey: .toolCalls)
    }

    func validate() throws {
        guard toolCalls.count <= Self.maximumToolCalls,
              text.utf8.count <= Self.maximumUTF8Bytes,
              toolCalls.enumerated().allSatisfy({ offset, call in
                  call.index == offset
                      && !call.id.isEmpty
                      && call.id.utf8.count <= 512
                      && !call.name.isEmpty
                      && call.name.utf8.count <= 256
                      && call.argumentsJSON.utf8.count
                          <= Self.maximumToolArgumentsUTF8Bytes
              }) else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
    }
}

extension AppDatabase {
    private static let providerRequestPayloadVersion = 1
    private static let providerResponsePayloadVersion = 1

    func persistPreparedProviderRequest(
        _ request: ProviderRequestSnapshot,
        verifiedConnection: VerifiedModelConnection
    ) throws -> ProviderRequestSnapshot {
        let validated = try Self.validatedProviderRequest(request)
        guard validated.phase == .prepared,
              Self.requestIdentity(
                validated.identity,
                matches: verifiedConnection
              ) else {
            throw AppDatabaseError.invalidProviderRequest
        }

        return try queue.write { db in
            guard let intentRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM pendingModelIntent WHERE id = ? AND consumedAt IS NULL",
                arguments: [validated.identity.intentID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let intent = try Self.decodePendingModelIntent(intentRow)
            guard intent.conversationID == validated.identity.conversationID,
                  intent.projectID == validated.identity.projectID,
                  intent.branchID == validated.identity.branchID else {
                throw AppDatabaseError.invalidProviderRequest
            }

            guard let current = try Self.currentModelConnection(in: db),
                  current.connection == verifiedConnection.connection else {
                throw AppDatabaseError.invalidProviderRequest
            }

            if let existingRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ? OR intentID = ? LIMIT 1",
                arguments: [
                    validated.identity.requestID.uuidString,
                    validated.identity.intentID.uuidString
                ]
            ) {
                let existing = try Self.decodeProviderRequest(existingRow)
                guard existing == validated else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return existing
            }

            let run = AgentRunSnapshot(
                id: validated.identity.runID,
                projectID: validated.identity.projectID,
                kind: "providerTurn",
                status: .running,
                idempotencyKey: "agent.run.\(validated.identity.intentID.uuidString)",
                currentStage: "provider.prepared",
                startedAt: validated.createdAt,
                updatedAt: validated.updatedAt
            )
            try Self.upsertAgentRun(
                run,
                conversationID: validated.identity.conversationID,
                in: db
            )

            let emptyResponseHash = Self.payloadHash(
                ProviderResponsePayload.emptyJSON
            )
            try db.execute(
                sql: """
                    INSERT INTO providerResponseAsset (
                        id, payloadVersion, payloadJSON, payloadHash,
                        createdAt, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    validated.responseAssetID.uuidString,
                    Self.providerResponsePayloadVersion,
                    ProviderResponsePayload.emptyJSON,
                    emptyResponseHash,
                    validated.createdAt.timeIntervalSince1970,
                    validated.updatedAt.timeIntervalSince1970
                ]
            )
            try Self.insertProviderRequest(validated, in: db)
            return validated
        }
    }

    func providerRequest(id: UUID) throws -> ProviderRequestSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ?",
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try Self.decodeProviderRequest(row)
        }
    }

    func providerRequest(intentID: UUID) throws -> ProviderRequestSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE intentID = ?",
                arguments: [intentID.uuidString]
            ) else {
                return nil
            }
            return try Self.decodeProviderRequest(row)
        }
    }

    func updateProviderRequest(_ request: ProviderRequestSnapshot) throws {
        let validated = try Self.validatedProviderRequest(request)
        guard validated.phase != .responseComplete,
              validated.phase != .continuationCommitted else {
            throw AppDatabaseError.invalidProviderRequest
        }
        try queue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ?",
                arguments: [validated.identity.requestID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let existing = try Self.decodeProviderRequest(row)
            guard Self.sameProviderRequestIdentity(existing, validated),
                  existing.phase != validated.phase else {
                throw AppDatabaseError.invalidProviderRequest
            }
            do {
                try ProviderRequestLifecycle.validateTransition(
                    from: existing,
                    to: validated
                )
            } catch {
                throw AppDatabaseError.invalidProviderRequest
            }
            try Self.updateProviderRequestRow(
                validated,
                expectedPayloadHash: Self.payloadHash(
                    try Self.encodeProviderRequest(existing)
                ),
                in: db
            )
        }
    }

    func completeProviderResponse(
        _ request: ProviderRequestSnapshot
    ) throws {
        let validated = try Self.validatedProviderRequest(request)
        guard validated.phase == .responseComplete,
              let expectedResponseHash = validated.responseHash else {
            throw AppDatabaseError.invalidProviderRequest
        }
        try queue.write { db in
            guard let requestRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ?",
                arguments: [validated.identity.requestID.uuidString]
            ), let assetRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerResponseAsset WHERE id = ?",
                arguments: [validated.responseAssetID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let existing = try Self.decodeProviderRequest(requestRow)
            let assetVersion: Int = assetRow["payloadVersion"]
            let assetJSON: String = assetRow["payloadJSON"]
            let assetHash: String = assetRow["payloadHash"]
            guard existing.phase == .streaming,
                  Self.sameProviderRequestIdentity(existing, validated),
                  assetVersion == Self.providerResponsePayloadVersion,
                  assetHash == Self.payloadHash(assetJSON),
                  assetHash == expectedResponseHash,
                  assetJSON.utf8.count == validated.receivedUTF8Bytes else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            let payload = try Self.decodeProviderResponse(assetJSON)
            try payload.validate()
            do {
                try ProviderRequestLifecycle.validateTransition(
                    from: existing,
                    to: validated
                )
            } catch {
                throw AppDatabaseError.invalidProviderRequest
            }
            try Self.updateProviderRequestRow(
                validated,
                expectedPayloadHash: Self.payloadHash(
                    try Self.encodeProviderRequest(existing)
                ),
                in: db
            )
        }
    }

    func checkpointProviderResponse(
        _ request: ProviderRequestSnapshot,
        responsePayloadJSON: String
    ) throws {
        let validated = try Self.validatedProviderRequest(request)
        let payload = try Self.decodeProviderResponse(responsePayloadJSON)
        try payload.validate()
        let responseHash = Self.payloadHash(responsePayloadJSON)
        guard validated.phase == .streaming,
              validated.responseHash == responseHash,
              validated.receivedUTF8Bytes == responsePayloadJSON.utf8.count else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }

        try queue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ?",
                arguments: [validated.identity.requestID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let existing = try Self.decodeProviderRequest(row)
            guard Self.sameProviderRequestIdentity(existing, validated),
                  existing.phase == .sending || existing.phase == .streaming,
                  validated.streamCursor > existing.streamCursor else {
                throw AppDatabaseError.invalidProviderRequest
            }
            do {
                try ProviderRequestLifecycle.validateTransition(
                    from: existing,
                    to: validated
                )
            } catch {
                throw AppDatabaseError.invalidProviderRequest
            }
            try db.execute(
                sql: """
                    UPDATE providerResponseAsset
                    SET payloadJSON = ?, payloadHash = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [
                    responsePayloadJSON,
                    responseHash,
                    validated.updatedAt.timeIntervalSince1970,
                    validated.responseAssetID.uuidString
                ]
            )
            guard db.changesCount == 1 else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            try Self.updateProviderRequestRow(
                validated,
                expectedPayloadHash: Self.payloadHash(
                    try Self.encodeProviderRequest(existing)
                ),
                in: db
            )
        }
    }

    func providerResponsePayload(assetID: UUID) throws -> String? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerResponseAsset WHERE id = ?",
                arguments: [assetID.uuidString]
            ) else {
                return nil
            }
            let version: Int = row["payloadVersion"]
            let json: String = row["payloadJSON"]
            let storedHash: String = row["payloadHash"]
            guard version == Self.providerResponsePayloadVersion,
                  storedHash == Self.payloadHash(json) else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            let payload = try Self.decodeProviderResponse(json)
            try payload.validate()
            return json
        }
    }

    private static func insertProviderRequest(
        _ request: ProviderRequestSnapshot,
        in db: Database
    ) throws {
        let payloadJSON = try encodeProviderRequest(request)
        try db.execute(
            sql: """
                INSERT INTO providerRequest (
                    id, idempotencyKey, intentID, conversationID, projectID,
                    runID, connectionID, responseAssetID, phase,
                    payloadVersion, payloadJSON, payloadHash, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                request.identity.requestID.uuidString,
                request.identity.idempotencyKey,
                request.identity.intentID.uuidString,
                request.identity.conversationID.uuidString,
                request.identity.projectID?.uuidString,
                request.identity.runID.uuidString,
                request.identity.connectionID.uuidString,
                request.responseAssetID.uuidString,
                request.phase.rawValue,
                providerRequestPayloadVersion,
                payloadJSON,
                payloadHash(payloadJSON),
                request.createdAt.timeIntervalSince1970,
                request.updatedAt.timeIntervalSince1970
            ]
        )
    }

    private static func updateProviderRequestRow(
        _ request: ProviderRequestSnapshot,
        expectedPayloadHash: String,
        in db: Database
    ) throws {
        let payloadJSON = try encodeProviderRequest(request)
        try db.execute(
            sql: """
                UPDATE providerRequest
                SET phase = ?, payloadJSON = ?, payloadHash = ?, updatedAt = ?
                WHERE id = ? AND payloadHash = ?
                """,
            arguments: [
                request.phase.rawValue,
                payloadJSON,
                payloadHash(payloadJSON),
                request.updatedAt.timeIntervalSince1970,
                request.identity.requestID.uuidString,
                expectedPayloadHash
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.idempotencyConflict
        }
    }

    private static func decodeProviderRequest(
        _ row: Row
    ) throws -> ProviderRequestSnapshot {
        let version: Int = row["payloadVersion"]
        let payloadJSON: String = row["payloadJSON"]
        let storedHash: String = row["payloadHash"]
        guard version == providerRequestPayloadVersion,
              storedHash == payloadHash(payloadJSON),
              let data = payloadJSON.data(using: .utf8) else {
            throw AppDatabaseError.invalidProviderRequest
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let request = try? decoder.decode(
            ProviderRequestSnapshot.self,
            from: data
        ) else {
            throw AppDatabaseError.invalidProviderRequest
        }
        let id: String = row["id"]
        let idempotencyKey: String = row["idempotencyKey"]
        let intentID: String = row["intentID"]
        let conversationID: String = row["conversationID"]
        let projectID: String? = row["projectID"]
        let runID: String = row["runID"]
        let connectionID: String = row["connectionID"]
        let responseAssetID: String = row["responseAssetID"]
        let phase: String = row["phase"]
        let createdAt: Double = row["createdAt"]
        let updatedAt: Double = row["updatedAt"]
        guard id == request.identity.requestID.uuidString,
              idempotencyKey == request.identity.idempotencyKey,
              intentID == request.identity.intentID.uuidString,
              conversationID == request.identity.conversationID.uuidString,
              projectID == request.identity.projectID?.uuidString,
              runID == request.identity.runID.uuidString,
              connectionID == request.identity.connectionID.uuidString,
              responseAssetID == request.responseAssetID.uuidString,
              phase == request.phase.rawValue,
              createdAt == request.createdAt.timeIntervalSince1970,
              updatedAt == request.updatedAt.timeIntervalSince1970 else {
            throw AppDatabaseError.invalidProviderRequest
        }
        return request
    }

    private static func encodeProviderRequest(
        _ request: ProviderRequestSnapshot
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(request)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppDatabaseError.invalidProviderRequest
        }
        return json
    }

    private static func validatedProviderRequest(
        _ request: ProviderRequestSnapshot
    ) throws -> ProviderRequestSnapshot {
        let json = try encodeProviderRequest(request)
        guard let data = json.data(using: .utf8) else {
            throw AppDatabaseError.invalidProviderRequest
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decoded = try? decoder.decode(
            ProviderRequestSnapshot.self,
            from: data
        ), decoded == request else {
            throw AppDatabaseError.invalidProviderRequest
        }
        return decoded
    }

    private static func requestIdentity(
        _ identity: ProviderRequestIdentity,
        matches verified: VerifiedModelConnection
    ) -> Bool {
        let connection = verified.connection
        let evidence = verified.credentialVerification
        return identity.connectionID == connection.id
            && identity.provider == connection.provider
            && identity.baseURL == connection.baseURL
            && identity.modelID == connection.selectedModel
            && identity.credentialID == evidence.credentialID
            && identity.credentialVersionID == evidence.versionID
            && identity.credentialVersionProof == evidence.credentialVersionProof
            && identity.credentialPayloadHash == evidence.credentialPayloadHash
            && identity.setupAuthorizationHash == evidence.setupAuthorizationHash
    }

    private static func sameProviderRequestIdentity(
        _ lhs: ProviderRequestSnapshot,
        _ rhs: ProviderRequestSnapshot
    ) -> Bool {
        lhs.identity == rhs.identity
            && lhs.responseAssetID == rhs.responseAssetID
            && lhs.promptManifestHash == rhs.promptManifestHash
            && lhs.contextManifestHash == rhs.contextManifestHash
            && lhs.toolCatalogManifestHash == rhs.toolCatalogManifestHash
            && lhs.disclosureScopeHash == rhs.disclosureScopeHash
            && lhs.requestPolicyHash == rhs.requestPolicyHash
            && lhs.createdAt == rhs.createdAt
    }

    private static func decodeProviderResponse(
        _ json: String
    ) throws -> ProviderResponsePayload {
        guard json.utf8.count <= ProviderResponsePayload.maximumUTF8Bytes,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(
                ProviderResponsePayload.self,
                from: data
              ) else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let canonicalData = try? encoder.encode(decoded),
              String(data: canonicalData, encoding: .utf8) == json else {
            throw AppDatabaseError.invalidProviderResponseAsset
        }
        return decoded
    }
}
