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
struct KnowledgeGraphStatistics: Codable, Equatable {
    let totalTriples: Int
    let byEntityType: [String: Int]
    let byImportance: [String: Int]
    let bySourceType: [String: Int]

    enum CodingKeys: String, CodingKey {
        case totalTriples = "total_triples"
        case byEntityType = "by_entity_type"
        case byImportance = "by_importance"
        case bySourceType = "by_source_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.totalTriples = dict["total_triples"]?.intValue ?? 0
        self.byEntityType = (dict["by_entity_type"]?.dictionaryValue ?? [:]).compactMapValues { $0.intValue }
        self.byImportance = (dict["by_importance"]?.dictionaryValue ?? [:]).compactMapValues { $0.intValue }
        self.bySourceType = (dict["by_source_type"]?.dictionaryValue ?? [:]).compactMapValues { $0.intValue }
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
        self.triples = (try? JSONDecoder().decode([KnowledgeTriple].self, from: tripleData)) ?? []
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
