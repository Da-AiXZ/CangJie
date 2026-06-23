//
//  MonitorModels.swift
//  Cangjie
//
//  监控模型，字段对齐后端 interfaces/api/v1/workbench/monitor.py 的 Pydantic 模型。
//

import Foundation

// MARK: - 张力曲线

/// 张力点，对应后端 TensionPoint
struct TensionPoint: Codable, Identifiable, Equatable {
    var id: Int { chapter }
    let chapter: Int
    let tension: Double
    let title: String
    let evaluated: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.chapter = try c.decodeIfPresent(Int.self, forKey: .chapter) ?? 0
        self.tension = try c.decodeIfPresent(Double.self, forKey: .tension) ?? 0.0
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.evaluated = try c.decodeIfPresent(Bool.self, forKey: .evaluated) ?? true
    }
}

/// 张力曲线统计，对应后端 TensionCurveStats
struct TensionCurveStats: Codable, Equatable {
    let avgTension: Double
    let maxTension: Double
    let minTension: Double
    let variance: Double
    let isFlat: Bool
    let evaluatedCount: Int
    let unevaluatedCount: Int
    let consecutiveLow: Int

    enum CodingKeys: String, CodingKey {
        case avgTension = "avg_tension"
        case maxTension = "max_tension"
        case minTension = "min_tension"
        case variance
        case isFlat = "is_flat"
        case evaluatedCount = "evaluated_count"
        case unevaluatedCount = "unevaluated_count"
        case consecutiveLow = "consecutive_low"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.avgTension = try c.decodeIfPresent(Double.self, forKey: .avgTension) ?? 0.0
        self.maxTension = try c.decodeIfPresent(Double.self, forKey: .maxTension) ?? 0.0
        self.minTension = try c.decodeIfPresent(Double.self, forKey: .minTension) ?? 0.0
        self.variance = try c.decodeIfPresent(Double.self, forKey: .variance) ?? 0.0
        self.isFlat = try c.decodeIfPresent(Bool.self, forKey: .isFlat) ?? false
        self.evaluatedCount = try c.decodeIfPresent(Int.self, forKey: .evaluatedCount) ?? 0
        self.unevaluatedCount = try c.decodeIfPresent(Int.self, forKey: .unevaluatedCount) ?? 0
        self.consecutiveLow = try c.decodeIfPresent(Int.self, forKey: .consecutiveLow) ?? 0
    }
}

/// 张力曲线响应，对应后端 TensionCurveResponse
struct TensionCurveResponse: Codable, Equatable {
    let novelId: String
    let points: [TensionPoint]
    let stats: TensionCurveStats?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case points, stats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.points = try c.decodeIfPresent([TensionPoint].self, forKey: .points) ?? []
        self.stats = try c.decodeIfPresent(TensionCurveStats.self, forKey: .stats)
    }
}

// MARK: - 文风漂移

/// 文风漂移响应，对应后端 VoiceDriftResponse
struct VoiceDrift: Codable, Identifiable, Equatable {
    var id: String { characterId }
    let characterId: String
    let characterName: String
    let driftScore: Double
    let status: String
    let sampleCount: Int

    enum CodingKeys: String, CodingKey {
        case characterId = "character_id"
        case characterName = "character_name"
        case driftScore = "drift_score"
        case status
        case sampleCount = "sample_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.characterId = try c.decodeIfPresent(String.self, forKey: .characterId) ?? ""
        self.characterName = try c.decodeIfPresent(String.self, forKey: .characterName) ?? ""
        self.driftScore = try c.decodeIfPresent(Double.self, forKey: .driftScore) ?? 0.0
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "normal"
        self.sampleCount = try c.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0
    }
}

// MARK: - 伏笔统计

/// 伏笔统计响应，对应后端 ForeshadowStatsResponse
struct ForeshadowStats: Codable, Equatable {
    let totalPlanted: Int
    let totalResolved: Int
    let pending: Int
    let forgottenRisk: Int
    let resolutionRate: Double

    enum CodingKeys: String, CodingKey {
        case totalPlanted = "total_planted"
        case totalResolved = "total_resolved"
        case pending
        case forgottenRisk = "forgotten_risk"
        case resolutionRate = "resolution_rate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.totalPlanted = try c.decodeIfPresent(Int.self, forKey: .totalPlanted) ?? 0
        self.totalResolved = try c.decodeIfPresent(Int.self, forKey: .totalResolved) ?? 0
        self.pending = try c.decodeIfPresent(Int.self, forKey: .pending) ?? 0
        self.forgottenRisk = try c.decodeIfPresent(Int.self, forKey: .forgottenRisk) ?? 0
        self.resolutionRate = try c.decodeIfPresent(Double.self, forKey: .resolutionRate) ?? 0.0
    }
}

// MARK: - 监控快照

/// 监控快照，聚合所有监控数据用于展示
struct MonitorSnapshot: Equatable {
    let tensionCurve: TensionCurveResponse?
    let voiceDrifts: [VoiceDrift]
    let foreshadowStats: ForeshadowStats?
}
