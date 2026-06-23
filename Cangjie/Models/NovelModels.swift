//
//  NovelModels.swift
//  Cangjie
//
//  小说与章节模型，字段对齐后端 application/core/dtos/novel_dto.py + chapter_dto.py + chapter_structure_dto.py
//  以及 interfaces/api/v1/core/novels.py 中的请求模型。
//  空值处理遵循架构 6.7 节：decodeIfPresent + ?? 默认值。
//

import Foundation

// MARK: - 章节状态

/// 章节状态枚举，对应后端 ChapterStatus value object
enum ChapterStatus: String, Codable, CaseIterable {
    case draft
    case completed
}

// MARK: - 小说阶段

/// 小说阶段，对应后端 NovelStage / _public_stage 映射后的粗粒度 stage
enum NovelStage: String, Codable, CaseIterable {
    case planning
    case writing
    case reviewing
    case completed

    /// 中文显示名
    var displayName: String {
        switch self {
        case .planning: return "规划中"
        case .writing: return "写作中"
        case .reviewing: return "审阅中"
        case .completed: return "已完成"
        }
    }
}

/// 自动驾驶运行状态
enum AutopilotRunState: String, Codable {
    case stopped
    case running
    case paused
    case error

    var displayName: String {
        switch self {
        case .stopped: return "已停止"
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .error: return "错误"
        }
    }
}

// MARK: - 章节 DTO

/// 章节 DTO，对应后端 ChapterDTO（application/core/dtos/chapter_dto.py）
///
/// 后端返回字段：id, novel_id, number, title, content, word_count, status, generation_hint
struct ChapterDTO: Codable, Identifiable, Equatable {

    /// 章节 ID
    let id: String

    /// 小说 ID
    let novelId: String

    /// 章节编号
    let number: Int

    /// 章节标题
    let title: String

    /// 章节内容
    let content: String

    /// 字数
    let wordCount: Int

    /// 状态（draft / completed）
    let status: String

    /// 生成提示
    let generationHint: String

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case number, title, content
        case wordCount = "word_count"
        case status
        case generationHint = "generation_hint"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 0
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "draft"
        self.generationHint = try c.decodeIfPresent(String.self, forKey: .generationHint) ?? ""
    }

    init(id: String, novelId: String, number: Int, title: String, content: String,
         wordCount: Int, status: String, generationHint: String = "") {
        self.id = id
        self.novelId = novelId
        self.number = number
        self.title = title
        self.content = content
        self.wordCount = wordCount
        self.status = status
        self.generationHint = generationHint
    }
}

// MARK: - 小说 DTO

/// 小说 DTO，对应后端 NovelDTO（application/core/dtos/novel_dto.py）
///
/// 后端返回字段（snake_case）：id, title, author, target_chapters, stage, premise,
/// chapters, total_word_count, slug, has_bible, has_outline, autopilot_status,
/// auto_approve_mode, locked_genre, locked_world_preset, locked_story_structure,
/// locked_pacing_control, locked_writing_style, locked_special_requirements,
/// target_words_per_chapter, generation_prefs
struct NovelDTO: Codable, Identifiable, Equatable {

    let id: String
    let title: String
    let author: String
    let targetChapters: Int
    let stage: String
    let premise: String
    let chapters: [ChapterDTO]
    let totalWordCount: Int
    let slug: String
    let hasBible: Bool
    let hasOutline: Bool
    let autopilotStatus: String
    let autoApproveMode: Bool
    let lockedGenre: String
    let lockedWorldPreset: String
    let lockedStoryStructure: String
    let lockedPacingControl: String
    let lockedWritingStyle: String
    let lockedSpecialRequirements: String
    let targetWordsPerChapter: Int
    let generationPrefs: AnyCodable

    enum CodingKeys: String, CodingKey {
        case id, title, author, stage, premise, chapters, slug
        case targetChapters = "target_chapters"
        case totalWordCount = "total_word_count"
        case hasBible = "has_bible"
        case hasOutline = "has_outline"
        case autopilotStatus = "autopilot_status"
        case autoApproveMode = "auto_approve_mode"
        case lockedGenre = "locked_genre"
        case lockedWorldPreset = "locked_world_preset"
        case lockedStoryStructure = "locked_story_structure"
        case lockedPacingControl = "locked_pacing_control"
        case lockedWritingStyle = "locked_writing_style"
        case lockedSpecialRequirements = "locked_special_requirements"
        case targetWordsPerChapter = "target_words_per_chapter"
        case generationPrefs = "generation_prefs"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.targetChapters = try c.decodeIfPresent(Int.self, forKey: .targetChapters) ?? 0
        self.stage = try c.decodeIfPresent(String.self, forKey: .stage) ?? "planning"
        self.premise = try c.decodeIfPresent(String.self, forKey: .premise) ?? ""
        self.chapters = try c.decodeIfPresent([ChapterDTO].self, forKey: .chapters) ?? []
        self.totalWordCount = try c.decodeIfPresent(Int.self, forKey: .totalWordCount) ?? 0
        self.slug = try c.decodeIfPresent(String.self, forKey: .slug) ?? ""
        self.hasBible = try c.decodeIfPresent(Bool.self, forKey: .hasBible) ?? false
        self.hasOutline = try c.decodeIfPresent(Bool.self, forKey: .hasOutline) ?? false
        self.autopilotStatus = try c.decodeIfPresent(String.self, forKey: .autopilotStatus) ?? "stopped"
        self.autoApproveMode = try c.decodeIfPresent(Bool.self, forKey: .autoApproveMode) ?? false
        self.lockedGenre = try c.decodeIfPresent(String.self, forKey: .lockedGenre) ?? ""
        self.lockedWorldPreset = try c.decodeIfPresent(String.self, forKey: .lockedWorldPreset) ?? ""
        self.lockedStoryStructure = try c.decodeIfPresent(String.self, forKey: .lockedStoryStructure) ?? ""
        self.lockedPacingControl = try c.decodeIfPresent(String.self, forKey: .lockedPacingControl) ?? ""
        self.lockedWritingStyle = try c.decodeIfPresent(String.self, forKey: .lockedWritingStyle) ?? ""
        self.lockedSpecialRequirements = try c.decodeIfPresent(String.self, forKey: .lockedSpecialRequirements) ?? ""
        self.targetWordsPerChapter = try c.decodeIfPresent(Int.self, forKey: .targetWordsPerChapter) ?? 2500
        self.generationPrefs = try c.decodeIfPresent(AnyCodable.self, forKey: .generationPrefs) ?? AnyCodable([:])
    }

    init(id: String, title: String, author: String, targetChapters: Int,
         stage: String, premise: String, chapters: [ChapterDTO],
         totalWordCount: Int, slug: String, hasBible: Bool, hasOutline: Bool,
         autopilotStatus: String, autoApproveMode: Bool,
         lockedGenre: String, lockedWorldPreset: String,
         lockedStoryStructure: String, lockedPacingControl: String,
         lockedWritingStyle: String, lockedSpecialRequirements: String,
         targetWordsPerChapter: Int, generationPrefs: AnyCodable) {
        self.id = id
        self.title = title
        self.author = author
        self.targetChapters = targetChapters
        self.stage = stage
        self.premise = premise
        self.chapters = chapters
        self.totalWordCount = totalWordCount
        self.slug = slug
        self.hasBible = hasBible
        self.hasOutline = hasOutline
        self.autopilotStatus = autopilotStatus
        self.autoApproveMode = autoApproveMode
        self.lockedGenre = lockedGenre
        self.lockedWorldPreset = lockedWorldPreset
        self.lockedStoryStructure = lockedStoryStructure
        self.lockedPacingControl = lockedPacingControl
        self.lockedWritingStyle = lockedWritingStyle
        self.lockedSpecialRequirements = lockedSpecialRequirements
        self.targetWordsPerChapter = targetWordsPerChapter
        self.generationPrefs = generationPrefs
    }

    /// 阶段枚举
    var stageEnum: NovelStage? {
        return NovelStage(rawValue: stage)
    }

    /// 自动驾驶状态枚举
    var autopilotStatusEnum: AutopilotRunState? {
        return AutopilotRunState(rawValue: autopilotStatus)
    }
}

// MARK: - 创建小说请求

/// 创建小说请求，对应后端 CreateNovelRequest（interfaces/api/v1/core/novels.py）
struct CreateNovelRequest: Codable {

    let novelId: String
    let title: String
    let author: String
    let targetChapters: Int
    let premise: String
    let genre: String
    let worldPreset: String
    let storyStructure: String
    let pacingControl: String
    let writingStyle: String
    let specialRequirements: String
    let lengthTier: String?
    let targetWordsPerChapter: Int?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case title, author, premise, genre
        case targetChapters = "target_chapters"
        case worldPreset = "world_preset"
        case storyStructure = "story_structure"
        case pacingControl = "pacing_control"
        case writingStyle = "writing_style"
        case specialRequirements = "special_requirements"
        case lengthTier = "length_tier"
        case targetWordsPerChapter = "target_words_per_chapter"
    }

    init(
        novelId: String,
        title: String,
        author: String,
        targetChapters: Int = 100,
        premise: String = "",
        genre: String = "",
        worldPreset: String = "",
        storyStructure: String = "",
        pacingControl: String = "",
        writingStyle: String = "",
        specialRequirements: String = "",
        lengthTier: String? = nil,
        targetWordsPerChapter: Int? = nil
    ) {
        self.novelId = novelId
        self.title = title
        self.author = author
        self.targetChapters = targetChapters
        self.premise = premise
        self.genre = genre
        self.worldPreset = worldPreset
        self.storyStructure = storyStructure
        self.pacingControl = pacingControl
        self.writingStyle = writingStyle
        self.specialRequirements = specialRequirements
        self.lengthTier = lengthTier
        self.targetWordsPerChapter = targetWordsPerChapter
    }
}

// MARK: - 更新小说请求

/// 更新小说请求，对应后端 UpdateNovelRequest
struct UpdateNovelRequest: Codable {

    let title: String?
    let author: String?
    let targetChapters: Int?
    let premise: String?
    let targetWordsPerChapter: Int?
    let generationPrefs: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case title, author, premise
        case targetChapters = "target_chapters"
        case targetWordsPerChapter = "target_words_per_chapter"
        case generationPrefs = "generation_prefs"
    }
}

// MARK: - 更新阶段请求

/// 更新阶段请求
struct UpdateStageRequest: Codable {
    let stage: String
}

// MARK: - 更新自动审阅模式请求

/// 更新全自动模式请求
struct UpdateAutoApproveRequest: Codable {
    let autoApproveMode: Bool

    enum CodingKeys: String, CodingKey {
        case autoApproveMode = "auto_approve_mode"
    }
}

// MARK: - 章节审阅

/// 章节审阅响应，对应后端 ChapterReviewResponse
struct ChapterReviewResponse: Codable, Equatable {
    let status: String
    let memo: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case status, memo
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "draft"
        self.memo = try c.decodeIfPresent(String.self, forKey: .memo) ?? ""
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

/// 保存章节审阅请求
struct SaveChapterReviewRequest: Codable {
    let status: String
    let memo: String
}

// MARK: - AI 审阅

/// AI 审阅请求
struct ChapterAIReviewRequest: Codable {
    let save: Bool?
}

/// AI 审阅响应
struct ChapterAIReviewResponse: Codable, Equatable {
    let ok: Bool
    let status: String
    let memo: String
    let saved: Bool
    let score: Int
    let suggestions: [String]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.memo = try c.decodeIfPresent(String.self, forKey: .memo) ?? ""
        self.saved = try c.decodeIfPresent(Bool.self, forKey: .saved) ?? false
        self.score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        self.suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
    }
}

// MARK: - 章节结构分析

/// 章节结构分析响应
struct ChapterStructureResponse: Codable, Equatable {
    let wordCount: Int
    let paragraphCount: Int
    let dialogueRatio: Double
    let sceneCount: Int
    let pacing: String

    enum CodingKeys: String, CodingKey {
        case wordCount = "word_count"
        case paragraphCount = "paragraph_count"
        case dialogueRatio = "dialogue_ratio"
        case sceneCount = "scene_count"
        case pacing
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.paragraphCount = try c.decodeIfPresent(Int.self, forKey: .paragraphCount) ?? 0
        self.dialogueRatio = try c.decodeIfPresent(Double.self, forKey: .dialogueRatio) ?? 0.0
        self.sceneCount = try c.decodeIfPresent(Int.self, forKey: .sceneCount) ?? 0
        self.pacing = try c.decodeIfPresent(String.self, forKey: .pacing) ?? ""
    }
}

// MARK: - 章节草稿

/// 章节历史草稿响应
struct ChapterDraftResponse: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let chapterId: String
    let chapterNumber: Int
    let content: String
    let outline: String
    let source: String
    let wordCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case chapterId = "chapter_id"
        case chapterNumber = "chapter_number"
        case content, outline, source
        case wordCount = "word_count"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.chapterId = try c.decodeIfPresent(String.self, forKey: .chapterId) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.outline = try c.decodeIfPresent(String.self, forKey: .outline) ?? ""
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
        self.wordCount = try c.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
    }
}

// MARK: - 更新章节内容请求

/// 更新章节内容请求
struct UpdateChapterContentRequest: Codable {
    let content: String
}

/// 更新章节生成约束请求
struct UpdateChapterHintRequest: Codable {
    let generationHint: String

    enum CodingKeys: String, CodingKey {
        case generationHint = "generation_hint"
    }
}

// MARK: - 章节元素

/// 章节元素创建请求
struct ChapterElementCreate: Codable {
    let elementType: String
    let elementId: String
    let relationType: String
    let importance: String?
    let appearanceOrder: Int?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case elementType = "element_type"
        case elementId = "element_id"
        case relationType = "relation_type"
        case importance
        case appearanceOrder = "appearance_order"
        case notes
    }
}

// MARK: - 小说统计

/// 小说统计响应（GET /novels/{id}/statistics）
struct NovelStatistics: Codable, Equatable {
    let totalWords: Int
    let completedChapters: Int
    let totalChapters: Int
    let avgWordsPerChapter: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.totalWords = dict["total_words"]?.intValue ?? 0
        self.completedChapters = dict["completed_chapters"]?.intValue ?? 0
        self.totalChapters = dict["total_chapters"]?.intValue ?? 0
        self.avgWordsPerChapter = dict["avg_words_per_chapter"]?.doubleValue ?? 0.0
    }
}
