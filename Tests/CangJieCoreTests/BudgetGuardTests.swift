import XCTest
@testable import CangJieCore

final class BudgetGuardTests: XCTestCase {
    func testUsageWithinLimitProceeds() {
        let usage = UsageRecord(inputTokens: 1_000, outputTokens: 2_000, estimatedCostCNY: 12, elapsedSeconds: 900)
        let limit = BudgetLimit(maximumCostCNY: 20, maximumElapsedSeconds: 1_200)
        XCTAssertEqual(BudgetGuard().evaluate(usage, against: limit), .proceed)
    }

    func testCostAndTimeOverrunRequiresApproval() {
        let usage = UsageRecord(inputTokens: 10_000, outputTokens: 12_000, estimatedCostCNY: 21, elapsedSeconds: 1_201)
        let limit = BudgetLimit(maximumCostCNY: 20, maximumElapsedSeconds: 1_200)
        XCTAssertEqual(BudgetGuard().evaluate(usage, against: limit), .pauseForApproval(reasons: [.cost, .elapsedTime]))
    }

    func testInvalidUsageAndLimitsPauseInsteadOfProceeding() {
        let usage = UsageRecord(inputTokens: -1, outputTokens: 0, estimatedCostCNY: 0, elapsedSeconds: .infinity)
        let limit = BudgetLimit(maximumCostCNY: -1, maximumElapsedSeconds: -1)
        XCTAssertEqual(
            BudgetGuard().evaluate(usage, against: limit),
            .pauseForApproval(reasons: [.invalidUsage, .invalidLimit, .cost, .elapsedTime])
        )
    }

    func testNaNCostUsageFailsClosed() {
        let usage = UsageRecord(
            inputTokens: 1,
            outputTokens: 1,
            estimatedCostCNY: .nan,
            elapsedSeconds: 1
        )
        let limit = BudgetLimit(maximumCostCNY: 10, maximumElapsedSeconds: 10)

        XCTAssertEqual(
            BudgetGuard().evaluate(usage, against: limit),
            .pauseForApproval(reasons: [.invalidUsage])
        )
    }

    func testNaNCostLimitFailsClosed() {
        let usage = UsageRecord(inputTokens: 1, outputTokens: 1, estimatedCostCNY: 1, elapsedSeconds: 1)
        let limit = BudgetLimit(maximumCostCNY: .nan, maximumElapsedSeconds: 10)

        XCTAssertEqual(
            BudgetGuard().evaluate(usage, against: limit),
            .pauseForApproval(reasons: [.invalidLimit])
        )
    }
}
