import Foundation

public struct TaskCheckpoint: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let taskID: UUID
    public let idempotencyKey: String
    public let stage: String
    public let sequence: Int
    public let payloadHash: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        idempotencyKey: String,
        stage: String,
        sequence: Int,
        payloadHash: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.idempotencyKey = idempotencyKey
        self.stage = stage
        self.sequence = sequence
        self.payloadHash = payloadHash
        self.createdAt = createdAt
    }
}

public enum CheckpointStoreError: Error, Equatable, Sendable {
    case invalidIdempotencyKey
    case invalidStage
    case invalidSequence
    case invalidPayloadHash
    case payloadMismatch(existing: TaskCheckpoint, incoming: TaskCheckpoint)
    case replayMetadataMismatch(existing: TaskCheckpoint, incoming: TaskCheckpoint)
    case sequenceConflict(existing: TaskCheckpoint, incoming: TaskCheckpoint)
}

public protocol CheckpointStore: Sendable {
    func save(_ checkpoint: TaskCheckpoint) async throws
    func latest(taskID: UUID) async throws -> TaskCheckpoint?
    func checkpoint(taskID: UUID, idempotencyKey: String) async throws -> TaskCheckpoint?
}

public enum RecoveryAction: Equatable, Sendable {
    case execute
    case reuse(TaskCheckpoint)
    case rejectPayloadMismatch(existing: TaskCheckpoint)
}

public struct RecoveryPlanner: Sendable {
    public init() {}

    public func action(
        taskID: UUID,
        idempotencyKey: String,
        payloadHash: String,
        existing: TaskCheckpoint?
    ) -> RecoveryAction {
        guard let existing else { return .execute }
        guard existing.taskID == taskID else { return .execute }
        guard existing.idempotencyKey == idempotencyKey else { return .execute }
        guard existing.payloadHash == payloadHash else {
            return .rejectPayloadMismatch(existing: existing)
        }
        return .reuse(existing)
    }
}

public actor FileCheckpointStore: CheckpointStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var checkpoints: [TaskCheckpoint]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder.dateDecodingStrategy = .iso8601

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            let decoded = try self.decoder.decode([TaskCheckpoint].self, from: data)
            try Self.validateLoadedCheckpoints(decoded)
            self.checkpoints = decoded
        } else {
            self.checkpoints = []
        }
    }

    public func save(_ checkpoint: TaskCheckpoint) async throws {
        try Self.validateFields(of: checkpoint)

        if let existing = checkpoints.first(where: {
            $0.taskID == checkpoint.taskID && $0.idempotencyKey == checkpoint.idempotencyKey
        }) {
            try Self.validateReplay(existing: existing, incoming: checkpoint)
            return
        }

        if let existing = checkpoints.first(where: {
            $0.taskID == checkpoint.taskID && $0.sequence == checkpoint.sequence
        }) {
            throw CheckpointStoreError.sequenceConflict(existing: existing, incoming: checkpoint)
        }

        let updated = (checkpoints + [checkpoint]).sorted {
            if $0.taskID == $1.taskID { return $0.sequence < $1.sequence }
            return $0.createdAt < $1.createdAt
        }
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try encoder.encode(updated)
        try data.write(to: fileURL, options: .atomic)
        checkpoints = updated
    }

    public func latest(taskID: UUID) async throws -> TaskCheckpoint? {
        checkpoints.filter { $0.taskID == taskID }.max { $0.sequence < $1.sequence }
    }

    public func checkpoint(taskID: UUID, idempotencyKey: String) async throws -> TaskCheckpoint? {
        checkpoints.first {
            $0.taskID == taskID && $0.idempotencyKey == idempotencyKey
        }
    }

    private static func validateLoadedCheckpoints(_ checkpoints: [TaskCheckpoint]) throws {
        var validated: [TaskCheckpoint] = []
        validated.reserveCapacity(checkpoints.count)

        for checkpoint in checkpoints {
            try validateFields(of: checkpoint)

            if let existing = validated.first(where: {
                $0.taskID == checkpoint.taskID && $0.sequence == checkpoint.sequence
            }) {
                throw CheckpointStoreError.sequenceConflict(existing: existing, incoming: checkpoint)
            }

            if let existing = validated.first(where: {
                $0.taskID == checkpoint.taskID && $0.idempotencyKey == checkpoint.idempotencyKey
            }) {
                try validateReplay(existing: existing, incoming: checkpoint)
            }

            validated.append(checkpoint)
        }
    }

    private static func validateFields(of checkpoint: TaskCheckpoint) throws {
        guard !checkpoint.idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CheckpointStoreError.invalidIdempotencyKey
        }
        guard !checkpoint.stage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CheckpointStoreError.invalidStage
        }
        guard checkpoint.sequence > 0 else {
            throw CheckpointStoreError.invalidSequence
        }
        guard !checkpoint.payloadHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CheckpointStoreError.invalidPayloadHash
        }
    }

    private static func validateReplay(
        existing: TaskCheckpoint,
        incoming: TaskCheckpoint
    ) throws {
        guard existing.payloadHash == incoming.payloadHash else {
            throw CheckpointStoreError.payloadMismatch(existing: existing, incoming: incoming)
        }

        // The stored UUID identifies the checkpoint record. A replay is a no-op only
        // when all persisted identity metadata matches; callers must reuse that UUID.
        guard existing.id == incoming.id,
              existing.stage == incoming.stage,
              existing.sequence == incoming.sequence,
              existing.createdAt == incoming.createdAt else {
            throw CheckpointStoreError.replayMetadataMismatch(existing: existing, incoming: incoming)
        }
    }
}
