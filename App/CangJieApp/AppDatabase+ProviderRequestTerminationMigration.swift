import GRDB

extension AppDatabase {
    static func migrateProviderRequestTermination(_ db: Database) throws {
        guard let tableSQL = try String.fetchOne(
            db,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name = 'providerRequest'
                """
        ) else {
            throw AppDatabaseError.invalidProviderRequest
        }
        let oldFragment = "'responseComplete', 'continuationCommitted',"
        let newFragment =
            "'responseComplete', 'continuationCommitted', 'terminated',"
        let parts = tableSQL.components(separatedBy: oldFragment)
        guard parts.count == 2,
              !tableSQL.contains("'terminated'") else {
            throw AppDatabaseError.invalidProviderRequest
        }
        let migratedSQL = parts[0] + newFragment + parts[1]

        try db.execute(sql: "PRAGMA writable_schema = ON")
        defer { try? db.execute(sql: "PRAGMA writable_schema = OFF") }
        try db.execute(
            sql: """
                UPDATE sqlite_master
                SET sql = ?
                WHERE type = 'table' AND name = 'providerRequest' AND sql = ?
                """,
            arguments: [migratedSQL, tableSQL]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.invalidProviderRequest
        }
        try db.execute(sql: "PRAGMA writable_schema = OFF")

        let schemaVersion = try Int.fetchOne(
            db,
            sql: "PRAGMA schema_version"
        ) ?? 0
        guard schemaVersion < Int.max else {
            throw AppDatabaseError.invalidProviderRequest
        }
        try db.execute(sql: "PRAGMA schema_version = \(schemaVersion + 1)")

        try db.execute(sql: "DROP TRIGGER providerRequest_phase_transition_guard")
        try db.execute(sql: """
            CREATE TRIGGER providerRequest_phase_transition_guard
            BEFORE UPDATE OF phase ON providerRequest
            WHEN NOT (
                (OLD.phase = 'prepared' AND NEW.phase IN ('sending', 'cancelled', 'failed'))
                OR (OLD.phase = 'sending' AND NEW.phase IN ('streaming', 'failed', 'outcomeUnknown'))
                OR (OLD.phase = 'streaming' AND NEW.phase IN ('streaming', 'responseComplete', 'outcomeUnknown'))
                OR (OLD.phase = 'responseComplete' AND NEW.phase IN ('continuationCommitted', 'terminated'))
            )
            BEGIN
                SELECT RAISE(ABORT, 'invalid provider request transition');
            END
            """)

        let integrity = try String.fetchOne(db, sql: "PRAGMA integrity_check")
        let violations = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM pragma_foreign_key_check"
        ) ?? 0
        guard integrity == "ok", violations == 0 else {
            throw AppDatabaseError.invalidProviderRequest
        }
    }
}
