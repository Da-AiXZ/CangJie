import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    func restoreS1ConversationWorkspace() throws -> S1ConversationWorkspaceSnapshot {
        try queue.read { db in
            try Self.s1ConversationWorkspaceSnapshot(in: db)
        }
    }

    func saveS1ConversationDraft(
        _ content: String,
        selectedConversationID: UUID?,
        now: Date = Date()
    ) throws {
        guard content.utf8.count <= S1ConversationPreview.maximumDraftUTF8Bytes else {
            throw AppDatabaseError.draftInputLimitExceeded
        }

        try queue.write { db in
            try Self.requireCurrentS1WorkspaceSelection(selectedConversationID, in: db)
            if let selectedConversationID {
                try db.execute(
                    sql: """
                        INSERT INTO s1ConversationDraft (conversationID, content, updatedAt)
                        VALUES (?, ?, ?)
                        ON CONFLICT(conversationID) DO UPDATE SET
                            content = excluded.content,
                            updatedAt = excluded.updatedAt
                        """,
                    arguments: [
                        selectedConversationID.uuidString,
                        content,
                        now.timeIntervalSince1970
                    ]
                )
            } else {
                try db.execute(
                    sql: """
                        UPDATE s1WorkspaceState
                        SET unboundDraft = ?, updatedAt = ?
                        WHERE id = 'default'
                        """,
                    arguments: [content, now.timeIntervalSince1970]
                )
            }
            // Compatibility mirror only. S1 workspace tables are the source of truth.
            try Self.upsertDraft(content, now: now, in: db)
        }
    }

    func selectNewS1Conversation(
        now: Date = Date()
    ) throws -> S1ConversationWorkspaceSnapshot {
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE s1WorkspaceState
                    SET selectedConversationID = NULL, updatedAt = ?
                    WHERE id = 'default'
                    """,
                arguments: [now.timeIntervalSince1970]
            )
            return try Self.s1ConversationWorkspaceSnapshot(in: db)
        }
    }

    func selectS1Conversation(
        _ conversationID: UUID,
        now: Date = Date()
    ) throws -> S1ConversationWorkspaceSnapshot {
        try queue.write { db in
            guard try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM agentConversation WHERE id = ?",
                arguments: [conversationID.uuidString]
            ) == 1 else {
                throw AppDatabaseError.invalidAgentSession
            }
            try db.execute(
                sql: """
                    UPDATE s1WorkspaceState
                    SET selectedConversationID = ?, updatedAt = ?
                    WHERE id = 'default'
                    """,
                arguments: [conversationID.uuidString, now.timeIntervalSince1970]
            )
            return try Self.s1ConversationWorkspaceSnapshot(in: db)
        }
    }

    func appendS1WorkspacePreviewTurn(
        selectedConversationID: UUID?,
        turn: S1ConversationPreviewTurn,
        now: Date = Date()
    ) throws -> S1PreviewConversationAppendResult {
        let validatedTurn = try Self.validateS1PreviewTurn(turn)

        return try queue.write { db in
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
                conversation = AgentConversation(
                    id: UUID(),
                    title: "New conversation",
                    createdAt: now,
                    updatedAt: now
                )
                try db.execute(
                    sql: "INSERT INTO agentConversation (id, title, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
                    arguments: [
                        conversation.id.uuidString,
                        conversation.title,
                        conversation.createdAt.timeIntervalSince1970,
                        conversation.updatedAt.timeIntervalSince1970
                    ]
                )
            }

            let persistedTurn = try Self.persistS1PreviewTurn(
                conversationID: conversation.id,
                currentTitle: conversation.title,
                turn: validatedTurn,
                now: now,
                minimumTimestamp: conversation.updatedAt.timeIntervalSince1970,
                in: db
            )
            let updatedConversation = AgentConversation(
                id: conversation.id,
                title: persistedTurn.conversationTitle,
                createdAt: conversation.createdAt,
                updatedAt: persistedTurn.messages.last?.createdAt ?? conversation.updatedAt
            )

            try db.execute(
                sql: "DELETE FROM s1ConversationDraft WHERE conversationID = ?",
                arguments: [conversation.id.uuidString]
            )
            if selectedConversationID == nil {
                try db.execute(
                    sql: """
                        UPDATE s1WorkspaceState
                        SET selectedConversationID = ?, unboundDraft = '', updatedAt = ?
                        WHERE id = 'default'
                        """,
                    arguments: [conversation.id.uuidString, updatedConversation.updatedAt.timeIntervalSince1970]
                )
            } else {
                try db.execute(
                    sql: """
                        UPDATE s1WorkspaceState
                        SET selectedConversationID = ?, updatedAt = ?
                        WHERE id = 'default'
                        """,
                    arguments: [conversation.id.uuidString, updatedConversation.updatedAt.timeIntervalSince1970]
                )
            }
            // Keep the retired m0 slot as a compatibility mirror until legacy callers are removed.
            try Self.upsertDraft("", now: updatedConversation.updatedAt, in: db)
            let workspace = try Self.s1ConversationWorkspaceSnapshot(in: db)

            return S1PreviewConversationAppendResult(
                conversation: updatedConversation,
                messages: persistedTurn.messages,
                workspace: workspace
            )
        }
    }

    func appendS1PreviewTurn(
        conversationID: UUID,
        turn: S1ConversationPreviewTurn,
        now: Date = Date()
    ) throws -> [AgentMessage] {
        let validatedTurn = try Self.validateS1PreviewTurn(turn)

        return try queue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT title, updatedAt FROM agentConversation WHERE id = ?",
                arguments: [conversationID.uuidString]
            ) else {
                throw AppDatabaseError.invalidAgentSession
            }
            let conversationTitle: String = row["title"]
            let conversationUpdatedAt: Double = row["updatedAt"]

            return try Self.persistS1PreviewTurn(
                conversationID: conversationID,
                currentTitle: conversationTitle,
                turn: validatedTurn,
                now: now,
                minimumTimestamp: conversationUpdatedAt,
                in: db
            ).messages
        }
    }

    private static func validateS1PreviewTurn(
        _ turn: S1ConversationPreviewTurn
    ) throws -> S1ConversationPreviewTurn {
        let validatedTurn = try S1ConversationPreview.makeTurn(from: turn.userText)
        guard validatedTurn == turn else {
            throw AppDatabaseError.invalidS1PreviewTurn
        }
        return validatedTurn
    }

    struct PersistedConversationTurn {
        let messages: [AgentMessage]
        let conversationTitle: String
    }

    static func persistConversationMessages(
        conversationID: UUID,
        currentTitle: String,
        userText: String,
        systemContent: String,
        now: Date,
        minimumTimestamp: TimeInterval,
        in db: Database
    ) throws -> PersistedConversationTurn {
        let existingMessageCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM agentMessage WHERE conversationID = ?",
            arguments: [conversationID.uuidString]
        ) ?? 0
        let latestCreatedAt = try Double.fetchOne(
            db,
            sql: "SELECT MAX(createdAt) FROM agentMessage WHERE conversationID = ?",
            arguments: [conversationID.uuidString]
        )
        let conversationTitle = existingMessageCount == 0
            ? S1ConversationPreview.makeHistoryTitle(fromValidatedUserText: userText)
            : currentTitle
        let effectiveTimestamp = max(
            minimumTimestamp,
            max(now.timeIntervalSince1970, latestCreatedAt ?? now.timeIntervalSince1970)
        )
        let effectiveDate = Date(timeIntervalSince1970: effectiveTimestamp)
        let userMessage = AgentMessage(
            id: UUID(),
            role: .user,
            content: userText,
            createdAt: effectiveDate
        )
        let systemMessage = AgentMessage(
            id: UUID(),
            role: .system,
            content: systemContent,
            createdAt: effectiveDate
        )

        for message in [userMessage, systemMessage] {
            try db.execute(
                sql: "INSERT INTO agentMessage (id, conversationID, role, content, idempotencyKey, createdAt) VALUES (?, ?, ?, ?, NULL, ?)",
                arguments: [
                    message.id.uuidString,
                    conversationID.uuidString,
                    message.role.rawValue,
                    message.content,
                    message.createdAt.timeIntervalSince1970
                ]
            )
        }
        try db.execute(
            sql: "UPDATE agentConversation SET title = ?, updatedAt = ? WHERE id = ?",
            arguments: [conversationTitle, effectiveTimestamp, conversationID.uuidString]
        )
        return PersistedConversationTurn(
            messages: [userMessage, systemMessage],
            conversationTitle: conversationTitle
        )
    }

    private static func persistS1PreviewTurn(
        conversationID: UUID,
        currentTitle: String,
        turn: S1ConversationPreviewTurn,
        now: Date,
        minimumTimestamp: TimeInterval,
        in db: Database
    ) throws -> PersistedConversationTurn {
        try persistConversationMessages(
            conversationID: conversationID,
            currentTitle: currentTitle,
            userText: turn.userText,
            systemContent: turn.systemReceipt,
            now: now,
            minimumTimestamp: minimumTimestamp,
            in: db
        )
    }

    func ensureDefaultConversation(now: Date = Date()) throws -> AgentConversation {
        try queue.write { db in
            let conversation: AgentConversation
            if let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentConversation ORDER BY updatedAt DESC, rowid DESC LIMIT 1"
            ), let restored = Self.decodeConversation(row) {
                conversation = restored
            } else {
                conversation = AgentConversation(
                    id: UUID(),
                    title: "New conversation",
                    createdAt: now,
                    updatedAt: now
                )
                try db.execute(
                    sql: "INSERT INTO agentConversation (id, title, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
                    arguments: [conversation.id.uuidString, conversation.title, now.timeIntervalSince1970, now.timeIntervalSince1970]
                )
            }

            // The pre-runtime app had one implicit conversation. Adopt its unscoped
            // artifacts and receipts once so upgrades do not make accepted work vanish.
            try db.execute(
                sql: "UPDATE agentArtifact SET conversationID = ? WHERE conversationID IS NULL",
                arguments: [conversation.id.uuidString]
            )
            try db.execute(
                sql: "UPDATE toolReceipt SET conversationID = ? WHERE conversationID IS NULL",
                arguments: [conversation.id.uuidString]
            )
            return conversation
        }
    }

    func listConversations() throws -> [AgentConversation] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM agentConversation ORDER BY updatedAt DESC, rowid DESC").compactMap(Self.decodeConversation)
        }
    }

    func appendAgentMessage(
        conversationID: UUID,
        role: AgentMessageRole,
        content: String,
        idempotencyKey: String? = nil,
        now: Date = Date()
    ) throws -> AgentMessage {
        try queue.write { db in
            if let idempotencyKey,
               let row = try Row.fetchOne(
                   db,
                   sql: "SELECT * FROM agentMessage WHERE idempotencyKey = ? LIMIT 1",
                   arguments: [idempotencyKey]
               ) {
                let storedConversationID: String = row["conversationID"]
                guard let existing = Self.decodeAgentMessage(row),
                      storedConversationID == conversationID.uuidString,
                      existing.role == role,
                      existing.content == content else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return existing
            }

            let message = AgentMessage(id: UUID(), role: role, content: content, createdAt: now)
            try db.execute(
                sql: "INSERT INTO agentMessage (id, conversationID, role, content, idempotencyKey, createdAt) VALUES (?, ?, ?, ?, ?, ?)",
                arguments: [
                    message.id.uuidString,
                    conversationID.uuidString,
                    message.role.rawValue,
                    message.content,
                    idempotencyKey,
                    message.createdAt.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: "UPDATE agentConversation SET updatedAt = ? WHERE id = ?",
                arguments: [now.timeIntervalSince1970, conversationID.uuidString]
            )
            return message
        }
    }

    func listAgentMessages(conversationID: UUID) throws -> [AgentMessage] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM agentMessage WHERE conversationID = ? ORDER BY createdAt ASC, rowid ASC",
                arguments: [conversationID.uuidString]
            ).compactMap(Self.decodeAgentMessage)
        }
    }

    func s1PreviewMessageWindow(
        conversationID: UUID,
        maximumMessageCount: Int = 200,
        maximumUTF8Bytes: Int = 512 * 1_024
    ) throws -> S1PreviewMessageWindow {
        try queue.read { db in
            try Self.s1PreviewMessageWindow(
                conversationID: conversationID,
                maximumMessageCount: maximumMessageCount,
                maximumUTF8Bytes: maximumUTF8Bytes,
                in: db
            )
        }
    }

    func saveAgentSession(_ session: AgentSessionState, conversationID: UUID) throws {
        let answers = try JSONEncoder().encode(session.interviewAnswers)
        guard let answersJSON = String(data: answers, encoding: .utf8) else { throw AppDatabaseError.invalidAgentSession }
        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO agentSession (conversationID, focusedProjectID, interviewStep, currentQuestion, interviewAnswersJSON, updatedAt)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(conversationID) DO UPDATE SET
                    focusedProjectID = excluded.focusedProjectID,
                    interviewStep = excluded.interviewStep,
                    currentQuestion = excluded.currentQuestion,
                    interviewAnswersJSON = excluded.interviewAnswersJSON,
                    updatedAt = excluded.updatedAt
                """,
                arguments: [conversationID.uuidString, session.focusedProjectID?.uuidString, session.interviewStep, session.currentQuestion, answersJSON, session.updatedAt.timeIntervalSince1970]
            )
        }
    }

    func loadAgentSession(conversationID: UUID) throws -> AgentSessionState? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM agentSession WHERE conversationID = ?", arguments: [conversationID.uuidString]) else { return nil }
            let answersJSON: String = row["interviewAnswersJSON"]
            guard let data = answersJSON.data(using: .utf8),
                  let answers = try? JSONDecoder().decode([String].self, from: data) else { throw AppDatabaseError.invalidAgentSession }
            let projectText: String? = row["focusedProjectID"]
            return AgentSessionState(
                focusedProjectID: projectText.flatMap { UUID(uuidString: $0) },
                interviewStep: row["interviewStep"],
                currentQuestion: row["currentQuestion"],
                interviewAnswers: answers,
                updatedAt: Date(timeIntervalSince1970: row["updatedAt"])
            )
        }
    }

    func focusedProjectID(conversationID: UUID) throws -> UUID? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT focusedProjectID FROM agentSession WHERE conversationID = ?",
                arguments: [conversationID.uuidString]
            ) else { return nil }
            let projectText: String? = row["focusedProjectID"]
            guard let projectText else { return nil }
            guard let projectID = UUID(uuidString: projectText) else {
                throw AppDatabaseError.invalidAgentSession
            }
            return projectID
        }
    }

    func saveAgentRun(_ run: AgentRunSnapshot, conversationID: UUID) throws {
        try queue.write { db in try Self.upsertAgentRun(run, conversationID: conversationID, in: db) }
    }

    func latestAgentRun(conversationID: UUID) throws -> AgentRunSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentRun WHERE conversationID = ? ORDER BY updatedAt DESC, rowid DESC LIMIT 1",
                arguments: [conversationID.uuidString]
            ) else { return nil }
            return try Self.decodeAgentRun(row)
        }
    }

    func agentRun(id: UUID, conversationID: UUID) throws -> AgentRunSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentRun WHERE id = ? AND conversationID = ? LIMIT 1",
                arguments: [id.uuidString, conversationID.uuidString]
            ) else { return nil }
            return try Self.decodeAgentRun(row)
        }
    }

    func agentRun(idempotencyKey: String) throws -> AgentRunSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentRun WHERE idempotencyKey = ? LIMIT 1",
                arguments: [idempotencyKey]
            ) else { return nil }
            return try Self.decodeAgentRun(row)
        }
    }

    func latestArtifact(kind: String, conversationID: UUID) throws -> AgentArtifact? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentArtifact WHERE kind = ? AND conversationID = ? ORDER BY updatedAt DESC, rowid DESC LIMIT 1",
                arguments: [kind, conversationID.uuidString]
            ) else { return nil }
            return Self.decodeAgentArtifact(row)
        }
    }

    func latestToolReceipt(conversationID: UUID) throws -> ToolReceipt? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM toolReceipt WHERE conversationID = ? ORDER BY createdAt DESC, rowid DESC LIMIT 1",
                arguments: [conversationID.uuidString]
            ) else { return nil }
            return Self.decodeToolReceipt(row)
        }
    }

    func toolReceipt(idempotencyKey: String) throws -> ToolReceipt? {
        try queue.read { db in
            try Self.receipt(idempotencyKey: idempotencyKey, in: db)
        }
    }

    func executeProjectCreateTool(
        conversationID: UUID,
        title: String,
        premise: String,
        idempotencyKey: String,
        now: Date = Date()
    ) throws -> ProjectCreateToolResult {
        try queue.write { db in
            if let receipt = try Self.receipt(idempotencyKey: idempotencyKey, in: db) {
                guard receipt.conversationID == conversationID,
                      let reference = receipt.outputReference,
                      let project = try Self.project(id: reference, in: db) else { throw AppDatabaseError.invalidToolReceiptReference }
                return ProjectCreateToolResult(project: project, receipt: receipt)
            }

            let project = NovelProject(id: UUID(), title: title, premise: premise, createdAt: now, updatedAt: now)
            try db.execute(
                sql: "INSERT INTO novelProject (id, title, premise, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)",
                arguments: [project.id.uuidString, project.title, project.premise, now.timeIntervalSince1970, now.timeIntervalSince1970]
            )
            let receipt = ToolReceipt(
                id: UUID(), toolID: "project.create", inputSummary: premise, outcome: "completed",
                conversationID: conversationID, projectID: project.id,
                idempotencyKey: idempotencyKey, outputReference: project.id.uuidString, createdAt: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            return ProjectCreateToolResult(project: project, receipt: receipt)
        }
    }

    func executeArtifactTool(
        conversationID: UUID,
        projectID: UUID?,
        toolID: String,
        kind: String,
        title: String,
        body: String,
        status: String,
        idempotencyKey: String,
        now: Date = Date()
    ) throws -> ArtifactToolResult {
        let expectedHash = ApprovalFingerprint.artifactHash(
            conversationID: conversationID,
            projectID: projectID,
            kind: kind,
            title: title,
            body: body
        )
        let expectedInputSummary = kind + ":" + status
        return try queue.write { db in
            if let receipt = try Self.receipt(idempotencyKey: idempotencyKey, in: db) {
                guard receipt.toolID == toolID,
                      receipt.toolVersion == "1",
                      receipt.inputSummary == expectedInputSummary,
                      receipt.inputHash == expectedHash,
                      receipt.conversationID == conversationID,
                      receipt.projectID == projectID,
                      let reference = receipt.outputReference,
                      let artifact = try Self.artifact(id: reference, in: db),
                      artifact.contentHash == expectedHash,
                      artifact.kind == kind,
                      artifact.title == title,
                      artifact.body == body,
                      artifact.status == status,
                      artifact.conversationID == conversationID,
                      artifact.projectID == projectID else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return ArtifactToolResult(artifact: artifact, receipt: receipt)
            }

            let previousRow: Row?
            if let projectID {
                previousRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM agentArtifact WHERE kind = ? AND conversationID = ? AND projectID = ? ORDER BY updatedAt DESC, rowid DESC LIMIT 1",
                    arguments: [kind, conversationID.uuidString, projectID.uuidString]
                )
            } else {
                previousRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM agentArtifact WHERE kind = ? AND conversationID = ? AND projectID IS NULL ORDER BY updatedAt DESC, rowid DESC LIMIT 1",
                    arguments: [kind, conversationID.uuidString]
                )
            }
            let previous = previousRow.flatMap(Self.decodeAgentArtifact)
            let artifactID = UUID()
            let artifact = AgentArtifact(
                id: artifactID,
                logicalID: previous?.logicalID ?? artifactID,
                revision: (previous?.revision ?? 0) + 1,
                contentHash: expectedHash,
                parentArtifactID: previous?.id,
                kind: kind,
                title: title,
                body: body,
                status: status,
                conversationID: conversationID,
                projectID: projectID,
                updatedAt: now
            )
            try db.execute(
                sql: """
                INSERT INTO agentArtifact (
                    id, logicalID, revision, contentHash, parentArtifactID, kind, title, body,
                    status, conversationID, projectID, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    artifact.id.uuidString,
                    artifact.logicalID.uuidString,
                    artifact.revision,
                    artifact.contentHash,
                    artifact.parentArtifactID?.uuidString,
                    artifact.kind,
                    artifact.title,
                    artifact.body,
                    artifact.status,
                    artifact.conversationID?.uuidString,
                    artifact.projectID?.uuidString,
                    artifact.updatedAt.timeIntervalSince1970
                ]
            )
            let receipt = ToolReceipt(
                id: UUID(), toolID: toolID, toolVersion: "1",
                inputSummary: expectedInputSummary, inputHash: artifact.contentHash, outcome: "completed",
                conversationID: conversationID, projectID: projectID,
                idempotencyKey: idempotencyKey, outputReference: artifact.id.uuidString, createdAt: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            return ArtifactToolResult(artifact: artifact, receipt: receipt)
        }
    }

    static func requireCurrentS1WorkspaceSelection(
        _ expectedConversationID: UUID?,
        in db: Database
    ) throws {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT selectedConversationID FROM s1WorkspaceState WHERE id = 'default'"
        ) else {
            throw AppDatabaseError.invalidAgentSession
        }
        let rawSelectedID: String? = row["selectedConversationID"]
        let persistedConversationID = try rawSelectedID.map { rawID in
            guard let id = UUID(uuidString: rawID) else {
                throw AppDatabaseError.invalidAgentSession
            }
            return id
        }
        guard persistedConversationID == expectedConversationID else {
            throw AppDatabaseError.invalidAgentSession
        }
    }

    static func s1ConversationWorkspaceSnapshot(
        in db: Database
    ) throws -> S1ConversationWorkspaceSnapshot {
        guard let workspaceRow = try Row.fetchOne(
            db,
            sql: "SELECT selectedConversationID, unboundDraft FROM s1WorkspaceState WHERE id = 'default'"
        ) else {
            throw AppDatabaseError.invalidAgentSession
        }

        let rawSelectedID: String? = workspaceRow["selectedConversationID"]
        let selectedConversation: AgentConversation?
        if let rawSelectedID {
            guard let selectedID = UUID(uuidString: rawSelectedID),
                  let conversationRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM agentConversation WHERE id = ?",
                    arguments: [rawSelectedID]
                  ),
                  let conversation = decodeConversation(conversationRow) else {
                throw AppDatabaseError.invalidAgentSession
            }
            guard conversation.id == selectedID else {
                throw AppDatabaseError.invalidAgentSession
            }
            selectedConversation = conversation
        } else {
            selectedConversation = nil
        }

        let conversations = try Row.fetchAll(
            db,
            sql: "SELECT * FROM agentConversation ORDER BY updatedAt DESC, rowid DESC"
        ).compactMap(decodeConversation)
        let draft: String
        let messageWindow: S1PreviewMessageWindow
        if let selectedConversation {
            draft = try String.fetchOne(
                db,
                sql: "SELECT content FROM s1ConversationDraft WHERE conversationID = ?",
                arguments: [selectedConversation.id.uuidString]
            ) ?? ""
            messageWindow = try s1PreviewMessageWindow(
                conversationID: selectedConversation.id,
                maximumMessageCount: 200,
                maximumUTF8Bytes: 512 * 1_024,
                in: db
            )
        } else {
            draft = workspaceRow["unboundDraft"]
            messageWindow = S1PreviewMessageWindow(
                messages: [],
                hasEarlierMessages: false
            )
        }

        return S1ConversationWorkspaceSnapshot(
            selectedConversation: selectedConversation,
            conversations: conversations,
            draft: draft,
            messageWindow: messageWindow
        )
    }

    private static func s1PreviewMessageWindow(
        conversationID: UUID,
        maximumMessageCount: Int,
        maximumUTF8Bytes: Int,
        in db: Database
    ) throws -> S1PreviewMessageWindow {
        guard maximumMessageCount > 0, maximumUTF8Bytes > 0 else {
            throw AppDatabaseError.invalidAgentSession
        }
        let fetchLimit = maximumMessageCount == Int.max
            ? maximumMessageCount
            : maximumMessageCount + 1
        let newestRows = try Row.fetchAll(
            db,
            sql: """
                SELECT * FROM agentMessage
                WHERE conversationID = ?
                ORDER BY createdAt DESC, rowid DESC
                LIMIT ?
                """,
            arguments: [conversationID.uuidString, fetchLimit]
        )
        let boundedRows = newestRows.prefix(maximumMessageCount)
        var newestMessages: [AgentMessage] = []
        newestMessages.reserveCapacity(boundedRows.count)
        var accumulatedBytes = 0
        var omittedForByteBudget = false

        for row in boundedRows {
            guard let message = decodeAgentMessage(row) else { continue }
            let messageBytes = message.content.utf8.count
            let remainingByteBudget = maximumUTF8Bytes - accumulatedBytes
            guard messageBytes <= remainingByteBudget else {
                omittedForByteBudget = true
                break
            }
            newestMessages.append(message)
            accumulatedBytes += messageBytes
        }

        return S1PreviewMessageWindow(
            messages: Array(newestMessages.reversed()),
            hasEarlierMessages: newestRows.count > maximumMessageCount || omittedForByteBudget
        )
    }

    static func decodeConversation(_ row: Row) -> AgentConversation? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        return AgentConversation(id: id, title: row["title"], createdAt: Date(timeIntervalSince1970: row["createdAt"]), updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
    }

    static func decodeAgentMessage(_ row: Row) -> AgentMessage? {
        guard let id = UUID(uuidString: row["id"]), let role = AgentMessageRole(rawValue: row["role"]) else { return nil }
        return AgentMessage(id: id, role: role, content: row["content"], createdAt: Date(timeIntervalSince1970: row["createdAt"]))
    }

    static func upsertAgentRun(_ run: AgentRunSnapshot, conversationID: UUID, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO agentRun (
                id, conversationID, projectID, kind, status, idempotencyKey,
                currentStage, startedAt, updatedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(idempotencyKey) DO UPDATE SET
                status = excluded.status,
                currentStage = excluded.currentStage,
                updatedAt = excluded.updatedAt
            WHERE agentRun.id = excluded.id
              AND agentRun.conversationID = excluded.conversationID
              AND agentRun.projectID IS excluded.projectID
              AND agentRun.kind = excluded.kind
            """,
            arguments: [
                run.id.uuidString,
                conversationID.uuidString,
                run.projectID?.uuidString,
                run.kind,
                run.status.rawValue,
                run.idempotencyKey,
                run.currentStage,
                run.startedAt.timeIntervalSince1970,
                run.updatedAt.timeIntervalSince1970
            ]
        )
        guard let stored = try Row.fetchOne(
            db,
            sql: "SELECT id, conversationID, projectID, kind FROM agentRun WHERE idempotencyKey = ? LIMIT 1",
            arguments: [run.idempotencyKey]
        ) else {
            throw AppDatabaseError.idempotencyConflict
        }
        let storedID: String = stored["id"]
        let storedConversationID: String = stored["conversationID"]
        let storedProjectID: String? = stored["projectID"]
        let storedKind: String = stored["kind"]
        guard storedID == run.id.uuidString,
              storedConversationID == conversationID.uuidString,
              storedProjectID == run.projectID?.uuidString,
              storedKind == run.kind else {
            throw AppDatabaseError.idempotencyConflict
        }
    }

    static func decodeAgentRun(_ row: Row) throws -> AgentRunSnapshot {
        guard let id = UUID(uuidString: row["id"]), let status = AgentRunStatus(rawValue: row["status"]) else { throw AppDatabaseError.invalidAgentRun }
        let projectText: String? = row["projectID"]
        return AgentRunSnapshot(
            id: id,
            projectID: projectText.flatMap(UUID.init(uuidString:)),
            kind: row["kind"],
            status: status,
            idempotencyKey: row["idempotencyKey"],
            currentStage: row["currentStage"],
            startedAt: Date(timeIntervalSince1970: row["startedAt"]),
            updatedAt: Date(timeIntervalSince1970: row["updatedAt"])
        )
    }

    static func receipt(idempotencyKey: String, in db: Database) throws -> ToolReceipt? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM toolReceipt WHERE idempotencyKey = ? LIMIT 1", arguments: [idempotencyKey]) else { return nil }
        return decodeToolReceipt(row)
    }

    static func insertToolReceipt(_ receipt: ToolReceipt, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO toolReceipt (
                id, toolID, toolVersion, inputSummary, inputHash, outcome, conversationID,
                projectID, approvalRequestID, approvalBindingHash, originRunID, idempotencyKey,
                outputReference, providerRequestID, providerCallID, providerCallIndex,
                createdAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                receipt.id.uuidString,
                receipt.toolID,
                receipt.toolVersion,
                receipt.inputSummary,
                receipt.inputHash,
                receipt.outcome,
                receipt.conversationID?.uuidString,
                receipt.projectID?.uuidString,
                receipt.approvalRequestID?.uuidString,
                receipt.approvalBindingHash,
                receipt.originRunID?.uuidString,
                receipt.idempotencyKey,
                receipt.outputReference,
                receipt.providerRequestID?.uuidString,
                receipt.providerCallID,
                receipt.providerCallIndex,
                receipt.createdAt.timeIntervalSince1970
            ]
        )
    }

    static func decodeToolReceipt(_ row: Row) -> ToolReceipt? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        let conversationText: String? = row["conversationID"]
        let projectText: String? = row["projectID"]
        let approvalRequestText: String? = row["approvalRequestID"]
        let originRunText: String? = row["originRunID"]
        let providerRequestText: String? = row["providerRequestID"]
        return ToolReceipt(
            id: id,
            toolID: row["toolID"],
            toolVersion: row["toolVersion"],
            inputSummary: row["inputSummary"],
            inputHash: row["inputHash"],
            outcome: row["outcome"],
            conversationID: conversationText.flatMap { UUID(uuidString: $0) },
            projectID: projectText.flatMap { UUID(uuidString: $0) },
            approvalRequestID: approvalRequestText.flatMap { UUID(uuidString: $0) },
            approvalBindingHash: row["approvalBindingHash"],
            originRunID: originRunText.flatMap { UUID(uuidString: $0) },
            idempotencyKey: row["idempotencyKey"],
            outputReference: row["outputReference"],
            providerRequestID: providerRequestText.flatMap(UUID.init(uuidString:)),
            providerCallID: row["providerCallID"],
            providerCallIndex: row["providerCallIndex"],
            createdAt: Date(timeIntervalSince1970: row["createdAt"])
        )
    }

    static func decodeAgentArtifact(_ row: Row) -> AgentArtifact? {
        let idText: String = row["id"]
        let logicalText: String? = row["logicalID"]
        let revision: Int? = row["revision"]
        let contentHash: String? = row["contentHash"]
        guard let id = UUID(uuidString: idText),
              let logicalText,
              let logicalID = UUID(uuidString: logicalText),
              let revision,
              revision > 0,
              let contentHash,
              !contentHash.isEmpty else { return nil }
        let conversationText: String? = row["conversationID"]
        let projectText: String? = row["projectID"]
        let parentText: String? = row["parentArtifactID"]
        return AgentArtifact(
            id: id,
            logicalID: logicalID,
            revision: revision,
            contentHash: contentHash,
            parentArtifactID: parentText.flatMap { UUID(uuidString: $0) },
            kind: row["kind"],
            title: row["title"],
            body: row["body"],
            status: row["status"],
            conversationID: conversationText.flatMap { UUID(uuidString: $0) },
            projectID: projectText.flatMap { UUID(uuidString: $0) },
            updatedAt: Date(timeIntervalSince1970: row["updatedAt"])
        )
    }

    static func project(id: String, in db: Database) throws -> NovelProject? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM novelProject WHERE id = ?", arguments: [id]), let uuid = UUID(uuidString: row["id"]) else { return nil }
        return NovelProject(id: uuid, title: row["title"], premise: row["premise"], version: row["version"] ?? 1, createdAt: Date(timeIntervalSince1970: row["createdAt"]), updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
    }

    static func artifact(id: String, in db: Database) throws -> AgentArtifact? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM agentArtifact WHERE id = ?", arguments: [id]) else { return nil }
        return decodeAgentArtifact(row)
    }
}
