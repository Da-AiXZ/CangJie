import XCTest
@testable import CangJie

final class ChapterAuditEquivalenceTests: XCTestCase {
    func testAuditEquivalenceAllowsOnlyAdjacentTimestampRepresentation() {
        let timestamp = Date(timeIntervalSinceReferenceDate: 123_456.789)
        let calibration = makeCalibration(updatedAt: timestamp)
        let adjacent = makeCalibration(
            updatedAt: Date(timeIntervalSinceReferenceDate: timestamp.timeIntervalSinceReferenceDate.nextUp)
        )
        let nonAdjacent = makeCalibration(
            updatedAt: Date(
                timeIntervalSinceReferenceDate: timestamp.timeIntervalSinceReferenceDate.nextUp.nextUp
            )
        )

        XCTAssertTrue(calibration.isAuditEquivalent(to: adjacent))
        XCTAssertFalse(calibration.isAuditEquivalent(to: nonAdjacent))
    }

    func testAuditEquivalenceStillRejectsBusinessStateChanges() {
        let timestamp = Date(timeIntervalSinceReferenceDate: 123_456.789)
        let calibration = makeCalibration(updatedAt: timestamp)
        let changed = ChapterCalibration(
            chapterLogicalID: calibration.chapterLogicalID,
            conversationID: calibration.conversationID,
            projectID: calibration.projectID,
            chapterNumber: calibration.chapterNumber,
            activeVersionID: calibration.activeVersionID,
            stage: .diagnosing,
            diagnosisEntries: calibration.diagnosisEntries,
            diagnosisHash: calibration.diagnosisHash,
            rejectionHistory: calibration.rejectionHistory,
            lockedParagraphIndexes: calibration.lockedParagraphIndexes,
            rewriteScope: calibration.rewriteScope,
            rewriteScopeHash: calibration.rewriteScopeHash,
            acceptedVersionID: calibration.acceptedVersionID,
            updatedAt: timestamp
        )

        XCTAssertFalse(calibration.isAuditEquivalent(to: changed))
    }

    private func makeCalibration(updatedAt: Date) -> ChapterCalibration {
        ChapterCalibration(
            chapterLogicalID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            conversationID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            projectID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            chapterNumber: 1,
            activeVersionID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            stage: .reviewingV1,
            diagnosisEntries: [],
            diagnosisHash: ChapterFingerprint.diagnosisHash([]),
            rejectionHistory: [],
            lockedParagraphIndexes: [],
            rewriteScope: nil,
            rewriteScopeHash: nil,
            acceptedVersionID: nil,
            updatedAt: updatedAt
        )
    }
}
