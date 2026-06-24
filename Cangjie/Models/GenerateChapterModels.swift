//
//  GenerateChapterModels.swift
//  Cangjie
//
//  单章生成 SSE 事件模型，字段对齐后端 workflow.ts:159-300
//  以及 POST /api/v1/novels/{novelId}/generate-chapter-stream 的 SSE 事件契约。
//

import Foundation

// MARK: - 单章生成请求载荷（workflow.ts:159-174）

/// 单章生成请求载荷，对应 GenerateChapterWithContextPayload（workflow.ts:159-174）
struct GenerateChapterWithContextPayload: Codable {
    /// 章节号（必填）
    let chapterNumber: Int
    /// 大纲（必填）
    let outline: String
    /// 场记分析结果（可选）
    let sceneDirectorResult: AnyCodable?
    /// 调用策略（可选）：DIRECT / REVIEW_BEFORE_CALL / REVIEW_AFTER_CALL / FULL_INTERACTIVE / INTERACTIVE_WHEN_AVAILABLE / AUTOPILOT_PAUSE
    let invocationPolicy: String?
    /// 重新生成时的改进方向（可选）
    let regenerationGuidance: String?
    /// 覆盖 LLM 控制台档案 ID（可选）
    let profileId: String?
    /// 自定义剧本生成提示词模板（可选，支持 {{variable}} 占位符）
    let scriptPromptTemplate: String?
    /// 自定义正文生成提示词模板（可选，支持 {{variable}} 占位符）
    let prosePromptTemplate: String?
    /// 提示词变量键值对（可选）
    let promptVariables: [String: String]?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case outline
        case sceneDirectorResult = "scene_director_result"
        case invocationPolicy = "invocation_policy"
        case regenerationGuidance = "regeneration_guidance"
        case profileId = "profile_id"
        case scriptPromptTemplate = "script_prompt_template"
        case prosePromptTemplate = "prose_prompt_template"
        case promptVariables = "prompt_variables"
    }

    /// 阶段1只传必填字段 chapterNumber + outline（system_design.md 6.2 Q决策）
    init(chapterNumber: Int, outline: String) {
        self.chapterNumber = chapterNumber
        self.outline = outline
        self.sceneDirectorResult = nil
        self.invocationPolicy = nil
        self.regenerationGuidance = nil
        self.profileId = nil
        self.scriptPromptTemplate = nil
        self.prosePromptTemplate = nil
        self.promptVariables = nil
    }
}

// MARK: - 流式统计（workflow.ts:273-277）

/// 流式统计，对应 ChunkStats（workflow.ts:273-277）
struct ChunkStats: Codable, Equatable {
    let chars: Int
    let chunks: Int
    let estimatedTokens: Int

    init(chars: Int = 0, chunks: Int = 0, estimatedTokens: Int = 0) {
        self.chars = chars
        self.chunks = chunks
        self.estimatedTokens = estimatedTokens
    }
}

// MARK: - 流式生成节拍（workflow.ts:280-300）

/// 流式生成节拍，对应 StreamGeneratedBeat（workflow.ts:280-300）
struct StreamGeneratedBeat: Codable, Equatable, Identifiable {
    /// 唯一 ID（本地生成，用于 SwiftUI ForEach；基于内容哈希保证 Equatable 一致性）
    var id: String {
        return "\(description)_\(targetWords)_\(focus)"
    }
    let description: String
    let targetWords: Int
    let focus: String
    let locationId: String?
    let function: String?
    let pov: String?
    let castRefs: [String]?
    let locationRefs: [String]?
    let propRefs: [String]?
    let knowledgeRefs: [String]?
    let visibleAction: String?
    let conflict: String?
    let delta: String?
    let handoffToNext: String?
    let mustInclude: [String]?
    let mustNotInclude: [String]?
    let activeAction: String?
    let emotionGap: String?
    let forbiddenDrift: String?

    enum CodingKeys: String, CodingKey {
        case description
        case targetWords = "target_words"
        case focus
        case locationId = "location_id"
        case function
        case pov
        case castRefs = "cast_refs"
        case locationRefs = "location_refs"
        case propRefs = "prop_refs"
        case knowledgeRefs = "knowledge_refs"
        case visibleAction = "visible_action"
        case conflict
        case delta
        case handoffToNext = "handoff_to_next"
        case mustInclude = "must_include"
        case mustNotInclude = "must_not_include"
        case activeAction = "active_action"
        case emotionGap = "emotion_gap"
        case forbiddenDrift = "forbidden_drift"
    }
}

// MARK: - 一致性报告（workflow.ts:242-253）

/// 一致性问题，对应 ConsistencyIssueDTO（workflow.ts:242-247）
struct ConsistencyIssueDTO: Codable, Equatable, Identifiable {
    var id: String { "\(type)_\(location)_\(description.hashValue)" }
    let type: String
    let severity: String
    let description: String
    let location: Int
}

/// 一致性报告，对应 ConsistencyReportDTO（workflow.ts:249-253）
struct ConsistencyReportDTO: Codable, Equatable {
    let issues: [ConsistencyIssueDTO]
    let warnings: [ConsistencyIssueDTO]
    let suggestions: [String]

    init(issues: [ConsistencyIssueDTO] = [], warnings: [ConsistencyIssueDTO] = [], suggestions: [String] = []) {
        self.issues = issues
        self.warnings = warnings
        self.suggestions = suggestions
    }
}

// MARK: - 文风警告（workflow.ts:255-261）

/// 文风警告，对应 StyleWarning（workflow.ts:255-261）
struct StyleWarning: Codable, Equatable, Identifiable {
    var id: String { "\(pattern)_\(start)" }
    let pattern: String
    let text: String
    let start: Int
    let end: Int
    let severity: String  // 'info' | 'warning'
}

// MARK: - 单章生成响应（workflow.ts:263-271）

/// 单章生成响应，对应 GenerateChapterWorkflowResponse（workflow.ts:263-271）
struct GenerateChapterWorkflowResponse: Codable, Equatable {
    let content: String
    let consistencyReport: ConsistencyReportDTO
    let tokenCount: Int
    let styleWarnings: [StyleWarning]?
    let ghostAnnotations: [AnyCodable]?
    let beats: [StreamGeneratedBeat]?

    enum CodingKeys: String, CodingKey {
        case content
        case consistencyReport = "consistency_report"
        case tokenCount = "token_count"
        case styleWarnings = "style_warnings"
        case ghostAnnotations = "ghost_annotations"
        case beats
    }
}

// MARK: - 节拍解析函数（workflow.ts:302-351）

/// 解析 SSE beats 行（beats_generated / done.beats 共用）（workflow.ts:302-351）
/// description 取 description/text/intent/scene_goal 任一非空值；
/// target_words 支持数字或数字字符串；focus 默认 "pacing"；
/// 其余可选字段按类型安全提取。
func parseStreamGeneratedBeats(_ raw: [Any]?) -> [StreamGeneratedBeat] {
    guard let raw = raw else { return [] }
    var beats: [StreamGeneratedBeat] = []

    for row in raw {
        guard let r = row as? [String: Any] else { continue }

        // description：取 description / text / intent / scene_goal 任一非空值（workflow.ts:317-319）
        let description = stringFromDict(r, "description")
            ?? stringFromDict(r, "text")
            ?? stringFromDict(r, "intent")
            ?? stringFromDict(r, "scene_goal")
            ?? ""
        if description.isEmpty { continue }  // workflow.ts:320

        // target_words：支持数字或数字字符串（workflow.ts:321-327）
        let targetWords: Int
        if let tw = r["target_words"] as? Int {
            targetWords = tw
        } else if let twStr = r["target_words"] as? String, let twInt = Int(twStr) {
            targetWords = twInt
        } else {
            targetWords = 0
        }

        // focus：默认 "pacing"（workflow.ts:331）
        let focusRaw = stringFromDict(r, "focus") ?? stringFromDict(r, "type") ?? ""
        let focus = focusRaw.isEmpty ? "pacing" : focusRaw

        beats.append(StreamGeneratedBeat(
            description: description,
            targetWords: targetWords,
            focus: focus,
            locationId: stringFromDict(r, "location_id"),
            function: stringFromDict(r, "function"),
            pov: stringFromDict(r, "pov"),
            castRefs: stringListFromDict(r, "cast_refs"),
            locationRefs: stringListFromDict(r, "location_refs"),
            propRefs: stringListFromDict(r, "prop_refs"),
            knowledgeRefs: stringListFromDict(r, "knowledge_refs"),
            visibleAction: stringFromDict(r, "visible_action"),
            conflict: stringFromDict(r, "conflict"),
            delta: stringFromDict(r, "delta"),
            handoffToNext: stringFromDict(r, "handoff_to_next"),
            mustInclude: stringListFromDict(r, "must_include"),
            mustNotInclude: stringListFromDict(r, "must_not_include"),
            activeAction: stringFromDict(r, "active_action"),
            emotionGap: stringFromDict(r, "emotion_gap"),
            forbiddenDrift: stringFromDict(r, "forbidden_drift")
        ))
    }

    return beats
}

// MARK: - 字典取值辅助函数

/// 从字典安全取字符串（workflow.ts:302-351 内联逻辑）
func stringFromDict(_ dict: [String: Any], _ key: String) -> String? {
    let val = dict[key]
    if let str = val as? String {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    return nil
}

/// 从字典安全取字符串数组（workflow.ts:306-313 asStringList 逻辑）
/// 数组 → map String; 字符串 → [字符串]; 空 → nil
func stringListFromDict(_ dict: [String: Any], _ key: String) -> [String]? {
    let val = dict[key]
    if let arr = val as? [Any] {
        let out = arr.compactMap { item -> String? in
            if let s = item as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }
        return out.isEmpty ? nil : out
    }
    if let str = val as? String {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : [trimmed]
    }
    return nil
}
