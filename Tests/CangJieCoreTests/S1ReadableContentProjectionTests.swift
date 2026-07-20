import XCTest
@testable import CangJieCore

final class S1ReadableContentProjectionTests: XCTestCase {
    private let conversationID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let projectID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let chapterLogicalID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    private let versionID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    func testSelectsCommittedActiveChapterBoundToSelectedConversationAndFocusedProject() {
        let projection = S1ReadableContentProjection.select(
            selectedConversationID: conversationID,
            focusedProjectID: projectID,
            candidate: candidate()
        )

        XCTAssertEqual(
            projection,
            S1ReadableContentProjection(
                conversationID: conversationID,
                projectID: projectID,
                chapterLogicalID: chapterLogicalID,
                activeVersionID: versionID,
                projectTitle: "雾城守夜人",
                chapterNumber: 1,
                chapterTitle: "第一章 山门夜响",
                body: "雨落在石阶上。\n\n封闭十年的山门忽然响了三声。",
                status: .waitingForReview
            )
        )
        XCTAssertEqual(projection?.statusDescription, "这一章正在等你阅读")
    }

    func testFailsClosedWithoutExactConversationAndProjectBindings() {
        XCTAssertNil(
            S1ReadableContentProjection.select(
                selectedConversationID: nil,
                focusedProjectID: projectID,
                candidate: candidate()
            )
        )
        XCTAssertNil(
            S1ReadableContentProjection.select(
                selectedConversationID: UUID(),
                focusedProjectID: projectID,
                candidate: candidate()
            )
        )
        XCTAssertNil(
            S1ReadableContentProjection.select(
                selectedConversationID: conversationID,
                focusedProjectID: UUID(),
                candidate: candidate()
            )
        )
    }

    func testFailsClosedForPartialInactiveEmptyOrHashMismatchedContent() {
        XCTAssertNil(select(candidate(isCommitted: false)))
        XCTAssertNil(select(candidate(activeVersionID: UUID())))
        XCTAssertNil(select(candidate(body: " \n ")))
        XCTAssertNil(select(candidate(storedContentHash: "wrong")))
        XCTAssertNil(select(candidate(calculatedContentHash: "wrong")))
    }

    func testMapsEveryKnownStageToOrdinaryLanguage() {
        let expectations: [(ChapterCalibrationStage, S1ReadableContentStatus, String)] = [
            (.notStarted, .preparing, "这一章还没有准备好"),
            (.reviewingV1, .waitingForReview, "这一章正在等你阅读"),
            (.diagnosing, .understandingFeedback, "仓颉正在理解你对这一章的感觉"),
            (.awaitingRewriteConfirmation, .waitingForChangeDecision, "修改方向正在等你确认"),
            (.rewriting, .updating, "仓颉正在调整这一章"),
            (.reviewingV2, .revisedWaitingForReview, "修改后的章节正在等你阅读"),
            (.approvedFrozen, .approved, "这一章已经按你的决定保存")
        ]

        for (stage, status, description) in expectations {
            let projection = select(candidate(stage: stage))
            XCTAssertEqual(projection?.status, status)
            XCTAssertEqual(projection?.statusDescription, description)
        }
    }

    private func select(_ candidate: S1ReadableContentCandidate) -> S1ReadableContentProjection? {
        S1ReadableContentProjection.select(
            selectedConversationID: conversationID,
            focusedProjectID: projectID,
            candidate: candidate
        )
    }

    private func candidate(
        activeVersionID: UUID? = nil,
        body: String = "雨落在石阶上。\n\n封闭十年的山门忽然响了三声。",
        storedContentHash: String = "hash",
        calculatedContentHash: String = "hash",
        stage: ChapterCalibrationStage = .reviewingV1,
        isCommitted: Bool = true
    ) -> S1ReadableContentCandidate {
        S1ReadableContentCandidate(
            conversationID: conversationID,
            projectID: projectID,
            chapterLogicalID: chapterLogicalID,
            activeVersionID: activeVersionID ?? versionID,
            versionID: versionID,
            projectTitle: "雾城守夜人",
            chapterNumber: 1,
            chapterTitle: "第一章 山门夜响",
            body: body,
            storedContentHash: storedContentHash,
            calculatedContentHash: calculatedContentHash,
            stage: stage,
            isCommitted: isCommitted
        )
    }
}