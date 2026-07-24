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
        let admissionRaw: String = intentRow["admissionCondition"]
        guard let admissionCondition = PendingModelIntentAdmissionCondition(
            rawValue: admissionRaw
        ) else {
            throw AppDatabaseError.invalidPendingModelIntent
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
        let initialState: AgentTaskControlState
        if hasPrimary == 0,
           admissionCondition == .networkConfirmationRequired {
            initialState = try AgentTaskControlState(
                status: .waitingUser,
                waitingReason: .networkConfirmation
            )
        } else {
            initialState = try AgentTaskControlState(
                status: hasPrimary == 0 ? .running : .queued
            )
        }
        let taskID = UUID()
        try db.execute(
            sql: """
                INSERT INTO agentTask (
                    id, intentID, conversationID, projectID, branchID,
                    status, outcome, waitingReason, requestedControl, revision,
                    queueOrdinal, primarySlot,
                    activeRunID, enqueueCommandID, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, NULL, 1, ?, ?, NULL, ?, ?, ?)
                """,
            arguments: [
                taskID.uuidString,
                intent.id.uuidString,
                intent.conversationID.uuidString,
                intent.projectID?.uuidString,
                intent.branchID?.uuidString,
                initialState.status.rawValue,
                initialState.waitingReason?.rawValue,
                nextOrdinal,
                isPrimaryAgentTaskStatus(initialState.status) ? 1 : nil,
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
            to: initialState,
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

    func latestAgentTask() throws -> AgentTaskSnapshot? {
        try queue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM agentTask
                    ORDER BY updatedAt DESC, queueOrdinal DESC, rowid DESC
                    LIMIT 1
                    """
            ) else {
                return nil
            }
            return try Self.decodeAgentTask(row)
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

    static func preparedProviderRunBindingStatus(
        for task: AgentTaskSnapshot
    ) -> AgentRunStatus? {
        switch task.status {
        case .running:
            return .running
        case .queued:
            return .queued
        case .waitingUser where task.waitingReason == .networkConfirmation:
            return .waitingUser
        case .pauseRequested, .reconciling, .paused, .stopRequested,
             .waitingUser, .completed, .failed, .discarded:
            return nil
        }
    }

    static func preparedProviderRunProjectionStatus(
        for task: AgentTaskSnapshot
    ) -> AgentRunStatus? {
        if task.status == .waitingUser,
           task.waitingReason == .connectionInvalid {
            return .waitingUser
        }
        return preparedProviderRunBindingStatus(for: task)
    }

    static func promotedAgentTaskState(
        for intentID: UUID,
        in db: Database
    ) throws -> AgentTaskControlState {
        guard let admissionRaw = try String.fetchOne(
            db,
            sql: "SELECT admissionCondition FROM pendingModelIntent WHERE id = ?",
            arguments: [intentID.uuidString]
        ), let admissionCondition = PendingModelIntentAdmissionCondition(
            rawValue: admissionRaw
        ) else {
            throw AppDatabaseError.invalidPendingModelIntent
        }
        if admissionCondition == .networkConfirmationRequired {
            return try AgentTaskControlState(
                status: .waitingUser,
                waitingReason: .networkConfirmation
            )
        }
        return try AgentTaskControlState(status: .running)
    }

    static func bindAgentRun(
        _ runID: UUID,
        to taskID: UUID,
        now: Date,
        in db: Database
    ) throws -> AgentTaskSnapshot {
        let current = try requiredAgentTask(id: taskID, in: db)
        guard preparedProviderRunBindingStatus(for: current) != nil else {
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
            outcome: current.outcome,
            waitingReason: current.waitingReason
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
        preservePreparedIfUnsent: Bool = false,
        now: Date = Date()
    ) throws -> AgentTaskSnapshot? {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            guard let task = try Self.agentTask(intentID: intentID, in: db),
                  task.status == .running
                    || task.status == .pauseRequested
                    || task.status == .stopRequested
                    || (task.status == .reconciling
                        && task.requestedControl != nil) else {
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
            case .prepared
                where preservePreparedIfUnsent && task.status == .running:
                break
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
                if task.status == .pauseRequested {
                    _ = try Self.transitionAgentTask(
                        id: task.id,
                        expectedRevision: task.revision,
                        commandID: UUID(),
                        to: .paused,
                        now: timestamp,
                        in: db
                    )
                } else if task.status == .stopRequested {
                    _ = try Self.transitionAgentTask(
                        id: task.id,
                        expectedRevision: task.revision,
                        commandID: UUID(),
                        to: .completed,
                        outcome: .kept,
                        now: timestamp,
                        in: db
                    )
                }
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
                if task.status == .running {
                    _ = try Self.transitionAgentTask(
                        id: task.id,
                        expectedRevision: task.revision,
                        commandID: UUID(),
                        to: .failed,
                        now: timestamp,
                        in: db
                    )
                    try Self.finishProviderRun(
                        request,
                        status: .waitingUser,
                        stage: "provider.hostContinuationFailed",
                        in: db
                    )
                    break
                }
                let target: AgentTaskStatus
                let outcome: AgentTaskOutcome?
                switch task.status {
                case .pauseRequested:
                    target = .paused
                    outcome = nil
                case .stopRequested:
                    target = .completed
                    outcome = .kept
                default:
                    throw AppDatabaseError.invalidAgentTask
                }
                _ = try Self.transitionAgentTask(
                    id: task.id,
                    expectedRevision: task.revision,
                    commandID: UUID(),
                    to: target,
                    outcome: outcome,
                    now: timestamp,
                    in: db
                )
            case .outcomeUnknown
                where task.requestedControl == .stopKeepingResults:
                _ = try Self.transitionAgentTask(
                    id: task.id,
                    expectedRevision: task.revision,
                    commandID: UUID(),
                    to: .completed,
                    outcome: .kept,
                    now: timestamp,
                    in: db
                )
            case .cancelled, .failed, .terminated, .outcomeUnknown,
                 .continuationCommitted:
                try Self.synchronizeAgentTask(for: request, in: db)
            }
            return try Self.agentTask(intentID: intentID, in: db)
        }
    }

    func prepareProviderRequestForLifecycleSuspension(
        intentID: UUID,
        now: Date = Date()
    ) throws -> ProviderRequestSnapshot? {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            guard let task = try Self.agentTask(intentID: intentID, in: db),
                  task.status == .running,
                  let requestRow = try Row.fetchOne(
                    db,
                    sql: """
                        SELECT * FROM providerRequest
                        WHERE intentID = ?
                        ORDER BY attemptNumber DESC, turnSequence DESC,
                                 rowid DESC
                        LIMIT 1
                        """,
                    arguments: [intentID.uuidString]
                  ) else {
                return nil
            }
            let request = try Self.decodeProviderRequest(requestRow)
            switch request.phase {
            case .sending, .streaming:
                let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
                    request,
                    reason: .lifecycleInterruption,
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
                return unknown
            case .outcomeUnknown:
                try Self.synchronizeAgentTask(for: request, in: db)
                return request
            case .prepared, .responseComplete:
                return request
            case .cancelled, .failed, .terminated, .continuationCommitted:
                throw AppDatabaseError.invalidProviderRequest
            }
        }
    }

    func transitionAgentTask(
        id: UUID,
        expectedRevision: Int,
        commandID: UUID,
        to status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        waitingReason: AgentTaskWaitingReason? = nil,
        hasAdoptedOutput: Bool = false,
        now: Date = Date()
    ) throws -> AgentTaskTransitionResult {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            if status == .running {
                let current = try Self.requiredAgentTask(id: id, in: db)
                if current.status == .paused {
                    let activeBudgetApprovalCount = try Int.fetchOne(
                        db,
                        sql: """
                            SELECT COUNT(*) FROM providerBudgetApproval
                            WHERE taskID = ? AND status IN ('pending', 'approved')
                            """,
                        arguments: [id.uuidString]
                    ) ?? 0
                    guard activeBudgetApprovalCount == 0 else {
                        throw AppDatabaseError.providerBudgetRequiresApproval
                    }
                }
            }
            try Self.transitionAgentTask(
                id: id,
                expectedRevision: expectedRevision,
                commandID: commandID,
                to: status,
                outcome: outcome,
                waitingReason: waitingReason,
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

    func settleAgentTaskAtProviderTurnLimit(
        intentID: UUID,
        now: Date = Date()
    ) throws -> AgentTaskSnapshot {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            guard let task = try Self.agentTask(intentID: intentID, in: db),
                  task.status == .running,
                  let requestRow = try Row.fetchOne(
                    db,
                    sql: """
                        SELECT * FROM providerRequest
                        WHERE intentID = ?
                        ORDER BY attemptNumber DESC, turnSequence DESC, rowid DESC
                        LIMIT 1
                        """,
                    arguments: [intentID.uuidString]
                  ) else {
                throw AppDatabaseError.invalidAgentTask
            }
            let request = try Self.decodeProviderRequest(requestRow)
            guard request.phase == .responseComplete,
                  request.identity.runID == task.activeRunID else {
                throw AppDatabaseError.invalidProviderRequest
            }
            let receiptCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*)
                    FROM toolReceipt AS receipt
                    JOIN agentRun AS run ON run.id = receipt.originRunID
                    WHERE run.taskID = ? AND receipt.outcome = 'completed'
                    """,
                arguments: [task.id.uuidString]
            ) ?? 0
            let terminated = try ProviderRequestLifecycle.terminateAfterResponse(
                request,
                reason: .outputLimit,
                now: timestamp
            )
            try Self.updateProviderRequestRow(
                terminated,
                expectedPayloadHash: Self.payloadHash(
                    try Self.encodeProviderRequest(request)
                ),
                in: db
            )
            if receiptCount > 0 {
                let stopping = try Self.transitionAgentTask(
                    id: task.id,
                    expectedRevision: task.revision,
                    commandID: UUID(),
                    to: .stopRequested,
                    hasAdoptedOutput: true,
                    now: timestamp,
                    in: db
                ).task
                let completed = try Self.transitionAgentTask(
                    id: task.id,
                    expectedRevision: stopping.revision,
                    commandID: UUID(),
                    to: .completed,
                    outcome: .kept,
                    hasAdoptedOutput: true,
                    now: timestamp,
                    in: db
                ).task
                try Self.finishProviderRun(
                    terminated,
                    status: .completed,
                    stage: "provider.turnLimitKept",
                    in: db
                )
                return completed
            }
            let failed = try Self.transitionAgentTask(
                id: task.id,
                expectedRevision: task.revision,
                commandID: UUID(),
                to: .failed,
                now: timestamp,
                in: db
            ).task
            let discarded = try Self.transitionAgentTask(
                id: task.id,
                expectedRevision: failed.revision,
                commandID: UUID(),
                to: .discarded,
                outcome: .discarded,
                now: timestamp,
                in: db
            ).task
            try Self.finishProviderRun(
                terminated,
                status: .failed,
                stage: "provider.turnLimitDiscarded",
                in: db
            )
            return discarded
        }
    }

    private static func finishProviderRun(
        _ request: ProviderRequestSnapshot,
        status: AgentRunStatus,
        stage: String,
        in db: Database
    ) throws {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentRun WHERE id = ? AND conversationID = ?",
            arguments: [
                request.identity.runID.uuidString,
                request.identity.conversationID.uuidString
            ]
        ) else {
            throw AppDatabaseError.invalidAgentRun
        }
        let run = try decodeAgentRun(row)
        let scopeMatches = try providerContinuationRunScopeMatches(
            run,
            request: request,
            in: db
        )
        guard run.id == request.identity.runID,
              scopeMatches,
              run.kind == "providerTurn" else {
            throw AppDatabaseError.invalidAgentRun
        }
        try upsertAgentRun(
            AgentRunSnapshot(
                id: run.id,
                projectID: run.projectID,
                kind: run.kind,
                status: status,
                idempotencyKey: run.idempotencyKey,
                currentStage: stage,
                startedAt: run.startedAt,
                updatedAt: request.updatedAt
            ),
            conversationID: request.identity.conversationID,
            in: db
        )
    }

    static func transitionAgentTask(
        id: UUID,
        expectedRevision: Int,
        commandID: UUID,
        to status: AgentTaskStatus,
        outcome: AgentTaskOutcome? = nil,
        waitingReason: AgentTaskWaitingReason? = nil,
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
                waitingReason: waitingReason,
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
            outcome: current.outcome,
            waitingReason: current.waitingReason
        )
        let nextState = try AgentTaskControlMachine().transition(
            currentState,
            to: status,
            outcome: outcome,
            waitingReason: waitingReason,
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
                SET status = ?, outcome = ?, waitingReason = ?, requestedControl = ?,
                    revision = ?, queueOrdinal = ?, primarySlot = ?,
                    updatedAt = ?
                WHERE id = ? AND revision = ?
                """,
            arguments: [
                nextState.status.rawValue,
                nextState.outcome?.rawValue,
                nextState.waitingReason?.rawValue,
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
        try synchronizePreparedProviderRunProjection(for: updated, in: db)
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

    static func promoteNextAgentTask(
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
        let targetState = try promotedAgentTaskState(
            for: queued.intentID,
            in: db
        )
        let promotedState = try AgentTaskControlMachine().transition(
            currentState,
            to: targetState.status,
            waitingReason: targetState.waitingReason
        )
        let nextRevision = queued.revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            throw AppDatabaseError.invalidAgentTask
        }
        try db.execute(
            sql: """
                UPDATE agentTask
                SET status = ?, waitingReason = ?, revision = ?,
                    primarySlot = 1, updatedAt = ?
                WHERE id = ? AND revision = ? AND status = 'queued'
                """,
            arguments: [
                promotedState.status.rawValue,
                promotedState.waitingReason?.rawValue,
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
        try synchronizePreparedProviderRunProjection(for: promoted, in: db)
        try insertAgentTaskEvent(
            commandID: UUID(),
            taskID: queued.id,
            expectedRevision: queued.revision,
            from: currentState,
            to: promotedState,
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

}
