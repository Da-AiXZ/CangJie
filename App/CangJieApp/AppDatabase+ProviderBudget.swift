import CangJieCore
import Foundation
import GRDB

enum ProviderBudgetApprovalStatus: String, Codable, Equatable {
    case pending
    case approved
    case consumed
    case rejected
    case invalidated
    case expired
}

struct ProviderBudgetApprovalSnapshot: Identifiable, Equatable {
    let id: UUID
    let taskID: UUID
    let budgetVersion: Int64
    let providerRequestID: UUID
    let bindingHash: String
    let reasons: Set<BudgetApprovalReason>
    let estimate: NextRequestBudgetEstimate
    let status: ProviderBudgetApprovalStatus
    let invalidationReason: String?
    let expiresAt: Date
    let createdAt: Date
    let updatedAt: Date
    let approvedAt: Date?
    let consumedAt: Date?
}

struct ProviderBudgetSendAuthorization: Equatable {
    let request: ProviderRequestSnapshot
    let isReplay: Bool
}

struct ProviderBudgetTaskSnapshot: Equatable {
    let policy: TaskBudgetPolicy
    let usage: BudgetUsageSnapshot
    let approval: ProviderBudgetApprovalSnapshot?
}

enum ProviderBudgetGateResult: Equatable {
    case authorized(ProviderBudgetSendAuthorization)
    case requiresApproval(ProviderBudgetApprovalSnapshot)
    case blocked(reasons: Set<BudgetBlockReason>)
}

private enum ProviderBudgetApprovalAttempt {
    case approved(ProviderBudgetApprovalSnapshot)
    case expired
    case requiresReapproval
}

extension AppDatabase {
    private static let providerBudgetPayloadVersion = 1
    private static let providerBudgetApprovalLifetimeMilliseconds: Int64 =
        7 * 24 * 60 * 60 * 1_000

    func storeProviderBudgetPolicy(
        _ policy: TaskBudgetPolicy,
        now: Date = Date()
    ) throws -> TaskBudgetPolicy {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            try Self.storeProviderBudgetPolicy(policy, now: timestamp, in: db)
        }
    }

    func latestProviderBudgetPolicy(taskID: UUID) throws -> TaskBudgetPolicy? {
        try queue.read { db in
            try Self.latestProviderBudgetPolicy(taskID: taskID, in: db)
        }
    }

    func providerBudgetUsageSnapshot(taskID: UUID) throws -> BudgetUsageSnapshot {
        try queue.read { db in
            guard let policy = try Self.latestProviderBudgetPolicy(
                taskID: taskID,
                in: db
            ) else {
                throw AppDatabaseError.invalidProviderBudget
            }
            return try Self.providerBudgetUsageSnapshot(policy: policy, in: db)
        }
    }

    func providerBudgetApproval(
        id: UUID
    ) throws -> ProviderBudgetApprovalSnapshot? {
        try queue.read { db in
            try Self.providerBudgetApproval(id: id, in: db)
        }
    }

    func pendingProviderBudgetApproval(
        taskID: UUID
    ) throws -> ProviderBudgetApprovalSnapshot? {
        try queue.read { db in
            try Self.activeProviderBudgetApproval(taskID: taskID, in: db)
                .map(Self.approvalSnapshot)
        }
    }

    static func providerBudgetTaskSnapshot(
        taskID: UUID,
        in db: Database
    ) throws -> ProviderBudgetTaskSnapshot? {
        guard let policy = try latestProviderBudgetPolicy(
            taskID: taskID,
            in: db
        ) else {
            return nil
        }
        return ProviderBudgetTaskSnapshot(
            policy: policy,
            usage: try providerBudgetUsageSnapshot(policy: policy, in: db),
            approval: try activeProviderBudgetApproval(
                taskID: taskID,
                in: db
            ).map(approvalSnapshot)
        )
    }

    func authorizeAndMarkProviderRequestSending(
        _ request: ProviderRequestSnapshot,
        initialPolicy: TaskBudgetPolicy,
        estimate: NextRequestBudgetEstimate,
        now: Date = Date()
    ) throws -> ProviderBudgetGateResult {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            guard let budgetTask = try Self.agentTask(
                intentID: request.identity.intentID,
                in: db
            ), initialPolicy.taskID == budgetTask.id,
              budgetTask.activeRunID == request.identity.runID else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let policy = try Self.latestProviderBudgetPolicy(
                taskID: initialPolicy.taskID,
                in: db
            ) ?? Self.storeProviderBudgetPolicy(
                initialPolicy,
                now: timestamp,
                in: db
            )
            guard estimate.requestIdentity.requestID == request.identity.requestID,
                  estimate.taskID == policy.taskID,
                  estimate.requestIdentity.exactRequestHash
                    == (try ProviderRequestBudgetIdentity(
                        trustedTaskScope: ProviderRequestBudgetTaskScope(
                            taskID: budgetTask.id,
                            intentID: budgetTask.intentID,
                            activeRunID: request.identity.runID
                        ),
                        request: request
                    )).exactRequestHash,
                  let storedRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM providerRequest WHERE id = ?",
                    arguments: [request.identity.requestID.uuidString]
                  ) else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let stored = try Self.decodeProviderRequest(storedRow)

            if let usageRow = try Row.fetchOne(
                db,
                sql: "SELECT status FROM providerBudgetUsage WHERE providerRequestID = ?",
                arguments: [request.identity.requestID.uuidString]
            ) {
                let status: String = usageRow["status"]
                guard status != "legacyUnknown",
                      stored.phase != .prepared else {
                    throw AppDatabaseError.invalidProviderBudget
                }
                return .authorized(
                    ProviderBudgetSendAuthorization(request: stored, isReplay: true)
                )
            }

            guard stored == request, stored.phase == .prepared else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let task = budgetTask
            let usage = try Self.providerBudgetUsageSnapshot(
                policy: policy,
                in: db
            )
            let governance = BudgetGovernance()
            let decision = governance.preflight(
                policy: policy,
                usage: usage,
                nextRequest: estimate
            )
            let nowEpochMilliseconds = try Self.providerBudgetEpochMilliseconds(
                timestamp
            )
            var invalidatedPausedBudgetApproval = false

            if let active = try Self.activeProviderBudgetApproval(
                taskID: task.id,
                in: db
            ) {
                if active.binding.validate(
                    approvalRequestID: active.binding.approvalRequestID,
                    approvedBindingHash: active.binding.bindingHash,
                    decision: decision,
                    nowEpochMilliseconds: nowEpochMilliseconds
                ) == .approved {
                    switch active.status {
                    case .approved:
                        guard task.status == .running else {
                            throw AppDatabaseError.invalidProviderBudget
                        }
                        return .authorized(
                            try Self.consumeApprovalAndMarkSending(
                                active,
                                request: stored,
                                policy: policy,
                                estimate: estimate,
                                usage: usage,
                                now: timestamp,
                                in: db
                            )
                        )
                    case .pending:
                        guard task.status == .paused else {
                            throw AppDatabaseError.invalidProviderBudget
                        }
                        return .requiresApproval(Self.approvalSnapshot(active))
                    case .consumed, .rejected, .invalidated, .expired:
                        throw AppDatabaseError.invalidProviderBudget
                    }
                }
                if nowEpochMilliseconds
                    >= active.binding.expiresAtEpochMilliseconds,
                   active.status == .pending {
                    try Self.expireProviderBudgetApproval(
                        active.binding.approvalRequestID,
                        now: timestamp,
                        in: db
                    )
                } else {
                    try Self.invalidateProviderBudgetApproval(
                        active.binding.approvalRequestID,
                        reason: "bindingChanged",
                        now: timestamp,
                        in: db
                    )
                }
                invalidatedPausedBudgetApproval = task.status == .paused
            }

            switch decision.outcome {
            case let .proceed(reservation):
                if task.status == .paused {
                    guard invalidatedPausedBudgetApproval else {
                        throw AppDatabaseError.invalidProviderBudget
                    }
                    _ = try Self.transitionAgentTask(
                        id: task.id,
                        expectedRevision: task.revision,
                        commandID: UUID(),
                        to: .running,
                        now: timestamp,
                        in: db
                    )
                } else {
                    guard task.status == .running else {
                        throw AppDatabaseError.invalidProviderBudget
                    }
                }
                return .authorized(
                    try Self.markProviderRequestSending(
                        stored,
                        policy: policy,
                        estimate: estimate,
                        usage: usage,
                        reservation: reservation,
                        now: timestamp,
                        in: db
                    )
                )
            case .requiresApproval:
                guard task.status == .running || task.status == .paused,
                      task.status != .paused || invalidatedPausedBudgetApproval else {
                    throw AppDatabaseError.invalidProviderBudget
                }
                let approval = try Self.createProviderBudgetApproval(
                    decision: decision,
                    estimate: estimate,
                    now: timestamp,
                    in: db
                )
                _ = try Self.pauseAgentTaskForProviderBudget(
                    task,
                    now: timestamp,
                    in: db
                )
                return .requiresApproval(Self.approvalSnapshot(approval))
            case let .blocked(reasons):
                return .blocked(reasons: reasons)
            }
        }
    }

    func approveProviderBudgetApproval(
        approvalID: UUID,
        displayedBindingHash: String,
        estimate: NextRequestBudgetEstimate,
        now: Date = Date()
    ) throws -> ProviderBudgetApprovalSnapshot {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        let attempt: ProviderBudgetApprovalAttempt = try queue.write { db in
            guard var approval = try Self.providerBudgetApprovalRecord(
                id: approvalID,
                in: db
            ), approval.binding.bindingHash == displayedBindingHash else {
                throw AppDatabaseError.providerBudgetRequiresApproval
            }
            guard approval.status == .pending || approval.status == .approved else {
                throw AppDatabaseError.providerBudgetRequiresApproval
            }
            if approval.estimate != estimate {
                try Self.invalidateProviderBudgetApproval(
                    approvalID,
                    reason: "estimateChanged",
                    now: timestamp,
                    in: db
                )
                return .requiresReapproval
            }
            if approval.status == .approved {
                return .approved(Self.approvalSnapshot(approval))
            }
            let nowEpochMilliseconds = try Self.providerBudgetEpochMilliseconds(
                timestamp
            )
            guard nowEpochMilliseconds
                    < approval.binding.expiresAtEpochMilliseconds else {
                try Self.expireProviderBudgetApproval(
                    approvalID,
                    now: timestamp,
                    in: db
                )
                return .expired
            }
            guard let policy = try Self.latestProviderBudgetPolicy(
                taskID: approval.binding.taskID,
                in: db
            ) else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let usage = try Self.providerBudgetUsageSnapshot(policy: policy, in: db)
            let decision = BudgetGovernance().preflight(
                policy: policy,
                usage: usage,
                nextRequest: estimate
            )
            guard let task = try Self.agentTask(
                    id: approval.binding.taskID,
                    in: db
                  ), task.status == .paused,
                  approval.binding.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: displayedBindingHash,
                decision: decision,
                nowEpochMilliseconds: nowEpochMilliseconds
            ) == .approved,
                  let requestRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM providerRequest WHERE id = ?",
                    arguments: [approval.binding.providerRequestID.uuidString]
                  ),
                  let storedRequest = try? Self.decodeProviderRequest(requestRow),
                  storedRequest.phase == .prepared,
                  storedRequest.identity.requestID == estimate.requestIdentity.requestID,
                  estimate.taskID == approval.binding.taskID,
                  (try ProviderRequestBudgetIdentity(
                    trustedTaskScope: ProviderRequestBudgetTaskScope(
                        taskID: task.id,
                        intentID: task.intentID,
                        activeRunID: storedRequest.identity.runID
                    ),
                    request: storedRequest
                  ))
                    .exactRequestHash == estimate.requestIdentity.exactRequestHash,
                  task.activeRunID == storedRequest.identity.runID else {
                try Self.invalidateProviderBudgetApproval(
                    approvalID,
                    reason: "bindingChanged",
                    now: timestamp,
                    in: db
                )
                return .requiresReapproval
            }
            try db.execute(
                sql: """
                    UPDATE providerBudgetApproval
                    SET status = 'approved', approvedAt = ?, updatedAt = ?
                    WHERE id = ? AND status = 'pending' AND bindingHash = ?
                    """,
                arguments: [
                    timestamp.timeIntervalSince1970,
                    timestamp.timeIntervalSince1970,
                    approvalID.uuidString,
                    displayedBindingHash
                ]
            )
            guard db.changesCount == 1 else {
                throw AppDatabaseError.providerBudgetRequiresApproval
            }
            approval = try Self.requiredProviderBudgetApproval(
                id: approvalID,
                in: db
            )
            _ = try Self.transitionAgentTask(
                id: task.id,
                expectedRevision: task.revision,
                commandID: approvalID,
                to: .running,
                now: timestamp,
                in: db
            )
            return .approved(Self.approvalSnapshot(approval))
        }
        switch attempt {
        case let .approved(approval):
            return approval
        case .expired:
            throw AppDatabaseError.providerBudgetApprovalExpired
        case .requiresReapproval:
            throw AppDatabaseError.providerBudgetRequiresApproval
        }
    }

    func rejectProviderBudgetApproval(
        approvalID: UUID,
        displayedBindingHash: String,
        now: Date = Date()
    ) throws -> AgentTaskSnapshot {
        let timestamp = try Self.canonicalAgentTaskTimestamp(now)
        return try queue.write { db in
            guard let approval = try Self.providerBudgetApprovalRecord(
                id: approvalID,
                in: db
            ), approval.binding.bindingHash == displayedBindingHash,
               approval.status == .pending || approval.status == .approved,
               let requestRow = try Row.fetchOne(
                db,
                sql: "SELECT * FROM providerRequest WHERE id = ?",
                arguments: [approval.binding.providerRequestID.uuidString]
               ) else {
                throw AppDatabaseError.providerBudgetRequiresApproval
            }
            let request = try Self.decodeProviderRequest(requestRow)
            guard request.phase == .prepared,
                  let task = try Self.agentTask(
                    id: approval.binding.taskID,
                    in: db
                  ), task.status == .paused
                    || task.status == .running
                    || task.status == .waitingUser else {
                throw AppDatabaseError.providerBudgetRequiresApproval
            }
            try db.execute(
                sql: """
                    UPDATE providerBudgetApproval
                    SET status = 'rejected', updatedAt = ?
                    WHERE id = ? AND status IN ('pending', 'approved')
                    """,
                arguments: [timestamp.timeIntervalSince1970, approvalID.uuidString]
            )
            guard db.changesCount == 1 else {
                throw AppDatabaseError.providerBudgetRequiresApproval
            }
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
            let receiptCount = try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM toolReceipt AS receipt
                    JOIN agentRun AS run ON run.id = receipt.originRunID
                    WHERE run.taskID = ? AND receipt.outcome = 'completed'
                    """,
                arguments: [task.id.uuidString]
            ) ?? 0
            let sourceTask: AgentTaskSnapshot
            if task.status == .running {
                sourceTask = try Self.transitionAgentTask(
                    id: task.id,
                    expectedRevision: task.revision,
                    commandID: UUID(),
                    to: .pauseRequested,
                    now: timestamp,
                    in: db
                ).task
            } else {
                sourceTask = task
            }
            let settled: AgentTaskSnapshot
            if receiptCount > 0 {
                let stoppingSource: AgentTaskSnapshot
                if sourceTask.status == .pauseRequested {
                    stoppingSource = try Self.transitionAgentTask(
                        id: sourceTask.id,
                        expectedRevision: sourceTask.revision,
                        commandID: UUID(),
                        to: .stopRequested,
                        hasAdoptedOutput: true,
                        now: timestamp,
                        in: db
                    ).task
                } else {
                    let resumed = try Self.transitionAgentTask(
                        id: sourceTask.id,
                        expectedRevision: sourceTask.revision,
                        commandID: UUID(),
                        to: .running,
                        now: timestamp,
                        in: db
                    ).task
                    stoppingSource = try Self.transitionAgentTask(
                        id: resumed.id,
                        expectedRevision: resumed.revision,
                        commandID: UUID(),
                        to: .stopRequested,
                        hasAdoptedOutput: true,
                        now: timestamp,
                        in: db
                    ).task
                }
                settled = try Self.transitionAgentTask(
                    id: stoppingSource.id,
                    expectedRevision: stoppingSource.revision,
                    commandID: UUID(),
                    to: .completed,
                    outcome: .kept,
                    hasAdoptedOutput: true,
                    now: timestamp,
                    in: db
                ).task
            } else {
                let paused: AgentTaskSnapshot
                if sourceTask.status == .pauseRequested {
                    paused = try Self.transitionAgentTask(
                        id: sourceTask.id,
                        expectedRevision: sourceTask.revision,
                        commandID: UUID(),
                        to: .paused,
                        now: timestamp,
                        in: db
                    ).task
                } else {
                    paused = sourceTask
                }
                settled = try Self.transitionAgentTask(
                    id: paused.id,
                    expectedRevision: paused.revision,
                    commandID: UUID(),
                    to: .discarded,
                    outcome: .discarded,
                    now: timestamp,
                    in: db
                ).task
            }
            try Self.updateCancelledProviderRun(
                cancelled,
                task: settled,
                in: db
            )
            return settled
        }
    }

    static func settleProviderBudgetUsageIfPresent(
        _ request: ProviderRequestSnapshot,
        in db: Database
    ) throws {
        let terminalStatus: String
        switch request.phase {
        case .responseComplete:
            terminalStatus = "completed"
        case .outcomeUnknown:
            terminalStatus = "outcomeUnknown"
        case .failed:
            try db.execute(
                sql: """
                    UPDATE providerBudgetApproval
                    SET status = 'invalidated',
                        invalidationReason = 'requestNotSendable',
                        updatedAt = ?
                    WHERE providerRequestID = ?
                      AND status IN ('pending', 'approved')
                    """,
                arguments: [
                    request.updatedAt.timeIntervalSince1970,
                    request.identity.requestID.uuidString
                ]
            )
            terminalStatus = "rejected"
        case .cancelled, .terminated:
            try db.execute(
                sql: """
                    UPDATE providerBudgetApproval
                    SET status = 'invalidated',
                        invalidationReason = 'requestNotSendable',
                        updatedAt = ?
                    WHERE providerRequestID = ?
                      AND status IN ('pending', 'approved')
                    """,
                arguments: [
                    request.updatedAt.timeIntervalSince1970,
                    request.identity.requestID.uuidString
                ]
            )
            return
        default:
            return
        }
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM providerBudgetUsage WHERE providerRequestID = ?",
            arguments: [request.identity.requestID.uuidString]
        ) else {
            return
        }

        let storedInput: Int64? = row["observedInputTokens"]
        let storedOutput: Int64? = row["observedOutputTokens"]
        let observedInput = request.usage.map { Int64($0.inputTokens) }
            ?? storedInput
        let observedOutput = request.usage.map { Int64($0.outputTokens) }
            ?? storedOutput
        let existingStatus: String = row["status"]
        if existingStatus == "legacyUnknown" {
            let startedAtEpoch: Double? = row["startedAt"]
            guard let startedAtEpoch else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let elapsed = try providerBudgetElapsedMilliseconds(
                startedAtEpoch: startedAtEpoch,
                finishedAtEpoch: request.updatedAt.timeIntervalSince1970
            )
            let currentRevision: Int64 = row["usageRevision"]
            let nextRevision = currentRevision.addingReportingOverflow(1)
            guard !nextRevision.overflow else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let unknownReason = terminalStatus == "outcomeUnknown"
                ? BudgetUnknownCostReason.outcomeUnknown.rawValue
                : BudgetUnknownCostReason.providerChargeUnavailable.rawValue
            try db.execute(
                sql: """
                    UPDATE providerBudgetUsage
                    SET usageRevision = ?, status = ?,
                        observedInputTokens = ?, observedOutputTokens = ?,
                        unknownCostReason = ?, pricingKey = ?,
                        elapsedMilliseconds = ?, finishedAt = ?, updatedAt = ?
                    WHERE providerRequestID = ? AND status = 'legacyUnknown'
                      AND usageRevision = ?
                    """,
                arguments: [
                    nextRevision.partialValue,
                    terminalStatus,
                    observedInput,
                    observedOutput,
                    unknownReason,
                    providerBudgetPricingKey(for: request),
                    elapsed,
                    request.updatedAt.timeIntervalSince1970,
                    request.updatedAt.timeIntervalSince1970,
                    request.identity.requestID.uuidString,
                    currentRevision
                ]
            )
            guard db.changesCount == 1 else {
                throw AppDatabaseError.idempotencyConflict
            }
            return
        }
        if existingStatus == terminalStatus {
            let existingInput: Int64? = row["observedInputTokens"]
            let existingOutput: Int64? = row["observedOutputTokens"]
            let existingElapsed: Int64 = row["elapsedMilliseconds"]
            let existingStartedAt: Double? = row["startedAt"]
            let existingFinishedAt: Double? = row["finishedAt"]
            guard let existingStartedAt else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let expectedElapsed = try providerBudgetElapsedMilliseconds(
                startedAtEpoch: existingStartedAt,
                finishedAtEpoch: request.updatedAt.timeIntervalSince1970
            )
            guard existingInput == observedInput,
                  existingOutput == observedOutput,
                  existingElapsed == expectedElapsed,
                  existingFinishedAt == request.updatedAt.timeIntervalSince1970 else {
                throw AppDatabaseError.idempotencyConflict
            }
            if terminalStatus == "outcomeUnknown" {
                let reason: String? = row["unknownCostReason"]
                let key: String? = row["pricingKey"]
                guard reason == BudgetUnknownCostReason.outcomeUnknown.rawValue,
                      key == providerBudgetPricingKey(for: request) else {
                    throw AppDatabaseError.idempotencyConflict
                }
            }
            return
        }
        let startedAtEpoch: Double? = row["startedAt"]
        guard let startedAtEpoch,
              startedAtEpoch.isFinite,
              request.updatedAt.timeIntervalSince1970 >= startedAtEpoch else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let elapsedDouble = (
            request.updatedAt.timeIntervalSince1970 - startedAtEpoch
        ) * 1_000
        guard elapsedDouble.isFinite,
              elapsedDouble >= 0,
              elapsedDouble < Double(Int64.max) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let elapsed = Int64(elapsedDouble.rounded(.down))
        guard existingStatus == "reserved" else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let currentRevision: Int64 = row["usageRevision"]
        let nextRevision = currentRevision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            throw AppDatabaseError.invalidProviderBudget
        }

        if terminalStatus == "completed" {
            guard request.usage != nil else {
                throw AppDatabaseError.invalidProviderBudget
            }
            try db.execute(
                sql: """
                    UPDATE providerBudgetUsage
                    SET usageRevision = ?, status = 'completed',
                        observedInputTokens = ?, observedOutputTokens = ?,
                        elapsedMilliseconds = ?, finishedAt = ?, updatedAt = ?
                    WHERE providerRequestID = ? AND status = 'reserved'
                      AND usageRevision = ?
                    """,
                arguments: [
                    nextRevision.partialValue,
                    observedInput,
                    observedOutput,
                    elapsed,
                    request.updatedAt.timeIntervalSince1970,
                    request.updatedAt.timeIntervalSince1970,
                    request.identity.requestID.uuidString,
                    currentRevision
                ]
            )
        } else if terminalStatus == "outcomeUnknown" {
            try db.execute(
                sql: """
                    UPDATE providerBudgetUsage
                    SET usageRevision = ?, status = 'outcomeUnknown',
                        observedInputTokens = ?, observedOutputTokens = ?,
                        estimatedCostMicroUnits = NULL,
                        actualCostMicroUnits = NULL, pricingVersion = NULL,
                        unknownCostReason = 'outcomeUnknown',
                        pricingKey = ?, elapsedMilliseconds = ?,
                        finishedAt = ?, updatedAt = ?
                    WHERE providerRequestID = ? AND status = 'reserved'
                      AND usageRevision = ?
                    """,
                arguments: [
                    nextRevision.partialValue,
                    observedInput,
                    observedOutput,
                    providerBudgetPricingKey(for: request),
                    elapsed,
                    request.updatedAt.timeIntervalSince1970,
                    request.updatedAt.timeIntervalSince1970,
                    request.identity.requestID.uuidString,
                    currentRevision
                ]
            )
        } else {
            guard terminalStatus == "rejected" else {
                throw AppDatabaseError.invalidProviderBudget
            }
            try db.execute(
                sql: """
                    UPDATE providerBudgetUsage
                    SET usageRevision = ?, status = 'rejected',
                        observedInputTokens = ?, observedOutputTokens = ?,
                        estimatedCostMicroUnits = NULL,
                        actualCostMicroUnits = NULL, pricingVersion = NULL,
                        unknownCostReason = 'providerChargeUnavailable',
                        pricingKey = ?, elapsedMilliseconds = ?,
                        finishedAt = ?, updatedAt = ?
                    WHERE providerRequestID = ? AND status = 'reserved'
                      AND usageRevision = ?
                    """,
                arguments: [
                    nextRevision.partialValue,
                    observedInput,
                    observedOutput,
                    providerBudgetPricingKey(for: request),
                    elapsed,
                    request.updatedAt.timeIntervalSince1970,
                    request.updatedAt.timeIntervalSince1970,
                    request.identity.requestID.uuidString,
                    currentRevision
                ]
            )
        }
        guard db.changesCount == 1 else {
            throw AppDatabaseError.idempotencyConflict
        }
    }
}

extension AppDatabase {
    static func providerBudgetElapsedMilliseconds(
        startedAtEpoch: Double,
        finishedAtEpoch: Double
    ) throws -> Int64 {
        guard startedAtEpoch.isFinite, finishedAtEpoch.isFinite else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let elapsedSeconds = finishedAtEpoch - startedAtEpoch
        guard elapsedSeconds.isFinite else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let milliseconds = max(0, elapsedSeconds) * 1_000
        guard milliseconds.isFinite,
              milliseconds < Double(Int64.max) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        return Int64(milliseconds.rounded(.down))
    }
}

private extension AppDatabase {
    struct StoredProviderBudgetApproval {
        let binding: BudgetApprovalBinding
        let estimate: NextRequestBudgetEstimate
        let status: ProviderBudgetApprovalStatus
        let invalidationReason: String?
        let expiresAt: Date
        let createdAt: Date
        let updatedAt: Date
        let approvedAt: Date?
        let consumedAt: Date?
    }

    static func storeProviderBudgetPolicy(
        _ policy: TaskBudgetPolicy,
        now: Date,
        in db: Database
    ) throws -> TaskBudgetPolicy {
        guard try requiredAgentTask(id: policy.taskID, in: db).id == policy.taskID else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let json = try encodeProviderBudget(policy)
        if let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM providerBudgetPolicy WHERE taskID = ? AND version = ?",
            arguments: [policy.taskID.uuidString, policy.version]
        ) {
            let existing: TaskBudgetPolicy = try decodeProviderBudgetPayload(row)
            guard existing == policy else {
                throw AppDatabaseError.idempotencyConflict
            }
            return existing
        }
        let latestVersion = try Int64.fetchOne(
            db,
            sql: "SELECT MAX(version) FROM providerBudgetPolicy WHERE taskID = ?",
            arguments: [policy.taskID.uuidString]
        )
        guard latestVersion == nil || policy.version == latestVersion! + 1 else {
            throw AppDatabaseError.invalidProviderBudget
        }
        try db.execute(
            sql: """
                INSERT INTO providerBudgetPolicy (
                    taskID, version, payloadVersion, payloadJSON, payloadHash,
                    createdAt
                ) VALUES (?, ?, 1, ?, ?, ?)
                """,
            arguments: [
                policy.taskID.uuidString,
                policy.version,
                json,
                payloadHash(json),
                now.timeIntervalSince1970
            ]
        )
        return policy
    }

    static func latestProviderBudgetPolicy(
        taskID: UUID,
        in db: Database
    ) throws -> TaskBudgetPolicy? {
        guard let row = try Row.fetchOne(
            db,
            sql: """
                SELECT * FROM providerBudgetPolicy
                WHERE taskID = ? ORDER BY version DESC LIMIT 1
                """,
            arguments: [taskID.uuidString]
        ) else { return nil }
        let policy: TaskBudgetPolicy = try decodeProviderBudgetPayload(row)
        guard policy.taskID == taskID else {
            throw AppDatabaseError.invalidProviderBudget
        }
        return policy
    }

    static func providerBudgetUsageSnapshot(
        policy: TaskBudgetPolicy,
        in db: Database
    ) throws -> BudgetUsageSnapshot {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT * FROM providerBudgetUsage
                WHERE taskID = ? ORDER BY usageRevision
                """,
            arguments: [policy.taskID.uuidString]
        )
        var input: Int64 = 0
        var output: Int64 = 0
        var elapsed: Int64 = 0
        var knownCost: Int64 = 0
        var allKnownCostsAreActual = true
        var pricingVersions: Set<String> = []
        var unknownCost: (BudgetUnknownCostReason, String)?
        var costCurrencyCode: String?
        var costScale: Int64?
        var unsettled = false
        var revision: Int64 = 1
        for row in rows {
            let rowRevision: Int64 = row["usageRevision"]
            revision = max(revision, rowRevision)
            let status: String = row["status"]
            unsettled = unsettled || status == "reserved"
                || status == "outcomeUnknown" || status == "legacyUnknown"
            guard status != "reserved" else { continue }
            let rowCurrencyCode: String = row["currencyCode"]
            let rowCostScale: Int64 = row["costScale"]
            guard (costCurrencyCode == nil || costCurrencyCode == rowCurrencyCode),
                  (costScale == nil || costScale == rowCostScale) else {
                throw AppDatabaseError.invalidProviderBudget
            }
            costCurrencyCode = rowCurrencyCode
            costScale = rowCostScale
            try addBudgetInteger(row["observedInputTokens"] ?? 0, to: &input)
            try addBudgetInteger(row["observedOutputTokens"] ?? 0, to: &output)
            try addBudgetInteger(row["elapsedMilliseconds"], to: &elapsed)
            let unknownReasonRaw: String? = row["unknownCostReason"]
            let pricingKey: String? = row["pricingKey"]
            if let unknownReasonRaw,
               let reason = BudgetUnknownCostReason(rawValue: unknownReasonRaw),
               let pricingKey {
                unknownCost = unknownCost ?? (reason, pricingKey)
                continue
            }
            let actual: Int64? = row["actualCostMicroUnits"]
            let estimated: Int64? = row["estimatedCostMicroUnits"]
            let version: String? = row["pricingVersion"]
            guard let value = actual ?? estimated, let version else {
                unknownCost = unknownCost ?? (
                    .providerChargeUnavailable,
                    "request-cost-unavailable"
                )
                continue
            }
            try addBudgetInteger(value, to: &knownCost)
            allKnownCostsAreActual = allKnownCostsAreActual && actual != nil
            pricingVersions.insert(version)
        }
        let effectiveCurrencyCode = costCurrencyCode ?? policy.currencyCode
        let effectiveCostScale = costScale ?? policy.costScale
        let cost: BudgetCost
        if let unknownCost {
            cost = .unknown(
                reason: unknownCost.0,
                pricingKey: unknownCost.1,
                currencyCode: effectiveCurrencyCode,
                scale: effectiveCostScale
            )
        } else {
            let pricingVersion: String
            if pricingVersions.isEmpty {
                pricingVersion = "no-provider-usage-v1"
            } else if pricingVersions.count == 1 {
                pricingVersion = pricingVersions.first!
            } else {
                pricingVersion = "mixed:\(payloadHash(pricingVersions.sorted().joined(separator: "|")))"
            }
            cost = .known(
                microUnits: knownCost,
                basis: allKnownCostsAreActual ? .actual : .estimated,
                pricingVersion: pricingVersion,
                currencyCode: effectiveCurrencyCode,
                scale: effectiveCostScale
            )
        }
        return try BudgetUsageSnapshot(
            taskID: policy.taskID,
            budgetVersion: policy.version,
            revision: revision,
            cumulativeInputTokens: input,
            cumulativeOutputTokens: output,
            cumulativeCost: cost,
            cumulativeElapsedMilliseconds: elapsed,
            hasUnsettledReservation: unsettled
        )
    }

    static func markProviderRequestSending(
        _ request: ProviderRequestSnapshot,
        policy: TaskBudgetPolicy,
        estimate: NextRequestBudgetEstimate,
        usage: BudgetUsageSnapshot,
        reservation: BudgetReservationCandidate? = nil,
        now: Date,
        in db: Database
    ) throws -> ProviderBudgetSendAuthorization {
        if let reservation {
            guard reservation.validate(
                policy: policy,
                usage: usage,
                nextRequest: estimate
            ) == .valid else {
                throw AppDatabaseError.invalidProviderBudget
            }
        }
        let sending = try ProviderRequestLifecycle.markSending(request, now: now)
        let nextRevision = usage.revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let cost = providerBudgetCostColumns(estimate.reservedCost)
        try db.execute(
            sql: """
                INSERT INTO providerBudgetUsage (
                    providerRequestID, taskID, budgetVersion, usageRevision,
                    status, observedInputTokens, observedOutputTokens,
                    estimatedCostMicroUnits, actualCostMicroUnits,
                    pricingVersion, unknownCostReason, pricingKey,
                    currencyCode, costScale, elapsedMilliseconds,
                    startedAt, finishedAt, updatedAt
                ) VALUES (
                    ?, ?, ?, ?, 'reserved', NULL, NULL, ?, ?, ?, ?, ?,
                    ?, ?, 0, ?, NULL, ?
                )
                """,
            arguments: [
                request.identity.requestID.uuidString,
                usage.taskID.uuidString,
                usage.budgetVersion,
                nextRevision.partialValue,
                cost.estimated,
                cost.actual,
                cost.pricingVersion,
                cost.unknownReason,
                cost.pricingKey,
                cost.currencyCode,
                cost.scale,
                sending.updatedAt.timeIntervalSince1970,
                sending.updatedAt.timeIntervalSince1970
            ]
        )
        try updateProviderRequestRow(
            sending,
            expectedPayloadHash: payloadHash(try encodeProviderRequest(request)),
            in: db
        )
        try updateProviderBackedRun(sending, in: db)
        return ProviderBudgetSendAuthorization(request: sending, isReplay: false)
    }

    static func consumeApprovalAndMarkSending(
        _ approval: StoredProviderBudgetApproval,
        request: ProviderRequestSnapshot,
        policy: TaskBudgetPolicy,
        estimate: NextRequestBudgetEstimate,
        usage: BudgetUsageSnapshot,
        now: Date,
        in db: Database
    ) throws -> ProviderBudgetSendAuthorization {
        try db.execute(
            sql: """
                UPDATE providerBudgetApproval
                SET status = 'consumed', consumedAt = ?, updatedAt = ?
                WHERE id = ? AND status = 'approved'
                """,
            arguments: [
                now.timeIntervalSince1970,
                now.timeIntervalSince1970,
                approval.binding.approvalRequestID.uuidString
            ]
        )
        guard db.changesCount == 1 else {
            throw AppDatabaseError.providerBudgetRequiresApproval
        }
        return try markProviderRequestSending(
            request,
            policy: policy,
            estimate: estimate,
            usage: usage,
            now: now,
            in: db
        )
    }

    static func createProviderBudgetApproval(
        decision: BudgetPreflightDecision,
        estimate: NextRequestBudgetEstimate,
        now: Date,
        in db: Database
    ) throws -> StoredProviderBudgetApproval {
        let approvalID = UUID()
        let nowEpochMilliseconds = try providerBudgetEpochMilliseconds(now)
        let expiry = nowEpochMilliseconds.addingReportingOverflow(
            providerBudgetApprovalLifetimeMilliseconds
        )
        guard !expiry.overflow else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let binding = try BudgetGovernance().makeApprovalBinding(
            approvalRequestID: approvalID,
            decision: decision,
            expiresAtEpochMilliseconds: expiry.partialValue,
            nowEpochMilliseconds: nowEpochMilliseconds
        )
        let json = try encodeProviderBudget(binding)
        guard binding.estimateHash == estimate.canonicalHash else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let estimateJSON = try encodeProviderBudget(estimate)
        let reasonsJSON = try encodeProviderBudget(
            binding.reasons.map(\.rawValue).sorted()
        )
        try db.execute(
            sql: """
                INSERT INTO providerBudgetApproval (
                    id, taskID, budgetVersion, policyHash,
                    usageRevision, usageHash,
                    providerRequestID, exactRequestHash, estimateHash,
                    estimatePayloadJSON, estimatePayloadHash,
                    reasonsJSON, payloadVersion, payloadJSON, payloadHash,
                    bindingHash, status, invalidationReason,
                    expiresAtEpochMilliseconds,
                    createdAt, updatedAt, approvedAt, consumedAt
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, 'pending',
                    NULL, ?, ?, ?, NULL, NULL
                )
                """,
            arguments: [
                approvalID.uuidString,
                binding.taskID.uuidString,
                binding.budgetVersion,
                binding.policyHash,
                binding.usageRevision,
                binding.usageHash,
                binding.providerRequestID.uuidString,
                binding.exactRequestHash,
                binding.estimateHash,
                estimateJSON,
                payloadHash(estimateJSON),
                reasonsJSON,
                json,
                payloadHash(json),
                binding.bindingHash,
                binding.expiresAtEpochMilliseconds,
                now.timeIntervalSince1970,
                now.timeIntervalSince1970
            ]
        )
        return try requiredProviderBudgetApproval(id: approvalID, in: db)
    }

    static func pauseAgentTaskForProviderBudget(
        _ task: AgentTaskSnapshot,
        now: Date,
        in db: Database
    ) throws -> AgentTaskSnapshot {
        if task.status == .paused { return task }
        guard task.status == .running else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let requested = try transitionAgentTask(
            id: task.id,
            expectedRevision: task.revision,
            commandID: UUID(),
            to: .pauseRequested,
            now: now,
            in: db
        ).task
        return try transitionAgentTask(
            id: requested.id,
            expectedRevision: requested.revision,
            commandID: UUID(),
            to: .paused,
            now: now,
            in: db
        ).task
    }

    static func activeProviderBudgetApproval(
        taskID: UUID,
        in db: Database
    ) throws -> StoredProviderBudgetApproval? {
        guard let row = try Row.fetchOne(
            db,
            sql: """
                SELECT * FROM providerBudgetApproval
                WHERE taskID = ? AND status IN ('pending', 'approved')
                ORDER BY createdAt DESC LIMIT 1
                """,
            arguments: [taskID.uuidString]
        ) else { return nil }
        return try decodeProviderBudgetApproval(row)
    }

    static func providerBudgetApproval(
        id: UUID,
        in db: Database
    ) throws -> ProviderBudgetApprovalSnapshot? {
        try providerBudgetApprovalRecord(id: id, in: db).map(approvalSnapshot)
    }

    static func providerBudgetApprovalRecord(
        id: UUID,
        in db: Database
    ) throws -> StoredProviderBudgetApproval? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM providerBudgetApproval WHERE id = ?",
            arguments: [id.uuidString]
        ) else { return nil }
        return try decodeProviderBudgetApproval(row)
    }

    static func requiredProviderBudgetApproval(
        id: UUID,
        in db: Database
    ) throws -> StoredProviderBudgetApproval {
        guard let approval = try providerBudgetApprovalRecord(id: id, in: db) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        return approval
    }

    static func decodeProviderBudgetApproval(
        _ row: Row
    ) throws -> StoredProviderBudgetApproval {
        let binding: BudgetApprovalBinding = try decodeProviderBudgetPayload(row)
        let id: String = row["id"]
        let taskID: String = row["taskID"]
        let budgetVersion: Int64 = row["budgetVersion"]
        let policyHash: String = row["policyHash"]
        let usageRevision: Int64 = row["usageRevision"]
        let usageHash: String = row["usageHash"]
        let requestID: String = row["providerRequestID"]
        let exactRequestHash: String = row["exactRequestHash"]
        let estimateHash: String = row["estimateHash"]
        let estimateJSON: String = row["estimatePayloadJSON"]
        let estimatePayloadHash: String = row["estimatePayloadHash"]
        let bindingHash: String = row["bindingHash"]
        let expiresAtEpochMilliseconds: Int64 = row["expiresAtEpochMilliseconds"]
        let reasonsJSON: String = row["reasonsJSON"]
        guard payloadHash(estimateJSON) == estimatePayloadHash,
              let estimateData = estimateJSON.data(using: .utf8),
              let estimate = try? JSONDecoder().decode(
                NextRequestBudgetEstimate.self,
                from: estimateData
              ),
              let reasonsData = reasonsJSON.data(using: .utf8),
              let reasonNames = try? JSONDecoder().decode(
                [String].self,
                from: reasonsData
              ) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let decodedReasons = reasonNames.compactMap(BudgetApprovalReason.init(rawValue:))
        guard id == binding.approvalRequestID.uuidString,
              taskID == binding.taskID.uuidString,
              budgetVersion == binding.budgetVersion,
              policyHash == binding.policyHash,
              usageRevision == binding.usageRevision,
              usageHash == binding.usageHash,
              requestID == binding.providerRequestID.uuidString,
              exactRequestHash == binding.exactRequestHash,
              estimateHash == binding.estimateHash,
              estimate.canonicalHash == binding.estimateHash,
              estimate.taskID == binding.taskID,
              estimate.requestIdentity.requestID == binding.providerRequestID,
              expiresAtEpochMilliseconds == binding.expiresAtEpochMilliseconds,
              decodedReasons.count == reasonNames.count,
              Set(decodedReasons) == binding.reasons,
              bindingHash == binding.bindingHash,
              let status = ProviderBudgetApprovalStatus(rawValue: row["status"]) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        let approvedAt: Double? = row["approvedAt"]
        let consumedAt: Double? = row["consumedAt"]
        return StoredProviderBudgetApproval(
            binding: binding,
            estimate: estimate,
            status: status,
            invalidationReason: row["invalidationReason"],
            expiresAt: Date(
                timeIntervalSince1970:
                    Double(binding.expiresAtEpochMilliseconds) / 1_000
            ),
            createdAt: Date(timeIntervalSince1970: row["createdAt"]),
            updatedAt: Date(timeIntervalSince1970: row["updatedAt"]),
            approvedAt: approvedAt.map(Date.init(timeIntervalSince1970:)),
            consumedAt: consumedAt.map(Date.init(timeIntervalSince1970:))
        )
    }

    static func approvalSnapshot(
        _ approval: StoredProviderBudgetApproval
    ) -> ProviderBudgetApprovalSnapshot {
        ProviderBudgetApprovalSnapshot(
            id: approval.binding.approvalRequestID,
            taskID: approval.binding.taskID,
            budgetVersion: approval.binding.budgetVersion,
            providerRequestID: approval.binding.providerRequestID,
            bindingHash: approval.binding.bindingHash,
            reasons: approval.binding.reasons,
            estimate: approval.estimate,
            status: approval.status,
            invalidationReason: approval.invalidationReason,
            expiresAt: approval.expiresAt,
            createdAt: approval.createdAt,
            updatedAt: approval.updatedAt,
            approvedAt: approval.approvedAt,
            consumedAt: approval.consumedAt
        )
    }

    static func invalidateProviderBudgetApproval(
        _ id: UUID,
        reason: String,
        now: Date,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
                UPDATE providerBudgetApproval
                SET status = 'invalidated', invalidationReason = ?, updatedAt = ?
                WHERE id = ? AND status IN ('pending', 'approved')
                """,
            arguments: [reason, now.timeIntervalSince1970, id.uuidString]
        )
    }

    static func expireProviderBudgetApproval(
        _ id: UUID,
        now: Date,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
                UPDATE providerBudgetApproval
                SET status = 'expired', invalidationReason = 'expired', updatedAt = ?
                WHERE id = ? AND status = 'pending'
                """,
            arguments: [now.timeIntervalSince1970, id.uuidString]
        )
    }

    static func updateCancelledProviderRun(
        _ request: ProviderRequestSnapshot,
        task: AgentTaskSnapshot,
        in db: Database
    ) throws {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM agentRun WHERE id = ?",
            arguments: [request.identity.runID.uuidString]
        ) else {
            throw AppDatabaseError.invalidAgentRun
        }
        let run = try decodeAgentRun(row)
        try upsertAgentRun(
            AgentRunSnapshot(
                id: run.id,
                projectID: run.projectID,
                kind: run.kind,
                status: .cancelled,
                idempotencyKey: run.idempotencyKey,
                currentStage: "provider.budgetRejected",
                startedAt: run.startedAt,
                updatedAt: max(request.updatedAt, task.updatedAt)
            ),
            conversationID: request.identity.conversationID,
            in: db
        )
    }

    static func providerBudgetCostColumns(
        _ cost: BudgetCost
    ) -> (
        estimated: Int64?, actual: Int64?, pricingVersion: String?,
        unknownReason: String?, pricingKey: String?,
        currencyCode: String, scale: Int64
    ) {
        switch cost {
        case let .known(value, basis, version, currencyCode, scale):
            return basis == .estimated
                ? (value, nil, version, nil, nil, currencyCode, scale)
                : (nil, value, version, nil, nil, currencyCode, scale)
        case let .unknown(reason, key, currencyCode, scale):
            return (
                nil, nil, nil, reason.rawValue, key, currencyCode, scale
            )
        }
    }

    static func providerBudgetPricingKey(
        for request: ProviderRequestSnapshot
    ) -> String {
        [
            request.identity.provider.rawValue,
            request.identity.baseURL.absoluteString,
            request.identity.modelID
        ].joined(separator: "|")
    }

    static func addBudgetInteger(_ value: Int64, to total: inout Int64) throws {
        let next = total.addingReportingOverflow(value)
        guard !next.overflow else {
            throw AppDatabaseError.invalidProviderBudget
        }
        total = next.partialValue
    }

    static func providerBudgetEpochMilliseconds(_ date: Date) throws -> Int64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite,
              milliseconds >= 0,
              milliseconds < Double(Int64.max) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        return Int64(milliseconds.rounded(.down))
    }

    static func encodeProviderBudget<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        return json
    }

    static func decodeProviderBudgetPayload<T: Decodable>(
        _ row: Row
    ) throws -> T {
        let version: Int = row["payloadVersion"]
        let json: String = row["payloadJSON"]
        let hash: String = row["payloadHash"]
        guard version == providerBudgetPayloadVersion,
              hash == payloadHash(json),
              let data = json.data(using: .utf8),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            throw AppDatabaseError.invalidProviderBudget
        }
        return value
    }
}
