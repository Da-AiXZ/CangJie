import CangJieCore
import Foundation

protocol ProviderBudgetEstimating: Sendable {
    func initialPolicy(taskID: UUID) throws -> TaskBudgetPolicy

    func estimate(
        taskScope: ProviderRequestBudgetTaskScope,
        request: ProviderRequestSnapshot,
        prompt: ProviderGenerationPrompt
    ) throws -> NextRequestBudgetEstimate
}

struct FailClosedProviderBudgetEstimator: ProviderBudgetEstimating {
    static let policyVersion: Int64 = 1
    static let maximumInputTokens: Int64 = 1_048_576
    static let maximumOutputTokens: Int64 = 8_192
    static let maximumCostMicroCNY: Int64 = 2_000_000
    static let maximumElapsedMilliseconds: Int64 = 600_000
    static let requestElapsedReservationMilliseconds: Int64 = 300_000
    static let promptEnvelopeTokenUpperBound: Int64 = 16_384

    func initialPolicy(taskID: UUID) throws -> TaskBudgetPolicy {
        try TaskBudgetPolicy(
            taskID: taskID,
            version: Self.policyVersion,
            maximumInputTokens: Self.maximumInputTokens,
            maximumOutputTokens: Self.maximumOutputTokens,
            maximumCostMicroUnits: Self.maximumCostMicroCNY,
            currencyCode: "CNY",
            costScale: BudgetCost.microUnitScale,
            maximumElapsedMilliseconds: Self.maximumElapsedMilliseconds
        )
    }

    func estimate(
        taskScope: ProviderRequestBudgetTaskScope,
        request: ProviderRequestSnapshot,
        prompt: ProviderGenerationPrompt
    ) throws -> NextRequestBudgetEstimate {
        try prompt.validate()
        let reservedInputTokens = try inputTokenUpperBound(for: prompt)
        let reservedOutputTokens = Int64(
            ProviderRequestPolicyVersion.current.maximumOutputTokens ?? 0
        )
        guard reservedOutputTokens > 0 else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        let identity = request.identity
        let pricingKey = [
            identity.provider.rawValue,
            identity.baseURL.absoluteString,
            identity.modelID
        ].joined(separator: "|")
        return try NextRequestBudgetEstimate(
            requestIdentity: ProviderRequestBudgetIdentity(
                trustedTaskScope: taskScope,
                request: request
            ),
            reservedInputTokens: reservedInputTokens,
            reservedOutputTokens: reservedOutputTokens,
            reservedCost: .unknown(
                reason: .pricingUnavailable,
                pricingKey: pricingKey,
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            ),
            reservedElapsedMilliseconds:
                Self.requestElapsedReservationMilliseconds
        )
    }

    private func inputTokenUpperBound(
        for prompt: ProviderGenerationPrompt
    ) throws -> Int64 {
        var total = Self.promptEnvelopeTokenUpperBound
        try add(prompt.systemPrompt, to: &total)
        try add(prompt.userPrompt, to: &total)
        if let response = prompt.assistantResponse {
            try add(response.text, to: &total)
            for call in response.toolCalls {
                try add(call.id ?? "", to: &total)
                try add(call.name ?? "", to: &total)
                try add(call.argumentsJSON, to: &total)
            }
        }
        for result in prompt.toolResults {
            try add(result.callID, to: &total)
            try add(result.contentJSON, to: &total)
        }
        return total
    }

    private func add(_ value: String, to total: inout Int64) throws {
        guard let count = Int64(exactly: value.utf8.count) else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        let result = total.addingReportingOverflow(count)
        guard !result.overflow else {
            throw ProviderGenerationError.invalidPreparedRequest
        }
        total = result.partialValue
    }
}

#if DEBUG
struct DeterministicTestProviderBudgetEstimator: ProviderBudgetEstimating {
    func initialPolicy(taskID: UUID) throws -> TaskBudgetPolicy {
        try TaskBudgetPolicy(
            taskID: taskID,
            version: 1,
            maximumInputTokens: 10_000_000,
            maximumOutputTokens: 10_000_000,
            maximumCostMicroUnits: 10_000_000_000,
            currencyCode: "CNY",
            costScale: BudgetCost.microUnitScale,
            maximumElapsedMilliseconds: 86_400_000
        )
    }

    func estimate(
        taskScope: ProviderRequestBudgetTaskScope,
        request: ProviderRequestSnapshot,
        prompt: ProviderGenerationPrompt
    ) throws -> NextRequestBudgetEstimate {
        let base = try FailClosedProviderBudgetEstimator().estimate(
            taskScope: taskScope,
            request: request,
            prompt: prompt
        )
        return try NextRequestBudgetEstimate(
            requestIdentity: base.requestIdentity,
            reservedInputTokens: base.reservedInputTokens,
            reservedOutputTokens: base.reservedOutputTokens,
            reservedCost: .known(
                microUnits: 0,
                basis: .estimated,
                pricingVersion: "deterministic-test-v1",
                currencyCode: "CNY",
                scale: BudgetCost.microUnitScale
            ),
            reservedElapsedMilliseconds: base.reservedElapsedMilliseconds
        )
    }
}
#endif
