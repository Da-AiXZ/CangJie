import XCTest
@testable import CangJieCore

final class AgentRuntimeOrdinaryCopyTests: XCTestCase {
    func testNormalRecoveryAndReplayUseTheSameOrdinaryChapterCopy() {
        let expectedReady = "第一章已经准备好了。你可以先看看；满意就说“这一章就这样”，不满意直接告诉我哪里不对。"
        let expectedConfirmed = "第一章已经确认。我会保留当前内容，后面继续写时以这一版为准。"

        for delivery in AgentRuntimeOrdinaryCopy.Delivery.allCases {
            XCTAssertEqual(AgentRuntimeOrdinaryCopy.firstChapterReady(delivery: delivery), expectedReady)
            XCTAssertEqual(AgentRuntimeOrdinaryCopy.chapterConfirmed(delivery: delivery), expectedConfirmed)
        }
    }

    func testRewritePlanKeepsUserMeaningButHidesGovernanceMetadata() {
        let summary = """
        Chapter 1 rejection diagnosis
        Root cause: 主角的反应太快
        Must preserve: 山崖上的对话
        Required ending effect: 让读者担心他会失去师父
        Locked paragraph indexes: 1, 3
        """
        let scope = """
        Rewrite only Chapter 1 revision 1.
        Source version: 11111111-1111-1111-1111-111111111111
        Source hash: deadbeef
        Apply the confirmed diagnosis below without changing locked paragraphs or silently adding canon:
        \(summary)
        """

        let copy = AgentRuntimeOrdinaryCopy.rewritePlan(summary: summary, scope: scope)

        XCTAssertTrue(copy.contains("主角的反应太快"))
        XCTAssertTrue(copy.contains("山崖上的对话"))
        XCTAssertTrue(copy.contains("让读者担心他会失去师父"))
        XCTAssertTrue(copy.contains("第 1、3 段"))
        XCTAssertFalse(copy.contains("11111111-1111-1111-1111-111111111111"))
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("deadbeef"))
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("revision"))
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("hash"))
        XCTAssertFalse(copy.localizedCaseInsensitiveContains("canon"))
    }

    func testOrdinaryCopyNeverLeaksEngineeringVocabularyOrEnglishInternalStatus() {
        let samples = AgentRuntimeOrdinaryCopy.contractSamples
        let forbidden = [
            "revision", "binding", "hash", "receipt", "exact rewrite scope", "v1", "v2", "diff",
            "idempotent", "replay", "recovered", "verified:", "completed", "approvedfrozen",
            "哈希", "工具回执", "幂等", "精确重写范围"
        ]

        XCTAssertFalse(samples.isEmpty)
        for sample in samples {
            for token in forbidden {
                XCTAssertFalse(
                    sample.localizedCaseInsensitiveContains(token),
                    "Ordinary copy leaked forbidden token '\(token)': \(sample)"
                )
            }
        }
    }

    func testHistoricalCanonicalAssistantMessagesProjectToOrdinaryCopyWithoutChangingStorageText() {
        let historicalMessages = [
            AgentRuntimeCanonicalMessage.openingPlanConfirmed,
            AgentRuntimeCanonicalMessage.firstChapterReady,
            AgentRuntimeCanonicalMessage.rewrittenChapterReady(revision: 2),
            AgentRuntimeCanonicalMessage.chapterConfirmed(revision: 2)
        ]

        let projected = historicalMessages.map(AgentRuntimeOrdinaryCopy.projectPersistedAssistantMessage)

        XCTAssertEqual(projected[0], AgentRuntimeOrdinaryCopy.openingPlanConfirmed(delivery: .normal))
        XCTAssertEqual(projected[1], AgentRuntimeOrdinaryCopy.firstChapterReady(delivery: .normal))
        XCTAssertEqual(projected[2], AgentRuntimeOrdinaryCopy.rewrittenChapterReady(delivery: .normal))
        XCTAssertEqual(projected[3], AgentRuntimeOrdinaryCopy.chapterConfirmed(delivery: .normal))
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.openingPlanConfirmed,
            "Opening plan approved and persisted. Chapter planning is now unlocked."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterPlanningUnlocked,
            "Chapter planning is unlocked. Say \u{2018}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019}, \u{2018}\u{5F00}\u{59CB}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019}, \u{2018}\u{7EE7}\u{7EED}\u{2019}, or \u{2018}generate chapter\u{2019} to begin the governed Chapter 1 calibration."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterGenerationReady,
            "Chapter 1 is ready to generate when you say \u{2018}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019} or \u{2018}\u{7EE7}\u{7EED}\u{2019}."
        )
        XCTAssertEqual(
            AgentRuntimeOrdinaryCopy.projectPersistedAssistantMessage(
                "Chapter planning is unlocked. Say \u{2018}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019}, \u{2018}\u{5F00}\u{59CB}\u{751F}\u{6210}\u{7B2C}\u{4E00}\u{7AE0}\u{2019}, \u{2018}\u{7EE7}\u{7EED}\u{2019}, or \u{2018}generate chapter\u{2019} to begin the governed Chapter 1 calibration."
            ),
            AgentRuntimeOrdinaryCopy.chapterGenerationReady
        )
    }

    func testCanonicalStorageCopyMatchesThePreProjectionRuntimeContract() {
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.strategicQuestions,
            [
                "What is the one-sentence hook that makes this novel impossible to confuse with another?",
                "Who is the protagonist before the first major change, and what do they want right now?",
                "What concrete cost or danger makes the first victory matter?"
            ]
        )
        XCTAssertEqual(AgentRuntimeCanonicalMessage.projectCreated(title: "Legacy"), "Project created: Legacy")
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.openingPlanAwaitingConfirmation,
            "The opening plan is waiting for your exact approval. Review the bound revision, budget, expiration, and expected change before we continue."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.openingPlanPrepared,
            "I have compiled the opening plan. Review its exact approval card before chapter planning."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterReviewReminder(revision: 2),
            "Review Chapter 1 revision 2. You may accept and freeze it, or reject it and enter diagnosis. I will not reroll it without a diagnosis."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.rewriteConfirmationRequired,
            "The diagnosis and exact rewrite scope are ready. Confirm that scope before I create revision 2; a generic regenerate request will not bypass this gate."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.approvedChapterAudit(revision: 2),
            "Chapter 1 revision 2 is approved and frozen. Its versions, diagnosis, and tool receipts remain available for audit."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.firstChapterReady,
            "Chapter 1 revision 1 has been generated and evidence-reviewed. Review the exact revision, then accept and freeze it or reject it for diagnosis."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.diagnosisStarted(question: "Question"),
            "I will not reroll the chapter. We will diagnose it one high-information question at a time.\n\nQuestion"
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.diagnosisNeedsMoreDetail(question: "Question"),
            "A direct reroll would hide the root cause and is not allowed. Please answer the current diagnosis question with one concrete observation:\n\nQuestion"
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.diagnosisComplete(summary: "Summary", scope: "Scope"),
            "Diagnosis complete. Review the exact rewrite scope before revision 2 is created.\n\nSummary\n\nRewrite scope:\nScope\n\nSay \u{2018}\u{786E}\u{8BA4}\u{91CD}\u{5199}\u{2019} to authorize only this scope."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.rewrittenChapterReady(revision: 2),
            "Chapter 1 revision 2 is ready. Locked paragraphs were verified byte-for-byte. Review the V1/V2 diff, then accept and freeze this final calibration candidate."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterConfirmed(revision: 2),
            "Chapter 1 revision 2 is approved and frozen. The exact content hash, version history, and receipts have been preserved."
        )
        XCTAssertEqual(AgentRuntimeCanonicalMessage.chapterStatusNotStarted, "Chapter 1 has not started.")
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterStatusReviewing(revision: 2),
            "Chapter 1 revision 2 is waiting for your review."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterStatusDiagnosing(question: 2, total: 3),
            "Chapter 1 is in diagnosis question 2 of 3."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterStatusAwaitingRewriteConfirmation,
            "The diagnosis is complete and the exact rewrite scope is waiting for confirmation."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterStatusRewriting,
            "The confirmed Chapter 1 rewrite is resumable from its idempotent tool binding."
        )
        XCTAssertEqual(
            AgentRuntimeCanonicalMessage.chapterStatusConfirmed(revision: 2),
            "Chapter 1 revision 2 is approved and frozen."
        )
    }

    func testHistoricalDynamicCanonicalMessagesHideGovernanceMetadataButPreserveMeaning() {
        let diagnosis = AgentRuntimeCanonicalMessage.diagnosisComplete(
            summary: "Root cause: 主角反应太快\nMust preserve: 山崖上的对话\nRequired ending effect: 担心师父\nLocked paragraph indexes: 1, 3",
            scope: "Rewrite only Chapter 1 revision 1.\nSource hash: deadbeef"
        )
        let historicalMessages = [
            AgentRuntimeCanonicalMessage.projectCreated(title: "未命名小说"),
            AgentRuntimeCanonicalMessage.chapterReviewReminder(revision: 1),
            diagnosis,
            AgentRuntimeCanonicalMessage.chapterStatusRewriting
        ]

        let projected = historicalMessages.map(AgentRuntimeOrdinaryCopy.projectPersistedAssistantMessage)
        let forbidden = ["revision", "receipt", "binding", "hash", "verified:", "v1", "v2", "idempotent"]

        XCTAssertTrue(projected[0].contains("未命名小说"))
        XCTAssertTrue(projected[1].contains("第一章"))
        XCTAssertTrue(projected[2].contains("主角反应太快"))
        XCTAssertTrue(projected[2].contains("山崖上的对话"))
        XCTAssertTrue(projected[2].contains("担心师父"))
        for message in projected {
            for token in forbidden {
                XCTAssertFalse(message.localizedCaseInsensitiveContains(token), "Projected copy leaked \(token): \(message)")
            }
        }
    }

    func testUnknownAssistantContentAndFixedPreviewReceiptAreNotRewritten() {
        let unknown = "这是一段用户需要原样看到的普通回复。"
        let fixedReceipt = "界面预览版：这句话已保存。当前只验证界面和导航，真正的模型对话从 S2 接入。"

        XCTAssertEqual(AgentRuntimeOrdinaryCopy.projectPersistedAssistantMessage(unknown), unknown)
        XCTAssertEqual(AgentRuntimeOrdinaryCopy.projectPersistedAssistantMessage(fixedReceipt), fixedReceipt)
    }

    func testChapterStatusUsesReaderLanguageInsteadOfRuntimeStageNames() {
        XCTAssertEqual(
            AgentRuntimeOrdinaryCopy.chapterStatus(.diagnosing(question: 2, total: 3)),
            "我正在理解第一章哪里不对，目前还需要你回答第 2 个问题，共 3 个。"
        )
        XCTAssertFalse(
            AgentRuntimeOrdinaryCopy.chapterStatus(.rewriting).localizedCaseInsensitiveContains("rewriting")
        )
    }
}
