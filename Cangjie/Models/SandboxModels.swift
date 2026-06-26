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

/// 角色锚点响应（GET /novels/{id}/sandbox/character/{character_id}/anchor），字段对齐原版 sandbox.ts:22-28
struct CharacterAnchor: Codable, Equatable {
    let characterId: String
    let characterName: String
    let mentalState: String
    let verbalTic: String
    let idleBehavior: String

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case characterName = "character_name"
        case mentalState = "mental_state"
        case verbalTic = "verbal_tic"
        case idleBehavior = "idle_behavior"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.characterId = try c.decodeIfPresent(String.self, forKey: .characterId) ?? ""
        self.characterName = try c.decodeIfPresent(String.self, forKey: .characterName) ?? ""
        self.mentalState = try c.decodeIfPresent(String.self, forKey: .mentalState) ?? ""
        self.verbalTic = try c.decodeIfPresent(String.self, forKey: .verbalTic) ?? ""
        self.idleBehavior = try c.decodeIfPresent(String.self, forKey: .idleBehavior) ?? ""
    }

    /// 显式 memberwise init（T04教训8：自定义 init(from:) 会抑制 memberwise init 合成）
    init(characterId: String, characterName: String, mentalState: String, verbalTic: String, idleBehavior: String) {
        self.characterId = characterId
        self.characterName = characterName
        self.mentalState = mentalState
        self.verbalTic = verbalTic
        self.idleBehavior = idleBehavior
    }
}

// MARK: - 角色锚点更新请求 — sandbox.ts:63-72

/// 角色锚点更新请求（PATCH /novels/{id}/sandbox/character/{character_id}/anchor）
struct PatchCharacterAnchorRequest: Codable {
    let mentalState: String
    let verbalTic: String
    let idleBehavior: String

    enum CodingKeys: String, CodingKey {
        case mentalState = "mental_state"
        case verbalTic = "verbal_tic"
        case idleBehavior = "idle_behavior"
    }
}

// MARK: - 生成对话请求

/// 生成对话请求（POST /novels/{id}/sandbox/generate-dialogue）
/// 字段对齐原版 sandbox.ts:30-37 GenerateDialogueRequest
struct GenerateDialogueRequest: Codable {
    let novelId: String
    let characterId: String
    let scenePrompt: String
    let mentalState: String?
    let verbalTic: String?
    let idleBehavior: String?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case characterId = "character_id"
        case scenePrompt = "scene_prompt"
        case mentalState = "mental_state"
        case verbalTic = "verbal_tic"
        case idleBehavior = "idle_behavior"
    }

    /// 显式 memberwise init（自定义 CodingKeys 后编译器不再自动合成）
    init(novelId: String,
         characterId: String,
         scenePrompt: String,
         mentalState: String? = nil,
         verbalTic: String? = nil,
         idleBehavior: String? = nil) {
        self.novelId = novelId
        self.characterId = characterId
        self.scenePrompt = scenePrompt
        self.mentalState = mentalState
        self.verbalTic = verbalTic
        self.idleBehavior = idleBehavior
    }
}

// MARK: - 生成对话响应

/// 生成对话响应，对应后端 GenerateDialogueResponse
/// 字段对齐原版 sandbox.ts:39-42 GenerateDialogueResponse
struct GenerateDialogueResponse: Codable, Equatable {
    let dialogue: String
    let characterName: String?
    let metadata: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case dialogue
        case characterName = "character_name"
        case metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.dialogue = dict["dialogue"]?.stringStringValue ?? ""
        self.characterName = dict["character_name"]?.stringStringValue
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
