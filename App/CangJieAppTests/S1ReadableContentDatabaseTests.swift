import CangJieCore
import GRDB
import XCTest
@testable import CangJie

final class S1ReadableContentDatabaseTests: XCTestCase {
    func testRestoresOnlyCommittedHashValidActiveChapterForSelectedConversationFocus() throws {
        try withDatabase { database in
            let seeded = try seedReadableContent(in: database)

            let projection = try database.restoreS1ReadableContent(
                selectedConversationID: seeded.conversationID
            )

            XCTAssertEqual(projection?.conversationID, seeded.conversationID)
            XCTAssertEqual(projection?.projectID, seeded.projectID)
            XCTAssertEqual(projection?.chapterLogicalID, seeded.chapterLogicalID)
            XCTAssertEqual(projection?.activeVersionID, seeded.versionID)
            XCTAssertEqual(projection?.projectTitle, "雾城守夜人")
            XCTAssertEqual(projection?.chapterTitle, "第一章 山门夜响")
            XCTAssertEqual(projection?.body, seeded.body)
            XCTAssertEqual(projection?.statusDescription, "这一章正在等你阅读")
        }
    }

    func testFailsClosedWithoutSelectionFocusCalibrationOrValidHash() throws {
        try withDatabase { database in
            XCTAssertNil(try database.restoreS1ReadableContent(selectedConversationID: nil))

            let conversation = try createConversation(in: database, message: "只有对话")
            XCTAssertNil(try database.restoreS1ReadableContent(selectedConversationID: conversation.id))
        }

        try withDatabase { database in
            let seeded = try seedReadableContent(in: database, storedHashOverride: "mismatched-hash")
            XCTAssertNil(
                try database.restoreS1ReadableContent(
                    selectedConversationID: seeded.conversationID
                )
            )
        }
    }

    func testBrowsingNewerReadableProjectPreservesFocusedReaderDraftAndMessages() throws {
        try withDatabase { database in
            let primary = try seedReadableContent(in: database)
            try database.saveS1ConversationDraft(
                "下一步想让主角先不开门",
                selectedConversationID: primary.conversationID,
                now: Date(timeIntervalSince1970: 1_100)
            )
            _ = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: primary.conversationID,
                turn: S1ConversationPreview.makeTurn(from: "先保留山门外的悬念"),
                now: Date(timeIntervalSince1970: 1_101)
            )
            try database.saveS1ConversationDraft(
                "下一步想让主角先不开门",
                selectedConversationID: primary.conversationID,
                now: Date(timeIntervalSince1970: 1_102)
            )

            let primaryProjectionBeforeBrowse = try XCTUnwrap(
                database.restoreS1ReadableContent(
                    selectedConversationID: primary.conversationID
                )
            )
            let primaryMessagesBeforeBrowse = try database.listAgentMessages(
                conversationID: primary.conversationID
            )
            XCTAssertEqual(
                try database.focusedProjectID(conversationID: primary.conversationID),
                primary.projectID
            )

            _ = try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 1_900))
            let secondaryConversation = try createConversation(
                in: database,
                message: "写另一本雾城之外的小说",
                now: Date(timeIntervalSince1970: 1_901)
            )
            let secondaryProject = try database.createProject(
                title: "另一座城",
                premise: "书架里用于验证只浏览、不偷换创作上下文的另一本书",
                now: Date(timeIntervalSince1970: 2_000)
            )
            try database.saveAgentSession(
                AgentSessionState(
                    focusedProjectID: secondaryProject.id,
                    interviewStep: 0,
                    currentQuestion: "",
                    interviewAnswers: [],
                    updatedAt: Date(timeIntervalSince1970: 2_001)
                ),
                conversationID: secondaryConversation.id
            )
            let secondary = try seedTrustedReadableChapter(
                in: database,
                conversationID: secondaryConversation.id,
                projectID: secondaryProject.id,
                chapterTitle: "第一章 雾港来信",
                body: "潮声越过旧城墙，一封没有署名的信落在灯下。",
                now: Date(timeIntervalSince1970: 2_002)
            )

            XCTAssertEqual(try database.listProjects().first?.id, secondaryProject.id)
            XCTAssertEqual(
                try database.focusedProjectID(conversationID: primary.conversationID),
                primary.projectID
            )

            _ = try database.selectS1Conversation(
                primary.conversationID,
                now: Date(timeIntervalSince1970: 2_100)
            )
            let secondaryProjection = try XCTUnwrap(
                database.restoreS1ReadableContent(
                    selectedConversationID: secondaryConversation.id
                )
            )

            XCTAssertEqual(secondaryProjection.projectID, secondaryProject.id)
            XCTAssertEqual(secondaryProjection.activeVersionID, secondary.versionID)
            XCTAssertEqual(secondaryProjection.projectTitle, "另一座城")
            XCTAssertEqual(
                try database.focusedProjectID(conversationID: primary.conversationID),
                primary.projectID
            )

            let primaryProjectionAfterBrowse = try XCTUnwrap(
                database.restoreS1ReadableContent(
                    selectedConversationID: primary.conversationID
                )
            )
            let workspaceAfterBrowse = try database.restoreS1ConversationWorkspace()

            XCTAssertEqual(primaryProjectionAfterBrowse, primaryProjectionBeforeBrowse)
            XCTAssertEqual(primaryProjectionAfterBrowse.projectID, primary.projectID)
            XCTAssertEqual(primaryProjectionAfterBrowse.activeVersionID, primary.versionID)
            XCTAssertEqual(workspaceAfterBrowse.selectedConversation?.id, primary.conversationID)
            XCTAssertEqual(workspaceAfterBrowse.draft, "下一步想让主角先不开门")
            XCTAssertEqual(
                workspaceAfterBrowse.messageWindow.messages,
                primaryMessagesBeforeBrowse
            )
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: primary.conversationID),
                primaryMessagesBeforeBrowse
            )
        }
    }

    private struct SeededContent {
        let conversationID: UUID
        let projectID: UUID
        let chapterLogicalID: UUID
        let versionID: UUID
        let body: String
    }

    @discardableResult
    private func seedReadableContent(
        in database: AppDatabase,
        storedHashOverride: String? = nil
    ) throws -> SeededContent {
        let now = Date(timeIntervalSince1970: 1_000)
        let conversation = try createConversation(in: database, message: "写一本雨夜山门的小说")
        let project = try database.createProject(
            title: "雾城守夜人",
            premise: "封闭十年的山门在雨夜重新响起",
            now: now.addingTimeInterval(1)
        )
        try database.saveAgentSession(
            AgentSessionState(
                focusedProjectID: project.id,
                interviewStep: 0,
                currentQuestion: "",
                interviewAnswers: [],
                updatedAt: now.addingTimeInterval(2)
            ),
            conversationID: conversation.id
        )

        let logicalID = UUID()
        let versionID = logicalID
        let body = "雨落在石阶上。\n\n封闭十年的山门忽然响了三声。"
        let hash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: logicalID,
            conversationID: conversation.id,
            projectID: project.id,
            chapterNumber: 1,
            revision: 1,
            parentVersionID: nil,
            title: "第一章 山门夜响",
            body: body
        )

        try database.queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO chapterVersion (
                        id, logicalID, conversationID, projectID, chapterNumber, revision,
                        parentVersionID, title, body, contentHash, creationStatus,
                        evidenceReview, diffSummary, createdAt
                    ) VALUES (?, ?, ?, ?, 1, 1, NULL, ?, ?, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    versionID.uuidString,
                    logicalID.uuidString,
                    conversation.id.uuidString,
                    project.id.uuidString,
                    "第一章 山门夜响",
                    body,
                    storedHashOverride ?? hash,
                    ChapterVersionCreationStatus.calibrationReview.rawValue,
                    "已完成证据检查",
                    now.addingTimeInterval(3).timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO chapterCalibration (
                        chapterLogicalID, conversationID, projectID, chapterNumber,
                        activeVersionID, stage, diagnosisEntriesJSON, diagnosisHash,
                        rejectionHistoryJSON, lockedParagraphIndexesJSON, rewriteScope,
                        rewriteScopeHash, acceptedVersionID, updatedAt
                    ) VALUES (?, ?, ?, 1, ?, ?, '[]', ?, '[]', '[]', NULL, NULL, NULL, ?)
                    """,
                arguments: [
                    logicalID.uuidString,
                    conversation.id.uuidString,
                    project.id.uuidString,
                    versionID.uuidString,
                    ChapterCalibrationStage.reviewingV1.rawValue,
                    ChapterFingerprint.diagnosisHash([]),
                    now.addingTimeInterval(4).timeIntervalSince1970
                ]
            )
        }

        return SeededContent(
            conversationID: conversation.id,
            projectID: project.id,
            chapterLogicalID: logicalID,
            versionID: versionID,
            body: body
        )
    }

    @discardableResult
    private func seedTrustedReadableChapter(
        in database: AppDatabase,
        conversationID: UUID,
        projectID: UUID,
        chapterTitle: String,
        body: String,
        now: Date,
        storedHashOverride: String? = nil
    ) throws -> SeededContent {
        let logicalID = UUID()
        let versionID = logicalID
        let hash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: logicalID,
            conversationID: conversationID,
            projectID: projectID,
            chapterNumber: 1,
            revision: 1,
            parentVersionID: nil,
            title: chapterTitle,
            body: body
        )

        try database.queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO chapterVersion (
                        id, logicalID, conversationID, projectID, chapterNumber, revision,
                        parentVersionID, title, body, contentHash, creationStatus,
                        evidenceReview, diffSummary, createdAt
                    ) VALUES (?, ?, ?, ?, 1, 1, NULL, ?, ?, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    versionID.uuidString,
                    logicalID.uuidString,
                    conversationID.uuidString,
                    projectID.uuidString,
                    chapterTitle,
                    body,
                    storedHashOverride ?? hash,
                    ChapterVersionCreationStatus.calibrationReview.rawValue,
                    "已完成证据检查",
                    now.timeIntervalSince1970
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO chapterCalibration (
                        chapterLogicalID, conversationID, projectID, chapterNumber,
                        activeVersionID, stage, diagnosisEntriesJSON, diagnosisHash,
                        rejectionHistoryJSON, lockedParagraphIndexesJSON, rewriteScope,
                        rewriteScopeHash, acceptedVersionID, updatedAt
                    ) VALUES (?, ?, ?, 1, ?, ?, '[]', ?, '[]', '[]', NULL, NULL, NULL, ?)
                    """,
                arguments: [
                    logicalID.uuidString,
                    conversationID.uuidString,
                    projectID.uuidString,
                    versionID.uuidString,
                    ChapterCalibrationStage.reviewingV1.rawValue,
                    ChapterFingerprint.diagnosisHash([]),
                    now.addingTimeInterval(1).timeIntervalSince1970
                ]
            )
        }

        return SeededContent(
            conversationID: conversationID,
            projectID: projectID,
            chapterLogicalID: logicalID,
            versionID: versionID,
            body: body
        )
    }

    private func createConversation(
        in database: AppDatabase,
        message: String,
        now: Date = Date(timeIntervalSince1970: 900)
    ) throws -> AgentConversation {
        try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: message),
            now: now
        ).conversation
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CangJie-S1Reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}