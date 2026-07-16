import Foundation

public struct UsageRecord: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let estimatedCostCNY: Decimal
    public let elapsedSeconds: TimeInterval

    public init(inputTokens: Int, outputTokens: Int, estimatedCostCNY: Decimal, elapsedSeconds: TimeInterval) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.estimatedCostCNY = estimatedCostCNY
        self.elapsedSeconds = elapsedSeconds
    }
}

public struct BudgetLimit: Codable, Equatable, Sendable {
    public let maximumCostCNY: Decimal
    public let maximumElapsedSeconds: TimeInterval

    public init(maximumCostCNY: Decimal, maximumElapsedSeconds: TimeInterval) {
        self.maximumCostCNY = maximumCostCNY
        self.maximumElapsedSeconds = maximumElapsedSeconds
    }
}

public enum BudgetDecision: Equatable, Sendable {
    case proceed
    case pauseForApproval(reasons: Set<BudgetExceededReason>)
}

public enum BudgetExceededReason: String, Codable, Hashable, Sendable {
    case cost
    case elapsedTime
    case invalidUsage
    case invalidLimit
}

public struct BudgetGuard: Sendable {
    public init() {}

    public func evaluate(_ usage: UsageRecord, against limit: BudgetLimit) -> BudgetDecision {
        var reasons: Set<BudgetExceededReason> = []
        if usage.inputTokens < 0 || usage.outputTokens < 0 ||
            usage.estimatedCostCNY.isNaN || usage.estimatedCostCNY < 0 ||
            usage.elapsedSeconds < 0 || !usage.elapsedSeconds.isFinite {
            reasons.insert(.invalidUsage)
        }
        if limit.maximumCostCNY.isNaN || limit.maximumCostCNY < 0 ||
            limit.maximumElapsedSeconds < 0 || !limit.maximumElapsedSeconds.isFinite {
            reasons.insert(.invalidLimit)
        }
        if !usage.estimatedCostCNY.isNaN && !limit.maximumCostCNY.isNaN &&
            usage.estimatedCostCNY > limit.maximumCostCNY {
            reasons.insert(.cost)
        }
        if usage.elapsedSeconds > limit.maximumElapsedSeconds { reasons.insert(.elapsedTime) }
        return reasons.isEmpty ? .proceed : .pauseForApproval(reasons: reasons)
    }
}
