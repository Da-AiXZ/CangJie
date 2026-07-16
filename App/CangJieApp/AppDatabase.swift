import Foundation
import GRDB

struct NovelProject: Identifiable, Equatable {
    let id: UUID
    let title: String
    let premise: String
    let createdAt: Date
    let updatedAt: Date
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

enum AppDatabaseError: Error {
    case writeAheadLoggingUnavailable(actualMode: String)
    case invalidCheckpointIdentifier
    case checkpointTaskMismatch
}

final class AppDatabase {
    private let queue: DatabaseQueue

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
        let project = NovelProject(id: UUID(), title: title, premise: premise, createdAt: now, updatedAt: now)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO novelProject (id, title, premise, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)", arguments: [project.id.uuidString, project.title, project.premise, project.createdAt.timeIntervalSince1970, project.updatedAt.timeIntervalSince1970])
        }
        return project
    }

    func listProjects() throws -> [NovelProject] {
        try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM novelProject ORDER BY updatedAt DESC").compactMap { row in
                guard let id = UUID(uuidString: row["id"]) else { return nil }
                return NovelProject(id: id, title: row["title"], premise: row["premise"], createdAt: Date(timeIntervalSince1970: row["createdAt"]), updatedAt: Date(timeIntervalSince1970: row["updatedAt"]))
            }
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
        return migrator
    }
}
