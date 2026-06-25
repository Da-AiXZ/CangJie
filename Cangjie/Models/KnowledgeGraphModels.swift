//
//  KnowledgeGraphModels.swift
//  Cangjie
//
//  知识图谱模型，字段对齐后端 application/world/dtos/knowledge_dto.py 的 KnowledgeTripleDTO。
//  以及 interfaces/api/v1/world/knowledge_graph_routes.py 的响应。
//

import Foundation

// MARK: - 知识三元组

/// 知识三元组，对应后端 KnowledgeTripleDTO
///
/// 字段对齐原版 api/knowledgeGraph.ts:37-48 `TripleDTO`：
/// ```typescript
/// interface TripleDTO {
///   id: string
///   subject: string
///   subject_type: string
///   predicate: string
///   object: string
///   object_type: string
///   confidence: number
///   source_type: string
///   chapter_number: number | null
///   is_starred?: boolean
/// }
/// ```
struct KnowledgeTriple: Codable, Identifiable, Equatable {
    let id: String
    let subject: String
    let predicate: String
    let object: String
    let chapterId: Int?
    let note: String
    let entityType: String?
    let importance: String?
    let locationType: String?
    let description: String?
    let firstAppearance: Int?
    let relatedChapters: [Int]
    let tags: [String]
    let attributes: [String: AnyCodable]
    let confidence: Double?
    let sourceType: String?
    let subjectEntityId: String?
    let objectEntityId: String?
    let provenance: [AnyCodable]
    /// 是否标星 — 对齐原版 TripleDTO.is_starred (knowledgeGraph.ts:47)
    let isStarred: Bool?

    enum CodingKeys: String, CodingKey {
        case id, subject, predicate, object, note, importance, description, tags, attributes, confidence
        case chapterId = "chapter_id"
        case entityType = "entity_type"
        case locationType = "location_type"
        case firstAppearance = "first_appearance"
        case relatedChapters = "related_chapters"
        case sourceType = "source_type"
        case subjectEntityId = "subject_entity_id"
        case objectEntityId = "object_entity_id"
        case provenance
        case isStarred = "is_starred"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        self.predicate = try c.decodeIfPresent(String.self, forKey: .predicate) ?? ""
        self.object = try c.decodeIfPresent(String.self, forKey: .object) ?? ""
        self.chapterId = try c.decodeIfPresent(Int.self, forKey: .chapterId)
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.entityType = try c.decodeIfPresent(String.self, forKey: .entityType)
        self.importance = try c.decodeIfPresent(String.self, forKey: .importance)
        self.locationType = try c.decodeIfPresent(String.self, forKey: .locationType)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.firstAppearance = try c.decodeIfPresent(Int.self, forKey: .firstAppearance)
        self.relatedChapters = try c.decodeIfPresent([Int].self, forKey: .relatedChapters) ?? []
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.attributes = try c.decodeIfPresent([String: AnyCodable].self, forKey: .attributes) ?? [:]
        self.confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
        self.sourceType = try c.decodeIfPresent(String.self, forKey: .sourceType)
        self.subjectEntityId = try c.decodeIfPresent(String.self, forKey: .subjectEntityId)
        self.objectEntityId = try c.decodeIfPresent(String.self, forKey: .objectEntityId)
        self.provenance = try c.decodeIfPresent([AnyCodable].self, forKey: .provenance) ?? []
        self.isStarred = try c.decodeIfPresent(Bool.self, forKey: .isStarred)
    }

    /// 成员初始化器（教训8：自定义 init(from:) 的 struct 需补 memberwise init）
    init(
        id: String,
        subject: String,
        predicate: String,
        object: String,
        chapterId: Int? = nil,
        note: String = "",
        entityType: String? = nil,
        importance: String? = nil,
        locationType: String? = nil,
        description: String? = nil,
        firstAppearance: Int? = nil,
        relatedChapters: [Int] = [],
        tags: [String] = [],
        attributes: [String: AnyCodable] = [:],
        confidence: Double? = nil,
        sourceType: String? = nil,
        subjectEntityId: String? = nil,
        objectEntityId: String? = nil,
        provenance: [AnyCodable] = [],
        isStarred: Bool? = nil
    ) {
        self.id = id
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.chapterId = chapterId
        self.note = note
        self.entityType = entityType
        self.importance = importance
        self.locationType = locationType
        self.description = description
        self.firstAppearance = firstAppearance
        self.relatedChapters = relatedChapters
        self.tags = tags
        self.attributes = attributes
        self.confidence = confidence
        self.sourceType = sourceType
        self.subjectEntityId = subjectEntityId
        self.objectEntityId = objectEntityId
        self.provenance = provenance
        self.isStarred = isStarred
    }
}

// MARK: - 章节摘要

/// 章节摘要，对应后端 ChapterSummaryDTO
struct ChapterSummaryDTO: Codable, Equatable {
    let chapterId: Int
    let summary: String
    let keyEvents: String
    let openThreads: String
    let consistencyNote: String
    let beatSections: [String]
    let microBeats: [AnyCodable]
    let syncStatus: String

    enum CodingKeys: String, CodingKey {
        case summary
        case chapterId = "chapter_id"
        case keyEvents = "key_events"
        case openThreads = "open_threads"
        case consistencyNote = "consistency_note"
        case beatSections = "beat_sections"
        case microBeats = "micro_beats"
        case syncStatus = "sync_status"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterId = try c.decodeIfPresent(Int.self, forKey: .chapterId) ?? 0
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.keyEvents = try c.decodeIfPresent(String.self, forKey: .keyEvents) ?? ""
        self.openThreads = try c.decodeIfPresent(String.self, forKey: .openThreads) ?? ""
        self.consistencyNote = try c.decodeIfPresent(String.self, forKey: .consistencyNote) ?? ""
        self.beatSections = try c.decodeIfPresent([String].self, forKey: .beatSections) ?? []
        self.microBeats = try c.decodeIfPresent([AnyCodable].self, forKey: .microBeats) ?? []
        self.syncStatus = try c.decodeIfPresent(String.self, forKey: .syncStatus) ?? "draft"
    }
}

// MARK: - 故事知识

/// 故事知识，对应后端 StoryKnowledgeDTO
struct StoryKnowledge: Codable, Equatable {
    let version: Int
    let premiseLock: String
    let chapters: [ChapterSummaryDTO]
    let facts: [KnowledgeTriple]

    enum CodingKeys: String, CodingKey {
        case version, chapters, facts
        case premiseLock = "premise_lock"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.premiseLock = try c.decodeIfPresent(String.self, forKey: .premiseLock) ?? ""
        self.chapters = try c.decodeIfPresent([ChapterSummaryDTO].self, forKey: .chapters) ?? []
        self.facts = try c.decodeIfPresent([KnowledgeTriple].self, forKey: .facts) ?? []
    }

    /// 成员初始化器（教训8：自定义 init(from:) 的 struct 需补 memberwise init）
    init(
        version: Int = 1,
        premiseLock: String = "",
        chapters: [ChapterSummaryDTO] = [],
        facts: [KnowledgeTriple] = []
    ) {
        self.version = version
        self.premiseLock = premiseLock
        self.chapters = chapters
        self.facts = facts
    }
}

// MARK: - 知识搜索

/// 知识搜索结果项
struct KnowledgeSearchHit: Codable, Identifiable, Equatable {
    let id: String
    let text: String
    let meta: AnyCodable?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.meta = try c.decodeIfPresent(AnyCodable.self, forKey: .meta)
    }
}

/// 知识搜索响应
struct KnowledgeSearchResponse: Codable, Equatable {
    let hits: [KnowledgeSearchHit]

    enum CodingKeys: String, CodingKey {
        case hits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hits = try c.decodeIfPresent([KnowledgeSearchHit].self, forKey: .hits) ?? []
    }
}

// MARK: - 知识图谱统计

/// 知识图谱统计响应（GET /knowledge-graph/novels/{id}/statistics）
///
/// 字段对齐原版 api/knowledgeGraph.ts:50-55 `KGStatistics`：
/// ```typescript
/// interface KGStatistics {
///   total_triples: number
///   source_distribution: Record<string, number>
///   confidence_distribution: { high: number; medium: number; low: number }
///   predicate_distribution: Record<string, number>
/// }
/// ```
struct KnowledgeGraphStatistics: Codable, Equatable {
    /// 三元组总数 — knowledgeGraph.ts:51 `total_triples`
    let totalTriples: Int

    /// 来源分布 — knowledgeGraph.ts:52 `source_distribution: Record<string, number>`
    let sourceDistribution: [String: Int]

    /// 置信度分布 — knowledgeGraph.ts:53 `confidence_distribution: { high, medium, low }`
    let confidenceDistribution: KGConfidenceDistribution

    /// 谓词分布 — knowledgeGraph.ts:54 `predicate_distribution: Record<string, number>`
    let predicateDistribution: [String: Int]

    enum CodingKeys: String, CodingKey {
        case totalTriples = "total_triples"
        case sourceDistribution = "source_distribution"
        case confidenceDistribution = "confidence_distribution"
        case predicateDistribution = "predicate_distribution"
    }

    init(
        totalTriples: Int = 0,
        sourceDistribution: [String: Int] = [:],
        confidenceDistribution: KGConfidenceDistribution = KGConfidenceDistribution(),
        predicateDistribution: [String: Int] = [:]
    ) {
        self.totalTriples = totalTriples
        self.sourceDistribution = sourceDistribution
        self.confidenceDistribution = confidenceDistribution
        self.predicateDistribution = predicateDistribution
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.totalTriples = dict["total_triples"]?.intValue ?? 0

        // source_distribution: Record<string, number>
        if let srcDict = dict["source_distribution"]?.dictionaryValue {
            self.sourceDistribution = srcDict.compactMapValues { $0.intValue }
        } else {
            self.sourceDistribution = [:]
        }

        // confidence_distribution: { high, medium, low }
        if let confDict = dict["confidence_distribution"]?.dictionaryValue {
            self.confidenceDistribution = KGConfidenceDistribution(
                high: confDict["high"]?.intValue ?? 0,
                medium: confDict["medium"]?.intValue ?? 0,
                low: confDict["low"]?.intValue ?? 0
            )
        } else {
            self.confidenceDistribution = KGConfidenceDistribution()
        }

        // predicate_distribution: Record<string, number>
        if let predDict = dict["predicate_distribution"]?.dictionaryValue {
            self.predicateDistribution = predDict.compactMapValues { $0.intValue }
        } else {
            self.predicateDistribution = [:]
        }
    }
}

/// 置信度分布，对齐原版 knowledgeGraph.ts:53 `confidence_distribution: { high: number; medium: number; low: number }`
struct KGConfidenceDistribution: Codable, Equatable {
    let high: Int
    let medium: Int
    let low: Int

    enum CodingKeys: String, CodingKey {
        case high, medium, low
    }

    init(high: Int = 0, medium: Int = 0, low: Int = 0) {
        self.high = high
        self.medium = medium
        self.low = low
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.high = try c.decodeIfPresent(Int.self, forKey: .high) ?? 0
        self.medium = try c.decodeIfPresent(Int.self, forKey: .medium) ?? 0
        self.low = try c.decodeIfPresent(Int.self, forKey: .low) ?? 0
    }
}

// MARK: - 推断证据

/// 推断证据响应（GET /knowledge-graph/novels/{id}/chapters/by-number/{chapter}/inference-evidence）
struct InferenceEvidence: Codable, Equatable {
    let triples: [KnowledgeTriple]
    let evidence: [AnyCodable]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        let tripleData = try JSONSerialization.data(withJSONObject: dict["triples"]?.value ?? [])
        self.triples = (try? CangjieDecoder.shared.decode([KnowledgeTriple].self, from: tripleData)) ?? []
        self.evidence = (dict["evidence"]?.arrayValue ?? []).map { AnyCodable($0) }
    }
}

// MARK: - 知识图谱搜索请求

/// 知识图谱搜索请求
struct KnowledgeGraphSearchRequest: Codable {
    let query: String
    let topK: Int?

    enum CodingKeys: String, CodingKey {
        case query
        case topK = "top_k"
    }
}

// MARK: - 章节推断证据（结构化模型）
// 对齐原版 api/knowledgeGraph.ts:6-33 的接口定义

/// 推断溯源行，对应原版 knowledgeGraph.ts:6-11 `InferenceProvenanceRow`
///
/// ```typescript
/// interface InferenceProvenanceRow {
///   id: string
///   chapter_element_id: string | null
///   rule_id: string
///   role: string
/// }
/// ```
struct InferenceProvenanceRow: Codable, Identifiable, Equatable {
    /// 溯源 ID — knowledgeGraph.ts:7
    let id: String

    /// 章节元素 ID（可空）— knowledgeGraph.ts:8 `chapter_element_id`
    let chapterElementId: String?

    /// 规则 ID — knowledgeGraph.ts:9 `rule_id`
    let ruleId: String

    /// 角色 — knowledgeGraph.ts:10
    let role: String

    enum CodingKeys: String, CodingKey {
        case id
        case chapterElementId = "chapter_element_id"
        case ruleId = "rule_id"
        case role
    }

    init(id: String = "", chapterElementId: String? = nil, ruleId: String = "", role: String = "") {
        self.id = id
        self.chapterElementId = chapterElementId
        self.ruleId = ruleId
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.chapterElementId = try c.decodeIfPresent(String.self, forKey: .chapterElementId)
        self.ruleId = try c.decodeIfPresent(String.self, forKey: .ruleId) ?? ""
        self.role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
    }
}

/// 推断事实载荷，对应原版 knowledgeGraph.ts:13-21 `InferenceFactPayload`
///
/// ```typescript
/// interface InferenceFactPayload {
///   id: string
///   subject: string
///   predicate: string
///   object: string
///   chapter_number: number | null
///   confidence: number | null
///   source_type: string | null
/// }
/// ```
struct InferenceFactPayload: Codable, Identifiable, Equatable {
    /// 事实 ID — knowledgeGraph.ts:14
    let id: String

    /// 主语 — knowledgeGraph.ts:15
    let subject: String

    /// 谓词 — knowledgeGraph.ts:16
    let predicate: String

    /// 宾语 — knowledgeGraph.ts:17
    let object: String

    /// 章节编号（可空）— knowledgeGraph.ts:18 `chapter_number`
    let chapterNumber: Int?

    /// 置信度（可空）— knowledgeGraph.ts:19 `confidence`
    let confidence: Double?

    /// 来源类型（可空）— knowledgeGraph.ts:20 `source_type`
    let sourceType: String?

    enum CodingKeys: String, CodingKey {
        case id, subject, predicate, object
        case chapterNumber = "chapter_number"
        case confidence
        case sourceType = "source_type"
    }

    init(
        id: String = "",
        subject: String = "",
        predicate: String = "",
        object: String = "",
        chapterNumber: Int? = nil,
        confidence: Double? = nil,
        sourceType: String? = nil
    ) {
        self.id = id
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.chapterNumber = chapterNumber
        self.confidence = confidence
        self.sourceType = sourceType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        self.predicate = try c.decodeIfPresent(String.self, forKey: .predicate) ?? ""
        self.object = try c.decodeIfPresent(String.self, forKey: .object) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
        self.sourceType = try c.decodeIfPresent(String.self, forKey: .sourceType)
    }
}

/// 推断事实包（事实 + 溯源），对应原版 knowledgeGraph.ts:23-26 `InferenceFactBundle`
///
/// ```typescript
/// interface InferenceFactBundle {
///   fact: InferenceFactPayload
///   provenance: InferenceProvenanceRow[]
/// }
/// ```
struct InferenceFactBundle: Codable, Identifiable, Equatable {
    /// 事实 ID（用于 Identifiable）
    var id: String { fact.id }

    /// 事实载荷 — knowledgeGraph.ts:24
    let fact: InferenceFactPayload

    /// 溯源列表 — knowledgeGraph.ts:25
    let provenance: [InferenceProvenanceRow]

    enum CodingKeys: String, CodingKey {
        case fact, provenance
    }

    init(fact: InferenceFactPayload = InferenceFactPayload(), provenance: [InferenceProvenanceRow] = []) {
        self.fact = fact
        self.provenance = provenance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.fact = try c.decodeIfPresent(InferenceFactPayload.self, forKey: .fact) ?? InferenceFactPayload()
        self.provenance = try c.decodeIfPresent([InferenceProvenanceRow].self, forKey: .provenance) ?? []
    }
}

/// 章节推断证据数据，对应原版 knowledgeGraph.ts:28-33 `ChapterInferenceEvidenceData`
///
/// ```typescript
/// interface ChapterInferenceEvidenceData {
///   story_node_id: string | null
///   chapter_number: number
///   facts: InferenceFactBundle[]
///   hint?: string
/// }
/// ```
struct ChapterInferenceEvidenceData: Codable, Equatable {
    /// 故事节点 ID（可空）— knowledgeGraph.ts:29 `story_node_id`
    let storyNodeId: String?

    /// 章节编号 — knowledgeGraph.ts:30 `chapter_number`
    let chapterNumber: Int

    /// 推断事实包列表 — knowledgeGraph.ts:31 `facts`
    let facts: [InferenceFactBundle]

    /// 提示（可选）— knowledgeGraph.ts:32 `hint?`
    let hint: String?

    enum CodingKeys: String, CodingKey {
        case storyNodeId = "story_node_id"
        case chapterNumber = "chapter_number"
        case facts
        case hint
    }

    init(
        storyNodeId: String? = nil,
        chapterNumber: Int = 0,
        facts: [InferenceFactBundle] = [],
        hint: String? = nil
    ) {
        self.storyNodeId = storyNodeId
        self.chapterNumber = chapterNumber
        self.facts = facts
        self.hint = hint
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.storyNodeId = try c.decodeIfPresent(String.self, forKey: .storyNodeId)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.facts = try c.decodeIfPresent([InferenceFactBundle].self, forKey: .facts) ?? []
        self.hint = try c.decodeIfPresent(String.self, forKey: .hint)
    }
}

// MARK: - starTriple 响应

/// starTriple 响应，对应原版 knowledgeGraph.ts:128-133
/// `{ success: boolean; triple_id: string; starred: boolean }`
struct StarTripleResponse: Codable, Equatable {
    let success: Bool
    let tripleId: String
    let starred: Bool

    enum CodingKeys: String, CodingKey {
        case success
        case tripleId = "triple_id"
        case starred
    }

    init(success: Bool = false, tripleId: String = "", starred: Bool = false) {
        self.success = success
        self.tripleId = tripleId
        self.starred = starred
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.tripleId = try c.decodeIfPresent(String.self, forKey: .tripleId) ?? ""
        self.starred = try c.decodeIfPresent(Bool.self, forKey: .starred) ?? false
    }
}

// MARK: - revokeChapterInference 响应

/// revokeChapterInference 响应，对应原版 knowledgeGraph.ts:73-78
/// `{ success: boolean; data: { removed_provenance_triples: number; deleted_inferred_facts: number } }`
struct RevokeInferenceResponse: Codable, Equatable {
    let success: Bool
    let data: RevokeInferenceData

    enum CodingKeys: String, CodingKey {
        case success, data
    }

    init(success: Bool = false, data: RevokeInferenceData = RevokeInferenceData()) {
        self.success = success
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.data = try c.decodeIfPresent(RevokeInferenceData.self, forKey: .data) ?? RevokeInferenceData()
    }
}

/// revokeChapterInference 响应内层 data
struct RevokeInferenceData: Codable, Equatable {
    let removedProvenanceTriples: Int
    let deletedInferredFacts: Int

    enum CodingKeys: String, CodingKey {
        case removedProvenanceTriples = "removed_provenance_triples"
        case deletedInferredFacts = "deleted_inferred_facts"
    }

    init(removedProvenanceTriples: Int = 0, deletedInferredFacts: Int = 0) {
        self.removedProvenanceTriples = removedProvenanceTriples
        self.deletedInferredFacts = deletedInferredFacts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.removedProvenanceTriples = try c.decodeIfPresent(Int.self, forKey: .removedProvenanceTriples) ?? 0
        self.deletedInferredFacts = try c.decodeIfPresent(Int.self, forKey: .deletedInferredFacts) ?? 0
    }
}

// MARK: - starTriple 请求体

/// starTriple 请求体，对应原版 knowledgeGraph.ts:131 `{ starred }`
struct StarTripleRequest: Codable {
    let starred: Bool
}
