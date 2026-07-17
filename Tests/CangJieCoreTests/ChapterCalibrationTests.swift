import XCTest
@testable import CangJieCore

final class ChapterCalibrationTests: XCTestCase {
    func testFullRejectionRewriteAndAcceptancePath() throws {
        let initial = ChapterCalibrationMachine(stage: .notStarted)
        let reviewingV1 = try initial.applying(.generateV1)
        let diagnosing = try reviewingV1.applying(.reject)
        let awaitingScope = try diagnosing.applying(.completeDiagnosis)
        let rewriting = try awaitingScope.applying(.confirmRewrite)
        let reviewingV2 = try rewriting.applying(.presentV2)
        let frozen = try reviewingV2.applying(.accept)

        XCTAssertEqual(frozen.stage, .approvedFrozen)
    }


    func testReviewingV2CannotBeRejectedAgain() throws {
        let reviewingV2 = ChapterCalibrationMachine(stage: .reviewingV2)

        XCTAssertThrowsError(try reviewingV2.applying(.reject)) { error in
            XCTAssertEqual(
                error as? ChapterCalibrationError,
                .invalidTransition(from: .reviewingV2, action: .reject)
            )
        }
    }

    func testProtectedParagraphBytesUseTheSameVisibleIndexesWithOuterBlankLines() {
        let body = "\n\nA\r\n\r\nB\r\r"

        XCTAssertEqual(ChapterContentIntegrity.paragraphs(in: body), ["A", "B"])
        XCTAssertEqual(
            ChapterContentIntegrity.protectedParagraphBytes(in: body).map { String(decoding: $0, as: UTF8.self) },
            ["A\r\n\r\n", "B\r\r"]
        )
    }

    func testV1CanBeAcceptedWithoutRewrite() throws {
        let reviewing = try ChapterCalibrationMachine(stage: .notStarted).applying(.generateV1)
        XCTAssertEqual(try reviewing.applying(.accept).stage, .approvedFrozen)
    }

    func testInvalidTransitionFailsClosed() throws {
        XCTAssertThrowsError(try ChapterCalibrationMachine(stage: .notStarted).applying(.accept)) { error in
            XCTAssertEqual(
                error as? ChapterCalibrationError,
                .invalidTransition(from: .notStarted, action: .accept)
            )
        }
    }

    func testLockedParagraphsMustRemainByteEquivalentAtTheSameIndexes() throws {
        let original = "First paragraph.\n\nKeep this paragraph exactly.\n\nOld ending."
        let revised = "Rewritten first paragraph.\n\nKeep this paragraph exactly.\n\nNew ending."

        XCTAssertNoThrow(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: original,
                revisedBody: revised,
                lockedParagraphIndexes: [1]
            )
        )
    }

    func testChangedLockedParagraphFailsClosed() throws {
        XCTAssertThrowsError(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: "A\n\nB\n\nC",
                revisedBody: "A\n\nChanged B\n\nC",
                lockedParagraphIndexes: [1]
            )
        ) { error in
            XCTAssertEqual(error as? ChapterCalibrationError, .lockedContentChanged(index: 1))
        }
    }

    func testLockedParagraphWhitespaceChangeFailsClosed() throws {
        XCTAssertThrowsError(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: "A\n\nKeep exactly. \n\nC",
                revisedBody: "A\n\nKeep exactly.\n\nC",
                lockedParagraphIndexes: [1]
            )
        ) { error in
            XCTAssertEqual(error as? ChapterCalibrationError, .lockedContentChanged(index: 1))
        }
    }

    func testLockedParagraphLineEndingChangeFailsClosed() throws {
        XCTAssertThrowsError(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: "A\r\n\r\nKeep\r\nline\r\n\r\nC",
                revisedBody: "A\n\nKeep\nline\n\nC",
                lockedParagraphIndexes: [1]
            )
        ) { error in
            XCTAssertEqual(error as? ChapterCalibrationError, .lockedContentChanged(index: 1))
        }
    }

    func testLockedParagraphSeparatorLineEndingChangeFailsClosed() throws {
        XCTAssertThrowsError(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: "LOCKED\r\n\r\nunlocked",
                revisedBody: "LOCKED\n\nunlocked",
                lockedParagraphIndexes: [0]
            )
        ) { error in
            XCTAssertEqual(error as? ChapterCalibrationError, .lockedContentChanged(index: 0))
        }
    }

    func testOutOfRangeLockFailsClosed() throws {
        XCTAssertThrowsError(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: "Only one",
                revisedBody: "Only one",
                lockedParagraphIndexes: [2]
            )
        ) { error in
            XCTAssertEqual(error as? ChapterCalibrationError, .invalidLockedParagraphIndex(2))
        }
    }

    func testParagraphDiffReportsChangedIndexes() {
        let diff = ChapterContentIntegrity.diff(
            originalBody: "A\n\nB\n\nC",
            revisedBody: "A\n\nNew B\n\nC\n\nD"
        )

        XCTAssertEqual(diff.changedParagraphIndexes, [1, 3])
        XCTAssertEqual(diff.unchangedParagraphIndexes, [0, 2])
    }

    func testRewritingParagraphsPreservesOriginalSeparatorsAndLockedContent() throws {
        let original = "Locked A\r\n\r\nOld middle\n\nLocked C"
        let revised = ChapterContentIntegrity.rewritingParagraphs(in: original) { index, paragraph in
            index == 1 ? "New middle" : paragraph
        }

        XCTAssertEqual(revised, "Locked A\r\n\r\nNew middle\n\nLocked C")
        XCTAssertNoThrow(
            try ChapterContentIntegrity.validateLockedParagraphs(
                originalBody: original,
                revisedBody: revised,
                lockedParagraphIndexes: [0, 2]
            )
        )
    }
}
