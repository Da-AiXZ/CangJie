//
//  TraceExtraModels.swift
//  Cangjie
//
//  Trace 扩展模型，字段对齐原版 api/engineCore.ts:374-394 + 43-61 + 175-196。
//  AiStageDTO + AiStageListResponse + StageDefDTO + StageTaxonomyResponse +
//  BranchDTO + BranchChild + BranchesResponse + HeadStateResponse + HeadState +
//  CharacterPsycheEvolutionEntryDTO + CharacterPsycheDetailDTO。
//

import Foundation

// MARK: - AI Trace 阶段统计

/// AI Trace 阶段统计，对应原版 engineCore.ts:374-378 AiStageDTO
struct AiStageDTO: Codable, Equatable {
    let stage: String
    let stageLabel: String
    let cnt: Int

    enum CodingKeys: String, CodingKey {
        case stage
        case stageLabel = "stage_label"
        case cnt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stage = try c.decodeIfPresent(String.self, forKey: .stage) ?? ""
        self.stageLabel = try c.decodeIfPresent(String.self, forKey: .stageLabel) ?? ""
        self.cnt = try c.decodeIfPresent(Int.self, forKey: .cnt) ?? 0
    }

    init(stage: String = "", stageLabel: String = "", cnt: Int = 0) {
        self.stage = stage
        self.stageLabel = stageLabel
        self.cnt = cnt
    }
}

/// AI Trace 阶段列表响应，对应原版 engineCore.ts:380-383 AiStageListResponse
struct AiStageListResponse: Codable, Equatable {
    let stages: [AiStageDTO]
    let total: Int

    enum CodingKeys: String, CodingKey {
        case stages, total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stages = try c.decodeIfPresent([AiStageDTO].self, forKey: .stages) ?? []
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }

    init(stages: [AiStageDTO] = [], total: Int = 0) {
        self.stages = stages
        self.total = total
    }
}

// MARK: - 阶段分类法

/// 阶段定义，对应原版 engineCore.ts:385-390 StageDefDTO
struct StageDefDTO: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let domain: String
    let semantic: String

    enum CodingKeys: String, CodingKey {
        case key, label, domain, semantic
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.domain = try c.decodeIfPresent(String.self, forKey: .domain) ?? ""
        self.semantic = try c.decodeIfPresent(String.self, forKey: .semantic) ?? ""
    }

    init(key: String = "", label: String = "", domain: String = "", semantic: String = "") {
        self.key = key
        self.label = label
        self.domain = domain
        self.semantic = semantic
    }
}

/// 阶段分类法响应，对应原版 engineCore.ts:392-394 StageTaxonomyResponse
struct StageTaxonomyResponse: Codable, Equatable {
    let stages: [StageDefDTO]

    enum CodingKeys: String, CodingKey {
        case stages
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.stages = try c.decodeIfPresent([StageDefDTO].self, forKey: .stages) ?? []
    }

    init(stages: [StageDefDTO] = []) {
        self.stages = stages
    }
}

// MARK: - 分支

/// 分支子节点，对应原版 engineCore.ts:46 BranchDTO.children[{id, reason}]
struct BranchChild: Codable, Identifiable, Equatable {
    let id: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case id, reason
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }

    init(id: String = "", reason: String = "") {
        self.id = id
        self.reason = reason
    }
}

/// 分支，对应原版 engineCore.ts:43-47 BranchDTO
struct BranchDTO: Codable, Identifiable, Equatable {
    var id: String { branchPointId }
    let branchPointId: String
    let reason: String
    let children: [BranchChild]

    enum CodingKeys: String, CodingKey {
        case branchPointId = "branch_point_id"
        case reason, children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.branchPointId = try c.decodeIfPresent(String.self, forKey: .branchPointId) ?? ""
        self.reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        self.children = try c.decodeIfPresent([BranchChild].self, forKey: .children) ?? []
    }

    init(branchPointId: String = "", reason: String = "", children: [BranchChild] = []) {
        self.branchPointId = branchPointId
        self.reason = reason
        self.children = children
    }
}

/// 分支列表响应，对应原版 engineCore.ts:49-51 BranchesResponse
struct BranchesResponse: Codable, Equatable {
    let branches: [BranchDTO]

    enum CodingKeys: String, CodingKey {
        case branches
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.branches = try c.decodeIfPresent([BranchDTO].self, forKey: .branches) ?? []
    }

    init(branches: [BranchDTO] = []) {
        self.branches = branches
    }
}

// MARK: - HEAD 状态

/// HEAD 状态，对应原版 engineCore.ts:55-60 HeadStateResponse.state
struct HeadState: Codable, Equatable {
    let triggerType: String
    let triggerReason: String
    let storyState: AnyCodable
    let activeForeshadows: [String]

    enum CodingKeys: String, CodingKey {
        case triggerType = "trigger_type"
        case triggerReason = "trigger_reason"
        case storyState = "story_state"
        case activeForeshadows = "active_foreshadows"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.triggerType = try c.decodeIfPresent(String.self, forKey: .triggerType) ?? ""
        self.triggerReason = try c.decodeIfPresent(String.self, forKey: .triggerReason) ?? ""
        self.storyState = try c.decodeIfPresent(AnyCodable.self, forKey: .storyState) ?? AnyCodable([:])
        self.activeForeshadows = try c.decodeIfPresent([String].self, forKey: .activeForeshadows) ?? []
    }

    init(
        triggerType: String = "",
        triggerReason: String = "",
        storyState: AnyCodable = AnyCodable([:]),
        activeForeshadows: [String] = []
    ) {
        self.triggerType = triggerType
        self.triggerReason = triggerReason
        self.storyState = storyState
        self.activeForeshadows = activeForeshadows
    }
}

/// HEAD 状态响应，对应原版 engineCore.ts:53-61 HeadStateResponse
struct HeadStateResponse: Codable, Equatable {
    let headId: String?
    let state: HeadState?

    enum CodingKeys: String, CodingKey {
        case headId = "head_id"
        case state
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.headId = try c.decodeIfPresent(String.self, forKey: .headId)
        self.state = try c.decodeIfPresent(HeadState.self, forKey: .state)
    }

    init(headId: String? = nil, state: HeadState? = nil) {
        self.headId = headId
        self.state = state
    }
}

// MARK: - 角色心理演化

/// 角色心理演化条目，对应原版 engineCore.ts:186-190 CharacterPsycheEvolutionEntryDTO
struct CharacterPsycheEvolutionEntryDTO: Codable, Identifiable, Equatable {
    var id: String { "\(triggerChapter)-\(triggerEvent.prefix(32))" }
    let triggerChapter: Int
    let triggerEvent: String
    let changedFields: [String]

    enum CodingKeys: String, CodingKey {
        case triggerChapter = "trigger_chapter"
        case triggerEvent = "trigger_event"
        case changedFields = "changed_fields"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.triggerChapter = try c.decodeIfPresent(Int.self, forKey: .triggerChapter) ?? 0
        self.triggerEvent = try c.decodeIfPresent(String.self, forKey: .triggerEvent) ?? ""
        self.changedFields = try c.decodeIfPresent([String].self, forKey: .changedFields) ?? []
    }

    init(triggerChapter: Int = 0, triggerEvent: String = "", changedFields: [String] = []) {
        self.triggerChapter = triggerChapter
        self.triggerEvent = triggerEvent
        self.changedFields = changedFields
    }
}

/// 角色心理详情，对应原版 engineCore.ts:192-196 CharacterPsycheDetailDTO
/// 继承 CharacterPsycheDTO 7 字段 + emotion_ledger + mask_summary + evolution_timeline
struct CharacterPsycheDetailDTO: Codable, Identifiable, Equatable {
    var id: String { name }
    // CharacterPsycheDTO 7 字段
    let name: String
    let role: String
    let coreBelief: String
    let taboo: String
    let voiceTag: String
    let wound: String
    let traumaCount: Int
    // 扩展字段
    let emotionLedger: AnyCodable
    let maskSummary: String
    let evolutionTimeline: [CharacterPsycheEvolutionEntryDTO]?

    enum CodingKeys: String, CodingKey {
        case name, role
        case coreBelief = "core_belief"
        case taboo
        case voiceTag = "voice_tag"
        case wound
        case traumaCount = "trauma_count"
        case emotionLedger = "emotion_ledger"
        case maskSummary = "mask_summary"
        case evolutionTimeline = "evolution_timeline"
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
        self.emotionLedger = try c.decodeIfPresent(AnyCodable.self, forKey: .emotionLedger) ?? AnyCodable([:])
        self.maskSummary = try c.decodeIfPresent(String.self, forKey: .maskSummary) ?? ""
        self.evolutionTimeline = try c.decodeIfPresent([CharacterPsycheEvolutionEntryDTO].self, forKey: .evolutionTimeline)
    }

    init(
        name: String = "",
        role: String = "",
        coreBelief: String = "",
        taboo: String = "",
        voiceTag: String = "",
        wound: String = "",
        traumaCount: Int = 0,
        emotionLedger: AnyCodable = AnyCodable([:]),
        maskSummary: String = "",
        evolutionTimeline: [CharacterPsycheEvolutionEntryDTO]? = nil
    ) {
        self.name = name
        self.role = role
        self.coreBelief = coreBelief
        self.taboo = taboo
        self.voiceTag = voiceTag
        self.wound = wound
        self.traumaCount = traumaCount
        self.emotionLedger = emotionLedger
        self.maskSummary = maskSummary
        self.evolutionTimeline = evolutionTimeline
    }
}
