import CangJieCore
import Foundation
import GRDB
import XCTest
@testable import CangJie

final class S1NovelProgressDatabaseTests: XCTestCase {
    func testReturnsFactsForEveryProjectWithoutTreatingPremiseAsChapterProgress() throws {
        try withDatabase { database in
            let ideaProject = try database.createProject(
                title: "雾城守夜人",
                premise: "封闭十年的山门在雨夜重新响起",
                now: Date(timeIntervalSince1970: 1_000)
            )
            let emptyProject = try database.createProject(
                title: "空白新书",
                premise: " \n ",
                now: Date(timeIntervalSince1970: 1_001)
            )

            let factsByProject = try database.loadS1NovelProgressFacts()

            XCTAssertEqual(factsByProject.count, 2)
            XCTAssertEqual(
                factsByProject[ideaProject.id],
                S1NovelProgressFacts(
                    hasSavedStoryIdea: true,
                    latestAvailableChapterNumber: nil,
                    awaitingReviewChapterNumber: nil,
                    editingChapterNumber: nil
                )
            )
            XCTAssertEqual(
                factsByProject[emptyProject.id],
                S1NovelProgressFacts(
                    hasSavedStoryIdea: false,
                    latestAvailableChapterNumber: nil,
                    awaitingReviewChapterNumber: nil,
                    editingChapterNumber: nil
                )
            )
        }
    }

    func testProjectsTrustedChapterStagesPerProjectWithoutCrossContamination() throws {
        try withDatabase { database in
            let first = try makeProject(in: database, title: "第一本书")
            try seedChapter(in: database, fixture: first, chapterNumber: 1, stage: .reviewingV1)
            try seedChapter(in: database, fixture: first, chapterNumber: 2, stage: .reviewingV2)
            try seedChapter(in: database, fixture: first, chapterNumber: 3, stage: .diagnosing)

            let second = try makeProject(in: database, title: "第二本书")
            try seedChapter(in: database, fixture: second, chapterNumber: 1, stage: .reviewingV1)

            let factsByProject = try database.loadS1NovelProgressFacts()

            XCTAssertEqual(
                factsByProject[first.project.id],
                S1NovelProgressFacts(
                    hasSavedStoryIdea: true,
                    latestAvailableChapterNumber: 3,
                    awaitingReviewChapterNumber: 2,
                    editingChapterNumber: 3
                )
            )
            XCTAssertEqual(
                factsByProject[second.project.id],
                S1NovelProgressFacts(
                    hasSavedStoryIdea: true,
                    latestAvailableChapterNumber: 1,
                    awaitingReviewChapterNumber: 1,
                    editingChapterNumber: nil
                )
            )
        }
    }

    func testEditingIncludesFeedbackDecisionAndRewriteStages() throws {
        try withDatabase { database in
            let diagnosing = try makeProject(in: database, title: "正在理解反馈")
            try seedChapter(in: database, fixture: diagnosing, chapterNumber: 1, stage: .diagnosing)

            let awaitingDecision = try makeProject(in: database, title: "等待修改决定")
            try seedChapter(
                in: database,
                fixture: awaitingDecision,
                chapterNumber: 2,
                stage: .awaitingRewriteConfirmation
            )

            let rewriting = try makeProject(in: database, title: "正在修改")
            try seedChapter(in: database, fixture: rewriting, chapterNumber: 4, stage: .rewriting)

            let factsByProject = try database.loadS1NovelProgressFacts()

            XCTAssertEqual(factsByProject[diagnosing.project.id]?.editingChapterNumber, 1)
            XCTAssertEqual(factsByProject[awaitingDecision.project.id]?.editingChapterNumber, 2)
            XCTAssertEqual(factsByProject[rewriting.project.id]?.editingChapterNumber, 4)
        }
    }

    func testHashInvalidHigherChapterCannotBecomeLatestOrAwaitingProgress() throws {
        try withDatabase { database in
            let fixture = try makeProject(in: database, title: "哈希回退")
            try seedChapter(in: database, fixture: fixture, chapterNumber: 1, stage: .reviewingV1)
            try seedChapter(
                in: database,
                fixture: fixture,
                chapterNumber: 2,
                stage: .reviewingV2,
                storedHashOverride: "untrusted-content-hash"
            )

            let facts = try XCTUnwrap(database.loadS1NovelProgressFacts()[fixture.project.id])

            XCTAssertEqual(facts.latestAvailableChapterNumber, 1)
            XCTAssertEqual(facts.awaitingReviewChapterNumber, 1)
            XCTAssertNil(facts.editingChapterNumber)
        }
    }

    func testIncompleteUnknownAndUncommittedChaptersFailClosed() throws {
        try withDatabase { database in
            let versionOnly = try makeProject(in: database, title: "缺少校准")
            try seedVersionOnly(in: database, fixture: versionOnly, chapterNumber: 1)

            let unknownStage = try makeProject(in: database, title: "未知状态")
            try seedChapter(
                in: database,
                fixture: unknownStage,
                chapterNumber: 1,
                stageText: "futureUnknownStage"
            )

            let uncommitted = try makeProject(in: database, title: "未提交正文")
            try seedChapter(
                in: database,
                fixture: uncommitted,
                chapterNumber: 1,
                stage: .reviewingV1,
                creationStatus: "streamingTemporary"
            )

            let notStarted = try makeProject(in: database, title: "尚未开始")
            try seedChapter(in: database, fixture: notStarted, chapterNumber: 1, stage: .notStarted)

            let factsByProject = try database.loadS1NovelProgressFacts()

            for projectID in [
                versionOnly.project.id,
                unknownStage.project.id,
                uncommitted.project.id,
                notStarted.project.id
            ] {
                let facts = try XCTUnwrap(factsByProject[projectID])
                XCTAssertNil(facts.latestAvailableChapterNumber)
                XCTAssertNil(facts.awaitingReviewChapterNumber)
                XCTAssertNil(facts.editingChapterNumber)
            }
        }
    }

    func testMalformedCalibrationIntegrityFailsClosedWithoutHidingOtherProjects() throws {
        try withDatabase { database in
            let malformed = try makeProject(in: database, title: "损坏校准")
            try seedChapter(
                in: database,
                fixture: malformed,
                chapterNumber: 1,
                stage: .reviewingV1,
                diagnosisHashOverride: "wrong-diagnosis-hash"
            )

            let healthy = try makeProject(in: database, title: "可信项目")
            try seedChapter(in: database, fixture: healthy, chapterNumber: 2, stage: .reviewingV2)

            let factsByProject = try database.loadS1NovelProgressFacts()

            XCTAssertNil(factsByProject[malformed.project.id]?.latestAvailableChapterNumber)
            XCTAssertEqual(factsByProject[healthy.project.id]?.latestAvailableChapterNumber, 2)
            XCTAssertEqual(factsByProject[healthy.project.id]?.awaitingReviewChapterNumber, 2)
        }
    }

    private struct ProjectFixture {
        let conversationID: UUID
        let project: NovelProject
    }

    private func makeProject(
        in database: AppDatabase,
        title: String
    ) throws -> ProjectFixture {
        let conversation = try database.appendS1WorkspacePreviewTurn(
            selectedConversationID: nil,
            turn: S1ConversationPreview.makeTurn(from: "为\(title)保存一个故事念头"),
            now: Date(timeIntervalSince1970: 900)
        ).conversation
        let project = try database.createProject(
            title: title,
            premise: "\(title)的故事念头",
            now: Date(timeIntervalSince1970: 901)
        )
        return ProjectFixture(conversationID: conversation.id, project: project)
    }

    @discardableResult
    private func seedChapter(
        in database: AppDatabase,
        fixture: ProjectFixture,
        chapterNumber: Int,
        stage: ChapterCalibrationStage? = nil,
        stageText: String? = nil,
        creationStatus: String = ChapterVersionCreationStatus.calibrationReview.rawValue,
        storedHashOverride: String? = nil,
        diagnosisHashOverride: String? = nil
    ) throws -> UUID {
        let versionID = try seedVersionOnly(
            in: database,
            fixture: fixture,
            chapterNumber: chapterNumber,
            creationStatus: creationStatus,
            storedHashOverride: storedHashOverride
        )
        let stageValue: String
        if let stageText {
            stageValue = stageText
        } else {
            stageValue = try XCTUnwrap(stage).rawValue
        }

        try database.queue.write { db in
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
                    stageValue,
                    diagnosisHashOverride ?? ChapterFingerprint.diagnosisHash([]),
                    Date(timeIntervalSince1970: 1_100 + Double(chapterNumber)).timeIntervalSince1970
                ]
            )
        }
        return versionID
    }

    @discardableResult
    private func seedVersionOnly(
        in database: AppDatabase,
        fixture: ProjectFixture,
        chapterNumber: Int,
        creationStatus: String = ChapterVersionCreationStatus.calibrationReview.rawValue,
        storedHashOverride: String? = nil
    ) throws -> UUID {
        let versionID = UUID()
        let title = "第 \(chapterNumber) 章"
        let body = "这是第 \(chapterNumber) 章的可信正文。"
        let hash = ChapterFingerprint.versionHash(
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
                    storedHashOverride ?? hash,
                    creationStatus,
                    "已完成证据检查",
                    Date(timeIntervalSince1970: 1_000 + Double(chapterNumber)).timeIntervalSince1970
                ]
            )
        }
        return versionID
    }

    private func withDatabase(_ body: (AppDatabase) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CangJie-S1NovelProgress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(AppDatabase(path: directory.appendingPathComponent("test.sqlite").path))
    }
}
