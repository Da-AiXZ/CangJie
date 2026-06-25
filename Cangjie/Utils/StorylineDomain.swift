//
//  StorylineDomain.swift
//  Cangjie
//
//  故事线/角色 domain 辅助函数集中管理。
//  对齐原版 domain/storyline.ts:100-256 + domain/character.ts:1-101。
//  新组件 NarrativeDashboardPanel 等优先使用此文件中的权威版本。
//

import SwiftUI
import Foundation

// MARK: - 故事阶段常量 — storyline.ts:100-133

/// 故事阶段选项 — storyline.ts:100-105 STORY_PHASE_STAGES
struct StoryPhaseStep: Identifiable, Equatable {
    let value: String
    let label: String
    var id: String { value }
}

/// 故事阶段步骤列表 — storyline.ts:100-105
let STORY_PHASE_STAGES: [StoryPhaseStep] = [
    StoryPhaseStep(value: "opening", label: "开局"),
    StoryPhaseStep(value: "development", label: "发展"),
    StoryPhaseStep(value: "convergence", label: "收敛"),
    StoryPhaseStep(value: "finale", label: "终局"),
]

/// 故事阶段顺序 — storyline.ts:107
private let STORY_PHASE_ORDER: [String] = STORY_PHASE_STAGES.map { $0.value }

/// 故事阶段标签 — storyline.ts:109-119
private let STORY_PHASE_LABELS: [String: String] = [
    "opening": "开局期",
    "development": "发展期",
    "convergence": "收敛期",
    "finale": "终局期",
    "setup": "设定阶段",
    "rising_action": "冲突升级",
    "crisis": "危机阶段",
    "climax": "高潮阶段",
    "resolution": "收束阶段",
]

/// 故事阶段提示 — storyline.ts:121-126
private let STORY_PHASE_HINTS: [String: String] = [
    "opening": "铺陈悬念，埋设伏笔，建立世界观",
    "development": "激化矛盾，引入支线，角色成长",
    "convergence": "禁止开新坑，强制填坑，收敛线索",
    "finale": "终极对决，切断日常，揭晓谜底",
]

/// 旧阶段映射 — storyline.ts:135-141
private let LEGACY_PHASE_MAP: [String: String] = [
    "setup": "opening",
    "rising_action": "development",
    "crisis": "development",
    "climax": "convergence",
    "resolution": "finale",
]

// MARK: - 故事阶段函数 — storyline.ts:215-247

/// 标准化故事阶段 — storyline.ts:215-218
func normalizeStoryPhase(_ phase: String?) -> String {
    let key = (phase ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return LEGACY_PHASE_MAP[key] ?? key
}

/// 获取故事阶段标签 — storyline.ts:220-223
func getStoryPhaseLabel(_ phase: String?) -> String {
    let key = (phase ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return STORY_PHASE_LABELS[key] ?? key
}

/// 获取故事阶段提示 — storyline.ts:225-228
func getStoryPhaseHint(_ phase: String?) -> String {
    let normalized = normalizeStoryPhase(phase)
    return STORY_PHASE_HINTS[normalized] ?? ""
}

/// 获取故事阶段颜色 — storyline.ts:230-233
func getStoryPhaseColor(_ phase: String?) -> Color {
    let normalized = normalizeStoryPhase(phase)
    switch normalized {
    case "opening": return Theme.info
    case "development": return Theme.primary
    case "convergence": return Theme.warning
    case "finale": return Color(red: 0.831, green: 0.659, blue: 0.325) // gold
    default: return Theme.primary
    }
}

/// 判断阶段是否已过 — storyline.ts:244-247
func isStoryPhasePast(_ stage: String, current: String?) -> Bool {
    let normalizedCurrent = normalizeStoryPhase(current)
    guard let stageIdx = STORY_PHASE_ORDER.firstIndex(of: stage),
          let currentIdx = STORY_PHASE_ORDER.firstIndex(of: normalizedCurrent) else {
        return false
    }
    return stageIdx < currentIdx
}

// MARK: - 汇流标签 — storyline.ts:249-256

/// 汇流类型标签 — storyline.ts:249-256
func getConfluenceLabel(_ type: String?) -> String {
    switch type ?? "" {
    case "intersect": return "交叉"
    case "absorb": return "并入"
    case "reveal": return "显影"
    default: return type ?? ""
    }
}

// MARK: - 故事线角色 — storyline.ts:185-203

/// 标准化故事线角色 — storyline.ts:151-157
private func normalizeStorylineRole(_ role: String?) -> String {
    let normalized = (role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "main_plot": return "main"
    case "sub_plot": return "sub"
    case "dark_line": return "dark"
    default: return normalized
    }
}

/// 故事线角色标签（紧凑版）— storyline.ts:190-193
func getStorylineRoleCompactLabel(_ role: String?) -> String {
    let normalized = normalizeStorylineRole(role)
    switch normalized {
    case "main": return "主线"
    case "sub": return "支线"
    case "dark": return "暗线"
    default: return role ?? ""
    }
}

/// 故事线角色 CSS key — storyline.ts:200-203
func getStorylineRoleCssKey(_ role: String?) -> String {
    let normalized = normalizeStorylineRole(role)
    switch normalized {
    case "main": return "main"
    case "sub": return "sub"
    case "dark": return "dark"
    default: return "default"
    }
}

/// 故事线角色 Tag 颜色 — storyline.ts:195-198 (映射到SwiftUI Color)
func getStorylineRoleColor(_ role: String?) -> Color {
    let normalized = normalizeStorylineRole(role)
    switch normalized {
    case "main": return Theme.success
    case "sub": return Theme.warning
    case "dark": return Color.purple
    default: return Theme.warning
    }
}

/// 判断是否主线 — storyline.ts:163-166
func isMainStoryline(_ sl: StorylineDTO) -> Bool {
    return normalizeStorylineRole(sl.role) == "main"
        || (sl.storylineType?.lowercased() == "main_plot")
}

// MARK: - 角色角色 — character.ts:1-101

/// 标准化角色角色 — character.ts:75-79
private func normalizeCharacterRole(_ role: String?) -> String {
    let raw = (role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch raw {
    case "protagonist", "main", "lead", "hero":
        return "PROTAGONIST"
    case "supporting", "support", "secondary":
        return "SUPPORTING"
    case "minor", "cameo", "extra":
        return "MINOR"
    default:
        return "MINOR"
    }
}

/// 角色角色排序 — character.ts:95-97
func getCharacterRoleSortOrder(_ role: String?) -> Int {
    switch normalizeCharacterRole(role) {
    case "PROTAGONIST": return 0
    case "SUPPORTING": return 1
    case "MINOR": return 2
    default: return 2
    }
}

/// 角色角色图标（Emoji/单字）— character.ts:99-101
func getCharacterRoleIcon(_ role: String?) -> String {
    switch normalizeCharacterRole(role) {
    case "PROTAGONIST": return "主"
    case "SUPPORTING": return "配"
    case "MINOR": return "群"
    default: return "群"
    }
}

/// 角色角色标签 — character.ts:81-83
func getCharacterRoleLabel(_ role: String?) -> String {
    switch normalizeCharacterRole(role) {
    case "PROTAGONIST": return "主角"
    case "SUPPORTING": return "配角"
    case "MINOR": return "龙套"
    default: return "龙套"
    }
}

/// 角色角色颜色 — character.ts:89-93
func getCharacterRoleColor(_ role: String?) -> Color {
    switch normalizeCharacterRole(role) {
    case "PROTAGONIST": return Theme.primary
    case "SUPPORTING": return Theme.warning
    case "MINOR": return Theme.textTertiary
    default: return Theme.textTertiary
    }
}
