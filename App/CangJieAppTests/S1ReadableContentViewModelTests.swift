import CangJieCore
import GRDB
import SwiftUI
import XCTest
@testable import CangJie

@MainActor
final class S1ReadableContentViewModelTests: XCTestCase {
    func testInitializationRestoresReaderWithoutRestoringLegacyRuntimeCards() throws {
        try withDatabase { database in
            let seeded = try seedReadableContent(in: database)
            let model = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(model.readableContent?.projectID, seeded.projectID)
            XCTAssertEqual(model.readableContent?.body, seeded.body)
            XCTAssertTrue(model.hasReadableContent)
            XCTAssertNil(model.openingPlanApproval)
            XCTAssertNil(model.lastToolReceipt)
            XCTAssertNil(model.latestAgentRun)
            XCTAssertNil(model.chapter)
        }
    }

    func testSwitchingConversationRefreshesReaderAndUnboundWorkspaceFailsClosed() throws {
        try withDatabase { database in
            let seeded = try seedReadableContent(in: database)
            _ = try database.selectNewS1Conversation(now: Date(timeIntervalSince1970: 1_999))
            let otherConversation = try database.appendS1WorkspacePreviewTurn(
                selectedConversationID: nil,
                turn: S1ConversationPreview.makeTurn(from: "另一个没有正文的对话"),
                now: Date(timeIntervalSince1970: 2_000)
            ).conversation
            let model = AppViewModel(database: database, keychain: StubSecretRepository())

            model.selectS1Conversation(otherConversation.id)
            XCTAssertNil(model.readableContent)

            model.selectS1Conversation(seeded.conversationID)
            XCTAssertEqual(model.readableContent?.projectID, seeded.projectID)

            model.startNewS1Conversation()
            XCTAssertNil(model.readableContent)
        }
    }

    func testReturningActiveRefreshesNewlyCommittedReaderProjection() throws {
        try withDatabase { database in
            let scope = try seedConversationFocus(in: database)
            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertNil(model.readableContent)

            let seeded = try insertReadableChapter(
                in: database,
                conversationID: scope.conversationID,
                projectID: scope.projectID
            )
            model.handleScenePhase(.active)

            XCTAssertEqual(model.readableContent?.activeVersionID, seeded.versionID)
            XCTAssertEqual(model.readableContent?.projectID, scope.projectID)
        }
    }

    private struct Scope {
        let conversationID: UUID
        let projectID: UUID
    }

    private struct SeededContent {
        let conversationID: UUID
        let projectID: UUID
        let versionID: UUID
        let body: String
    }

    private func seedReadableContent(in database: AppDatabase) throws -> SeededContent {
        let scope = try seedConversationFocus(in: database)
        return try insertReadableChapter(
            in: database,
            conversationID: scope.conversationID,
            projectID: scope.projectID
        )
    }

    private func seedConversationFocus(in database: AppDatabase) throws -> Scope {
        let now = Date(timeIntervalSince1970: 1_000)
        let conversation = try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: "写一本雨夜山门的小说"),
            now: now
        ).conversation
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
        return Scope(conversationID: conversation.id, projectID: project.id)
    }

    private func insertReadableChapter(
        in database: AppDatabase,
        conversationID: UUID,
        projectID: UUID
    ) throws -> SeededContent {
        let now = Date(timeIntervalSince1970: 1_100)
        let logicalID = UUID()
        let versionID = logicalID
        let title = "第一章 山门夜响"
        let body = "雨落在石阶上。\n\n封闭十年的山门忽然响了三声。"
        let hash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: logicalID,
            conversationID: conversationID,
            projectID: projectID,
            chapterNumber: 1,
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
                    ) VALUES (?, ?, ?, ?, 1, 1, NULL, ?, ?, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    versionID.uuidString,
                    logicalID.uuidString,
                    conversationID.uuidString,
                    projectID.uuidString,
                    title,
                    body,
                    hash,
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
            versionID: versionID,
            body: body
        )
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CangJie-S1ReaderVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}