import XCTest
@testable import CangJieCore

final class CheckpointTests: XCTestCase {
    func testSameIdempotencyKeyAndPayloadReusesCheckpoint() {
        let checkpoint = makeCheckpoint(hash: "same")
        let action = RecoveryPlanner().action(
            taskID: checkpoint.taskID,
            idempotencyKey: checkpoint.idempotencyKey,
            payloadHash: "same",
            existing: checkpoint
        )
        XCTAssertEqual(action, .reuse(checkpoint))
    }

    func testRecoveryPlannerDoesNotReuseCheckpointFromAnotherTask() {
        let checkpoint = makeCheckpoint(hash: "same")
        let action = RecoveryPlanner().action(
            taskID: UUID(),
            idempotencyKey: checkpoint.idempotencyKey,
            payloadHash: checkpoint.payloadHash,
            existing: checkpoint
        )
        XCTAssertEqual(action, .execute)
    }

    func testChangedPayloadCannotReusePaidResult() {
        let checkpoint = makeCheckpoint(hash: "old")
        let action = RecoveryPlanner().action(
            taskID: checkpoint.taskID,
            idempotencyKey: checkpoint.idempotencyKey,
            payloadHash: "new",
            existing: checkpoint
        )
        XCTAssertEqual(action, .rejectPayloadMismatch(existing: checkpoint))
    }

    func testFileStorePersistsAndRestoresLatestCheckpoint() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("checkpoints.json")
        let taskID = UUID()
        let first = makeCheckpoint(
            taskID: taskID,
            idempotencyKey: "chapter-1.plan.v1",
            sequence: 1,
            hash: "one"
        )
        let second = makeCheckpoint(
            taskID: taskID,
            idempotencyKey: "chapter-1.prose.v1",
            sequence: 2,
            hash: "two"
        )
        let store = try FileCheckpointStore(fileURL: fileURL)
        try await store.save(first)
        try await store.save(second)
        let restored = try FileCheckpointStore(fileURL: fileURL)
        let latest = try await restored.latest(taskID: taskID)
        XCTAssertEqual(latest, second)
    }

    func testSameTaskAndKeyWithDifferentPayloadIsRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let taskID = UUID()
        let original = makeCheckpoint(taskID: taskID, sequence: 1, hash: "original")
        let conflicting = makeCheckpoint(taskID: taskID, sequence: 2, hash: "changed")
        try await store.save(original)

        do {
            try await store.save(conflicting)
            XCTFail("Expected payload mismatch")
        } catch let error as CheckpointStoreError {
            XCTAssertEqual(
                error,
                .payloadMismatch(existing: original, incoming: conflicting)
            )
        }

        let restored = try await store.checkpoint(
            taskID: taskID,
            idempotencyKey: original.idempotencyKey
        )
        XCTAssertEqual(restored, original)
    }

    func testIdenticalCheckpointSaveIsANoOp() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("checkpoints.json")
        let store = try FileCheckpointStore(fileURL: fileURL)
        let checkpoint = makeCheckpoint(hash: "same")
        try await store.save(checkpoint)
        let firstData = try Data(contentsOf: fileURL)
        try await store.save(checkpoint)
        let secondData = try Data(contentsOf: fileURL)
        XCTAssertEqual(secondData, firstData)
    }

    func testSameTaskAndSequenceWithDifferentKeyIsRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let taskID = UUID()
        let original = makeCheckpoint(
            taskID: taskID,
            idempotencyKey: "chapter-1.plan.v1",
            sequence: 1,
            hash: "plan"
        )
        let conflicting = makeCheckpoint(
            taskID: taskID,
            idempotencyKey: "chapter-1.prose.v1",
            sequence: 1,
            hash: "prose"
        )
        try await store.save(original)

        do {
            try await store.save(conflicting)
            XCTFail("Expected sequence conflict")
        } catch let error as CheckpointStoreError {
            XCTAssertEqual(
                error,
                .sequenceConflict(existing: original, incoming: conflicting)
            )
        }
    }

    func testLoadingJSONWithDuplicateTaskSequenceIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("checkpoints.json")
        let taskID = UUID()
        let original = makeCheckpoint(
            taskID: taskID,
            idempotencyKey: "chapter-1.plan.v1",
            sequence: 1,
            hash: "plan"
        )
        let conflicting = makeCheckpoint(
            taskID: taskID,
            idempotencyKey: "chapter-1.prose.v1",
            sequence: 1,
            hash: "prose"
        )
        try writeCheckpoints([original, conflicting], to: fileURL)

        XCTAssertThrowsError(try FileCheckpointStore(fileURL: fileURL)) { error in
            XCTAssertEqual(
                error as? CheckpointStoreError,
                .sequenceConflict(existing: original, incoming: conflicting)
            )
        }
    }

    func testSameTaskKeyAndHashWithDifferentStageIsRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let original = makeCheckpoint(stage: "plan", hash: "same")
        let conflicting = makeCheckpoint(
            id: original.id,
            taskID: original.taskID,
            idempotencyKey: original.idempotencyKey,
            stage: "prose",
            sequence: original.sequence,
            hash: original.payloadHash,
            createdAt: original.createdAt
        )
        try await store.save(original)

        do {
            try await store.save(conflicting)
            XCTFail("Expected replay metadata mismatch")
        } catch let error as CheckpointStoreError {
            XCTAssertEqual(
                error,
                .replayMetadataMismatch(existing: original, incoming: conflicting)
            )
        }
    }

    func testSameTaskKeyAndHashWithDifferentSequenceIsRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let original = makeCheckpoint(sequence: 1, hash: "same")
        let conflicting = makeCheckpoint(
            id: original.id,
            taskID: original.taskID,
            idempotencyKey: original.idempotencyKey,
            stage: original.stage,
            sequence: 2,
            hash: original.payloadHash,
            createdAt: original.createdAt
        )
        try await store.save(original)

        do {
            try await store.save(conflicting)
            XCTFail("Expected replay metadata mismatch")
        } catch let error as CheckpointStoreError {
            XCTAssertEqual(
                error,
                .replayMetadataMismatch(existing: original, incoming: conflicting)
            )
        }
    }

    func testReplayRequiresSameCheckpointIdentifier() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let original = makeCheckpoint(hash: "same")
        let conflicting = makeCheckpoint(
            taskID: original.taskID,
            idempotencyKey: original.idempotencyKey,
            stage: original.stage,
            sequence: original.sequence,
            hash: original.payloadHash,
            createdAt: original.createdAt
        )
        try await store.save(original)

        do {
            try await store.save(conflicting)
            XCTFail("Expected replay metadata mismatch")
        } catch let error as CheckpointStoreError {
            XCTAssertEqual(
                error,
                .replayMetadataMismatch(existing: original, incoming: conflicting)
            )
        }
    }

    func testLoadingJSONWithReplayMetadataConflictIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("checkpoints.json")
        let original = makeCheckpoint(sequence: 1, hash: "same")
        let conflicting = makeCheckpoint(
            id: original.id,
            taskID: original.taskID,
            idempotencyKey: original.idempotencyKey,
            stage: "different-stage",
            sequence: 2,
            hash: original.payloadHash,
            createdAt: original.createdAt
        )
        try writeCheckpoints([original, conflicting], to: fileURL)

        XCTAssertThrowsError(try FileCheckpointStore(fileURL: fileURL)) { error in
            XCTAssertEqual(
                error as? CheckpointStoreError,
                .replayMetadataMismatch(existing: original, incoming: conflicting)
            )
        }
    }

    func testInvalidCheckpointFieldsAreRejected() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let taskID = UUID()
        let cases: [(TaskCheckpoint, CheckpointStoreError)] = [
            (TaskCheckpoint(taskID: taskID, idempotencyKey: " ", stage: "prose", sequence: 1, payloadHash: "hash"), .invalidIdempotencyKey),
            (TaskCheckpoint(taskID: taskID, idempotencyKey: "key", stage: " ", sequence: 1, payloadHash: "hash"), .invalidStage),
            (TaskCheckpoint(taskID: taskID, idempotencyKey: "key", stage: "prose", sequence: 0, payloadHash: "hash"), .invalidSequence),
            (TaskCheckpoint(taskID: taskID, idempotencyKey: "key", stage: "prose", sequence: 1, payloadHash: " "), .invalidPayloadHash)
        ]

        for (checkpoint, expectedError) in cases {
            do {
                try await store.save(checkpoint)
                XCTFail("Expected invalid checkpoint to be rejected")
            } catch let error as CheckpointStoreError {
                XCTAssertEqual(error, expectedError)
            }
        }
    }

    func testSameIdempotencyKeyInDifferentTasksDoesNotOverwriteCheckpoint() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try FileCheckpointStore(fileURL: directory.appendingPathComponent("checkpoints.json"))
        let firstTaskID = UUID()
        let secondTaskID = UUID()
        let first = makeCheckpoint(taskID: firstTaskID, sequence: 1, hash: "first")
        let second = makeCheckpoint(taskID: secondTaskID, sequence: 1, hash: "second")

        try await store.save(first)
        try await store.save(second)

        let restoredFirst = try await store.checkpoint(
            taskID: firstTaskID,
            idempotencyKey: first.idempotencyKey
        )
        let restoredSecond = try await store.checkpoint(
            taskID: secondTaskID,
            idempotencyKey: second.idempotencyKey
        )
        XCTAssertEqual(restoredFirst, first)
        XCTAssertEqual(restoredSecond, second)
    }

    private func writeCheckpoints(_ checkpoints: [TaskCheckpoint], to fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(checkpoints).write(to: fileURL, options: .atomic)
    }

    private func makeCheckpoint(
        id: UUID = UUID(),
        taskID: UUID = UUID(),
        idempotencyKey: String = "chapter-1.prose.v1",
        stage: String = "prose",
        sequence: Int = 1,
        hash: String,
        createdAt: Date? = nil
    ) -> TaskCheckpoint {
        TaskCheckpoint(
            id: id,
            taskID: taskID,
            idempotencyKey: idempotencyKey,
            stage: stage,
            sequence: sequence,
            payloadHash: hash,
            createdAt: createdAt ?? Date(timeIntervalSince1970: TimeInterval(sequence))
        )
    }
}
