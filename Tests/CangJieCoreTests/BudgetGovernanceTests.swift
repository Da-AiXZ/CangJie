import Foundation
import XCTest
@testable import CangJieCore

final class BudgetGovernanceTests: XCTestCase {
    private let taskID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private let approvalID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    private let requestID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!

    func testExactCeilingProceedsWithBoundValidatedReservation() throws {
        let policy = try makePolicy(
            maximumInputTokens: 110,
            maximumOutputTokens: 220,
            maximumCostMicroUnits: 330,
            maximumElapsedMilliseconds: 440
        )
        let usage = try makeUsage(
            inputTokens: 100,
            outputTokens: 200,
            cost: knownCost(300),
            elapsedMilliseconds: 400
        )
        let estimate = try makeEstimate(
            inputTokens: 10,
            outputTokens: 20,
            cost: knownCost(30),
            elapsedMilliseconds: 40
        )

        let decision = BudgetGovernance().preflight(
            policy: policy,
            usage: usage,
            nextRequest: estimate
        )

        guard case let .proceed(reservation) = decision.outcome else {
            return XCTFail("Expected exact ceiling to proceed, got \(decision)")
        }
        XCTAssertEqual(reservation.taskID, taskID)
        XCTAssertEqual(reservation.budgetVersion, policy.version)
        XCTAssertEqual(reservation.policyHash, policy.canonicalHash)
        XCTAssertEqual(reservation.usageRevision, usage.revision)
        XCTAssertEqual(reservation.usageHash, usage.canonicalHash)
        XCTAssertEqual(reservation.providerRequestID, estimate.requestIdentity.requestID)
        XCTAssertEqual(reservation.exactRequestHash, estimate.requestIdentity.exactRequestHash)
        XCTAssertEqual(reservation.estimateHash, estimate.canonicalHash)
        XCTAssertEqual(
            try JSONDecoder().decode(
                BudgetReservationCandidate.self,
                from: JSONEncoder().encode(reservation)
            ),
            reservation
        )
        XCTAssertEqual(
            reservation.validate(policy: policy, usage: usage, nextRequest: estimate),
            .valid
        )
        XCTAssertEqual(
            reservation.validate(
                policy: try makePolicy(
                    maximumInputTokens: 111,
                    maximumOutputTokens: 220,
                    maximumCostMicroUnits: 330,
                    maximumElapsedMilliseconds: 440
                ),
                usage: usage,
                nextRequest: estimate
            ),
            .requiresNewPreflight(reasons: [.policyChanged])
        )
        XCTAssertEqual(
            reservation.validate(
                policy: policy,
                usage: try makeUsage(
                    revision: 2,
                    inputTokens: 100,
                    outputTokens: 200,
                    cost: knownCost(300),
                    elapsedMilliseconds: 400
                ),
                nextRequest: estimate
            ),
            .requiresNewPreflight(reasons: [.usageChanged])
        )
    }

    func testAllProjectedDimensionsOverLimitProduceBoundApprovalRequirement() throws {
        let policy = try makePolicy(
            maximumInputTokens: 109,
            maximumOutputTokens: 219,
            maximumCostMicroUnits: 329,
            maximumElapsedMilliseconds: 439
        )
        let usage = try makeUsage(
            inputTokens: 100,
            outputTokens: 200,
            cost: knownCost(300, basis: .actual, pricingVersion: "provider-receipt-v1"),
            elapsedMilliseconds: 400
        )
        let estimate = try makeEstimate(
            inputTokens: 10,
            outputTokens: 20,
            cost: knownCost(30),
            elapsedMilliseconds: 40
        )

        let decision = BudgetGovernance().preflight(
            policy: policy,
            usage: usage,
            nextRequest: estimate
        )
        guard case let .requiresApproval(requirement) = decision.outcome else {
            return XCTFail("Expected approval requirement, got \(decision)")
        }
        XCTAssertEqual(requirement.reasons, [
            .inputTokens,
            .outputTokens,
            .cost,
            .elapsedTime
        ])
        XCTAssertEqual(requirement.taskID, policy.taskID)
        XCTAssertEqual(requirement.policyHash, policy.canonicalHash)
        XCTAssertEqual(requirement.usageHash, usage.canonicalHash)
        XCTAssertEqual(requirement.exactRequestHash, estimate.requestIdentity.exactRequestHash)
        XCTAssertEqual(requirement.estimateHash, estimate.canonicalHash)
    }

    func testUnknownCostsAreNeverTreatedAsZero() throws {
        let unknownEstimate = try makeEstimate(
            cost: unknownCost(
                reason: .pricingUnavailable,
                pricingKey: "custom|https://example.com|custom-model"
            )
        )
        guard case let .requiresApproval(unknownPricing) = BudgetGovernance().preflight(
            policy: try makePolicy(),
            usage: try makeUsage(),
            nextRequest: unknownEstimate
        ).outcome else {
            return XCTFail("Expected unknown pricing approval")
        }
        XCTAssertEqual(unknownPricing.reasons, [.pricingUnavailable])

        let unknownUsage = try makeUsage(
            cost: unknownCost(
                reason: .providerChargeUnavailable,
                pricingKey: "deepseek|deepseek-chat"
            )
        )
        guard case let .requiresApproval(unknownCumulative) = BudgetGovernance().preflight(
            policy: try makePolicy(),
            usage: unknownUsage,
            nextRequest: try makeEstimate()
        ).outcome else {
            return XCTFail("Expected cumulative unknown approval")
        }
        XCTAssertEqual(unknownCumulative.reasons, [.cumulativeCostUnavailable])

        guard case let .requiresApproval(bothUnknown) = BudgetGovernance().preflight(
            policy: try makePolicy(),
            usage: unknownUsage,
            nextRequest: unknownEstimate
        ).outcome else {
            return XCTFail("Expected both unknown costs to require approval")
        }
        XCTAssertEqual(
            bothUnknown.reasons,
            [.cumulativeCostUnavailable, .pricingUnavailable]
        )
    }

    func testScopeAndCostUnitMismatchesFailClosed() throws {
        let otherTaskID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
        let otherTaskUsage = try makeUsage(taskID: otherTaskID)
        XCTAssertEqual(
            BudgetGovernance().preflight(
                policy: try makePolicy(),
                usage: otherTaskUsage,
                nextRequest: try makeEstimate()
            ).outcome,
            .blocked(reasons: [.scopeMismatch])
        )

        XCTAssertEqual(
            BudgetGovernance().preflight(
                policy: try makePolicy(),
                usage: try makeUsage(),
                nextRequest: try makeEstimate(taskID: otherTaskID)
            ).outcome,
            .blocked(reasons: [.scopeMismatch])
        )

        XCTAssertEqual(
            BudgetGovernance().preflight(
                policy: try makePolicy(),
                usage: try makeUsage(cost: knownCost(0, currencyCode: "USD")),
                nextRequest: try makeEstimate()
            ).outcome,
            .blocked(reasons: [.costUnitMismatch])
        )
        XCTAssertEqual(
            BudgetGovernance().preflight(
                policy: try makePolicy(),
                usage: try makeUsage(),
                nextRequest: try makeEstimate(cost: knownCost(0, currencyCode: "USD"))
            ).outcome,
            .blocked(reasons: [.costUnitMismatch])
        )
    }

    func testUnsettledReservationAndEveryArithmeticOverflowFailClosed() throws {
        XCTAssertEqual(
            BudgetGovernance().preflight(
                policy: try makePolicy(),
                usage: try makeUsage(hasUnsettledReservation: true),
                nextRequest: try makeEstimate()
            ).outcome,
            .blocked(reasons: [.unsettledReservation])
        )

        let maximumPolicy = try makePolicy(
            maximumInputTokens: Int64.max,
            maximumOutputTokens: Int64.max,
            maximumCostMicroUnits: Int64.max,
            maximumElapsedMilliseconds: Int64.max
        )
        let overflowCases: [(BudgetUsageSnapshot, NextRequestBudgetEstimate)] = [
            (
                try makeUsage(inputTokens: Int64.max),
                try makeEstimate(inputTokens: 1)
            ),
            (
                try makeUsage(outputTokens: Int64.max),
                try makeEstimate(outputTokens: 1)
            ),
            (
                try makeUsage(cost: knownCost(Int64.max)),
                try makeEstimate(cost: knownCost(1))
            ),
            (
                try makeUsage(elapsedMilliseconds: Int64.max),
                try makeEstimate(elapsedMilliseconds: 1)
            )
        ]
        for (usage, estimate) in overflowCases {
            XCTAssertEqual(
                BudgetGovernance().preflight(
                    policy: maximumPolicy,
                    usage: usage,
                    nextRequest: estimate
                ).outcome,
                .blocked(reasons: [.arithmeticOverflow])
            )
        }
    }

    func testExactRequestHashBindsTrustedTaskAndImmutableManifests() throws {
        let original = try ProviderRequestBudgetIdentity(
            trustedTaskScope: budgetScope(),
            request: makePreparedRequest(promptManifestHash: hash("1"))
        )
        let changedManifest = try ProviderRequestBudgetIdentity(
            trustedTaskScope: budgetScope(),
            request: makePreparedRequest(promptManifestHash: hash("9"))
        )
        let changedTask = try ProviderRequestBudgetIdentity(
            trustedTaskScope: budgetScope(
                taskID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
            ),
            request: makePreparedRequest(promptManifestHash: hash("1"))
        )

        XCTAssertEqual(original.requestID, changedManifest.requestID)
        XCTAssertNotEqual(original.exactRequestHash, changedManifest.exactRequestHash)
        XCTAssertNotEqual(original.exactRequestHash, changedTask.exactRequestHash)
    }

    func testBudgetRequestIdentityUsesProviderModelLimitAndStrictCanonicalText() throws {
        let maximumModel = String(repeating: "m", count: ModelConnection.maximumModelIdentifierUTF8Bytes)
        XCTAssertNoThrow(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(modelID: maximumModel)
            )
        )
        XCTAssertNoThrow(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(modelID: String(repeating: "😀", count: 256))
            )
        )

        let valid = try ProviderRequestBudgetIdentity(
            trustedTaskScope: budgetScope(),
            request: makePreparedRequest()
        )
        let encoded = try JSONEncoder().encode(valid)
        var object = try jsonObject(encoded)
        var identity = try XCTUnwrap(object["identity"] as? [String: Any])
        identity["modelID"] = String(
            repeating: "m",
            count: ModelConnection.maximumModelIdentifierUTF8Bytes + 1
        )
        object["identity"] = identity
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                ProviderRequestBudgetIdentity.self,
                from: try JSONSerialization.data(withJSONObject: object)
            )
        )

        XCTAssertThrowsError(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(modelID: " deepseek-chat ")
            )
        )
        XCTAssertThrowsError(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(idempotencyKey: " request.key ")
            )
        )
        XCTAssertThrowsError(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(intentID: UUID()),
                request: makePreparedRequest()
            )
        )
        XCTAssertThrowsError(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(activeRunID: UUID()),
                request: makePreparedRequest()
            )
        )

        let maximumHost = [
            String(repeating: "a", count: 63),
            String(repeating: "b", count: 63),
            String(repeating: "c", count: 63),
            String(repeating: "d", count: 61)
        ].joined(separator: ".")
        XCTAssertEqual(maximumHost.utf8.count, ModelConnection.maximumBaseURLHostUTF8Bytes)
        XCTAssertNoThrow(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(
                    baseURL: try XCTUnwrap(URL(string: "https://\(maximumHost)"))
                )
            )
        )
        XCTAssertThrowsError(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(
                    baseURL: try XCTUnwrap(URL(string: "https://\(maximumHost)x"))
                )
            )
        )

        let maximumPath = "/" + String(
            repeating: "p",
            count: ModelConnection.maximumBaseURLPathUTF8Bytes - 1
        )
        XCTAssertNoThrow(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(
                    baseURL: try XCTUnwrap(URL(string: "https://example.com\(maximumPath)"))
                )
            )
        )
        XCTAssertThrowsError(
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(),
                request: makePreparedRequest(
                    baseURL: try XCTUnwrap(URL(string: "https://example.com\(maximumPath)p"))
                )
            )
        )
    }

    func testApprovalCanOnlyBeMintedFromLiveRequiresApprovalDecision() throws {
        let governance = BudgetGovernance()
        let now: Int64 = 1_700_000_000_000
        let expiresAt: Int64 = 1_800_000_000_000
        let approvalDecision = try self.approvalDecision()

        XCTAssertNoThrow(
            try governance.makeApprovalBinding(
                approvalRequestID: approvalID,
                decision: approvalDecision,
                expiresAtEpochMilliseconds: expiresAt,
                nowEpochMilliseconds: now
            )
        )
        XCTAssertThrowsError(
            try governance.makeApprovalBinding(
                approvalRequestID: approvalID,
                decision: governance.preflight(
                    policy: makePolicy(),
                    usage: makeUsage(),
                    nextRequest: makeEstimate()
                ),
                expiresAtEpochMilliseconds: expiresAt,
                nowEpochMilliseconds: now
            )
        ) { error in
            XCTAssertEqual(error as? BudgetGovernanceError, .invalidApprovalBinding)
        }
        XCTAssertThrowsError(
            try governance.makeApprovalBinding(
                approvalRequestID: approvalID,
                decision: governance.preflight(
                    policy: makePolicy(),
                    usage: makeUsage(taskID: UUID()),
                    nextRequest: makeEstimate()
                ),
                expiresAtEpochMilliseconds: expiresAt,
                nowEpochMilliseconds: now
            )
        )
        XCTAssertThrowsError(
            try governance.makeApprovalBinding(
                approvalRequestID: approvalID,
                decision: approvalDecision,
                expiresAtEpochMilliseconds: now,
                nowEpochMilliseconds: now
            )
        )
        XCTAssertThrowsError(
            try governance.makeApprovalBinding(
                approvalRequestID: approvalID,
                decision: approvalDecision,
                expiresAtEpochMilliseconds: expiresAt,
                nowEpochMilliseconds: -1
            )
        )
    }

    func testApprovalBindsTaskBudgetUsageRequestReasonsAndExpiry() throws {
        let policy = try makePolicy()
        let usage = try makeUsage()
        let estimate = try makeEstimate(cost: knownCost(20_000))
        let now: Int64 = 1_700_000_000_000
        let expiresAt: Int64 = 1_800_000_000_000
        let governance = BudgetGovernance()
        let approved = try governance.makeApprovalBinding(
            approvalRequestID: approvalID,
            decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
            expiresAtEpochMilliseconds: expiresAt,
            nowEpochMilliseconds: now
        )

        XCTAssertEqual(approved.expiresAtEpochMilliseconds, expiresAt)
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
                nowEpochMilliseconds: expiresAt - 1
            ),
            .approved
        )
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
                nowEpochMilliseconds: expiresAt
            ),
            .requiresReapproval(reasons: [.approvalExpired])
        )
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
                nowEpochMilliseconds: -1
            ),
            .requiresReapproval(reasons: [.invalidCurrentTime])
        )

        let newerPolicy = try makePolicy(version: 2)
        let newerUsage = try makeUsage(budgetVersion: 2)
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: try approvalDecision(
                    policy: newerPolicy,
                    usage: newerUsage,
                    estimate: estimate
                ),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.budgetVersionChanged, .usageChanged])
        )

        let changedUsage = try makeUsage(revision: 2, inputTokens: 1)
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: try approvalDecision(
                    policy: policy,
                    usage: changedUsage,
                    estimate: estimate
                ),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.usageChanged])
        )

        let changedRequest = try makeEstimate(
            cost: knownCost(20_000),
            promptManifestHash: hash("8")
        )
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: try approvalDecision(
                    policy: policy,
                    usage: usage,
                    estimate: changedRequest
                ),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.providerRequestChanged, .estimateChanged])
        )

        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: governance.preflight(
                    policy: policy,
                    usage: usage,
                    nextRequest: try makeEstimate()
                ),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.preflightNoLongerRequiresApproval])
        )
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: approved.bindingHash,
                decision: governance.preflight(
                    policy: policy,
                    usage: try makeUsage(taskID: UUID()),
                    nextRequest: estimate
                ),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.preflightBlocked])
        )

        let replacementID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
        let rebound = try governance.makeApprovalBinding(
            approvalRequestID: replacementID,
            decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
            expiresAtEpochMilliseconds: expiresAt,
            nowEpochMilliseconds: now
        )
        let decodedRebound = try JSONDecoder().decode(
            BudgetApprovalBinding.self,
            from: JSONEncoder().encode(rebound)
        )
        XCTAssertEqual(
            decodedRebound.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: decodedRebound.bindingHash,
                decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.approvalRequestIDChanged])
        )
        XCTAssertEqual(
            approved.validate(
                approvalRequestID: approvalID,
                approvedBindingHash: "sha256-v1:" + hash("0"),
                decision: try approvalDecision(policy: policy, usage: usage, estimate: estimate),
                nowEpochMilliseconds: now
            ),
            .requiresReapproval(reasons: [.bindingHashChanged])
        )
    }

    func testApprovalCodableRejectsFieldExpiryReasonAndHashTampering() throws {
        let binding = try makeApprovalBinding()
        let data = try JSONEncoder().encode(binding)
        XCTAssertEqual(
            try JSONDecoder().decode(BudgetApprovalBinding.self, from: data),
            binding
        )

        for (key, replacement): (String, Any) in [
            ("approvalRequestID", "cccccccc-cccc-cccc-cccc-cccccccccccc"),
            ("taskID", "cccccccc-cccc-cccc-cccc-cccccccccccc"),
            ("budgetVersion", 99),
            ("policyHash", hash("f")),
            ("usageRevision", 99),
            ("usageHash", hash("f")),
            ("providerRequestID", "cccccccc-cccc-cccc-cccc-cccccccccccc"),
            ("exactRequestHash", hash("f")),
            ("estimateHash", hash("f")),
            ("reasons", ["inputTokens"]),
            ("expiresAtEpochMilliseconds", binding.expiresAtEpochMilliseconds + 1),
            ("bindingHash", "sha256-v1:" + hash("0"))
        ] {
            var object = try jsonObject(data)
            object[key] = replacement
            XCTAssertThrowsError(
                try JSONDecoder().decode(
                    BudgetApprovalBinding.self,
                    from: try JSONSerialization.data(withJSONObject: object)
                ),
                "Expected tampered key \(key) to fail"
            )
        }

        var duplicateReasons = try jsonObject(data)
        duplicateReasons["reasons"] = ["cost", "cost"]
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                BudgetApprovalBinding.self,
                from: try JSONSerialization.data(withJSONObject: duplicateReasons)
            )
        )
    }

    func testReservationCodableRejectsCanonicalFieldAndHashTampering() throws {
        let decision = BudgetGovernance().preflight(
            policy: try makePolicy(),
            usage: try makeUsage(),
            nextRequest: try makeEstimate()
        )
        guard case let .proceed(reservation) = decision.outcome else {
            return XCTFail("Expected reservation")
        }
        let data = try JSONEncoder().encode(reservation)

        for (key, replacement): (String, Any) in [
            ("taskID", "cccccccc-cccc-cccc-cccc-cccccccccccc"),
            ("budgetVersion", 0),
            ("usageRevision", 0),
            ("policyHash", hash("f")),
            ("usageHash", hash("f")),
            ("providerRequestID", "cccccccc-cccc-cccc-cccc-cccccccccccc"),
            ("exactRequestHash", hash("f")),
            ("estimateHash", hash("f")),
            ("canonicalHash", hash("0"))
        ] {
            var object = try jsonObject(data)
            object[key] = replacement
            XCTAssertThrowsError(
                try JSONDecoder().decode(
                    BudgetReservationCandidate.self,
                    from: try JSONSerialization.data(withJSONObject: object)
                ),
                "Expected tampered key \(key) to fail"
            )
        }
    }

    func testBudgetCostCodableIsExplicitAndValidated() throws {
        let costs: [BudgetCost] = [
            knownCost(123, basis: .actual, pricingVersion: "receipt-v1"),
            unknownCost(reason: .outcomeUnknown, pricingKey: "deepseek|deepseek-chat")
        ]
        for cost in costs {
            XCTAssertEqual(
                try JSONDecoder().decode(BudgetCost.self, from: JSONEncoder().encode(cost)),
                cost
            )
        }

        let knownData = try JSONEncoder().encode(knownCost(123))
        for (key, replacement): (String, Any) in [
            ("microUnits", -1),
            ("currencyCode", "cny"),
            ("scale", 100),
            ("pricingVersion", " pricing-v1 ")
        ] {
            var object = try jsonObject(knownData)
            object[key] = replacement
            XCTAssertThrowsError(
                try JSONDecoder().decode(
                    BudgetCost.self,
                    from: try JSONSerialization.data(withJSONObject: object)
                ),
                "Expected invalid cost key \(key) to fail"
            )
        }

        var mixedFields = try jsonObject(knownData)
        mixedFields["reason"] = "pricingUnavailable"
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                BudgetCost.self,
                from: try JSONSerialization.data(withJSONObject: mixedFields)
            )
        )
        XCTAssertThrowsError(
            try JSONEncoder().encode(
                BudgetCost.known(
                    microUnits: -1,
                    basis: .estimated,
                    pricingVersion: "pricing-v1",
                    currencyCode: "CNY",
                    scale: BudgetCost.microUnitScale
                )
            )
        )
    }

    func testStrictCanonicalCostTextIsRejectedAtEveryBoundary() throws {
        XCTAssertThrowsError(
            try makeUsage(
                cost: .known(
                    microUnits: 0,
                    basis: .estimated,
                    pricingVersion: " pricing-v1 ",
                    currencyCode: "CNY",
                    scale: BudgetCost.microUnitScale
                )
            )
        )
        XCTAssertThrowsError(
            try makeEstimate(
                cost: .unknown(
                    reason: .pricingUnavailable,
                    pricingKey: " key ",
                    currencyCode: "CNY",
                    scale: BudgetCost.microUnitScale
                )
            )
        )
    }

    func testCanonicalHashVectorsAreStable() throws {
        let policy = try makePolicy(
            maximumInputTokens: 110,
            maximumOutputTokens: 220,
            maximumCostMicroUnits: 330,
            maximumElapsedMilliseconds: 440
        )
        let usage = try makeUsage(
            inputTokens: 100,
            outputTokens: 200,
            cost: knownCost(300),
            elapsedMilliseconds: 400
        )
        let estimate = try makeEstimate(
            inputTokens: 10,
            outputTokens: 20,
            cost: knownCost(30),
            elapsedMilliseconds: 40
        )
        let requestIdentity = estimate.requestIdentity
        let decision = BudgetGovernance().preflight(
            policy: policy,
            usage: usage,
            nextRequest: estimate
        )
        guard case let .proceed(reservation) = decision.outcome else {
            return XCTFail("Expected reservation")
        }
        let approval = try makeApprovalBinding()

        XCTAssertEqual(
            policy.canonicalHash,
            "faceebc394bae7b36dc1cc0a5961ef8326ef04517b7deb0537f1280630a32852"
        )
        XCTAssertEqual(
            usage.canonicalHash,
            "1c1e2dc9132b7089ebcbff1f7ee4f4bde07344e3ff44384996b0a3be455d9ee0"
        )
        XCTAssertEqual(
            requestIdentity.exactRequestHash,
            "d4c5b38677587c244d91c2fdc28b0ad28ef7e902b07cbffcd593aa981eb569b4"
        )
        XCTAssertEqual(
            estimate.canonicalHash,
            "2b7c14ad328d1bffdb0c526d3e98611fc8fcf9c1f2d0e1acb9946f556301c250"
        )
        XCTAssertEqual(
            reservation.canonicalHash,
            "13eaf77c73dc38b70d9e0cee425af61085de854af45648b26c56e8adc707b732"
        )
        XCTAssertEqual(
            approval.bindingHash,
            "sha256-v1:10e75f41a4af9d996656872b3a91ded539aaeb310a095deac1deea0e941a2f33"
        )
    }

    private func makePolicy(
        taskID: UUID? = nil,
        version: Int64 = 1,
        maximumInputTokens: Int64 = 10_000,
        maximumOutputTokens: Int64 = 10_000,
        maximumCostMicroUnits: Int64 = 10_000,
        maximumElapsedMilliseconds: Int64 = 60_000
    ) throws -> TaskBudgetPolicy {
        try TaskBudgetPolicy(
            taskID: taskID ?? self.taskID,
            version: version,
            maximumInputTokens: maximumInputTokens,
            maximumOutputTokens: maximumOutputTokens,
            maximumCostMicroUnits: maximumCostMicroUnits,
            currencyCode: "CNY",
            costScale: BudgetCost.microUnitScale,
            maximumElapsedMilliseconds: maximumElapsedMilliseconds
        )
    }

    private func makeUsage(
        taskID: UUID? = nil,
        budgetVersion: Int64 = 1,
        revision: Int64 = 1,
        inputTokens: Int64 = 0,
        outputTokens: Int64 = 0,
        cost: BudgetCost? = nil,
        elapsedMilliseconds: Int64 = 0,
        hasUnsettledReservation: Bool = false
    ) throws -> BudgetUsageSnapshot {
        try BudgetUsageSnapshot(
            taskID: taskID ?? self.taskID,
            budgetVersion: budgetVersion,
            revision: revision,
            cumulativeInputTokens: inputTokens,
            cumulativeOutputTokens: outputTokens,
            cumulativeCost: cost ?? knownCost(0),
            cumulativeElapsedMilliseconds: elapsedMilliseconds,
            hasUnsettledReservation: hasUnsettledReservation
        )
    }

    private func makeEstimate(
        taskID: UUID? = nil,
        inputTokens: Int64 = 0,
        outputTokens: Int64 = 0,
        cost: BudgetCost? = nil,
        elapsedMilliseconds: Int64 = 0,
        promptManifestHash: String? = nil
    ) throws -> NextRequestBudgetEstimate {
        try NextRequestBudgetEstimate(
            requestIdentity: ProviderRequestBudgetIdentity(
                trustedTaskScope: budgetScope(taskID: taskID ?? self.taskID),
                request: makePreparedRequest(
                    promptManifestHash: promptManifestHash ?? hash("1")
                )
            ),
            reservedInputTokens: inputTokens,
            reservedOutputTokens: outputTokens,
            reservedCost: cost ?? knownCost(0),
            reservedElapsedMilliseconds: elapsedMilliseconds
        )
    }

    private func approvalDecision(
        policy: TaskBudgetPolicy? = nil,
        usage: BudgetUsageSnapshot? = nil,
        estimate: NextRequestBudgetEstimate? = nil
    ) throws -> BudgetPreflightDecision {
        let decision = BudgetGovernance().preflight(
            policy: try policy ?? makePolicy(),
            usage: try usage ?? makeUsage(),
            nextRequest: try estimate ?? makeEstimate(cost: knownCost(20_000))
        )
        guard case .requiresApproval = decision.outcome else {
            throw TestError.expectedApproval
        }
        return decision
    }

    private func makeApprovalBinding() throws -> BudgetApprovalBinding {
        try BudgetGovernance().makeApprovalBinding(
            approvalRequestID: approvalID,
            decision: approvalDecision(),
            expiresAtEpochMilliseconds: 1_800_000_000_000,
            nowEpochMilliseconds: 1_700_000_000_000
        )
    }

    private func knownCost(
        _ microUnits: Int64,
        basis: BudgetCostBasis = .estimated,
        pricingVersion: String = "deepseek-2026-07",
        currencyCode: String = "CNY"
    ) -> BudgetCost {
        .known(
            microUnits: microUnits,
            basis: basis,
            pricingVersion: pricingVersion,
            currencyCode: currencyCode,
            scale: BudgetCost.microUnitScale
        )
    }

    private func unknownCost(
        reason: BudgetUnknownCostReason,
        pricingKey: String,
        currencyCode: String = "CNY"
    ) -> BudgetCost {
        .unknown(
            reason: reason,
            pricingKey: pricingKey,
            currencyCode: currencyCode,
            scale: BudgetCost.microUnitScale
        )
    }

    private func makePreparedRequest(
        requestID: UUID? = nil,
        promptManifestHash: String? = nil,
        modelID: String = "deepseek-chat",
        idempotencyKey: String = "provider.request.budget.1.1",
        baseURL: URL = URL(string: "https://api.deepseek.com")!
    ) throws -> ProviderRequestSnapshot {
        try ProviderRequestLifecycle.prepare(
            identity: ProviderRequestIdentity(
                requestID: requestID ?? self.requestID,
                idempotencyKey: idempotencyKey,
                intentID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                conversationID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                projectID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                branchID: nil,
                runID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                connectionID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                credentialID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                credentialVersionID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                credentialVersionProof: hash("a"),
                credentialPayloadHash: hash("b"),
                setupAuthorizationHash: hash("c"),
                provider: .deepSeek,
                baseURL: baseURL,
                modelID: modelID
            ),
            responseAssetID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            promptManifestHash: promptManifestHash ?? hash("1"),
            contextManifestHash: hash("2"),
            toolCatalogManifestHash: hash("3"),
            disclosureScopeHash: hash("4"),
            requestPolicyHash: hash("5"),
            now: Date(timeIntervalSince1970: 1_753_456_789)
        )
    }

    private func budgetScope(
        taskID: UUID? = nil,
        intentID: UUID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        activeRunID: UUID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    ) -> ProviderRequestBudgetTaskScope {
        ProviderRequestBudgetTaskScope(
            taskID: taskID ?? self.taskID,
            intentID: intentID,
            activeRunID: activeRunID
        )
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private enum TestError: Error {
        case expectedApproval
    }
}
