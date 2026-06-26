//
//  CastModels.swift
//  Cangjie
//
//  人物关系模型，字段对齐后端 application/world/dtos/cast_dto.py。
//

import Foundation

// MARK: - 故事事件

/// 故事事件，对应后端 StoryEventDTO
struct CastStoryEvent: Codable, Identifiable, Equatable {
    let id: String
    let summary: String
    let chapterId: Int?
    let importance: String

    enum CodingKeys: String, CodingKey {
        case id, summary
        case chapterId = "chapter_id"
        case importance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.chapterId = try c.decodeIfPresent(Int.self, forKey: .chapterId)
        self.importance = try c.decodeIfPresent(String.self, forKey: .importance) ?? "normal"
    }
}

// MARK: - Cast 角色

/// Cast 角色，对应后端 cast_dto.py CharacterDTO
struct CastCharacter: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let aliases: [String]
    let role: String
    let traits: String
    let note: String
    let storyEvents: [CastStoryEvent]

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, role, traits, note
        case storyEvents = "story_events"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        self.role = try c.decodeIfPresent(String.self, forKey: .role) ?? ""
        self.traits = try c.decodeIfPresent(String.self, forKey: .traits) ?? ""
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.storyEvents = try c.decodeIfPresent([CastStoryEvent].self, forKey: .storyEvents) ?? []
    }
}

// MARK: - Cast 关系

/// Cast 关系，对应后端 RelationshipDTO
struct CastRelationship: Codable, Identifiable, Equatable {
    let id: String
    let sourceId: String
    let targetId: String
    let label: String
    let note: String
    let directed: Bool
    let storyEvents: [CastStoryEvent]

    enum CodingKeys: String, CodingKey {
        case id
        case sourceId = "source_id"
        case targetId = "target_id"
        case label, note, directed
        case storyEvents = "story_events"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.sourceId = try c.decodeIfPresent(String.self, forKey: .sourceId) ?? ""
        self.targetId = try c.decodeIfPresent(String.self, forKey: .targetId) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        self.directed = try c.decodeIfPresent(Bool.self, forKey: .directed) ?? true
        self.storyEvents = try c.decodeIfPresent([CastStoryEvent].self, forKey: .storyEvents) ?? []
    }
}

// MARK: - Cast 关系图

/// Cast 关系图，对应后端 CastGraphDTO
struct CastGraph: Codable, Equatable {
    let version: Int
    let characters: [CastCharacter]
    let relationships: [CastRelationship]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.characters = try c.decodeIfPresent([CastCharacter].self, forKey: .characters) ?? []
        self.relationships = try c.decodeIfPresent([CastRelationship].self, forKey: .relationships) ?? []
    }
}

// MARK: - Cast 搜索结果

/// Cast 搜索结果，对应后端 CastSearchResultDTO
struct CastSearchResult: Codable, Equatable {
    let characters: [CastCharacter]
    let relationships: [CastRelationship]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.characters = try c.decodeIfPresent([CastCharacter].self, forKey: .characters) ?? []
        self.relationships = try c.decodeIfPresent([CastRelationship].self, forKey: .relationships) ?? []
    }
}

// MARK: - 角色覆盖

/// 角色覆盖项，对应后端 CharacterCoverageDTO
struct CharacterCoverage: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let mentioned: Bool
    let chapterIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id, name, mentioned
        case chapterIds = "chapter_ids"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.mentioned = try c.decodeIfPresent(Bool.self, forKey: .mentioned) ?? false
        self.chapterIds = try c.decodeIfPresent([Int].self, forKey: .chapterIds) ?? []
    }
}

// MARK: - Cast 覆盖分析

/// Cast 覆盖分析，对应后端 CastCoverageDTO
///
/// C-2：bibleNotInCast 从 [AnyCodable] 结构化为 [CastBibleCharacter]；
/// quotedNotInCast 从 [AnyCodable] 结构化为 [CastQuotedText]。
struct CastCoverage: Codable, Equatable {
    let chapterFilesScanned: Int
    let characters: [CharacterCoverage]
    let bibleNotInCast: [CastBibleCharacter]
    let quotedNotInCast: [CastQuotedText]

    enum CodingKeys: String, CodingKey {
        case characters
        case chapterFilesScanned = "chapter_files_scanned"
        case bibleNotInCast = "bible_not_in_cast"
        case quotedNotInCast = "quoted_not_in_cast"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterFilesScanned = try c.decodeIfPresent(Int.self, forKey: .chapterFilesScanned) ?? 0
        self.characters = try c.decodeIfPresent([CharacterCoverage].self, forKey: .characters) ?? []
        self.bibleNotInCast = try c.decodeIfPresent([CastBibleCharacter].self, forKey: .bibleNotInCast) ?? []
        self.quotedNotInCast = try c.decodeIfPresent([CastQuotedText].self, forKey: .quotedNotInCast) ?? []
    }
}

// MARK: - 角色叙事画像

/// 角色叙事画像（GET /novels/{id}/characters/{character_id}/narrative-profile）
/// 字段对齐原版 cast.ts:98-112 CharacterNarrativeProfile
/// Q6 决策：base_profile/current_state 等字段原项目本身是 Record<string,unknown>，
/// 用 AnyCodable 对齐是正确做法（非结构化字段）。
struct CharacterNarrativeProfile: Codable, Equatable {
    let characterId: String
    let name: String
    let baseProfile: AnyCodable?
    let currentState: AnyCodable?
    let castHistory: [AnyCodable]?
    let relationshipEdges: [AnyCodable]?
    let knowledgeFacts: [AnyCodable]?
    let hiddenFacts: [AnyCodable]?
    let openDebts: [AnyCodable]?
    let foreshadowLinks: [AnyCodable]?
    let causalLinks: [AnyCodable]?
    let recentDialogueSamples: [AnyCodable]?
    let consistencyRisks: [AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case name
        case baseProfile = "base_profile"
        case currentState = "current_state"
        case castHistory = "cast_history"
        case relationshipEdges = "relationship_edges"
        case knowledgeFacts = "knowledge_facts"
        case hiddenFacts = "hidden_facts"
        case openDebts = "open_debts"
        case foreshadowLinks = "foreshadow_links"
        case causalLinks = "causal_links"
        case recentDialogueSamples = "recent_dialogue_samples"
        case consistencyRisks = "consistency_risks"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.characterId = dict["character_id"]?.stringStringValue ?? ""
        self.name = dict["name"]?.stringStringValue ?? ""
        self.baseProfile = dict["base_profile"].map { AnyCodable($0) }
        self.currentState = dict["current_state"].map { AnyCodable($0) }
        self.castHistory = dict["cast_history"]?.arrayValue?.map { AnyCodable($0) }
        self.relationshipEdges = dict["relationship_edges"]?.arrayValue?.map { AnyCodable($0) }
        self.knowledgeFacts = dict["knowledge_facts"]?.arrayValue?.map { AnyCodable($0) }
        self.hiddenFacts = dict["hidden_facts"]?.arrayValue?.map { AnyCodable($0) }
        self.openDebts = dict["open_debts"]?.arrayValue?.map { AnyCodable($0) }
        self.foreshadowLinks = dict["foreshadow_links"]?.arrayValue?.map { AnyCodable($0) }
        self.causalLinks = dict["causal_links"]?.arrayValue?.map { AnyCodable($0) }
        self.recentDialogueSamples = dict["recent_dialogue_samples"]?.arrayValue?.map { AnyCodable($0) }
        self.consistencyRisks = dict["consistency_risks"]?.arrayValue?.map { AnyCodable($0) }
    }
}
