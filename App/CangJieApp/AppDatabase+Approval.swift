import CangJieCore
import Foundation
import GRDB

struct OpeningPlanApprovalExecutionPolicy: Equatable {
    let toolID: String
    let toolVersion: String
    let parametersHash: String
    let estimatedCostMinorUnits: Int
    let budgetCeilingMinorUnits: Int

    static var current: OpeningPlanApprovalExecutionPolicy {
        OpeningPlanApprovalExecutionPolicy(
            toolID: "artifact.openingPlan.approve",
            toolVersion: "1",
            parametersHash: ApprovalFingerprint.parametersHash("{}"),
            estimatedCostMinorUnits: 0,
            budgetCeilingMinorUnits: 2_000
        )
    }
}

extension AppDatabase {
    private static let openingPlanApprovalToolID = "artifact.openingPlan.approve"
    private static let openingPlanApprovalToolVersion = "1"
    private static let openingPlanSaveToolID = "artifact.openingPlan.save"
    private static let openingPlanSaveToolVersion = "1"

    func executeOpeningPlanSaveTool(
        conversationID: UUID,
        projectID: UUID,
        title: String,
        body: String,
        idempotencyKey: String,
        now: Date = Date(),
        expiresAt: Date? = nil,
        estimatedCostMinorUnits: Int = 0,
        budgetCeilingMinorUnits: Int = 2_000
    ) throws -> OpeningPlanSaveToolResult {
        let expirationMilliseconds = try Self.requiredEpochMilliseconds(
            expiresAt ?? now.addingTimeInterval(7 * 24 * 60 * 60)
        )
        let effectiveExpiration = Date(
            timeIntervalSince1970: Double(expirationMilliseconds) / 1_000
        )
        let nowMilliseconds = try Self.requiredEpochMilliseconds(now)
        guard estimatedCostMinorUnits >= 0,
              budgetCeilingMinorUnits >= 0,
              estimatedCostMinorUnits <= budgetCeilingMinorUnits else {
            throw AppDatabaseError.approvalBudgetExceeded
        }
        guard expirationMilliseconds > nowMilliseconds else {
            throw AppDatabaseError.approvalExpired
        }

        let approvalPolicy = OpeningPlanApprovalExecutionPolicy(
            toolID: Self.openingPlanApprovalToolID,
            toolVersion: Self.openingPlanApprovalToolVersion,
            parametersHash: ApprovalFingerprint.parametersHash("{}"),
            estimatedCostMinorUnits: estimatedCostMinorUnits,
            budgetCeilingMinorUnits: budgetCeilingMinorUnits
        )
        let artifactHash = ApprovalFingerprint.artifactHash(
            conversationID: conversationID,
            projectID: projectID,
            kind: "openingPlan",
            title: title,
            body: body
        )
        let saveInputHash = ApprovalFingerprint.parametersHash([
            conversationID.uuidString,
            projectID.uuidString,
            title,
            body,
            String(estimatedCostMinorUnits),
            String(budgetCeilingMinorUnits),
            String(expirationMilliseconds)
        ].joined(separator: "|"))

        return try queue.write { db in
            if let receipt = try Self.receipt(idempotencyKey: idempotencyKey, in: db) {
                guard receipt.toolID == Self.openingPlanSaveToolID,
                      receipt.toolVersion == Self.openingPlanSaveToolVersion,
                      receipt.inputHash == saveInputHash,
                      receipt.outcome == "completed",
                      receipt.conversationID == conversationID,
                      receipt.projectID == projectID,
                      let artifactReference = receipt.outputReference,
                      let artifact = try Self.artifact(id: artifactReference, in: db),
                      let approvalID = receipt.approvalRequestID,
                      let approval = try Self.approvalRequest(id: approvalID, in: db),
                      receipt.approvalBindingHash == approval.bindingHash,
                      approval.toolID == approvalPolicy.toolID,
                      approval.toolVersion == approvalPolicy.toolVersion,
                      approval.parametersHash == approvalPolicy.parametersHash,
                      approval.estimatedCostMinorUnits == approvalPolicy.estimatedCostMinorUnits,
                      approval.budgetCeilingMinorUnits == approvalPolicy.budgetCeilingMinorUnits,
                      approval.expiresAtEpochMilliseconds == expirationMilliseconds,
                      try Self.hasValidStoredApprovalRelationship(
                        approval,
                        artifact: artifact,
                        conversationID: conversationID
                      ) else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return OpeningPlanSaveToolResult(artifact: artifact, approval: approval, receipt: receipt)
            }

            guard let project = try Self.project(id: projectID.uuidString, in: db) else {
                throw AppDatabaseError.invalidApprovalRequest
            }
            let previous = try Self.latestArtifact(
                kind: "openingPlan",
                conversationID: conversationID,
                projectID: projectID,
                in: db
            )
            let artifact: AgentArtifact
            if let previous, previous.contentHash == artifactHash {
                artifact = previous
            } else {
                let artifactID = UUID()
                artifact = AgentArtifact(
                    id: artifactID,
                    logicalID: previous?.logicalID ?? artifactID,
                    revision: (previous?.revision ?? 0) + 1,
                    contentHash: artifactHash,
                    parentArtifactID: previous?.id,
                    kind: "openingPlan",
                    title: title,
                    body: body,
                    status: "waitingApproval",
                    conversationID: conversationID,
                    projectID: projectID,
                    updatedAt: now
                )
                try Self.insertArtifact(artifact, in: db)
            }

            try Self.invalidateActiveApprovals(
                logicalID: artifact.logicalID,
                reason: "artifactOrBindingChanged",
                now: now,
                in: db
            )
            let approval = try Self.makeApprovalRequest(
                conversationID: conversationID,
                project: project,
                artifact: artifact,
                policy: approvalPolicy,
                expiresAt: effectiveExpiration,
                now: now,
                in: db
            )
            let receipt = ToolReceipt(
                id: UUID(),
                toolID: Self.openingPlanSaveToolID,
                toolVersion: Self.openingPlanSaveToolVersion,
                inputSummary: "openingPlan:waitingApproval",
                inputHash: saveInputHash,
                outcome: "completed",
                conversationID: conversationID,
                projectID: projectID,
                approvalRequestID: approval.id,
                approvalBindingHash: approval.bindingHash,
                idempotencyKey: idempotencyKey,
                outputReference: artifact.id.uuidString,
                createdAt: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            return OpeningPlanSaveToolResult(artifact: artifact, approval: approval, receipt: receipt)
        }
    }

    func executeOpeningPlanApprovalTool(
        conversationID: UUID,
        approvalRequestID: UUID,
        displayedBindingHash: String,
        idempotencyKey: String,
        now: Date = Date(),
        currentPolicy: OpeningPlanApprovalExecutionPolicy = .current
    ) throws -> OpeningPlanApprovalToolResult {
        let nowMilliseconds = try Self.requiredEpochMilliseconds(now)
        var deferredError: AppDatabaseError?
        let result: OpeningPlanApprovalToolResult? = try queue.write { db in
            if let receipt = try Self.receipt(idempotencyKey: idempotencyKey, in: db) {
                guard let artifactReference = receipt.outputReference,
                      let artifact = try Self.artifact(id: artifactReference, in: db),
                      let approval = try Self.approvalRequest(id: approvalRequestID, in: db),
                      let project = try Self.project(id: approval.projectID.uuidString, in: db),
                      let latest = try Self.latestArtifact(
                        kind: artifact.kind,
                        conversationID: conversationID,
                        projectID: approval.projectID,
                        in: db
                      ),
                      receipt.toolID == currentPolicy.toolID,
                      receipt.toolVersion == currentPolicy.toolVersion,
                      receipt.inputHash == displayedBindingHash,
                      receipt.outcome == "completed",
                      receipt.conversationID == conversationID,
                      receipt.projectID == approval.projectID,
                      receipt.approvalRequestID == approvalRequestID,
                      receipt.approvalBindingHash == displayedBindingHash,
                      approval.status == .approved,
                      approval.bindingHash == displayedBindingHash,
                      latest.id == artifact.id,
                      try Self.currentApprovalValidation(
                        approval,
                        artifact: artifact,
                        project: project,
                        conversationID: conversationID,
                        policy: currentPolicy,
                        nowEpochMilliseconds: nowMilliseconds,
                        enforceExpiration: false
                      ) == .approved else {
                    throw AppDatabaseError.idempotencyConflict
                }
                return OpeningPlanApprovalToolResult(
                    artifact: artifact,
                    approval: approval,
                    receipt: receipt,
                    isReplay: true
                )
            }

            guard var approval = try Self.approvalRequest(id: approvalRequestID, in: db),
                  approval.conversationID == conversationID else {
                throw AppDatabaseError.invalidApprovalRequest
            }
            guard approval.bindingHash == displayedBindingHash else {
                throw AppDatabaseError.approvalRequiresReapproval
            }
            if approval.status == .invalidated {
                throw AppDatabaseError.approvalRequiresReapproval
            }
            if approval.status == .expired
                || (approval.status == .pending
                    && nowMilliseconds >= approval.expiresAtEpochMilliseconds) {
                try Self.invalidateApproval(
                    approval.id,
                    status: .expired,
                    reason: "expired",
                    now: now,
                    in: db
                )
                deferredError = .approvalExpired
                return nil
            }
            guard approval.status == .pending,
                  let artifact = try Self.artifact(id: approval.artifactID.uuidString, in: db),
                  let latest = try Self.latestArtifact(
                    kind: artifact.kind,
                    conversationID: conversationID,
                    projectID: approval.projectID,
                    in: db
                  ),
                  let project = try Self.project(id: approval.projectID.uuidString, in: db) else {
                throw AppDatabaseError.approvalRequiresReapproval
            }

            let validation = try Self.currentApprovalValidation(
                approval,
                artifact: artifact,
                project: project,
                conversationID: conversationID,
                policy: currentPolicy,
                nowEpochMilliseconds: nowMilliseconds,
                enforceExpiration: true
            )
            guard latest.id == artifact.id,
                  validation == .approved else {
                let reasons = Self.invalidationReasons(from: validation)
                let status: ApprovalRequestStatus = reasons.contains(.expired) ? .expired : .invalidated
                try Self.invalidateApproval(
                    approval.id,
                    status: status,
                    reason: status == .expired ? "expired" : "currentBindingChanged",
                    now: now,
                    in: db
                )
                deferredError = Self.approvalValidationError(for: reasons)
                return nil
            }

            try db.execute(
                sql: "UPDATE approvalRequest SET status = ?, approvedAt = ?, updatedAt = ? WHERE id = ? AND status = ? AND bindingHash = ? AND expiresAt > ?",
                arguments: [
                    ApprovalRequestStatus.approved.rawValue,
                    now.timeIntervalSince1970,
                    now.timeIntervalSince1970,
                    approval.id.uuidString,
                    ApprovalRequestStatus.pending.rawValue,
                    displayedBindingHash,
                    nowMilliseconds
                ]
            )
            guard db.changesCount == 1 else {
                throw AppDatabaseError.approvalRequiresReapproval
            }
            approval = try Self.requiredApprovalRequest(id: approval.id, in: db)
            let receipt = ToolReceipt(
                id: UUID(),
                toolID: currentPolicy.toolID,
                toolVersion: currentPolicy.toolVersion,
                inputSummary: "openingPlan:approved",
                inputHash: displayedBindingHash,
                outcome: "completed",
                conversationID: conversationID,
                projectID: approval.projectID,
                approvalRequestID: approval.id,
                approvalBindingHash: displayedBindingHash,
                idempotencyKey: idempotencyKey,
                outputReference: artifact.id.uuidString,
                createdAt: now
            )
            try Self.insertToolReceipt(receipt, in: db)
            return OpeningPlanApprovalToolResult(
                artifact: artifact,
                approval: approval,
                receipt: receipt,
                isReplay: false
            )
        }
        if let deferredError { throw deferredError }
        guard let result else { throw AppDatabaseError.invalidApprovalRequest }
        return result
    }

    func ensureOpeningPlanApprovalState(
        conversationID: UUID,
        focusedProjectID: UUID?,
        now: Date = Date(),
        currentPolicy: OpeningPlanApprovalExecutionPolicy = .current
    ) throws -> OpeningPlanApprovalState? {
        let nowMilliseconds = try Self.requiredEpochMilliseconds(now)
        return try queue.write { db in
            guard let focusedProjectID,
                  let artifact = try Self.latestArtifact(
                    kind: "openingPlan",
                    conversationID: conversationID,
                    projectID: focusedProjectID,
                    in: db
                  ),
                  let project = try Self.project(id: focusedProjectID.uuidString, in: db) else {
                return nil
            }

            if let current = try Self.latestApprovalRequest(
                conversationID: conversationID,
                artifactLogicalID: artifact.logicalID,
                in: db
            ), current.artifactID == artifact.id,
               Self.approval(current, matches: artifact, conversationID: conversationID),
               current.status == .pending || current.status == .approved {
                let enforceExpiration = current.status == .pending
                let validation = try Self.currentApprovalValidation(
                    current,
                    artifact: artifact,
                    project: project,
                    conversationID: conversationID,
                    policy: currentPolicy,
                    nowEpochMilliseconds: nowMilliseconds,
                    enforceExpiration: enforceExpiration
                )
                let hasRequiredReceipt: Bool
                if current.status != .approved {
                    hasRequiredReceipt = true
                } else {
                    hasRequiredReceipt = try Self.hasCompletedApprovalReceipt(
                        approval: current,
                        artifact: artifact,
                        conversationID: conversationID,
                        policy: currentPolicy,
                        in: db
                    )
                }
                if validation == .approved, hasRequiredReceipt {
                    return OpeningPlanApprovalState(artifact: artifact, approval: current)
                }

                let reasons = Self.invalidationReasons(from: validation)
                let status: ApprovalRequestStatus = current.status == .pending && reasons.contains(.expired)
                    ? .expired
                    : .invalidated
                try Self.invalidateApproval(
                    current.id,
                    status: status,
                    reason: status == .expired ? "expiredBeforeDisplay" : "currentBindingChanged",
                    now: now,
                    in: db
                )
            }

            try Self.invalidateActiveApprovals(
                logicalID: artifact.logicalID,
                reason: "legacyApprovalRequiresExactBinding",
                now: now,
                in: db
            )
            let approval = try Self.makeApprovalRequest(
                conversationID: conversationID,
                project: project,
                artifact: artifact,
                policy: currentPolicy,
                expiresAt: now.addingTimeInterval(7 * 24 * 60 * 60),
                now: now,
                in: db
            )
            return OpeningPlanApprovalState(artifact: artifact, approval: approval)
        }
    }

    func ensureOpeningPlanApprovalRequest(
        conversationID: UUID,
        focusedProjectID: UUID?,
        now: Date = Date()
    ) throws -> ApprovalRequest? {
        try ensureOpeningPlanApprovalState(
            conversationID: conversationID,
            focusedProjectID: focusedProjectID,
            now: now
        )?.approval
    }

    func approvalRequest(id: UUID) throws -> ApprovalRequest? {
        try queue.read { db in try Self.approvalRequest(id: id, in: db) }
    }

    func latestApprovalRequest(conversationID: UUID) throws -> ApprovalRequest? {
        try queue.read { db in
            try Self.latestApprovalRequest(conversationID: conversationID, artifactLogicalID: nil, in: db)
        }
    }

    func countArtifacts(kind: String) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM agentArtifact WHERE kind = ?", arguments: [kind]) ?? 0
        }
    }

    func countToolReceipts(toolID: String) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM toolReceipt WHERE toolID = ?", arguments: [toolID]) ?? 0
        }
    }


    private static func coreApprovalBinding(
        approvalRequestID: UUID,
        conversationID: UUID,
        projectID: UUID,
        artifactLogicalID: UUID,
        artifactID: UUID,
        artifactRevision: Int,
        artifactHash: String,
        toolID: String,
        toolVersion: String,
        parametersHash: String,
        targetVersions: [ApprovalTargetVersion],
        estimatedCostMinorUnits: Int,
        budgetCeilingMinorUnits: Int,
        expiresAtEpochMilliseconds: Int64,
        expectedDiffHash: String
    ) throws -> ApprovalBinding {
        var targets: [String: Int] = [:]
        for target in targetVersions {
            let key = "\(target.type):\(target.id.uuidString)"
            guard !target.type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  target.version >= 0,
                  targets[key] == nil else {
                throw AppDatabaseError.invalidApprovalRequest
            }
            targets[key] = target.version
        }
        return ApprovalBinding(
            approvalRequestID: approvalRequestID,
            conversationID: conversationID,
            projectID: projectID,
            artifactLogicalID: artifactLogicalID,
            artifactID: artifactID,
            artifactRevision: artifactRevision,
            artifactHash: artifactHash,
            toolID: toolID,
            toolVersion: toolVersion,
            parametersHash: parametersHash,
            targetVersions: targets,
            estimatedCostMinorUnits: estimatedCostMinorUnits,
            budgetCeilingMinorUnits: budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds,
            expectedDiffHash: expectedDiffHash
        )
    }

    private static func storedBinding(for approval: ApprovalRequest) throws -> ApprovalBinding {
        try coreApprovalBinding(
            approvalRequestID: approval.id,
            conversationID: approval.conversationID,
            projectID: approval.projectID,
            artifactLogicalID: approval.artifactLogicalID,
            artifactID: approval.artifactID,
            artifactRevision: approval.artifactRevision,
            artifactHash: approval.artifactHash,
            toolID: approval.toolID,
            toolVersion: approval.toolVersion,
            parametersHash: approval.parametersHash,
            targetVersions: approval.targetVersions,
            estimatedCostMinorUnits: approval.estimatedCostMinorUnits,
            budgetCeilingMinorUnits: approval.budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: approval.expiresAtEpochMilliseconds,
            expectedDiffHash: approval.expectedDiffHash
        )
    }

    private static func approval(
        _ approval: ApprovalRequest,
        matches artifact: AgentArtifact,
        conversationID: UUID
    ) -> Bool {
        approval.conversationID == conversationID
            && approval.artifactID == artifact.id
            && approval.artifactLogicalID == artifact.logicalID
            && approval.artifactRevision == artifact.revision
            && approval.artifactHash == artifact.contentHash
            && approval.projectID == artifact.projectID
            && artifact.conversationID == conversationID
    }

    private static func hasValidStoredApprovalRelationship(
        _ approval: ApprovalRequest,
        artifact: AgentArtifact,
        conversationID: UUID
    ) throws -> Bool {
        guard artifact.kind == "openingPlan",
              Self.approval(approval, matches: artifact, conversationID: conversationID),
              artifact.contentHash == ApprovalFingerprint.artifactHash(
                conversationID: artifact.conversationID,
                projectID: artifact.projectID,
                kind: artifact.kind,
                title: artifact.title,
                body: artifact.body
              ),
              approval.targetVersionsHash == ApprovalFingerprint.targetVersionsHash(
                approval.targetVersions
              ),
              approval.expectedDiffHash == ApprovalFingerprint.expectedDiffHash(
                artifactHash: artifact.contentHash
              ) else {
            return false
        }
        let binding = try storedBinding(for: approval)
        guard binding.bindingHash == approval.bindingHash,
              approval.expiresAtEpochMilliseconds > 0 else {
            return false
        }
        return binding.validate(
            candidate: binding,
            nowEpochMilliseconds: approval.expiresAtEpochMilliseconds - 1
        ) == .approved
    }

    private static func currentApprovalValidation(
        _ approval: ApprovalRequest,
        artifact: AgentArtifact,
        project: NovelProject,
        conversationID: UUID,
        policy: OpeningPlanApprovalExecutionPolicy,
        nowEpochMilliseconds: Int64,
        enforceExpiration: Bool
    ) throws -> ApprovalValidationResult {
        guard try hasValidStoredApprovalRelationship(
            approval,
            artifact: artifact,
            conversationID: conversationID
        ) else {
            return .requiresReapproval(reasons: [.bindingHashChanged])
        }

        let candidate = try coreApprovalBinding(
            approvalRequestID: approval.id,
            conversationID: conversationID,
            projectID: project.id,
            artifactLogicalID: artifact.logicalID,
            artifactID: artifact.id,
            artifactRevision: artifact.revision,
            artifactHash: ApprovalFingerprint.artifactHash(
                conversationID: artifact.conversationID,
                projectID: artifact.projectID,
                kind: artifact.kind,
                title: artifact.title,
                body: artifact.body
            ),
            toolID: policy.toolID,
            toolVersion: policy.toolVersion,
            parametersHash: policy.parametersHash,
            targetVersions: [
                ApprovalTargetVersion(type: "novelProject", id: project.id, version: project.version)
            ],
            estimatedCostMinorUnits: policy.estimatedCostMinorUnits,
            budgetCeilingMinorUnits: policy.budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: approval.expiresAtEpochMilliseconds,
            expectedDiffHash: ApprovalFingerprint.expectedDiffHash(
                artifactHash: artifact.contentHash
            )
        )
        let validationTime = enforceExpiration
            ? nowEpochMilliseconds
            : approval.expiresAtEpochMilliseconds - 1
        return try storedBinding(for: approval).validate(
            candidate: candidate,
            nowEpochMilliseconds: validationTime
        )
    }

    private static func hasCompletedApprovalReceipt(
        approval: ApprovalRequest,
        artifact: AgentArtifact,
        conversationID: UUID,
        policy: OpeningPlanApprovalExecutionPolicy,
        in db: Database
    ) throws -> Bool {
        guard let row = try Row.fetchOne(
            db,
            sql: """
            SELECT * FROM toolReceipt
            WHERE approvalRequestID = ?
              AND approvalBindingHash = ?
              AND toolID = ?
              AND outcome = ?
            ORDER BY createdAt DESC, rowid DESC
            LIMIT 1
            """,
            arguments: [
                approval.id.uuidString,
                approval.bindingHash,
                policy.toolID,
                "completed"
            ]
        ), let receipt = decodeToolReceipt(row) else {
            return false
        }
        return receipt.toolID == policy.toolID
            && receipt.toolVersion == policy.toolVersion
            && receipt.inputHash == approval.bindingHash
            && receipt.outcome == "completed"
            && receipt.conversationID == conversationID
            && receipt.projectID == approval.projectID
            && receipt.approvalRequestID == approval.id
            && receipt.approvalBindingHash == approval.bindingHash
            && receipt.outputReference == artifact.id.uuidString
    }

    private static func requiredEpochMilliseconds(_ date: Date) throws -> Int64 {
        guard let value = ApprovalBinding.canonicalEpochMilliseconds(from: date) else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        return value
    }

    private static func invalidateApproval(
        _ id: UUID,
        status: ApprovalRequestStatus,
        reason: String,
        now: Date,
        in db: Database
    ) throws {
        try db.execute(
            sql: "UPDATE approvalRequest SET status = ?, invalidationReason = ?, updatedAt = ? WHERE id = ?",
            arguments: [status.rawValue, reason, now.timeIntervalSince1970, id.uuidString]
        )
    }

    private static func invalidationReasons(
        from validation: ApprovalValidationResult
    ) -> Set<ApprovalInvalidationReason> {
        switch validation {
        case .approved:
            return []
        case let .requiresReapproval(reasons):
            return reasons
        }
    }

    private static func approvalValidationError(
        for reasons: Set<ApprovalInvalidationReason>
    ) -> AppDatabaseError {
        if reasons.contains(.expired) {
            return .approvalExpired
        }
        if reasons.contains(.invalidEstimatedCost)
            || reasons.contains(.invalidBudgetCeiling)
            || reasons.contains(.estimatedCostExceedsBudget) {
            return .approvalBudgetExceeded
        }
        return .approvalRequiresReapproval
    }

    private static func makeApprovalRequest(
        conversationID: UUID,
        project: NovelProject,
        artifact: AgentArtifact,
        policy: OpeningPlanApprovalExecutionPolicy,
        expiresAt: Date,
        now: Date,
        in db: Database
    ) throws -> ApprovalRequest {
        guard artifact.kind == "openingPlan",
              artifact.conversationID == conversationID,
              artifact.projectID == project.id,
              artifact.contentHash == ApprovalFingerprint.artifactHash(
                conversationID: artifact.conversationID,
                projectID: artifact.projectID,
                kind: artifact.kind,
                title: artifact.title,
                body: artifact.body
              ) else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        let targets = [
            ApprovalTargetVersion(type: "novelProject", id: project.id, version: project.version)
        ]
        let targetData = try JSONEncoder().encode(targets)
        guard let targetJSON = String(data: targetData, encoding: .utf8) else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        let requestID = UUID()
        let expiresAtEpochMilliseconds = try requiredEpochMilliseconds(expiresAt)
        let targetVersionsHash = ApprovalFingerprint.targetVersionsHash(targets)
        let expectedDiffHash = ApprovalFingerprint.expectedDiffHash(artifactHash: artifact.contentHash)
        let binding = try coreApprovalBinding(
            approvalRequestID: requestID,
            conversationID: conversationID,
            projectID: project.id,
            artifactLogicalID: artifact.logicalID,
            artifactID: artifact.id,
            artifactRevision: artifact.revision,
            artifactHash: artifact.contentHash,
            toolID: policy.toolID,
            toolVersion: policy.toolVersion,
            parametersHash: policy.parametersHash,
            targetVersions: targets,
            estimatedCostMinorUnits: policy.estimatedCostMinorUnits,
            budgetCeilingMinorUnits: policy.budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds,
            expectedDiffHash: expectedDiffHash
        )
        let validation = binding.validate(
            candidate: binding,
            nowEpochMilliseconds: try requiredEpochMilliseconds(now)
        )
        guard validation == .approved else {
            throw approvalValidationError(for: invalidationReasons(from: validation))
        }
        let request = ApprovalRequest(
            id: requestID,
            conversationID: conversationID,
            projectID: project.id,
            artifactID: artifact.id,
            artifactLogicalID: artifact.logicalID,
            artifactRevision: artifact.revision,
            artifactHash: artifact.contentHash,
            toolID: policy.toolID,
            toolVersion: policy.toolVersion,
            parametersHash: policy.parametersHash,
            targetVersions: targets,
            targetVersionsHash: targetVersionsHash,
            estimatedCostMinorUnits: policy.estimatedCostMinorUnits,
            budgetCeilingMinorUnits: policy.budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds,
            expectedDiffHash: expectedDiffHash,
            bindingHash: binding.bindingHash,
            status: .pending,
            invalidationReason: nil,
            createdAt: now,
            updatedAt: now,
            approvedAt: nil
        )
        try db.execute(
            sql: """
            INSERT INTO approvalRequest (
                id, conversationID, projectID, artifactID, artifactLogicalID, artifactRevision,
                artifactHash, toolID, toolVersion, parametersHash, targetVersionsJSON,
                targetVersionsHash, estimatedCostMinorUnits, budgetCeilingMinorUnits, expiresAt,
                expectedDiffHash, bindingHash, status, invalidationReason, createdAt, updatedAt, approvedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, NULL)
            """,
            arguments: [
                request.id.uuidString,
                request.conversationID.uuidString,
                request.projectID.uuidString,
                request.artifactID.uuidString,
                request.artifactLogicalID.uuidString,
                request.artifactRevision,
                request.artifactHash,
                request.toolID,
                request.toolVersion,
                request.parametersHash,
                targetJSON,
                request.targetVersionsHash,
                request.estimatedCostMinorUnits,
                request.budgetCeilingMinorUnits,
                request.expiresAtEpochMilliseconds,
                request.expectedDiffHash,
                request.bindingHash,
                request.status.rawValue,
                request.createdAt.timeIntervalSince1970,
                request.updatedAt.timeIntervalSince1970
            ]
        )
        return request
    }

    private static func invalidateActiveApprovals(
        logicalID: UUID,
        reason: String,
        now: Date,
        in db: Database
    ) throws {
        try db.execute(
            sql: "UPDATE approvalRequest SET status = ?, invalidationReason = ?, updatedAt = ? WHERE artifactLogicalID = ? AND status IN (?, ?)",
            arguments: [
                ApprovalRequestStatus.invalidated.rawValue,
                reason,
                now.timeIntervalSince1970,
                logicalID.uuidString,
                ApprovalRequestStatus.pending.rawValue,
                ApprovalRequestStatus.approved.rawValue
            ]
        )
    }

    private static func latestApprovalRequest(
        conversationID: UUID,
        artifactLogicalID: UUID?,
        in db: Database
    ) throws -> ApprovalRequest? {
        let row: Row?
        if let artifactLogicalID {
            row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM approvalRequest WHERE conversationID = ? AND artifactLogicalID = ? ORDER BY artifactRevision DESC, createdAt DESC, rowid DESC LIMIT 1",
                arguments: [conversationID.uuidString, artifactLogicalID.uuidString]
            )
        } else {
            row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM approvalRequest WHERE conversationID = ? ORDER BY createdAt DESC, rowid DESC LIMIT 1",
                arguments: [conversationID.uuidString]
            )
        }
        guard let row else { return nil }
        return try decodeApprovalRequest(row)
    }

    private static func approvalRequest(id: UUID, in db: Database) throws -> ApprovalRequest? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM approvalRequest WHERE id = ? LIMIT 1",
            arguments: [id.uuidString]
        ) else { return nil }
        return try decodeApprovalRequest(row)
    }

    private static func requiredApprovalRequest(id: UUID, in db: Database) throws -> ApprovalRequest {
        guard let request = try approvalRequest(id: id, in: db) else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        return request
    }

    private static func decodeApprovalRequest(_ row: Row) throws -> ApprovalRequest {
        guard let id = UUID(uuidString: row["id"]),
              let conversationID = UUID(uuidString: row["conversationID"]),
              let projectID = UUID(uuidString: row["projectID"]),
              let artifactID = UUID(uuidString: row["artifactID"]),
              let artifactLogicalID = UUID(uuidString: row["artifactLogicalID"]),
              let status = ApprovalRequestStatus(rawValue: row["status"]) else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        let targetJSON: String = row["targetVersionsJSON"]
        guard let targetData = targetJSON.data(using: .utf8),
              let targets = try? JSONDecoder().decode([ApprovalTargetVersion].self, from: targetData) else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        let artifactRevision: Int = row["artifactRevision"]
        let artifactHash: String = row["artifactHash"]
        let toolID: String = row["toolID"]
        let toolVersion: String = row["toolVersion"]
        let parametersHash: String = row["parametersHash"]
        let targetVersionsHash: String = row["targetVersionsHash"]
        let estimatedCostMinorUnits: Int = row["estimatedCostMinorUnits"]
        let budgetCeilingMinorUnits: Int = row["budgetCeilingMinorUnits"]
        let expiresAtEpochMilliseconds: Int64 = row["expiresAt"]
        let expectedDiffHash: String = row["expectedDiffHash"]
        let bindingHash: String = row["bindingHash"]
        let invalidationReason: String? = row["invalidationReason"]
        let approvedAtValue: Double? = row["approvedAt"]
        let request = ApprovalRequest(
            id: id,
            conversationID: conversationID,
            projectID: projectID,
            artifactID: artifactID,
            artifactLogicalID: artifactLogicalID,
            artifactRevision: artifactRevision,
            artifactHash: artifactHash,
            toolID: toolID,
            toolVersion: toolVersion,
            parametersHash: parametersHash,
            targetVersions: targets,
            targetVersionsHash: targetVersionsHash,
            estimatedCostMinorUnits: estimatedCostMinorUnits,
            budgetCeilingMinorUnits: budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds,
            expectedDiffHash: expectedDiffHash,
            bindingHash: bindingHash,
            status: status,
            invalidationReason: invalidationReason,
            createdAt: Date(timeIntervalSince1970: row["createdAt"]),
            updatedAt: Date(timeIntervalSince1970: row["updatedAt"]),
            approvedAt: approvedAtValue.map(Date.init(timeIntervalSince1970:))
        )
        let binding = try storedBinding(for: request)
        let statusTimestampsAreValid = status == .approved
            ? request.approvedAt != nil
            : status != .pending || request.approvedAt == nil
        guard expiresAtEpochMilliseconds > 0,
              targetVersionsHash == ApprovalFingerprint.targetVersionsHash(targets),
              binding.bindingHash == bindingHash,
              binding.validate(
                candidate: binding,
                nowEpochMilliseconds: expiresAtEpochMilliseconds - 1
              ) == .approved,
              statusTimestampsAreValid else {
            throw AppDatabaseError.invalidApprovalRequest
        }
        return request
    }

    private static func latestArtifact(
        kind: String,
        conversationID: UUID,
        projectID: UUID?,
        in db: Database
    ) throws -> AgentArtifact? {
        let row: Row?
        if let projectID {
            row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentArtifact WHERE kind = ? AND conversationID = ? AND projectID = ? ORDER BY updatedAt DESC, rowid DESC LIMIT 1",
                arguments: [kind, conversationID.uuidString, projectID.uuidString]
            )
        } else {
            row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM agentArtifact WHERE kind = ? AND conversationID = ? ORDER BY updatedAt DESC, rowid DESC LIMIT 1",
                arguments: [kind, conversationID.uuidString]
            )
        }
        guard let row else { return nil }
        return decodeAgentArtifact(row)
    }

    private static func insertArtifact(_ artifact: AgentArtifact, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO agentArtifact (
                id, logicalID, revision, contentHash, parentArtifactID, kind, title, body,
                status, conversationID, projectID, updatedAt
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                artifact.id.uuidString,
                artifact.logicalID.uuidString,
                artifact.revision,
                artifact.contentHash,
                artifact.parentArtifactID?.uuidString,
                artifact.kind,
                artifact.title,
                artifact.body,
                artifact.status,
                artifact.conversationID?.uuidString,
                artifact.projectID?.uuidString,
                artifact.updatedAt.timeIntervalSince1970
            ]
        )
    }
}
