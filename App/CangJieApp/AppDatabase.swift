import Foundation
import GRDB

struct ToolReceipt: Identifiable, Equatable {
    let id: UUID
    let toolID: String
    let toolVersion: String?
    let inputSummary: String
    let inputHash: String?
    let outcome: String
    let conversationID: UUID?
    let projectID: UUID?
    let approvalRequestID: UUID?
    let approvalBindingHash: String?
    let idempotencyKey: String?
    let outputReference: String?
    let createdAt: Date

    init(
        id: UUID,
        toolID: String,
        toolVersion: String? = nil,
        inputSummary: String,
        inputHash: String? = nil,
        outcome: String,
        conversationID: UUID?,
        projectID: UUID?,
        approvalRequestID: UUID? = nil,
        approvalBindingHash: String? = nil,
        idempotencyKey: String?,
        outputReference: String?,
        createdAt: Date
    ) {
        self.id = id
        self.toolID = toolID
        self.toolVersion = toolVersion
        self.inputSummary = inputSummary
        self.inputHash = inputHash
        self.outcome = outcome
        self.conversationID = conversationID
        self.projectID = projectID
        self.approvalRequestID = approvalRequestID
        self.approvalBindingHash = approvalBindingHash
        self.idempotencyKey = idempotencyKey
        self.outputReference = outputReference
        self.createdAt = createdAt
    }
}

struct AgentArtifact: Identifiable, Equatable {
    let id: UUID
    let logicalID: UUID
    let revision: Int
    let contentHash: String
    let parentArtifactID: UUID?
    let kind: String
    let title: String
    let body: String
    let status: String
    let conversationID: UUID?
    let projectID: UUID?
    let updatedAt: Date

    init(
        id: UUID,
        logicalID: UUID? = nil,
        revision: Int = 1,
        contentHash: String = "",
        parentArtifactID: UUID? = nil,
        kind: String,
        title: String,
        body: String,
        status: String,
        conversationID: UUID?,
        projectID: UUID?,
        updatedAt: Date
    ) {
        self.id = id
        self.logicalID = logicalID ?? id
        self.revision = revision
        self.contentHash = contentHash
        self.parentArtifactID = parentArtifactID
        self.kind = kind
        self.title = title
        self.body = body
        self.status = status
        self.conversationID = conversationID
        self.projectID = projectID
        self.updatedAt = updatedAt
    }
}

struct NovelProject: Identifiable, Equatable {
    let id: UUID
    let title: String
    let premise: String
    let version: Int
    let createdAt: Date
    let updatedAt: Date

    init(id: UUID, title: String, premise: String, version: Int = 1, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.premise = premise
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DraftSnapshot: Equatable {
    let content: String
    let updatedAt: Date
}

struct PersistedCheckpoint: Equatable {
    let id: UUID
    let taskID: UUID
    let idempotencyKey: String
    let stage: String
    let sequence: Int
    let payloadHash: String
    let createdAt: Date
}

enum AppDatabaseError: Error, Equatable {
    case writeAheadLoggingUnavailable(actualMode: String)
    case invalidCheckpointIdentifier
    case checkpointTaskMismatch
    case invalidAgentSession
    case invalidAgentRun
    case invalidToolReceiptReference
    case idempotencyConflict
    case invalidApprovalRequest
    case approvalRequiresReapproval
    case approvalExpired
    case approvalBudgetExceeded
}

final class AppDatabase {
    let queue: DatabaseQueue

    init(path: String) throws {
        var configuration = Configuration()
        configuration.label = "CangJie.SQLite"
        configuration.foreignKeysEnabled = true
        queue = try DatabaseQueue(path: path, configuration: configuration)
        try queue.writeWithoutTransaction { db in
            let mode = try String.fetchOne(db, sql: "PRAGMA journal_mode = WAL") ?? "unknown"
            guard mode.lowercased() == "wal" else {
                throw AppDatabaseError.writeAheadLoggingUnavailable(actualMode: mode)
            }
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
        }
        try Self.migrator.migrate(queue)
    }

    static func makeDefault(fileManager: FileManager = .default) throws -> AppDatabase {
        var support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("CangJie", isDirectory: true)
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        try applyLocalDataProtection(to: &support, fileManager: fileManager)

        let databaseURL = support.appendingPathComponent("cangjie.sqlite")
        let database = try AppDatabase(path: databaseURL.path)
        for suffix in ["", "-wal", "-shm"] {
            let protectedPath = databaseURL.path + suffix
            if fileManager.fileExists(atPath: protectedPath) {
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: protectedPath
                )
            }
        }
        return database
    }

    func saveDraft(_ content: String, now: Date = Date()) throws {
        try queue.write { db in
            try Self.upsertDraft(content, now: now, in: db)
        }
    }

    func checkpointDraft(
        content: String,
        taskID: UUID,
        reason: String,
        payloadHash: String,
        now: Date = Date()
    ) throws -> PersistedCheckpoint {
        try queue.write { db in
            let latest = try Self.latestCheckpoint(taskID: taskID, in: db)
            if let latest, latest.payloadHash == payloadHash {
                return latest
            }

            let checkpoint = PersistedCheckpoint(
                id: UUID(),
                taskID: taskID,
                idempotencyKey: "m0-draft.\(taskID.uuidString).\(UUID().uuidString)",
                stage: reason,
                sequence: (latest?.sequence ?? 0) + 1,
                payloadHash: payloadHash,
                createdAt: now
            )
            try Self.upsertDraft(content, now: now, in: db)
            try Self.insertCheckpoint(checkpoint, in: db)
            return checkpoint
        }
    }

    func loadDraft() throws -> DraftSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT content, updatedAt FROM draft WHERE id = 'm0'"
            ) else { return nil }
            return DraftSnapshot(
                content: row["content"],
                updatedAt: Date(timeIntervalSince1970: row["updatedAt"])
            )
        }
    }

    func latestCheckpoint(taskID: UUID) throws -> PersistedCheckpoint? {
        try queue.read { db in
            try Self.latestCheckpoint(taskID: taskID, in: db)
        }
    }

    func createProject(title: String, premise: String, now: Date = Date()) throws -> NovelProject {
        let project = NovelProject(id: UUID(), title: title, premise: premise, version: 1, createdAt: now, updatedAt: now)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO novelProject (id, title, premise, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)", arguments: [project.id.uuidString, project.title, project.premise, project.createdAt.timeIntervalSince1970, project.updatedAt.timeIntervalSince1970])
        }
        return project
    }

    func listProjects() throws -> [NovelProject] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM novelProject ORDER BY updatedAt DESC").compactMap { row in
                guard let id = UUID(uuidString: row["id"]) else { return nil }
                return NovelProject(id: id, title: row["title"], premise: row["premise"], version: row["version"] ?? 1, createdAt: Date(timeIntervalSince1970: row["createdAt"]), updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
            }
        }
    }

    func recordToolReceipt(
        toolID: String,
        inputSummary: String,
        outcome: String,
        idempotencyKey: String? = nil,
        outputReference: String? = nil,
        now: Date = Date()
    ) throws -> ToolReceipt {
        let receipt = ToolReceipt(
            id: UUID(),
            toolID: toolID,
            inputSummary: inputSummary,
            outcome: outcome,
            conversationID: nil,
            projectID: nil,
            idempotencyKey: idempotencyKey,
            outputReference: outputReference,
            createdAt: now
        )
        try queue.write { db in
            try Self.insertToolReceipt(receipt, in: db)
        }
        return receipt
    }

    func latestToolReceipt() throws -> ToolReceipt? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM toolReceipt ORDER BY createdAt DESC, rowid DESC LIMIT 1") else { return nil }
            return Self.decodeToolReceipt(row)
        }
    }

    func saveArtifact(kind: String, title: String, body: String, status: String, now: Date = Date()) throws -> AgentArtifact {
        let id = UUID()
        let hash = ApprovalFingerprint.artifactHash(
            conversationID: nil,
            projectID: nil,
            kind: kind,
            title: title,
            body: body
        )
        let artifact = AgentArtifact(
            id: id,
            logicalID: id,
            revision: 1,
            contentHash: hash,
            kind: kind,
            title: title,
            body: body,
            status: status,
            conversationID: nil,
            projectID: nil,
            updatedAt: now
        )
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO agentArtifact (id, logicalID, revision, contentHash, parentArtifactID, kind, title, body, status, updatedAt) VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?)",
                arguments: [artifact.id.uuidString, artifact.logicalID.uuidString, artifact.revision, artifact.contentHash, artifact.kind, artifact.title, artifact.body, artifact.status, artifact.updatedAt.timeIntervalSince1970]
            )
        }
        return artifact
    }

    func latestArtifact(kind: String) throws -> AgentArtifact? {
        try queue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM agentArtifact WHERE kind = ? ORDER BY updatedAt DESC LIMIT 1", arguments: [kind]), let id = UUID(uuidString: row["id"]) else { return nil }
            let conversationText: String? = row["conversationID"]
            let projectText: String? = row["projectID"]
            let logicalText: String? = row["logicalID"]
            let parentText: String? = row["parentArtifactID"]
            return AgentArtifact(
                id: id,
                logicalID: logicalText.flatMap { UUID(uuidString: $0) } ?? id,
                revision: row["revision"] ?? 1,
                contentHash: row["contentHash"] ?? "",
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
    }

    func journalMode() throws -> String {
        try queue.read { db in
            try String.fetchOne(db, sql: "PRAGMA journal_mode") ?? "unknown"
        }
    }

    private static func latestCheckpoint(
        taskID: UUID,
        in db: Database
    ) throws -> PersistedCheckpoint? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM checkpoint WHERE taskID = ? ORDER BY sequence DESC LIMIT 1",
            arguments: [taskID.uuidString]
        ) else { return nil }
        return try decodeCheckpoint(row, expectedTaskID: taskID)
    }

    private static func decodeCheckpoint(
        _ row: Row,
        expectedTaskID: UUID
    ) throws -> PersistedCheckpoint {
        guard let id = UUID(uuidString: row["id"]),
              let storedTaskID = UUID(uuidString: row["taskID"]) else {
            throw AppDatabaseError.invalidCheckpointIdentifier
        }
        guard storedTaskID == expectedTaskID else {
            throw AppDatabaseError.checkpointTaskMismatch
        }
        return PersistedCheckpoint(
            id: id,
            taskID: storedTaskID,
            idempotencyKey: row["idempotencyKey"],
            stage: row["stage"],
            sequence: row["sequence"],
            payloadHash: row["payloadHash"],
            createdAt: Date(timeIntervalSince1970: row["createdAt"])
        )
    }

    private static func upsertDraft(_ content: String, now: Date, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO draft (id, content, updatedAt) VALUES ('m0', ?, ?)
            ON CONFLICT(id) DO UPDATE SET content = excluded.content, updatedAt = excluded.updatedAt
            """,
            arguments: [content, now.timeIntervalSince1970]
        )
    }

    private static func insertCheckpoint(_ checkpoint: PersistedCheckpoint, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO checkpoint (id, taskID, idempotencyKey, stage, sequence, payloadHash, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                checkpoint.id.uuidString,
                checkpoint.taskID.uuidString,
                checkpoint.idempotencyKey,
                checkpoint.stage,
                checkpoint.sequence,
                checkpoint.payloadHash,
                checkpoint.createdAt.timeIntervalSince1970
            ]
        )
    }

    private static func applyLocalDataProtection(
        to directory: inout URL,
        fileManager: FileManager
    ) throws {
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("m0-v1") { db in
            try db.create(table: "draft") { table in
                table.column("id", .text).primaryKey()
                table.column("content", .text).notNull()
                table.column("updatedAt", .double).notNull()
            }
            try db.create(table: "checkpoint") { table in
                table.column("id", .text).primaryKey()
                table.column("taskID", .text).notNull().indexed()
                table.column("idempotencyKey", .text).notNull()
                table.column("stage", .text).notNull()
                table.column("sequence", .integer).notNull()
                table.column("payloadHash", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.uniqueKey(["taskID", "sequence"])
                table.uniqueKey(["taskID", "idempotencyKey"])
            }
        }
        migrator.registerMigration("m1-projects") { db in
            try db.create(table: "novelProject") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("premise", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.column("updatedAt", .double).notNull()
            }
        }
        migrator.registerMigration("m1-tool-receipts") { db in
            try db.create(table: "toolReceipt") { table in
                table.column("id", .text).primaryKey()
                table.column("toolID", .text).notNull().indexed()
                table.column("inputSummary", .text).notNull()
                table.column("outcome", .text).notNull()
                table.column("createdAt", .double).notNull()
            }
        }
        migrator.registerMigration("m1-agent-artifacts") { db in
            try db.create(table: "agentArtifact") { table in
                table.column("id", .text).primaryKey()
                table.column("kind", .text).notNull().indexed()
                table.column("title", .text).notNull()
                table.column("body", .text).notNull()
                table.column("status", .text).notNull()
                table.column("updatedAt", .double).notNull()
            }
        }
        migrator.registerMigration("m1-agent-runtime") { db in
            try db.alter(table: "toolReceipt") { table in
                table.add(column: "conversationID", .text)
                table.add(column: "projectID", .text)
                table.add(column: "idempotencyKey", .text)
                table.add(column: "outputReference", .text)
            }
            try db.alter(table: "agentArtifact") { table in
                table.add(column: "conversationID", .text)
                table.add(column: "projectID", .text)
            }
            try db.execute(sql: "CREATE UNIQUE INDEX toolReceipt_on_idempotencyKey ON toolReceipt(idempotencyKey)")
            try db.create(table: "agentConversation") { table in
                table.column("id", .text).primaryKey()
                table.column("title", .text).notNull()
                table.column("createdAt", .double).notNull()
                table.column("updatedAt", .double).notNull().indexed()
            }
            try db.create(table: "agentMessage") { table in
                table.column("id", .text).primaryKey()
                table.column("conversationID", .text).notNull().indexed().references("agentConversation", onDelete: .cascade)
                table.column("role", .text).notNull()
                table.column("content", .text).notNull()
                table.column("createdAt", .double).notNull().indexed()
            }
            try db.create(table: "agentSession") { table in
                table.column("conversationID", .text).primaryKey().references("agentConversation", onDelete: .cascade)
                table.column("focusedProjectID", .text)
                table.column("interviewStep", .integer).notNull()
                table.column("currentQuestion", .text).notNull()
                table.column("interviewAnswersJSON", .text).notNull()
                table.column("updatedAt", .double).notNull()
            }
            try db.create(table: "agentRun") { table in
                table.column("id", .text).primaryKey()
                table.column("conversationID", .text).notNull().indexed().references("agentConversation", onDelete: .cascade)
                table.column("kind", .text).notNull()
                table.column("status", .text).notNull().indexed()
                table.column("idempotencyKey", .text).notNull().unique()
                table.column("currentStage", .text).notNull()
                table.column("startedAt", .double).notNull()
                table.column("updatedAt", .double).notNull().indexed()
            }
        }
        migrator.registerMigration("m1b-exact-approval-v1") { db in
            try db.alter(table: "novelProject") { table in
                table.add(column: "version", .integer).notNull().defaults(to: 1)
            }
            try db.alter(table: "agentArtifact") { table in
                table.add(column: "logicalID", .text)
                table.add(column: "revision", .integer)
                table.add(column: "contentHash", .text)
                table.add(column: "parentArtifactID", .text)
            }
            try db.alter(table: "toolReceipt") { table in
                table.add(column: "toolVersion", .text)
                table.add(column: "inputHash", .text)
                table.add(column: "approvalRequestID", .text)
                table.add(column: "approvalBindingHash", .text)
            }

            let rows = try Row.fetchAll(
                db,
                sql: "SELECT rowid, * FROM agentArtifact ORDER BY conversationID, projectID, kind, updatedAt ASC, rowid ASC"
            )
            var lineageByScope: [String: UUID] = [:]
            var revisionByScope: [String: Int] = [:]
            var previousByScope: [String: UUID] = [:]
            for row in rows {
                guard let artifactID = UUID(uuidString: row["id"]) else { continue }
                let conversation: String? = row["conversationID"]
                let project: String? = row["projectID"]
                let kind: String = row["kind"]
                let scope = [conversation ?? "", project ?? "", kind].joined(separator: "|")
                let lineage = lineageByScope[scope] ?? artifactID
                let revision = (revisionByScope[scope] ?? 0) + 1
                let title: String = row["title"]
                let body: String = row["body"]
                let hash = ApprovalFingerprint.artifactHash(
                    conversationID: conversation.flatMap(UUID.init(uuidString:)),
                    projectID: project.flatMap(UUID.init(uuidString:)),
                    kind: kind,
                    title: title,
                    body: body
                )
                try db.execute(
                    sql: "UPDATE agentArtifact SET logicalID = ?, revision = ?, contentHash = ?, parentArtifactID = ? WHERE id = ?",
                    arguments: [lineage.uuidString, revision, hash, previousByScope[scope]?.uuidString, artifactID.uuidString]
                )
                lineageByScope[scope] = lineage
                revisionByScope[scope] = revision
                previousByScope[scope] = artifactID
            }
            try db.execute(sql: "CREATE UNIQUE INDEX agentArtifact_on_logicalID_revision ON agentArtifact(logicalID, revision)")
            try db.execute(sql: "CREATE INDEX agentArtifact_latest_revision ON agentArtifact(conversationID, projectID, kind, logicalID, revision DESC)")

            try db.create(table: "approvalRequest") { table in
                table.column("id", .text).primaryKey()
                table.column("conversationID", .text).notNull().indexed().references("agentConversation", onDelete: .cascade)
                table.column("projectID", .text).notNull().indexed().references("novelProject", onDelete: .cascade)
                table.column("artifactID", .text).notNull().references("agentArtifact", onDelete: .restrict)
                table.column("artifactLogicalID", .text).notNull().indexed()
                table.column("artifactRevision", .integer).notNull()
                table.column("artifactHash", .text).notNull()
                table.column("toolID", .text).notNull()
                table.column("toolVersion", .text).notNull()
                table.column("parametersHash", .text).notNull()
                table.column("targetVersionsJSON", .text).notNull()
                table.column("targetVersionsHash", .text).notNull()
                table.column("estimatedCostMinorUnits", .integer).notNull()
                table.column("budgetCeilingMinorUnits", .integer).notNull()
                table.column("expiresAt", .integer).notNull().indexed()
                table.column("expectedDiffHash", .text).notNull()
                table.column("bindingHash", .text).notNull().unique()
                table.column("status", .text).notNull().indexed()
                table.column("invalidationReason", .text)
                table.column("createdAt", .double).notNull()
                table.column("updatedAt", .double).notNull()
                table.column("approvedAt", .double)
            }
            try db.execute(sql: "CREATE INDEX approvalRequest_on_artifact_revision ON approvalRequest(artifactLogicalID, artifactRevision DESC)")
        }
        migrator.registerMigration("m1b-exact-artifact-integrity-v2") { db in
            try db.execute(sql: """
                CREATE TRIGGER agentArtifact_exact_fields_insert
                BEFORE INSERT ON agentArtifact
                WHEN NEW.logicalID IS NULL
                  OR NEW.revision IS NULL
                  OR NEW.revision <= 0
                  OR NEW.contentHash IS NULL
                  OR length(NEW.contentHash) = 0
                BEGIN
                    SELECT RAISE(ABORT, 'agentArtifact exact identity is required');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER agentArtifact_exact_fields_update
                BEFORE UPDATE OF logicalID, revision, contentHash ON agentArtifact
                WHEN NEW.logicalID IS NULL
                  OR NEW.revision IS NULL
                  OR NEW.revision <= 0
                  OR NEW.contentHash IS NULL
                  OR length(NEW.contentHash) = 0
                BEGIN
                    SELECT RAISE(ABORT, 'agentArtifact exact identity is required');
                END
                """)
            try db.execute(sql: "CREATE INDEX agentArtifact_latest_activity ON agentArtifact(conversationID, projectID, kind, updatedAt DESC)")
        }
        migrator.registerMigration("m1b-agent-message-idempotency-v3") { db in
            try db.alter(table: "agentMessage") { table in
                table.add(column: "idempotencyKey", .text)
            }
            try db.execute(sql: "CREATE UNIQUE INDEX agentMessage_on_idempotencyKey ON agentMessage(idempotencyKey) WHERE idempotencyKey IS NOT NULL")
        }
        return migrator
    }
}
