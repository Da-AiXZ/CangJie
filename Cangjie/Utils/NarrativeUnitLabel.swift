//
//  NarrativeUnitLabel.swift
//  Cangjie
//
//  叙事单元标签辅助函数，对齐原版 utils/narrativeUnitLabel.ts。
//  B-2 前置：narrativeOrdinalLabel / narrativeUnitNoun / isPhaseDisplayMode / narrativeTreeChapterLine。
//

import Foundation

// MARK: - 叙事单元标签辅助函数

/// 判断是否为阶段展示模式，对齐原版 narrativeUnitLabel.ts:4-8 isPhaseDisplayMode。
///
/// 与后端缺省一致：未带字段时视为阶段模式。
/// - Parameter prefs: 生成偏好（可选）
/// - Returns: 是否为阶段展示模式
func isPhaseDisplayMode(_ prefs: GenerationPrefsDTO?) -> Bool {
    guard let prefs = prefs else { return true }
    // 如果 phaseDisplayMode 字段不存在（nil），视为默认阶段模式
    return prefs.phaseDisplayMode ?? true
}

/// 叙事单元名词，对齐原版 narrativeUnitLabel.ts:10-12 narrativeUnitNoun。
///
/// 阶段模式返回"阶段"，章模式返回"章"。
/// - Parameter prefs: 生成偏好（可选）
/// - Returns: "阶段" 或 "章"
func narrativeUnitNoun(_ prefs: GenerationPrefsDTO?) -> String {
    return isPhaseDisplayMode(prefs) ? "阶段" : "章"
}

/// 序数标签，对齐原版 narrativeUnitLabel.ts:17-25 narrativeOrdinalLabel。
///
/// 阶段模式为"第 N 阶段"（阿拉伯数字）；章模式为"第 N 章"。
/// - Parameters:
///   - n: 序号
///   - prefs: 生成偏好（可选）
/// - Returns: 序数标签字符串
func narrativeOrdinalLabel(_ n: Int, _ prefs: GenerationPrefsDTO?) -> String {
    if n < 1 || !n.isFinite {
        return isPhaseDisplayMode(prefs) ? "第\(n)阶段" : "第\(n)章"
    }
    if isPhaseDisplayMode(prefs) {
        return "第\(n)阶段"
    }
    return "第\(n)章"
}

/// 结构树章节行，对齐原版 narrativeUnitLabel.ts:29-37 narrativeTreeChapterLine。
///
/// 节点 number 为全书章号，固定用"第 N 章"（强制 phase_display_mode=false），
/// 避免与"阶段模式"下的叙事单元文案及节拍/故事阶段混淆。
/// - Parameters:
///   - n: 章号
///   - title: 章节标题
///   - prefs: 生成偏好（未使用，对齐原版 _prefs 参数）
/// - Returns: "第 N 章 标题" 或 "第 N 章"
func narrativeTreeChapterLine(_ n: Int, _ title: String, _ prefs: GenerationPrefsDTO? = nil) -> String {
    // 强制使用章模式（phase_display_mode=false）
    let head = narrativeOrdinalLabel(n, GenerationPrefsDTO(phaseDisplayMode: false))
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedTitle.isEmpty ? head : "\(head) \(trimmedTitle)"
}
