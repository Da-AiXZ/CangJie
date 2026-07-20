import XCTest
@testable import CangJieCore

final class S1ActivityBarContractTests: XCTestCase {
    func testVisibleItemsAreOnlyTheFourHonestS1DestinationsInStableOrder() {
        XCTAssertEqual(
            S1ActivityBarContract.visibleItems.map(\.destination),
            [.conversation, .novels, .tasks, .settings]
        )
        XCTAssertEqual(Set(S1ActivityBarContract.visibleItems.map(\.destination)).count, 4)
    }

    func testEveryVisibleItemHasAPlainLanguageNamePurposeAndDistinctIconRole() {
        let items = S1ActivityBarContract.visibleItems

        XCTAssertTrue(items.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertTrue(items.allSatisfy { !$0.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        XCTAssertEqual(Set(items.map(\.iconRole)).count, items.count)
        XCTAssertEqual(items.first(where: { $0.destination == .tasks })?.title, "AI 任务")
        XCTAssertEqual(items.first(where: { $0.destination == .settings })?.title, "设置")
    }

    func testLegacyEngineeringAndUnavailableProductEntriesAreNotDestinations() {
        let rawValues = Set(S1ActivityDestination.allCases.map(\.rawValue))

        XCTAssertFalse(rawValues.contains("workbenches"))
        XCTAssertFalse(rawValues.contains("research"))
        XCTAssertFalse(rawValues.contains("deviceDiagnostics"))
        XCTAssertFalse(rawValues.contains("buildIdentity"))
        XCTAssertFalse(rawValues.contains("materials"))
    }
}
