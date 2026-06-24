//
//  PlotOutlineModels.swift
//  Cangjie
//
//  剧情总纲模型 + SSE事件 + 向导缓存 + plotOutlineModel 工具函数。
//  对齐原版 workflow.ts:109-144, wizardStageCache.ts:1-103, plotOutlineModel.ts:1-410。
//  机制4：每个模型/函数标注原版文件+行号。
//

import Foundation

// MARK: - 剧情总纲 DTO（workflow.ts:109-124）

/// 剧情总纲阶段 DTO — workflow.ts:109-117
struct PlotOutlineStageDTO: Codable, Equatable, Identifiable {
    var id: String { "\(phase)_\(chapterStart ?? 0)_\(chapterEnd ?? 0)" }
    var phase: String
    var label: String
    var rangePercent: String
    var chapterStart: Int?
    var chapterEnd: Int?
    var summary: String
    var keyGoals: [String]?

    enum CodingKeys: String, CodingKey {
        case phase, label
        case rangePercent = "range_percent"
        case chapterStart = "chapter_start"
        case chapterEnd = "chapter_end"
        case summary
        case keyGoals = "key_goals"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase) ?? ""
        self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        self.rangePercent = try c.decodeIfPresent(String.self, forKey: .rangePercent) ?? ""
        self.chapterStart = try c.decodeIfPresent(Int.self, forKey: .chapterStart)
        self.chapterEnd = try c.decodeIfPresent(Int.self, forKey: .chapterEnd)
        self.summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.keyGoals = try c.decodeIfPresent([String].self, forKey: .keyGoals)
    }

    init(phase: String = "", label: String = "", rangePercent: String = "",
         chapterStart: Int? = nil, chapterEnd: Int? = nil,
         summary: String = "", keyGoals: [String]? = nil) {
        self.phase = phase
        self.label = label
        self.rangePercent = rangePercent
        self.chapterStart = chapterStart
        self.chapterEnd = chapterEnd
        self.summary = summary
        self.keyGoals = keyGoals
    }
}

/// 剧情总纲 DTO — workflow.ts:119-124
struct PlotOutlineDTO: Codable, Equatable {
    var mainStoryOverview: String
    var stagePlan: [PlotOutlineStageDTO]
    var expectedEnding: String
    var coreConflict: String

    enum CodingKeys: String, CodingKey {
        case mainStoryOverview = "main_story_overview"
        case stagePlan = "stage_plan"
        case expectedEnding = "expected_ending"
        case coreConflict = "core_conflict"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mainStoryOverview = try c.decodeIfPresent(String.self, forKey: .mainStoryOverview) ?? ""
        self.stagePlan = try c.decodeIfPresent([PlotOutlineStageDTO].self, forKey: .stagePlan) ?? []
        self.expectedEnding = try c.decodeIfPresent(String.self, forKey: .expectedEnding) ?? ""
        self.coreConflict = try c.decodeIfPresent(String.self, forKey: .coreConflict) ?? ""
    }

    init(mainStoryOverview: String = "", stagePlan: [PlotOutlineStageDTO] = [],
         expectedEnding: String = "", coreConflict: String = "") {
        self.mainStoryOverview = mainStoryOverview
        self.stagePlan = stagePlan
        self.expectedEnding = expectedEnding
        self.coreConflict = coreConflict
    }
}

/// 生成剧情总纲响应 — workflow.ts:126-130
struct GeneratePlotOutlineResponse: Codable, Equatable {
    var plotOutline: PlotOutlineDTO?
    var invocationSessionId: String?
    var invocationNextAction: String?

    enum CodingKeys: String, CodingKey {
        case plotOutline = "plot_outline"
        case invocationSessionId = "invocation_session_id"
        case invocationNextAction = "invocation_next_action"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.plotOutline = try c.decodeIfPresent(PlotOutlineDTO.self, forKey: .plotOutline)
        self.invocationSessionId = try c.decodeIfPresent(String.self, forKey: .invocationSessionId)
        self.invocationNextAction = try c.decodeIfPresent(String.self, forKey: .invocationNextAction)
    }
}

// MARK: - SSE 事件类型（workflow.ts:140-144）

/// 剧情总纲 SSE 事件类型
enum PlotOutlineStreamEventType: String {
    case phase
    case approvalRequired = "approval_required"
    case done
    case error
}

/// 剧情总纲 SSE 事件处理器 — workflow.ts:682-771 consumePlotOutlineStream
struct PlotOutlineStreamHandlers {
    var onPhase: ((String) -> Void)?
    var onApprovalRequired: ((String, String?, String?) -> Void)?
    var onDone: ((PlotOutlineDTO?) -> Void)?
    var onError: ((String) -> Void)?

    init(
        onPhase: ((String) -> Void)? = nil,
        onApprovalRequired: ((String, String?, String?) -> Void)? = nil,
        onDone: ((PlotOutlineDTO?) -> Void)? = nil,
        onError: ((String) -> Void)? = nil
    ) {
        self.onPhase = onPhase
        self.onApprovalRequired = onApprovalRequired
        self.onDone = onDone
        self.onError = onError
    }
}

// MARK: - 向导 UI 缓存（wizardStageCache.ts:1-103）

/// 向导 UI 缓存版本号 — wizardStageCache.ts:8
let kWizardUiCacheSchema = 4

/// 剧情总纲缓存有效期（7天） — wizardStageCache.ts:10
let kWizardPlotOutlineTtlMs: TimeInterval = 7 * 24 * 60 * 60 * 1000

/// 向导 UI 缓存 Payload — wizardStageCache.ts:12-27
/// 主理人决策：保留8个字段（去掉 worldbuildingFieldLabels）
struct WizardUiCachePayload: Codable, Equatable {
    var v: Int
    var novelId: String
    var savedAt: Double
    var plotOutlineSavedAt: Double?
    var plotOutline: PlotOutlineDTO?
    var invocationSessionId: String?
    var wizardCompleted: Bool?
    var lastStep: Int?

    enum CodingKeys: String, CodingKey {
        case v
        case novelId = "novelId"
        case savedAt
        case plotOutlineSavedAt
        case plotOutline
        case invocationSessionId
        case wizardCompleted
        case lastStep
    }
}

/// 向导缓存工具 — wizardStageCache.ts:33-102
/// 主理人决策Q3：用 UserDefaults，key = wizard_ui_cache_{novelId}
enum WizardUiCache {

    /// 构建缓存 key
    private static func cacheKey(novelId: String) -> String {
        return "wizard_ui_cache_\(novelId)"
    }

    /// 读取缓存 — wizardStageCache.ts:33-39
    static func read(novelId: String) -> WizardUiCachePayload? {
        guard !novelId.isEmpty else { return nil }
        guard let data = UserDefaults.standard.data(forKey: cacheKey(novelId: novelId)) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(WizardUiCachePayload.self, from: data)
    }

    /// 写入缓存（增量合并） — wizardStageCache.ts:41-69
    static func write(novelId: String, patch: WizardUiCachePatch) {
        guard !novelId.isEmpty else { return }
        let prev = read(novelId: novelId)
        var next = WizardUiCachePayload(
            v: kWizardUiCacheSchema,
            novelId: novelId,
            savedAt: Date().timeIntervalSince1970 * 1000
        )
        if let prev = prev {
            next = prev
        }

        // 合并 patch
        if let plotOutline = patch.plotOutline {
            next.plotOutline = plotOutline
            next.plotOutlineSavedAt = Date().timeIntervalSince1970 * 1000
        } else if patch.clearPlotOutline == true {
            next.plotOutline = nil
            next.plotOutlineSavedAt = nil
        }
        if let invocationSessionId = patch.invocationSessionId {
            next.invocationSessionId = invocationSessionId
        } else if patch.clearInvocationSessionId == true {
            next.invocationSessionId = nil
        }
        if let wizardCompleted = patch.wizardCompleted {
            next.wizardCompleted = wizardCompleted
        }
        if let lastStep = patch.lastStep {
            next.lastStep = lastStep
        }

        next.v = kWizardUiCacheSchema
        next.novelId = novelId
        next.savedAt = Date().timeIntervalSince1970 * 1000

        let encoder = JSONEncoder()
        if let data = try? encoder.encode(next) {
            UserDefaults.standard.set(data, forKey: cacheKey(novelId: novelId))
        }
    }

    /// 清除缓存 — wizardStageCache.ts:71-74
    static func clear(novelId: String) {
        guard !novelId.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: cacheKey(novelId: novelId))
    }

    /// 检查缓存是否新鲜 — wizardStageCache.ts:76-80
    static func isPlotOutlineFresh(_ payload: WizardUiCachePayload?) -> Bool {
        guard let payload = payload, payload.plotOutline != nil else { return false }
        let base = payload.plotOutlineSavedAt ?? payload.savedAt
        let now = Date().timeIntervalSince1970 * 1000
        return (now - base) <= kWizardPlotOutlineTtlMs
    }

    /// 向导是否已完成 — wizardStageCache.ts:83-86
    static func isWizardCompleted(novelId: String) -> Bool {
        return read(novelId: novelId)?.wizardCompleted == true
    }

    /// 标记向导已完成 — wizardStageCache.ts:89-91
    static func markCompleted(novelId: String) {
        write(novelId: novelId, patch: WizardUiCachePatch(wizardCompleted: true))
    }

    /// 获取最后到达步骤 — wizardStageCache.ts:94-97
    static func getLastStep(novelId: String) -> Int? {
        return read(novelId: novelId)?.lastStep
    }

    /// 记录最后到达步骤 — wizardStageCache.ts:100-102
    static func setLastStep(novelId: String, step: Int) {
        write(novelId: novelId, patch: WizardUiCachePatch(lastStep: step))
    }
}

/// 向导缓存增量更新结构
struct WizardUiCachePatch {
    var plotOutline: PlotOutlineDTO?
    var clearPlotOutline: Bool?
    var invocationSessionId: String?
    var clearInvocationSessionId: Bool?
    var wizardCompleted: Bool?
    var lastStep: Int?

    init(
        plotOutline: PlotOutlineDTO? = nil,
        clearPlotOutline: Bool? = nil,
        invocationSessionId: String? = nil,
        clearInvocationSessionId: Bool? = nil,
        wizardCompleted: Bool? = nil,
        lastStep: Int? = nil
    ) {
        self.plotOutline = plotOutline
        self.clearPlotOutline = clearPlotOutline
        self.invocationSessionId = invocationSessionId
        self.clearInvocationSessionId = clearInvocationSessionId
        self.wizardCompleted = wizardCompleted
        self.lastStep = lastStep
    }
}

// MARK: - plotOutlineModel 工具函数（plotOutlineModel.ts:1-410）
// 主理人决策：放入此文件（PlotOutline 数据处理辅助函数，逻辑内聚）

/// 剧情总纲状态类型 — plotOutlineModel.ts:5
enum PlotOutlineStatus: String {
    case idle
    case creating
    case reviewing
    case generating
    case committing
    case done
    case error
}

/// 剧情总纲进度状态 — plotOutlineModel.ts:6
enum PlotOutlineProgressState: String {
    case pending
    case active
    case done
}

/// 剧情总纲进度项 — plotOutlineModel.ts:8-13
struct PlotOutlineProgressItem: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let desc: String
    var state: PlotOutlineProgressState
}

// MARK: - 常量（plotOutlineModel.ts:15-46）

private let kPlotOutlineMetaKeys: Set<String> = ["stage_plan"]
private let kPlotStageMetaKeys: Set<String> = ["phase", "label", "range_percent", "chapter_start", "chapter_end", "key_goals"]

private let kPlotFieldLabels: [String: String] = [
    "main_story_overview": "故事主线概述",
    "core_conflict": "核心冲突",
    "expected_ending": "预期结局",
    "summary": "阶段任务",
]

private let kPlotOverviewKeys = ["main_story_overview", "outline_main", "main_axis", "overview", "story_overview", "故事主线概述", "主线概述", "故事概述"]
private let kPlotEndingKeys = ["expected_ending", "ending_expect", "ending_expectation", "expectedEnding", "ending", "finale", "预期结局", "预期结尾", "结局预期", "故事最终走向"]
private let kPlotConflictKeys = ["core_conflict", "coreConflict", "conflict", "main_conflict", "核心冲突", "核心矛盾", "核心对抗"]
private let kPlotStageKeys = ["stage_plan", "stages", "阶段规划"]

private let kLegacyStageKeyAliases: [[String]] = [
    ["stage_opening_1_15", "stage_opening", "opening"],
    ["stage_develop_15_40", "stage_develop", "development"],
    ["stage_deepen_40_70", "stage_deepen", "deepening"],
    ["stage_climax_70_90", "stage_climax", "climax"],
    ["stage_end_90_100", "stage_end", "stage_ending", "ending"],
]

private struct StagePhaseMeta {
    let phase: String
    let label: String
    let rangePercent: String
}

private let kStagePhaseMeta: [StagePhaseMeta] = [
    StagePhaseMeta(phase: "opening", label: "开篇阶段", rangePercent: "1-15%"),
    StagePhaseMeta(phase: "development", label: "发展阶段", rangePercent: "15-40%"),
    StagePhaseMeta(phase: "deepening", label: "深化阶段", rangePercent: "40-70%"),
    StagePhaseMeta(phase: "climax", label: "高潮阶段", rangePercent: "70-90%"),
    StagePhaseMeta(phase: "ending", label: "收尾阶段", rangePercent: "90-100%"),
]

private let kStageRangeRatios: [Double] = [0.15, 0.40, 0.70, 0.90, 1.0]

private let kPhaseAliases: [String: String] = [
    "opening": "opening", "open": "opening", "start": "opening", "beginning": "opening", "setup": "opening",
    "开篇": "opening", "开篇阶段": "opening", "开局": "opening", "起始": "opening",
    "development": "development", "develop": "development", "rising": "development", "rising_action": "development",
    "发展": "development", "发展阶段": "development", "展开": "development",
    "deepening": "deepening", "deepen": "deepening", "middle": "deepening", "mid": "deepening",
    "深化": "deepening", "深化阶段": "deepening", "深入": "deepening",
    "climax": "climax", "peak": "climax", "high": "climax",
    "高潮": "climax", "高潮阶段": "climax", "爆发": "climax",
    "ending": "ending", "end": "ending", "finale": "ending", "resolution": "ending",
    "收尾": "ending", "收尾阶段": "ending", "结尾": "ending", "结局": "ending",
]

// MARK: - 工具函数实现（plotOutlineModel.ts:88-409）

/// 创建空剧情总纲 — plotOutlineModel.ts:88-95
func createEmptyPlotOutline() -> PlotOutlineDTO {
    return PlotOutlineDTO(
        mainStoryOverview: "",
        stagePlan: [],
        expectedEnding: "",
        coreConflict: ""
    )
}

/// 强制转章节号 — plotOutlineModel.ts:97-102
private func coerceChapterNumber(_ value: Any?) -> Int? {
    guard let value = value else { return nil }
    if let str = value as? String, str.isEmpty { return nil }
    let number: Double?
    if let n = value as? Int { number = Double(n) }
    else if let n = value as? Double { number = n }
    else if let str = value as? String, let n = Double(str) { number = n }
    else { return nil }
    guard let n = number, n.isFinite, n > 0 else { return nil }
    return Int(n)
}

/// 规范化阶段名 — plotOutlineModel.ts:104-107
private func canonicalPhase(_ value: Any?) -> String {
    guard let text = value as? String else { return "" }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        .replacingOccurrences(of: "-", with: "_")
        .replacingOccurrences(of: " ", with: "_")
    return kPhaseAliases[trimmed] ?? ""
}

/// 构建阶段章节范围 — plotOutlineModel.ts:109-129
private func buildStageChapterRanges(totalChapters: Int) -> [(chapterStart: Int, chapterEnd: Int)] {
    let total = max(kStageRangeRatios.count, Int(Double(totalChapters)) ?? 100)
    var ends: [Int] = []
    var previous = 0
    for (index, ratio) in kStageRangeRatios.enumerated() {
        var end: Int
        if index == kStageRangeRatios.count - 1 {
            end = total
        } else {
            end = max(previous + 1, Int((Double(total) * ratio).rounded()))
            let remainingMin = kStageRangeRatios.count - index - 1
            end = min(end, total - remainingMin)
        }
        ends.append(end)
        previous = end
    }
    return ends.enumerated().map { (index, end) in
        (chapterStart: index == 0 ? 1 : ends[index - 1] + 1, chapterEnd: end)
    }
}

/// 规范化阶段计划范围 — plotOutlineModel.ts:131-159
private func normalizeStagePlanRanges(_ stagePlan: [PlotOutlineStageDTO], totalChapters: Int) -> [PlotOutlineStageDTO] {
    let ranges = buildStageChapterRanges(totalChapters: totalChapters)
    return stagePlan.enumerated().map { (index, stage) in
        let meta = index < kStagePhaseMeta.count ? kStagePhaseMeta[index] : nil
        let fallback = index < ranges.count ? ranges[index] : (chapterStart: index + 1, chapterEnd: max(index + 1, totalChapters))
        let rawStart = stage.chapterStart
        let rawEnd = stage.chapterEnd
        let keepManualRange = rawStart != nil && rawEnd != nil && rawStart! <= rawEnd!
        var next = stage
        next.phase = meta?.phase ?? stage.phase
        if stage.label.isEmpty {
            next.label = meta?.label ?? ""
        }
        next.chapterStart = keepManualRange ? rawStart : fallback.chapterStart
        next.chapterEnd = keepManualRange ? rawEnd : fallback.chapterEnd
        let total = max(totalChapters, next.chapterEnd ?? 0)
        next.rangePercent = buildStageRangePercentLabel(next, totalChapters: total)
        if !next.rangePercent.isEmpty && !stage.rangePercent.isEmpty {
            next.rangePercent = stage.rangePercent
        }
        return next
    }
}

/// 解析标签段落 — plotOutlineModel.ts:161-179
private func parsePlotLabeledSections(_ text: String) -> [String: String] {
    let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else { return [:] }
    let labels = ["阶段任务", "冲突变化", "角色成长", "关键剧情节点", "关键剧情", "核心冲突", "预期结局"]
    // 简单按标签分割
    var fields: [String: String] = [:]
    var currentKey: String?
    var currentValue: String = ""
    for line in source.components(separatedBy: "\n") {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let matchedLabel = labels.first { label in
            trimmedLine.hasPrefix(label) && (trimmedLine.contains(":") || trimmedLine.contains("："))
        }
        if let label = matchedLabel {
            if let key = currentKey, !currentValue.isEmpty {
                fields[key] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            currentKey = label == "阶段任务" ? "summary" : label
            let afterLabel = trimmedLine.dropFirst(label.count)
            currentValue = afterLabel.trimmingCharacters(in: CharacterSet(charactersIn: "：: \t"))
        } else {
            currentValue += line + "\n"
        }
    }
    if let key = currentKey, !currentValue.isEmpty {
        fields[key] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return fields
}

/// 克隆剧情总纲 — plotOutlineModel.ts:181-197
func clonePlotOutline(_ outline: PlotOutlineDTO?, totalChapters: Int = 100) -> PlotOutlineDTO {
    guard let outline = outline else { return createEmptyPlotOutline() }
    let clonedStages = outline.stagePlan.map { stage -> PlotOutlineStageDTO in
        var s = stage
        let sections = parsePlotLabeledSections(s.summary)
        if let summaryFromSections = sections["summary"], !summaryFromSections.isEmpty {
            s.summary = summaryFromSections
        }
        if s.keyGoals == nil { s.keyGoals = [] }
        return s
    }
    return PlotOutlineDTO(
        mainStoryOverview: outline.mainStoryOverview,
        stagePlan: normalizeStagePlanRanges(clonedStages, totalChapters: totalChapters),
        expectedEnding: outline.expectedEnding,
        coreConflict: outline.coreConflict
    )
}

/// 获取顶层字段 key 列表 — plotOutlineModel.ts:199-207
func getPlotOutlineTopFieldKeys(_ outline: PlotOutlineDTO) -> [String] {
    let preferred = ["main_story_overview", "core_conflict", "expected_ending"]
    return preferred
}

/// 字段中文标签 — plotOutlineModel.ts:209-211
func plotFieldLabel(_ key: String) -> String {
    return kPlotFieldLabels[key] ?? key
}

/// 取字段文本 — plotOutlineModel.ts:213-221
func plotFieldText(_ target: [String: Any], key: String) -> String {
    let value = target[key]
    if value == nil { return "" }
    if let str = value as? String { return str }
    if let data = try? JSONSerialization.data(withJSONObject: value as Any, options: [.prettyPrinted, .fragmentsAllowed]),
       let str = String(data: data, encoding: .utf8) {
        return str
    }
    return "\(value ?? "")"
}

/// 更新字段值 — plotOutlineModel.ts:223-229
/// Swift 中 PlotOutlineDTO 是值类型，直接赋值即可，此函数保留用于兼容
func updatePlotField(_ target: inout [String: Any], key: String, value: String) {
    target[key] = value
}

/// 获取阶段内容字段 key 列表 — plotOutlineModel.ts:231-238
func stageContentFieldKeys(_ stage: PlotOutlineStageDTO) -> [String] {
    return ["summary"]
}

/// 构建阶段章节范围百分比标签 — plotOutlineModel.ts:240-251
func buildStageRangePercentLabel(_ stage: PlotOutlineStageDTO, totalChapters: Int) -> String {
    let total = max(1, totalChapters)
    let start = stage.chapterStart ?? 0
    let end = stage.chapterEnd ?? 0
    if start <= 0 || end <= 0 { return stage.rangePercent }
    let startPercent = max(1, min(100, Int((Double(start - 1) / Double(total)) * 100)))
    let endPercent = max(startPercent, min(100, Int((Double(end) / Double(total)) * 100)))
    return "\(startPercent)-\(endPercent)%"
}

/// 从编辑副本构建提交 payload — plotOutlineModel.ts:253-271
func buildEditablePlotOutlinePayload(_ editable: PlotOutlineDTO, totalChapters: Int) -> PlotOutlineDTO {
    return PlotOutlineDTO(
        mainStoryOverview: editable.mainStoryOverview.trimmingCharacters(in: .whitespacesAndNewlines),
        stagePlan: editable.stagePlan.map { stage in
            var s = stage
            s.summary = s.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            s.rangePercent = buildStageRangePercentLabel(s, totalChapters: totalChapters)
            if s.rangePercent.isEmpty { s.rangePercent = stage.rangePercent }
            s.keyGoals = (s.keyGoals ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return s
        },
        expectedEnding: editable.expectedEnding.trimmingCharacters(in: .whitespacesAndNewlines),
        coreConflict: editable.coreConflict.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

/// 校验编辑后的剧情总纲 — plotOutlineModel.ts:273-289
func validateEditablePlotOutline(_ outline: PlotOutlineDTO) -> String {
    let hasTopContent = !outline.mainStoryOverview.isEmpty || !outline.coreConflict.isEmpty || !outline.expectedEnding.isEmpty
    if !hasTopContent { return "请至少保留一项总纲内容" }
    if outline.stagePlan.isEmpty { return "请保留并填写阶段规划" }
    for stage in outline.stagePlan {
        guard let start = stage.chapterStart, let end = stage.chapterEnd, start >= 1, end >= 1, start <= end else {
            return "请检查\(stage.label)的起止章节"
        }
        if stage.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写\(stage.label)的规划内容"
        }
    }
    return ""
}

/// 从字典中取字符串 — plotOutlineModel.ts:291-299
private func pickPlotString(_ record: [String: Any], keys: [String]) -> String {
    for key in keys {
        if let value = record[key], let str = value as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return ""
}

/// 从字典中取值 — plotOutlineModel.ts:301-307
private func pickPlotValue(_ record: [String: Any], keys: [String]) -> Any? {
    for key in keys {
        if let value = record[key], !(value is NSNull) {
            return value
        }
    }
    return nil
}

/// 规范化旧版阶段计划 — plotOutlineModel.ts:309-331
private func normalizeLegacyStagePlan(_ stagePlan: Any?) -> [PlotOutlineStageDTO] {
    guard let dict = stagePlan as? [String: Any] else { return [] }
    return kLegacyStageKeyAliases.enumerated().compactMap { (index, aliases) -> PlotOutlineStageDTO? in
        let meta = kStagePhaseMeta[index]
        let value = aliases.compactMap { dict[$0] }.first { $0 != nil && !($0 is NSNull) }
        if let valueDict = value as? [String: Any] {
            var stage = PlotOutlineStageDTO()
            stage.phase = meta.phase
            stage.label = (valueDict["label"] as? String) ?? meta.label
            stage.rangePercent = (valueDict["range_percent"] as? String) ?? meta.rangePercent
            stage.summary = (valueDict["summary"] as? String) ?? ""
            stage.keyGoals = valueDict["key_goals"] as? [String]
            if let cs = valueDict["chapter_start"] as? Int { stage.chapterStart = cs }
            if let ce = valueDict["chapter_end"] as? Int { stage.chapterEnd = ce }
            return stage
        } else if let str = value as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PlotOutlineStageDTO(phase: meta.phase, label: meta.label, rangePercent: meta.rangePercent, summary: str)
        }
        return nil
    }
}

/// 规范化剧情总纲结构 — plotOutlineModel.ts:333-347
func normalizePlotOutlineShape(_ value: Any?, totalChapters: Int = 100) -> PlotOutlineDTO? {
    guard let value = value, let record = value as? [String: Any] else { return nil }
    let stagePlanValue = pickPlotValue(record, keys: kPlotStageKeys)
    let normalizedStagePlan: [PlotOutlineStageDTO]
    if let arr = stagePlanValue as? [[String: Any]] {
        let stages = arr.compactMap { dict -> PlotOutlineStageDTO? in
            var stage = PlotOutlineStageDTO()
            stage.phase = dict["phase"] as? String ?? ""
            stage.label = dict["label"] as? String ?? ""
            stage.rangePercent = dict["range_percent"] as? String ?? ""
            stage.chapterStart = dict["chapter_start"] as? Int
            stage.chapterEnd = dict["chapter_end"] as? Int
            stage.summary = dict["summary"] as? String ?? ""
            stage.keyGoals = dict["key_goals"] as? [String]
            return stage
        }
        normalizedStagePlan = stages
    } else {
        normalizedStagePlan = normalizeLegacyStagePlan(stagePlanValue)
    }
    return PlotOutlineDTO(
        mainStoryOverview: pickPlotString(record, keys: kPlotOverviewKeys),
        stagePlan: normalizeStagePlanRanges(normalizedStagePlan, totalChapters: totalChapters),
        expectedEnding: pickPlotString(record, keys: kPlotEndingKeys),
        coreConflict: pickPlotString(record, keys: kPlotConflictKeys)
    )
}

/// 从绑定中规范化剧情总纲 — plotOutlineModel.ts:349-368
func normalizePlotOutlineFromBindings(
    _ source: [String: Any],
    bindings: [InvocationVariableBinding],
    totalChapters: Int = 100
) -> PlotOutlineDTO? {
    let (byAlias, byVariableKey) = extractBoundOutputMaps(source, bindings: bindings)
    if let direct = byVariableKey["plot.outline"] {
        return normalizePlotOutlineShape(direct, totalChapters: totalChapters)
    }
    let stagePlan = byVariableKey["plot.stage_plan"]
    let overview = byVariableKey["plot.main_story_overview"]
    let ending = byVariableKey["plot.expected_ending"]
    let conflict = byVariableKey["plot.core_conflict"]
    if stagePlan == nil && overview == nil && ending == nil && conflict == nil { return nil }
    var record: [String: Any] = [:]
    if let overview = overview { record["main_story_overview"] = overview }
    if let ending = ending { record["expected_ending"] = ending }
    if let conflict = conflict { record["core_conflict"] = conflict }
    if let stagePlan = stagePlan { record["stage_plan"] = stagePlan }
    _ = byAlias // 按原版逻辑，byAlias 不用于此函数
    return normalizePlotOutlineShape(record, totalChapters: totalChapters)
}

/// 从审批结果中提取剧情总纲 — plotOutlineModel.ts:370-409
func extractPlotOutlineFromResult(
    _ result: [String: Any],
    outputBindings: [InvocationVariableBinding] = [],
    totalChapters: Int = 100
) -> PlotOutlineDTO? {
    // 1. 直接 plot_outline
    if let direct = result["plot_outline"] {
        if let outline = normalizePlotOutlineShape(direct, totalChapters: totalChapters) {
            return outline
        }
    }
    // 2. 通过 bindings 提取
    if !outputBindings.isEmpty {
        if let bound = normalizePlotOutlineFromBindings(result, bindings: outputBindings, totalChapters: totalChapters),
           !bound.stagePlan.isEmpty {
            return bound
        }
    }
    // 3. continuation
    if let continuation = result["continuation"] as? [String: Any] {
        if let fromContinuation = continuation["plot_outline"] {
            if let outline = normalizePlotOutlineShape(fromContinuation, totalChapters: totalChapters) {
                return outline
            }
        }
        if !outputBindings.isEmpty {
            if let boundContinuation = normalizePlotOutlineFromBindings(continuation, bindings: outputBindings, totalChapters: totalChapters),
               !boundContinuation.stagePlan.isEmpty {
                return boundContinuation
            }
        }
        if let normalizedContinuation = normalizePlotOutlineShape(continuation, totalChapters: totalChapters),
           !normalizedContinuation.mainStoryOverview.isEmpty, !normalizedContinuation.stagePlan.isEmpty {
            return normalizedContinuation
        }
    }
    // 4. accepted_content
    if let acceptedContent = result["accepted_content"] as? String, !acceptedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        if let parsedRecord = parseJsonLikeRecord(acceptedContent) {
            if !outputBindings.isEmpty {
                if let boundAccepted = normalizePlotOutlineFromBindings(parsedRecord, bindings: outputBindings, totalChapters: totalChapters),
                   !boundAccepted.stagePlan.isEmpty {
                    return boundAccepted
                }
            }
            if let fromParsed = parsedRecord["plot_outline"] {
                if let outline = normalizePlotOutlineShape(fromParsed, totalChapters: totalChapters) {
                    return outline
                }
            }
            if let normalizedAccepted = normalizePlotOutlineShape(parsedRecord, totalChapters: totalChapters),
               !normalizedAccepted.mainStoryOverview.isEmpty, !normalizedAccepted.stagePlan.isEmpty {
                return normalizedAccepted
            }
        }
    }
    return nil
}
