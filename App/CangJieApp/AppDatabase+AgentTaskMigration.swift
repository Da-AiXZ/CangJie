import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    static func migrateAgentTaskControl(_ db: Database) throws {
        try createAgentTaskTables(in: db)
        try db.execute(
            sql: "ALTER TABLE agentRun ADD COLUMN taskID TEXT REFERENCES agentTask(id) ON DELETE RESTRICT"
        )
        try db.execute(
            sql: "ALTER TABLE pendingModelIntent ADD COLUMN resolutionKind TEXT CHECK (resolutionKind IN ('kept', 'discarded'))"
        )
        try db.execute(
            sql: "ALTER TABLE pendingModelIntent ADD COLUMN resolvedTaskID TEXT REFERENCES agentTask(id) ON DELETE RESTRICT"
        )
        try backfillAgentTasks(in: db)
        try replacePendingIntentConsumptionGuard(in: db)
        try db.execute(sql: """
            CREATE TRIGGER pendingModelIntent_resolution_immutable
            BEFORE UPDATE OF resolutionKind, resolvedTaskID
            ON pendingModelIntent
            WHEN OLD.consumedAt IS NOT NULL
              OR OLD.resolutionKind IS NOT NULL
              OR OLD.resolvedTaskID IS NOT NULL
            BEGIN
                SELECT RAISE(ABORT, 'pending intent resolution is immutable');
            END
            """)
    }

    private static func createAgentTaskTables(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE agentTask (
                id TEXT PRIMARY KEY NOT NULL,
                intentID TEXT NOT NULL UNIQUE
                    REFERENCES pendingModelIntent(id) ON DELETE RESTRICT,
                conversationID TEXT NOT NULL
                    REFERENCES agentConversation(id) ON DELETE RESTRICT,
                projectID TEXT
                    REFERENCES novelProject(id) ON DELETE RESTRICT,
                branchID TEXT,
                status TEXT NOT NULL CHECK (
                    status IN (
                        'queued', 'running', 'pauseRequested', 'reconciling',
                        'paused', 'stopRequested', 'waitingUser', 'completed',
                        'failed', 'discarded'
                    )
                ),
                outcome TEXT CHECK (outcome IN ('natural', 'kept', 'discarded')),
                requestedControl TEXT CHECK (
                    requestedControl IN ('pauseNow', 'stopKeepingResults')
                ),
                revision INTEGER NOT NULL CHECK (revision > 0),
                queueOrdinal INTEGER NOT NULL UNIQUE CHECK (queueOrdinal > 0),
                primarySlot INTEGER CHECK (primarySlot = 1),
                activeRunID TEXT
                    REFERENCES agentRun(id) ON DELETE RESTRICT,
                enqueueCommandID TEXT NOT NULL UNIQUE,
                createdAt DOUBLE NOT NULL,
                updatedAt DOUBLE NOT NULL,
                CHECK (branchID IS NULL OR projectID IS NOT NULL),
                CHECK (
                    (status = 'completed' AND outcome IN ('natural', 'kept'))
                    OR (status = 'discarded' AND outcome = 'discarded')
                    OR (
                        status NOT IN ('completed', 'discarded')
                        AND outcome IS NULL
                    )
                ),
                CHECK (
                    (status = 'pauseRequested' AND requestedControl = 'pauseNow')
                    OR (
                        status = 'stopRequested'
                        AND requestedControl = 'stopKeepingResults'
                    )
                    OR (
                        status = 'reconciling'
                        AND (
                            requestedControl IS NULL
                            OR requestedControl IN (
                                'pauseNow', 'stopKeepingResults'
                            )
                        )
                    )
                    OR (
                        status NOT IN (
                            'pauseRequested', 'stopRequested', 'reconciling'
                        )
                        AND requestedControl IS NULL
                    )
                ),
                CHECK (
                    (
                        status IN (
                            'running', 'pauseRequested', 'reconciling',
                            'paused', 'stopRequested', 'waitingUser'
                        )
                        AND primarySlot = 1
                    )
                    OR (
                        status NOT IN (
                            'running', 'pauseRequested', 'reconciling',
                            'paused', 'stopRequested', 'waitingUser'
                        )
                        AND primarySlot IS NULL
                    )
                )
            )
            """)
        try db.execute(sql: """
            CREATE UNIQUE INDEX agentTask_one_primary
            ON agentTask (primarySlot)
            WHERE primarySlot IS NOT NULL
            """)
        try db.execute(sql: """
            CREATE INDEX agentTask_queue
            ON agentTask (status, queueOrdinal)
            """)
        try db.execute(sql: """
            CREATE TABLE agentTaskEvent (
                commandID TEXT PRIMARY KEY NOT NULL,
                taskID TEXT NOT NULL
                    REFERENCES agentTask(id) ON DELETE RESTRICT,
                expectedRevision INTEGER NOT NULL CHECK (expectedRevision >= 0),
                resultRevision INTEGER NOT NULL CHECK (
                    resultRevision = expectedRevision + 1
                ),
                fromStatus TEXT,
                fromOutcome TEXT,
                fromRequestedControl TEXT,
                toStatus TEXT NOT NULL,
                toOutcome TEXT,
                toRequestedControl TEXT,
                hasAdoptedOutput INTEGER NOT NULL CHECK (
                    hasAdoptedOutput IN (0, 1)
                ),
                resultActiveRunID TEXT,
                resultQueueOrdinal INTEGER NOT NULL CHECK (
                    resultQueueOrdinal > 0
                ),
                promotedTaskID TEXT
                    REFERENCES agentTask(id) ON DELETE RESTRICT,
                promotedRevision INTEGER,
                promotedQueueOrdinal INTEGER,
                promotedActiveRunID TEXT,
                promotedUpdatedAt DOUBLE,
                createdAt DOUBLE NOT NULL,
                UNIQUE (taskID, resultRevision)
            )
            """)
    }

    private static func backfillAgentTasks(in db: Database) throws {
        let rows = try Row.fetchAll(db, sql: """
            SELECT intent.*, request.runID AS latestRunID,
                   request.phase AS latestPhase,
                   request.updatedAt AS latestRequestUpdatedAt
            FROM pendingModelIntent AS intent
            JOIN providerRequest AS request
              ON request.intentID = intent.id
            WHERE request.rowid = (
                SELECT latest.rowid
                FROM providerRequest AS latest
                WHERE latest.intentID = intent.id
                ORDER BY latest.attemptNumber DESC,
                         latest.turnSequence DESC,
                         latest.rowid DESC
                LIMIT 1
            )
            ORDER BY intent.createdAt ASC, intent.rowid ASC
            """)
        var primaryCount = 0
        var queueOrdinal: Int64 = 0
        for row in rows {
            let intent = try decodePendingModelIntent(row)
            let phaseText: String = row["latestPhase"]
            guard let phase = ProviderRequestPhase(rawValue: phaseText),
                  let runID = UUID(uuidString: row["latestRunID"]) else {
                throw AppDatabaseError.invalidAgentTask
            }
            queueOrdinal += 1
            let state = try migratedAgentTaskState(for: phase)
            let primarySlot: Int? = isPrimaryAgentTaskStatus(state.status)
                ? 1
                : nil
            if primarySlot != nil {
                primaryCount += 1
            }
            guard primaryCount <= 1 else {
                throw AppDatabaseError.invalidAgentTask
            }
            let taskID = UUID()
            let commandID = UUID()
            let updatedAt: Double = row["latestRequestUpdatedAt"]
            try db.execute(
                sql: """
                    INSERT INTO agentTask (
                        id, intentID, conversationID, projectID, branchID,
                        status, outcome, requestedControl, revision,
                        queueOrdinal, primarySlot,
                        activeRunID, enqueueCommandID, createdAt, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 1, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    taskID.uuidString,
                    intent.id.uuidString,
                    intent.conversationID.uuidString,
                    intent.projectID?.uuidString,
                    intent.branchID?.uuidString,
                    state.status.rawValue,
                    state.outcome?.rawValue,
                    queueOrdinal,
                    primarySlot,
                    runID.uuidString,
                    commandID.uuidString,
                    intent.createdAt.timeIntervalSince1970,
                    updatedAt
                ]
            )
            try insertMigratedAgentTaskEvent(
                commandID: commandID,
                taskID: taskID,
                state: state,
                activeRunID: runID,
                queueOrdinal: queueOrdinal,
                createdAt: updatedAt,
                in: db
            )
        }
        try db.execute(sql: """
            UPDATE agentRun
            SET taskID = (
                SELECT task.id
                FROM providerRequest AS request
                JOIN agentTask AS task ON task.intentID = request.intentID
                WHERE request.runID = agentRun.id
                ORDER BY request.attemptNumber DESC,
                         request.turnSequence DESC,
                         request.rowid DESC
                LIMIT 1
            )
            WHERE kind = 'providerTurn'
              AND EXISTS (
                  SELECT 1 FROM providerRequest
                  WHERE providerRequest.runID = agentRun.id
              )
            """)
        let unboundCount = try Int.fetchOne(db, sql: """
            SELECT COUNT(*)
            FROM agentRun
            WHERE kind = 'providerTurn'
              AND taskID IS NULL
              AND EXISTS (
                  SELECT 1 FROM providerRequest
                  WHERE providerRequest.runID = agentRun.id
              )
            """) ?? 0
        guard unboundCount == 0 else {
            throw AppDatabaseError.invalidAgentTask
        }
    }

    private static func migratedAgentTaskState(
        for phase: ProviderRequestPhase
    ) throws -> AgentTaskControlState {
        switch phase {
        case .prepared, .sending, .streaming, .responseComplete:
            return try AgentTaskControlState(status: .running)
        case .outcomeUnknown:
            return try AgentTaskControlState(status: .reconciling)
        case .continuationCommitted:
            return try AgentTaskControlState(
                status: .completed,
                outcome: .natural
            )
        case .cancelled, .failed:
            return try AgentTaskControlState(status: .failed)
        }
    }

    private static func insertMigratedAgentTaskEvent(
        commandID: UUID,
        taskID: UUID,
        state: AgentTaskControlState,
        activeRunID: UUID,
        queueOrdinal: Int64,
        createdAt: Double,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
                INSERT INTO agentTaskEvent (
                    commandID, taskID, expectedRevision, resultRevision,
                    fromStatus, fromOutcome, fromRequestedControl,
                    toStatus, toOutcome, toRequestedControl,
                    hasAdoptedOutput, resultActiveRunID, resultQueueOrdinal,
                    promotedTaskID,
                    promotedRevision, promotedQueueOrdinal,
                    promotedActiveRunID, promotedUpdatedAt, createdAt
                ) VALUES (
                    ?, ?, 0, 1, NULL, NULL, NULL, ?, ?, NULL,
                    0, ?, ?, NULL, NULL, NULL, NULL, NULL, ?
                )
                """,
            arguments: [
                commandID.uuidString,
                taskID.uuidString,
                state.status.rawValue,
                state.outcome?.rawValue,
                activeRunID.uuidString,
                queueOrdinal,
                createdAt
            ]
        )
    }

    private static func replacePendingIntentConsumptionGuard(
        in db: Database
    ) throws {
        try db.execute(sql: "DROP TRIGGER pendingModelIntent_consumption_guard")
        try db.execute(sql: """
            CREATE TRIGGER pendingModelIntent_consumption_guard
            BEFORE UPDATE OF consumedAt, continuationRequestID,
                             resolutionKind, resolvedTaskID
            ON pendingModelIntent
            WHEN OLD.consumedAt IS NULL
              AND NEW.consumedAt IS NOT NULL
              AND NOT (
                (
                    NEW.resolutionKind IS NULL
                    AND NEW.resolvedTaskID IS NULL
                    AND EXISTS (
                        SELECT 1
                        FROM providerRequest AS request
                        WHERE request.id = NEW.continuationRequestID
                          AND request.intentID = NEW.id
                          AND request.conversationID = NEW.conversationID
                          AND request.phase = 'continuationCommitted'
                    )
                )
                OR (
                    NEW.continuationRequestID IS NULL
                    AND NEW.resolutionKind IN ('kept', 'discarded')
                    AND EXISTS (
                        SELECT 1
                        FROM agentTask AS task
                        WHERE task.id = NEW.resolvedTaskID
                          AND task.intentID = NEW.id
                          AND task.conversationID = NEW.conversationID
                          AND (
                            (
                                NEW.resolutionKind = 'kept'
                                AND task.status = 'completed'
                                AND task.outcome = 'kept'
                            )
                            OR (
                                NEW.resolutionKind = 'discarded'
                                AND task.status = 'discarded'
                                AND task.outcome = 'discarded'
                            )
                          )
                    )
                )
              )
            BEGIN
                SELECT RAISE(ABORT, 'pending intent requires settled task');
            END
            """)
    }

    static func isPrimaryAgentTaskStatus(_ status: AgentTaskStatus) -> Bool {
        switch status {
        case .running, .pauseRequested, .reconciling, .paused,
             .stopRequested, .waitingUser:
            return true
        case .queued, .completed, .failed, .discarded:
            return false
        }
    }
}
