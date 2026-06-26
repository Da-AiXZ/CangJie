//
//  GenerationPrefsModels.swift
//  Cangjie
//
//  生成偏好 DTO，字段对齐原版 api/novel.ts:32-50 GenerationPrefsDTO。
//  C-1：将 NovelDTO.generationPrefs 从 AnyCodable 结构化为 10 字段 Codable。
//  所有字段可选（对齐 TS interface 的 ? 修饰），使用 decodeIfPresent 容错。
//

import Foundation

// MARK: - 生成偏好 DTO

/// 生成偏好 DTO，对齐原版 api/novel.ts:32-50 GenerationPrefsDTO。
///
/// 与后端 novels.generation_prefs_json 一致（按需扩展）。
/// 10 个字段全部可选，CodingKey 使用 snake_case。
struct GenerationPrefsDTO: Codable, Equatable {

    /// 阶段展示模式 — novel.ts:33 phase_display_mode
    let phaseDisplayMode: Bool?

    /// 兼容旧配置字段；当前版本不再驱动正文截断 — novel.ts:35 smart_truncate_enabled
    let smartTruncateEnabled: Bool?

    /// 兼容旧配置字段；当前版本不再启用节拍硬帽 — novel.ts:37 beat_hard_cap_enabled
    let beatHardCapEnabled: Bool?

    /// 落盘前段内碎片换行连片；默认关闭 — novel.ts:39 inline_prose_aggregation_enabled
    let inlineProseAggregationEnabled: Bool?

    /// 指挥器收敛阈值 — novel.ts:40 conductor_converge_threshold
    let conductorConvergeThreshold: Double?

    /// 指挥器着陆阈值 — novel.ts:41 conductor_land_threshold
    let conductorLandThreshold: Double?

    /// 每章审计结束后进入「待审阅」，需点恢复才写下一章；全自动书目仍跳过 — novel.ts:43 pause_after_each_chapter_audit
    let pauseAfterEachChapterAudit: Bool?

    /// 叙事失败或文风仍不及格 → 待在审阅（与 pause 开关合用）— novel.ts:45 audit_pause_on_hard_fail
    let auditPauseOnHardFail: Bool?

    /// Anti-AI 综合判定「严重」→ 待在审阅 — novel.ts:47 audit_pause_on_anti_ai_severe
    let auditPauseOnAntiAiSevere: Bool?

    /// 当前章节目标字数；兼容后端 generation_prefs_json 旧字段 — novel.ts:49 target_chapter_words
    let targetChapterWords: Int?

    enum CodingKeys: String, CodingKey {
        case phaseDisplayMode = "phase_display_mode"
        case smartTruncateEnabled = "smart_truncate_enabled"
        case beatHardCapEnabled = "beat_hard_cap_enabled"
        case inlineProseAggregationEnabled = "inline_prose_aggregation_enabled"
        case conductorConvergeThreshold = "conductor_converge_threshold"
        case conductorLandThreshold = "conductor_land_threshold"
        case pauseAfterEachChapterAudit = "pause_after_each_chapter_audit"
        case auditPauseOnHardFail = "audit_pause_on_hard_fail"
        case auditPauseOnAntiAiSevere = "audit_pause_on_anti_ai_severe"
        case targetChapterWords = "target_chapter_words"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.phaseDisplayMode = try c.decodeIfPresent(Bool.self, forKey: .phaseDisplayMode)
        self.smartTruncateEnabled = try c.decodeIfPresent(Bool.self, forKey: .smartTruncateEnabled)
        self.beatHardCapEnabled = try c.decodeIfPresent(Bool.self, forKey: .beatHardCapEnabled)
        self.inlineProseAggregationEnabled = try c.decodeIfPresent(Bool.self, forKey: .inlineProseAggregationEnabled)
        self.conductorConvergeThreshold = try c.decodeIfPresent(Double.self, forKey: .conductorConvergeThreshold)
        self.conductorLandThreshold = try c.decodeIfPresent(Double.self, forKey: .conductorLandThreshold)
        self.pauseAfterEachChapterAudit = try c.decodeIfPresent(Bool.self, forKey: .pauseAfterEachChapterAudit)
        self.auditPauseOnHardFail = try c.decodeIfPresent(Bool.self, forKey: .auditPauseOnHardFail)
        self.auditPauseOnAntiAiSevere = try c.decodeIfPresent(Bool.self, forKey: .auditPauseOnAntiAiSevere)
        self.targetChapterWords = try c.decodeIfPresent(Int.self, forKey: .targetChapterWords)
    }

    init(
        phaseDisplayMode: Bool? = nil,
        smartTruncateEnabled: Bool? = nil,
        beatHardCapEnabled: Bool? = nil,
        inlineProseAggregationEnabled: Bool? = nil,
        conductorConvergeThreshold: Double? = nil,
        conductorLandThreshold: Double? = nil,
        pauseAfterEachChapterAudit: Bool? = nil,
        auditPauseOnHardFail: Bool? = nil,
        auditPauseOnAntiAiSevere: Bool? = nil,
        targetChapterWords: Int? = nil
    ) {
        self.phaseDisplayMode = phaseDisplayMode
        self.smartTruncateEnabled = smartTruncateEnabled
        self.beatHardCapEnabled = beatHardCapEnabled
        self.inlineProseAggregationEnabled = inlineProseAggregationEnabled
        self.conductorConvergeThreshold = conductorConvergeThreshold
        self.conductorLandThreshold = conductorLandThreshold
        self.pauseAfterEachChapterAudit = pauseAfterEachChapterAudit
        self.auditPauseOnHardFail = auditPauseOnHardFail
        self.auditPauseOnAntiAiSevere = auditPauseOnAntiAiSevere
        self.targetChapterWords = targetChapterWords
    }

    /// 空值（默认实例），用于无 generation_prefs 时的回退
    static let empty = GenerationPrefsDTO()
}
