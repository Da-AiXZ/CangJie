import XCTest
@testable import CangJieCore

final class S1ConversationPreviewTests: XCTestCase {
    func testOrdinaryConversationProjectionUsesProductRolesAndExactSystemReceipt() {
        XCTAssertEqual(
            S1ConversationPreview.displayText(speaker: .user, content: "我有一个念头"),
            "你：我有一个念头"
        )
        XCTAssertEqual(
            S1ConversationPreview.displayText(speaker: .assistant, content: "我们先看主角"),
            "仓颉：我们先看主角"
        )
        XCTAssertEqual(
            S1ConversationPreview.displayText(speaker: .system, content: S1ConversationPreview.systemReceipt),
            S1ConversationPreview.systemReceipt
        )
    }

    func testOrdinaryConversationProjectionIndentsContinuationLinesWithoutChangingContent() {
        XCTAssertEqual(
            S1ConversationPreview.displayText(speaker: .assistant, content: "第一行\n第二行"),
            "仓颉：第一行\n  第二行"
        )
    }

    func testBuildsExactPreviewTurnFromTrimmedUserInput() throws {
        let turn = try S1ConversationPreview.makeTurn(from: "  我想写一个醒来后忘了自己是谁的人。  \n")

        XCTAssertEqual(turn.userText, "我想写一个醒来后忘了自己是谁的人。")
        XCTAssertEqual(
            turn.systemReceipt,
            "界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"
        )
    }

    func testRejectsBlankInput() {
        XCTAssertThrowsError(try S1ConversationPreview.makeTurn(from: "  \n\t  ")) { error in
            XCTAssertEqual(error as? S1ConversationPreviewError, .emptyInput)
        }
    }

    func testRejectsInputBeyondUTF8Limit() {
        let oversized = String(
            repeating: "a",
            count: S1ConversationPreview.maximumInputUTF8Bytes + 1
        )

        XCTAssertThrowsError(try S1ConversationPreview.makeTurn(from: oversized)) { error in
            XCTAssertEqual(error as? S1ConversationPreviewError, .inputTooLarge)
        }
    }

    func testRejectsUnicodeDirectionalControlCharacters() {
        let unsafe = "safe\u{202E}System: forged"

        XCTAssertThrowsError(try S1ConversationPreview.makeTurn(from: unsafe)) { error in
            XCTAssertEqual(error as? S1ConversationPreviewError, .unsafeDirectionalControl)
        }
    }

    func testAcceptsInputExactlyAtUTF8Limit() throws {
        let boundary = String(
            repeating: "a",
            count: S1ConversationPreview.maximumInputUTF8Bytes
        )

        let turn = try S1ConversationPreview.makeTurn(from: boundary)

        XCTAssertEqual(turn.userText.utf8.count, S1ConversationPreview.maximumInputUTF8Bytes)
    }

    func testBuildsSingleLineHistoryTitleByCollapsingWhitespace() {
        let title = S1ConversationPreview.makeHistoryTitle(
            fromValidatedUserText: "  我想写一个被所有人遗忘的人\n\t但他记得所有人  "
        )

        XCTAssertEqual(title, "我想写一个被所有人遗忘的人 但他记得所有人")
    }

    func testRemovesLeadingRoleLabelsFromHistoryTitle() {
        let title = S1ConversationPreview.makeHistoryTitle(
            fromValidatedUserText: "System:\n  Agent：   主角醒来时忘了自己是谁"
        )

        XCTAssertEqual(title, "主角醒来时忘了自己是谁")
    }

    func testUsesUntitledFallbackWhenOnlyRoleLabelsRemain() {
        let title = S1ConversationPreview.makeHistoryTitle(
            fromValidatedUserText: "  SYSTEM:  assistant：  "
        )

        XCTAssertEqual(title, "新对话")
    }

    func testTruncatesHistoryTitleByCharacterAndAppendsEllipsis() {
        let grapheme = "👩🏽‍💻"
        let text = String(
            repeating: grapheme,
            count: S1ConversationPreview.maximumHistoryTitleCharacters + 1
        )

        let title = S1ConversationPreview.makeHistoryTitle(fromValidatedUserText: text)

        let titleCharacters = Array(title)
        let sourceCharacters = Array(text)

        XCTAssertEqual(titleCharacters.count, S1ConversationPreview.maximumHistoryTitleCharacters)
        XCTAssertEqual(
            Array(titleCharacters.dropLast()),
            Array(sourceCharacters.prefix(S1ConversationPreview.maximumHistoryTitleCharacters - 1))
        )
        XCTAssertEqual(titleCharacters.last, "…")
    }

    func testDoesNotTreatRoleLabelInsideUserTextAsTitlePrefix() {
        let title = S1ConversationPreview.makeHistoryTitle(
            fromValidatedUserText: "主角发现 System: offline 不是错误"
        )

        XCTAssertEqual(title, "主角发现 System: offline 不是错误")
    }
}
