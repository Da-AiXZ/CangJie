//
//  GenerationStreamPresentation.swift
//  Cangjie
//
//  生成流展示辅助纯函数，对齐原版 workbench/generationStreamPresentation.ts。
//

import Foundation

/// 生成流日志行，对齐原版 GenerateStreamLogLine
struct GenerateStreamLogLineDTO: Identifiable, Equatable {
    let id = UUID()
    let tag: String
    let msg: String
}

/// 生成流日志最大行数，对齐原版 GENERATE_STREAM_LOG_LIMIT
let GENERATE_STREAM_LOG_LIMIT = 7

/// 流式阶段 → 进度百分比映射，对齐原版 STREAM_PHASE_PROGRESS（8 阶段）
private let STREAM_PHASE_PROGRESS: [String: Int] = [
    "planning": 14,
    "context": 28,
    "script": 52,
    "prose": 78,
    "outline_planning": 48,
    "chapter_plan_ready": 50,
    "llm": 72,
    "post": 92,
]

/// 流式阶段 → 中文标签映射，对齐原版 STREAM_PHASE_LABELS
private let STREAM_PHASE_LABELS: [String: String] = [
    "planning": "宏观 planning…",
    "context": "组装上下文…",
    "script": "生成六模块剧本…",
    "outline_planning": "章节执行剧本准备…",
    "chapter_plan_ready": "章节执行剧本已就绪…",
    "prose": "正文撰写…",
    "llm": "撰写正文…",
    "post": "质检与收尾…",
]

/// 流式阶段 → 日志标签映射，对齐原版 STREAM_PHASE_LOG_LABELS
private let STREAM_PHASE_LOG_LABELS: [String: String] = [
    "planning": "宏观 planning",
    "context": "上下文 context",
    "script": "剧本生成 script",
    "outline_planning": "执行剧本准备",
    "chapter_plan_ready": "执行剧本已就绪",
    "prose": "正文撰写 prose",
    "llm": "正文撰写 llm（兼容）",
    "post": "质检 post",
]

/// 流式日志标签 → 颜色类型映射，对齐原版 STREAM_LOG_TAG_TYPES
private let STREAM_LOG_TAG_TYPES: [String: String] = [
    "SSE": "info",
    "规划": "warning",
    "节拍": "success",
    "正文": "primary",
]

/// phase → 进度百分比，对齐原版 streamPhaseToProgress
/// 未知 phase 返回 12（对齐原版默认值）
func streamPhaseToProgress(_ phase: String) -> Int {
    return STREAM_PHASE_PROGRESS[phase] ?? 12
}

/// phase → 中文标签，对齐原版 streamPhaseToLabel
/// 未知 phase 返回原值
func streamPhaseToLabel(_ phase: String) -> String {
    return STREAM_PHASE_LABELS[phase] ?? phase
}

/// phase → 日志标签，对齐原版 streamPhaseToLogLabel
/// 未知 phase 返回原值
func streamPhaseToLogLabel(_ phase: String) -> String {
    return STREAM_PHASE_LOG_LABELS[phase] ?? phase
}

/// 日志标签 → 颜色类型，对齐原版 generateStreamTagType
/// 未知标签返回 "default"
func generateStreamTagType(_ tag: String) -> String {
    return STREAM_LOG_TAG_TYPES[tag] ?? "default"
}

/// 规划骨架屏宽度百分比，对齐原版 planningSkeletonWidthPct
/// - Parameter rowIndex: 行索引（0-based）
/// - Returns: 宽度百分比字符串（如 "36%", "46%", ...）
func planningSkeletonWidthPct(_ rowIndex: Int) -> String {
    return "\(Swift.min(94, 36 + rowIndex * 10))%"
}

/// 追加生成流日志行，对齐原版 appendGenerateStreamLog
/// - Parameters:
///   - lines: 现有日志行
///   - line: 新行
///   - limit: 最大行数（默认 GENERATE_STREAM_LOG_LIMIT）
/// - Returns: 截断后的日志行数组
func appendGenerateStreamLog(
    _ lines: [GenerateStreamLogLineDTO],
    line: GenerateStreamLogLineDTO,
    limit: Int = GENERATE_STREAM_LOG_LIMIT
) -> [GenerateStreamLogLineDTO] {
    return (lines + [line]).suffix(limit)
}
