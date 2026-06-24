//
//  PropModels.swift
//  Cangjie
//
//  道具模型，字段对齐后端 interfaces/api/v1/prop/prop_routes.py 的 DTO。
//

import Foundation

// MARK: - 道具 DTO

/// 道具 DTO，对应后端 PropDTO — propApi.ts:3-17
struct PropDTO: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let name: String
    let description: String
    let aliases: [String]
    let propCategory: String
    let lifecycleState: String
    let introducedChapter: Int?
    let resolvedChapter: Int?
    let holderCharacterId: String?
    let attributes: [String: AnyCodable]
    let isPriorityForChapter: Bool?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case name, description, aliases
        case propCategory = "prop_category"
        case lifecycleState = "lifecycle_state"
        case introducedChapter = "introduced_chapter"
        case resolvedChapter = "resolved_chapter"
        case holderCharacterId = "holder_character_id"
        case attributes
        case isPriorityForChapter = "is_priority_for_chapter"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        self.propCategory = try c.decodeIfPresent(String.self, forKey: .propCategory) ?? "OTHER"
        self.lifecycleState = try c.decodeIfPresent(String.self, forKey: .lifecycleState) ?? "DORMANT"
        self.introducedChapter = try c.decodeIfPresent(Int.self, forKey: .introducedChapter)
        self.resolvedChapter = try c.decodeIfPresent(Int.self, forKey: .resolvedChapter)
        self.holderCharacterId = try c.decodeIfPresent(String.self, forKey: .holderCharacterId)
        self.attributes = try c.decodeIfPresent([String: AnyCodable].self, forKey: .attributes) ?? [:]
        self.isPriorityForChapter = try c.decodeIfPresent(Bool.self, forKey: .isPriorityForChapter)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

// MARK: - 道具分类枚举（propApi.ts:3-17）

/// 道具分类 — propApi.ts:3-17
enum PropCategory: String, Codable, CaseIterable {
    case weapon = "WEAPON"
    case artifact = "ARTIFACT"
    case tool = "TOOL"
    case consumable = "CONSUMABLE"
    case token = "TOKEN"
    case other = "OTHER"
}

/// 道具生命周期状态 — propApi.ts:3-17
enum PropLifecycleState: String, Codable, CaseIterable {
    case dormant = "DORMANT"
    case introduced = "INTRODUCED"
    case active = "ACTIVE"
    case damaged = "DAMAGED"
    case resolved = "RESOLVED"
}

// MARK: - 道具事件 DTO

/// 道具事件 DTO，对应后端 PropEventDTO
struct PropEventDTO: Codable, Identifiable, Equatable {
    let id: String
    let propId: String
    let chapterNumber: Int
    let eventType: String
    let source: String
    let description: String
    let actorCharacterId: String?
    let fromHolderId: String?
    let toHolderId: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case propId = "prop_id"
        case chapterNumber = "chapter_number"
        case eventType = "event_type"
        case source, description
        case actorCharacterId = "actor_character_id"
        case fromHolderId = "from_holder_id"
        case toHolderId = "to_holder_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.propId = try c.decodeIfPresent(String.self, forKey: .propId) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.eventType = try c.decodeIfPresent(String.self, forKey: .eventType) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.actorCharacterId = try c.decodeIfPresent(String.self, forKey: .actorCharacterId)
        self.fromHolderId = try c.decodeIfPresent(String.self, forKey: .fromHolderId)
        self.toHolderId = try c.decodeIfPresent(String.self, forKey: .toHolderId)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

// MARK: - 创建道具请求

/// 创建道具请求，对应后端 CreatePropBody
struct CreatePropRequest: Codable {
    let name: String
    let description: String
    let aliases: [String]
    let propCategory: String
    let holderCharacterId: String?
    let introducedChapter: Int?
    let attributes: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case name, description, aliases
        case propCategory = "prop_category"
        case holderCharacterId = "holder_character_id"
        case introducedChapter = "introduced_chapter"
        case attributes
    }
}

// MARK: - 更新道具请求

/// 更新道具请求，对应后端 PatchPropBody
struct PatchPropRequest: Codable {
    let name: String?
    let description: String?
    let aliases: [String]?
    let propCategory: String?
    let lifecycleState: String?
    let holderCharacterId: String?
    let introducedChapter: Int?
    let attributes: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case name, description, aliases
        case propCategory = "prop_category"
        case lifecycleState = "lifecycle_state"
        case holderCharacterId = "holder_character_id"
        case introducedChapter = "introduced_chapter"
        case attributes
    }
}

// MARK: - 创建道具事件请求

/// 创建道具事件请求，对应后端 CreateEventBody
struct CreatePropEventRequest: Codable {
    let chapterNumber: Int
    let eventType: String
    let description: String
    let actorCharacterId: String?
    let fromHolderId: String?
    let toHolderId: String?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case eventType = "event_type"
        case description
        case actorCharacterId = "actor_character_id"
        case fromHolderId = "from_holder_id"
        case toHolderId = "to_holder_id"
    }
}
