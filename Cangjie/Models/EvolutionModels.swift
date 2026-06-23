//
//  EvolutionModels.swift
//  Cangjie
//
//  故事演化模型，字段对齐后端 interfaces/api/v1/engine/evolution_routes.py。
//  以及 domain/evolution/models.py。
//

import Foundation

// MARK: - 演化快照

/// 演化快照，后端返回 dict（来自 to_dict()）
struct EvolutionSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let novelId: String
    let branchId: String
    let chapterNumber: Int
    let status: String
    let snapshotData: AnyCodable
    let violations: [AnyCodable]?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case novelId = "novel_id"
        case branchId = "branch_id"
        case chapterNumber = "chapter_number"
        case status
        case snapshotData = "snapshot"
        case violations
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.branchId = try c.decodeIfPresent(String.self, forKey: .branchId) ?? "main"
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        self.snapshotData = try c.decodeIfPresent(AnyCodable.self, forKey: .snapshotData) ?? AnyCodable([:])
        self.violations = try c.decodeIfPresent([AnyCodable].self, forKey: .violations)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - 演化快照列表响应

/// 演化快照列表响应（GET /novels/{id}/evolution/snapshots）
struct EvolutionSnapshotListResponse: Codable, Equatable {
    let novelId: String
    let branchId: String
    let snapshots: [EvolutionSnapshot]
    let counts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case snapshots, counts
        case novelId = "novel_id"
        case branchId = "branch_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId) ?? ""
        self.branchId = try c.decodeIfPresent(String.self, forKey: .branchId) ?? "main"
        self.snapshots = try c.decodeIfPresent([EvolutionSnapshot].self, forKey: .snapshots) ?? []
        self.counts = try c.decodeIfPresent([String: Int].self, forKey: .counts) ?? [:]
    }
}

// MARK: - 闸门请求

/// 闸门请求，对应后端 GateRequest
struct EvolutionGateRequest: Codable {
    let chapterNumber: Int
    let branchId: String
    let outlineContent: String
    let povCharacterId: String?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
        case branchId = "branch_id"
        case outlineContent = "outline_content"
        case povCharacterId = "pov_character_id"
        case tags
    }
}

// MARK: - 闸门响应

/// 闸门检查响应（POST /novels/{id}/evolution/gate），后端返回 report.to_dict()
struct EvolutionGateReport: Codable, Equatable {
    let chapterNumber: Int
    let branchId: String
    let passed: Bool?
    let violations: [AnyCodable]?
    let governanceBudget: AnyCodable?
    let governanceContextRequest: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case passed, violations
        case chapterNumber = "chapter_number"
        case branchId = "branch_id"
        case governanceBudget = "governance_budget"
        case governanceContextRequest = "governance_context_request"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        self.chapterNumber = dict["chapter_number"]?.intValue ?? 0
        self.branchId = dict["branch_id"]?.stringStringValue ?? "main"
        self.passed = dict["passed"]?.boolValue
        self.violations = dict["violations"]?.arrayValue?.map { AnyCodable($0) }
        self.governanceBudget = dict["governance_budget"].map { AnyCodable($0) }
        self.governanceContextRequest = dict["governance_context_request"].map { AnyCodable($0) }
    }
}

// MARK: - 覆盖请求

/// 覆盖请求，对应后端 OverrideRequest
struct EvolutionOverrideRequest: Codable {
    let branchId: String
    let patches: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
        case patches
    }
}

// MARK: - 回放请求

/// 回放请求，对应后端 ReplayRequest
struct EvolutionReplayRequest: Codable {
    let branchId: String

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
    }
}

// MARK: - 演化时间线

/// 演化时间线（聚合多个快照的章节数据）
struct EvolutionTimeline: Equatable {
    let snapshots: [EvolutionSnapshot]
    let counts: [String: Int]
}
