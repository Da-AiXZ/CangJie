@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class ProviderBudgetPersistenceTests: XCTestCase {
    func testFreshDatabaseContainsVersionedBudgetTables() throws {
        let database = try AppDatabase(path: temporaryDatabasePath())

        let tables = try database.queue.read { db in
            Set(try String.fetchAll(
                db,
                sql: """
                    SELECT name FROM sqlite_master
                    WHERE type = 'table' AND name LIKE 'providerBudget%'
                    """
            ))
        }

        XCTAssertEqual(tables, [
            "providerBudgetApproval",
            "providerBudgetPolicy",
            "providerBudgetUsage"
        ])
    }

    func testMigrationBackfillsAlreadySentRequestAsLegacyUnknown() throws {
        let path = temporaryDatabasePath()
        let fixture = try makeFixture(databasePath: path)
        let sending = try ProviderRequestLifecycle.markSending(
            fixture.request,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)
        try fixture.database.queue.write { db in
            try db.execute(
                sql: "DROP TRIGGER agentTask_pending_provider_budget_resume_guard"
            )
            try db.execute(sql: "DROP TABLE providerBudgetApproval")
            try db.execute(sql: "DROP TABLE providerBudgetUsage")
            try db.execute(sql: "DROP TABLE providerBudgetPolicy")
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
                arguments: ["s2-provider-budget-v5"]
            )
        }

        let migrated = try AppDatabase(path: path)
        let row = try migrated.queue.read { db in
            try XCTUnwrap(Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM providerBudgetUsage
                    WHERE providerRequestID = ?
                    """,
                arguments: [sending.identity.requestID.uuidString]
            ))
        }
        let status: String = row["status"]
        let budgetVersion: Int64 = row["budgetVersion"]
        let unknownCostReason: String? = row["unknownCostReason"]
        let currencyCode: String = row["currencyCode"]
        let costScale: Int64 = row["costScale"]
        let elapsedMilliseconds: Int64 = row["elapsedMilliseconds"]
        let startedAt: Double? = row["startedAt"]
        let finishedAt: Double? = row["finishedAt"]
        XCTAssertEqual(status, "legacyUnknown")
        XCTAssertEqual(budgetVersion, 0)
        XCTAssertEqual(unknownCostReason, "providerChargeUnavailable")
        XCTAssertEqual(currencyCode, "CNY")
        XCTAssertEqual(costScale, BudgetCost.microUnitScale)
        XCTAssertEqual(elapsedMilliseconds, 1_000)
        XCTAssertEqual(startedAt, fixture.now.timeIntervalSince1970)
        XCTAssertNil(finishedAt)
        XCTAssertEqual(
            try migrated.providerRequest(id: sending.identity.requestID),
            sending
        )

        let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
            sending,
            reason: .lifecycleInterruption,
            now: fixture.now.addingTimeInterval(2)
        )
        try migrated.updateProviderRequest(unknown)
        let reconciledRow = try migrated.queue.read { db in
            try XCTUnwrap(Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM providerBudgetUsage
                    WHERE providerRequestID = ?
                    """,
                arguments: [sending.identity.requestID.uuidString]
            ))
        }
        let reconciledStatus: String = reconciledRow["status"]
        let reconciledElapsed: Int64 = reconciledRow["elapsedMilliseconds"]
        let reconciledStartedAt: Double? = reconciledRow["startedAt"]
        let reconciledFinishedAt: Double? = reconciledRow["finishedAt"]
        XCTAssertEqual(reconciledStatus, "outcomeUnknown")
        XCTAssertEqual(reconciledElapsed, 2_000)
        XCTAssertEqual(reconciledStartedAt, fixture.now.timeIntervalSince1970)
        XCTAssertEqual(
            reconciledFinishedAt,
            unknown.updatedAt.timeIntervalSince1970
        )
        XCTAssertEqual(
            try migrated.providerRequest(id: sending.identity.requestID),
            unknown
        )
        try migrated.queue.write { db in
            try AppDatabase.settleProviderBudgetUsageIfPresent(
                unknown,
                in: db
            )
        }
    }

    func testMigrationBackfillsHistoricalFailureAsRejectedAndRetryRequiresApproval() throws {
        let path = temporaryDatabasePath()
        let fixture = try makeFixture(databasePath: path)
        let sending = try ProviderRequestLifecycle.markSending(
            fixture.request,
            now: fixture.now.addingTimeInterval(1)
        )
        try fixture.database.updateProviderRequest(sending)
        let rejected = try ProviderRequestLifecycle.reject(
            sending,
            failure: .rateLimited,
            now: fixture.now.addingTimeInterval(2)
        )
        try fixture.database.updateProviderRequest(rejected)
        try fixture.database.queue.write { db in
            try db.execute(
                sql: "DROP TRIGGER agentTask_pending_provider_budget_resume_guard"
            )
            try db.execute(sql: "DROP TABLE providerBudgetApproval")
            try db.execute(sql: "DROP TABLE providerBudgetUsage")
            try db.execute(sql: "DROP TABLE providerBudgetPolicy")
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
                arguments: ["s2-provider-budget-v5"]
            )
        }

        let migrated = try AppDatabase(path: path)
        let row = try migrated.queue.read { db in
            try XCTUnwrap(Row.fetchOne(
                db,
                sql: """
                    SELECT * FROM providerBudgetUsage
                    WHERE providerRequestID = ?
                    """,
                arguments: [rejected.identity.requestID.uuidString]
            ))
        }
        let status: String = row["status"]
        let budgetVersion: Int64 = row["budgetVersion"]
        let observedInputTokens: Int64? = row["observedInputTokens"]
        let observedOutputTokens: Int64? = row["observedOutputTokens"]
        let unknownCostReason: String? = row["unknownCostReason"]
        let elapsedMilliseconds: Int64 = row["elapsedMilliseconds"]
        let startedAt: Double? = row["startedAt"]
        let finishedAt: Double? = row["finishedAt"]
        XCTAssertEqual(status, "rejected")
        XCTAssertEqual(budgetVersion, 0)
        XCTAssertNil(observedInputTokens)
        XCTAssertNil(observedOutputTokens)
        XCTAssertEqual(unknownCostReason, "providerChargeUnavailable")
        XCTAssertEqual(elapsedMilliseconds, 2_000)
        XCTAssertEqual(startedAt, rejected.createdAt.timeIntervalSince1970)
        XCTAssertEqual(finishedAt, rejected.updatedAt.timeIntervalSince1970)
        XCTAssertEqual(
            try migrated.providerRequest(id: rejected.identity.requestID),
            rejected
        )

        let task = try XCTUnwrap(
            migrated.agentTask(intentID: fixture.intent.id)
        )
        let policy = try makePolicy(taskID: task.id)
        _ = try migrated.storeProviderBudgetPolicy(
            policy,
            now: fixture.now.addingTimeInterval(3)
        )
        let usage = try migrated.providerBudgetUsageSnapshot(taskID: task.id)
        let pricingKey = [
            rejected.identity.provider.rawValue,
            rejected.identity.baseURL.absoluteString,
            rejected.identity.modelID
        ].joined(separator: "|")
        XCTAssertEqual(usage.cumulativeInputTokens, 0)
        XCTAssertEqual(usage.cumulativeOutputTokens, 0)
        XCTAssertFalse(usage.hasUnsettledReservation)
        XCTAssertEqual(
            usage.cumulativeCost,
            .unknown(
                reason: .providerChargeUnavailable,
                pricingKey: pricingKey,
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )

        let retryAt = fixture.now.addingTimeInterval(4)
        let retry = try ProviderRequestLifecycle.prepare(
            requestID: UUID(),
            runID: UUID(),
            idempotencyKey: "provider.request.\(fixture.intent.id.uuidString).2.1",
            attemptNumber: 2,
            turnSequence: 1,
            previousRequestID: rejected.identity.requestID,
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection,
            responseAssetID: UUID(),
            promptManifestHash: rejected.promptManifestHash,
            contextManifestHash: rejected.contextManifestHash,
            toolCatalogManifestHash: rejected.toolCatalogManifestHash,
            disclosureScopeHash: rejected.disclosureScopeHash,
            requestPolicyHash: rejected.requestPolicyHash,
            now: retryAt
        )
        _ = try migrated.persistExplicitProviderRetry(
            retry,
            intent: fixture.intent,
            verifiedConnection: fixture.verifiedConnection,
            failedTaskID: task.id,
            expectedTaskRevision: task.revision,
            commandID: retry.identity.requestID,
            now: retryAt
        )

        let gate = try migrated.authorizeAndMarkProviderRequestSending(
            retry,
            initialPolicy: policy,
            estimate: try makeEstimate(taskID: task.id, request: retry),
            now: fixture.now.addingTimeInterval(5)
        )
        guard case let .requiresApproval(approval) = gate else {
            return XCTFail("Unknown historical charge must require approval")
        }
        XCTAssertEqual(approval.reasons, [.cumulativeCostUnavailable])
    }

    func testMigrationBackfillsCompletedAndTerminatedLifecycleElapsed() throws {
        let completedPath = temporaryDatabasePath()
        let completedFixture = try makeFixture(databasePath: completedPath)
        let completed = try persistHistoricalCompletedRequest(
            database: completedFixture.database,
            request: completedFixture.request,
            now: completedFixture.now,
            usage: ProviderUsage(
                inputTokens: 11,
                outputTokens: 7,
                totalTokens: 18
            )
        )
        try removeProviderBudgetV5State(from: completedFixture.database)

        let migratedCompleted = try AppDatabase(path: completedPath)
        let completedTask = try XCTUnwrap(
            migratedCompleted.agentTask(intentID: completedFixture.intent.id)
        )
        _ = try migratedCompleted.storeProviderBudgetPolicy(
            try makePolicy(taskID: completedTask.id),
            now: completedFixture.now.addingTimeInterval(4)
        )
        let completedUsage = try migratedCompleted.providerBudgetUsageSnapshot(
            taskID: completedTask.id
        )
        XCTAssertEqual(completedUsage.cumulativeInputTokens, 11)
        XCTAssertEqual(completedUsage.cumulativeOutputTokens, 7)
        XCTAssertEqual(completedUsage.cumulativeElapsedMilliseconds, 3_000)
        XCTAssertFalse(completedUsage.hasUnsettledReservation)
        let completedRow = try migratedCompleted.queue.read { db in
            try XCTUnwrap(Row.fetchOne(
                db,
                sql: "SELECT * FROM providerBudgetUsage WHERE providerRequestID = ?",
                arguments: [completed.identity.requestID.uuidString]
            ))
        }
        let completedStartedAt: Double? = completedRow["startedAt"]
        let completedFinishedAt: Double? = completedRow["finishedAt"]
        XCTAssertEqual(completedStartedAt, completed.createdAt.timeIntervalSince1970)
        XCTAssertEqual(completedFinishedAt, completed.updatedAt.timeIntervalSince1970)

        let terminatedPath = temporaryDatabasePath()
        let terminatedFixture = try makeFixture(
            now: Date(timeIntervalSince1970: 4_000),
            databasePath: terminatedPath
        )
        let responseComplete = try persistHistoricalCompletedRequest(
            database: terminatedFixture.database,
            request: terminatedFixture.request,
            now: terminatedFixture.now,
            usage: ProviderUsage(
                inputTokens: 13,
                outputTokens: 9,
                totalTokens: 22
            )
        )
        _ = try terminatedFixture.database.settleAgentTaskAtProviderTurnLimit(
            intentID: terminatedFixture.intent.id,
            now: terminatedFixture.now.addingTimeInterval(5)
        )
        let terminated = try XCTUnwrap(
            terminatedFixture.database.providerRequest(
                id: responseComplete.identity.requestID
            )
        )
        XCTAssertEqual(terminated.phase, .terminated)
        try removeProviderBudgetV5State(from: terminatedFixture.database)

        let migratedTerminated = try AppDatabase(path: terminatedPath)
        let terminatedTask = try XCTUnwrap(
            migratedTerminated.agentTask(intentID: terminatedFixture.intent.id)
        )
        _ = try migratedTerminated.storeProviderBudgetPolicy(
            try makePolicy(taskID: terminatedTask.id),
            now: terminatedFixture.now.addingTimeInterval(6)
        )
        let terminatedUsage = try migratedTerminated.providerBudgetUsageSnapshot(
            taskID: terminatedTask.id
        )
        XCTAssertEqual(terminatedUsage.cumulativeInputTokens, 13)
        XCTAssertEqual(terminatedUsage.cumulativeOutputTokens, 9)
        XCTAssertEqual(terminatedUsage.cumulativeElapsedMilliseconds, 5_000)
        XCTAssertFalse(terminatedUsage.hasUnsettledReservation)
        let terminatedRow = try migratedTerminated.queue.read { db in
            try XCTUnwrap(Row.fetchOne(
                db,
                sql: "SELECT * FROM providerBudgetUsage WHERE providerRequestID = ?",
                arguments: [terminated.identity.requestID.uuidString]
            ))
        }
        let terminatedStartedAt: Double? = terminatedRow["startedAt"]
        let terminatedFinishedAt: Double? = terminatedRow["finishedAt"]
        XCTAssertEqual(terminatedStartedAt, terminated.createdAt.timeIntervalSince1970)
        XCTAssertEqual(terminatedFinishedAt, terminated.updatedAt.timeIntervalSince1970)
    }

    func testWithinBudgetAtomicallyMarksSendingAndReservesUsage() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let policy = try makePolicy(taskID: task.id)
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            inputTokens: 100,
            outputTokens: 200,
            cost: .known(
                microUnits: 300,
                basis: .estimated,
                pricingVersion: "deepseek-2026-07",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            ),
            elapsedMilliseconds: 400
        )

        let result = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: policy,
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )

        guard case let .authorized(authorization) = result else {
            return XCTFail("Expected an authorized send, got \(result)")
        }
        XCTAssertFalse(authorization.isReplay)
        XCTAssertEqual(authorization.request.phase, .sending)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .sending
        )
        let usage = try fixture.database.providerBudgetUsageSnapshot(taskID: task.id)
        XCTAssertEqual(usage.budgetVersion, policy.version)
        XCTAssertEqual(usage.cumulativeInputTokens, 0)
        XCTAssertEqual(usage.cumulativeOutputTokens, 0)
        XCTAssertTrue(usage.hasUnsettledReservation)
    }

    func testPauseDuringPreparedBudgetWindowSettlesToPaused() throws {
        let fixture = try makeFixture()
        let running = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        _ = try fixture.database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .pauseRequested,
            now: fixture.now.addingTimeInterval(1)
        )

        let settled = try fixture.database.settleAgentTaskControlAfterProviderExit(
            intentID: fixture.intent.id,
            now: fixture.now.addingTimeInterval(2)
        )

        XCTAssertEqual(settled?.status, .paused)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .cancelled
        )
    }

    func testUnknownPricingPausesWithExactApprovalAndOrdinaryResumeFailsClosed() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            cost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: "deepseek|deepseek-chat",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )

        let result = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )

        guard case let .requiresApproval(approval) = result else {
            return XCTFail("Expected a durable approval, got \(result)")
        }
        XCTAssertEqual(approval.taskID, task.id)
        XCTAssertEqual(approval.providerRequestID, fixture.request.identity.requestID)
        XCTAssertEqual(approval.status, .pending)
        XCTAssertEqual(approval.estimate, estimate)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .prepared
        )
        let paused = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        XCTAssertEqual(paused.status, .paused)
        XCTAssertThrowsError(
            try fixture.database.transitionAgentTask(
                id: paused.id,
                expectedRevision: paused.revision,
                commandID: UUID(),
                to: .running,
                now: fixture.now.addingTimeInterval(2)
            )
        )
        XCTAssertEqual(
            try fixture.database.pendingProviderBudgetApproval(taskID: task.id),
            approval
        )
    }

    func testApprovalOnlyResumesPreparedRequestAndGateConsumesItOnce() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            cost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: "deepseek|deepseek-chat",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        let gate = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        guard case let .requiresApproval(approval) = gate else {
            return XCTFail("Expected approval")
        }

        let approved = try fixture.database.approveProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            estimate: estimate,
            now: fixture.now.addingTimeInterval(2)
        )
        XCTAssertEqual(approved.status, .approved)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .prepared
        )
        XCTAssertEqual(
            try fixture.database.agentTask(intentID: fixture.intent.id)?.status,
            .running
        )

        let first = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(3)
        )
        let replay = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(4)
        )

        guard case let .authorized(firstAuthorization) = first,
              case let .authorized(replayAuthorization) = replay else {
            return XCTFail("Expected exact gate authorization and replay")
        }
        XCTAssertFalse(firstAuthorization.isReplay)
        XCTAssertEqual(firstAuthorization.request.phase, .sending)
        XCTAssertTrue(replayAuthorization.isReplay)
        XCTAssertEqual(
            replayAuthorization.request.identity.requestID,
            firstAuthorization.request.identity.requestID
        )
        XCTAssertEqual(
            try fixture.database.providerBudgetApproval(id: approval.id)?.status,
            .consumed
        )
    }

    func testExpiredAndChangedApprovalStatesPersistAfterCallerReceivesError() throws {
        let expiredFixture = try makeFixture()
        let expiredTask = try XCTUnwrap(
            expiredFixture.database.agentTask(intentID: expiredFixture.intent.id)
        )
        let expiredEstimate = try makeEstimate(
            taskID: expiredTask.id,
            request: expiredFixture.request,
            cost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: "expired-price",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        let expiredGate = try expiredFixture.database
            .authorizeAndMarkProviderRequestSending(
                expiredFixture.request,
                initialPolicy: try makePolicy(taskID: expiredTask.id),
                estimate: expiredEstimate,
                now: expiredFixture.now
            )
        guard case let .requiresApproval(expiredApproval) = expiredGate else {
            return XCTFail("Expected approval")
        }

        XCTAssertThrowsError(
            try expiredFixture.database.approveProviderBudgetApproval(
                approvalID: expiredApproval.id,
                displayedBindingHash: expiredApproval.bindingHash,
                estimate: expiredEstimate,
                now: expiredApproval.expiresAt.addingTimeInterval(1)
            )
        ) { error in
            XCTAssertEqual(
                error as? AppDatabaseError,
                .providerBudgetApprovalExpired
            )
        }
        XCTAssertEqual(
            try expiredFixture.database.providerBudgetApproval(
                id: expiredApproval.id
            )?.status,
            .expired
        )

        let changedFixture = try makeFixture()
        let changedTask = try XCTUnwrap(
            changedFixture.database.agentTask(intentID: changedFixture.intent.id)
        )
        let originalEstimate = try makeEstimate(
            taskID: changedTask.id,
            request: changedFixture.request,
            cost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: "original-price",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        let changedGate = try changedFixture.database
            .authorizeAndMarkProviderRequestSending(
                changedFixture.request,
                initialPolicy: try makePolicy(taskID: changedTask.id),
                estimate: originalEstimate,
                now: changedFixture.now
            )
        guard case let .requiresApproval(changedApproval) = changedGate else {
            return XCTFail("Expected approval")
        }
        let changedEstimate = try makeEstimate(
            taskID: changedTask.id,
            request: changedFixture.request,
            outputTokens: 1,
            cost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: "changed-price",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )

        XCTAssertThrowsError(
            try changedFixture.database.approveProviderBudgetApproval(
                approvalID: changedApproval.id,
                displayedBindingHash: changedApproval.bindingHash,
                estimate: changedEstimate,
                now: changedFixture.now.addingTimeInterval(1)
            )
        )
        XCTAssertEqual(
            try changedFixture.database.providerBudgetApproval(
                id: changedApproval.id
            )?.status,
            .invalidated
        )
    }

    func testRejectCancelsPreparedRequestAndResolvesUnadoptedTask() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            outputTokens: 20_000
        )
        let gate = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        guard case let .requiresApproval(approval) = gate else {
            return XCTFail("Expected approval")
        }

        let rejected = try fixture.database.rejectProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            now: fixture.now.addingTimeInterval(2)
        )

        XCTAssertEqual(rejected.status, .discarded)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .cancelled
        )
        XCTAssertEqual(
            try fixture.database.providerBudgetApproval(id: approval.id)?.status,
            .rejected
        )
        XCTAssertNil(try fixture.database.pendingModelIntent(id: fixture.intent.id))
    }

    func testApprovedRequestCanBeRejectedWhileWaitingForConnectionRecovery() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            cost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: "connection-recovery",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        let gate = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now
        )
        guard case let .requiresApproval(approval) = gate else {
            return XCTFail("Expected approval")
        }
        _ = try fixture.database.approveProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        let running = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        _ = try fixture.database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .waitingUser,
            waitingReason: .connectionInvalid,
            now: fixture.now.addingTimeInterval(2)
        )

        let rejected = try fixture.database.rejectProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            now: fixture.now.addingTimeInterval(3)
        )

        XCTAssertEqual(rejected.status, .discarded)
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .cancelled
        )
    }

    func testRejectKeepsCommittedToolReceiptAndItsArtifact() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let toolResult = try fixture.database.executeArtifactTool(
            conversationID: fixture.intent.conversationID,
            projectID: nil,
            toolID: "artifact.save",
            kind: "provider-budget-test",
            title: "已完成成果",
            body: "必须在拒绝后保留",
            status: "completed",
            idempotencyKey: "provider-budget.receipt.\(task.id.uuidString)",
            now: fixture.now.addingTimeInterval(0.5)
        )
        try fixture.database.queue.write { db in
            try db.execute(
                sql: "UPDATE toolReceipt SET originRunID = ? WHERE id = ?",
                arguments: [
                    fixture.request.identity.runID.uuidString,
                    toolResult.receipt.id.uuidString
                ]
            )
        }
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            outputTokens: 20_000
        )
        let gate = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        guard case let .requiresApproval(approval) = gate else {
            return XCTFail("Expected approval")
        }

        let rejected = try fixture.database.rejectProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            now: fixture.now.addingTimeInterval(2)
        )

        XCTAssertEqual(rejected.status, .completed)
        XCTAssertEqual(rejected.outcome, .kept)
        XCTAssertEqual(
            try fixture.database.toolReceipt(
                idempotencyKey: toolResult.receipt.idempotencyKey!
            )?.id,
            toolResult.receipt.id
        )
        XCTAssertEqual(
            try fixture.database.latestArtifact(kind: "provider-budget-test")?.id,
            toolResult.artifact.id
        )
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .cancelled
        )
    }

    func testApprovedRequestCanBeRejectedAfterACommittedToolReceipt() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let toolResult = try fixture.database.executeArtifactTool(
            conversationID: fixture.intent.conversationID,
            projectID: nil,
            toolID: "artifact.save",
            kind: "provider-budget-approved-rejection",
            title: "已完成成果",
            body: "批准后的拒绝仍必须保留",
            status: "completed",
            idempotencyKey: "provider-budget.approved-receipt.\(task.id.uuidString)",
            now: fixture.now.addingTimeInterval(0.5)
        )
        try fixture.database.queue.write { db in
            try db.execute(
                sql: "UPDATE toolReceipt SET originRunID = ? WHERE id = ?",
                arguments: [
                    fixture.request.identity.runID.uuidString,
                    toolResult.receipt.id.uuidString
                ]
            )
        }
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request,
            outputTokens: 20_000
        )
        let gate = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: try makePolicy(taskID: task.id),
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        guard case let .requiresApproval(approval) = gate else {
            return XCTFail("Expected approval")
        }
        _ = try fixture.database.approveProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            estimate: estimate,
            now: fixture.now.addingTimeInterval(2)
        )
        let running = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        _ = try fixture.database.transitionAgentTask(
            id: running.id,
            expectedRevision: running.revision,
            commandID: UUID(),
            to: .waitingUser,
            waitingReason: .connectionInvalid,
            now: fixture.now.addingTimeInterval(3)
        )

        let rejected = try fixture.database.rejectProviderBudgetApproval(
            approvalID: approval.id,
            displayedBindingHash: approval.bindingHash,
            now: fixture.now.addingTimeInterval(4)
        )

        XCTAssertEqual(rejected.status, .completed)
        XCTAssertEqual(rejected.outcome, .kept)
        XCTAssertEqual(
            try fixture.database.toolReceipt(
                idempotencyKey: toolResult.receipt.idempotencyKey!
            )?.id,
            toolResult.receipt.id
        )
        XCTAssertEqual(
            try fixture.database.providerRequest(id: fixture.request.identity.requestID)?.phase,
            .cancelled
        )
    }

    func testCompletedAndUnknownUsageSettlementAreIdempotent() throws {
        let completedFixture = try makeFixture()
        let completedTask = try XCTUnwrap(
            completedFixture.database.agentTask(intentID: completedFixture.intent.id)
        )
        let completedEstimate = try makeEstimate(
            taskID: completedTask.id,
            request: completedFixture.request,
            inputTokens: 100,
            outputTokens: 200,
            cost: .known(
                microUnits: 300,
                basis: .estimated,
                pricingVersion: "deepseek-2026-07",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            ),
            elapsedMilliseconds: 400
        )
        let completedGate = try completedFixture.database
            .authorizeAndMarkProviderRequestSending(
                completedFixture.request,
                initialPolicy: try makePolicy(taskID: completedTask.id),
                estimate: completedEstimate,
                now: completedFixture.now.addingTimeInterval(1)
            )
        guard case let .authorized(completedAuthorization) = completedGate else {
            return XCTFail("Expected completed fixture authorization")
        }
        let payload = ProviderResponsePayload(
            text: "完成",
            toolCalls: [],
            finishReason: "stop"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadJSON = try XCTUnwrap(
            String(data: try encoder.encode(payload), encoding: .utf8)
        )
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            completedAuthorization.request,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            now: completedFixture.now.addingTimeInterval(2)
        )
        try completedFixture.database.checkpointProviderResponse(
            streaming,
            responsePayloadJSON: payloadJSON
        )
        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: AppDatabase.payloadHash(payloadJSON),
            usage: ProviderUsage(
                inputTokens: 11,
                outputTokens: 7,
                totalTokens: 18
            ),
            now: completedFixture.now.addingTimeInterval(3)
        )
        try completedFixture.database.completeProviderResponse(completed)
        try completedFixture.database.queue.write { db in
            try AppDatabase.settleProviderBudgetUsageIfPresent(completed, in: db)
        }
        let completedUsage = try completedFixture.database
            .providerBudgetUsageSnapshot(taskID: completedTask.id)
        XCTAssertEqual(completedUsage.cumulativeInputTokens, 11)
        XCTAssertEqual(completedUsage.cumulativeOutputTokens, 7)
        XCTAssertEqual(completedUsage.cumulativeElapsedMilliseconds, 2_000)
        XCTAssertFalse(completedUsage.hasUnsettledReservation)

        let unknownFixture = try makeFixture(now: Date(timeIntervalSince1970: 4_000))
        let unknownTask = try XCTUnwrap(
            unknownFixture.database.agentTask(intentID: unknownFixture.intent.id)
        )
        let unknownEstimate = try makeEstimate(
            taskID: unknownTask.id,
            request: unknownFixture.request,
            cost: .known(
                microUnits: 300,
                basis: .estimated,
                pricingVersion: "deepseek-2026-07",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        let unknownGate = try unknownFixture.database
            .authorizeAndMarkProviderRequestSending(
                unknownFixture.request,
                initialPolicy: try makePolicy(taskID: unknownTask.id),
                estimate: unknownEstimate,
                now: unknownFixture.now.addingTimeInterval(1)
            )
        guard case let .authorized(unknownAuthorization) = unknownGate else {
            return XCTFail("Expected unknown fixture authorization")
        }
        let unknown = try ProviderRequestLifecycle.markOutcomeUnknown(
            unknownAuthorization.request,
            reason: .network,
            now: unknownFixture.now.addingTimeInterval(2)
        )
        try unknownFixture.database.updateProviderRequest(unknown)
        try unknownFixture.database.queue.write { db in
            try AppDatabase.settleProviderBudgetUsageIfPresent(unknown, in: db)
        }
        let unknownUsage = try unknownFixture.database
            .providerBudgetUsageSnapshot(taskID: unknownTask.id)
        XCTAssertEqual(
            unknownUsage.cumulativeCost,
            .unknown(
                reason: .outcomeUnknown,
                pricingKey: "deepSeek|https://api.deepseek.com|deepseek-chat",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        XCTAssertTrue(unknownUsage.hasUnsettledReservation)
    }

    func testDefinitiveProviderRejectionSettlesReservationForExplicitRetry() throws {
        let fixture = try makeFixture()
        let task = try XCTUnwrap(
            fixture.database.agentTask(intentID: fixture.intent.id)
        )
        let policy = try makePolicy(taskID: task.id)
        let estimate = try makeEstimate(
            taskID: task.id,
            request: fixture.request
        )
        let gate = try fixture.database.authorizeAndMarkProviderRequestSending(
            fixture.request,
            initialPolicy: policy,
            estimate: estimate,
            now: fixture.now.addingTimeInterval(1)
        )
        guard case let .authorized(authorization) = gate else {
            return XCTFail("Expected authorized request")
        }
        let rejected = try ProviderRequestLifecycle.reject(
            authorization.request,
            failure: .rateLimited,
            now: fixture.now.addingTimeInterval(2)
        )

        try fixture.database.updateProviderRequest(rejected)

        let usage = try fixture.database.providerBudgetUsageSnapshot(
            taskID: task.id
        )
        XCTAssertFalse(usage.hasUnsettledReservation)
        XCTAssertEqual(
            usage.cumulativeCost,
            .unknown(
                reason: .providerChargeUnavailable,
                pricingKey: [
                    rejected.identity.provider.rawValue,
                    rejected.identity.baseURL.absoluteString,
                    rejected.identity.modelID
                ].joined(separator: "|"),
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
    }

    private func persistHistoricalCompletedRequest(
        database: AppDatabase,
        request: ProviderRequestSnapshot,
        now: Date,
        usage: ProviderUsage
    ) throws -> ProviderRequestSnapshot {
        let sending = try ProviderRequestLifecycle.markSending(
            request,
            now: now.addingTimeInterval(1)
        )
        try database.updateProviderRequest(sending)
        let payload = ProviderResponsePayload(
            text: "completed",
            toolCalls: [],
            finishReason: "stop"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadJSON = try XCTUnwrap(
            String(data: try encoder.encode(payload), encoding: .utf8)
        )
        let responseHash = AppDatabase.payloadHash(payloadJSON)
        let streaming = try ProviderRequestLifecycle.checkpointStream(
            sending,
            cursor: 1,
            receivedUTF8Bytes: payloadJSON.utf8.count,
            responseHash: responseHash,
            now: now.addingTimeInterval(2)
        )
        try database.checkpointProviderResponse(
            streaming,
            responsePayloadJSON: payloadJSON
        )
        let completed = try ProviderRequestLifecycle.complete(
            streaming,
            responseHash: responseHash,
            usage: usage,
            now: now.addingTimeInterval(3)
        )
        try database.completeProviderResponse(completed)
        return completed
    }

    private func removeProviderBudgetV5State(from database: AppDatabase) throws {
        try database.queue.write { db in
            try db.execute(
                sql: "DROP TRIGGER agentTask_pending_provider_budget_resume_guard"
            )
            try db.execute(sql: "DROP TABLE providerBudgetApproval")
            try db.execute(sql: "DROP TABLE providerBudgetUsage")
            try db.execute(sql: "DROP TABLE providerBudgetPolicy")
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
                arguments: ["s2-provider-budget-v5"]
            )
        }
    }

    private func makeFixture(
        now: Date = Date(timeIntervalSince1970: 2_000),
        databasePath: String? = nil
    ) throws -> (
        database: AppDatabase,
        intent: PendingModelIntent,
        verifiedConnection: VerifiedModelConnection,
        request: ProviderRequestSnapshot,
        now: Date
    ) {
        let database = try AppDatabase(
            path: databasePath ?? temporaryDatabasePath()
        )
        let conversation = try database.ensureDefaultConversation(now: now)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: conversation.id,
            projectID: nil,
            branchID: nil,
            userRequest: "Create a suspense novel",
            createdAt: now
        )
        _ = try database.storePendingModelIntent(
            intent,
            admissionCondition: .ready
        )
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat",
            secret: "fixture-secret"
        )
        _ = try database.storeModelConnection(
            connection,
            makeCurrent: true,
            now: now
        )
        let verification = try ModelCredentialVerification(
            reference: connection.credential,
            credentialVersionProof: hash("a"),
            credentialPayloadHash: hash("b"),
            setupAuthorizationHash: hash("c")
        )
        let verified = try VerifiedModelConnection(
            connection: connection,
            credentialVerification: verification
        )
        let request = try ProviderRequestLifecycle.prepare(
            requestID: UUID(),
            runID: UUID(),
            idempotencyKey: "provider.request.\(intent.id.uuidString).1.1",
            intent: intent,
            verifiedConnection: verified,
            responseAssetID: UUID(),
            promptManifestHash: hash("1"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: hash("3"),
            disclosureScopeHash: hash("4"),
            requestPolicyHash: hash("5"),
            now: now
        )
        _ = try database.persistPreparedProviderRequest(
            request,
            verifiedConnection: verified
        )
        return (database, intent, verified, request, now)
    }

    private func makePolicy(taskID: UUID) throws -> TaskBudgetPolicy {
        try TaskBudgetPolicy(
            taskID: taskID,
            version: 1,
            maximumInputTokens: 64_000,
            maximumOutputTokens: 8_192,
            maximumCostMicroUnits: 2_000_000,
            currencyCode: "CNY",
            costScale: BudgetCost.microUnitScale,
            maximumElapsedMilliseconds: 600_000
        )
    }

    private func makeEstimate(
        taskID: UUID,
        request: ProviderRequestSnapshot,
        inputTokens: Int64 = 0,
        outputTokens: Int64 = 0,
        cost: BudgetCost = .known(
            microUnits: 0,
            basis: .estimated,
            pricingVersion: "deepseek-2026-07",
            currencyCode: "CNY",
            scale: BudgetCost.microUnitScale
        ),
        elapsedMilliseconds: Int64 = 0
    ) throws -> NextRequestBudgetEstimate {
        try NextRequestBudgetEstimate(
            requestIdentity: ProviderRequestBudgetIdentity(
                trustedTaskScope: ProviderRequestBudgetTaskScope(
                    taskID: taskID,
                    intentID: request.identity.intentID,
                    activeRunID: request.identity.runID
                ),
                request: request
            ),
            reservedInputTokens: inputTokens,
            reservedOutputTokens: outputTokens,
            reservedCost: cost,
            reservedElapsedMilliseconds: elapsedMilliseconds
        )
    }

    private func temporaryDatabasePath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-budget-\(UUID().uuidString).sqlite")
            .path
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
