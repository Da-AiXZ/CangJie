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
    let originRunID: UUID?
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
        originRunID: UUID? = nil,
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
        self.originRunID = originRunID
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
    let scopeKey: String
    let conversationID: UUID?
    let createdAt: Date
}

enum AppDatabaseError: Error, Equatable {
    case writeAheadLoggingUnavailable(actualMode: String)
    case invalidCheckpointIdentifier
    case invalidCheckpointScope
    case checkpointTaskMismatch
    case invalidAgentSession
    case invalidS1PreviewTurn
    case draftInputLimitExceeded
    case invalidUITestDatabaseScope
    case invalidAgentRun
    case invalidToolReceiptReference
    case idempotencyConflict
    case invalidApprovalRequest
    case approvalRequiresReapproval
    case approvalExpired
    case approvalBudgetExceeded
    case invalidChapterVersion
    case invalidChapterCalibration
    case chapterBindingMismatch
    case chapterOpeningPlanNotApproved
    case chapterOperationNotAllowed
    case invalidChapterParagraphIndex(Int)
    case chapterLockedContentChanged(index: Int)
    case invalidChapterDiagnosis
    case invalidRewriteScope
    case chapterInputLimitExceeded(field: String)
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

    static func makeDefault(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> AppDatabase {
        var support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("CangJie", isDirectory: true)
        if let rawScope = environment["CANGJIE_UI_TEST_DATABASE_SCOPE"] {
            guard let scope = UUID(uuidString: rawScope) else {
                throw AppDatabaseError.invalidUITestDatabaseScope
            }
            support.appendPathComponent("UITests", isDirectory: true)
            support.appendPathComponent(scope.uuidString, isDirectory: true)
        }
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
            let latestInLegacyScope = try Self.latestCheckpoint(
                taskID: taskID,
                scopeKey: "legacy:m0",
                in: db
            )
            if let latestInLegacyScope, latestInLegacyScope.payloadHash == payloadHash {
                return latestInLegacyScope
            }
            let latestSequence = try Int.fetchOne(
                db,
                sql: "SELECT MAX(sequence) FROM checkpoint WHERE taskID = ?",
                arguments: [taskID.uuidString]
            ) ?? 0

            let checkpoint = PersistedCheckpoint(
                id: UUID(),
                taskID: taskID,
                idempotencyKey: "m0-draft.\(taskID.uuidString).\(UUID().uuidString)",
                stage: reason,
                sequence: latestSequence + 1,
                payloadHash: payloadHash,
                scopeKey: "legacy:m0",
                conversationID: nil,
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

    func checkpointS1ConversationDraft(
        content: String,
        selectedConversationID: UUID?,
        taskID: UUID,
        reason: String,
        payloadHash: String,
        now: Date = Date()
    ) throws -> PersistedCheckpoint {
        try queue.write { db in
            try Self.requireS1WorkspaceSelection(selectedConversationID, in: db)
            let scopeKey = Self.s1CheckpointScopeKey(selectedConversationID)
            let latestInScope = try Self.latestCheckpoint(
                taskID: taskID,
                scopeKey: scopeKey,
                in: db
            )
            if let latestInScope, latestInScope.payloadHash == payloadHash {
                return latestInScope
            }
            let latestSequence = try Int.fetchOne(
                db,
                sql: "SELECT MAX(sequence) FROM checkpoint WHERE taskID = ?",
                arguments: [taskID.uuidString]
            ) ?? 0
            let checkpoint = PersistedCheckpoint(
                id: UUID(),
                taskID: taskID,
                idempotencyKey: "s1-draft.\(taskID.uuidString).\(UUID().uuidString)",
                stage: reason,
                sequence: latestSequence + 1,
                payloadHash: payloadHash,
                scopeKey: scopeKey,
                conversationID: selectedConversationID,
                createdAt: now
            )
            try Self.upsertDraft(content, now: now, in: db)
            try Self.upsertS1WorkspaceDraft(
                content,
                selectedConversationID: selectedConversationID,
                now: now,
                in: db
            )
            try Self.insertCheckpoint(checkpoint, in: db)
            return checkpoint
        }
    }

    func latestS1ConversationCheckpoint(
        taskID: UUID,
        selectedConversationID: UUID?
    ) throws -> PersistedCheckpoint? {
        try queue.read { db in
            try Self.latestCheckpoint(
                taskID: taskID,
                scopeKey: Self.s1CheckpointScopeKey(selectedConversationID),
                in: db
            )
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

    private static func latestCheckpoint(
        taskID: UUID,
        scopeKey: String,
        in db: Database
    ) throws -> PersistedCheckpoint? {
        guard let row = try Row.fetchOne(
            db,
            sql: """
                SELECT * FROM checkpoint
                WHERE taskID = ? AND scopeKey = ?
                ORDER BY sequence DESC
                LIMIT 1
                """,
            arguments: [taskID.uuidString, scopeKey]
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
        let scopeKey: String = row["scopeKey"]
        let rawConversationID: String? = row["conversationID"]
        let conversationID: UUID?
        if let rawConversationID {
            guard let parsedConversationID = UUID(uuidString: rawConversationID) else {
                throw AppDatabaseError.invalidCheckpointIdentifier
            }
            conversationID = parsedConversationID
        } else {
            conversationID = nil
        }
        try validateCheckpointScope(scopeKey, conversationID: conversationID)

        return PersistedCheckpoint(
            id: id,
            taskID: storedTaskID,
            idempotencyKey: row["idempotencyKey"],
            stage: row["stage"],
            sequence: row["sequence"],
            payloadHash: row["payloadHash"],
            scopeKey: scopeKey,
            conversationID: conversationID,
            createdAt: Date(timeIntervalSince1970: row["createdAt"])
        )
    }

    static func upsertDraft(_ content: String, now: Date, in db: Database) throws {
        guard content.utf8.count <= S1ConversationPreview.maximumDraftUTF8Bytes else {
            throw AppDatabaseError.draftInputLimitExceeded
        }
        try db.execute(
            sql: """
            INSERT INTO draft (id, content, updatedAt) VALUES ('m0', ?, ?)
            ON CONFLICT(id) DO UPDATE SET content = excluded.content, updatedAt = excluded.updatedAt
            """,
            arguments: [content, now.timeIntervalSince1970]
        )
    }

    private static func requireS1WorkspaceSelection(
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
        let persistedConversationID = rawSelectedID.flatMap(UUID.init(uuidString:))
        guard (rawSelectedID == nil || persistedConversationID != nil),
              persistedConversationID == expectedConversationID else {
            throw AppDatabaseError.invalidAgentSession
        }
    }

    private static func s1CheckpointScopeKey(_ conversationID: UUID?) -> String {
        if let conversationID {
            return "s1:conversation:\(conversationID.uuidString)"
        }
        return "s1:new"
    }

    private static func upsertS1WorkspaceDraft(
        _ content: String,
        selectedConversationID: UUID?,
        now: Date,
        in db: Database
    ) throws {
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
    }

    private static func validateCheckpointScope(
        _ scopeKey: String,
        conversationID: UUID?
    ) throws {
        switch scopeKey {
        case "legacy:m0", "s1:new":
            guard conversationID == nil else {
                throw AppDatabaseError.invalidCheckpointScope
            }
        default:
            guard let conversationID,
                  scopeKey == s1CheckpointScopeKey(conversationID) else {
                throw AppDatabaseError.invalidCheckpointScope
            }
        }
    }

    private static func insertCheckpoint(_ checkpoint: PersistedCheckpoint, in db: Database) throws {
        try validateCheckpointScope(
            checkpoint.scopeKey,
            conversationID: checkpoint.conversationID
        )
        try db.execute(
            sql: """
            INSERT INTO checkpoint (
                id, taskID, idempotencyKey, stage, sequence, payloadHash,
                scopeKey, conversationID, createdAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                checkpoint.id.uuidString,
                checkpoint.taskID.uuidString,
                checkpoint.idempotencyKey,
                checkpoint.stage,
                checkpoint.sequence,
                checkpoint.payloadHash,
                checkpoint.scopeKey,
                checkpoint.conversationID?.uuidString,
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
        migrator.registerMigration("m1c-chapter-calibration-v1") { db in
            try db.create(table: "chapterVersion") { table in
                table.column("id", .text).primaryKey()
                table.column("logicalID", .text).notNull().indexed()
                table.column("conversationID", .text).notNull().indexed().references("agentConversation", onDelete: .restrict)
                table.column("projectID", .text).notNull().indexed().references("novelProject", onDelete: .restrict)
                table.column("chapterNumber", .integer).notNull()
                table.column("revision", .integer).notNull()
                table.column("parentVersionID", .text).references("chapterVersion", onDelete: .restrict)
                table.column("title", .text).notNull()
                table.column("body", .text).notNull()
                table.column("contentHash", .text).notNull()
                table.column("creationStatus", .text).notNull()
                table.column("evidenceReview", .text).notNull()
                table.column("diffSummary", .text)
                table.column("createdAt", .double).notNull()
                table.uniqueKey(["logicalID", "revision"])
            }
            try db.execute(sql: "CREATE INDEX chapterVersion_scope_revision ON chapterVersion(conversationID, projectID, chapterNumber, revision ASC)")
            try db.create(table: "chapterCalibration") { table in
                table.column("chapterLogicalID", .text).primaryKey()
                table.column("conversationID", .text).notNull().indexed().references("agentConversation", onDelete: .restrict)
                table.column("projectID", .text).notNull().indexed().references("novelProject", onDelete: .restrict)
                table.column("chapterNumber", .integer).notNull()
                table.column("activeVersionID", .text).notNull().references("chapterVersion", onDelete: .restrict)
                table.column("stage", .text).notNull().indexed()
                table.column("diagnosisEntriesJSON", .text).notNull()
                table.column("diagnosisHash", .text).notNull()
                table.column("rejectionHistoryJSON", .text).notNull()
                table.column("lockedParagraphIndexesJSON", .text).notNull()
                table.column("rewriteScope", .text)
                table.column("rewriteScopeHash", .text)
                table.column("acceptedVersionID", .text).references("chapterVersion", onDelete: .restrict)
                table.column("updatedAt", .double).notNull()
                table.uniqueKey(["conversationID", "projectID", "chapterNumber"])
            }
            try db.execute(sql: "CREATE INDEX chapterCalibration_active_version ON chapterCalibration(activeVersionID)")
            try db.create(table: "chapterToolResultSnapshot") { table in
                table.column("receiptID", .text).primaryKey().references("toolReceipt", onDelete: .restrict)
                table.column("toolID", .text).notNull()
                table.column("inputHash", .text).notNull()
                table.column("conversationID", .text).notNull().indexed().references("agentConversation", onDelete: .restrict)
                table.column("projectID", .text).notNull().indexed().references("novelProject", onDelete: .restrict)
                table.column("chapterLogicalID", .text).notNull().indexed()
                table.column("chapterNumber", .integer).notNull()
                table.column("versionID", .text).notNull().references("chapterVersion", onDelete: .restrict)
                table.column("calibrationJSON", .text).notNull()
                table.column("calibrationHash", .text).notNull()
                table.column("createdAt", .double).notNull()
            }
            try db.execute(sql: "CREATE INDEX chapterToolSnapshot_scope ON chapterToolResultSnapshot(conversationID, projectID, chapterLogicalID, createdAt DESC)")
            try db.execute(sql: """
                CREATE TRIGGER chapterVersion_immutable_update
                BEFORE UPDATE ON chapterVersion
                BEGIN
                    SELECT RAISE(ABORT, 'chapterVersion is immutable');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterVersion_immutable_delete
                BEFORE DELETE ON chapterVersion
                BEGIN
                    SELECT RAISE(ABORT, 'chapterVersion is immutable');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterVersion_integrity_insert
                BEFORE INSERT ON chapterVersion
                WHEN NEW.chapterNumber <= 0
                  OR NEW.revision <= 0
                  OR length(NEW.contentHash) = 0
                  OR length(NEW.title) = 0
                  OR length(NEW.body) = 0
                BEGIN
                    SELECT RAISE(ABORT, 'invalid chapterVersion identity');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterVersion_lineage_insert
                BEFORE INSERT ON chapterVersion
                WHEN (NEW.revision = 1 AND (NEW.parentVersionID IS NOT NULL OR NEW.logicalID <> NEW.id))
                  OR (NEW.revision > 1 AND (
                    NEW.parentVersionID IS NULL
                    OR NOT EXISTS (
                        SELECT 1 FROM chapterVersion AS parent
                        WHERE parent.id = NEW.parentVersionID
                          AND parent.logicalID = NEW.logicalID
                          AND parent.conversationID = NEW.conversationID
                          AND parent.projectID = NEW.projectID
                          AND parent.chapterNumber = NEW.chapterNumber
                          AND parent.revision = NEW.revision - 1
                    )
                  ))
                BEGIN
                    SELECT RAISE(ABORT, 'invalid chapterVersion lineage');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterCalibration_scope_insert
                BEFORE INSERT ON chapterCalibration
                WHEN NOT EXISTS (
                    SELECT 1 FROM chapterVersion AS active
                    WHERE active.id = NEW.activeVersionID
                      AND active.logicalID = NEW.chapterLogicalID
                      AND active.conversationID = NEW.conversationID
                      AND active.projectID = NEW.projectID
                      AND active.chapterNumber = NEW.chapterNumber
                )
                OR (NEW.stage = 'approvedFrozen' AND (NEW.acceptedVersionID IS NULL OR NEW.acceptedVersionID <> NEW.activeVersionID))
                OR (NEW.stage <> 'approvedFrozen' AND NEW.acceptedVersionID IS NOT NULL)
                OR (NEW.acceptedVersionID IS NOT NULL AND NOT EXISTS (
                    SELECT 1 FROM chapterVersion AS accepted
                    WHERE accepted.id = NEW.acceptedVersionID
                      AND accepted.logicalID = NEW.chapterLogicalID
                      AND accepted.conversationID = NEW.conversationID
                      AND accepted.projectID = NEW.projectID
                      AND accepted.chapterNumber = NEW.chapterNumber
                ))
                BEGIN
                    SELECT RAISE(ABORT, 'invalid chapterCalibration scope');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterCalibration_scope_update
                BEFORE UPDATE ON chapterCalibration
                WHEN NEW.chapterLogicalID <> OLD.chapterLogicalID
                  OR NEW.conversationID <> OLD.conversationID
                  OR NEW.projectID <> OLD.projectID
                  OR NEW.chapterNumber <> OLD.chapterNumber
                  OR NOT EXISTS (
                    SELECT 1 FROM chapterVersion AS active
                    WHERE active.id = NEW.activeVersionID
                      AND active.logicalID = NEW.chapterLogicalID
                      AND active.conversationID = NEW.conversationID
                      AND active.projectID = NEW.projectID
                      AND active.chapterNumber = NEW.chapterNumber
                )
                OR (NEW.stage = 'approvedFrozen' AND (NEW.acceptedVersionID IS NULL OR NEW.acceptedVersionID <> NEW.activeVersionID))
                OR (NEW.stage <> 'approvedFrozen' AND NEW.acceptedVersionID IS NOT NULL)
                OR (NEW.acceptedVersionID IS NOT NULL AND NOT EXISTS (
                    SELECT 1 FROM chapterVersion AS accepted
                    WHERE accepted.id = NEW.acceptedVersionID
                      AND accepted.logicalID = NEW.chapterLogicalID
                      AND accepted.conversationID = NEW.conversationID
                      AND accepted.projectID = NEW.projectID
                      AND accepted.chapterNumber = NEW.chapterNumber
                ))
                BEGIN
                    SELECT RAISE(ABORT, 'invalid chapterCalibration scope');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterToolResultSnapshot_immutable_update
                BEFORE UPDATE ON chapterToolResultSnapshot
                BEGIN
                    SELECT RAISE(ABORT, 'chapterToolResultSnapshot is immutable');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterToolResultSnapshot_immutable_delete
                BEFORE DELETE ON chapterToolResultSnapshot
                BEGIN
                    SELECT RAISE(ABORT, 'chapterToolResultSnapshot is immutable');
                END
                """)
        }
        migrator.registerMigration("m1c-chapter-calibration-v2") { db in
            try db.alter(table: "toolReceipt") { table in
                table.add(column: "originRunID", .text)
            }
            try db.execute(sql: "CREATE INDEX toolReceipt_origin_run ON toolReceipt(originRunID) WHERE originRunID IS NOT NULL")
            try db.execute(sql: """
                CREATE TRIGGER chapterCalibration_frozen_update
                BEFORE UPDATE ON chapterCalibration
                WHEN OLD.stage = 'approvedFrozen'
                BEGIN
                    SELECT RAISE(ABORT, 'approved chapter calibration is frozen');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterCalibration_approved_insert
                BEFORE INSERT ON chapterCalibration
                WHEN NEW.stage = 'approvedFrozen'
                BEGIN
                    SELECT RAISE(ABORT, 'approved chapter calibration must be reached by accept transition');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER chapterCalibration_approved_receipt_update
                BEFORE UPDATE ON chapterCalibration
                WHEN NEW.stage = 'approvedFrozen'
                  AND (
                    OLD.stage NOT IN ('reviewingV1', 'reviewingV2')
                    OR NEW.acceptedVersionID IS NULL
                    OR NEW.acceptedVersionID <> NEW.activeVersionID
                    OR NOT EXISTS (
                        SELECT 1
                        FROM toolReceipt AS receipt
                        JOIN chapterToolResultSnapshot AS snapshot ON snapshot.receiptID = receipt.id
                        WHERE receipt.toolID = 'chapter.accept'
                          AND receipt.toolVersion = '1'
                          AND receipt.inputSummary = 'chapter:' || NEW.activeVersionID || ':accept'
                          AND receipt.inputHash IS NOT NULL
                          AND length(trim(receipt.inputHash)) > 0
                          AND receipt.outcome = 'completed'
                          AND receipt.conversationID = NEW.conversationID
                          AND receipt.projectID = NEW.projectID
                          AND receipt.idempotencyKey IS NOT NULL
                          AND length(trim(receipt.idempotencyKey)) > 0
                          AND receipt.outputReference = NEW.activeVersionID
                          AND snapshot.toolID = receipt.toolID
                          AND snapshot.inputHash = receipt.inputHash
                          AND snapshot.conversationID = NEW.conversationID
                          AND snapshot.projectID = NEW.projectID
                          AND snapshot.chapterLogicalID = NEW.chapterLogicalID
                          AND snapshot.chapterNumber = NEW.chapterNumber
                          AND snapshot.versionID = NEW.activeVersionID
                    )
                  )
                BEGIN
                    SELECT RAISE(ABORT, 'approved chapter calibration requires accept receipt');
                END
                """)
        }
        migrator.registerMigration("m1c-origin-run-binding-v3") { db in
            try db.alter(table: "agentRun") { table in
                table.add(column: "projectID", .text)
            }
            try db.execute(sql: "CREATE INDEX agentRun_project_scope ON agentRun(conversationID, projectID)")
            try db.execute(sql: """
                UPDATE agentRun
                SET projectID = (
                    SELECT receipt.projectID
                    FROM toolReceipt AS receipt
                    WHERE receipt.originRunID = agentRun.id
                      AND receipt.conversationID = agentRun.conversationID
                      AND receipt.projectID IS NOT NULL
                    ORDER BY receipt.createdAt DESC, receipt.rowid DESC
                    LIMIT 1
                )
                WHERE projectID IS NULL
                  AND EXISTS (
                    SELECT 1
                    FROM toolReceipt AS receipt
                    WHERE receipt.originRunID = agentRun.id
                      AND receipt.conversationID = agentRun.conversationID
                      AND receipt.projectID IS NOT NULL
                )
                """)
            let invalidOriginBindingCount = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM toolReceipt AS receipt
                LEFT JOIN agentRun AS run ON run.id = receipt.originRunID
                WHERE receipt.originRunID IS NOT NULL
                  AND (
                    run.id IS NULL
                    OR run.conversationID IS NOT receipt.conversationID
                    OR run.projectID IS NOT receipt.projectID
                  )
                """
            ) ?? 0
            guard invalidOriginBindingCount == 0 else {
                throw AppDatabaseError.invalidToolReceiptReference
            }
            try db.execute(sql: """
                CREATE TRIGGER toolReceipt_origin_run_insert
                BEFORE INSERT ON toolReceipt
                WHEN NEW.originRunID IS NOT NULL
                  AND NOT EXISTS (
                    SELECT 1
                    FROM agentRun AS run
                    WHERE run.id = NEW.originRunID
                      AND run.conversationID = NEW.conversationID
                      AND run.projectID IS NEW.projectID
                )
                BEGIN
                    SELECT RAISE(ABORT, 'tool receipt origin run scope mismatch');
                END
                """)
            try db.execute(sql: """
                CREATE TRIGGER toolReceipt_origin_run_update
                BEFORE UPDATE OF originRunID, conversationID, projectID ON toolReceipt
                WHEN NEW.originRunID IS NOT NULL
                  AND NOT EXISTS (
                    SELECT 1
                    FROM agentRun AS run
                    WHERE run.id = NEW.originRunID
                      AND run.conversationID = NEW.conversationID
                      AND run.projectID IS NEW.projectID
                )
                BEGIN
                    SELECT RAISE(ABORT, 'tool receipt origin run scope mismatch');
                END
                """)
        }
        migrator.registerMigration("s1-conversation-workspace-v1") { db in
            try db.create(table: "s1ConversationDraft") { table in
                table.column("conversationID", .text)
                    .primaryKey()
                    .references("agentConversation", onDelete: .cascade)
                table.column("content", .text).notNull()
                table.column("updatedAt", .double).notNull()
            }
            try db.create(table: "s1WorkspaceState") { table in
                table.column("id", .text).primaryKey()
                table.column("selectedConversationID", .text)
                    .references("agentConversation", onDelete: .setNull)
                table.column("unboundDraft", .text).notNull()
                table.column("updatedAt", .double).notNull()
            }

            let latestConversationID = try String.fetchOne(
                db,
                sql: "SELECT id FROM agentConversation ORDER BY updatedAt DESC, rowid DESC LIMIT 1"
            )
            let legacyDraft = try String.fetchOne(
                db,
                sql: "SELECT content FROM draft WHERE id = 'm0'"
            ) ?? ""
            let legacyDraftUpdatedAt = try Double.fetchOne(
                db,
                sql: "SELECT updatedAt FROM draft WHERE id = 'm0'"
            ) ?? 0

            if let latestConversationID {
                try db.execute(
                    sql: "INSERT INTO s1ConversationDraft (conversationID, content, updatedAt) VALUES (?, ?, ?)",
                    arguments: [latestConversationID, legacyDraft, legacyDraftUpdatedAt]
                )
            }
            try db.execute(
                sql: "INSERT INTO s1WorkspaceState (id, selectedConversationID, unboundDraft, updatedAt) VALUES ('default', ?, ?, ?)",
                arguments: [
                    latestConversationID,
                    latestConversationID == nil ? legacyDraft : "",
                    legacyDraftUpdatedAt
                ]
            )
        }
        migrator.registerMigration("s1-checkpoint-scope-v1") { db in
            try db.alter(table: "checkpoint") { table in
                table.add(column: "scopeKey", .text).notNull().defaults(to: "legacy:m0")
                table.add(column: "conversationID", .text)
                    .references("agentConversation", onDelete: .restrict)
            }
            try db.create(
                index: "checkpoint_task_scope_sequence",
                on: "checkpoint",
                columns: ["taskID", "scopeKey", "sequence"]
            )
        }
        migrator.registerMigration("s1-checkpoint-conversation-retention-v1") { db in
            let orphanedScopedCheckpointCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*)
                    FROM checkpoint
                    WHERE scopeKey LIKE 's1:conversation:%'
                      AND conversationID IS NULL
                    """) ?? 0
            guard orphanedScopedCheckpointCount == 0 else {
                throw AppDatabaseError.invalidCheckpointScope
            }

            try db.execute(sql: """
                CREATE TRIGGER checkpoint_conversation_delete_restrict
                BEFORE DELETE ON agentConversation
                WHEN EXISTS (
                    SELECT 1 FROM checkpoint
                    WHERE conversationID = OLD.id
                )
                BEGIN
                    SELECT RAISE(ABORT, 'checkpoint conversation is retained');
                END
                """)
        }
        return migrator
    }
}
