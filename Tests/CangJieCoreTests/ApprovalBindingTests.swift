import Foundation
import XCTest
@testable import CangJieCore

final class ApprovalBindingTests: XCTestCase {
    private let approvalRequestID = UUID(uuidString: "00000000-1111-2222-3333-444444444444")!
    private let conversationID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let projectID = UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!
    private let artifactLogicalID = UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!
    private let artifactID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let nowEpochMilliseconds: Int64 = 1_800_000_000_000

    func testApprovalAcceptsOnlyExactBoundCandidate() {
        let approved = makeBinding()

        XCTAssertEqual(
            approved.validate(candidate: approved, nowEpochMilliseconds: nowEpochMilliseconds),
            .approved
        )
    }

    func testCanonicalBindingHashMatchesFixedVector() {
        XCTAssertEqual(
            makeBinding().bindingHash,
            "sha256-v1:61b41170c1e85d6455eb5d3caf774a78857eaa27f85bc07de971fc27ddae1631"
        )
    }

    func testCanonicalHashDoesNotDependOnTargetDictionaryInsertionOrder() {
        let first = makeBinding(targetVersions: ["project": 3, "conversation": 12])
        let second = makeBinding(targetVersions: ["conversation": 12, "project": 3])

        XCTAssertEqual(first.bindingHash, second.bindingHash)
        XCTAssertEqual(first, second)
    }

    func testNewApprovalRequestIdentityProducesDistinctBindingHash() {
        let first = makeBinding()
        let second = first.replacing(
            approvalRequestID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        )

        XCTAssertNotEqual(first.bindingHash, second.bindingHash)
        XCTAssertEqual(
            first.validate(candidate: second, nowEpochMilliseconds: nowEpochMilliseconds),
            .requiresReapproval(reasons: [.approvalRequestIDChanged, .bindingHashChanged])
        )
    }

    func testAnyMaterialBindingChangeInvalidatesApproval() {
        let approved = makeBinding()
        let changes: [(ApprovalInvalidationReason, (ApprovalBinding) -> ApprovalBinding)] = [
            (.conversationIDChanged, { binding in
                binding.replacing(conversationID: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!)
            }),
            (.projectIDChanged, { binding in
                binding.replacing(projectID: UUID(uuidString: "77777777-8888-9999-AAAA-BBBBBBBBBBBB")!)
            }),
            (.artifactLogicalIDChanged, { binding in
                binding.replacing(artifactLogicalID: UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-000000000000")!)
            }),
            (.artifactIDChanged, { binding in
                binding.replacing(artifactID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!)
            }),
            (.artifactRevisionChanged, { binding in binding.replacing(artifactRevision: 8) }),
            (.artifactHashChanged, { binding in binding.replacing(artifactHash: "sha256:plan-2") }),
            (.toolIDChanged, { binding in binding.replacing(toolID: "artifact.openingPlan.patch") }),
            (.toolVersionChanged, { binding in binding.replacing(toolVersion: "2") }),
            (.parametersHashChanged, { binding in binding.replacing(parametersHash: "sha256:parameters-2") }),
            (.targetVersionsChanged, { binding in
                binding.replacing(targetVersions: ["project": 4, "conversation": 12])
            }),
            (.estimatedCostChanged, { binding in binding.replacing(estimatedCostMinorUnits: 499) }),
            (.budgetCeilingChanged, { binding in binding.replacing(budgetCeilingMinorUnits: 1_001) }),
            (.expirationChanged, { binding in
                binding.replacing(expiresAtEpochMilliseconds: binding.expiresAtEpochMilliseconds + 60_000)
            }),
            (.expectedDiffChanged, { binding in binding.replacing(expectedDiffHash: "sha256:diff-2") })
        ]

        for (expectedReason, mutate) in changes {
            let candidate = mutate(approved)

            XCTAssertEqual(
                approved.validate(candidate: candidate, nowEpochMilliseconds: nowEpochMilliseconds),
                .requiresReapproval(reasons: [expectedReason, .bindingHashChanged]),
                "Changing \(expectedReason) must invalidate the prior approval"
            )
        }
    }

    func testApprovalExpiresExactlyAtCanonicalMillisecondBoundary() {
        let approved = makeBinding(expiresAtEpochMilliseconds: nowEpochMilliseconds + 60_000)

        XCTAssertEqual(
            approved.validate(
                candidate: approved,
                nowEpochMilliseconds: approved.expiresAtEpochMilliseconds - 1
            ),
            .approved
        )
        XCTAssertEqual(
            approved.validate(
                candidate: approved,
                nowEpochMilliseconds: approved.expiresAtEpochMilliseconds
            ),
            .requiresReapproval(reasons: [.expired])
        )
        XCTAssertEqual(
            approved.validate(
                candidate: approved,
                nowEpochMilliseconds: approved.expiresAtEpochMilliseconds + 1
            ),
            .requiresReapproval(reasons: [.expired])
        )
    }

    func testDateValidationUsesFloorToCanonicalEpochMilliseconds() {
        let approved = makeBinding(expiresAtEpochMilliseconds: nowEpochMilliseconds + 60_000)
        let justBeforeExpiry = Date(
            timeIntervalSince1970: Double(approved.expiresAtEpochMilliseconds) / 1_000 - 0.000_1
        )
        let atExpiry = approved.expiresAt

        XCTAssertEqual(approved.validate(candidate: approved, now: justBeforeExpiry), .approved)
        XCTAssertEqual(
            approved.validate(candidate: approved, now: atExpiry),
            .requiresReapproval(reasons: [.expired])
        )
    }

    func testBudgetAtCeilingIsAllowedButOverCeilingIsRejected() {
        let atCeiling = makeBinding(estimatedCostMinorUnits: 1_000, budgetCeilingMinorUnits: 1_000)
        let overCeiling = makeBinding(estimatedCostMinorUnits: 1_001, budgetCeilingMinorUnits: 1_000)

        XCTAssertEqual(
            atCeiling.validate(candidate: atCeiling, nowEpochMilliseconds: nowEpochMilliseconds),
            .approved
        )
        XCTAssertEqual(
            overCeiling.validate(candidate: overCeiling, nowEpochMilliseconds: nowEpochMilliseconds),
            .requiresReapproval(reasons: [.estimatedCostExceedsBudget])
        )
    }

    func testInvalidBudgetsFailClosed() {
        let negativeEstimate = makeBinding(estimatedCostMinorUnits: -1)
        let negativeCeiling = makeBinding(budgetCeilingMinorUnits: -1)
        let bothInvalid = makeBinding(estimatedCostMinorUnits: -1, budgetCeilingMinorUnits: -1)

        XCTAssertEqual(
            negativeEstimate.validate(candidate: negativeEstimate, nowEpochMilliseconds: nowEpochMilliseconds),
            .requiresReapproval(reasons: [.invalidEstimatedCost])
        )
        XCTAssertEqual(
            negativeCeiling.validate(candidate: negativeCeiling, nowEpochMilliseconds: nowEpochMilliseconds),
            .requiresReapproval(reasons: [.invalidBudgetCeiling, .estimatedCostExceedsBudget])
        )
        XCTAssertEqual(
            bothInvalid.validate(candidate: bothInvalid, nowEpochMilliseconds: nowEpochMilliseconds),
            .requiresReapproval(reasons: [.invalidEstimatedCost, .invalidBudgetCeiling])
        )
    }

    func testInvalidStructureFailsClosedEvenWhenStoredAndCandidateMatch() {
        let cases: [(ApprovalInvalidationReason, ApprovalBinding)] = [
            (.invalidArtifactRevision, makeBinding(artifactRevision: 0)),
            (.emptyArtifactHash, makeBinding(artifactHash: "  ")),
            (.emptyToolID, makeBinding(toolID: "")),
            (.emptyToolVersion, makeBinding(toolVersion: "\n")),
            (.emptyParametersHash, makeBinding(parametersHash: "")),
            (.emptyExpectedDiffHash, makeBinding(expectedDiffHash: "\t")),
            (.emptyTargetVersions, makeBinding(targetVersions: [:])),
            (.emptyTargetIdentifier, makeBinding(targetVersions: ["": 1])),
            (.invalidTargetVersion, makeBinding(targetVersions: ["project": -1]))
        ]

        for (expectedReason, binding) in cases {
            XCTAssertEqual(
                binding.validate(candidate: binding, nowEpochMilliseconds: nowEpochMilliseconds),
                .requiresReapproval(reasons: [expectedReason]),
                "Invalid structure must fail closed with \(expectedReason)"
            )
        }
    }

    func testBindingCodableRoundTripPreservesExactContractAndComputedHash() throws {
        let binding = makeBinding()

        let encoded = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(ApprovalBinding.self, from: encoded)

        XCTAssertEqual(decoded, binding)
        XCTAssertEqual(decoded.bindingHash, binding.bindingHash)
        XCTAssertEqual(decoded.expiresAtEpochMilliseconds, 1_800_000_600_000)
    }

    func testDecodingRejectsPayloadWhoseFieldsDoNotMatchEncodedBindingHash() throws {
        let encoded = try JSONEncoder().encode(makeBinding())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["artifactHash"] = "sha256:tampered"
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertThrowsError(try JSONDecoder().decode(ApprovalBinding.self, from: tampered)) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
        }
    }

    private func makeBinding(
        artifactRevision: Int = 7,
        artifactHash: String = "sha256:plan-1",
        toolID: String = "artifact.openingPlan.approve",
        toolVersion: String = "1",
        parametersHash: String = "sha256:parameters-1",
        targetVersions: [String: Int] = ["project": 3, "conversation": 12],
        estimatedCostMinorUnits: Int = 500,
        budgetCeilingMinorUnits: Int = 1_000,
        expiresAtEpochMilliseconds: Int64? = nil,
        expectedDiffHash: String = "sha256:diff-1"
    ) -> ApprovalBinding {
        ApprovalBinding(
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
            targetVersions: targetVersions,
            estimatedCostMinorUnits: estimatedCostMinorUnits,
            budgetCeilingMinorUnits: budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds ?? nowEpochMilliseconds + 600_000,
            expectedDiffHash: expectedDiffHash
        )
    }
}

private extension ApprovalBinding {
    func replacing(
        approvalRequestID: UUID? = nil,
        conversationID: UUID? = nil,
        projectID: UUID? = nil,
        artifactLogicalID: UUID? = nil,
        artifactID: UUID? = nil,
        artifactRevision: Int? = nil,
        artifactHash: String? = nil,
        toolID: String? = nil,
        toolVersion: String? = nil,
        parametersHash: String? = nil,
        targetVersions: [String: Int]? = nil,
        estimatedCostMinorUnits: Int? = nil,
        budgetCeilingMinorUnits: Int? = nil,
        expiresAtEpochMilliseconds: Int64? = nil,
        expectedDiffHash: String? = nil
    ) -> ApprovalBinding {
        ApprovalBinding(
            approvalRequestID: approvalRequestID ?? self.approvalRequestID,
            conversationID: conversationID ?? self.conversationID,
            projectID: projectID ?? self.projectID,
            artifactLogicalID: artifactLogicalID ?? self.artifactLogicalID,
            artifactID: artifactID ?? self.artifactID,
            artifactRevision: artifactRevision ?? self.artifactRevision,
            artifactHash: artifactHash ?? self.artifactHash,
            toolID: toolID ?? self.toolID,
            toolVersion: toolVersion ?? self.toolVersion,
            parametersHash: parametersHash ?? self.parametersHash,
            targetVersions: targetVersions ?? self.targetVersions,
            estimatedCostMinorUnits: estimatedCostMinorUnits ?? self.estimatedCostMinorUnits,
            budgetCeilingMinorUnits: budgetCeilingMinorUnits ?? self.budgetCeilingMinorUnits,
            expiresAtEpochMilliseconds: expiresAtEpochMilliseconds ?? self.expiresAtEpochMilliseconds,
            expectedDiffHash: expectedDiffHash ?? self.expectedDiffHash
        )
    }
}
