//
//  BibleModels.swift
//  Cangjie
//
//  Bible 设定集模型，字段对齐后端 application/world/dtos/bible_dto.py
//  以及 interfaces/api/v1/world/bible.py 的请求/响应模型。
//

import Foundation

// MARK: - 角色 DTO

/// 角色 DTO，对应后端 CharacterDTO（application/world/dtos/bible_dto.py）
struct CharacterDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let relationships: [AnyCodable]
    let gender: String
    let age: String
    let appearance: String
    let personality: String
    let background: String
    let coreMotivation: String
    let innerLack: String
    let publicProfile: String
    let hiddenProfile: String
    let revealChapter: Int?
    let mentalState: String
    let mentalStateReason: String
    let verbalTic: String
    let idleBehavior: String
    let coreBelief: String
    let moralTaboos: [String]
    let voiceProfile: AnyCodable
    let activeWounds: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case id, name, description, relationships, gender, age, appearance, personality, background
        case coreMotivation = "core_motivation"
        case innerLack = "inner_lack"
        case publicProfile = "public_profile"
        case hiddenProfile = "hidden_profile"
        case revealChapter = "reveal_chapter"
        case mentalState = "mental_state"
        case mentalStateReason = "mental_state_reason"
        case verbalTic = "verbal_tic"
        case idleBehavior = "idle_behavior"
        case coreBelief = "core_belief"
        case moralTaboos = "moral_taboos"
        case voiceProfile = "voice_profile"
        case activeWounds = "active_wounds"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.relationships = try c.decodeIfPresent([AnyCodable].self, forKey: .relationships) ?? []
        self.gender = try c.decodeIfPresent(String.self, forKey: .gender) ?? ""
        self.age = try c.decodeIfPresent(String.self, forKey: .age) ?? ""
        self.appearance = try c.decodeIfPresent(String.self, forKey: .appearance) ?? ""
        self.personality = try c.decodeIfPresent(String.self, forKey: .personality) ?? ""
        self.background = try c.decodeIfPresent(String.self, forKey: .background) ?? ""
        self.coreMotivation = try c.decodeIfPresent(String.self, forKey: .coreMotivation) ?? ""
        self.innerLack = try c.decodeIfPresent(String.self, forKey: .innerLack) ?? ""
        self.publicProfile = try c.decodeIfPresent(String.self, forKey: .publicProfile) ?? ""
        self.hiddenProfile = try c.decodeIfPresent(String.self, forKey: .hiddenProfile) ?? ""
        self.revealChapter = try c.decodeIfPresent(Int.self, forKey: .revealChapter)
        self.mentalState = try c.decodeIfPresent(String.self, forKey: .mentalState) ?? "NORMAL"
        self.mentalStateReason = try c.decodeIfPresent(String.self, forKey: .mentalStateReason) ?? ""
        self.verbalTic = try c.decodeIfPresent(String.self, forKey: .verbalTic) ?? ""
        self.idleBehavior = try c.decodeIfPresent(String.self, forKey: .idleBehavior) ?? ""
        self.coreBelief = try c.decodeIfPresent(String.self, forKey: .coreBelief) ?? ""
        self.moralTaboos = try c.decodeIfPresent([String].self, forKey: .moralTaboos) ?? []
        self.voiceProfile = try c.decodeIfPresent(AnyCodable.self, forKey: .voiceProfile) ?? AnyCodable([:])
        self.activeWounds = try c.decodeIfPresent([AnyCodable].self, forKey: .activeWounds) ?? []
    }
}

// MARK: - 世界设定 DTO

/// 世界设定 DTO
struct WorldSettingDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let settingType: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case settingType = "setting_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.settingType = try c.decodeIfPresent(String.self, forKey: .settingType) ?? ""
    }
}

// MARK: - 地点 DTO

/// 地点 DTO
struct LocationDTO: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let locationType: String
    let parentId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case locationType = "location_type"
        case parentId = "parent_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.locationType = try c.decodeIfPresent(String.self, forKey: .locationType) ?? ""
        self.parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
    }
}

// MARK: - 时间线笔记 DTO

/// 时间线笔记 DTO
struct TimelineNoteDTO: Codable, Identifiable, Equatable {
    let id: String
    let event: String
    let timePoint: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case id, event
        case timePoint = "time_point"
        case description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.event = try c.decodeIfPresent(String.self, forKey: .event) ?? ""
        self.timePoint = try c.decodeIfPresent(String.self, forKey: .timePoint) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

// MARK: - 风格笔记 DTO

/// 风格笔记 DTO
struct StyleNoteDTO: Codable, Identifiable, Equatable {
    let id: String
    let category: String
    let content: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
    }
}

// MARK: - Bible DTO

/// Bible DTO，对应后端 BibleDTO
struct BibleDTO: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let characters: [CharacterDTO]
    let worldSettings: [WorldSettingDTO]
    let locations: [LocationDTO]
    let timelineNotes: [TimelineNoteDTO]
    let styleNotes: [StyleNoteDTO]
    let style: String

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case characters
        case worldSettings = "world_settings"
        case locations
        case timelineNotes = "timeline_notes"
        case styleNotes = "style_notes"
        case style
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.characters = try c.decodeIfPresent([CharacterDTO].self, forKey: .characters) ?? []
        self.worldSettings = try c.decodeIfPresent([WorldSettingDTO].self, forKey: .worldSettings) ?? []
        self.locations = try c.decodeIfPresent([LocationDTO].self, forKey: .locations) ?? []
        self.timelineNotes = try c.decodeIfPresent([TimelineNoteDTO].self, forKey: .timelineNotes) ?? []
        self.styleNotes = try c.decodeIfPresent([StyleNoteDTO].self, forKey: .styleNotes) ?? []
        self.style = try c.decodeIfPresent(String.self, forKey: .style) ?? ""
    }
}

// MARK: - Bible 生成状态

/// Bible 生成状态响应（GET /bible/novels/{id}/bible/status）
struct BibleGenerationStatus: Codable, Equatable {
    let status: String
    let stage: String?
    let progress: Double?
    let message: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.status = dict["status"]?.stringStringValue ?? "idle"
        self.stage = dict["stage"]?.stringStringValue
        self.progress = dict["progress"]?.doubleValue
        self.message = dict["message"]?.stringStringValue
    }
}

// MARK: - Bible 生成反馈

/// Bible 生成反馈（GET /bible/novels/{id}/bible/generation-feedback）
struct BibleGenerationFeedback: Codable, Equatable {
    let feedback: String?
    let suggestions: [String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.feedback = dict["feedback"]?.stringStringValue
        self.suggestions = (dict["suggestions"]?.arrayValue ?? []).compactMap { $0 as? String }
    }
}

// MARK: - 添加角色/设定/地点请求

/// 添加角色请求体，对应后端 AddCharacterRequest（interfaces/api/v1/world/bible.py）
/// 【修复】后端要求 character_id 字段（必填），修复前缺失导致 422 错误。
struct AddCharacterRequest: Codable {
    let characterId: String
    let name: String
    let description: String
    let gender: String?
    let age: String?
    let personality: String?
    let background: String?
    let coreMotivation: String?

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case name, description, gender, age, personality, background
        case coreMotivation = "core_motivation"
    }

    init(
        characterId: String = UUID().uuidString,
        name: String,
        description: String,
        gender: String? = nil,
        age: String? = nil,
        personality: String? = nil,
        background: String? = nil,
        coreMotivation: String? = nil
    ) {
        self.characterId = characterId
        self.name = name
        self.description = description
        self.gender = gender
        self.age = age
        self.personality = personality
        self.background = background
        self.coreMotivation = coreMotivation
    }
}

/// 添加世界设定请求体，对应后端 AddWorldSettingRequest
/// 【修复】后端要求 setting_id 字段（必填），修复前缺失导致 422 错误。
struct AddWorldSettingRequest: Codable {
    let settingId: String
    let name: String
    let description: String
    let settingType: String

    enum CodingKeys: String, CodingKey {
        case settingId = "setting_id"
        case name, description
        case settingType = "setting_type"
    }

    init(
        settingId: String = UUID().uuidString,
        name: String,
        description: String,
        settingType: String
    ) {
        self.settingId = settingId
        self.name = name
        self.description = description
        self.settingType = settingType
    }
}

/// 添加地点请求体，对应后端 AddLocationRequest
/// 【修复】后端要求 location_id 字段（必填），修复前缺失导致 422 错误。
struct AddLocationRequest: Codable {
    let locationId: String
    let name: String
    let description: String
    let locationType: String
    let parentId: String?

    enum CodingKeys: String, CodingKey {
        case locationId = "location_id"
        case name, description
        case locationType = "location_type"
        case parentId = "parent_id"
    }

    init(
        locationId: String = UUID().uuidString,
        name: String,
        description: String,
        locationType: String,
        parentId: String? = nil
    ) {
        self.locationId = locationId
        self.name = name
        self.description = description
        self.locationType = locationType
        self.parentId = parentId
    }
}

/// 添加时间线笔记请求体，对应后端 AddTimelineNoteRequest
/// 【修复】后端要求 note_id 字段（必填），修复前整个模型缺失。
struct AddTimelineNoteRequest: Codable {
    let noteId: String
    let event: String
    let timePoint: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case event
        case timePoint = "time_point"
        case description
    }

    init(
        noteId: String = UUID().uuidString,
        event: String,
        timePoint: String,
        description: String
    ) {
        self.noteId = noteId
        self.event = event
        self.timePoint = timePoint
        self.description = description
    }
}

/// 添加风格笔记请求体，对应后端 AddStyleNoteRequest
/// 【修复】后端要求 note_id 字段（必填），修复前整个模型缺失。
struct AddStyleNoteRequest: Codable {
    let noteId: String
    let category: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case noteId = "note_id"
        case category, content
    }

    init(
        noteId: String = UUID().uuidString,
        category: String,
        content: String
    ) {
        self.noteId = noteId
        self.category = category
        self.content = content
    }
}

// MARK: - BibleDTO 扩展

extension BibleDTO {
    /// 转为字典（用于 API 请求体）
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
