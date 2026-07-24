import CangJieCore
import Foundation
import GRDB

extension AppDatabase {
    static func migrateProviderBudget(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE providerBudgetPolicy (
                taskID TEXT NOT NULL
                    REFERENCES agentTask(id) ON DELETE RESTRICT,
                version INTEGER NOT NULL CHECK (version > 0),
                payloadVersion INTEGER NOT NULL CHECK (payloadVersion = 1),
                payloadJSON TEXT NOT NULL,
                payloadHash TEXT NOT NULL CHECK (
                    length(payloadHash) = 64
                    AND payloadHash NOT GLOB '*[^0-9a-f]*'
                ),
                createdAt DOUBLE NOT NULL,
                PRIMARY KEY (taskID, version)
            )
            """)
        try db.execute(sql: """
            CREATE TRIGGER providerBudgetPolicy_immutable
            BEFORE UPDATE ON providerBudgetPolicy
            BEGIN
                SELECT RAISE(ABORT, 'provider budget policy is immutable');
            END
            """)

        try db.execute(sql: """
            CREATE TABLE providerBudgetUsage (
                providerRequestID TEXT PRIMARY KEY NOT NULL
                    REFERENCES providerRequest(id) ON DELETE RESTRICT,
                taskID TEXT NOT NULL
                    REFERENCES agentTask(id) ON DELETE RESTRICT,
                budgetVersion INTEGER NOT NULL CHECK (budgetVersion >= 0),
                usageRevision INTEGER NOT NULL CHECK (usageRevision > 0),
                status TEXT NOT NULL CHECK (
                    status IN (
                        'reserved', 'completed', 'outcomeUnknown',
                        'rejected', 'legacyUnknown'
                    )
                ),
                observedInputTokens INTEGER CHECK (
                    observedInputTokens IS NULL OR observedInputTokens >= 0
                ),
                observedOutputTokens INTEGER CHECK (
                    observedOutputTokens IS NULL OR observedOutputTokens >= 0
                ),
                estimatedCostMicroUnits INTEGER CHECK (
                    estimatedCostMicroUnits IS NULL
                    OR estimatedCostMicroUnits >= 0
                ),
                actualCostMicroUnits INTEGER CHECK (
                    actualCostMicroUnits IS NULL OR actualCostMicroUnits >= 0
                ),
                pricingVersion TEXT,
                unknownCostReason TEXT CHECK (
                    unknownCostReason IS NULL OR unknownCostReason IN (
                        'pricingUnavailable', 'providerChargeUnavailable',
                        'outcomeUnknown'
                    )
                ),
                pricingKey TEXT,
                currencyCode TEXT NOT NULL CHECK (
                    length(currencyCode) = 3
                    AND currencyCode NOT GLOB '*[^A-Z]*'
                ),
                costScale INTEGER NOT NULL CHECK (costScale = 1000000),
                elapsedMilliseconds INTEGER NOT NULL
                    CHECK (elapsedMilliseconds >= 0),
                startedAt DOUBLE,
                finishedAt DOUBLE,
                updatedAt DOUBLE NOT NULL,
                CHECK (
                    (unknownCostReason IS NULL AND pricingKey IS NULL)
                    OR (
                        unknownCostReason IS NOT NULL
                        AND pricingKey IS NOT NULL
                        AND length(pricingKey) > 0
                        AND estimatedCostMicroUnits IS NULL
                        AND actualCostMicroUnits IS NULL
                    )
                ),
                CHECK (
                    estimatedCostMicroUnits IS NULL
                    OR actualCostMicroUnits IS NULL
                ),
                UNIQUE (taskID, usageRevision)
            )
            """)
        try db.execute(sql: """
            CREATE INDEX providerBudgetUsage_task
            ON providerBudgetUsage (taskID, usageRevision)
            """)
        try db.execute(sql: """
            CREATE TRIGGER providerBudgetUsage_identity_immutable
            BEFORE UPDATE OF providerRequestID, taskID, budgetVersion
            ON providerBudgetUsage
            BEGIN
                SELECT RAISE(ABORT, 'provider budget usage identity is immutable');
            END
            """)
        try db.execute(sql: """
            CREATE TRIGGER providerBudgetUsage_monotonic
            BEFORE UPDATE ON providerBudgetUsage
            WHEN NEW.usageRevision <= OLD.usageRevision
              OR (
                OLD.observedInputTokens IS NOT NULL
                AND (
                    NEW.observedInputTokens IS NULL
                    OR NEW.observedInputTokens < OLD.observedInputTokens
                )
              )
              OR (
                OLD.observedOutputTokens IS NOT NULL
                AND (
                    NEW.observedOutputTokens IS NULL
                    OR NEW.observedOutputTokens < OLD.observedOutputTokens
                )
              )
              OR NEW.elapsedMilliseconds < OLD.elapsedMilliseconds
              OR OLD.status IN ('completed', 'outcomeUnknown', 'rejected')
              OR (
                OLD.status = 'legacyUnknown'
                AND NEW.status NOT IN ('completed', 'outcomeUnknown')
              )
            BEGIN
                SELECT RAISE(ABORT, 'provider budget usage is not monotonic');
            END
            """)

        try db.execute(sql: """
            CREATE TABLE providerBudgetApproval (
                id TEXT PRIMARY KEY NOT NULL,
                taskID TEXT NOT NULL
                    REFERENCES agentTask(id) ON DELETE RESTRICT,
                budgetVersion INTEGER NOT NULL CHECK (budgetVersion > 0),
                policyHash TEXT NOT NULL CHECK (
                    length(policyHash) = 64
                    AND policyHash NOT GLOB '*[^0-9a-f]*'
                ),
                usageRevision INTEGER NOT NULL CHECK (usageRevision > 0),
                usageHash TEXT NOT NULL CHECK (
                    length(usageHash) = 64
                    AND usageHash NOT GLOB '*[^0-9a-f]*'
                ),
                providerRequestID TEXT NOT NULL
                    REFERENCES providerRequest(id) ON DELETE RESTRICT,
                exactRequestHash TEXT NOT NULL CHECK (
                    length(exactRequestHash) = 64
                    AND exactRequestHash NOT GLOB '*[^0-9a-f]*'
                ),
                estimateHash TEXT NOT NULL CHECK (
                    length(estimateHash) = 64
                    AND estimateHash NOT GLOB '*[^0-9a-f]*'
                ),
                estimatePayloadJSON TEXT NOT NULL,
                estimatePayloadHash TEXT NOT NULL CHECK (
                    length(estimatePayloadHash) = 64
                    AND estimatePayloadHash NOT GLOB '*[^0-9a-f]*'
                ),
                reasonsJSON TEXT NOT NULL,
                payloadVersion INTEGER NOT NULL CHECK (payloadVersion = 1),
                payloadJSON TEXT NOT NULL,
                payloadHash TEXT NOT NULL CHECK (
                    length(payloadHash) = 64
                    AND payloadHash NOT GLOB '*[^0-9a-f]*'
                ),
                bindingHash TEXT NOT NULL UNIQUE CHECK (
                    length(bindingHash) = 74
                    AND substr(bindingHash, 1, 10) = 'sha256-v1:'
                    AND substr(bindingHash, 11) NOT GLOB '*[^0-9a-f]*'
                ),
                status TEXT NOT NULL CHECK (
                    status IN (
                        'pending', 'approved', 'consumed', 'rejected',
                        'invalidated', 'expired'
                    )
                ),
                invalidationReason TEXT,
                expiresAtEpochMilliseconds INTEGER NOT NULL
                    CHECK (expiresAtEpochMilliseconds > 0),
                createdAt DOUBLE NOT NULL,
                updatedAt DOUBLE NOT NULL,
                approvedAt DOUBLE,
                consumedAt DOUBLE,
                CHECK (
                    (status = 'pending' AND approvedAt IS NULL
                        AND consumedAt IS NULL)
                    OR (status = 'approved' AND approvedAt IS NOT NULL
                        AND consumedAt IS NULL)
                    OR (status = 'consumed' AND approvedAt IS NOT NULL
                        AND consumedAt IS NOT NULL)
                    OR (status IN ('rejected', 'invalidated', 'expired')
                        AND consumedAt IS NULL)
                )
            )
            """)
        try db.execute(sql: """
            CREATE UNIQUE INDEX providerBudgetApproval_one_active_task
            ON providerBudgetApproval (taskID)
            WHERE status IN ('pending', 'approved')
            """)
        try db.execute(sql: """
            CREATE INDEX providerBudgetApproval_request
            ON providerBudgetApproval (providerRequestID, createdAt DESC)
            """)
        try db.execute(sql: """
            CREATE TRIGGER providerBudgetApproval_binding_immutable
            BEFORE UPDATE OF
                id, taskID, budgetVersion, usageRevision, usageHash,
                policyHash,
                providerRequestID, exactRequestHash, estimateHash,
                estimatePayloadJSON, estimatePayloadHash,
                reasonsJSON, payloadVersion, payloadJSON, payloadHash,
                bindingHash, expiresAtEpochMilliseconds, createdAt
            ON providerBudgetApproval
            BEGIN
                SELECT RAISE(ABORT, 'provider budget approval binding is immutable');
            END
            """)
        try db.execute(sql: """
            CREATE TRIGGER providerBudgetApproval_status_guard
            BEFORE UPDATE OF status ON providerBudgetApproval
            WHEN NOT (
                OLD.status = NEW.status
                OR (
                    OLD.status = 'pending'
                    AND NEW.status IN (
                        'approved', 'rejected',
                        'invalidated', 'expired'
                    )
                )
                OR (
                    OLD.status = 'approved'
                    AND NEW.status IN ('consumed', 'rejected', 'invalidated')
                )
            )
            BEGIN
                SELECT RAISE(ABORT, 'invalid provider budget approval transition');
            END
            """)
        try db.execute(sql: """
            CREATE TRIGGER agentTask_pending_provider_budget_resume_guard
            BEFORE UPDATE OF status ON agentTask
            WHEN OLD.status = 'paused'
              AND NEW.status = 'running'
              AND EXISTS (
                SELECT 1 FROM providerBudgetApproval
                WHERE taskID = OLD.id AND status = 'pending'
              )
            BEGIN
                SELECT RAISE(ABORT, 'pending provider budget approval blocks resume');
            END
            """)

        try backfillProviderBudgetUsage(in: db)

        let integrity = try String.fetchOne(db, sql: "PRAGMA integrity_check")
        let violations = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM pragma_foreign_key_check"
        ) ?? 0
        guard integrity == "ok", violations == 0 else {
            throw AppDatabaseError.invalidProviderBudget
        }
    }

    private static func backfillProviderBudgetUsage(in db: Database) throws {
        let rows = try Row.fetchAll(db, sql: """
            SELECT request.*, run.taskID AS budgetTaskID
            FROM providerRequest AS request
            JOIN agentRun AS run ON run.id = request.runID
            WHERE request.phase IN (
                'sending', 'streaming', 'responseComplete',
                'continuationCommitted', 'terminated', 'failed',
                'outcomeUnknown'
            )
            ORDER BY request.createdAt, request.rowid
            """)
        var revisionByTask: [UUID: Int64] = [:]
        for row in rows {
            guard let taskID = UUID(uuidString: row["budgetTaskID"]) else {
                throw AppDatabaseError.invalidProviderBudget
            }
            let request = try decodeProviderRequest(row)
            let legacyStatus: String
            switch request.phase {
            case .responseComplete, .continuationCommitted, .terminated:
                legacyStatus = "completed"
            case .sending, .streaming, .outcomeUnknown:
                legacyStatus = "legacyUnknown"
            case .failed:
                legacyStatus = "rejected"
            case .prepared, .cancelled:
                throw AppDatabaseError.invalidProviderBudget
            }
            let revision = (revisionByTask[taskID] ?? 0) + 1
            revisionByTask[taskID] = revision
            let pricingKey = [
                request.identity.provider.rawValue,
                request.identity.baseURL.absoluteString,
                request.identity.modelID
            ].joined(separator: "|")
            let startedAt = request.createdAt.timeIntervalSince1970
            let updatedAt = request.updatedAt.timeIntervalSince1970
            let elapsed = try providerBudgetElapsedMilliseconds(
                startedAtEpoch: startedAt,
                finishedAtEpoch: updatedAt
            )
            let finishedAt: Double? = legacyStatus == "legacyUnknown"
                ? nil
                : updatedAt
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
                        ?, ?, 0, ?, ?, ?, ?,
                        NULL, NULL, NULL, 'providerChargeUnavailable', ?,
                        'CNY', 1000000, ?, ?, ?, ?
                    )
                    """,
                arguments: [
                    request.identity.requestID.uuidString,
                    taskID.uuidString,
                    revision,
                    legacyStatus,
                    request.usage.map { Int64($0.inputTokens) },
                    request.usage.map { Int64($0.outputTokens) },
                    pricingKey,
                    elapsed,
                    startedAt,
                    finishedAt,
                    updatedAt
                ]
            )
        }
    }
}
