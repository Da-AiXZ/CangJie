//
//  WorldlineModels.swift
//  Cangjie
//
//  世界线 Git 图数据模型，对齐原版 api/worldline.ts:6-50 + confluence.ts:3-14。
//

import Foundation

// MARK: - 世界线图 — worldline.ts:38-43

/// 世界线图，对应原版 worldline.ts:38-43 `WorldlineGraph`
struct WorldlineGraph: Codable, Equatable {
    let nodes: [WorldlineCheckpointNode]
    let edges: [WorldlineEdge]
    let branches: [WorldlineBranchInfo]
    let headId: String?

    enum CodingKeys: String, CodingKey {
        case nodes, edges, branches
        case headId = "head_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodes = try c.decodeIfPresent([WorldlineCheckpointNode].self, forKey: .nodes) ?? []
        self.edges = try c.decodeIfPresent([WorldlineEdge].self, forKey: .edges) ?? []
        self.branches = try c.decodeIfPresent([WorldlineBranchInfo].self, forKey: .branches) ?? []
        self.headId = try c.decodeIfPresent(String.self, forKey: .headId)
    }

    init(nodes: [WorldlineCheckpointNode] = [],
         edges: [WorldlineEdge] = [],
         branches: [WorldlineBranchInfo] = [],
         headId: String? = nil) {
        self.nodes = nodes
        self.edges = edges
        self.branches = branches
        self.headId = headId
    }
}

// MARK: - 检查点节点 — worldline.ts:6-28

/// 世界线检查点节点，对应原版 worldline.ts:6-28 `CheckpointNode`
struct WorldlineCheckpointNode: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let triggerType: String
    let branchName: String
    let createdAt: String
    let anchorChapter: Int?
    let worldSlice: WorldSlice?
    let rollbackSlice: RollbackSlice?

    enum CodingKeys: String, CodingKey {
        case id, name
        case triggerType = "trigger_type"
        case branchName = "branch_name"
        case createdAt = "created_at"
        case anchorChapter = "anchor_chapter"
        case worldSlice = "world_slice"
        case rollbackSlice = "rollback_slice"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.triggerType = try c.decodeIfPresent(String.self, forKey: .triggerType) ?? ""
        self.branchName = try c.decodeIfPresent(String.self, forKey: .branchName) ?? "main"
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.anchorChapter = try c.decodeIfPresent(Int.self, forKey: .anchorChapter)
        self.worldSlice = try c.decodeIfPresent(WorldSlice.self, forKey: .worldSlice)
        self.rollbackSlice = try c.decodeIfPresent(RollbackSlice.self, forKey: .rollbackSlice)
    }

    init(id: String = "", name: String = "", triggerType: String = "",
         branchName: String = "main", createdAt: String = "",
         anchorChapter: Int? = nil,
         worldSlice: WorldSlice? = nil,
         rollbackSlice: RollbackSlice? = nil) {
        self.id = id
        self.name = name
        self.triggerType = triggerType
        self.branchName = branchName
        self.createdAt = createdAt
        self.anchorChapter = anchorChapter
        self.worldSlice = worldSlice
        self.rollbackSlice = rollbackSlice
    }
}

// MARK: - 世界切片 — worldline.ts:10-22

/// 世界切片，对应原版 worldline.ts:10-22 `CheckpointNode.world_slice`
struct WorldSlice: Codable, Equatable {
    let chapterNumber: Int?
    let timeAnchor: String?
    let location: String?
    let emotionalResidue: String?
    let characters: [WorldSliceCharacter]?
    let items: [WorldSliceItem]?
    let actionsCount: Int?
    let conflictsCount: Int?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case timeAnchor = "time_anchor"
        case location
        case emotionalResidue = "emotional_residue"
        case characters, items
        case actionsCount = "actions_count"
        case conflictsCount = "conflicts_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.timeAnchor = try c.decodeIfPresent(String.self, forKey: .timeAnchor)
        self.location = try c.decodeIfPresent(String.self, forKey: .location)
        self.emotionalResidue = try c.decodeIfPresent(String.self, forKey: .emotionalResidue)
        self.characters = try c.decodeIfPresent([WorldSliceCharacter].self, forKey: .characters)
        self.items = try c.decodeIfPresent([WorldSliceItem].self, forKey: .items)
        self.actionsCount = try c.decodeIfPresent(Int.self, forKey: .actionsCount)
        self.conflictsCount = try c.decodeIfPresent(Int.self, forKey: .conflictsCount)
    }

    init(chapterNumber: Int? = nil,
         timeAnchor: String? = nil,
         location: String? = nil,
         emotionalResidue: String? = nil,
         characters: [WorldSliceCharacter]? = nil,
         items: [WorldSliceItem]? = nil,
         actionsCount: Int? = nil,
         conflictsCount: Int? = nil) {
        self.chapterNumber = chapterNumber
        self.timeAnchor = timeAnchor
        self.location = location
        self.emotionalResidue = emotionalResidue
        self.characters = characters
        self.items = items
        self.actionsCount = actionsCount
        self.conflictsCount = conflictsCount
    }
}

/// 世界切片中的角色 — worldline.ts:14-17
struct WorldSliceCharacter: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let status: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status, location
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.location = try c.decodeIfPresent(String.self, forKey: .location)
    }

    init(id: String = "", name: String = "",
         status: String? = nil, location: String? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.location = location
    }
}

/// 世界切片中的物品 — worldline.ts:18-21
struct WorldSliceItem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let holder: String?

    enum CodingKeys: String, CodingKey {
        case id, name, holder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.holder = try c.decodeIfPresent(String.self, forKey: .holder)
    }

    init(id: String = "", name: String = "", holder: String? = nil) {
        self.id = id
        self.name = name
        self.holder = holder
    }
}

// MARK: - 回滚切片 — worldline.ts:24-27

/// 回滚切片，对应原版 worldline.ts:24-27 `CheckpointNode.rollback_slice`
struct RollbackSlice: Codable, Equatable {
    let toCheckpointId: String
    let toChapter: Int
    let branchName: String

    enum CodingKeys: String, CodingKey {
        case toCheckpointId = "to_checkpoint_id"
        case toChapter = "to_chapter"
        case branchName = "branch_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.toCheckpointId = try c.decodeIfPresent(String.self, forKey: .toCheckpointId) ?? ""
        self.toChapter = try c.decodeIfPresent(Int.self, forKey: .toChapter) ?? 0
        self.branchName = try c.decodeIfPresent(String.self, forKey: .branchName) ?? "main"
    }

    init(toCheckpointId: String = "", toChapter: Int = 0, branchName: String = "main") {
        self.toCheckpointId = toCheckpointId
        self.toChapter = toChapter
        self.branchName = branchName
    }
}

// MARK: - 分支信息 — worldline.ts:30-36

/// 分支信息，对应原版 worldline.ts:30-36 `BranchInfo`
struct WorldlineBranchInfo: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let headId: String?
    let isDefault: Int
    let storylineId: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case headId = "head_id"
        case isDefault = "is_default"
        case storylineId = "storyline_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? "main"
        self.headId = try c.decodeIfPresent(String.self, forKey: .headId)
        self.isDefault = try c.decodeIfPresent(Int.self, forKey: .isDefault) ?? 0
        self.storylineId = try c.decodeIfPresent(String.self, forKey: .storylineId)
    }

    init(id: String = "", name: String = "main",
         headId: String? = nil, isDefault: Int = 0,
         storylineId: String? = nil) {
        self.id = id
        self.name = name
        self.headId = headId
        self.isDefault = isDefault
        self.storylineId = storylineId
    }
}

// MARK: - 世界线边 — worldline.ts:40-42

/// 世界线边，对应原版 worldline.ts:40-42 `edges`
struct WorldlineEdge: Codable, Equatable {
    let from: String
    let to: String
    let kind: String?

    enum CodingKeys: String, CodingKey {
        case from, to, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.from = try c.decodeIfPresent(String.self, forKey: .from) ?? ""
        self.to = try c.decodeIfPresent(String.self, forKey: .to) ?? ""
        self.kind = try c.decodeIfPresent(String.self, forKey: .kind)
    }

    init(from: String = "", to: String = "", kind: String? = nil) {
        self.from = from
        self.to = to
        self.kind = kind
    }
}

// MARK: - 切换/重置结果 — worldline.ts:45-50

/// 切换/重置结果，对应原版 worldline.ts:45-50 `CheckoutResult`
struct WorldlineCheckoutResult: Codable, Equatable {
    let stashId: String?
    let restoredChapters: Int?
    let deletedChapters: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case stashId = "stash_id"
        case restoredChapters = "restored_chapters"
        case deletedChapters = "deleted_chapters"
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stashId = try c.decodeIfPresent(String.self, forKey: .stashId)
        self.restoredChapters = try c.decodeIfPresent(Int.self, forKey: .restoredChapters)
        self.deletedChapters = try c.decodeIfPresent(Int.self, forKey: .deletedChapters)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
    }

    init(stashId: String? = nil,
         restoredChapters: Int? = nil,
         deletedChapters: Int? = nil,
         message: String? = nil) {
        self.stashId = stashId
        self.restoredChapters = restoredChapters
        self.deletedChapters = deletedChapters
        self.message = message
    }
}

// MARK: - 创建检查点请求 — worldline.ts:59-65

/// 创建检查点请求，对应原版 worldline.ts:59-65
struct CreateWorldlineCheckpointRequest: Codable {
    let triggerType: String?
    let name: String
    let description: String?
    let branchName: String?

    enum CodingKeys: String, CodingKey {
        case triggerType = "trigger_type"
        case name, description
        case branchName = "branch_name"
    }
}

/// 创建检查点响应，对应原版 worldline.ts:64 `{ checkpoint_id }`
struct CreateWorldlineCheckpointResponse: Codable {
    let checkpointId: String?

    enum CodingKeys: String, CodingKey {
        case checkpointId = "checkpoint_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.checkpointId = try c.decodeIfPresent(String.self, forKey: .checkpointId)
    }
}

// MARK: - 创建分支请求 — worldline.ts:70-74

/// 创建分支请求，对应原版 worldline.ts:70-74
struct CreateWorldlineBranchRequest: Codable {
    let name: String
    let fromCheckpointId: String
    let storylineId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fromCheckpointId = "from_checkpoint_id"
        case storylineId = "storyline_id"
    }
}

/// 创建分支响应，对应原版 worldline.ts:73 `{ branch_id }`
struct CreateWorldlineBranchResponse: Codable {
    let branchId: String?

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.branchId = try c.decodeIfPresent(String.self, forKey: .branchId)
    }
}

// MARK: - 合并分支请求 — worldline.ts:106-114

/// 合并分支请求，对应原版 worldline.ts:106-114
struct MergeWorldlineBranchRequest: Codable {
    let targetBranchName: String?
    let name: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case targetBranchName = "target_branch_name"
        case name, description
    }
}

/// 合并分支响应，对应原版 worldline.ts:113 `{ checkpoint_id, message }`
struct MergeWorldlineBranchResponse: Codable {
    let checkpointId: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case checkpointId = "checkpoint_id"
        case message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.checkpointId = try c.decodeIfPresent(String.self, forKey: .checkpointId)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
    }
}

// MARK: - 汇流点 — confluence.ts:3-14, workflow.ts:50-61

/// 汇流点 DTO，对应原版 workflow.ts:50-61 `ConfluencePointDTO`
struct ConfluencePointDTO: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let sourceStorylineId: String
    let targetStorylineId: String
    let targetChapter: Int
    let mergeType: String
    let contextSummary: String?
    let preRevealHint: String?
    let behaviorGuards: [String]?
    let resolved: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case sourceStorylineId = "source_storyline_id"
        case targetStorylineId = "target_storyline_id"
        case targetChapter = "target_chapter"
        case mergeType = "merge_type"
        case contextSummary = "context_summary"
        case preRevealHint = "pre_reveal_hint"
        case behaviorGuards = "behavior_guards"
        case resolved
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.sourceStorylineId = try c.decodeIfPresent(String.self, forKey: .sourceStorylineId) ?? ""
        self.targetStorylineId = try c.decodeIfPresent(String.self, forKey: .targetStorylineId) ?? ""
        self.targetChapter = try c.decodeIfPresent(Int.self, forKey: .targetChapter) ?? 0
        self.mergeType = try c.decodeIfPresent(String.self, forKey: .mergeType) ?? "intersect"
        self.contextSummary = try c.decodeIfPresent(String.self, forKey: .contextSummary)
        self.preRevealHint = try c.decodeIfPresent(String.self, forKey: .preRevealHint)
        self.behaviorGuards = try c.decodeIfPresent([String].self, forKey: .behaviorGuards)
        self.resolved = try c.decodeIfPresent(Bool.self, forKey: .resolved) ?? false
    }

    init(id: String = "", novelId: String = "",
         sourceStorylineId: String = "", targetStorylineId: String = "",
         targetChapter: Int = 0, mergeType: String = "intersect",
         contextSummary: String? = nil, preRevealHint: String? = nil,
         behaviorGuards: [String]? = nil, resolved: Bool = false) {
        self.id = id
        self.novelId = novelId
        self.sourceStorylineId = sourceStorylineId
        self.targetStorylineId = targetStorylineId
        self.targetChapter = targetChapter
        self.mergeType = mergeType
        self.contextSummary = contextSummary
        self.preRevealHint = preRevealHint
        self.behaviorGuards = behaviorGuards
        self.resolved = resolved
    }
}
