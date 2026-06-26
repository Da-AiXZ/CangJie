//
//  ChapterEditModels.swift
//  Cangjie
//
//  P0-3 独立章节编辑页模型 + P0-2 上下文预览/场记分析模型。
//  字段对齐原版 api/chapter.ts + api/workflow.ts + api/knowledgeGraph.ts。
//
//  注意：InferenceFactBundle / InferenceProvenanceRow / ChapterInferenceEvidenceData
//  已在 KnowledgeGraphModels.swift 中定义（Grep 查重确认，铁律 #11），此处不重复声明。
//

import Foundation

// MARK: - 章节结构分析 — chapter.ts ChapterStructureDTO

/// 章节结构分析，对齐原版 chapter.ts ChapterStructureDTO
///
/// ```typescript
/// export interface ChapterStructureDTO {
///   word_count: number
///   paragraph_count: number
///   dialogue_ratio: number
///   scene_count: number
///   pacing: string
/// }
/// ```
struct ChapterStructureAnalysis: Codable, Equatable {
    /// 分析字数 — chapter.ts
    let wordCount: Int
    /// 分析段落数 — chapter.ts
    let paragraphCount: Int
    /// 对话占比（0.0-1.0）— chapter.ts
    let dialogueRatio: Double
    /// 场景数 — chapter.ts
    let sceneCount: Int
    /// 节奏（如 "fast"/"medium"/"slow"）— chapter.ts
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

    /// 显式 memberwise init
    init(wordCount: Int, paragraphCount: Int, dialogueRatio: Double, sceneCount: Int, pacing: String) {
        self.wordCount = wordCount
        self.paragraphCount = paragraphCount
        self.dialogueRatio = dialogueRatio
        self.sceneCount = sceneCount
        self.pacing = pacing
    }

    /// 对话占比百分比显示（0-100）
    var dialogueRatioPercent: Int {
        return Int(dialogueRatio * 100)
    }
}

// MARK: - 推断证据 API 响应包装

/// 推断证据 API 响应包装，对齐原版 knowledgeGraph.ts:60-68
/// `Promise<{ success: boolean; data: ChapterInferenceEvidenceData }>`
struct InferenceEvidenceAPIResponse: Codable, Equatable {
    let success: Bool
    let data: ChapterInferenceEvidenceData

    enum CodingKeys: String, CodingKey {
        case success, data
    }

    init(success: Bool = false, data: ChapterInferenceEvidenceData = ChapterInferenceEvidenceData()) {
        self.success = success
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.data = try c.decodeIfPresent(ChapterInferenceEvidenceData.self, forKey: .data) ?? ChapterInferenceEvidenceData()
    }
}

/// 删除推断三元组 API 响应，对齐原版 knowledgeGraph.ts:80-88
/// `Promise<{ success: boolean; message: string }>`
struct DeleteInferredTripleResponse: Codable, Equatable {
    let success: Bool
    let message: String

    enum CodingKeys: String, CodingKey {
        case success, message
    }

    init(success: Bool = false, message: String = "") {
        self.success = success
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        self.message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
    }
}

// MARK: - 场记分析 — workflow.ts:216-224 SceneDirectorAnalysis

/// 场记分析结果，对齐原版 workflow.ts:216-224 SceneDirectorAnalysis
/// POST /novels/{novelId}/scene-director/analyze 响应体
///
/// ```typescript
/// export interface SceneDirectorAnalysis {
///   chapter_number: number
///   outline: string
///   pov_character?: string
///   location?: string
///   entities?: string[]
///   tone?: string
///   [key: string]: unknown
/// }
/// ```
struct SceneDirectorAnalysis: Codable, Equatable {
    /// 章节编号 — workflow.ts:217
    let chapterNumber: Int
    /// 大纲 — workflow.ts:218
    let outline: String
    /// 视角角色（可选）— workflow.ts:219
    let povCharacter: String?
    /// 地点（可选）— workflow.ts:220
    let location: String?
    /// 涉及实体列表（可选）— workflow.ts:221
    let entities: [String]?
    /// 基调（可选）— workflow.ts:222
    let tone: String?
    /// 原始 JSON 数据（对齐 [key: string]: unknown 索引签名）
    let rawData: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case outline
        case povCharacter = "pov_character"
        case location
        case entities
        case tone
    }

    init(from decoder: Decoder) throws {
        // 先用 singleValueContainer 获取完整字典（对齐 [key: string]: unknown 索引签名）
        let single = try decoder.singleValueContainer()
        let fullDict = try single.decode([String: AnyCodable].self)

        self.chapterNumber = fullDict["chapter_number"]?.intValue ?? 0
        self.outline = fullDict["outline"]?.stringStringValue ?? ""
        self.povCharacter = fullDict["pov_character"]?.stringStringValue
        self.location = fullDict["location"]?.stringStringValue
        // entities 可能是 [String] 或 [AnyCodable]
        if let entitiesArr = fullDict["entities"]?.arrayValue {
            self.entities = entitiesArr.compactMap { AnyCodable($0).stringStringValue }
        } else {
            self.entities = nil
        }
        self.tone = fullDict["tone"]?.stringStringValue
        // 捕获完整原始 JSON
        self.rawData = AnyCodable(fullDict.mapValues { $0.value })
    }

    /// 显式 memberwise init
    init(chapterNumber: Int, outline: String, povCharacter: String? = nil,
         location: String? = nil, entities: [String]? = nil, tone: String? = nil,
         rawData: AnyCodable? = nil) {
        self.chapterNumber = chapterNumber
        self.outline = outline
        self.povCharacter = povCharacter
        self.location = location
        self.entities = entities
        self.tone = tone
        self.rawData = rawData
    }
}

// MARK: - 上下文预览 — workflow.ts:883-900

/// 上下文层内容，对齐原版 workflow.ts:883-885 ContextLayerContent
///
/// ```typescript
/// export interface ContextLayerContent {
///   content: string
/// }
/// ```
struct ContextLayerContent: Codable, Equatable {
    /// 层内容文本 — workflow.ts:884
    let content: String

    enum CodingKeys: String, CodingKey {
        case content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
    }

    init(content: String) {
        self.content = content
    }
}

/// 上下文 Token 用量，对齐原版 workflow.ts:887-894 ContextTokenUsage
///
/// ```typescript
/// export interface ContextTokenUsage {
///   layer1: number
///   layer2: number
///   layer3: number
///   total: number
///   limit: number
/// }
/// ```
struct ContextTokenUsage: Codable, Equatable {
    /// 第一层 Token 数 — workflow.ts:888
    let layer1: Int
    /// 第二层 Token 数 — workflow.ts:889
    let layer2: Int
    /// 第三层 Token 数 — workflow.ts:890
    let layer3: Int
    /// 总 Token 数 — workflow.ts:891
    let total: Int
    /// Token 上限 — workflow.ts:892
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case layer1, layer2, layer3, total, limit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.layer1 = try c.decodeIfPresent(Int.self, forKey: .layer1) ?? 0
        self.layer2 = try c.decodeIfPresent(Int.self, forKey: .layer2) ?? 0
        self.layer3 = try c.decodeIfPresent(Int.self, forKey: .layer3) ?? 0
        self.total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        self.limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 0
    }

    init(layer1: Int, layer2: Int, layer3: Int, total: Int, limit: Int) {
        self.layer1 = layer1
        self.layer2 = layer2
        self.layer3 = layer3
        self.total = total
        self.limit = limit
    }

    /// Token 使用率（0.0-1.0），limit 为 0 时返回 0
    var usageRatio: Double {
        guard limit > 0 else { return 0 }
        return Double(total) / Double(limit)
    }
}

/// 上下文预览结果，对齐原版 workflow.ts:896-901 ContextPreviewResult
/// POST /novels/{novelId}/context/retrieve 响应体
///
/// ```typescript
/// export interface ContextPreviewResult {
///   layer1: ContextLayerContent
///   layer2: ContextLayerContent
///   layer3: ContextLayerContent
///   token_usage: ContextTokenUsage
/// }
/// ```
struct ContextPreviewResult: Codable, Equatable {
    /// 第一层上下文（全局设定）— workflow.ts:897
    let layer1: ContextLayerContent
    /// 第二层上下文（近期章节）— workflow.ts:898
    let layer2: ContextLayerContent
    /// 第三层上下文（本章相关）— workflow.ts:899
    let layer3: ContextLayerContent
    /// Token 用量统计 — workflow.ts:900
    let tokenUsage: ContextTokenUsage

    enum CodingKeys: String, CodingKey {
        case layer1, layer2, layer3
        case tokenUsage = "token_usage"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.layer1 = try c.decodeIfPresent(ContextLayerContent.self, forKey: .layer1) ?? ContextLayerContent(content: "")
        self.layer2 = try c.decodeIfPresent(ContextLayerContent.self, forKey: .layer2) ?? ContextLayerContent(content: "")
        self.layer3 = try c.decodeIfPresent(ContextLayerContent.self, forKey: .layer3) ?? ContextLayerContent(content: "")
        self.tokenUsage = try c.decodeIfPresent(ContextTokenUsage.self, forKey: .tokenUsage) ?? ContextTokenUsage(layer1: 0, layer2: 0, layer3: 0, total: 0, limit: 0)
    }

    init(layer1: ContextLayerContent, layer2: ContextLayerContent, layer3: ContextLayerContent, tokenUsage: ContextTokenUsage) {
        self.layer1 = layer1
        self.layer2 = layer2
        self.layer3 = layer3
        self.tokenUsage = tokenUsage
    }
}

// MARK: - 主线推荐选项 — workflow.ts:82-101 MainPlotOptionDTO

/// 主线推荐选项，对齐原版 workflow.ts:82-101 MainPlotOptionDTO
///
/// ```typescript
/// export interface MainPlotOptionDTO {
///   id: string
///   type: string
///   title: string
///   logline: string
///   core_conflict: string
///   starting_hook: string
///   main_axis?: string
///   opening_pressure?: string
///   forbidden_drift?: string
///   sublines?: Array<{...}>
/// }
/// ```
struct MainPlotOptionDTO: Codable, Equatable, Identifiable {
    /// 选项 ID — workflow.ts:83
    let id: String
    /// 选项类型 — workflow.ts:84
    let type: String
    /// 选项标题 — workflow.ts:85
    let title: String
    /// 一句话概述 — workflow.ts:86
    let logline: String
    /// 核心冲突 — workflow.ts:87
    let coreConflict: String
    /// 开场钩子 — workflow.ts:88
    let startingHook: String
    /// 主轴（可选）— workflow.ts:89
    let mainAxis: String?
    /// 开局压力（可选）— workflow.ts:90
    let openingPressure: String?
    /// 禁忌偏移（可选）— workflow.ts:91
    let forbiddenDrift: String?
    /// 副线列表（可选）— workflow.ts:92-100
    let sublines: [MainPlotSubline]?

    enum CodingKeys: String, CodingKey {
        case id, type, title, logline
        case coreConflict = "core_conflict"
        case startingHook = "starting_hook"
        case mainAxis = "main_axis"
        case openingPressure = "opening_pressure"
        case forbiddenDrift = "forbidden_drift"
        case sublines
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.logline = try c.decodeIfPresent(String.self, forKey: .logline) ?? ""
        self.coreConflict = try c.decodeIfPresent(String.self, forKey: .coreConflict) ?? ""
        self.startingHook = try c.decodeIfPresent(String.self, forKey: .startingHook) ?? ""
        self.mainAxis = try c.decodeIfPresent(String.self, forKey: .mainAxis)
        self.openingPressure = try c.decodeIfPresent(String.self, forKey: .openingPressure)
        self.forbiddenDrift = try c.decodeIfPresent(String.self, forKey: .forbiddenDrift)
        self.sublines = try c.decodeIfPresent([MainPlotSubline].self, forKey: .sublines)
    }

    /// 空值（用于占位）
    static let empty = MainPlotOptionDTO(
        id: "", type: "", title: "", logline: "",
        coreConflict: "", startingHook: "",
        mainAxis: nil, openingPressure: nil,
        forbiddenDrift: nil, sublines: nil
    )

    /// 从字典构造（SSE 事件解析用）
    static func fromDict(_ dict: [String: Any]) -> MainPlotOptionDTO {
        return MainPlotOptionDTO(
            id: dict["id"] as? String ?? "",
            type: dict["type"] as? String ?? "",
            title: dict["title"] as? String ?? "",
            logline: dict["logline"] as? String ?? "",
            coreConflict: dict["core_conflict"] as? String ?? "",
            startingHook: dict["starting_hook"] as? String ?? "",
            mainAxis: dict["main_axis"] as? String,
            openingPressure: dict["opening_pressure"] as? String,
            forbiddenDrift: dict["forbidden_drift"] as? String,
            sublines: (dict["sublines"] as? [[String: Any]])?.map { MainPlotSubline.fromDict($0) }
        )
    }

    /// 显式 memberwise init
    init(id: String, type: String, title: String, logline: String,
         coreConflict: String, startingHook: String,
         mainAxis: String?, openingPressure: String?,
         forbiddenDrift: String?, sublines: [MainPlotSubline]?) {
        self.id = id
        self.type = type
        self.title = title
        self.logline = logline
        self.coreConflict = coreConflict
        self.startingHook = startingHook
        self.mainAxis = mainAxis
        self.openingPressure = openingPressure
        self.forbiddenDrift = forbiddenDrift
        self.sublines = sublines
    }
}

/// 主线副线，对齐原版 workflow.ts:92-100 sublines 数组元素
struct MainPlotSubline: Codable, Equatable, Identifiable {
    /// 副线 ID（可选）— workflow.ts:93
    var id: String { _id ?? UUID().uuidString }
    let _id: String?
    /// 副线名称 — workflow.ts:94
    let name: String
    /// 角色（sub/dark）— workflow.ts:95
    let role: String?
    /// 目的 — workflow.ts:96
    let purpose: String?
    /// 描述 — workflow.ts:97
    let desc: String?
    /// 合并章节 — workflow.ts:98
    let mergeChapter: Int?
    /// 守卫 — workflow.ts:99
    let guard_: String?

    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case name, role, purpose
        case desc = "description"
        case mergeChapter = "merge_chapter"
        case guard_ = "guard"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self._id = try c.decodeIfPresent(String.self, forKey: ._id)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.role = try c.decodeIfPresent(String.self, forKey: .role)
        self.purpose = try c.decodeIfPresent(String.self, forKey: .purpose)
        self.desc = try c.decodeIfPresent(String.self, forKey: .desc)
        self.mergeChapter = try c.decodeIfPresent(Int.self, forKey: .mergeChapter)
        self.guard_ = try c.decodeIfPresent(String.self, forKey: .guard_)
    }

    /// 从字典构造
    static func fromDict(_ dict: [String: Any]) -> MainPlotSubline {
        return MainPlotSubline(
            _id: dict["id"] as? String,
            name: dict["name"] as? String ?? "",
            role: dict["role"] as? String,
            purpose: dict["purpose"] as? String,
            desc: dict["description"] as? String,
            mergeChapter: dict["merge_chapter"] as? Int,
            guard_: dict["guard"] as? String
        )
    }

    /// 显式 memberwise init
    init(_id: String?, name: String, role: String?, purpose: String?,
         desc: String?, mergeChapter: Int?, guard_: String?) {
        self._id = _id
        self.name = name
        self.role = role
        self.purpose = purpose
        self.desc = desc
        self.mergeChapter = mergeChapter
        self.guard_ = guard_
    }
}

// MARK: - 主线推荐响应 — workflow.ts:103-107 SuggestMainPlotOptionsResponse

/// 主线推荐响应，对齐原版 workflow.ts:103-107 SuggestMainPlotOptionsResponse
struct SuggestMainPlotOptionsResponse: Codable, Equatable {
    /// 推荐选项列表 — workflow.ts:104
    let plotOptions: [MainPlotOptionDTO]
    /// 调用会话 ID（可选）— workflow.ts:105
    let invocationSessionId: String?
    /// 调用下一步操作（可选）— workflow.ts:106
    let invocationNextAction: String?

    enum CodingKeys: String, CodingKey {
        case plotOptions = "plot_options"
        case invocationSessionId = "invocation_session_id"
        case invocationNextAction = "invocation_next_action"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.plotOptions = try c.decodeIfPresent([MainPlotOptionDTO].self, forKey: .plotOptions) ?? []
        self.invocationSessionId = try c.decodeIfPresent(String.self, forKey: .invocationSessionId)
        self.invocationNextAction = try c.decodeIfPresent(String.self, forKey: .invocationNextAction)
    }
}
