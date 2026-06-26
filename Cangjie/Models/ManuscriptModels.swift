//
//  ManuscriptModels.swift
//  Cangjie
//
//  手稿实体索引模型，字段对齐原版 manuscript.ts:17-23 ChapterEntityMention。
//

import Foundation

// MARK: - 实体词典角色

/// 词典角色，对应原版 manuscript.ts:4-8 LexiconCharacter
struct LexiconCharacter: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let aliases: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, aliases
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    init(id: String = "", name: String = "", aliases: [String] = []) {
        self.id = id
        self.name = name
        self.aliases = aliases
    }
}

// MARK: - 实体词典地点

/// 词典地点，对应原版 manuscript.ts:10-15 LexiconLocation
struct LexiconLocation: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let locationType: String
    let aliases: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, aliases
        case locationType = "location_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.locationType = try c.decodeIfPresent(String.self, forKey: .locationType) ?? ""
        self.aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    init(id: String = "", name: String = "", locationType: String = "", aliases: [String] = []) {
        self.id = id
        self.name = name
        self.locationType = locationType
        self.aliases = aliases
    }
}

// MARK: - 实体词典响应

/// 实体词典响应 — manuscript.ts:26-29
struct EntityLexiconResponse: Codable, Equatable {
    let characters: [LexiconCharacter]
    let locations: [LexiconLocation]
    let props: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case characters, locations, props
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.characters = try c.decodeIfPresent([LexiconCharacter].self, forKey: .characters) ?? []
        self.locations = try c.decodeIfPresent([LexiconLocation].self, forKey: .locations) ?? []
        self.props = try c.decodeIfPresent([AnyCodable].self, forKey: .props) ?? []
    }

    init(characters: [LexiconCharacter] = [], locations: [LexiconLocation] = [], props: [AnyCodable] = []) {
        self.characters = characters
        self.locations = locations
        self.props = props
    }
}

// MARK: - 章节实体提及

/// 章节实体提及，对应原版 manuscript.ts:17-23 ChapterEntityMention
struct ChapterEntityMention: Codable, Identifiable, Equatable {
    var id: String { "\(entityKind)-\(entityId)" }
    let entityKind: String
    let entityId: String
    let displayLabel: String
    let mentionCount: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case entityKind = "entity_kind"
        case entityId = "entity_id"
        case displayLabel = "display_label"
        case mentionCount = "mention_count"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.entityKind = try c.decodeIfPresent(String.self, forKey: .entityKind) ?? ""
        self.entityId = try c.decodeIfPresent(String.self, forKey: .entityId) ?? ""
        self.displayLabel = try c.decodeIfPresent(String.self, forKey: .displayLabel) ?? ""
        self.mentionCount = try c.decodeIfPresent(Int.self, forKey: .mentionCount) ?? 0
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

// MARK: - 章节实体提及响应

/// 章节实体提及列表响应 — manuscript.ts:31-34
struct ChapterMentionsResponse: Codable, Equatable {
    let mentions: [ChapterEntityMention]

    enum CodingKeys: String, CodingKey {
        case mentions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mentions = try c.decodeIfPresent([ChapterEntityMention].self, forKey: .mentions) ?? []
    }
}

// MARK: - 重建索引响应

/// 重建索引响应 — manuscript.ts:41-45
struct ReindexMentionsResponse: Codable, Equatable {
    let ok: Bool
    let mentions: [ChapterEntityMention]

    enum CodingKeys: String, CodingKey {
        case ok, mentions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        self.mentions = try c.decodeIfPresent([ChapterEntityMention].self, forKey: .mentions) ?? []
    }
}

// MARK: - 实体类型辅助

/// 实体类型中文标签 — ManuscriptPropsPanel.vue:208-210
enum EntityKindHelper {
    static func label(_ kind: String) -> String {
        switch kind {
        case "char": return "角色"
        case "loc": return "地点"
        case "faction": return "势力"
        case "prop": return "道具"
        default: return kind
        }
    }
}
