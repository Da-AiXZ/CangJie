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

/// 治理状态（GET /novels/{id}/governance/state），字段对齐原版 governance.ts:61-67
/// storylines ← canonical_storylines, debts ← open_debts, latestReport ← latest_report（单条）
/// chapterBudgetPreview ← chapter_budget_preview（P0-3修复）
struct GovernanceState: Codable, Equatable {
    let contract: GovernanceContract?
    let storylines: [Storyline]?
    let debts: [DebtRecord]?
    let latestReport: GovernanceReport?
    let chapterBudgetPreview: ChapterNarrativeBudgetDTO?

    enum CodingKeys: String, CodingKey {
        case contract
        case storylines = "canonical_storylines"
        case debts = "open_debts"
        case latestReport = "latest_report"
        case chapterBudgetPreview = "chapter_budget_preview"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.contract = try c.decodeIfPresent(GovernanceContract.self, forKey: .contract)
        self.storylines = try c.decodeIfPresent([Storyline].self, forKey: .storylines)
        self.debts = try c.decodeIfPresent([DebtRecord].self, forKey: .debts)
        self.latestReport = try c.decodeIfPresent(GovernanceReport.self, forKey: .latestReport)
        self.chapterBudgetPreview = try c.decodeIfPresent(ChapterNarrativeBudgetDTO.self, forKey: .chapterBudgetPreview)
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

/// 故事线，对应原版 governance.ts:13-26 CanonicalStorylineDTO
struct Storyline: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let aliases: [String]?
    let promiseTags: [String]?
    let status: String?
    let introducedChapter: Int?
    let resolvedChapter: Int?
    /// P1 补齐：novel_id — governance.ts:15
    let novelId: String?
    /// P1 补齐：canonical_key — governance.ts:16
    let canonicalKey: String?
    /// P1 补齐：goal — governance.ts:19
    let goal: String?
    /// P1 补齐：conflict — governance.ts:20
    let conflict: String?
    /// P1 补齐：span: Record<string, number | null> — governance.ts:21
    let span: [String: Int?]?
    /// P1 补齐：source_storyline_ids — governance.ts:24
    let sourceStorylineIds: [String]?
    /// P1 补齐：updated_at — governance.ts:25
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, aliases, status
        case promiseTags = "promise_tags"
        case introducedChapter = "introduced_chapter"
        case resolvedChapter = "resolved_chapter"
        case novelId = "novel_id"
        case canonicalKey = "canonical_key"
        case goal, conflict, span
        case sourceStorylineIds = "source_storyline_ids"
        case updatedAt = "updated_at"
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
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId)
        self.canonicalKey = try c.decodeIfPresent(String.self, forKey: .canonicalKey)
        self.goal = try c.decodeIfPresent(String.self, forKey: .goal)
        self.conflict = try c.decodeIfPresent(String.self, forKey: .conflict)
        self.span = try c.decodeIfPresent([String: Int?].self, forKey: .span)
        self.sourceStorylineIds = try c.decodeIfPresent([String].self, forKey: .sourceStorylineIds)
        self.updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
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

/// 治理报告 — governance.ts:48-59 GovernanceReportDTO
/// P0-4修复：新增 promiseHitRate / severity / issues 字段
struct GovernanceReport: Codable, Identifiable, Equatable {
    let id: String
    let chapterNumber: Int?
    let promiseHitRate: Double?
    let severity: String?
    let issues: [GovernanceIssueDTO]?
    let budgetPatch: AnyCodable?
    let shouldPauseAutopilot: Bool?
    let status: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "report_id"
        case chapterNumber = "chapter_number"
        case promiseHitRate = "promise_hit_rate"
        case severity
        case issues
        case budgetPatch = "budget_patch"
        case shouldPauseAutopilot = "should_pause_autopilot"
        case status = "review_status"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber)
        self.promiseHitRate = try c.decodeIfPresent(Double.self, forKey: .promiseHitRate)
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity)
        self.issues = try c.decodeIfPresent([GovernanceIssueDTO].self, forKey: .issues)
        self.budgetPatch = try c.decodeIfPresent(AnyCodable.self, forKey: .budgetPatch)
        self.shouldPauseAutopilot = try c.decodeIfPresent(Bool.self, forKey: .shouldPauseAutopilot)
        self.status = try c.decodeIfPresent(String.self, forKey: .status)
        self.createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - 治理问题 DTO — governance.ts:39-46 GovernanceIssueDTO

/// 治理问题 DTO — governance.ts:39-46
struct GovernanceIssueDTO: Codable, Identifiable, Equatable {
    var id: String { code }
    let code: String
    let severity: String
    let title: String
    let detail: String
    let evidence: [String]?
    let suggestion: String?

    enum CodingKeys: String, CodingKey {
        case code, severity, title, detail, evidence, suggestion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try c.decodeIfPresent(String.self, forKey: .code) ?? ""
        self.severity = try c.decodeIfPresent(String.self, forKey: .severity) ?? "info"
        self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        self.evidence = try c.decodeIfPresent([String].self, forKey: .evidence)
        self.suggestion = try c.decodeIfPresent(String.self, forKey: .suggestion)
    }
}

// MARK: - 章节叙事预算 DTO — governance.ts:28-37 ChapterNarrativeBudgetDTO

/// 章节叙事预算 DTO — governance.ts:28-37
/// P0-3修复：用于 GovernanceState.chapterBudgetPreview
struct ChapterNarrativeBudgetDTO: Codable, Equatable {
    let novelId: String?
    let chapterNumber: Int
    let maxNewStorylines: Int
    let maxDebtClosures: Int
    let allowedRevealLevel: String
    let mustServePromiseTags: [String]
    let carryOverDebtIds: [String]
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case chapterNumber = "chapter_number"
        case maxNewStorylines = "max_new_storylines"
        case maxDebtClosures = "max_debt_closures"
        case allowedRevealLevel = "allowed_reveal_level"
        case mustServePromiseTags = "must_serve_promise_tags"
        case carryOverDebtIds = "carry_over_debt_ids"
        case notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try c.decodeIfPresent(String.self, forKey: .novelId)
        self.chapterNumber = try c.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 0
        self.maxNewStorylines = try c.decodeIfPresent(Int.self, forKey: .maxNewStorylines) ?? 0
        self.maxDebtClosures = try c.decodeIfPresent(Int.self, forKey: .maxDebtClosures) ?? 0
        self.allowedRevealLevel = try c.decodeIfPresent(String.self, forKey: .allowedRevealLevel) ?? ""
        self.mustServePromiseTags = try c.decodeIfPresent([String].self, forKey: .mustServePromiseTags) ?? []
        self.carryOverDebtIds = try c.decodeIfPresent([String].self, forKey: .carryOverDebtIds) ?? []
        self.notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
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
