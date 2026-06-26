//
//  AutopilotStatus.swift
//  Cangjie
//
//  自动驾驶状态辅助纯函数，对齐原版 workbench/autopilotStatus.ts。
//

import Foundation

/// 自动驾驶显示状态，对齐原版 AutopilotDisplayStatus
enum AutopilotDisplayStatus: String, Equatable {
    case idle
    case running
    case paused
    case completed
    case error
}

/// 大纲规划后子步骤集合，对齐原版 AUTOPILOT_AFTER_OUTLINE_PLAN_SUBSTEPS（9 个子步骤）
let AUTOPILOT_AFTER_OUTLINE_PLAN_SUBSTEPS: Set<String> = [
    "chapter_plan_ready",
    "llm_calling",
    "persisting",
    "continuity_check",
    "chapter_persist",
    "audit_voice_check",
    "audit_aftermath",
    "audit_tension",
    "audit_anti_ai",
]

/// 判断子步骤是否属于大纲规划后阶段，对齐原版 isAutopilotAfterOutlinePlanSubstep
/// - Parameter substep: 子步骤名
/// - Returns: 是否在集合中
func isAutopilotAfterOutlinePlanSubstep(_ substep: Any?) -> Bool {
    return AUTOPILOT_AFTER_OUTLINE_PLAN_SUBSTEPS.contains(String(describing: substep ?? ""))
}

/// 将自动驾驶状态对象转换为 DAG 显示状态，对齐原版 toAutopilotDAGDisplayStatus
/// - Parameter status: 状态字典（AnyCodable 或 [String: Any]）
/// - Returns: 显示状态枚举
func toAutopilotDAGDisplayStatus(_ status: AnyCodable?) -> AutopilotDisplayStatus {
    guard let status = status else { return .idle }
    return toAutopilotDAGDisplayStatus(status.dictionaryValue)
}

/// 将自动驾驶状态字典转换为 DAG 显示状态（重载）
func toAutopilotDAGDisplayStatus(_ status: [String: Any]?) -> AutopilotDisplayStatus {
    guard let status = status, !status.isEmpty else { return .idle }

    let autopilotStatus = String(status["autopilot_status"] as? String ?? status["status"] as? String ?? "stopped")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    let currentStage = String(status["current_stage"] as? String ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    let humanGate = (status["needs_review"] as? Bool == true) || (status["requires_ai_review"] as? Bool == true)
        || currentStage == "paused_for_review"
        || currentStage == "reviewing"

    if autopilotStatus == "completed" { return .completed }
    if autopilotStatus == "error" { return .error }
    if autopilotStatus == "running" && humanGate { return .paused }
    if autopilotStatus == "running" { return .running }
    return .idle
}

/// 构建自动驾驶桌面快照指纹，对齐原版 buildAutopilotDeskSnapshot
/// 仅包含能改变章节列表/故事树形状的字段，排除高频写作遥测
/// - Parameter status: 状态字典
/// - Returns: 指纹字符串
func buildAutopilotDeskSnapshot(_ status: AnyCodable?) -> String {
    guard let status = status, let dict = status.dictionaryValue else { return "" }
    let audit = dict["last_chapter_audit"] as? [String: Any]
    let auditCh = audit != nil ? (audit!["chapter_number"] ?? audit!["chapterNumber"] ?? "") : ""
    var parts: [String] = []
    parts.append(String(describing: dict["completed_chapters"] ?? 0))
    parts.append(String(describing: dict["manuscript_chapters"] ?? 0))
    parts.append(String(describing: dict["current_stage"] ?? ""))
    parts.append(String(describing: dict["current_act"] ?? 0))
    parts.append(String(describing: dict["current_chapter_in_act"] ?? 0))
    parts.append(String(describing: dict["current_chapter_number"] ?? ""))
    parts.append((dict["needs_review"] as? Bool == true) ? "1" : "0")
    parts.append(String(describing: dict["autopilot_status"] ?? ""))
    parts.append(String(describing: auditCh))
    return parts.joined(separator: "|")
}

/// 构建自动驾驶响应式指纹，对齐原版 buildAutopilotReactiveFingerprint
/// 仅读取用户可见状态，避免心跳/上下文令牌抖动
/// - Parameter status: 状态字典
/// - Returns: 指纹字符串
func buildAutopilotReactiveFingerprint(_ status: [String: Any]) -> String {
    let audit = status["last_chapter_audit"] as? [String: Any]
    let auditMini: String
    if let audit = audit {
        let parts: [Any?] = [
            audit["chapter_number"] ?? audit["chapterNumber"] ?? "",
            audit["tension"] ?? "",
            (audit["narrative_sync_ok"] as? Bool == true) ? "1" : "0",
            audit["similarity_score"] ?? "",
            audit["at"] ?? "",
            (audit["drift_alert"] as? Bool == true) ? "1" : "0",
        ]
        auditMini = parts.map { "\($0 ?? "")" }.joined(separator: ":")
    } else {
        auditMini = ""
    }

    let plannedMicroBeatsCount: Int
    if let beats = status["planned_micro_beats"] as? [Any] {
        plannedMicroBeatsCount = beats.count
    } else {
        plannedMicroBeatsCount = 0
    }

    let parts: [Any?] = [
        status["autopilot_status"] ?? "",
        status["current_stage"] ?? "",
        status["current_chapter_number"] ?? "",
        status["completed_chapters"] ?? 0,
        status["manuscript_chapters"] ?? 0,
        status["current_beat_index"] ?? 0,
        status["total_beats"] ?? 0,
        plannedMicroBeatsCount,
        status["outline_plan_mode"] ?? "",
        status["writing_substep"] ?? "",
        status["writing_substep_label"] ?? "",
        status["accumulated_words"] ?? 0,
        status["beat_phase"] ?? "",
        status["beat_focus"] ?? "",
        status["beat_target_words"] ?? 0,
        status["chapter_target_words"] ?? 0,
        status["beat_remaining_budget"] ?? 0,
        status["beat_max_words_hint"] ?? 0,
        auditMini,
    ]
    return parts.map { "\($0 ?? "")" }.joined(separator: "|")
}

/// 辅助自动驾驶轮询延迟（指数退避），对齐原版 assistedAutopilotPollDelayMs
/// - Parameters:
///   - failureCount: 失败次数
///   - baseMs: 基础延迟（默认 4000ms）
///   - maxMs: 最大延迟（默认 60000ms）
/// - Returns: 延迟毫秒数
func assistedAutopilotPollDelayMs(
    failureCount: Int,
    baseMs: Int = 4000,
    maxMs: Int = 60000
) -> Int {
    let mult = min(1 << min(failureCount, 8), 128)
    return min(baseMs * mult, maxMs)
}

// MARK: - E-1 toChapterMicroBeatPayloads

/// 将 StreamGeneratedBeat 数组转换为 ChapterMicroBeatPayload 数组，
/// 对齐原版 workbench/autopilotStatus.ts:100-110 toChapterMicroBeatPayloads。
///
/// 7 字段映射：description / targetWords / focus / locationId / activeAction / emotionGap / forbiddenDrift
/// - Parameter beats: 流式生成的节拍数组
/// - Returns: 章节微观节拍载荷数组
func toChapterMicroBeatPayloads(_ beats: [StreamGeneratedBeat]) -> [ChapterMicroBeatPayload] {
    return beats.map { beat in
        ChapterMicroBeatPayload(
            description: beat.description,
            targetWords: beat.targetWords,
            focus: beat.focus,
            locationId: beat.locationId,
            activeAction: beat.activeAction,
            emotionGap: beat.emotionGap,
            forbiddenDrift: beat.forbiddenDrift
        )
    }
}
