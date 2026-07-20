import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class S1ProjectBrowserReadableContentDatabaseTests: XCTestCase {
    func testLoadsHighestTrustedActiveCommittedCalibrationChapterForProject() throws {
        try withDatabase { database in
            let scope = try createProjectScope(
                in: database,
                title: "雾城守夜人",
                premise: "封闭十年的山门在雨夜重新响起",
                message: "写一本雨夜山门的小说",
                now: Date(timeIntervalSince1970: 1_000)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: scope,
                chapterNumber: 1,
                title: "第一章 山门夜响",
                body: "雨落在石阶上，山门忽然响了三声。",
                now: Date(timeIntervalSince1970: 1_010)
            )
            let expected = try seedActiveChapter(
                in: database,
                scope: scope,
                chapterNumber: 2,
                title: "第二章 门外来客",
                body: "门外的人没有报上姓名，只把一盏旧灯放在雨里。",
                now: Date(timeIntervalSince1970: 1_020)
            )
            _ = try seedAdditionalRevision(
                in: database,
                scope: scope,
                chapter: expected,
                title: "第二章 门外来客（未激活版本）",
                body: "这个更新版本尚未成为 active version，不能被书架正文读取。",
                now: Date(timeIntervalSince1970: 1_021)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: scope,
                chapterNumber: 3,
                title: "第三章 雨中旧信",
                body: "这一章的哈希已经损坏，不能遮住前一章可信正文。",
                now: Date(timeIntervalSince1970: 1_030),
                storedHashOverride: "corrupted-content-hash"
            )

            let projection = try XCTUnwrap(
                database.loadS1ReadableContent(projectID: scope.projectID)
            )

            XCTAssertEqual(projection.projectID, scope.projectID)
            XCTAssertEqual(projection.conversationID, scope.conversationID)
            XCTAssertEqual(projection.chapterLogicalID, expected.logicalID)
            XCTAssertEqual(projection.activeVersionID, expected.activeVersionID)
            XCTAssertEqual(projection.projectTitle, "雾城守夜人")
            XCTAssertEqual(projection.chapterNumber, 2)
            XCTAssertEqual(projection.chapterTitle, "第二章 门外来客")
            XCTAssertEqual(projection.body, "门外的人没有报上姓名，只把一盏旧灯放在雨里。")
            XCTAssertEqual(projection.statusDescription, "这一章正在等你阅读")
        }
    }

    func testFailsClosedWhenCalibrationActiveVersionIdentityIsCorrupted() throws {
        try withDatabase { database in
            let primary = try createProjectScope(
                in: database,
                title: "雾城守夜人",
                premise: "山门在雨夜重新响起",
                message: "先写山门故事",
                now: Date(timeIntervalSince1970: 2_000)
            )
            let primaryChapter = try seedActiveChapter(
                in: database,
                scope: primary,
                chapterNumber: 1,
                title: "第一章 山门夜响",
                body: "山门内外隔着一场十年未停的雨。",
                now: Date(timeIntervalSince1970: 2_010)
            )

            let foreignProject = try database.createProject(
                title: "另一座城",
                premise: "不属于当前书的正文",
                now: Date(timeIntervalSince1970: 2_020)
            )
            let foreignScope = ProjectScope(
                conversationID: primary.conversationID,
                projectID: foreignProject.id,
                projectTitle: foreignProject.title
            )
            let foreignChapter = try insertVersion(
                in: database,
                scope: foreignScope,
                chapterNumber: 1,
                revision: 1,
                logicalID: nil,
                parentVersionID: nil,
                title: "第一章 雾港来信",
                body: "这段正文属于另一座城。",
                creationStatus: ChapterVersionCreationStatus.calibrationReview.rawValue,
                storedHashOverride: nil,
                now: Date(timeIntervalSince1970: 2_021)
            )

            try database.queue.write { db in
                try db.execute(sql: "DROP TRIGGER chapterCalibration_scope_update")
                try db.execute(
                    sql: "UPDATE chapterCalibration SET activeVersionID = ? WHERE chapterLogicalID = ?",
                    arguments: [
                        foreignChapter.versionID.uuidString,
                        primaryChapter.logicalID.uuidString
                    ]
                )
            }

            XCTAssertNil(
                try database.loadS1ReadableContent(projectID: primary.projectID),
                "书架读取必须重新核对 active version 的 logical/conversation/project/chapter 身份，不能只信外键存在"
            )
        }
    }

    func testReturnsNilForUnknownEmptyUncommittedOrOnlyHashDamagedProject() throws {
        try withDatabase { database in
            XCTAssertNil(try database.loadS1ReadableContent(projectID: UUID()))

            let empty = try createProjectScope(
                in: database,
                title: "只有念头",
                premise: "还没有开始正文",
                message: "先记下这个想法",
                now: Date(timeIntervalSince1970: 3_000)
            )
            XCTAssertNil(try database.loadS1ReadableContent(projectID: empty.projectID))

            _ = try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 3_100))
            let uncommitted = try createProjectScope(
                in: database,
                title: "尚未提交",
                premise: "存在临时正文但没有形成 committed calibration chapter",
                message: "先生成一个临时版本",
                now: Date(timeIntervalSince1970: 3_110)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: uncommitted,
                chapterNumber: 1,
                title: "第一章 临时版本",
                body: "这只是未提交内容。",
                now: Date(timeIntervalSince1970: 3_120),
                creationStatus: "previewOnly"
            )
            XCTAssertNil(try database.loadS1ReadableContent(projectID: uncommitted.projectID))

            _ = try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 3_200))
            let damaged = try createProjectScope(
                in: database,
                title: "损坏正文",
                premise: "唯一正文的哈希不可信",
                message: "读取损坏正文",
                now: Date(timeIntervalSince1970: 3_210)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: damaged,
                chapterNumber: 1,
                title: "第一章 损坏版本",
                body: "正文存在，但完整性验证必须失败。",
                now: Date(timeIntervalSince1970: 3_220),
                storedHashOverride: "not-the-calculated-hash"
            )
            XCTAssertNil(try database.loadS1ReadableContent(projectID: damaged.projectID))
        }
    }

    func testReadingSecondaryProjectDoesNotChangePrimaryPersistedConversationState() throws {
        try withDatabase { database in
            let primary = try createProjectScope(
                in: database,
                title: "雾城守夜人",
                premise: "当前正在创作的甲书",
                message: "写一本雨夜山门的小说",
                now: Date(timeIntervalSince1970: 4_000)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: primary,
                chapterNumber: 1,
                title: "第一章 山门夜响",
                body: "雨落在石阶上，山门忽然响了三声。",
                now: Date(timeIntervalSince1970: 4_010)
            )
            try database.saveS1ConversationDraft(
                "下一步想让主角先不开门",
                selectedConversationID: primary.conversationID,
                now: Date(timeIntervalSince1970: 4_020)
            )
            _ = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: primary.conversationID,
                turn: S1ConversationPreview.makeTurn(from: "先保留山门外的悬念"),
                now: Date(timeIntervalSince1970: 4_021)
            )
            try database.saveS1ConversationDraft(
                "下一步想让主角先不开门",
                selectedConversationID: primary.conversationID,
                now: Date(timeIntervalSince1970: 4_022)
            )

            _ = try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 4_100))
            let secondary = try createProjectScope(
                in: database,
                title: "另一座城",
                premise: "书架里只读浏览的乙书",
                message: "写另一本雾城之外的小说",
                now: Date(timeIntervalSince1970: 4_110)
            )
            let secondaryChapter = try seedActiveChapter(
                in: database,
                scope: secondary,
                chapterNumber: 3,
                title: "第三章 雾港来信",
                body: "潮声越过旧城墙，一封没有署名的信落在灯下。",
                now: Date(timeIntervalSince1970: 4_120)
            )

            _ = try database.selectS1Conversation(
                primary.conversationID,
                now: Date(timeIntervalSince1970: 4_200)
            )
            let workspaceBefore = try database.restoreS1ConversationWorkspace()
            let sessionBefore = try database.loadAgentSession(conversationID: primary.conversationID)
            let focusedProjectBefore = try database.focusedProjectID(
                conversationID: primary.conversationID
            )
            let messagesBefore = try database.listAgentMessages(
                conversationID: primary.conversationID
            )

            let browsed = try XCTUnwrap(
                database.loadS1ReadableContent(projectID: secondary.projectID)
            )

            let workspaceAfter = try database.restoreS1ConversationWorkspace()
            XCTAssertEqual(browsed.projectID, secondary.projectID)
            XCTAssertEqual(browsed.conversationID, secondary.conversationID)
            XCTAssertEqual(browsed.activeVersionID, secondaryChapter.activeVersionID)
            XCTAssertEqual(browsed.chapterNumber, 3)
            XCTAssertEqual(browsed.body, "潮声越过旧城墙，一封没有署名的信落在灯下。")
            XCTAssertEqual(workspaceAfter, workspaceBefore)
            XCTAssertEqual(workspaceAfter.selectedConversation?.id, primary.conversationID)
            XCTAssertEqual(workspaceAfter.draft, "下一步想让主角先不开门")
            XCTAssertEqual(
                try database.loadAgentSession(conversationID: primary.conversationID),
                sessionBefore
            )
            XCTAssertEqual(
                try database.focusedProjectID(conversationID: primary.conversationID),
                focusedProjectBefore
            )
            XCTAssertEqual(focusedProjectBefore, primary.projectID)
            XCTAssertEqual(
                try database.listAgentMessages(conversationID: primary.conversationID),
                messagesBefore
            )
        }
    }

    func testRejectsApprovedFrozenCalibrationWithoutMatchingAcceptedVersion() throws {
        try withDatabase { database in
            let scope = try createProjectScope(
                in: database,
                title: "雾城守夜人",
                premise: "山门在雨夜重新响起",
                message: "先写山门故事",
                now: Date(timeIntervalSince1970: 5_000)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: scope,
                chapterNumber: 1,
                title: "第一章 山门夜响",
                body: "山门内外隔着一场十年未停的雨。",
                now: Date(timeIntervalSince1970: 5_010),
                stage: .approvedFrozen,
                acceptedVersionMode: .missing
            )

            XCTAssertNil(try database.loadS1ReadableContent(projectID: scope.projectID))
        }
    }

    func testRejectsNonPositiveRevisionEvenWhenStoredHashMatches() throws {
        try withDatabase { database in
            let scope = try createProjectScope(
                in: database,
                title: "雾城守夜人",
                premise: "山门在雨夜重新响起",
                message: "先写山门故事",
                now: Date(timeIntervalSince1970: 6_000)
            )
            _ = try seedActiveChapter(
                in: database,
                scope: scope,
                chapterNumber: 1,
                title: "第一章 山门夜响",
                body: "这一版使用非法 revision 重新计算了哈希，也不能成为可信正文。",
                now: Date(timeIntervalSince1970: 6_010),
                revision: 0
            )

            XCTAssertNil(try database.loadS1ReadableContent(projectID: scope.projectID))
        }
    }

    func testAcceptsApprovedFrozenCalibrationOnlyWhenAcceptedVersionMatchesActiveVersion() throws {
        try withDatabase { database in
            let scope = try createProjectScope(
                in: database,
                title: "雾城守夜人",
                premise: "山门在雨夜重新响起",
                message: "先写山门故事",
                now: Date(timeIntervalSince1970: 7_000)
            )
            let chapter = try seedActiveChapter(
                in: database,
                scope: scope,
                chapterNumber: 1,
                title: "第一章 山门夜响",
                body: "这版正文已经由用户确认。",
                now: Date(timeIntervalSince1970: 7_010),
                stage: .approvedFrozen,
                acceptedVersionMode: .active
            )

            let projection = try XCTUnwrap(
                database.loadS1ReadableContent(projectID: scope.projectID)
            )
            XCTAssertEqual(projection.activeVersionID, chapter.activeVersionID)
            XCTAssertEqual(projection.statusDescription, "这一章已经按你的决定保存")
        }
    }
    private struct ProjectScope {
        let conversationID: UUID
        let projectID: UUID
        let projectTitle: String
    }

    private enum AcceptedVersionMode {
        case missing
        case active
    }

    private struct SeededChapter {
        let logicalID: UUID
        let activeVersionID: UUID
        let chapterNumber: Int
    }

    private struct InsertedVersion {
        let logicalID: UUID
        let versionID: UUID
        let chapterNumber: Int
        let revision: Int
    }

    private func createProjectScope(
        in database: AppDatabase,
        title: String,
        premise: String,
        message: String,
        now: Date
    ) throws -> ProjectScope {
        let conversation = try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: message),
            now: now
        ).conversation
        let project = try database.createProject(
            title: title,
            premise: premise,
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
        return ProjectScope(
            conversationID: conversation.id,
            projectID: project.id,
            projectTitle: project.title
        )
    }

    @discardableResult
    private func seedActiveChapter(
        in database: AppDatabase,
        scope: ProjectScope,
        chapterNumber: Int,
        title: String,
        body: String,
        now: Date,
        revision: Int = 1,
        stage: ChapterCalibrationStage = .reviewingV1,
        acceptedVersionMode: AcceptedVersionMode = .missing,
        creationStatus: String = ChapterVersionCreationStatus.calibrationReview.rawValue,
        storedHashOverride: String? = nil
    ) throws -> SeededChapter {
        let version = try insertVersion(
            in: database,
            scope: scope,
            chapterNumber: chapterNumber,
            revision: revision,
            logicalID: nil,
            parentVersionID: nil,
            title: title,
            body: body,
            creationStatus: creationStatus,
            storedHashOverride: storedHashOverride,
            now: now
        )
        try database.queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO chapterCalibration (
                        chapterLogicalID, conversationID, projectID, chapterNumber,
                        activeVersionID, stage, diagnosisEntriesJSON, diagnosisHash,
                        rejectionHistoryJSON, lockedParagraphIndexesJSON, rewriteScope,
                        rewriteScopeHash, acceptedVersionID, updatedAt
                    ) VALUES (?, ?, ?, ?, ?, ?, '[]', ?, '[]', '[]', NULL, NULL, ?, ?)
                    """,
                arguments: [
                    version.logicalID.uuidString,
                    scope.conversationID.uuidString,
                    scope.projectID.uuidString,
                    chapterNumber,
                    version.versionID.uuidString,
                    stage.rawValue,
                    ChapterFingerprint.diagnosisHash([]),
                    acceptedVersionMode == .active ? version.versionID.uuidString : nil,
                    now.addingTimeInterval(1).timeIntervalSince1970
                ]
            )
        }
        return SeededChapter(
            logicalID: version.logicalID,
            activeVersionID: version.versionID,
            chapterNumber: chapterNumber
        )
    }

    @discardableResult
    private func seedAdditionalRevision(
        in database: AppDatabase,
        scope: ProjectScope,
        chapter: SeededChapter,
        title: String,
        body: String,
        now: Date
    ) throws -> InsertedVersion {
        try insertVersion(
            in: database,
            scope: scope,
            chapterNumber: chapter.chapterNumber,
            revision: 2,
            logicalID: chapter.logicalID,
            parentVersionID: chapter.activeVersionID,
            title: title,
            body: body,
            creationStatus: ChapterVersionCreationStatus.calibrationReview.rawValue,
            storedHashOverride: nil,
            now: now
        )
    }

    @discardableResult
    private func insertVersion(
        in database: AppDatabase,
        scope: ProjectScope,
        chapterNumber: Int,
        revision: Int,
        logicalID: UUID?,
        parentVersionID: UUID?,
        title: String,
        body: String,
        creationStatus: String,
        storedHashOverride: String?,
        now: Date
    ) throws -> InsertedVersion {
        let versionID = UUID()
        let resolvedLogicalID = logicalID ?? versionID
        let hash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: resolvedLogicalID,
            conversationID: scope.conversationID,
            projectID: scope.projectID,
            chapterNumber: chapterNumber,
            revision: revision,
            parentVersionID: parentVersionID,
            title: title,
            body: body
        )
        try database.queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO chapterVersion (
                        id, logicalID, conversationID, projectID, chapterNumber, revision,
                        parentVersionID, title, body, contentHash, creationStatus,
                        evidenceReview, diffSummary, createdAt
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    versionID.uuidString,
                    resolvedLogicalID.uuidString,
                    scope.conversationID.uuidString,
                    scope.projectID.uuidString,
                    chapterNumber,
                    revision,
                    parentVersionID?.uuidString,
                    title,
                    body,
                    storedHashOverride ?? hash,
                    creationStatus,
                    "已完成证据检查",
                    now.timeIntervalSince1970
                ]
            )
        }
        return InsertedVersion(
            logicalID: resolvedLogicalID,
            versionID: versionID,
            chapterNumber: chapterNumber,
            revision: revision
        )
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CangJie-S1ProjectBrowserReader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}
