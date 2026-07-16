import XCTest
@testable import CangJie

final class AppDatabaseTests: XCTestCase {
    func testDraftAndCheckpointRoundTripUsesWAL() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
        XCTAssertEqual(try database.journalMode().lowercased(), "wal")

        let date = Date(timeIntervalSince1970: 1_000)
        let taskID = UUID()
        let checkpoint = try database.checkpointDraft(
            content: "第一章草稿",
            taskID: taskID,
            reason: "manual",
            payloadHash: "abc",
            now: date
        )

        XCTAssertEqual(checkpoint.sequence, 1)
        XCTAssertEqual(
            try database.loadDraft(),
            DraftSnapshot(content: "第一章草稿", updatedAt: date)
        )
        XCTAssertEqual(try database.latestCheckpoint(taskID: taskID), checkpoint)
    }

    func testSamePayloadReusesCheckpointWithoutAdvancingSequence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path)
        let taskID = UUID()
        let first = try database.checkpointDraft(
            content: "未变化草稿",
            taskID: taskID,
            reason: "inactive",
            payloadHash: "same",
            now: Date(timeIntervalSince1970: 1_000)
        )
        let second = try database.checkpointDraft(
            content: "未变化草稿",
            taskID: taskID,
            reason: "background",
            payloadHash: "same",
            now: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertEqual(second, first)
        XCTAssertEqual(try database.latestCheckpoint(taskID: taskID)?.sequence, 1)
    }

    func testCreateAndListNovelProjectsPersistsNewestFirst() throws {
        let (database, directory) = try makeDatabase()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try database.createProject(title: "First", premise: "A", now: Date(timeIntervalSince1970: 100))
        let second = try database.createProject(title: "Second", premise: "B", now: Date(timeIntervalSince1970: 200))
        let projects = try database.listProjects()

        XCTAssertEqual(projects.map(\.id), [second.id, first.id])
        XCTAssertEqual(projects.map(\.title), ["Second", "First"])
    }


    func testPlanningArtifactRoundTripKeepsApprovalStatus() throws {
        let (database, directory) = try makeDatabase()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = try database.saveArtifact(kind: "openingPlan", title: "Plan", body: "Body", status: "waitingApproval", now: Date(timeIntervalSince1970: 300))
        let restored = try database.latestArtifact(kind: "openingPlan")

        XCTAssertEqual(restored, saved)
    }

    private func makeDatabase() throws -> (AppDatabase, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try AppDatabase(path: directory.appendingPathComponent("test.sqlite").path), directory)
    }

}