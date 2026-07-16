import Foundation
import GRDB

extension AppDatabase {
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
        try queue.write { db in
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

    private static func decodeConversation(_ row: Row) -> AgentConversation? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        return AgentConversation(id: id, title: row["title"], createdAt: Date(timeIntervalSince1970: row["createdAt"]), updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
    }

    private static func decodeAgentMessage(_ row: Row) -> AgentMessage? {
        guard let id = UUID(uuidString: row["id"]), let role = AgentMessageRole(rawValue: row["role"]) else { return nil }
        return AgentMessage(id: id, role: role, content: row["content"], createdAt: Date(timeIntervalSince1970: row["createdAt"]))
    }

    private static func upsertAgentRun(_ run: AgentRunSnapshot, conversationID: UUID, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO agentRun (id, conversationID, kind, status, idempotencyKey, currentStage, startedAt, updatedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(idempotencyKey) DO UPDATE SET
                status = excluded.status,
                currentStage = excluded.currentStage,
                updatedAt = excluded.updatedAt
            """,
            arguments: [run.id.uuidString, conversationID.uuidString, run.kind, run.status.rawValue, run.idempotencyKey, run.currentStage, run.startedAt.timeIntervalSince1970, run.updatedAt.timeIntervalSince1970]
        )
    }

    private static func decodeAgentRun(_ row: Row) throws -> AgentRunSnapshot {
        guard let id = UUID(uuidString: row["id"]), let status = AgentRunStatus(rawValue: row["status"]) else { throw AppDatabaseError.invalidAgentRun }
        return AgentRunSnapshot(id: id, kind: row["kind"], status: status, idempotencyKey: row["idempotencyKey"], currentStage: row["currentStage"], startedAt: Date(timeIntervalSince1970: row["startedAt"]), updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
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
                projectID, approvalRequestID, approvalBindingHash, idempotencyKey,
                outputReference, createdAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
                receipt.idempotencyKey,
                receipt.outputReference,
                receipt.createdAt.timeIntervalSince1970
            ]
        )
    }

    static func decodeToolReceipt(_ row: Row) -> ToolReceipt? {
        guard let id = UUID(uuidString: row["id"]) else { return nil }
        let conversationText: String? = row["conversationID"]
        let projectText: String? = row["projectID"]
        let approvalRequestText: String? = row["approvalRequestID"]
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
            idempotencyKey: row["idempotencyKey"],
            outputReference: row["outputReference"],
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
