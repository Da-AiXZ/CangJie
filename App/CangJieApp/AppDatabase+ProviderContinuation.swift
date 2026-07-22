import CangJieCore
import Foundation
import GRDB

struct ProviderContinuationCommitResult: Equatable {
    let request: ProviderRequestSnapshot
    let message: AgentMessage
    let receipt: ToolReceipt?
}

extension AppDatabase {
    func commitProviderContinuation(
        _ request: ProviderRequestSnapshot,
        now: Date = Date()
    ) throws -> ProviderContinuationCommitResult {
        try queue.write { db in
            guard let requestRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ?",
                arguments: [request.identity.requestID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let existing = try Self.decodeProviderRequest(requestRow)
            guard Self.sameProviderRequestIdentity(existing, request) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            if existing.phase == .continuationCommitted {
                return try Self.replayCommittedContinuation(existing, in: db)
            }
            guard existing.phase == .responseComplete else {
                throw AppDatabaseError.invalidProviderRequest
            }
            guard let responseHash = request.responseHash,
                  let assetRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM providerResponseAsset WHERE id = ?",
                    arguments: [request.responseAssetID.uuidString]
                  ) else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            let assetJSON: String = assetRow["payloadJSON"]
            let assetStoredHash: String = assetRow["payloadHash"]
            guard assetStoredHash == responseHash,
                  assetStoredHash == Self.payloadHash(assetJSON),
                  assetJSON.utf8.count == request.receivedUTF8Bytes else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            let payload = try Self.decodeProviderResponse(assetJSON)
            try payload.validate(allowIncompleteToolCalls: false)
            guard payload.toolCalls.isEmpty,
                  !payload.text.isEmpty else {
                throw AppDatabaseError.invalidProviderResponseAsset
            }
            let committed = try ProviderRequestLifecycle.commitContinuation(
                request,
                now: now
            )
            try Self.updateProviderRequestRow(
                committed,
                expectedPayloadHash: Self.payloadHash(
                    try Self.encodeProviderRequest(existing)
                ),
                in: db
            )
            try Self.completeProviderRun(
                committed,
                in: db
            )
            let message = try Self.insertOrReplayAssistantMessage(
                payload.text,
                conversationID: committed.identity.conversationID,
                idempotencyKey: "provider.response.\(committed.identity.requestID.uuidString)",
                now: now,
                in: db
            )
            try db.execute(
                sql: """
                    UPDATE pendingModelIntent
                    SET consumedAt = ?, continuationRequestID = ?
                    WHERE id = ? AND consumedAt IS NULL
                    """,
                arguments: [
                    now.timeIntervalSince1970,
                    committed.identity.requestID.uuidString,
                    committed.identity.intentID.uuidString
                ]
            )
            if db.changesCount != 1 {
                guard let intentRow = try Row.fetchOne(
                    db,
                    sql: "SELECT consumedAt, continuationRequestID FROM pendingModelIntent WHERE id = ?",
                    arguments: [committed.identity.intentID.uuidString]
                ) else {
                    throw AppDatabaseError.invalidPendingModelIntent
                }
                let continuationID: String? = intentRow["continuationRequestID"]
                guard continuationID == committed.identity.requestID.uuidString else {
                    throw AppDatabaseError.idempotencyConflict
                }
            }
            return ProviderContinuationCommitResult(
                request: committed,
                message: message,
                receipt: nil
            )
        }
    }

    private static func replayCommittedContinuation(
        _ request: ProviderRequestSnapshot,
        in db: Database
    ) throws -> ProviderContinuationCommitResult {
        let messageRow = try Row.fetchOne(
            db,
            sql: """
                SELECT * FROM agentMessage
                WHERE idempotencyKey = ? LIMIT 1
                """,
            arguments: [
                "provider.response.\(request.identity.requestID.uuidString)"
            ]
        )
        let message = messageRow.flatMap { row in
            decodeAgentMessage(row)
        }
        guard let message else {
            throw AppDatabaseError.invalidProviderRequest
        }
        return ProviderContinuationCommitResult(
            request: request,
            message: message,
            receipt: nil
        )
    }

    private static func completeProviderRun(
        _ request: ProviderRequestSnapshot,
        in db: Database
    ) throws {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentRun WHERE id = ? AND conversationID = ?",
            arguments: [
                request.identity.runID.uuidString,
                request.identity.conversationID.uuidString
            ]
        ) else {
            throw AppDatabaseError.invalidAgentRun
        }
        let existing = try decodeAgentRun(row)
        guard existing.kind == "providerTurn",
              existing.status == .running else {
            throw AppDatabaseError.invalidAgentRun
        }
        try upsertAgentRun(
            AgentRunSnapshot(
                id: existing.id,
                projectID: existing.projectID,
                kind: existing.kind,
                status: .completed,
                idempotencyKey: existing.idempotencyKey,
                currentStage: "provider.continuationCommitted",
                startedAt: existing.startedAt,
                updatedAt: request.updatedAt
            ),
            conversationID: request.identity.conversationID,
            in: db
        )
    }

    private static func insertOrReplayAssistantMessage(
        _ content: String,
        conversationID: UUID,
        idempotencyKey: String,
        now: Date,
        in db: Database
    ) throws -> AgentMessage {
        if let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentMessage WHERE idempotencyKey = ? LIMIT 1",
            arguments: [idempotencyKey]
        ) {
            guard let existing = decodeAgentMessage(row),
                  row["conversationID"] as String == conversationID.uuidString,
                  existing.role == .assistant,
                  existing.content == content else {
                throw AppDatabaseError.idempotencyConflict
            }
            return existing
        }
        let message = AgentMessage(
            id: UUID(),
            role: .assistant,
            content: content,
            createdAt: now
        )
        try db.execute(
            sql: """
                INSERT INTO agentMessage (
                    id, conversationID, role, content, idempotencyKey, createdAt
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                message.id.uuidString,
                conversationID.uuidString,
                message.role.rawValue,
                message.content,
                idempotencyKey,
                now.timeIntervalSince1970
            ]
        )
        try db.execute(
            sql: "UPDATE agentConversation SET updatedAt = ? WHERE id = ?",
            arguments: [now.timeIntervalSince1970, conversationID.uuidString]
        )
        return message
    }
}
