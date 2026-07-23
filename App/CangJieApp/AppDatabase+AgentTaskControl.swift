import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    func enqueueAgentTask(
        for intent: PendingModelIntent,
        commandID: UUID,
        now: Date = Date()
    ) throws -> AgentTaskSnapshot {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            try Self.enqueueAgentTask(
                for: intent,
                commandID: commandID,
                now: timestamp,
                in: db
            )
        }
    }

    static func enqueueAgentTask(
        for intent: PendingModelIntent,
        commandID: UUID,
        now: Date,
        in db: Database
    ) throws -> AgentTaskSnapshot {
        guard let intentRow = try Row.fetchOne(
            db,
            sql: "SELECT * FROM pendingModelIntent WHERE id = ? AND consumedAt IS NULL",
            arguments: [intent.id.uuidString]
        ), try decodePendingModelIntent(intentRow) == intent else {
            throw AppDatabaseError.invalidAgentTask
        }
        if let existingRow = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentTask WHERE intentID = ?",
            arguments: [intent.id.uuidString]
        ) {
            let storedCommandID: String = existingRow["enqueueCommandID"]
            guard storedCommandID == commandID.uuidString else {
                throw AppDatabaseError.idempotencyConflict
            }
            return try decodeAgentTask(existingRow)
        }
        guard try Row.fetchOne(
            db,
            sql: "SELECT commandID FROM agentTaskEvent WHERE commandID = ?",
            arguments: [commandID.uuidString]
        ) == nil else {
            throw AppDatabaseError.idempotencyConflict
        }
        let nextOrdinal = try nextAgentTaskQueueOrdinal(in: db)
        let hasPrimary = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM agentTask WHERE primarySlot = 1"
        ) ?? 0
        guard hasPrimary == 0 || hasPrimary == 1 else {
            throw AppDatabaseError.invalidAgentTask
        }
        let status: AgentTaskStatus = hasPrimary == 0 ? .running : .queued
        let taskID = UUID()
        try db.execute(
            sql: """
                INSERT INTO agentTask (
                    id, intentID, conversationID, projectID, branchID,
                    status, outcome, requestedControl, revision,
                    queueOrdinal, primarySlot,
                    activeRunID, enqueueCommandID, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, 1, ?, ?, NULL, ?, ?, ?)
                """,
            arguments: [
                taskID.uuidString,
                intent.id.uuidString,
                intent.conversationID.uuidString,
                intent.projectID?.uuidString,
                intent.branchID?.uuidString,
                status.rawValue,
                nextOrdinal,
                isPrimaryAgentTaskStatus(status) ? 1 : nil,
                commandID.uuidString,
                now.timeIntervalSince1970,
                now.timeIntervalSince1970
            ]
        )
        try insertAgentTaskEvent(
            commandID: commandID,
            taskID: taskID,
            expectedRevision: 0,
            from: nil,
            to: try AgentTaskControlState(status: status),
            fromRequestedControl: nil,
            toRequestedControl: nil,
            hasAdoptedOutput: false,
            resultActiveRunID: nil,
            resultQueueOrdinal: nextOrdinal,
            promoted: nil,
            now: now,
            in: db
        )
        return try requiredAgentTask(id: taskID, in: db)
    }

    func agentTask(id: UUID) throws -> AgentTaskSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentTask WHERE id = ?",
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try Self.decodeAgentTask(row)
        }
    }

    func agentTask(intentID: UUID) throws -> AgentTaskSnapshot? {
        try queue.read { db in
            try Self.agentTask(intentID: intentID, in: db)
        }
    }

    static func agentTask(
        intentID: UUID,
        in db: Database
    ) throws -> AgentTaskSnapshot? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentTask WHERE intentID = ?",
            arguments: [intentID.uuidString]
        ) else {
            return nil
        }
        return try decodeAgentTask(row)
    }

    func activeAgentTask() throws -> AgentTaskSnapshot? {
        try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT * FROM agentTask WHERE primarySlot = 1"
            )
            guard rows.count <= 1 else {
                throw AppDatabaseError.invalidAgentTask
            }
            return try rows.first.map(Self.decodeAgentTask)
        }
    }

    func queuedAgentTasks() throws -> [AgentTaskSnapshot] {
        try queue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM agentTask WHERE status = 'queued' ORDER BY queueOrdinal ASC"
            ).map(Self.decodeAgentTask)
        }
    }

    static func bindAgentRun(
        _ runID: UUID,
        to taskID: UUID,
        now: Date,
        in db: Database
    ) throws -> AgentTaskSnapshot {
        let current = try requiredAgentTask(id: taskID, in: db)
        guard current.status == .running || current.status == .queued else {
            throw AppDatabaseError.invalidAgentTask
        }
        if current.activeRunID == runID {
            return current
        }
        if let event = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentTaskEvent WHERE commandID = ?",
            arguments: [runID.uuidString]
        ) {
            let eventTaskID: String = event["taskID"]
            let resultActiveRunID: String? = event["resultActiveRunID"]
            guard eventTaskID == taskID.uuidString,
                  resultActiveRunID == runID.uuidString else {
                throw AppDatabaseError.idempotencyConflict
            }
            return current
        }
        let nextRevision = current.revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            throw AppDatabaseError.invalidAgentTask
        }
        try db.execute(
            sql: """
                UPDATE agentTask
                SET activeRunID = ?, revision = ?, updatedAt = ?
                WHERE id = ? AND revision = ?
                """,
            arguments: [
                runID.uuidString,
                nextRevision.partialValue,
                now.timeIntervalSince1970,
                taskID.uuidString,
                current.revision
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.agentTaskRevisionConflict
        }
        try db.execute(
            sql: """
                UPDATE agentRun
                SET taskID = ?
                WHERE id = ? AND (taskID IS NULL OR taskID = ?)
                """,
            arguments: [
                taskID.uuidString,
                runID.uuidString,
                taskID.uuidString
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.invalidAgentRun
        }
        let state = try AgentTaskControlState(
            status: current.status,
            outcome: current.outcome
        )
        try insertAgentTaskEvent(
            commandID: runID,
            taskID: taskID,
            expectedRevision: current.revision,
            from: state,
            to: state,
            fromRequestedControl: current.requestedControl,
            toRequestedControl: current.requestedControl,
            hasAdoptedOutput: false,
            resultActiveRunID: runID,
            resultQueueOrdinal: current.queueOrdinal,
            promoted: nil,
            now: now,
            in: db
        )
        return try requiredAgentTask(id: taskID, in: db)
    }

    func settleAgentTaskControlAfterProviderExit(
        intentID: UUID,
        now: Date = Date()
    ) throws -> AgentTaskSnapshot? {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            guard let task = try Self.agentTask(intentID: intentID, in: db),
                  task.status == .pauseRequested
                    || task.status == .stopRequested else {
                return try Self.agentTask(intentID: intentID, in: db)
            }
            guard let requestRow = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM providerRequest
                    WHERE intentID = ?
                    ORDER BY attemptNumber DESC, turnSequence DESC, rowid DESC
                    LIMIT 1
                    """,
                arguments: [intentID.uuidString]
            ) else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let request = try Self.decodeProviderRequest(requestRow)
            switch request.phase {
            case .prepared:
                let cancelled = try ProviderRequestLifecycle.cancel(
                    request,
                    now: timestamp
                )
                try Self.updateProviderRequestRow(
                    cancelled,
                    expectedPayloadHash: Self.payloadHash(
                        try Self.encodeProviderRequest(request)
                    ),
                    in: db
                )
                try Self.updateProviderBackedRun(cancelled, in: db)
            case .sending, .streaming:
                let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
                    request,
                    reason: .cancelled,
                    now: timestamp
                )
                try Self.updateProviderRequestRow(
                    unknown,
                    expectedPayloadHash: Self.payloadHash(
                        try Self.encodeProviderRequest(request)
                    ),
                    in: db
                )
                try Self.updateProviderBackedRun(unknown, in: db)
            case .responseComplete:
                let target: AgentTaskStatus = task.status == .pauseRequested
                    ? .paused
                    : .completed
                let outcome: AgentTaskOutcome? = task.status == .stopRequested
                    ? .kept
                    : nil
                _ = try Self.transitionAgentTask(
                    id: task.id,
                    expectedRevision: task.revision,
                    commandID: UUID(),
                    to: target,
                    outcome: outcome,
                    now: timestamp,
                    in: db
                )
            case .cancelled, .failed, .outcomeUnknown,
                 .continuationCommitted:
                try Self.synchronizeAgentTask(for: request, in: db)
            }
            return try Self.agentTask(intentID: intentID, in: db)
        }
    }

    func transitionAgentTask(
        id: UUID,
        expectedRevision: Int,
        commandID: UUID,
        to status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        hasAdoptedOutput: Bool = false,
        now: Date = Date()
    ) throws -> AgentTaskTransitionResult {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            try Self.transitionAgentTask(
                id: id,
                expectedRevision: expectedRevision,
                commandID: commandID,
                to: status,
                outcome: outcome,
                hasAdoptedOutput: hasAdoptedOutput,
                now: timestamp,
                in: db
            )
        }
    }

    func retryFailedAgentTask(
        id: UUID,
        expectedRevision: Int,
        commandID: UUID,
        now: Date = Date()
    ) throws -> AgentTaskSnapshot {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            if let event = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentTaskEvent WHERE commandID = ?",
                arguments: [commandID.uuidString]
            ) {
                let replay = try Self.replayAgentTaskTransition(
                    event,
                    taskID: id,
                    expectedRevision: expectedRevision,
                    status: .queued,
                    outcome: nil,
                    hasAdoptedOutput: false,
                    in: db
                )
                if let promoted = replay.promotedTask,
                   promoted.id == id {
                    return promoted
                }
                return replay.task
            }
            let transition = try Self.transitionAgentTask(
                id: id,
                expectedRevision: expectedRevision,
                commandID: commandID,
                to: .queued,
                now: timestamp,
                in: db
            )
            let primaryCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM agentTask WHERE primarySlot = 1"
            ) ?? 0
            guard primaryCount == 0 || primaryCount == 1 else {
                throw AppDatabaseError.invalidAgentTask
            }
            if primaryCount == 0,
               let promoted = try Self.promoteNextAgentTask(
                    now: timestamp,
                    in: db
               ) {
                try db.execute(
                    sql: """
                        UPDATE agentTaskEvent
                        SET promotedTaskID = ?, promotedRevision = ?,
                            promotedQueueOrdinal = ?, promotedActiveRunID = ?,
                            promotedUpdatedAt = ?
                        WHERE commandID = ?
                          AND promotedTaskID IS NULL
                        """,
                    arguments: [
                        promoted.id.uuidString,
                        promoted.revision,
                        promoted.queueOrdinal,
                        promoted.activeRunID?.uuidString,
                        promoted.updatedAt.timeIntervalSince1970,
                        commandID.uuidString
                    ]
                )
                return promoted.id == id ? promoted : transition.task
            }
            return transition.task
        }
    }

    static func transitionAgentTask(
        id: UUID,
        expectedRevision: Int,
        commandID: UUID,
        to status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        hasAdoptedOutput: Bool = false,
        now: Date,
        in db: Database
    ) throws -> AgentTaskTransitionResult {
        if let event = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentTaskEvent WHERE commandID = ?",
            arguments: [commandID.uuidString]
        ) {
            return try replayAgentTaskTransition(
                event,
                taskID: id,
                expectedRevision: expectedRevision,
                status: status,
                outcome: outcome,
                hasAdoptedOutput: hasAdoptedOutput,
                in: db
            )
        }
        let current = try requiredAgentTask(id: id, in: db)
        guard current.revision == expectedRevision,
              now >= current.updatedAt else {
            throw AppDatabaseError.agentTaskRevisionConflict
        }
        let committedSideEffectCount = try Int.fetchOne(
            db,
            sql: """
                SELECT COUNT(*)
                FROM toolReceipt AS receipt
                JOIN agentRun AS run ON run.id = receipt.originRunID
                WHERE run.taskID = ?
                  AND receipt.outcome = 'completed'
                """,
            arguments: [id.uuidString]
        ) ?? 0
        let effectiveAdoption = hasAdoptedOutput || committedSideEffectCount > 0
        let currentState = try AgentTaskControlState(
            status: current.status,
            outcome: current.outcome
        )
        let nextState = try AgentTaskControlMachine().transition(
            currentState,
            to: status,
            outcome: outcome,
            hasAdoptedOutput: effectiveAdoption
        )
        let nextRequestedControl: AgentTaskRequestedControl?
        switch nextState.status {
        case .pauseRequested:
            nextRequestedControl = .pauseNow
        case .stopRequested:
            nextRequestedControl = .stopKeepingResults
        case .reconciling:
            nextRequestedControl = current.requestedControl
        case .queued, .running, .paused, .waitingUser, .completed,
             .failed, .discarded:
            nextRequestedControl = nil
        }
        let nextQueueOrdinal: Int64
        if current.status == .failed && nextState.status == .queued {
            nextQueueOrdinal = try nextAgentTaskQueueOrdinal(in: db)
        } else {
            nextQueueOrdinal = current.queueOrdinal
        }
        let nextRevision = current.revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            throw AppDatabaseError.invalidAgentTask
        }
        try db.execute(
            sql: """
                UPDATE agentTask
                SET status = ?, outcome = ?, requestedControl = ?,
                    revision = ?, queueOrdinal = ?, primarySlot = ?,
                    updatedAt = ?
                WHERE id = ? AND revision = ?
                """,
            arguments: [
                nextState.status.rawValue,
                nextState.outcome?.rawValue,
                nextRequestedControl?.rawValue,
                nextRevision.partialValue,
                nextQueueOrdinal,
                isPrimaryAgentTaskStatus(nextState.status) ? 1 : nil,
                now.timeIntervalSince1970,
                id.uuidString,
                expectedRevision
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.agentTaskRevisionConflict
        }
        let updated = try requiredAgentTask(id: id, in: db)
        if updated.outcome == .kept || updated.outcome == .discarded {
            try resolveAgentTaskIntent(updated, now: now, in: db)
        }
        let releasedPrimary = isPrimaryAgentTaskStatus(current.status)
            && !isPrimaryAgentTaskStatus(updated.status)
        let promoted = releasedPrimary
            ? try promoteNextAgentTask(now: now, in: db)
            : nil
        try insertAgentTaskEvent(
            commandID: commandID,
            taskID: id,
            expectedRevision: expectedRevision,
            from: currentState,
            to: nextState,
            fromRequestedControl: current.requestedControl,
            toRequestedControl: nextRequestedControl,
            hasAdoptedOutput: hasAdoptedOutput,
            resultActiveRunID: updated.activeRunID,
            resultQueueOrdinal: updated.queueOrdinal,
            promoted: promoted,
            now: now,
            in: db
        )
        return AgentTaskTransitionResult(task: updated, promotedTask: promoted)
    }

    private static func resolveAgentTaskIntent(
        _ task: AgentTaskSnapshot,
        now: Date,
        in db: Database
    ) throws {
        let resolution: String
        switch task.outcome {
        case .kept:
            resolution = "kept"
        case .discarded:
            resolution = "discarded"
        case .natural, .none:
            throw AppDatabaseError.invalidAgentTask
        }
        try db.execute(
            sql: """
                UPDATE pendingModelIntent
                SET consumedAt = ?, continuationRequestID = NULL,
                    resolutionKind = ?, resolvedTaskID = ?
                WHERE id = ? AND consumedAt IS NULL
                """,
            arguments: [
                now.timeIntervalSince1970,
                resolution,
                task.id.uuidString,
                task.intentID.uuidString
            ]
        )
        if db.changesCount == 0 {
            guard let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT resolutionKind, resolvedTaskID
                    FROM pendingModelIntent WHERE id = ?
                    """,
                arguments: [task.intentID.uuidString]
            ) else {
                throw AppDatabaseError.invalidPendingModelIntent
            }
            let storedResolution: String? = row["resolutionKind"]
            let storedTaskID: String? = row["resolvedTaskID"]
            guard storedResolution == resolution,
                  storedTaskID == task.id.uuidString else {
                throw AppDatabaseError.idempotencyConflict
            }
        }
    }

    private static func promoteNextAgentTask(
        now: Date,
        in db: Database
    ) throws -> AgentTaskSnapshot? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentTask WHERE status = 'queued' ORDER BY queueOrdinal ASC LIMIT 1"
        ) else {
            return nil
        }
        let queued = try decodeAgentTask(row)
        let currentState = try AgentTaskControlState(status: queued.status)
        let running = try AgentTaskControlMachine().transition(
            currentState,
            to: .running
        )
        let nextRevision = queued.revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            throw AppDatabaseError.invalidAgentTask
        }
        try db.execute(
            sql: """
                UPDATE agentTask
                SET status = ?, revision = ?, primarySlot = 1, updatedAt = ?
                WHERE id = ? AND revision = ? AND status = 'queued'
                """,
            arguments: [
                running.status.rawValue,
                nextRevision.partialValue,
                now.timeIntervalSince1970,
                queued.id.uuidString,
                queued.revision
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.agentTaskRevisionConflict
        }
        let promoted = try requiredAgentTask(id: queued.id, in: db)
        try insertAgentTaskEvent(
            commandID: UUID(),
            taskID: queued.id,
            expectedRevision: queued.revision,
            from: currentState,
            to: running,
            fromRequestedControl: queued.requestedControl,
            toRequestedControl: nil,
            hasAdoptedOutput: false,
            resultActiveRunID: promoted.activeRunID,
            resultQueueOrdinal: promoted.queueOrdinal,
            promoted: nil,
            now: now,
            in: db
        )
        return promoted
    }

    private static func nextAgentTaskQueueOrdinal(
        in db: Database
    ) throws -> Int64 {
        let maximumOrdinal = try Int64.fetchOne(
            db,
            sql: "SELECT MAX(queueOrdinal) FROM agentTask"
        ) ?? 0
        let nextOrdinal = maximumOrdinal.addingReportingOverflow(1)
        guard !nextOrdinal.overflow, nextOrdinal.partialValue > 0 else {
            throw AppDatabaseError.invalidAgentTask
        }
        return nextOrdinal.partialValue
    }

    static func requiredAgentTask(
        id: UUID,
        in db: Database
    ) throws -> AgentTaskSnapshot {
        guard let task = try agentTask(id: id, in: db) else {
            throw AppDatabaseError.invalidAgentTask
        }
        return task
    }

    static func agentTask(
        id: UUID,
        in db: Database
    ) throws -> AgentTaskSnapshot? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentTask WHERE id = ?",
            arguments: [id.uuidString]
        ) else {
            return nil
        }
        return try decodeAgentTask(row)
    }

    static func decodeAgentTask(_ row: Row) throws -> AgentTaskSnapshot {
        let idText: String = row["id"]
        let intentText: String = row["intentID"]
        let conversationText: String = row["conversationID"]
        let projectText: String? = row["projectID"]
        let branchText: String? = row["branchID"]
        let statusText: String = row["status"]
        let outcomeText: String? = row["outcome"]
        let requestedControlText: String? = row["requestedControl"]
        let revision: Int = row["revision"]
        let queueOrdinal: Int64 = row["queueOrdinal"]
        let primarySlot: Int? = row["primarySlot"]
        let activeRunText: String? = row["activeRunID"]
        let createdAt = Date(timeIntervalSince1970: row["createdAt"])
        let updatedAt = Date(timeIntervalSince1970: row["updatedAt"])
        guard let id = UUID(uuidString: idText),
              let intentID = UUID(uuidString: intentText),
              let conversationID = UUID(uuidString: conversationText),
              let status = AgentTaskStatus(rawValue: statusText),
              revision > 0,
              queueOrdinal > 0,
              updatedAt >= createdAt,
              primarySlot == (isPrimaryAgentTaskStatus(status) ? 1 : nil) else {
            throw AppDatabaseError.invalidAgentTask
        }
        let projectID = try optionalAgentTaskUUID(projectText)
        let branchID = try optionalAgentTaskUUID(branchText)
        let activeRunID = try optionalAgentTaskUUID(activeRunText)
        let outcome: AgentTaskOutcome?
        if let outcomeText {
            guard let decoded = AgentTaskOutcome(rawValue: outcomeText) else {
                throw AppDatabaseError.invalidAgentTask
            }
            outcome = decoded
        } else {
            outcome = nil
        }
        let requestedControl: AgentTaskRequestedControl?
        if let requestedControlText {
            guard let decoded = AgentTaskRequestedControl(
                rawValue: requestedControlText
            ) else {
                throw AppDatabaseError.invalidAgentTask
            }
            requestedControl = decoded
        } else {
            requestedControl = nil
        }
        guard isValidAgentTaskRequestedControl(
            requestedControl,
            for: status
        ) else {
            throw AppDatabaseError.invalidAgentTask
        }
        do {
            _ = try AgentTaskControlState(status: status, outcome: outcome)
        } catch {
            throw AppDatabaseError.invalidAgentTask
        }
        return AgentTaskSnapshot(
            id: id,
            intentID: intentID,
            conversationID: conversationID,
            projectID: projectID,
            branchID: branchID,
            status: status,
            outcome: outcome,
            requestedControl: requestedControl,
            revision: revision,
            queueOrdinal: queueOrdinal,
            activeRunID: activeRunID,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func isValidAgentTaskRequestedControl(
        _ control: AgentTaskRequestedControl?,
        for status: AgentTaskStatus
    ) -> Bool {
        switch status {
        case .pauseRequested:
            return control == .pauseNow
        case .stopRequested:
            return control == .stopKeepingResults
        case .reconciling:
            return true
        case .queued, .running, .paused, .waitingUser, .completed,
             .failed, .discarded:
            return control == nil
        }
    }

    static func optionalAgentTaskUUID(
        _ value: String?
    ) throws -> UUID? {
        guard let value else { return nil }
        guard let id = UUID(uuidString: value) else {
            throw AppDatabaseError.invalidAgentTask
        }
        return id
    }

    private static func canonicalAgentTaskTimestamp(
        _ timestamp: Date
    ) throws -> Date {
        let microseconds = timestamp.timeIntervalSince1970 * 1_000_000
        guard microseconds.isFinite,
              microseconds >= Double(Int64.min),
              microseconds < Double(Int64.max) else {
            throw AppDatabaseError.invalidAgentTask
        }
        let epochMicroseconds = Int64(microseconds.rounded(.down))
        return Date(
            timeIntervalSince1970: Double(epochMicroseconds) / 1_000_000
        )
    }
}
