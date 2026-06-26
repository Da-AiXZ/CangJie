//
//  TensionModels.swift
//  Cangjie
//
//  P0-5 张力诊断模型，字段对齐原版 api/tools.ts:9-20。
//  TensionSlingshotPayload — POST /novels/{novelId}/writer-block/tension-slingshot 请求体
//  TensionDiagnosis — 同端点响应体
//

import Foundation

// MARK: - 张力弹弓请求载荷 — tools.ts:9-13

/// 张力弹弓请求载荷，对齐原版 tools.ts:9-13 TensionSlingshotPayload
///
/// ```typescript
/// export interface TensionSlingshotPayload {
///   novel_id: string
///   chapter_number: number
///   stuck_reason?: string
/// }
/// ```
struct TensionSlingshotPayload: Codable, Equatable {
    /// 小说 ID — tools.ts:10
    let novelId: String
    /// 章节编号 — tools.ts:11
    let chapterNumber: Int
    /// 卡壳原因（可选）— tools.ts:12
    let stuckReason: String?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case chapterNumber = "chapter_number"
        case stuckReason = "stuck_reason"
    }

    /// 显式 memberwise init（自定义 CodingKeys 后编译器不再自动合成）
    init(novelId: String, chapterNumber: Int, stuckReason: String? = nil) {
        self.novelId = novelId
        self.chapterNumber = chapterNumber
        self.stuckReason = stuckReason
    }
}

// MARK: - 张力诊断结果 — tools.ts:15-20

/// 张力诊断结果，对齐原版 tools.ts:15-20 TensionDiagnosis
///
/// ```typescript
/// export interface TensionDiagnosis {
///   diagnosis: string
///   tension_level: 'low' | 'medium' | 'high'
///   missing_elements: string[]
///   suggestions: string[]
/// }
/// ```
struct TensionDiagnosis: Codable, Equatable {
    /// 诊断文本 — tools.ts:16
    let diagnosis: String
    /// 张力等级（low/medium/high）— tools.ts:17
    let tensionLevel: String
    /// 缺失元素列表 — tools.ts:18
    let missingElements: [String]
    /// 突破建议列表 — tools.ts:19
    let suggestions: [String]

    enum CodingKeys: String, CodingKey {
        case diagnosis
        case tensionLevel = "tension_level"
        case missingElements = "missing_elements"
        case suggestions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.diagnosis = try c.decodeIfPresent(String.self, forKey: .diagnosis) ?? ""
        self.tensionLevel = try c.decodeIfPresent(String.self, forKey: .tensionLevel) ?? "medium"
        self.missingElements = try c.decodeIfPresent([String].self, forKey: .missingElements) ?? []
        self.suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
    }

    /// 显式 memberwise init
    init(diagnosis: String, tensionLevel: String, missingElements: [String], suggestions: [String]) {
        self.diagnosis = diagnosis
        self.tensionLevel = tensionLevel
        self.missingElements = missingElements
        self.suggestions = suggestions
    }

    /// 张力等级中文显示
    var tensionLevelDisplay: String {
        switch tensionLevel {
        case "high":
            return "高张力"
        case "medium":
            return "中等"
        case "low":
            return "低张力"
        default:
            return tensionLevel
        }
    }
}
