//
//  NarrativeDashboardStore.swift
//  Cangjie
//
//  叙事仪表盘 Store，对齐原版 NarrativeDashboardPanel.vue:434-455。
//  4路并行加载（storyEvolution + foreshadow + characterPsyches + bible）。
//

import SwiftUI
import Foundation

/// 叙事仪表盘 Store — NarrativeDashboardPanel.vue:296-451
@MainActor
final class NarrativeDashboardStore: ObservableObject {

    // MARK: - Published 状态 — NarrativeDashboardPanel.vue:296-300

    @Published var loading: Bool = false
    @Published var storyEvolution: StoryEvolutionReadModel?
    @Published var pendingForeshadows: [ForeshadowEntry] = []
    @Published var psyches: [CharacterPsyche] = []
    @Published var bibleChars: [CharacterDTO] = []
    @Published var errorMessage: String?

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 4路并行加载 — NarrativeDashboardPanel.vue:434-451

    /// 加载全部数据 — Promise.allSettled([getStoryEvolution, foreshadowApi.list, characterPsycheApi.list, bibleApi.getBible])
    func load(slug: String) async {
        guard !slug.isEmpty else { return }
        loading = true
        errorMessage = nil

        // 4路并行 — Promise.allSettled 等价
        async let evoResult: StoryEvolutionReadModel? = loadStoryEvolution(novelId: slug)
        async let foreshadowResult: [ForeshadowEntry] = loadPendingForeshadows(novelId: slug)
        async let psychesResult: [CharacterPsyche] = loadCharacterPsyches(novelId: slug)
        async let bibleResult: [CharacterDTO] = loadBibleCharacters(novelId: slug)

        let (evo, fs, ps, bible) = await (evoResult, foreshadowResult, psychesResult, bibleResult)
        self.storyEvolution = evo
        self.pendingForeshadows = fs
        self.psyches = ps
        self.bibleChars = bible

        loading = false
    }

    // MARK: - 单路加载

    /// 加载故事演化 — narrativeEngineApi.getStoryEvolution
    private func loadStoryEvolution(novelId: String) async -> StoryEvolutionReadModel? {
        do {
            return try await apiClient.request(
                APIEndpoint.NarrativeEngine.storyEvolution(novelId: novelId)
            )
        } catch {
            Logger.data.error("NarrativeDashboard: 加载故事演化失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 加载待处理伏笔 — foreshadowApi.list(slug, 'pending')
    /// 决策#11: Store层filter（ForeshadowStore.pendingEntries已实现filter逻辑）
    private func loadPendingForeshadows(novelId: String) async -> [ForeshadowEntry] {
        do {
            let allEntries: [ForeshadowEntry] = try await apiClient.request(
                APIEndpoint.Foreshadow.list(novelId: novelId)
            )
            return allEntries.filter { $0.status == "pending" }
        } catch {
            Logger.data.error("NarrativeDashboard: 加载伏笔失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 加载角色心理 — characterPsycheApi.list(slug) → psyches.characters
    private func loadCharacterPsyches(novelId: String) async -> [CharacterPsyche] {
        do {
            let response: CharacterPsycheListResponse = try await apiClient.request(
                APIEndpoint.Checkpoints.characterPsyches(novelId: novelId)
            )
            return response.characters
        } catch {
            Logger.data.error("NarrativeDashboard: 加载角色心理失败: \(error.localizedDescription)")
            return []
        }
    }

    /// 加载Bible角色 — bibleApi.getBible(slug) → bibleChars.characters
    private func loadBibleCharacters(novelId: String) async -> [CharacterDTO] {
        do {
            let bible: BibleDTO = try await apiClient.request(
                APIEndpoint.Bible.get(novelId: novelId)
            )
            return bible.characters
        } catch {
            Logger.data.error("NarrativeDashboard: 加载Bible失败: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - 便捷属性

    /// 阶段 — NarrativeDashboardPanel.vue:306
    var phase: String {
        storyEvolution?.lifeCycle?.phase ?? ""
    }

    /// 标准化阶段 — NarrativeDashboardPanel.vue:307
    var currentPhase: String {
        normalizeStoryPhase(phase)
    }

    /// 进度百分比 — NarrativeDashboardPanel.vue:309-312
    var progressPct: Int {
        let p = storyEvolution?.lifeCycle?.progress ?? 0
        return Int(p.rounded())
    }

    /// 最大章节数 — NarrativeDashboardPanel.vue:314
    var maxChapter: Int {
        storyEvolution?.chronotope?.maxChapterInBook ?? 0
    }

    /// 所有故事线
    var allStorylines: [StorylineDTO] {
        storyEvolution?.plotSpine?.storylines ?? []
    }

    /// 活跃故事线（按章节过滤）— NarrativeDashboardPanel.vue:327-340
    func activeStorylines(currentChapterNumber: Int) -> [StorylineDTO] {
        let all = allStorylines
        if currentChapterNumber == 0 {
            return Array(all.prefix(5))
        }
        return all.filter { sl in
            let start = sl.estimatedChapterStart ?? 0
            let end = sl.estimatedChapterEnd ?? 0
            let inRange = start <= currentChapterNumber && (end == 0 || currentChapterNumber <= end)
            let notDone = sl.status != "completed" && sl.status != "cancelled"
            return inRange && notDone
        }
        .prefix(5)
        .map { $0 }
    }

    /// 紧急伏笔（前5条）— NarrativeDashboardPanel.vue:342-351
    var urgentForeshadows: [ForeshadowEntry] {
        pendingForeshadows
            .sorted { a, b in
                let ca = a.suggestedResolveChapter ?? 9999
                let cb = b.suggestedResolveChapter ?? 9999
                return ca < cb
            }
            .prefix(5)
            .map { $0 }
    }

    /// 是否有紧急承诺 — NarrativeDashboardPanel.vue:353-355
    /// - Parameter currentChapterNumber: 当前章节号（原版用 props.currentChapter?.number ?? 0）
    func hasCriticalPromise(currentChapterNumber: Int) -> Bool {
        urgentForeshadows.contains { foreshadowUrgencyClass($0, currentChapterNumber: currentChapterNumber) == .danger }
    }

    /// 紧急伏笔计数 — NarrativeDashboardPanel.vue:357-359
    /// - Parameter currentChapterNumber: 当前章节号（原版用 props.currentChapter?.number ?? 0）
    func urgentCount(currentChapterNumber: Int) -> Int {
        pendingForeshadows.filter { foreshadowUrgencyClass($0, currentChapterNumber: currentChapterNumber) == .danger }.count
    }

    /// 是否有主线 — NarrativeDashboardPanel.vue:361-363
    var hasMainStoryline: Bool {
        allStorylines.contains { isMainStoryline($0) }
    }

    /// 主要角色（按角色排序，前5）— NarrativeDashboardPanel.vue:365-369
    var mainCharacters: [CharacterPsyche] {
        psyches
            .sorted { getCharacterRoleSortOrder($0.role) < getCharacterRoleSortOrder($1.role) }
            .prefix(5)
            .map { $0 }
    }

    /// Bible角色映射 — NarrativeDashboardPanel.vue:371-375
    var bibleCharMap: [String: CharacterDTO] {
        var m: [String: CharacterDTO] = [:]
        for c in bibleChars { m[c.name] = c }
        return m
    }

    /// 角色心理状态 — NarrativeDashboardPanel.vue:378-384
    func characterMentalState(name: String) -> String {
        guard let c = bibleCharMap[name] else { return "" }
        let ms = c.mentalState.trimmingCharacters(in: .whitespacesAndNewlines)
        if ms.isEmpty || ms.uppercased() == "NORMAL" { return "" }
        return ms
    }
}

// MARK: - 伏笔紧急度 — NarrativeDashboardPanel.vue:410-421

/// 伏笔紧急度分级
enum ForeshadowUrgency: String {
    case danger, warning, muted
}

/// 计算伏笔紧急度 — NarrativeDashboardPanel.vue:410-421
func foreshadowUrgencyClass(_ entry: ForeshadowEntry, currentChapterNumber: Int) -> ForeshadowUrgency {
    if entry.importance == "critical" { return .danger }
    let due = entry.suggestedResolveChapter
    if let due = due, currentChapterNumber > 0 {
        let remaining = due - currentChapterNumber
        if remaining <= 3 { return .danger }
        if remaining <= 10 { return .warning }
    }
    if entry.importance == "high" { return .warning }
    return .muted
}
