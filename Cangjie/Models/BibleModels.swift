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

    /// 显式 memberwise init（T04教训8）
    init(id: String, event: String, timePoint: String, description: String) {
        self.id = id
        self.event = event
        self.timePoint = timePoint
        self.description = description
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

/// Bible 生成状态响应，对应原版 bible.ts:252-256 getBibleStatus 返回类型
/// GET /bible/novels/{id}/bible/status 返回 { exists, ready, novel_id }
struct BibleGenerationStatus: Codable, Equatable {
    /// Bible 是否存在（bible.ts:253）
    let exists: Bool
    /// Bible 是否就绪（bible.ts:253）
    let ready: Bool
    /// 小说 ID（bible.ts:253）
    let novelId: String

    enum CodingKeys: String, CodingKey {
        case exists, ready
        case novelId = "novel_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.exists = try c.decodeIfPresent(Bool.self, forKey: .exists) ?? false
        self.ready = try c.decodeIfPresent(Bool.self, forKey: .ready) ?? false
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
    }
}

// MARK: - Bible 生成反馈

/// Bible 生成反馈，对应原版 bible.ts:262-275 getBibleGenerationFeedback 返回类型
/// GET /bible/novels/{id}/bible/generation-feedback 返回 { novel_id, error, stage, at }
struct BibleGenerationFeedback: Codable, Equatable {
    /// 小说 ID（bible.ts:264）
    let novelId: String
    /// 错误信息，成功或未失败时为 null（bible.ts:265）
    let error: String?
    /// 生成阶段，失败时为当前阶段，成功时为 null（bible.ts:266）
    let stage: String?
    /// 时间戳（bible.ts:267）
    let at: String?

    enum CodingKeys: String, CodingKey {
        case error, stage, at
        case novelId = "novel_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        self.stage = try c.decodeIfPresent(String.self, forKey: .stage)
        self.at = try c.decodeIfPresent(String.self, forKey: .at)
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

// MARK: - 子模型字典扩展（用于 updateBible 请求体）

extension CharacterDTO {
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

extension WorldSettingDTO {
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

extension LocationDTO {
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

extension TimelineNoteDTO {
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

extension StyleNoteDTO {
    var dictionaryValue: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

// MARK: - Bible SSE 事件模型（对齐 bible.ts:283-334）

/// 世界观维度数据（bible.ts:283-287）
struct WorldbuildingDimensionData: Codable, Equatable {
    let dimension: String
    let label: String
    let content: [String: String]
}

/// Bible SSE phase 事件（bible.ts:290-294）
struct BibleStreamPhaseEvent: Equatable {
    let phase: String
    let message: String
}

/// Bible SSE done 事件（bible.ts:308-313）
struct BibleStreamDoneEvent: Equatable {
    let message: String
    let novelId: String
    let invocationSessionId: String?
}

/// Bible SSE error 事件（bible.ts:323-326）
struct BibleStreamErrorEvent: Equatable {
    let message: String
}

/// Bible SSE approval_required 事件（bible.ts:315-321）
struct BibleStreamApprovalRequiredEvent: Equatable {
    let sessionId: String
    let status: String?
    let nextAction: String?
    let stage: String?
}

// MARK: - 世界观维度常量（bibleSetupModel.ts:4）

/// 世界观5维度常量数组（bibleSetupModel.ts:4）
let WB_DIMS: [String] = ["core_rules", "geography", "society", "culture", "daily_life"]

/// 维度中文标签映射
func worldbuildingDimensionLabel(_ dim: String) -> String {
    switch dim {
    case "core_rules": return "核心法则"
    case "geography": return "地理生态"
    case "society": return "社会结构"
    case "culture": return "历史文化"
    case "daily_life": return "沉浸感细节"
    default: return dim
    }
}

/// 空的世界观数据结构（bibleSetupModel.ts:26-34）
func emptyWorldbuildingData() -> [String: [String: String]] {
    var result: [String: [String: String]] = [:]
    for dim in WB_DIMS {
        result[dim] = [:]
    }
    return result
}

// MARK: - 可编辑角色模型（characterSetupModel.ts:25-49）

/// 可编辑角色模型（characterSetupModel.ts:25-49）
struct EditableCharacter: Identifiable, Equatable {
    var id: String
    var name: String
    var role: String
    var description: String
    var gender: String
    var age: String
    var appearance: String
    var personality: String
    var background: String
    var coreMotivation: String
    var innerLack: String
    var mentalState: String
    var mentalStateReason: String
    var verbalTic: String
    var idleBehavior: String
    var relationships: [EditableRelationship]
    var publicProfile: String
    var hiddenProfile: String
    var revealChapter: Int?
    var coreBelief: String
    var moralTaboos: [String]
    var voiceProfile: EditableVoiceProfile
    var activeWounds: [EditableWound]

    init(
        id: String = "",
        name: String = "",
        role: String = "",
        description: String = "",
        gender: String = "",
        age: String = "",
        appearance: String = "",
        personality: String = "",
        background: String = "",
        coreMotivation: String = "",
        innerLack: String = "",
        mentalState: String = "",
        mentalStateReason: String = "",
        verbalTic: String = "",
        idleBehavior: String = "",
        relationships: [EditableRelationship] = [],
        publicProfile: String = "",
        hiddenProfile: String = "",
        revealChapter: Int? = nil,
        coreBelief: String = "",
        moralTaboos: [String] = [],
        voiceProfile: EditableVoiceProfile = EditableVoiceProfile(),
        activeWounds: [EditableWound] = []
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.description = description
        self.gender = gender
        self.age = age
        self.appearance = appearance
        self.personality = personality
        self.background = background
        self.coreMotivation = coreMotivation
        self.innerLack = innerLack
        self.mentalState = mentalState
        self.mentalStateReason = mentalStateReason
        self.verbalTic = verbalTic
        self.idleBehavior = idleBehavior
        self.relationships = relationships
        self.publicProfile = publicProfile
        self.hiddenProfile = hiddenProfile
        self.revealChapter = revealChapter
        self.coreBelief = coreBelief
        self.moralTaboos = moralTaboos
        self.voiceProfile = voiceProfile
        self.activeWounds = activeWounds
    }
}

/// 可编辑关系（characterSetupModel.ts:19-23）
struct EditableRelationship: Equatable {
    var target: String
    var relation: String
    var description: String

    init(target: String = "", relation: String = "", description: String = "") {
        self.target = target
        self.relation = relation
        self.description = description
    }
}

/// 可编辑声线配置（characterSetupModel.ts:3-10）
struct EditableVoiceProfile: Equatable {
    var style: String
    var sentencePattern: String
    var speechTempo: String
    var metaphors: [String]?
    var catchphrases: [String]?

    init(
        style: String = "",
        sentencePattern: String = "",
        speechTempo: String = "",
        metaphors: [String]? = nil,
        catchphrases: [String]? = nil
    ) {
        self.style = style
        self.sentencePattern = sentencePattern
        self.speechTempo = speechTempo
        self.metaphors = metaphors
        self.catchphrases = catchphrases
    }
}

/// 可编辑创伤（characterSetupModel.ts:12-17）
struct EditableWound: Equatable {
    var description: String
    var trigger: String
    var effect: String

    init(description: String = "", trigger: String = "", effect: String = "") {
        self.description = description
        self.trigger = trigger
        self.effect = effect
    }
}

// MARK: - 生成角色载荷（characterSetupModel.ts:51-64）

/// 生成角色载荷，对应 GeneratedCharacterPayload（characterSetupModel.ts:51-64）
/// 含 ghost/want/need/flaw fallback 字段
struct GeneratedCharacterPayload {
    let id: String?
    let name: String?
    let description: String?
    let role: String?
    let gender: String?
    let age: String?
    let appearance: String?
    let personality: String?
    let background: String?
    let coreMotivation: String?
    let innerLack: String?
    let mentalState: String?
    let mentalStateReason: String?
    let verbalTic: String?
    let idleBehavior: String?
    let relationships: [Any]?
    let publicProfile: String?
    let hiddenProfile: String?
    let revealChapter: Int?
    let coreBelief: String?
    let moralTaboos: [String]?
    let voiceProfile: Any?
    let activeWounds: Any?
    // fallback 字段（characterSetupModel.ts:58-63）
    let ghost: String?
    let want: String?
    let need: String?
    let flaw: String?

    /// 从 SSE data 事件的 content 字典构造（bible.ts:455-456, payload 为 Record<string, unknown>）
    init(content: [String: Any]) {
        self.id = content["id"] as? String
        self.name = content["name"] as? String
        self.description = content["description"] as? String
        self.role = content["role"] as? String
        self.gender = content["gender"] as? String
        self.age = content["age"] as? String
        self.appearance = content["appearance"] as? String
        self.personality = content["personality"] as? String
        self.background = content["background"] as? String
        self.coreMotivation = content["core_motivation"] as? String
        self.innerLack = content["inner_lack"] as? String
        self.mentalState = content["mental_state"] as? String
        self.mentalStateReason = content["mental_state_reason"] as? String
        self.verbalTic = content["verbal_tic"] as? String
        self.idleBehavior = content["idle_behavior"] as? String
        self.relationships = content["relationships"] as? [Any]
        self.publicProfile = content["public_profile"] as? String
        self.hiddenProfile = content["hidden_profile"] as? String
        self.revealChapter = content["reveal_chapter"] as? Int
        self.coreBelief = content["core_belief"] as? String
        self.moralTaboos = content["moral_taboos"] as? [String]
        self.voiceProfile = content["voice_profile"]
        self.activeWounds = content["active_wounds"]
        self.ghost = content["ghost"] as? String
        self.want = content["want"] as? String
        self.need = content["need"] as? String
        self.flaw = content["flaw"] as? String
    }
}

// MARK: - 流式地点模型

/// 流式生成地点模型（NovelSetupGuide.vue:1627-1676, streamingLocations 元素结构）
struct GeneratedLocation: Identifiable, Equatable {
    let id: String
    var name: String
    var type: String
    var locationType: String
    var description: String

    init(id: String = UUID().uuidString, name: String = "", type: String = "", locationType: String = "", description: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.locationType = locationType
        self.description = description
    }

    /// 从 SSE data 事件的 content 字典构造（bible.ts:459-460）
    init(content: [String: Any]) {
        self.id = (content["id"] as? String) ?? UUID().uuidString
        self.name = (content["name"] as? String) ?? ""
        self.type = (content["type"] as? String) ?? ""
        self.locationType = (content["location_type"] as? String) ?? ""
        self.description = (content["description"] as? String) ?? ""
    }
}

// MARK: - 角色映射辅助函数（characterSetupModel.ts:116-174）

/// 从 description 中拆分 "role - description" 格式（characterSetupModel.ts:116-134）
/// 如果 role 为空但 description 含 " - "，则拆分；
/// 如果 role 有值且 description 以 role 开头且含 " - "，则去掉前缀。
func normalizeCharacterRoleAndDescription(role: String?, description: String?) -> (role: String, description: String) {
    var nextRole = role ?? ""
    var nextDescription = description ?? ""

    if nextRole.isEmpty && nextDescription.contains(" - ") {
        if let range = nextDescription.range(of: " - ") {
            let sepIdx = nextDescription.distance(from: nextDescription.startIndex, to: range.lowerBound)
            nextRole = String(nextDescription.prefix(sepIdx)).trimmingCharacters(in: .whitespaces)
            nextDescription = String(nextDescription.suffix(from: nextDescription.index(nextDescription.startIndex, offsetBy: sepIdx + 3))).trimmingCharacters(in: .whitespaces)
        }
    } else if !nextRole.isEmpty && nextDescription.hasPrefix(nextRole) && nextDescription.contains(" - ") {
        if let range = nextDescription.range(of: " - ") {
            let sepIdx = nextDescription.distance(from: nextDescription.startIndex, to: range.lowerBound)
            nextDescription = String(nextDescription.suffix(from: nextDescription.index(nextDescription.startIndex, offsetBy: sepIdx + 3))).trimmingCharacters(in: .whitespaces)
        }
    }

    return (nextRole, nextDescription)
}

/// 归一化关系列表（characterSetupModel.ts:84-95）
/// 字符串 → {target:str, relation:'', description:''}；对象 → {target, relation, description}
func normalizeRelationships(_ raw: [Any]?) -> [EditableRelationship] {
    guard let raw = raw else { return [] }
    return raw.compactMap { item -> EditableRelationship? in
        if let str = item as? String {
            return EditableRelationship(target: str, relation: "", description: "")
        }
        if let dict = item as? [String: Any] {
            return EditableRelationship(
                target: (dict["target"] as? String) ?? "",
                relation: (dict["relation"] as? String) ?? "",
                description: (dict["description"] as? String) ?? ""
            )
        }
        return nil
    }
}

/// 归一化声线配置（characterSetupModel.ts:66-73）
func normalizeVoiceProfile(_ raw: Any?) -> EditableVoiceProfile {
    guard let dict = raw as? [String: Any] else {
        return EditableVoiceProfile()
    }
    return EditableVoiceProfile(
        style: (dict["style"] as? String) ?? "",
        sentencePattern: (dict["sentence_pattern"] as? String) ?? "",
        speechTempo: (dict["speech_tempo"] as? String) ?? "",
        metaphors: dict["metaphors"] as? [String],
        catchphrases: dict["catchphrases"] as? [String]
    )
}

/// 归一化创伤列表（characterSetupModel.ts:75-82）
func normalizeWounds(_ raw: Any?) -> [EditableWound] {
    guard let array = raw as? [[String: Any]] else { return [] }
    return array.map { wound in
        EditableWound(
            description: (wound["description"] as? String) ?? "",
            trigger: (wound["trigger"] as? String) ?? "",
            effect: (wound["effect"] as? String) ?? ""
        )
    }
}

/// 角色草稿 key（characterSetupModel.ts:143-145）
func characterDraftKey(id: String?, name: String?) -> String {
    return (id ?? name ?? "").trimmingCharacters(in: .whitespaces).lowercased()
}

/// 将生成角色载荷映射为可编辑角色（characterSetupModel.ts:147-174）
/// 含 fallback 逻辑：personality→flaw、background→ghost、core_motivation→want、inner_lack→need
func mapGeneratedCharacterToEditable(_ payload: GeneratedCharacterPayload) -> EditableCharacter {
    let normalized = normalizeCharacterRoleAndDescription(role: payload.role, description: payload.description)

    return EditableCharacter(
        id: payload.id ?? "",
        name: payload.name ?? "",
        role: normalized.role,
        description: normalized.description,
        gender: payload.gender ?? "",
        age: payload.age ?? "",
        appearance: payload.appearance ?? "",
        personality: payload.personality ?? payload.flaw ?? "",  // fallback flaw（characterSetupModel.ts:157）
        background: payload.background ?? payload.ghost ?? "",   // fallback ghost（characterSetupModel.ts:158）
        coreMotivation: payload.coreMotivation ?? payload.want ?? "",  // fallback want（characterSetupModel.ts:159）
        innerLack: payload.innerLack ?? payload.need ?? "",      // fallback need（characterSetupModel.ts:160）
        mentalState: payload.mentalState ?? "",
        mentalStateReason: payload.mentalStateReason ?? "",
        verbalTic: payload.verbalTic ?? "",
        idleBehavior: payload.idleBehavior ?? "",
        relationships: normalizeRelationships(payload.relationships),  // characterSetupModel.ts:165
        publicProfile: payload.publicProfile ?? "",
        hiddenProfile: payload.hiddenProfile ?? "",
        revealChapter: payload.revealChapter,                     // characterSetupModel.ts:168
        coreBelief: payload.coreBelief ?? "",
        moralTaboos: payload.moralTaboos ?? [],                  // characterSetupModel.ts:170
        voiceProfile: normalizeVoiceProfile(payload.voiceProfile),  // characterSetupModel.ts:171
        activeWounds: normalizeWounds(payload.activeWounds)       // characterSetupModel.ts:172
    )
}

/// 将 Bible CharacterDTO 映射为可编辑角色，用 fallback 回填流式生成时缺失的字段（characterSetupModel.ts:176-214）
func mapCharacterToEditable(_ character: CharacterDTO, fallback: EditableCharacter? = nil) -> EditableCharacter {
    // CharacterDTO.role 从 description 拆分得到（characterSetupModel.ts:180-181）
    // 已经通过 CharacterDTO.role 扩展属性拆分，直接使用
    let charRole = character.role
    let normalized = normalizeCharacterRoleAndDescription(
        role: charRole.isEmpty ? nil : charRole,
        description: charRole.isEmpty ? character.description : character.pureDescription
    )

    // relationships: 优先用 character 自带，否则用 fallback
    let charRelationships: [Any]? = character.relationships.isEmpty ? nil : character.relationships.map { $0.value }
    let fallbackRelationships: [Any]? = fallback?.relationships.map { rel -> [String: Any] in
        ["target": rel.target, "relation": rel.relation, "description": rel.description] as [String: Any]
    }
    let relationships = normalizeRelationships(
        (charRelationships != nil) ? charRelationships : fallbackRelationships
    )

    // moralTaboos: 优先用 character 自带，否则用 fallback
    let moralTaboos = (!character.moralTaboos.isEmpty) ? character.moralTaboos : (fallback?.moralTaboos ?? [])

    // voiceProfile: 优先用 character 自带，否则用 fallback
    // CI#29 修复：Any 类型不能直接与 nil 比较，改用 NSNull 检查 + 空字典检查
    let vpVal = character.voiceProfile.value
    let voiceProfileRaw: Any? = (!(vpVal is NSNull) && !(vpVal is [String: Any] && (vpVal as? [String: Any])?.isEmpty == true))
        ? vpVal
        : (fallback?.voiceProfile != nil ? ["style": fallback!.voiceProfile.style, "sentence_pattern": fallback!.voiceProfile.sentencePattern, "speech_tempo": fallback!.voiceProfile.speechTempo] as [String: Any] : nil)
    let voiceProfile = normalizeVoiceProfile(voiceProfileRaw)

    // activeWounds: 优先用 character 自带，否则用 fallback
    let woundsRaw: [Any]? = (!character.activeWounds.isEmpty)
        ? character.activeWounds.map { $0.value }
        : fallback?.activeWounds.map { w -> [String: Any] in
            ["description": w.description, "trigger": w.trigger, "effect": w.effect] as [String: Any]
        }
    let activeWounds = normalizeWounds(woundsRaw)

    return EditableCharacter(
        id: character.id.isEmpty ? (fallback?.id ?? "") : character.id,
        name: character.name.isEmpty ? (fallback?.name ?? "") : character.name,
        role: normalized.role.isEmpty ? (fallback?.role ?? "") : normalized.role,
        description: normalized.description.isEmpty ? (fallback?.description ?? "") : normalized.description,
        gender: character.gender.isEmpty ? (fallback?.gender ?? "") : character.gender,
        age: character.age.isEmpty ? (fallback?.age ?? "") : character.age,
        appearance: character.appearance.isEmpty ? (fallback?.appearance ?? "") : character.appearance,
        personality: character.personality.isEmpty ? (fallback?.personality ?? "") : character.personality,
        background: character.background.isEmpty ? (fallback?.background ?? "") : character.background,
        coreMotivation: character.coreMotivation.isEmpty ? (fallback?.coreMotivation ?? "") : character.coreMotivation,
        innerLack: character.innerLack.isEmpty ? (fallback?.innerLack ?? "") : character.innerLack,
        mentalState: character.mentalState.isEmpty ? (fallback?.mentalState ?? "") : character.mentalState,
        mentalStateReason: character.mentalStateReason.isEmpty ? (fallback?.mentalStateReason ?? "") : character.mentalStateReason,
        verbalTic: character.verbalTic.isEmpty ? (fallback?.verbalTic ?? "") : character.verbalTic,
        idleBehavior: character.idleBehavior.isEmpty ? (fallback?.idleBehavior ?? "") : character.idleBehavior,
        relationships: relationships,
        publicProfile: character.publicProfile.isEmpty ? (fallback?.publicProfile ?? "") : character.publicProfile,
        hiddenProfile: character.hiddenProfile.isEmpty ? (fallback?.hiddenProfile ?? "") : character.hiddenProfile,
        revealChapter: character.revealChapter ?? fallback?.revealChapter,
        coreBelief: character.coreBelief.isEmpty ? (fallback?.coreBelief ?? "") : character.coreBelief,
        moralTaboos: moralTaboos,
        voiceProfile: voiceProfile,
        activeWounds: activeWounds
    )
}

// MARK: - CharacterDTO 角色字段扩展

extension CharacterDTO {
    /// 角色字段（从 description 拆分 "role - description" 格式，characterSetupModel.ts:116-134）
    /// CharacterDTO 本身没有 role 字段，后端将 role 编码在 description 中
    var role: String {
        return normalizeCharacterRoleAndDescription(role: nil, description: description).role
    }

    /// 拆分后的纯描述（去掉 role 前缀）
    var pureDescription: String {
        return normalizeCharacterRoleAndDescription(role: nil, description: description).description
    }
}

// MARK: - 更新 Bible 请求体（bible.ts:225-234, NovelSetupGuide.vue:1912-1931）

/// 更新 Bible 请求体，对应 PUT /bible/novels/{id}/bible（bible.ts:225-234）
struct UpdateBibleRequest: Codable {
    let characters: [AnyCodable]
    let worldSettings: [AnyCodable]
    let locations: [AnyCodable]
    let timelineNotes: [AnyCodable]
    let styleNotes: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case characters
        case worldSettings = "world_settings"
        case locations
        case timelineNotes = "timeline_notes"
        case styleNotes = "style_notes"
    }
}
