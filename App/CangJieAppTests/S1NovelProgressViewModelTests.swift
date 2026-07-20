import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

@MainActor
final class S1NovelProgressViewModelTests: XCTestCase {
    func testInitializationRestoresProgressDescriptionsForExistingProjects() throws {
        try withDatabase { database in
            let fixture = try makeProject(
                in: database,
                title: "雾城守夜人",
                premise: "封闭十年的山门在雨夜重新响起"
            )
            try seedChapter(
                in: database,
                fixture: fixture,
                chapterNumber: 1,
                stage: .reviewingV1
            )

            let model = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(model.novelProgressByProjectID.count, 1)
            XCTAssertEqual(model.novelProgressByProjectID[fixture.project.id], "第一章等你看看")
        }
    }

    func testReloadProjectsReloadsProgressDescriptionsFromCurrentDatabaseFacts() throws {
        try withDatabase { database in
            let fixture = try makeProject(
                in: database,
                title: "长夜行舟",
                premise: "一艘不能靠岸的船"
            )
            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            XCTAssertEqual(
                model.novelProgressByProjectID[fixture.project.id],
                "刚保存了故事念头，还没有开始正文"
            )

            try seedChapter(
                in: database,
                fixture: fixture,
                chapterNumber: 2,
                stage: .diagnosing
            )
            model.reloadProjects()

            XCTAssertEqual(model.novelProgressByProjectID[fixture.project.id], "正在修改第 2 章")
        }
    }

    func testUntrustedChapterFactsFailClosedInsteadOfClaimingProgress() throws {
        try withDatabase { database in
            let fixture = try makeProject(
                in: database,
                title: "空城旧梦",
                premise: ""
            )
            try seedChapter(
                in: database,
                fixture: fixture,
                chapterNumber: 8,
                stage: .reviewingV2,
                storedHashOverride: "corrupted-content-hash"
            )

            let model = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(model.novelProgressByProjectID[fixture.project.id], "这本书暂时没有正文")
            XCTAssertFalse(model.novelProgressByProjectID[fixture.project.id]?.contains("第 8 章") == true)
        }
    }

    func testEachProjectKeepsItsOwnIndependentProgressDescription() throws {
        try withDatabase { database in
            let awaitingReview = try makeProject(
                in: database,
                title: "第一本书",
                premise: "第一本书的故事念头"
            )
            try seedChapter(
                in: database,
                fixture: awaitingReview,
                chapterNumber: 1,
                stage: .reviewingV1
            )

            let editing = try makeProject(
                in: database,
                title: "第二本书",
                premise: "第二本书的故事念头"
            )
            try seedChapter(
                in: database,
                fixture: editing,
                chapterNumber: 3,
                stage: .rewriting
            )

            let model = AppViewModel(database: database, keychain: StubSecretRepository())

            XCTAssertEqual(model.novelProgressByProjectID.count, 2)
            XCTAssertEqual(model.novelProgressByProjectID[awaitingReview.project.id], "第一章等你看看")
            XCTAssertEqual(model.novelProgressByProjectID[editing.project.id], "正在修改第 3 章")
        }
    }

    func testPremiseNeverBecomesTheDisplayedProgressDescription() throws {
        try withDatabase { database in
            let premise = "已经写到第 99 章，正在修改第 100 章"
            let fixture = try makeProject(
                in: database,
                title: "误导性简介",
                premise: premise
            )

            let model = AppViewModel(database: database, keychain: StubSecretRepository())
            let progress = model.novelProgressByProjectID[fixture.project.id]

            XCTAssertEqual(progress, "刚保存了故事念头，还没有开始正文")
            XCTAssertNotEqual(progress, premise)
            XCTAssertFalse(progress?.contains("99") == true)
            XCTAssertFalse(progress?.contains("100") == true)
        }
    }

    private struct ProjectFixture {
        let conversationID: UUID
        let project: NovelProject
    }

    private func makeProject(
        in database: AppDatabase,
        title: String,
        premise: String
    ) throws -> ProjectFixture {
        let conversation = try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: "为\(title)保存一个故事念头"),
            now: Date(timeIntervalSince1970: 900)
        ).conversation
        let project = try database.createProject(
            title: title,
            premise: premise,
            now: Date(timeIntervalSince1970: 901)
        )
        return ProjectFixture(conversationID: conversation.id, project: project)
    }

    private func seedChapter(
        in database: AppDatabase,
        fixture: ProjectFixture,
        chapterNumber: Int,
        stage: ChapterCalibrationStage,
        storedHashOverride: String? = nil
    ) throws {
        let versionID = UUID()
        let title = "第 \(chapterNumber) 章"
        let body = "这是第 \(chapterNumber) 章的正文。"
        let contentHash = ChapterFingerprint.versionHash(
            id: versionID,
            logicalID: versionID,
            conversationID: fixture.conversationID,
            projectID: fixture.project.id,
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
                    versionID.uuidString,
                    fixture.conversationID.uuidString,
                    fixture.project.id.uuidString,
                    chapterNumber,
                    title,
                    body,
                    storedHashOverride ?? contentHash,
                    ChapterVersionCreationStatus.calibrationReview.rawValue,
                    "已完成证据检查",
                    Date(timeIntervalSince1970: 1_000 + Double(chapterNumber)).timeIntervalSince1970
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
                    versionID.uuidString,
                    fixture.conversationID.uuidString,
                    fixture.project.id.uuidString,
                    chapterNumber,
                    versionID.uuidString,
                    stage.rawValue,
                    ChapterFingerprint.diagnosisHash([]),
                    Date(timeIntervalSince1970: 1_100 + Double(chapterNumber)).timeIntervalSince1970
                ]
            )
        }
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CangJie-S1NovelProgressVM-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}