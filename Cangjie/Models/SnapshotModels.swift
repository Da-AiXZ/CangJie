//
//  SnapshotModels.swift
//  Cangjie
//
//  快照与检查点模型，字段对齐后端：
//  - interfaces/api/v1/engine/snapshot_routes.py 的 UnifiedSnapshotDTO
//  - interfaces/api/v1/engine/checkpoint_routes.py 的 CheckpointDTO
//

import Foundation

// MARK: - 统一快照

/// 统一快照 DTO，对应后端 UnifiedSnapshotDTO
struct UnifiedSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let parentSnapshotId: String?
    let branchName: String
    let triggerType: String
    let name: String
    let description: String?
    let chapterPointers: [String]
    let storyState: [String: AnyCodable]
    let characterMasks: [String: AnyCodable]
    let emotionLedger: [String: AnyCodable]
    let activeForeshadows: [String]
    let outline: String
    let recentChaptersSummary: String
    let createdAt: String
    let bibleState: [String: AnyCodable]
    let foreshadowState: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case parentSnapshotId = "parent_snapshot_id"
        case branchName = "branch_name"
        case triggerType = "trigger_type"
        case name, description
        case chapterPointers = "chapter_pointers"
        case storyState = "story_state"
        case characterMasks = "character_masks"
        case emotionLedger = "emotion_ledger"
        case activeForeshadows = "active_foreshadows"
        case outline
        case recentChaptersSummary = "recent_chapters_summary"
        case createdAt = "created_at"
        case bibleState = "bible_state"
        case foreshadowState = "foreshadow_state"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.parentSnapshotId = try c.decodeIfPresent(String.self, forKey: .parentSnapshotId)
        self.branchName = try c.decodeIfPresent(String.self, forKey: .branchName) ?? "main"
        self.triggerType = try c.decodeIfPresent(String.self, forKey: .triggerType) ?? "AUTO"
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.chapterPointers = try c.decodeIfPresent([String].self, forKey: .chapterPointers) ?? []
        self.storyState = try c.decodeIfPresent([String: AnyCodable].self, forKey: .storyState) ?? [:]
        self.characterMasks = try c.decodeIfPresent([String: AnyCodable].self, forKey: .characterMasks) ?? [:]
        self.emotionLedger = try c.decodeIfPresent([String: AnyCodable].self, forKey: .emotionLedger) ?? [:]
        self.activeForeshadows = try c.decodeIfPresent([String].self, forKey: .activeForeshadows) ?? []
        self.outline = try c.decodeIfPresent(String.self, forKey: .outline) ?? ""
        self.recentChaptersSummary = try c.decodeIfPresent(String.self, forKey: .recentChaptersSummary) ?? ""
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.bibleState = try c.decodeIfPresent([String: AnyCodable].self, forKey: .bibleState) ?? [:]
        self.foreshadowState = try c.decodeIfPresent([String: AnyCodable].self, forKey: .foreshadowState) ?? [:]
    }
}

// MARK: - 快照列表响应

/// 快照列表响应，对应后端 UnifiedSnapshotListResponse
struct UnifiedSnapshotListResponse: Codable, Equatable {
    let snapshots: [UnifiedSnapshot]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.snapshots = try c.decodeIfPresent([UnifiedSnapshot].self, forKey: .snapshots) ?? []
    }
}

// MARK: - 创建快照请求

/// 创建快照请求，对应后端 CreateSnapshotRequest
struct CreateSnapshotRequest: Codable {
    let triggerType: String
    let name: String
    let description: String?
    let chapterNumber: Int?
    let storyState: [String: AnyCodable]?
    let characterMasks: [String: AnyCodable]?
    let emotionLedger: [String: AnyCodable]?
    let activeForeshadows: [String]?
    let outline: String?
    let recentSummary: String?

    enum CodingKeys: String, CodingKey {
        case triggerType = "trigger_type"
        case name, description
        case chapterNumber = "chapter_number"
        case storyState = "story_state"
        case characterMasks = "character_masks"
        case emotionLedger = "emotion_ledger"
        case activeForeshadows = "active_foreshadows"
        case outline
        case recentSummary = "recent_summary"
    }
}

// MARK: - 创建快照响应

/// 创建快照响应
struct CreateSnapshotResponse: Codable, Equatable {
    let snapshotId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.snapshotId = try c.decodeIfPresent(String.self, forKey: .snapshotId) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? "快照已创建"
    }
}

// MARK: - 快照回滚响应

/// 快照回滚响应
struct SnapshotRollbackResponse: Codable, Equatable {
    let deletedChapterIds: [String]
    let deletedCount: Int
    let hasEngineState: Bool

    enum CodingKeys: String, CodingKey {
        case deletedChapterIds = "deleted_chapter_ids"
        case deletedCount = "deleted_count"
        case hasEngineState = "has_engine_state"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.deletedChapterIds = try c.decodeIfPresent([String].self, forKey: .deletedChapterIds) ?? []
        self.deletedCount = try c.decodeIfPresent(Int.self, forKey: .deletedCount) ?? 0
        self.hasEngineState = try c.decodeIfPresent(Bool.self, forKey: .hasEngineState) ?? false
    }
}

// MARK: - 检查点

/// 检查点 DTO，对应后端 CheckpointDTO
struct CheckpointDTO: Codable, Identifiable, Equatable {
    let id: String
    let storyId: String
    let triggerType: String
    let triggerReason: String
    let parentId: String?
    let chapterNumber: Int?
    let createdAt: String
    let isHead: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case storyId = "story_id"
        case triggerType = "trigger_type"
        case triggerReason = "trigger_reason"
        case parentId = "parent_id"
        case chapterNumber = "chapter_number"
        case createdAt = "created_at"
        case isHead = "is_head"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.storyId = try c.decodeIfPresent(String.self, forKey: .storyId) ?? ""
        self.triggerType = try c.decodeIfPresent(String.self, forKey: .triggerType) ?? ""
        self.triggerReason = try c.decodeIfPresent(String.self, forKey: .triggerReason) ?? ""
        self.parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.isHead = try c.decodeIfPresent(Bool.self, forKey: .isHead) ?? false
    }
}

// MARK: - 检查点列表响应

/// 检查点列表响应
struct CheckpointListResponse: Codable, Equatable {
    let checkpoints: [CheckpointDTO]
    let headId: String?

    enum CodingKeys: String, CodingKey {
        case checkpoints
        case headId = "head_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.checkpoints = try c.decodeIfPresent([CheckpointDTO].self, forKey: .checkpoints) ?? []
        self.headId = try c.decodeIfPresent(String.self, forKey: .headId)
    }
}

// MARK: - 创建检查点请求

/// 创建检查点请求
struct CreateCheckpointRequest: Codable {
    let reason: String
    let chapterNumber: Int?

    enum CodingKeys: String, CodingKey {
        case reason
        case chapterNumber = "chapter_number"
    }
}

/// 创建检查点响应
struct CreateCheckpointResponse: Codable, Equatable {
    let checkpointId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case checkpointId = "checkpoint_id"
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.checkpointId = try c.decodeIfPresent(String.self, forKey: .checkpointId) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? "Checkpoint已创建"
    }
}

// MARK: - 回滚响应

/// 检查点回滚响应
struct RollbackResponse: Codable, Equatable {
    let checkpointId: String
    let triggerReason: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case checkpointId = "checkpoint_id"
        case triggerReason = "trigger_reason"
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.checkpointId = try c.decodeIfPresent(String.self, forKey: .checkpointId) ?? ""
        self.triggerReason = try c.decodeIfPresent(String.self, forKey: .triggerReason) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? "已回滚"
    }
}

// MARK: - 故事阶段

/// 故事阶段 DTO
struct StoryPhase: Codable, Equatable {
    let phase: String
    let progress: Double
    let description: String
    let canAdvance: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase) ?? "setup"
        self.progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.canAdvance = try c.decodeIfPresent(Bool.self, forKey: .canAdvance) ?? false
    }
}

// MARK: - 角色心理

/// 角色心理 DTO
struct CharacterPsyche: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let role: String
    let coreBelief: String
    let taboo: String
    let voiceTag: String
    let wound: String
    let traumaCount: Int

    enum CodingKeys: String, CodingKey {
        case name, role, taboo, wound
        case coreBelief = "core_belief"
        case voiceTag = "voice_tag"
        case traumaCount = "trauma_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        self.coreBelief = try c.decodeIfPresent(String.self, forKey: .coreBelief) ?? ""
        self.taboo = try c.decodeIfPresent(String.self, forKey: .taboo) ?? ""
        self.voiceTag = try c.decodeIfPresent(String.self, forKey: .voiceTag) ?? ""
        self.wound = try c.decodeIfPresent(String.self, forKey: .wound) ?? ""
        self.traumaCount = try c.decodeIfPresent(Int.self, forKey: .traumaCount) ?? 0
    }
}

/// 角色心理列表响应
struct CharacterPsycheListResponse: Codable, Equatable {
    let characters: [CharacterPsyche]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.characters = try c.decodeIfPresent([CharacterPsyche].self, forKey: .characters) ?? []
    }
}
