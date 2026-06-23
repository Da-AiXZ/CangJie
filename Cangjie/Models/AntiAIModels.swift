//
//  AntiAIModels.swift
//  Cangjie
//
//  Anti-AI 防御模型，字段对齐后端 interfaces/api/v1/anti_ai.py 的请求/响应模型。
//

import Foundation

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

/// 单条 AI 味命中
struct AntiAIHit: Codable, Identifiable, Equatable {
    var id: String { UUID().uuidString }
    let category: String?
    let pattern: String?
    let severity: String?
    let excerpt: String?
    let suggestion: String?
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case category, pattern, severity, excerpt, suggestion, position
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.category = try c.decodeIfPresent(String.self, forKey: .category)
        self.pattern = try c.decodeIfPresent(String.self, forKey: .pattern)
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity)
        self.excerpt = try c.decodeIfPresent(String.self, forKey: .excerpt)
        self.suggestion = try c.decodeIfPresent(String.self, forKey: .suggestion)
        self.position = try c.decodeIfPresent(Int.self, forKey: .position)
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
