//
//  SandboxModels.swift
//  Cangjie
//
//  对话沙盒模型，字段对齐后端 application/workbench/dtos/sandbox_dto.py。
//  以及 interfaces/api/v1/workbench/sandbox.py 的响应。
//

import Foundation

// MARK: - 对话白名单条目

/// 对话白名单条目，对应后端 DialogueEntry
struct DialogueEntry: Codable, Identifiable, Equatable {
    var id: String { dialogueId }
    let dialogueId: String
    let chapter: Int
    let speaker: String
    let content: String
    let context: String
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case dialogueId = "dialogue_id"
        case chapter, speaker, content, context, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dialogueId = try c.decodeIfPresent(String.self, forKey: .dialogueId) ?? ""
        self.chapter = try c.decodeIfPresent(Int.self, forKey: .chapter) ?? 0
        self.speaker = try c.decodeIfPresent(String.self, forKey: .speaker) ?? ""
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
        self.tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

// MARK: - 对话白名单响应

/// 对话白名单响应，对应后端 DialogueWhitelistResponse
struct DialogueWhitelistResponse: Codable, Equatable {
    let dialogues: [DialogueEntry]
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case dialogues
        case totalCount = "total_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.dialogues = try c.decodeIfPresent([DialogueEntry].self, forKey: .dialogues) ?? []
        self.totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
    }
}

// MARK: - 角色锚点

/// 角色锚点响应（GET /novels/{id}/sandbox/character/{character_id}/anchor），后端返回 CharacterAnchorResponse
struct CharacterAnchor: Codable, Equatable {
    let characterId: String
    let name: String
    let anchorTraits: [String]?
    let verbalPatterns: [String]?
    let behavioralNotes: String?
    let recentDialogueSamples: [DialogueEntry]?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case name
        case anchorTraits = "anchor_traits"
        case verbalPatterns = "verbal_patterns"
        case behavioralNotes = "behavioral_notes"
        case recentDialogueSamples = "recent_dialogue_samples"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.characterId = dict["character_id"]?.stringStringValue ?? ""
        self.name = dict["name"]?.stringStringValue ?? ""
        self.anchorTraits = (dict["anchor_traits"]?.arrayValue ?? []).compactMap { $0 as? String }
        self.verbalPatterns = (dict["verbal_patterns"]?.arrayValue ?? []).compactMap { $0 as? String }
        self.behavioralNotes = dict["behavioral_notes"]?.stringStringValue
        let samplesData = try JSONSerialization.data(withJSONObject: dict["recent_dialogue_samples"]?.value ?? [])
        self.recentDialogueSamples = try? JSONDecoder().decode([DialogueEntry].self, from: samplesData)
    }
}

// MARK: - 生成对话请求

/// 生成对话请求（POST /novels/{id}/sandbox/generate-dialogue）
struct GenerateDialogueRequest: Codable {
    let characterId: String
    let scenario: String?
    let context: String?
    let maxTurns: Int?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case scenario, context
        case maxTurns = "max_turns"
    }
}

// MARK: - 生成对话响应

/// 生成对话响应，对应后端 GenerateDialogueResponse
struct GenerateDialogueResponse: Codable, Equatable {
    let dialogue: String
    let speaker: String?
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case dialogue, speaker, metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.dialogue = dict["dialogue"]?.stringStringValue ?? ""
        self.speaker = dict["speaker"]?.stringStringValue
        self.metadata = (dict["metadata"]?.dictionaryValue ?? [:]).mapValues { AnyCodable($0) }
    }
}

// MARK: - 对话沙盒回合

/// 对话沙盒中的一轮对话
struct DialogueTurn: Identifiable, Equatable {
    let id: UUID
    let speaker: String
    let content: String
    let isUser: Bool

    init(speaker: String, content: String, isUser: Bool) {
        self.id = UUID()
        self.speaker = speaker
        self.content = content
        self.isUser = isUser
    }
}

// MARK: - 沙盒配置

/// 沙盒配置
struct SandboxConfig: Codable, Equatable {
    let characterId: String
    let scenario: String?
    let context: String?
    let maxTurns: Int

    init(characterId: String, scenario: String? = nil, context: String? = nil, maxTurns: Int = 10) {
        self.characterId = characterId
        self.scenario = scenario
        self.context = context
        self.maxTurns = maxTurns
    }
}
