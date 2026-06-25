//
//  AntiAIModels.swift
//  Cangjie
//
//  Anti-AI 防御模型，字段对齐后端 interfaces/api/v1/anti_ai.py 的请求/响应模型。
//

import Foundation
import SwiftUI

// MARK: - 扫描请求

/// 扫描请求，对应后端 ScanRequest
struct AntiAIScanRequest: Codable {
    let content: String
    let chapterId: String?

    enum CodingKeys: String, CodingKey {
        case content
        case chapterId = "chapter_id"
    }
}

// MARK: - 扫描响应

/// 扫描响应，对应后端 ScanResponse
struct AntiAIScanResult: Codable, Equatable {
    let totalHits: Int
    let criticalHits: Int
    let warningHits: Int
    let severityScore: Double
    let overallAssessment: String
    let categoryDistribution: [String: Int]
    let topPatterns: [String]
    let recommendations: [String]
    let improvementSuggestions: [String]
    let hits: [AntiAIHit]

    enum CodingKeys: String, CodingKey {
        case totalHits = "total_hits"
        case criticalHits = "critical_hits"
        case warningHits = "warning_hits"
        case severityScore = "severity_score"
        case overallAssessment = "overall_assessment"
        case categoryDistribution = "category_distribution"
        case topPatterns = "top_patterns"
        case recommendations
        case improvementSuggestions = "improvement_suggestions"
        case hits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totalHits = try c.decodeIfPresent(Int.self, forKey: .totalHits) ?? 0
        self.criticalHits = try c.decodeIfPresent(Int.self, forKey: .criticalHits) ?? 0
        self.warningHits = try c.decodeIfPresent(Int.self, forKey: .warningHits) ?? 0
        self.severityScore = try c.decodeIfPresent(Double.self, forKey: .severityScore) ?? 0.0
        self.overallAssessment = try c.decodeIfPresent(String.self, forKey: .overallAssessment) ?? ""
        self.categoryDistribution = try c.decodeIfPresent([String: Int].self, forKey: .categoryDistribution) ?? [:]
        self.topPatterns = try c.decodeIfPresent([String].self, forKey: .topPatterns) ?? []
        self.recommendations = try c.decodeIfPresent([String].self, forKey: .recommendations) ?? []
        self.improvementSuggestions = try c.decodeIfPresent([String].self, forKey: .improvementSuggestions) ?? []
        self.hits = try c.decodeIfPresent([AntiAIHit].self, forKey: .hits) ?? []
    }
}

/// 单条 AI 味命中，字段对齐原版 types/anti-ai.ts:11-19 ClicheHit
struct AntiAIHit: Codable, Identifiable, Equatable {
    var id: String { "\(pattern ?? "")-\(start ?? 0)" }
    let pattern: String
    let text: String
    let start: Int?
    let end: Int?
    let severity: String
    let category: String
    let replacementHint: String

    enum CodingKeys: String, CodingKey {
        case pattern, text, start, end, severity, category
        case replacementHint = "replacement_hint"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pattern = try c.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        self.text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        self.start = try c.decodeIfPresent(Int.self, forKey: .start)
        self.end = try c.decodeIfPresent(Int.self, forKey: .end)
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity) ?? "info"
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.replacementHint = try c.decodeIfPresent(String.self, forKey: .replacementHint) ?? ""
    }
}

// MARK: - AntiAI 系统统计 — types/anti-ai.ts:76-90

/// Anti-AI 系统统计，对应后端 AntiAIStats
struct AntiAIStats: Codable, Equatable {
    let totalPrompts: Int
    let antiAiPrompts: Int
    let categoriesCount: Int
    let clichePatterns: Int
    let layers: AntiAILayers?

    enum CodingKeys: String, CodingKey {
        case totalPrompts = "total_prompts"
        case antiAiPrompts = "anti_ai_prompts"
        case categoriesCount = "categories_count"
        case clichePatterns = "cliche_patterns"
        case layers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totalPrompts = try c.decodeIfPresent(Int.self, forKey: .totalPrompts) ?? 0
        self.antiAiPrompts = try c.decodeIfPresent(Int.self, forKey: .antiAiPrompts) ?? 0
        self.categoriesCount = try c.decodeIfPresent(Int.self, forKey: .categoriesCount) ?? 0
        self.clichePatterns = try c.decodeIfPresent(Int.self, forKey: .clichePatterns) ?? 0
        self.layers = try c.decodeIfPresent(AntiAILayers.self, forKey: .layers)
    }
}

/// 七层防御状态 — types/anti-ai.ts:81-89
struct AntiAILayers: Codable, Equatable {
    let l1PositiveFraming: Int?
    let l2ProtocolRules: Int?
    let l3AllowlistScenes: Int?
    let l4StateVector: String?
    let l5ContextQuota: String?
    let l6TokenGuard: String?
    let l7Audit: String?

    enum CodingKeys: String, CodingKey {
        case l1PositiveFraming = "L1_positive_framing"
        case l2ProtocolRules = "L2_protocol_rules"
        case l3AllowlistScenes = "L3_allowlist_scenes"
        case l4StateVector = "L4_state_vector"
        case l5ContextQuota = "L5_context_quota"
        case l6TokenGuard = "L6_token_guard"
        case l7Audit = "L7_audit"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.l1PositiveFraming = try c.decodeIfPresent(Int.self, forKey: .l1PositiveFraming)
        self.l2ProtocolRules = try c.decodeIfPresent(Int.self, forKey: .l2ProtocolRules)
        self.l3AllowlistScenes = try c.decodeIfPresent(Int.self, forKey: .l3AllowlistScenes)
        self.l4StateVector = try c.decodeIfPresent(String.self, forKey: .l4StateVector)
        self.l5ContextQuota = try c.decodeIfPresent(String.self, forKey: .l5ContextQuota)
        self.l6TokenGuard = try c.decodeIfPresent(String.self, forKey: .l6TokenGuard)
        self.l7Audit = try c.decodeIfPresent(String.self, forKey: .l7Audit)
    }
}

// MARK: - 白名单场景 — types/anti-ai.ts:58-64

/// 白名单场景，对应后端 AllowlistScene
struct AllowlistScene: Codable, Identifiable, Equatable {
    var id: String { sceneType }
    let sceneType: String
    let allowedCategories: [String]
    let allowedPatterns: [String]
    let maxDensityPer1000: Int
    let description: String

    enum CodingKeys: String, CodingKey {
        case sceneType = "scene_type"
        case allowedCategories = "allowed_categories"
        case allowedPatterns = "allowed_patterns"
        case maxDensityPer1000 = "max_density_per_1000"
        case description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sceneType = try c.decodeIfPresent(String.self, forKey: .sceneType) ?? ""
        self.allowedCategories = try c.decodeIfPresent([String].self, forKey: .allowedCategories) ?? []
        self.allowedPatterns = try c.decodeIfPresent([String].self, forKey: .allowedPatterns) ?? []
        self.maxDensityPer1000 = try c.decodeIfPresent(Int.self, forKey: .maxDensityPer1000) ?? 0
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

// MARK: - 评估颜色映射 — types/anti-ai.ts:100-106

/// 评估颜色映射，对应原版 ASSESSMENT_COLORS
enum AntiAIAssessment {
    static let colors: [String: Color] = [
        "纯净": .green,
        "轻微": Color(red: 0.52, green: 0.80, blue: 0.09),
        "中等": .orange,
        "严重": .red,
        "未检测": Color(red: 0.42, green: 0.45, blue: 0.50),
    ]

    /// 场景类型中文映射 — types/anti-ai.ts:110-117
    static let sceneTypeLabels: [String: String] = [
        "default": "默认",
        "battle": "战斗",
        "suspense": "悬疑",
        "horror": "恐怖",
        "confession": "告白",
        "revelation": "揭秘/反转",
    ]

    static func color(for assessment: String) -> Color {
        colors[assessment] ?? Color(red: 0.42, green: 0.45, blue: 0.50)
    }

    static func sceneLabel(_ sceneType: String) -> String {
        sceneTypeLabels[sceneType] ?? sceneType
    }
}

// MARK: - 分类信息

/// 分类信息，对应后端 CategoryInfo
struct AntiAICategoryInfo: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let name: String
    let icon: String
    let description: String
    let color: String
    let sortOrder: Int
    let promptCount: Int

    enum CodingKeys: String, CodingKey {
        case key, name, icon, description, color
        case sortOrder = "sort_order"
        case promptCount = "prompt_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? ""
        self.description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        self.promptCount = try c.decodeIfPresent(Int.self, forKey: .promptCount) ?? 0
    }
}

// MARK: - 规则信息

/// 规则信息，对应后端 RuleInfo
struct AntiAIRuleInfo: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let antiPattern: String
    let positiveAction: String
    let category: String
    let severity: String

    enum CodingKeys: String, CodingKey {
        case key
        case antiPattern = "anti_pattern"
        case positiveAction = "positive_action"
        case category, severity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        self.antiPattern = try c.decodeIfPresent(String.self, forKey: .antiPattern) ?? ""
        self.positiveAction = try c.decodeIfPresent(String.self, forKey: .positiveAction) ?? ""
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity) ?? "info"
    }
}

// MARK: - 白名单更新请求

/// 白名单更新请求，对应后端 AllowlistUpdateRequest
struct AllowlistUpdateRequest: Codable {
    let sceneType: String
    let allowedCategories: [String]
    let allowedPatterns: [String]
    let maxDensityPer1000: Double
    let description: String

    enum CodingKeys: String, CodingKey {
        case sceneType = "scene_type"
        case allowedCategories = "allowed_categories"
        case allowedPatterns = "allowed_patterns"
        case maxDensityPer1000 = "max_density_per_1000"
        case description
    }
}

// MARK: - 审计趋势

/// 审计趋势（GET /anti-ai/trend/{novel_id}），后端返回 dict
struct AntiAITrend: Codable, Equatable {
    let novelId: String
    let dataPoints: [AntiAITrendPoint]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.novelId = dict["novel_id"]?.stringStringValue ?? ""
        let dpData = try JSONSerialization.data(withJSONObject: dict["data_points"]?.value ?? [])
        self.dataPoints = (try? CangjieDecoder.shared.decode([AntiAITrendPoint].self, from: dpData)) ?? []
    }
}

/// 趋势数据点
struct AntiAITrendPoint: Codable, Equatable {
    let chapter: Int
    let severityScore: Double
    let totalHits: Int

    enum CodingKeys: String, CodingKey {
        case chapter
        case severityScore = "severity_score"
        case totalHits = "total_hits"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapter = try c.decodeIfPresent(Int.self, forKey: .chapter) ?? 0
        self.severityScore = try c.decodeIfPresent(Double.self, forKey: .severityScore) ?? 0.0
        self.totalHits = try c.decodeIfPresent(Int.self, forKey: .totalHits) ?? 0
    }
}
