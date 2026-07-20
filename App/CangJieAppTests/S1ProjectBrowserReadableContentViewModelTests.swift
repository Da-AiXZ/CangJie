import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

@MainActor
final class S1ProjectBrowserReadableContentViewModelTests: XCTestCase {
    func testBrowsingTrustedProjectReturnsProjectionWithoutChangingCurrentWorkspace() throws {
        try withDatabase { database in
            let primary = try seedCurrentWorkspace(in: database)
            let secondary = try createSecondaryProjectScope(
                in: database,
                title: "另一座城",
                premise: "书架里只读浏览的乙书",
                message: "写另一本雾城之外的小说",
                now: Date(timeIntervalSince1970: 2_000)
            )
            let expected = try seedActiveChapter(
                in: database,
                scope: secondary,
                chapterNumber: 3,
                title: "第三章 雾港来信",
                body: "潮声越过旧城墙，一封没有署名的信落在灯下。",
                now: Date(timeIntervalSince1970: 2_010)
            )
            _ = try database.selectS1Conversation(
                primary.conversationID,
                now: Date(timeIntervalSince1970: 2_020)
            )
            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            let workspaceBefore = workspaceState(of: model)

            let browsed = try XCTUnwrap(
                model.readableContentForBrowsing(projectID: secondary.projectID)
            )

            XCTAssertEqual(browsed.projectID, secondary.projectID)
            XCTAssertEqual(browsed.conversationID, secondary.conversationID)
            XCTAssertEqual(browsed.chapterLogicalID, expected.logicalID)
            XCTAssertEqual(browsed.activeVersionID, expected.activeVersionID)
            XCTAssertEqual(browsed.projectTitle, "另一座城")
            XCTAssertEqual(browsed.chapterNumber, 3)
            XCTAssertEqual(browsed.chapterTitle, "第三章 雾港来信")
            XCTAssertEqual(browsed.body, "潮声越过旧城墙，一封没有署名的信落在灯下。")
            assertWorkspaceUnchanged(model, from: workspaceBefore)
        }
    }

    func testBrowsingUnknownOrEmptyProjectReturnsNilWithoutChangingCurrentWorkspace() throws {
        try withDatabase { database in
            let primary = try seedCurrentWorkspace(in: database)
            let empty = try createSecondaryProjectScope(
                in: database,
                title: "空白新书",
                premise: "只有故事念头，还没有正文",
                message: "先记下一本还没开始写的书",
                now: Date(timeIntervalSince1970: 3_000)
            )
            _ = try database.selectS1Conversation(
                primary.conversationID,
                now: Date(timeIntervalSince1970: 3_010)
            )
            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            let workspaceBefore = workspaceState(of: model)

            XCTAssertNil(model.readableContentForBrowsing(projectID: empty.projectID))
            XCTAssertNil(model.readableContentForBrowsing(projectID: UUID()))
            assertWorkspaceUnchanged(model, from: workspaceBefore)
        }
    }

    func testBrowsingDatabaseFailureFailsClosedKeepsDiagnosticAndShowsOrdinaryErrorCopy() throws {
        try withDatabase { database in
            let primary = try seedCurrentWorkspace(in: database)
            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            let workspaceBefore = workspaceState(of: model)

            try database.queue.write { db in
                try db.execute(sql: "DROP TABLE chapterCalibration")
            }

            XCTAssertNil(model.readableContentForBrowsing(projectID: primary.projectID))
            assertWorkspaceUnchanged(model, from: workspaceBefore)
            XCTAssertTrue(
                model.diagnosticErrorMessage?.contains("DB-PROJECT-READER") == true
            )
            XCTAssertEqual(model.errorMessage, "这次操作没有完成，请稍后再试")
            XCTAssertFalse(model.errorMessage?.contains("DB-") == true)
            XCTAssertFalse(model.errorMessage?.contains("SQLite") == true)
            XCTAssertFalse(model.errorMessage?.contains("chapterCalibration") == true)
        }
    }

    func testResultDrawerPresentationDoesNotChangeCurrentWorkspaceOrActiveVersion() throws {
        try withDatabase { database in
            _ = try seedCurrentWorkspace(in: database)
            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            let workspaceBefore = workspaceState(of: model)
            let activeVersionBefore = try XCTUnwrap(model.readableContent?.activeVersionID)
            XCTAssertFalse(model.isArtifactDrawerPresented)

            model.isArtifactDrawerPresented = true

            XCTAssertTrue(model.isArtifactDrawerPresented)
            assertWorkspaceUnchanged(model, from: workspaceBefore)
            XCTAssertEqual(model.readableContent?.activeVersionID, activeVersionBefore)

            model.isArtifactDrawerPresented = false

            XCTAssertFalse(model.isArtifactDrawerPresented)
            assertWorkspaceUnchanged(model, from: workspaceBefore)
            XCTAssertEqual(model.readableContent?.activeVersionID, activeVersionBefore)
        }
    }

    private struct ProjectScope {
        let conversationID: UUID
        let projectID: UUID
    }

    private struct SeededChapter {
        let logicalID: UUID
        let activeVersionID: UUID
    }

    private struct WorkspaceState: Equatable {
        let selectedConversationID: UUID?
        let readableContent: S1ReadableContentProjection?
        let composerDraft: String
        let messages: [String]
    }

    private func seedCurrentWorkspace(in database: AppDatabase) throws -> ProjectScope {
        let scope = try createProjectScope(
            in: database,
            title: "雾城守夜人",
            premise: "当前正在创作的甲书",
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
        try database.saveS1ConversationDraft(
            "下一步想让主角先不开门",
            selectedConversationID: scope.conversationID,
            now: Date(timeIntervalSince1970: 1_020)
        )
        _ = try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: scope.conversationID,
            turn: S1ConversationPreview.makeTurn(from: "先保留山门外的悬念"),
            now: Date(timeIntervalSince1970: 1_021)
        )
        try database.saveS1ConversationDraft(
            "下一步想让主角先不开门",
            selectedConversationID: scope.conversationID,
            now: Date(timeIntervalSince1970: 1_022)
        )
        return scope
    }

    private func createSecondaryProjectScope(
        in database: AppDatabase,
        title: String,
        premise: String,
        message: String,
        now: Date
    ) throws -> ProjectScope {
        _ = try database.selectNewS1Conversation(now: now.addingTimeInterval(-1))
        return try createProjectScope(
            in: database,
            title: title,
            premise: premise,
            message: message,
            now: now
        )
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
            projectID: project.id
        )
    }

    @discardableResult
    private func seedActiveChapter(
        in database: AppDatabase,
        scope: ProjectScope,
        chapterNumber: Int,
        title: String,
        body: String,
        now: Date
    ) throws -> SeededChapter {
        let versionID = UUID()
        let logicalID = versionID
        let contentHash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: logicalID,
            conversationID: scope.conversationID,
            projectID: scope.projectID,
            chapterNumber: chapterNumber,
            revision: 1,
            parentVersionID: nil,
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
                    ) VALUES (?, ?, ?, ?, ?, 1, NULL, ?, ?, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    versionID.uuidString,
                    logicalID.uuidString,
                    scope.conversationID.uuidString,
                    scope.projectID.uuidString,
                    chapterNumber,
                    title,
                    body,
                    contentHash,
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
                    ) VALUES (?, ?, ?, ?, ?, ?, '[]', ?, '[]', '[]', NULL, NULL, NULL, ?)
                    """,
                arguments: [
                    logicalID.uuidString,
                    scope.conversationID.uuidString,
                    scope.projectID.uuidString,
                    chapterNumber,
                    versionID.uuidString,
                    ChapterCalibrationStage.reviewingV1.rawValue,
                    ChapterFingerprint.diagnosisHash([]),
                    now.addingTimeInterval(1).timeIntervalSince1970
                ]
            )
        }

        return SeededChapter(
            logicalID: logicalID,
            activeVersionID: versionID
        )
    }

    private func workspaceState(of model: AppViewModel) -> WorkspaceState {
        WorkspaceState(
            selectedConversationID: model.selectedConversationID,
            readableContent: model.readableContent,
            composerDraft: model.draft,
            messages: model.conversationMessages
        )
    }

    private func assertWorkspaceUnchanged(
        _ model: AppViewModel,
        from expected: WorkspaceState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(model.selectedConversationID, expected.selectedConversationID, file: file, line: line)
        XCTAssertEqual(model.readableContent, expected.readableContent, file: file, line: line)
        XCTAssertEqual(model.draft, expected.composerDraft, file: file, line: line)
        XCTAssertEqual(model.conversationMessages, expected.messages, file: file, line: line)
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "CangJie-S1ProjectBrowserReaderVM-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}
