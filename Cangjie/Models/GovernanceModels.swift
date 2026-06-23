//
//  GovernanceModels.swift
//  Cangjie
//
//  叙事治理模型，字段对齐后端 interfaces/api/v1/engine/governance_routes.py 的请求模型。
//  以及 application/governance/service.py 的返回结构。
//

import Foundation

// MARK: - 治理契约载荷

/// 治理契约更新请求，对应后端 ContractPayload
struct GovernanceContractPayload: Codable {
    let titlePromise: String?
    let coreQuestion: String?
    let themeAnchors: [String]?
    let forbiddenEarlyPayoffs: [String]?
    let revealBudget: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case titlePromise = "title_promise"
        case coreQuestion = "core_question"
        case themeAnchors = "theme_anchors"
        case forbiddenEarlyPayoffs = "forbidden_early_payoffs"
        case revealBudget = "reveal_budget"
    }
}

// MARK: - 合并故事线载荷

/// 合并故事线请求，对应后端 MergeStorylinesPayload
struct MergeStorylinesPayload: Codable {
    let sourceIds: [String]
    let targetId: String?
    let title: String?
    let aliases: [String]
    let promiseTags: [String]

    enum CodingKeys: String, CodingKey {
        case sourceIds = "source_ids"
        case targetId = "target_id"
        case title, aliases
        case promiseTags = "promise_tags"
    }
}

// MARK: - 预算预览载荷

/// 预算预览请求，对应后端 BudgetPreviewPayload
struct BudgetPreviewPayload: Codable {
    let chapterNumber: Int?

    enum CodingKeys: String, CodingKey {
        case chapterNumber = "chapter_number"
    }
}

// MARK: - 审阅动作载荷

/// 审阅动作请求，对应后端 ReviewActionPayload
struct ReviewActionPayload: Codable {
    let reportId: String
    let action: String
    let patch: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case reportId = "report_id"
        case action, patch
    }
}

// MARK: - 治理状态

/// 治理状态（GET /novels/{id}/governance/state），后端返回 dict[str, Any]
struct GovernanceState: Codable, Equatable {
    let contract: GovernanceContract?
    let storylines: [Storyline]?
    let debts: [DebtRecord]?
    let reports: [GovernanceReport]?

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)

        let contractData = try JSONSerialization.data(withJSONObject: dict["contract"]?.value ?? [:])
        self.contract = try? CangjieDecoder.shared.decode(GovernanceContract.self, from: contractData)

        let storylinesData = try JSONSerialization.data(withJSONObject: dict["storylines"]?.value ?? [])
        self.storylines = try? CangjieDecoder.shared.decode([Storyline].self, from: storylinesData)

        let debtsData = try JSONSerialization.data(withJSONObject: dict["debts"]?.value ?? [])
        self.debts = try? CangjieDecoder.shared.decode([DebtRecord].self, from: debtsData)

        let reportsData = try JSONSerialization.data(withJSONObject: dict["reports"]?.value ?? [])
        self.reports = try? CangjieDecoder.shared.decode([GovernanceReport].self, from: reportsData)
    }
}

// MARK: - 治理契约

/// 治理契约
struct GovernanceContract: Codable, Equatable {
    let titlePromise: String?
    let coreQuestion: String?
    let themeAnchors: [String]?
    let forbiddenEarlyPayoffs: [String]?
    let revealBudget: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case titlePromise = "title_promise"
        case coreQuestion = "core_question"
        case themeAnchors = "theme_anchors"
        case forbiddenEarlyPayoffs = "forbidden_early_payoffs"
        case revealBudget = "reveal_budget"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.titlePromise = try c.decodeIfPresent(String.self, forKey: .titlePromise)
        self.coreQuestion = try c.decodeIfPresent(String.self, forKey: .coreQuestion)
        self.themeAnchors = try c.decodeIfPresent([String].self, forKey: .themeAnchors)
        self.forbiddenEarlyPayoffs = try c.decodeIfPresent([String].self, forKey: .forbiddenEarlyPayoffs)
        self.revealBudget = try c.decodeIfPresent([String: AnyCodable].self, forKey: .revealBudget)
    }
}

// MARK: - 故事线

/// 故事线
struct Storyline: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let aliases: [String]?
    let promiseTags: [String]?
    let status: String?
    let introducedChapter: Int?
    let resolvedChapter: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, aliases, status
        case promiseTags = "promise_tags"
        case introducedChapter = "introduced_chapter"
        case resolvedChapter = "resolved_chapter"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.aliases = try c.decodeIfPresent([String].self, forKey: .aliases)
        self.promiseTags = try c.decodeIfPresent([String].self, forKey: .promiseTags)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.introducedChapter = try c.decodeIfPresent(Int.self, forKey: .introducedChapter)
        self.resolvedChapter = try c.decodeIfPresent(Int.self, forKey: .resolvedChapter)
    }
}

// MARK: - 债务记录

/// 叙事债务记录
struct DebtRecord: Codable, Identifiable, Equatable {
    let id: String
    let type: String?
    let description: String?
    let chapter: Int?
    let status: String?
    let severity: String?

    enum CodingKeys: String, CodingKey {
        case id, type, description, chapter, status, severity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.type = try c.decodeIfPresent(String.self, forKey: .type)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.chapter = try c.decodeIfPresent(Int.self, forKey: .chapter)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity)
    }
}

// MARK: - 治理报告

/// 治理报告
struct GovernanceReport: Codable, Identifiable, Equatable {
    let id: String
    let chapterNumber: Int?
    let violations: [AnyCodable]?
    let budget: AnyCodable?
    let status: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, violations, budget
        case chapterNumber = "chapter_number"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.violations = try c.decodeIfPresent([AnyCodable].self, forKey: .violations)
        self.budget = try c.decodeIfPresent(AnyCodable.self, forKey: .budget)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - 预算预览响应

/// 预算预览响应（POST /novels/{id}/governance/chapter-budget/preview），后端返回 dict
struct GovernanceBudgetPreview: Codable, Equatable {
    let budget: GovernanceBudget?
    let contextRequest: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case budget
        case contextRequest = "context_request"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let dict = try c.decode([String: AnyCodable].self)
        let budgetData = try JSONSerialization.data(withJSONObject: dict["budget"]?.value ?? [:])
        self.budget = try? CangjieDecoder.shared.decode(GovernanceBudget.self, from: budgetData)
        self.contextRequest = dict["context_request"].map { AnyCodable($0) }
    }
}

// MARK: - 治理预算

/// 治理预算
struct GovernanceBudget: Codable, Equatable {
    let mustServePromiseTags: [String]?
    let availableRevealBudget: Int?
    let debtLoad: Int?
    let maxDebtsPerChapter: Int?

    enum CodingKeys: String, CodingKey {
        case mustServePromiseTags = "must_serve_promise_tags"
        case availableRevealBudget = "available_reveal_budget"
        case debtLoad = "debt_load"
        case maxDebtsPerChapter = "max_debts_per_chapter"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mustServePromiseTags = try c.decodeIfPresent([String].self, forKey: .mustServePromiseTags)
        self.availableRevealBudget = try c.decodeIfPresent(Int.self, forKey: .availableRevealBudget)
        self.debtLoad = try c.decodeIfPresent(Int.self, forKey: .debtLoad)
        self.maxDebtsPerChapter = try c.decodeIfPresent(Int.self, forKey: .maxDebtsPerChapter)
    }
}
