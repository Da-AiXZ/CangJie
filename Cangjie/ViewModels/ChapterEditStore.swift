//
//  ChapterEditStore.swift
//  Cangjie
//
//  P0-3 独立章节编辑页状态管理。
//  对齐原版 views/Chapter.vue（648 行）的完整状态与动作。
//
//  技术约定：
//  - ObservableObject + @Published（iOS 16+ 兼容，禁用 @Observable 宏）
//  - 日期解码用 CangjieDecoder.shared
//  - APIEndpoint.defaultPrefix = /api/v1
//  - 并行加载 4 个请求（对齐 Chapter.vue L496-501 Promise.allSettled）
//

import Foundation
import SwiftUI
import Combine

// MARK: - 保存状态枚举

/// 章节保存状态，对齐 Chapter.vue L289 saveStatus
enum ChapterSaveStatus: String, Equatable {
    case unsaved = "unsaved"
    case saving = "saving"
    case saved = "saved"

    /// 显示文本，对齐 Chapter.vue L336-339 saveStatusText
    var displayText: String {
        switch self {
        case .unsaved: return "未保存"
        case .saving: return "保存中…"
        case .saved: return "已保存"
        }
    }
}

// MARK: - 审定状态枚举

/// 审定状态（旧 API 值），对齐 Chapter.vue L230-246
/// old(pending/ok/revise) ↔ new(draft/approved/reviewed)
enum ChapterReviewStatus: String, CaseIterable, Equatable {
    case pending = "pending"
    case ok = "ok"
    case revise = "revise"

    /// 显示文本
    var displayText: String {
        switch self {
        case .pending: return "待阅"
        case .ok: return "已定稿"
        case .revise: return "需修订"
        }
    }

    /// 转换为新 API 状态值，对齐 Chapter.vue L230-237 statusToNew
    var newStatus: String {
        switch self {
        case .pending: return "draft"
        case .ok: return "approved"
        case .revise: return "reviewed"
        }
    }

    /// 从新 API 状态值创建，对齐 Chapter.vue L239-246 statusToOld
    static func from(newStatus: String) -> ChapterReviewStatus {
        switch newStatus {
        case "approved": return .ok
        case "reviewed": return .revise
        default: return .pending
        }
    }
}

// MARK: - ChapterEditStore

/// 独立章节编辑页状态管理，对齐原版 views/Chapter.vue
///
/// 管理 7 个功能模块状态：
/// 1. 正文编辑 + 自动保存
/// 2. 审定 Tab（状态/批注/AI审读）
/// 3. 推断证据 Tab（加载/撤销）
/// 4. 信息 Tab（统计/结构分析/时间）
/// 5. Markdown 预览（debounce 300ms）
/// 6. 上一章/下一章导航
/// 7. 工具下拉（复制全文/清空正文）
@MainActor
final class ChapterEditStore: ObservableObject {

    // MARK: - 依赖

    private let apiClient: APIClient

    // MARK: - 基础信息

    /// 小说 ID
    let novelId: String

    /// 当前章节编号
    @Published var chapterNumber: Int

    // MARK: - 正文编辑状态

    /// 章节正文内容
    @Published var chapterContent: String = ""

    /// 保存状态，对齐 Chapter.vue L289 saveStatus
    @Published var saveStatus: ChapterSaveStatus = .saved

    /// 是否正在保存
    @Published var isSaving: Bool = false

    /// 上次保存时间显示文本，对齐 Chapter.vue L290 lastSaveTime
    @Published var lastSaveTime: String = ""

    /// 页面加载中
    @Published var pageLoading: Bool = true

    /// 错误消息
    @Published var errorMessage: String?

    // MARK: - Markdown 预览状态

    /// 是否显示预览，对齐 Chapter.vue L304 showPreview
    @Published var showPreview: Bool = false

    /// 预览渲染后的 AttributedString（iOS 系统方案，Q5 决策）
    @Published var previewAttributed: AttributedString?

    // MARK: - 审定状态

    /// 审定状态（旧 API 值），对齐 Chapter.vue L292 reviewStatus
    @Published var reviewStatus: ChapterReviewStatus = .pending

    /// 审定批注，对齐 Chapter.vue L293 reviewMemo
    @Published var reviewMemo: String = ""

    /// 正在保存审定
    @Published var isSavingReview: Bool = false

    /// 正在 AI 审读
    @Published var isAiReviewing: Bool = false

    // MARK: - 推断证据状态

    /// 推断事实列表，对齐 Chapter.vue L255 inferenceFacts
    @Published var inferenceFacts: [InferenceFactBundle] = []

    /// 推断证据加载中，对齐 Chapter.vue L254 inferenceLoading
    @Published var inferenceLoading: Bool = false

    /// 推断提示文本，对齐 Chapter.vue L256 inferenceHint
    @Published var inferenceHint: String = ""

    /// 推断提示标题，对齐 Chapter.vue L257 inferenceHintTitle
    @Published var inferenceHintTitle: String = "提示"

    /// 故事节点 ID，对齐 Chapter.vue L258 storyNodeId
    @Published var storyNodeId: String?

    /// 正在撤销全部推断
    @Published var isRevokingAll: Bool = false

    /// 正在撤销的单条推断 ID，对齐 Chapter.vue L260 revokingId
    @Published var revokingId: String?

    // MARK: - 信息 Tab 状态

    /// 章节结构分析，对齐 Chapter.vue L296-302 chapterStructure
    @Published var chapterStructure: ChapterStructureAnalysis?

    /// 创建时间显示文本，对齐 Chapter.vue L358 createTime
    @Published var createTime: String = "—"

    /// 修改时间显示文本，对齐 Chapter.vue L359 updateTime
    @Published var updateTime: String = "—"

    // MARK: - 章节导航状态

    /// 章节编号列表（排序后），对齐 Chapter.vue L305 chapterIds
    @Published var chapterIds: [Int] = []

    /// 是否显示章节列表（预留）
    @Published var showChapterList: Bool = false

    // MARK: - Debounce 任务

    /// Markdown 预览 debounce 任务（300ms）
    private var previewDebounceTask: Task<Void, Never>?

    /// 自动保存 debounce 任务（30s）
    private var autosaveDebounceTask: Task<Void, Never>?

    /// 预览 debounce 间隔（纳秒），300ms
    private let previewDebounceNs: UInt64 = 300_000_000

    /// 自动保存 debounce 间隔（纳秒），30s
    private let autosaveDebounceNs: UInt64 = 30_000_000_000

    // MARK: - 初始化

    /// 初始化 ChapterEditStore
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节编号
    ///   - apiClient: API 客户端（默认 .shared）
    init(novelId: String, chapterNumber: Int, apiClient: APIClient = .shared) {
        self.novelId = novelId
        self.chapterNumber = chapterNumber
        self.apiClient = apiClient
    }

    // MARK: - 计算属性

    /// 字数（去空白字符），对齐 Chapter.vue L308 wordCount
    var wordCount: Int {
        chapterContent.filter { !$0.isWhitespace }.count
    }

    /// 行数，对齐 Chapter.vue L309 lineCount
    var lineCount: Int {
        chapterContent.isEmpty ? 0 : chapterContent.components(separatedBy: "\n").count
    }

    /// 段落数，对齐 Chapter.vue L310-312 paragraphCount
    /// `content.split(/\n\s*\n/).filter(p => p.trim()).length`
    var paragraphCount: Int {
        guard !chapterContent.isEmpty else { return 0 }
        // 对齐原版正则 /\n\s*\n/ — 空行分段
        // 先规范化 \n\s*\n 为 \n\n，再按 \n\n 分段
        let normalized = chapterContent.replacingOccurrences(
            of: "\\n\\s*\\n",
            with: "\n\n",
            options: .regularExpression
        )
        return normalized
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    /// 当前章节在 chapterIds 中的索引，对齐 Chapter.vue L343-346 currentChapterIndex
    var currentChapterIndex: Int {
        chapterIds.firstIndex(of: chapterNumber) ?? -1
    }

    /// 是否可以上一章，对齐 Chapter.vue L348-351 canPrev
    var canPrev: Bool {
        currentChapterIndex > 0
    }

    /// 是否可以下一章，对齐 Chapter.vue L353-356 canNext
    var canNext: Bool {
        let i = currentChapterIndex
        return i >= 0 && i < chapterIds.count - 1
    }

    /// 内容是否有未保存更改，对齐 Chapter.vue L341 contentDirty
    var contentDirty: Bool {
        saveStatus == .unsaved
    }

    // MARK: - 页面加载

    /// 加载章节数据，对齐 Chapter.vue L489-543 loadChapter
    ///
    /// 并行加载 4 个请求（章节列表 + 章节数据 + 审定 + 结构），
    /// 对齐 Chapter.vue L496-501 Promise.allSettled。
    /// 加载完成后调用 loadInferenceEvidence。
    func loadChapter() async {
        pageLoading = true
        errorMessage = nil

        // 并行加载 4 个请求，对齐 Chapter.vue L496-501 Promise.allSettled
        // 使用 async let 实现并行加载
        async let chaptersListResult = loadChapterList()
        async let chapterDataResult = loadChapterData()
        async let reviewResult = loadReview()
        async let structureResult = loadStructure()

        let (chaptersList, chapterData, review, structure) = await (chaptersListResult, chapterDataResult, reviewResult, structureResult)

        // 处理章节列表结果，对齐 Chapter.vue L503-507
        if let chapters = chaptersList {
            chapterIds = chapters.map { $0.number }.sorted()
        }

        // 处理章节数据结果，对齐 Chapter.vue L510-519
        if let chapter = chapterData {
            chapterContent = chapter.content
            if !chapter.createdAt.isEmpty {
                createTime = Self.formatDateTime(chapter.createdAt)
            }
            if !chapter.updatedAt.isEmpty {
                updateTime = Self.formatDateTime(chapter.updatedAt)
            }
            updatePreview(immediate: true)
        }

        // 处理审定结果，对齐 Chapter.vue L522-525
        if let rev = review {
            reviewStatus = ChapterReviewStatus.from(newStatus: rev.status)
            reviewMemo = rev.memo
        }

        // 处理结构分析结果，对齐 Chapter.vue L528-539
        if let struct_ = structure {
            chapterStructure = struct_
        } else {
            chapterStructure = nil
        }

        saveStatus = .saved

        // 加载推断证据，对齐 Chapter.vue L542
        await loadInferenceEvidence()

        pageLoading = false
    }

    // MARK: - 并行加载子方法

    /// 加载章节列表，对齐 chapterApi.listChapters
    private func loadChapterList() async -> [ChapterDTO]? {
        do {
            let chapters: [ChapterDTO] = try await apiClient.request(
                APIEndpoint.Chapters.list(novelId: novelId)
            )
            return chapters
        } catch {
            Logger.data.error("加载章节列表失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 加载章节数据，对齐 chapterApi.getChapter
    private func loadChapterData() async -> ChapterDTO? {
        do {
            let chapter: ChapterDTO = try await apiClient.request(
                APIEndpoint.Chapters.get(novelId: novelId, chapterNumber: chapterNumber)
            )
            return chapter
        } catch {
            Logger.data.error("加载章节数据失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 加载审定数据，对齐 chapterApi.getChapterReview
    private func loadReview() async -> ChapterReviewResponse? {
        do {
            let review: ChapterReviewResponse = try await apiClient.request(
                APIEndpoint.Chapters.getReview(novelId: novelId, chapterNumber: chapterNumber)
            )
            return review
        } catch {
            Logger.data.error("加载审定数据失败: \(error.localizedDescription)")
            return nil
        }
    }

    /// 加载结构分析，对齐 chapterApi.getChapterStructure
    private func loadStructure() async -> ChapterStructureAnalysis? {
        do {
            let structure: ChapterStructureAnalysis = try await apiClient.request(
                APIEndpoint.Chapters.structure(novelId: novelId, chapterNumber: chapterNumber)
            )
            return structure
        } catch {
            Logger.data.error("加载结构分析失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 推断证据

    /// 加载推断证据，对齐 Chapter.vue L545-574 loadInferenceEvidence
    func loadInferenceEvidence() async {
        inferenceLoading = true
        inferenceHint = ""

        do {
            let response: InferenceEvidenceAPIResponse = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.inferenceEvidence(novelId: novelId, chapterNumber: chapterNumber)
            )
            let d = response.data
            storyNodeId = d.storyNodeId
            inferenceFacts = d.facts

            if d.storyNodeId != nil {
                inferenceHint = ""
            }
            if let hint = d.hint, !hint.isEmpty {
                inferenceHintTitle = "无结构节点"
                inferenceHint = hint
            } else if d.storyNodeId == nil {
                inferenceHintTitle = "无结构节点"
                inferenceHint = "未匹配到故事结构中的章节节点，推断证据为空。"
            }
        } catch {
            Logger.data.error("加载推断证据失败: \(error.localizedDescription)")
            inferenceHintTitle = "加载失败"
            inferenceHint = "无法加载推断证据（请确认后端与 SQLite 可用）。"
            inferenceFacts = []
            storyNodeId = nil
        }

        inferenceLoading = false
    }

    /// 撤销单条推断，对齐 Chapter.vue L576-596 revokeOneInference
    /// - Parameter tripleId: 三元组 ID
    func revokeOneInference(tripleId: String) async {
        revokingId = tripleId

        do {
            let _: DeleteInferredTripleResponse = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.deleteInferredTriple(novelId: novelId, tripleId: tripleId)
            )
            await loadInferenceEvidence()
        } catch {
            errorMessage = "撤销失败：\(error.localizedDescription)"
            Logger.data.error("撤销单条推断失败: \(error.localizedDescription)")
        }

        revokingId = nil
    }

    /// 撤销本章全部推断，对齐 Chapter.vue L598-613 revokeAllInference
    func revokeAllInference() async {
        isRevokingAll = true

        do {
            let response: RevokeInferenceResponse = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.deleteChapterInference(novelId: novelId, chapterNumber: chapterNumber)
            )
            let deleted = response.data.deletedInferredFacts
            let removed = response.data.removedProvenanceTriples
            errorMessage = nil
            // 对齐 Chapter.vue L604-606 消息文本
            Logger.data.info("已处理：删除 \(deleted) 条推断三元组（涉及 \(removed) 条证据关联）")
            await loadInferenceEvidence()
        } catch {
            errorMessage = "撤销失败：\(error.localizedDescription)"
            Logger.data.error("撤销全部推断失败: \(error.localizedDescription)")
        }

        isRevokingAll = false
    }

    // MARK: - 保存正文

    /// 保存章节内容，对齐 Chapter.vue L380-404 saveContent
    /// - Parameter fromAutosave: 是否来自自动保存
    func saveContent(fromAutosave: Bool = false) async {
        guard !isSaving else { return }
        if fromAutosave && saveStatus == .saved { return }

        isSaving = true
        saveStatus = .saving

        do {
            let _: ChapterDTO = try await apiClient.request(
                APIEndpoint.Chapters.update(novelId: novelId, chapterNumber: chapterNumber),
                body: UpdateChapterContentRequest(content: chapterContent)
            )
            saveStatus = .saved
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "HH:mm:ss"
            lastSaveTime = formatter.string(from: Date())
            updateTime = Self.formatNow()
            Logger.data.info("章节保存成功: 第\(chapterNumber)章")
        } catch {
            Logger.data.error("保存章节失败: \(error.localizedDescription)")
            saveStatus = .unsaved
            errorMessage = "保存失败，请稍后重试"
        }

        isSaving = false
    }

    // MARK: - 保存审定

    /// 保存审定，对齐 Chapter.vue L422-438 saveReview
    func saveReview() async {
        isSavingReview = true

        do {
            let newStatus = reviewStatus.newStatus
            let _: ChapterReviewResponse = try await apiClient.request(
                APIEndpoint.Chapters.saveReview(novelId: novelId, chapterNumber: chapterNumber),
                body: SaveChapterReviewRequest(status: newStatus, memo: reviewMemo)
            )
            errorMessage = nil
            Logger.data.info("审定已保存: 第\(chapterNumber)章")
        } catch {
            Logger.data.error("保存审定失败: \(error.localizedDescription)")
            errorMessage = "保存失败，请稍后重试"
        }

        isSavingReview = false
    }

    // MARK: - AI 审读

    /// 生成 AI 审读意见，对齐 Chapter.vue L440-454 runAiReview
    /// - Parameter save: 是否同时写入审定
    func runAiReview(save: Bool) async {
        isAiReviewing = true

        do {
            let r: ChapterAIReviewResponse = try await apiClient.request(
                APIEndpoint.Chapters.aiReview(novelId: novelId, chapterNumber: chapterNumber),
                body: ChapterAIReviewRequest(save: save)
            )
            reviewStatus = ChapterReviewStatus.from(newStatus: r.status)
            reviewMemo = r.memo
            errorMessage = nil
            Logger.data.info("AI 审读完成: save=\(save)")
        } catch {
            Logger.data.error("AI 审读失败: \(error.localizedDescription)")
            errorMessage = "生成失败：\(error.localizedDescription)"
        }

        isAiReviewing = false
    }

    // MARK: - 输入处理

    /// 正文输入回调，对齐 Chapter.vue L416-420 onInput
    ///
    /// 标记为未保存 + 调度自动保存 + 调度预览更新
    func onContentInput() {
        saveStatus = .unsaved
        scheduleAutosave()
        schedulePreviewDebounce()
    }

    // MARK: - 工具操作

    /// 复制全文到剪贴板，对齐 Chapter.vue L367-371 handleToolSelect 'copy'
    func copyAllText() {
        UIPasteboard.general.string = chapterContent
    }

    /// 清空正文，对齐 Chapter.vue L373-377 handleToolSelect 'clear'
    func clearContent() {
        chapterContent = ""
        onContentInput()
        updatePreview(immediate: true)
    }

    // MARK: - 章节导航

    /// 上一章，对齐 Chapter.vue L470-473 prevChapter
    /// - Returns: 上一章的章节编号，如果无法导航则返回 nil
    func prevChapterNumber() -> Int? {
        let i = currentChapterIndex
        guard i > 0 else { return nil }
        return chapterIds[i - 1]
    }

    /// 下一章，对齐 Chapter.vue L475-480 nextChapter
    /// - Returns: 下一章的章节编号，如果无法导航则返回 nil
    func nextChapterNumber() -> Int? {
        let i = currentChapterIndex
        guard i >= 0 && i < chapterIds.count - 1 else { return nil }
        return chapterIds[i + 1]
    }

    /// 切换到指定章节编号，对齐 Chapter.vue L615-631 watch route.params.id
    func switchToChapter(_ newChapterNumber: Int) async {
        // 取消 debounce 任务
        cancelDebounceTasks()

        chapterNumber = newChapterNumber
        chapterContent = ""
        saveStatus = .saved
        previewAttributed = nil
        reviewStatus = .pending
        reviewMemo = ""
        inferenceFacts = []
        chapterStructure = nil
        createTime = "—"
        updateTime = "—"
        lastSaveTime = ""
        storyNodeId = nil
        inferenceHint = ""

        await loadChapter()
    }

    // MARK: - Markdown 预览

    /// 更新预览，对齐 Chapter.vue L327-334 updatePreview
    /// - Parameter immediate: 是否立即更新（false = debounce 300ms）
    func updatePreview(immediate: Bool = false) {
        if immediate {
            previewDebounceTask?.cancel()
            parseMarkdownPreview()
        } else {
            schedulePreviewDebounce()
        }
    }

    /// 解析 Markdown 预览，对齐 Chapter.vue L316-320 parseMarkdown
    ///
    /// 使用 AttributedString(markdown:options:) 系统方案渲染（Q5 决策）。
    private func parseMarkdownPreview() {
        guard !chapterContent.isEmpty else {
            previewAttributed = nil
            return
        }

        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .full
            options.failurePolicy = .returnPartiallyParsedIfPossible
            options.allowsExtendedAttributes = true
            previewAttributed = try AttributedString(markdown: chapterContent, options: options)
        } catch {
            // 降级：用纯文本
            previewAttributed = AttributedString(chapterContent)
        }
    }

    // MARK: - Debounce 调度

    /// 调度预览 debounce（300ms），对齐 Chapter.vue L322-325 previewTask
    private func schedulePreviewDebounce() {
        previewDebounceTask?.cancel()
        previewDebounceTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: self.previewDebounceNs)
            guard !Task.isCancelled else { return }
            self.parseMarkdownPreview()
        }
    }

    /// 调度自动保存 debounce（30s），对齐 Chapter.vue L406-414 autosaveTask
    private func scheduleAutosave() {
        autosaveDebounceTask?.cancel()
        autosaveDebounceTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: self.autosaveDebounceNs)
            guard !Task.isCancelled else { return }
            await self.saveContent(fromAutosave: true)
        }
    }

    /// 取消所有 debounce 任务
    func cancelDebounceTasks() {
        previewDebounceTask?.cancel()
        autosaveDebounceTask?.cancel()
    }

    // MARK: - 日期格式化

    /// 将 ISO 日期字符串格式化为本地化显示文本
    /// 对齐 Chapter.vue L513-514 `new Date(created_at).toLocaleString('zh-CN', { hour12: false })`
    private static func formatDateTime(_ isoString: String) -> String {
        // 尝试用 CangjieDecoder 的日期解析器解析
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "zh_CN")
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return displayFormatter.string(from: date)
        }

        // 降级：尝试不带毫秒
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let date = fallback.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.locale = Locale(identifier: "zh_CN")
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return displayFormatter.string(from: date)
        }

        return isoString
    }

    /// 格式化当前时间
    private static func formatNow() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
