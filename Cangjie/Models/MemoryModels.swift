//
//  MemoryModels.swift
//  Cangjie
//
//  记忆系统模型，字段对齐原版 api/memory.ts:4-35。
//  E-5 前置：MemoryAtom + CharacterProjection，供角色档案视图接线消费者。
//

import Foundation

// MARK: - 记忆原子

/// 记忆原子，对齐原版 api/memory.ts:4-16 MemoryAtom。
///
/// 表示一条结构化记忆事件（实体在某个章节的某个记忆片段）。
/// payload 字段原项目为 Record<string, unknown>，用 AnyCodable 对齐（动态结构）。
struct MemoryAtom: Codable, Identifiable, Equatable {

    /// 原子 ID
    let id: String

    /// 小说 ID
    let novelId: String

    /// 实体 ID
    let entityId: String

    /// 实体类型（character / location / prop / …）
    let entityType: String

    /// 记忆类型
    let memoryType: String

    /// 作用域
    let scope: String

    /// 来源
    let source: String

    /// 状态（pending / confirmed / rejected / promoted）
    let status: String

    /// 载荷（动态结构，原项目 Record<string, unknown>）
    let payload: AnyCodable

    /// 章节编号（可选）
    let chapterNumber: Int?

    /// 文本跨度
    let textSpan: String

    /// 置信度
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case entityId = "entity_id"
        case entityType = "entity_type"
        case memoryType = "memory_type"
        case scope, source, status, payload
        case chapterNumber = "chapter_number"
        case textSpan = "text_span"
        case confidence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.entityId = try c.decodeIfPresent(String.self, forKey: .entityId) ?? ""
        self.entityType = try c.decodeIfPresent(String.self, forKey: .entityType) ?? ""
        self.memoryType = try c.decodeIfPresent(String.self, forKey: .memoryType) ?? ""
        self.scope = try c.decodeIfPresent(String.self, forKey: .scope) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.payload = try c.decodeIfPresent(AnyCodable.self, forKey: .payload) ?? AnyCodable([:])
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.textSpan = try c.decodeIfPresent(String.self, forKey: .textSpan) ?? ""
        self.confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.0
    }

    init(
        id: String,
        novelId: String,
        entityId: String,
        entityType: String,
        memoryType: String,
        scope: String,
        source: String,
        status: String,
        payload: AnyCodable = AnyCodable([:]),
        chapterNumber: Int? = nil,
        textSpan: String = "",
        confidence: Double = 0.0
    ) {
        self.id = id
        self.novelId = novelId
        self.entityId = entityId
        self.entityType = entityType
        self.memoryType = memoryType
        self.scope = scope
        self.source = source
        self.status = status
        self.payload = payload
        self.chapterNumber = chapterNumber
        self.textSpan = textSpan
        self.confidence = confidence
    }
}

// MARK: - 记忆操作响应

/// 记忆确认/拒绝/提升操作响应，对齐原版 api/memory.ts:49-58 confirm/reject/promote 返回。
struct MemoryAtomActionResponse: Codable, Equatable {

    /// 是否成功
    let ok: Bool

    /// 操作后的原子
    let atom: MemoryAtom

    enum CodingKeys: String, CodingKey {
        case ok, atom
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        self.atom = try c.decodeIfPresent(MemoryAtom.self, forKey: .atom) ?? MemoryAtom(
            id: "", novelId: "", entityId: "", entityType: "", memoryType: "",
            scope: "", source: "", status: ""
        )
    }
}

// MARK: - 章节记忆候选响应

/// 章节记忆候选响应，对齐原版 api/memory.ts:43-46 getChapterCandidates 返回。
struct ChapterMemoryCandidatesResponse: Codable, Equatable {

    /// 章节编号
    let chapterNumber: Int

    /// 候选记忆列表
    let candidates: [MemoryAtom]

    enum CodingKeys: String, CodingKey {
        case candidates
        case chapterNumber = "chapter_number"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.candidates = try c.decodeIfPresent([MemoryAtom].self, forKey: .candidates) ?? []
    }
}

// MARK: - 角色投影

/// 角色投影，对齐原版 api/memory.ts:18-35 CharacterProjection。
///
/// 包含角色的宪法、当前状态、伤疤、动机、情感弧线、关系、知识边界、
/// 声纹指纹、弧线债务、最近证据、候选记忆等。
/// constitution/currentState/knowledgeBoundary/voiceFingerprint 等字段原项目为
/// Record<string, unknown>，用 AnyCodable 对齐（动态结构）。
struct CharacterProjection: Codable, Equatable {

    /// 小说 ID
    let novelId: String

    /// 实体 ID
    let entityId: String

    /// 角色 ID
    let characterId: String

    /// 角色名
    let name: String

    /// 角色宪法（动态结构）
    let constitution: AnyCodable

    /// 当前状态（动态结构）
    let currentState: AnyCodable

    /// 活跃伤疤列表（动态结构数组）
    let activeScars: [AnyCodable]

    /// 活跃动机列表（动态结构数组）
    let activeMotivations: [AnyCodable]

    /// 情感弧线列表（动态结构数组）
    let emotionalArc: [AnyCodable]

    /// 关系列表（动态结构数组）
    let relationships: [AnyCodable]

    /// 知识边界（动态结构）
    let knowledgeBoundary: AnyCodable

    /// 声纹指纹（动态结构）
    let voiceFingerprint: AnyCodable

    /// 弧线债务列表（动态结构数组）
    let arcDebts: [AnyCodable]

    /// 最近证据（记忆原子列表）
    let recentEvidence: [MemoryAtom]

    /// 候选记忆（记忆原子列表）
    let candidateMemories: [MemoryAtom]

    /// 上下文锁
    let contextLocks: ContextLocks

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case entityId = "entity_id"
        case characterId = "character_id"
        case name
        case constitution
        case currentState = "current_state"
        case activeScars = "active_scars"
        case activeMotivations = "active_motivations"
        case emotionalArc = "emotional_arc"
        case relationships
        case knowledgeBoundary = "knowledge_boundary"
        case voiceFingerprint = "voice_fingerprint"
        case arcDebts = "arc_debts"
        case recentEvidence = "recent_evidence"
        case candidateMemories = "candidate_memories"
        case contextLocks = "context_locks"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.entityId = try c.decodeIfPresent(String.self, forKey: .entityId) ?? ""
        self.characterId = try c.decodeIfPresent(String.self, forKey: .characterId) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.constitution = try c.decodeIfPresent(AnyCodable.self, forKey: .constitution) ?? AnyCodable([:])
        self.currentState = try c.decodeIfPresent(AnyCodable.self, forKey: .currentState) ?? AnyCodable([:])
        self.activeScars = try c.decodeIfPresent([AnyCodable].self, forKey: .activeScars) ?? []
        self.activeMotivations = try c.decodeIfPresent([AnyCodable].self, forKey: .activeMotivations) ?? []
        self.emotionalArc = try c.decodeIfPresent([AnyCodable].self, forKey: .emotionalArc) ?? []
        self.relationships = try c.decodeIfPresent([AnyCodable].self, forKey: .relationships) ?? []
        self.knowledgeBoundary = try c.decodeIfPresent(AnyCodable.self, forKey: .knowledgeBoundary) ?? AnyCodable([:])
        self.voiceFingerprint = try c.decodeIfPresent(AnyCodable.self, forKey: .voiceFingerprint) ?? AnyCodable([:])
        self.arcDebts = try c.decodeIfPresent([AnyCodable].self, forKey: .arcDebts) ?? []
        self.recentEvidence = try c.decodeIfPresent([MemoryAtom].self, forKey: .recentEvidence) ?? []
        self.candidateMemories = try c.decodeIfPresent([MemoryAtom].self, forKey: .candidateMemories) ?? []
        self.contextLocks = try c.decodeIfPresent(ContextLocks.self, forKey: .contextLocks) ?? ContextLocks()
    }
}

// MARK: - 上下文锁

/// 上下文锁，对齐原版 api/memory.ts:34 context_locks。
struct ContextLocks: Codable, Equatable {

    /// T0 锁定时间
    let t0: String?

    /// T1 锁定时间
    let t1: String?

    /// T2 锁定时间
    let t2: String?

    enum CodingKeys: String, CodingKey {
        case t0, t1, t2
    }

    init(t0: String? = nil, t1: String? = nil, t2: String? = nil) {
        self.t0 = t0
        self.t1 = t1
        self.t2 = t2
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.t0 = try c.decodeIfPresent(String.self, forKey: .t0)
        self.t1 = try c.decodeIfPresent(String.self, forKey: .t1)
        self.t2 = try c.decodeIfPresent(String.self, forKey: .t2)
    }
}
