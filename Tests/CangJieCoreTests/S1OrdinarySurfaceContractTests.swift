import Foundation
import XCTest
@testable import CangJieCore

final class S1OrdinarySurfaceContractTests: XCTestCase {
    func testProgressStatesUsePlainChineseWithoutEngineeringDetails() {
        let expectations: [(S1OrdinaryProgress, String)] = [
            (.waitingForIdea, "等你说说想写什么"),
            (.understandingIdea, "正在和你一起想清楚"),
            (.waitingForOpeningPlan, "等你确认开篇方向"),
            (.openingPlanChanged, "开篇方向有变化，需要重新看看"),
            (.openingPlanExpired, "开篇方向需要重新确认"),
            (.openingPlanApproved, "开篇方向已确认，准备第一章"),
            (.chapterReady, "可以开始准备第一章"),
            (.reviewingChapter, "等你看看第一章"),
            (.understandingChapterFeedback, "正在理解第一章哪里不对"),
            (.waitingForRewritePlan, "等你确认准备怎么改"),
            (.rewritingChapter, "正在按确认的方向修改"),
            (.chapterApproved, "第一章已经确认")
        ]

        for (progress, expected) in expectations {
            XCTAssertEqual(S1OrdinarySurfaceContract.progressDescription(progress), expected)
            for term in S1OrdinarySurfaceContract.forbiddenEngineeringTerms {
                XCTAssertFalse(expected.localizedCaseInsensitiveContains(term), "\(expected) leaked \(term)")
            }
        }
    }

    func testChapterStagesUsePlainChineseInsteadOfInternalRawValues() {
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.notStarted), "还没有开始")
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.reviewingV1), "等你看看第一版")
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.diagnosing), "正在理解哪里不对")
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.awaitingRewriteConfirmation), "等你确认准备怎么改")
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.rewriting), "正在按确认的方向修改")
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.reviewingV2), "等你看看修改版")
        XCTAssertEqual(S1OrdinarySurfaceContract.chapterStageDescription(.approvedFrozen), "已经确认")
    }

    func testParagraphSummariesAreReadableOneBasedAndStable() {
        XCTAssertEqual(S1OrdinarySurfaceContract.protectedParagraphsDescription([]), "还没有保留不动的段落")
        XCTAssertEqual(S1OrdinarySurfaceContract.protectedParagraphsDescription([2, 0, 2, -1]), "第 1、3 段会保留不动")
        XCTAssertEqual(S1OrdinarySurfaceContract.changedParagraphsDescription([]), "和上一版相比没有正文变化")
        XCTAssertEqual(S1OrdinarySurfaceContract.changedParagraphsDescription([3, 1, 1]), "和上一版相比，改了第 2、4 段")
    }

    func testOrdinaryReviewCopyDoesNotContainEngineeringTerms() {
        let ordinaryCopy = S1OrdinarySurfaceContract.ordinaryReviewCopy
        let forbidden = S1OrdinarySurfaceContract.forbiddenEngineeringTerms

        XCTAssertFalse(ordinaryCopy.isEmpty)
        for text in ordinaryCopy {
            XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            for term in forbidden {
                XCTAssertFalse(text.localizedCaseInsensitiveContains(term), "\(text) leaked \(term)")
            }
        }
    }

    func testEngineeringDiagnosticsAreProjectedToPlainUserFacingErrors() {
        let expectations = [
            ("SQLite initialization failed (DB-INIT)", "暂时无法打开本地内容，请重新打开仓颉后再试"),
            ("Project reader failed (DB-PROJECT-READER)", "这次操作没有完成，请稍后再试"),
            ("Draft autosave failed (DB-DRAFT-AUTOSAVE)", "草稿暂时无法保存，请稍后再试"),
            ("Displayed approval is no longer current (AGENT-APPROVAL-STALE)", "这个开篇方向已经发生变化，请重新打开最新内容"),
            ("Chapter acceptance was not confirmed by the persisted projection (CHAPTER-PROJECTION)", "这次章节操作没有完成，请稍后再试"),
            ("Keychain unavailable (KEY-READ)", "本机安全存储暂时不可用，请稍后再试")
        ]

        for (diagnostic, expected) in expectations {
            let projected = S1OrdinarySurfaceContract.errorDescription(for: diagnostic)
            XCTAssertEqual(projected, expected)
            XCTAssertFalse(projected.contains("DB-"))
            XCTAssertFalse(projected.contains("KEY-"))
            XCTAssertFalse(projected.localizedCaseInsensitiveContains("revision"))
            XCTAssertFalse(projected.localizedCaseInsensitiveContains("projection"))
        }
    }

    func testEngineeringStorageAndNetworkNoticesAreProjectedToPlainCopy() {
        let expectations = [
            ("Restored checkpoint #7", "已恢复上次安全保存的内容"),
            ("SQLite ready; no checkpoint yet", "本地内容已准备好"),
            ("Draft saved | 12:30:00", "草稿已保存"),
            ("Draft protected by checkpoint #8 (background)", "当前内容已安全保存"),
            ("Connecting to HTTPS SSE...", "正在检查网络连接…")
        ]

        for (diagnostic, expected) in expectations {
            let projected = S1OrdinarySurfaceContract.noticeDescription(for: diagnostic)
            XCTAssertEqual(projected, expected)
            XCTAssertFalse(projected.localizedCaseInsensitiveContains("checkpoint"))
            XCTAssertFalse(projected.localizedCaseInsensitiveContains("SQLite"))
            XCTAssertFalse(projected.localizedCaseInsensitiveContains("SSE"))
        }
    }

}
