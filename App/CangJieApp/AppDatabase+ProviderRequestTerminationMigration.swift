import GRDB

extension AppDatabase {
    static func migrateProviderRequestTermination(_ db: Database) throws {
        guard let tableSQL = try String.fetchOne(
            db,
            sql: """
                SELECT sql FROM sqlite_master
                WHERE type = 'table' AND name = 'providerRequest'
                """
        ), tableSQL.contains("'responseComplete', 'continuationCommitted',"),
           !tableSQL.contains("'terminated'") else {
            throw AppDatabaseError.invalidProviderRequest
        }

        try db.execute(sql: """
            CREATE TABLE providerRequest_v4 (
                id TEXT PRIMARY KEY NOT NULL,
                idempotencyKey TEXT NOT NULL UNIQUE,
                intentID TEXT NOT NULL
                    REFERENCES pendingModelIntent(id) ON DELETE RESTRICT,
                conversationID TEXT NOT NULL
                    REFERENCES agentConversation(id) ON DELETE RESTRICT,
                projectID TEXT
                    REFERENCES novelProject(id) ON DELETE RESTRICT,
                runID TEXT NOT NULL
                    REFERENCES agentRun(id) ON DELETE RESTRICT,
                attemptNumber INTEGER NOT NULL CHECK (
                    attemptNumber BETWEEN 1 AND 8
                ),
                turnSequence INTEGER NOT NULL CHECK (
                    turnSequence BETWEEN 1 AND 8
                ),
                previousRequestID TEXT
                    REFERENCES providerRequest_v4(id) ON DELETE RESTRICT,
                connectionID TEXT NOT NULL
                    REFERENCES modelConnection(id) ON DELETE RESTRICT,
                responseAssetID TEXT NOT NULL UNIQUE
                    REFERENCES providerResponseAsset(id) ON DELETE RESTRICT,
                phase TEXT NOT NULL CHECK (
                    phase IN (
                        'prepared', 'sending', 'streaming',
                        'responseComplete', 'continuationCommitted', 'terminated',
                        'cancelled', 'failed', 'outcomeUnknown'
                    )
                ),
                payloadVersion INTEGER NOT NULL CHECK (payloadVersion = 1),
                payloadJSON TEXT NOT NULL,
                payloadHash TEXT NOT NULL CHECK (
                    length(payloadHash) = 64
                    AND payloadHash NOT GLOB '*[^0-9a-f]*'
                ),
                createdAt DOUBLE NOT NULL,
                updatedAt DOUBLE NOT NULL,
                CHECK (
                    (
                        attemptNumber = 1
                        AND turnSequence = 1
                        AND previousRequestID IS NULL
                    )
                    OR (
                        NOT (attemptNumber = 1 AND turnSequence = 1)
                        AND previousRequestID IS NOT NULL
                    )
                )
            )
            """)
        try db.execute(sql: """
            INSERT INTO providerRequest_v4 (
                id, idempotencyKey, intentID, conversationID, projectID,
                runID, attemptNumber, turnSequence, previousRequestID,
                connectionID, responseAssetID, phase, payloadVersion,
                payloadJSON, payloadHash, createdAt, updatedAt
            )
            SELECT
                id, idempotencyKey, intentID, conversationID, projectID,
                runID, attemptNumber, turnSequence, previousRequestID,
                connectionID, responseAssetID, phase, payloadVersion,
                payloadJSON, payloadHash, createdAt, updatedAt
            FROM providerRequest
            """)
        try db.execute(sql: "DROP TABLE providerRequest")
        try db.execute(
            sql: "ALTER TABLE providerRequest_v4 RENAME TO providerRequest"
        )

        try db.execute(sql: """
            CREATE INDEX providerRequest_conversation_updated
            ON providerRequest (conversationID, updatedAt DESC)
            """)
        try db.execute(sql: """
            CREATE UNIQUE INDEX providerRequest_intent_attempt_turn
            ON providerRequest (intentID, attemptNumber, turnSequence)
            """)
        try db.execute(sql: """
            CREATE UNIQUE INDEX providerRequest_previous_unique
            ON providerRequest (previousRequestID)
            WHERE previousRequestID IS NOT NULL
            """)
        try db.execute(sql: """
            CREATE UNIQUE INDEX providerRequest_intent_active
            ON providerRequest (intentID)
            WHERE phase IN (
                'prepared', 'sending', 'streaming', 'outcomeUnknown'
            )
            """)
        try db.execute(sql: """
            CREATE INDEX providerRequest_run_sequence
            ON providerRequest (runID, attemptNumber, turnSequence)
            """)
        try db.execute(sql: """
            CREATE TRIGGER providerRequest_identity_immutable
            BEFORE UPDATE OF
                id, idempotencyKey, intentID, conversationID, projectID,
                runID, attemptNumber, turnSequence, previousRequestID,
                connectionID, responseAssetID, createdAt
            ON providerRequest
            BEGIN
                SELECT RAISE(ABORT, 'provider request identity is immutable');
            END
            """)
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
