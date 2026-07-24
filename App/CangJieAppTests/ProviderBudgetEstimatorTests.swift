@_spi(ModelCredentialVerification) import CangJieCore
import Foundation
import XCTest
@testable import CangJie

final class ProviderBudgetEstimatorTests: XCTestCase {
    func testProductionPolicyIsVersionedAndFourDimensional() throws {
        let taskID = UUID()
        let policy = try FailClosedProviderBudgetEstimator()
            .initialPolicy(taskID: taskID)

        XCTAssertEqual(policy.taskID, taskID)
        XCTAssertEqual(policy.version, 1)
        XCTAssertEqual(policy.maximumInputTokens, 1_048_576)
        XCTAssertEqual(policy.maximumOutputTokens, 8_192)
        XCTAssertEqual(policy.maximumCostMicroUnits, 2_000_000)
        XCTAssertEqual(policy.currencyCode, "CNY")
        XCTAssertEqual(policy.costScale, BudgetCost.microUnitScale)
        XCTAssertEqual(policy.maximumElapsedMilliseconds, 600_000)
    }

    func testProductionEstimateUsesConservativeTokensAndUnknownPricing() throws {
        let request = try makeRequest()
        let taskID = UUID()
        let prompt = ProviderGenerationPrompt.initial(
            systemPrompt: "system",
            userPrompt: "user"
        )

        let estimate = try FailClosedProviderBudgetEstimator().estimate(
            taskScope: ProviderRequestBudgetTaskScope(
                taskID: taskID,
                intentID: request.identity.intentID,
                activeRunID: request.identity.runID
            ),
            request: request,
            prompt: prompt
        )

        XCTAssertEqual(
            estimate.requestIdentity,
            try ProviderRequestBudgetIdentity(
                trustedTaskScope: ProviderRequestBudgetTaskScope(
                    taskID: taskID,
                    intentID: request.identity.intentID,
                    activeRunID: request.identity.runID
                ),
                request: request
            )
        )
        XCTAssertGreaterThanOrEqual(
            estimate.reservedInputTokens,
            Int64(prompt.systemPrompt.utf8.count + prompt.userPrompt.utf8.count)
        )
        XCTAssertEqual(estimate.reservedOutputTokens, 4_096)
        XCTAssertEqual(
            estimate.reservedCost,
            .unknown(
                reason: .pricingUnavailable,
                pricingKey: "deepSeek|https://api.deepseek.com|deepseek-chat",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            )
        )
        XCTAssertEqual(estimate.reservedElapsedMilliseconds, 300_000)
    }

    private func makeRequest() throws -> ProviderRequestSnapshot {
        let now = Date(timeIntervalSince1970: 2_000)
        let intent = try PendingModelIntent(
            id: UUID(),
            conversationID: UUID(),
            projectID: nil,
            branchID: nil,
            userRequest: "test",
            createdAt: now
        )
        let connection = try ModelConnectionTestFixture.makeConnection(
            provider: .deepSeek,
            baseURL: URL(string: "https://api.deepseek.com")!,
            credentialID: UUID(),
            selectedModel: "deepseek-chat",
            secret: "fixture-secret"
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
        return try ProviderRequestLifecycle.prepare(
            requestID: UUID(),
            runID: UUID(),
            idempotencyKey: "provider.request.budget-estimate.1.1",
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
    }

    private func hash(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }
}
