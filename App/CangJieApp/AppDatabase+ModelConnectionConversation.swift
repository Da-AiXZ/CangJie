import CangJieCore
import Foundation
import GRDB

struct ModelConnectionPendingIntentAppendResult {
    let conversation: AgentConversation
    let pendingIntent: PendingModelIntent
    let workspace: S1ConversationWorkspaceSnapshot
}

extension AppDatabase {
    /// Atomically binds a first model-dependent turn to a Conversation and its
    /// pending intent. No Provider request, usage, artifact, or ToolReceipt is
    /// created at this boundary.
    func appendPendingModelIntentTurn(
        selectedConversationID: UUID?,
        rawRequest: String,
        intentID: UUID,
        projectID: UUID? = nil,
        branchID: UUID? = nil,
        now: Date = Date()
    ) throws -> ModelConnectionPendingIntentAppendResult {
        let validatedTurn = try S1ConversationPreview.makeTurn(from: rawRequest)

        return try queue.write { db in
            if let existingRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM pendingModelIntent WHERE id = ?",
                arguments: [intentID.uuidString]
            ) {
                let existing = try Self.decodePendingModelIntent(existingRow)
                let durableSelectedID = try String.fetchOne(
                    db,
                    sql: "SELECT selectedConversationID FROM s1WorkspaceState WHERE id = 'default'"
                ).flatMap { UUID(uuidString: $0) }
                let selectedConversationMatches = selectedConversationID.map {
                    existing.conversationID == $0
                } ?? (durableSelectedID == existing.conversationID)
                let explicitProjectMatches = projectID.map {
                    existing.projectID == $0
                } ?? true
                guard existing.userRequest == validatedTurn.userText,
                      existing.branchID == branchID,
                      explicitProjectMatches,
                      selectedConversationMatches,
                      let conversationRow = try Row.fetchOne(
                        db,
                        sql: "SELECT * FROM agentConversation WHERE id = ?",
                        arguments: [existing.conversationID.uuidString]
                      ), let conversation = Self.decodeConversation(conversationRow) else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return ModelConnectionPendingIntentAppendResult(
                    conversation: conversation,
                    pendingIntent: existing,
                    workspace: try Self.s1ConversationWorkspaceSnapshot(in: db)
                )
            }

            try Self.requireCurrentS1WorkspaceSelection(selectedConversationID, in: db)

            let conversation: AgentConversation
            if let selectedConversationID {
                guard let row = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM agentConversation WHERE id = ?",
                    arguments: [selectedConversationID.uuidString]
                ), let restored = Self.decodeConversation(row) else {
                    throw AppDatabaseError.invalidAgentSession
                }
                conversation = restored
            } else {
                let created = AgentConversation(
                    id: UUID(),
                    title: "New conversation",
                    createdAt: now,
                    updatedAt: now
                )
                try db.execute(
                    sql: "INSERT INTO agentConversation (id, title, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
                    arguments: [
                        created.id.uuidString,
                        created.title,
                        created.createdAt.timeIntervalSince1970,
                        created.updatedAt.timeIntervalSince1970
                    ]
                )
                conversation = created
            }

            let existingPendingIntentCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM pendingModelIntent WHERE conversationID = ?",
                arguments: [conversation.id.uuidString]
            ) ?? 0
            guard existingPendingIntentCount == 0 else {
                throw AppDatabaseError.pendingModelIntentAlreadyExists
            }

            let persisted = try Self.persistConversationMessages(
                conversationID: conversation.id,
                currentTitle: conversation.title,
                userText: validatedTurn.userText,
                systemContent: ModelConnectionSetupConversationCopy.intentSaved,
                now: now,
                minimumTimestamp: conversation.updatedAt.timeIntervalSince1970,
                in: db
            )
            let effectiveDate = persisted.messages.last?.createdAt ?? now
            let updatedConversation = AgentConversation(
                id: conversation.id,
                title: persisted.conversationTitle,
                createdAt: conversation.createdAt,
                updatedAt: effectiveDate
            )
            let focusedProjectText = try String.fetchOne(
                db,
                sql: "SELECT focusedProjectID FROM agentSession WHERE conversationID = ?",
                arguments: [conversation.id.uuidString]
            )
            let focusedProjectID: UUID?
            if let focusedProjectText {
                guard let decoded = UUID(uuidString: focusedProjectText) else {
                    throw AppDatabaseError.invalidAgentSession
                }
                focusedProjectID = decoded
            } else {
                focusedProjectID = nil
            }
            if let projectID, let focusedProjectID, projectID != focusedProjectID {
                throw AppDatabaseError.invalidPendingModelIntent
            }
            let boundProjectID = projectID ?? focusedProjectID
            let pendingIntent = try PendingModelIntent(
                id: intentID,
                conversationID: conversation.id,
                projectID: boundProjectID,
                branchID: branchID,
                userRequest: validatedTurn.userText,
                createdAt: effectiveDate
            )

            try db.execute(
                sql: "DELETE FROM s1ConversationDraft WHERE conversationID = ?",
                arguments: [conversation.id.uuidString]
            )
            try db.execute(
                sql: """
                    UPDATE s1WorkspaceState
                    SET selectedConversationID = ?, unboundDraft = '', updatedAt = ?
                    WHERE id = 'default'
                    """,
                arguments: [conversation.id.uuidString, effectiveDate.timeIntervalSince1970]
            )
            try Self.upsertDraft("", now: effectiveDate, in: db)
            _ = try Self.storePendingModelIntent(pendingIntent, in: db)

            return ModelConnectionPendingIntentAppendResult(
                conversation: updatedConversation,
                pendingIntent: pendingIntent,
                workspace: try Self.s1ConversationWorkspaceSnapshot(in: db)
            )
        }
    }
}
