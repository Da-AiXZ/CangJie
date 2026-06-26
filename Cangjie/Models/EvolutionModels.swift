//
//  EvolutionModels.swift
//  Cangjie
//
//  故事演化模型，字段对齐后端 interfaces/api/v1/engine/evolution_routes.py。
//  以及 domain/evolution/models.py。
//

import Foundation

// MARK: - 演化快照

/// 演化快照，字段对齐原版 evolution.ts:3-19 EvolutionSnapshot
struct EvolutionSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let branchId: String
    let chapterNumber: Int
    let schemaVersion: String
    let status: String
    let openingState: AnyCodable?
    let deltaActions: [AnyCodable]
    let machineState: AnyCodable?
    let humanOverridePatches: [AnyCodable]
    let endingState: AnyCodable?
    let sourceRefs: [AnyCodable]
    let conflicts: [AnyCodable]
    let snapshotData: AnyCodable
    let violations: [AnyCodable]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "snapshot_id"
        case novelId = "novel_id"
        case branchId = "branch_id"
        case chapterNumber = "chapter_number"
        case schemaVersion = "schema_version"
        case status
        case openingState = "opening_state"
        case deltaActions = "delta_actions"
        case machineState = "machine_state"
        case humanOverridePatches = "human_override_patches"
        case endingState = "ending_state"
        case sourceRefs = "source_refs"
        case conflicts
        case snapshotData = "snapshot"
        case violations
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.branchId = try c.decodeIfPresent(String.self, forKey: .branchId) ?? "main"
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.schemaVersion = try c.decodeIfPresent(String.self, forKey: .schemaVersion) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        self.openingState = try c.decodeIfPresent(AnyCodable.self, forKey: .openingState)
        self.deltaActions = try c.decodeIfPresent([AnyCodable].self, forKey: .deltaActions) ?? []
        self.machineState = try c.decodeIfPresent(AnyCodable.self, forKey: .machineState)
        self.humanOverridePatches = try c.decodeIfPresent([AnyCodable].self, forKey: .humanOverridePatches) ?? []
        self.endingState = try c.decodeIfPresent(AnyCodable.self, forKey: .endingState)
        self.sourceRefs = try c.decodeIfPresent([AnyCodable].self, forKey: .sourceRefs) ?? []
        self.conflicts = try c.decodeIfPresent([AnyCodable].self, forKey: .conflicts) ?? []
        self.snapshotData = try c.decodeIfPresent(AnyCodable.self, forKey: .snapshotData) ?? AnyCodable([:])
        self.violations = try c.decodeIfPresent([AnyCodable].self, forKey: .violations)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    /// 显式 memberwise init（T04教训8）
    init(id: String, novelId: String, branchId: String, chapterNumber: Int,
         schemaVersion: String, status: String,
         openingState: AnyCodable?, deltaActions: [AnyCodable],
         machineState: AnyCodable?, humanOverridePatches: [AnyCodable],
         endingState: AnyCodable?, sourceRefs: [AnyCodable], conflicts: [AnyCodable],
         snapshotData: AnyCodable, violations: [AnyCodable]?, createdAt: String?) {
        self.id = id
        self.novelId = novelId
        self.branchId = branchId
        self.chapterNumber = chapterNumber
        self.schemaVersion = schemaVersion
        self.status = status
        self.openingState = openingState
        self.deltaActions = deltaActions
        self.machineState = machineState
        self.humanOverridePatches = humanOverridePatches
        self.endingState = endingState
        self.sourceRefs = sourceRefs
        self.conflicts = conflicts
        self.snapshotData = snapshotData
        self.violations = violations
        self.createdAt = createdAt
    }
}

// MARK: - 演化快照列表响应

/// 演化快照列表响应（GET /novels/{id}/evolution/snapshots）
struct EvolutionSnapshotListResponse: Codable, Equatable {
    let novelId: String
    let branchId: String
    let snapshots: [EvolutionSnapshot]
    let counts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case snapshots, counts
        case novelId = "novel_id"
        case branchId = "branch_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.branchId = try c.decodeIfPresent(String.self, forKey: .branchId) ?? "main"
        self.snapshots = try c.decodeIfPresent([EvolutionSnapshot].self, forKey: .snapshots) ?? []
        self.counts = try c.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:]
    }
}

// MARK: - 闸门请求

/// 闸门请求，对应后端 GateRequest
struct EvolutionGateRequest: Codable {
    let chapterNumber: Int
    let branchId: String
    let outlineContent: String
    let povCharacterId: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case branchId = "branch_id"
        case outlineContent = "outline_content"
        case povCharacterId = "pov_character_id"
        case tags
    }
}

// MARK: - 闸门违规项

/// 闸门违规项，对齐原版 api/evolution.ts:30-35 violations 数组元素。
///
/// C-3：将 EvolutionGateReport.violations 从 [AnyCodable] 结构化为 [GateViolation]。
struct GateViolation: Codable, Equatable {

    /// 违规级别（error / warning / info）
    let level: String

    /// 违规类型
    let type: String

    /// 违规消息
    let message: String

    /// 修复建议（可选）
    let suggestion: String?

    enum CodingKeys: String, CodingKey {
        case level, type, message, suggestion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.level = try c.decodeIfPresent(String.self, forKey: .level) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.suggestion = try c.decodeIfPresent(String.self, forKey: .suggestion)
    }

    init(level: String, type: String, message: String, suggestion: String? = nil) {
        self.level = level
        self.type = type
        self.message = message
        self.suggestion = suggestion
    }
}

// MARK: - 闸门响应

/// 闸门检查响应（POST /novels/{id}/evolution/gate），后端返回 report.to_dict()
///
/// C-3：violations 从 [AnyCodable]? 结构化为 [GateViolation]?；
/// 补齐 requiredContinuations / repairPlan 字段（对齐 evolution.ts:36-37）。
struct EvolutionGateReport: Codable, Equatable {
    let chapterNumber: Int
    let branchId: String
    let passed: Bool?
    let violations: [GateViolation]?
    let requiredContinuations: [String]?
    let repairPlan: [String]?
    let governanceBudget: AnyCodable?
    let governanceContextRequest: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case passed = "is_pass", violations
        case chapterNumber = "chapter_number"
        case branchId = "branch_id"
        case requiredContinuations = "required_continuations"
        case repairPlan = "repair_plan"
        case governanceBudget = "governance_budget"
        case governanceContextRequest = "governance_context_request"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.chapterNumber = dict["chapter_number"]?.intValue ?? 0
        self.branchId = dict["branch_id"]?.stringStringValue ?? "main"
        self.passed = dict["is_pass"]?.boolValue
        // violations: 逐元素解码为 GateViolation
        if let violationsArray = dict["violations"]?.arrayValue {
            let jsonDecoder = CangjieDecoder.shared
            self.violations = violationsArray.compactMap { item in
                guard let data = try? JSONSerialization.data(withJSONObject: item, options: []) else { return nil }
                return try? jsonDecoder.decode(GateViolation.self, from: data)
            }
        } else {
            self.violations = nil
        }
        // requiredContinuations: 字符串数组
        if let contArray = dict["required_continuations"]?.arrayValue {
            self.requiredContinuations = contArray.compactMap { $0 as? String }
        } else {
            self.requiredContinuations = nil
        }
        // repairPlan: 字符串数组
        if let planArray = dict["repair_plan"]?.arrayValue {
            self.repairPlan = planArray.compactMap { $0 as? String }
        } else {
            self.repairPlan = nil
        }
        self.governanceBudget = dict["governance_budget"].map { AnyCodable($0) }
        self.governanceContextRequest = dict["governance_context_request"].map { AnyCodable($0) }
    }
}

// MARK: - 覆盖请求 — evolution.ts:69-73

/// JSON Patch 操作 — RFC 6902 op: replace/add/remove
struct JSONPatchOp: Codable, Equatable {
    let op: String
    let path: String
    let value: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case op, path, value
    }
}

/// 覆盖请求，对应原版 evolution.ts:69-73 applyOverrides
/// body: { branch_id, patches: [{op, path, value}] }
struct EvolutionOverrideRequest: Codable {
    let branchId: String
    let patches: [JSONPatchOp]

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
        case patches
    }
}

// MARK: - 剧情大纲 DTO（PlotOutlineDTO/PlotOutlineStageDTO/GeneratePlotOutlineResponse）
// 注意：这三个类型定义在 PlotOutlineModels.swift 中（字段更完整，含 memberwise init）
// 此处不再重复声明，避免 "ambiguous for type lookup" 编译错误（教训10：新建类型前必须 Grep 查同名）

// MARK: - 回放请求

/// 回放请求，对应后端 ReplayRequest
struct EvolutionReplayRequest: Codable {
    let branchId: String

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
    }
}

// MARK: - 演化时间线

/// 演化时间线（聚合多个快照的章节数据）
struct EvolutionTimeline: Equatable {
    let snapshots: [EvolutionSnapshot]
    let counts: [String: Int]
}

// MARK: - StoryEvolutionReadModel — narrativeEngine.ts:9-38

/// 故事演化只读聚合模型，对齐原版 narrativeEngine.ts:9-38
struct StoryEvolutionReadModel: Codable, Equatable {
    let novelId: String
    let schemaVersion: String
    let lifeCycle: StoryPhaseDTO?
    let plotSpine: PlotSpineDTO?
    let chronotope: ChronotopeDTO?
    let chaptersDigest: [AnyCodable]
    let subtextSurface: SubtextSurfaceDTO?
    let evolutionSurface: EvolutionSurfaceDTO?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case schemaVersion = "schema_version"
        case lifeCycle = "life_cycle"
        case plotSpine = "plot_spine"
        case chronotope
        case chaptersDigest = "chapters_digest"
        case subtextSurface = "subtext_surface"
        case evolutionSurface = "evolution_surface"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.schemaVersion = try c.decodeIfPresent(String.self, forKey: .schemaVersion) ?? ""
        self.lifeCycle = try c.decodeIfPresent(StoryPhaseDTO.self, forKey: .lifeCycle)
        self.plotSpine = try c.decodeIfPresent(PlotSpineDTO.self, forKey: .plotSpine)
        self.chronotope = try c.decodeIfPresent(ChronotopeDTO.self, forKey: .chronotope)
        self.chaptersDigest = try c.decodeIfPresent([AnyCodable].self, forKey: .chaptersDigest) ?? []
        self.subtextSurface = try c.decodeIfPresent(SubtextSurfaceDTO.self, forKey: .subtextSurface)
        self.evolutionSurface = try c.decodeIfPresent(EvolutionSurfaceDTO.self, forKey: .evolutionSurface)
    }
}

/// 故事阶段 DTO — engineCore.ts StoryPhaseDTO
struct StoryPhaseDTO: Codable, Equatable {
    let phase: String?
    let progress: Double?
    let chapterRange: String?

    enum CodingKeys: String, CodingKey {
        case phase, progress
        case chapterRange = "chapter_range"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase)
        self.progress = try c.decodeIfPresent(Double.self, forKey: .progress)
        self.chapterRange = try c.decodeIfPresent(String.self, forKey: .chapterRange)
    }
}

/// 故事骨架 DTO — narrativeEngine.ts:13-16
struct PlotSpineDTO: Codable, Equatable {
    let storylines: [StorylineDTO]
    let plotArc: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case storylines
        case plotArc = "plot_arc"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.storylines = try c.decodeIfPresent([StorylineDTO].self, forKey: .storylines) ?? []
        self.plotArc = try c.decodeIfPresent(AnyCodable.self, forKey: .plotArc)
    }
}

/// 故事线 DTO — workflow.ts:31-46 StorylineDTO
struct StorylineDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let role: String?
    let status: String?
    let parentId: String?
    let estimatedChapterStart: Int?
    let estimatedChapterEnd: Int?
    let storylineType: String?
    /// 里程碑列表 — workflow.ts:40
    let milestones: [StorylineMilestoneDTO]?
    /// 当前里程碑索引 — workflow.ts:41
    let currentMilestoneIndex: Int?
    /// 最后活跃章节 — workflow.ts:42
    let lastActiveChapter: Int?
    /// 进度摘要 — workflow.ts:43
    let progressSummary: String?
    /// 章节权重 — workflow.ts:45
    let chapterWeight: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, role, status
        case parentId = "parent_id"
        case estimatedChapterStart = "estimated_chapter_start"
        case estimatedChapterEnd = "estimated_chapter_end"
        case storylineType = "storyline_type"
        case milestones
        case currentMilestoneIndex = "current_milestone_index"
        case lastActiveChapter = "last_active_chapter"
        case progressSummary = "progress_summary"
        case chapterWeight = "chapter_weight"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name)
        self.role = try c.decodeIfPresent(String.self, forKey: .role)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        self.estimatedChapterStart = try c.decodeIfPresent(Int.self, forKey: .estimatedChapterStart)
        self.estimatedChapterEnd = try c.decodeIfPresent(Int.self, forKey: .estimatedChapterEnd)
        self.storylineType = try c.decodeIfPresent(String.self, forKey: .storylineType)
        self.milestones = try c.decodeIfPresent([StorylineMilestoneDTO].self, forKey: .milestones)
        self.currentMilestoneIndex = try c.decodeIfPresent(Int.self, forKey: .currentMilestoneIndex)
        self.lastActiveChapter = try c.decodeIfPresent(Int.self, forKey: .lastActiveChapter)
        self.progressSummary = try c.decodeIfPresent(String.self, forKey: .progressSummary)
        self.chapterWeight = try c.decodeIfPresent(Int.self, forKey: .chapterWeight)
    }
}

/// 时空编年体 DTO — narrativeEngine.ts:17-21
struct ChronotopeDTO: Codable, Equatable {
    let rows: [ChronicleRow]
    let maxChapterInBook: Int
    let note: String?

    enum CodingKeys: String, CodingKey {
        case rows, note
        case maxChapterInBook = "max_chapter_in_book"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rows = try c.decodeIfPresent([ChronicleRow].self, forKey: .rows) ?? []
        self.maxChapterInBook = try c.decodeIfPresent(Int.self, forKey: .maxChapterInBook) ?? 0
        self.note = try c.decodeIfPresent(String.self, forKey: .note)
    }
}

/// 伏笔表层 DTO — narrativeEngine.ts:23-25
struct SubtextSurfaceDTO: Codable, Equatable {
    let foreshadowLedgerCount: Int

    enum CodingKeys: String, CodingKey {
        case foreshadowLedgerCount = "foreshadow_ledger_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.foreshadowLedgerCount = try c.decodeIfPresent(Int.self, forKey: .foreshadowLedgerCount) ?? 0
    }
}

/// 演化表层 DTO — narrativeEngine.ts:26-37
struct EvolutionSurfaceDTO: Codable, Equatable {
    let activeSnapshot: ActiveSnapshotDTO?
    let counts: [String: Int]
    let recentGateRisks: [AnyCodable]
    let requiredContinuations: [String]

    enum CodingKeys: String, CodingKey {
        case activeSnapshot = "active_snapshot"
        case counts
        case recentGateRisks = "recent_gate_risks"
        case requiredContinuations = "required_continuations"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.activeSnapshot = try c.decodeIfPresent(ActiveSnapshotDTO.self, forKey: .activeSnapshot)
        self.counts = try c.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:]
        self.recentGateRisks = try c.decodeIfPresent([AnyCodable].self, forKey: .recentGateRisks) ?? []
        self.requiredContinuations = try c.decodeIfPresent([String].self, forKey: .requiredContinuations) ?? []
    }
}

/// 活跃快照摘要 — narrativeEngine.ts:28-33
struct ActiveSnapshotDTO: Codable, Equatable {
    let snapshotId: String
    let chapterNumber: Int
    let status: String
    let schemaVersion: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
        case chapterNumber = "chapter_number"
        case status
        case schemaVersion = "schema_version"
        case summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.snapshotId = try c.decodeIfPresent(String.self, forKey: .snapshotId) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.schemaVersion = try c.decodeIfPresent(String.self, forKey: .schemaVersion) ?? ""
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }
}

// MARK: - 快照回滚响应 — chronicles.ts:37-40
// 声明已移至 SnapshotModels.swift（CI#29 修复：消除重复声明）
