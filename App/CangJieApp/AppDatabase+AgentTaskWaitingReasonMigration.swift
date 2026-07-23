import GRDB

extension AppDatabase {
    static func migrateAgentTaskWaitingReason(_ db: Database) throws {
        try db.execute(sql: """
            ALTER TABLE agentTask ADD COLUMN waitingReason TEXT CHECK (
                waitingReason IS NULL
                OR waitingReason IN ('networkConfirmation', 'connectionInvalid')
            )
            """)
        try db.execute(sql: """
            UPDATE agentTask
            SET waitingReason = 'connectionInvalid'
            WHERE status = 'waitingUser'
            """)
        try db.execute(sql: """
            ALTER TABLE agentTaskEvent ADD COLUMN fromWaitingReason TEXT CHECK (
                fromWaitingReason IS NULL
                OR fromWaitingReason IN (
                    'networkConfirmation', 'connectionInvalid'
                )
            )
            """)
        try db.execute(sql: """
            ALTER TABLE agentTaskEvent ADD COLUMN toWaitingReason TEXT CHECK (
                toWaitingReason IS NULL
                OR toWaitingReason IN (
                    'networkConfirmation', 'connectionInvalid'
                )
            )
            """)
        try db.execute(sql: """
            UPDATE agentTaskEvent
            SET fromWaitingReason = 'connectionInvalid'
            WHERE fromStatus = 'waitingUser'
            """)
        try db.execute(sql: """
            UPDATE agentTaskEvent
            SET toWaitingReason = 'connectionInvalid'
            WHERE toStatus = 'waitingUser'
            """)
        try db.execute(sql: """
            CREATE TRIGGER agentTask_waiting_reason_insert
            BEFORE INSERT ON agentTask
            WHEN (
                NEW.status = 'waitingUser'
                AND NEW.waitingReason IS NULL
            ) OR (
                NEW.status <> 'waitingUser'
                AND NEW.waitingReason IS NOT NULL
            )
            BEGIN
                SELECT RAISE(ABORT, 'invalid agent task waiting reason');
            END
            """)
        try db.execute(sql: """
            CREATE TRIGGER agentTask_waiting_reason_update
            BEFORE UPDATE OF status, waitingReason ON agentTask
            WHEN (
                NEW.status = 'waitingUser'
                AND NEW.waitingReason IS NULL
            ) OR (
                NEW.status <> 'waitingUser'
                AND NEW.waitingReason IS NOT NULL
            )
            BEGIN
                SELECT RAISE(ABORT, 'invalid agent task waiting reason');
            END
            """)
    }
}
