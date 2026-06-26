//
//  WorkbenchStore.swift
//  Cangjie
//
//  工作台状态：当前章节正文/编辑/保存/章节元素/上下文装配。
//

import SwiftUI
import Foundation

/// 工作台 Store，管理章节编辑、保存、审阅等。
@MainActor
final class WorkbenchStore: ObservableObject {

    // MARK: - 跨面板刷新通知（对齐原版 workbenchRefreshStore 的 tick 机制）

    /// 刷新通知名 — 对齐原版 foreshadowTick/deskTick/chroniclesTick
    static let foreshadowTickNotification = Notification.Name("WorkbenchForeshadowTick")
    static let deskTickNotification = Notification.Name("WorkbenchDeskTick")
    static let chroniclesTickNotification = Notification.Name("WorkbenchChroniclesTick")

    /// 发布伏笔刷新通知
    func bumpForeshadowTick() {
        NotificationCenter.default.post(name: Self.foreshadowTickNotification, object: nil)
    }

    /// 发布工作台刷新通知
    func bumpDeskTick() {
        NotificationCenter.default.post(name: Self.deskTickNotification, object: nil)
    }

    /// 发布编年史刷新通知
    func bumpChroniclesTick() {
        NotificationCenter.default.post(name: Self.chroniclesTickNotification, object: nil)
    }

    // MARK: - 状态

    /// 当前编辑的章节内容
    @Published var chapterContent: String = ""

    /// 编辑前的原始内容（用于判断是否有改动）
    @Published var originalContent: String = ""

    /// 章节生成约束
    @Published var generationHint: String = ""

    /// 是否有未保存的修改
    @Published var hasUnsavedChanges: Bool = false

    /// 是否正在保存
    @Published var isSaving: Bool = false

    /// 是否正在生成
    @Published var isGenerating: Bool = false

    /// 章节审阅信息
    @Published var review: ChapterReviewResponse?

    /// 章节结构分析
    @Published var structure: ChapterStructureResponse?

    /// AI 审阅结果
    @Published var aiReviewResult: ChapterAIReviewResponse?

    /// 章节草稿列表
    @Published var drafts: [ChapterDraftResponse] = []

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - M5 单章生成 SSE 状态字段（workflow.ts:375-511）

    /// 当前生成阶段（phase 事件值：planning/context/script/prose/outline_planning/llm/post）
    @Published var generateChapterPhase: String?

    /// 生成中流式正文内容（chunk 事件实时追加）
    @Published var generateChapterContent: String = ""

    /// 生成完成的一致性报告（done 事件）
    @Published var generateChapterConsistencyReport: ConsistencyReportDTO?

    /// 生成完成的一致性报告样式警告（done 事件）
    @Published var generateChapterStyleWarnings: [StyleWarning]?

    /// 生成完成的节拍列表（beats_generated / done 事件）
    @Published var generateChapterBeats: [StreamGeneratedBeat]?

    /// 是否正在生成章节
    @Published var isGeneratingChapter: Bool = false

    /// 【返工M5】当前生成的小说ID（用于 approval_required/error/done 时显式 cancel SSE）
    /// 原版 workflow.ts:446,489 在这些事件中 return true 终止流，iOS 需显式调用 cancel
    private var currentGenerateNovelId: String?

    /// 阶段3：AI Invocation Store（审批面板）
    /// 用于单章生成 approval_required 事件接线
    @Published var aiInvocationStore: AIInvocationStore = AIInvocationStore()

    // MARK: - P0-2 生成弹窗状态字段（对齐 WorkArea.vue L955-1126）

    /// 生成弹窗是否显示
    @Published var showGenerateModal: Bool = false

    /// 目标章节 ID（弹窗内选择）
    @Published var generateTargetChapterId: String? = nil

    /// 大纲输入
    @Published var generateOutline: String = ""

    /// 生成的正文内容（弹窗内）
    @Published var generatedContent: String = ""

    /// 是否正在生成中（弹窗内）
    @Published var generateInProgress: Bool = false

    /// 场记分析开关（useSceneDirector）
    @Published var useSceneDirector: Bool = false

    /// 场记分析中
    @Published var analyzingScene: Bool = false

    /// 场记分析错误
    @Published var sceneDirectorError: String = ""

    /// 大纲失焦预分析中（outlineBlurAnalyzing）
    @Published var outlineBlurAnalyzing: Bool = false

    /// 大纲失焦预分析缓存（blurSceneCache）
    @Published var blurSceneCache: AnyCodable?

    /// LLM 配置档案 ID（generateProfileId）
    @Published var generateProfileId: String? = nil

    /// LLM 配置档案列表加载中
    @Published var llmProfilesLoading: Bool = false

    /// LLM 配置档案列表
    @Published var llmProfiles: [LLMProfile] = []

    /// 是否使用自定义剧本提示词模板
    @Published var useCustomScriptPrompt: Bool = false

    /// 自定义剧本提示词模板
    @Published var customScriptTemplate: String = ""

    /// 剧本提示词变量键值对
    @Published var scriptPromptVarPairs: [PromptVarPair] = []

    /// 是否使用自定义正文提示词模板
    @Published var useCustomProsePrompt: Bool = false

    /// 自定义正文提示词模板
    @Published var customProseTemplate: String = ""

    /// 正文提示词变量键值对
    @Published var prosePromptVarPairs: [PromptVarPair] = []

    /// 上下文预览结果
    @Published var contextPreview: ContextPreviewResult? = nil

    /// 上下文预览加载中
    @Published var loadingContext: Bool = false

    /// SSE 实时日志（generateSseLog）
    @Published var generateSseLog: [GenerateStreamLogLine] = []

    /// 流式进度百分比
    @Published var streamProgressPct: Int = 0

    /// 流式阶段标签
    @Published var streamPhaseLabel: String = ""

    /// 流式统计（字数/token/chunk 数）
    @Published var streamStats: ChunkStats = ChunkStats()

    /// 当前流式 phase（用于骨架屏显隐）
    @Published var generateStreamPhase: String = ""

    /// 重新生成模式
    @Published var isRegenerationMode: Bool = false

    /// 重新生成改进方向
    @Published var regenerationGuidance: String = ""

    /// 重新生成前正在保存草稿
    @Published var savingDraftBeforeRegen: Bool = false

    // MARK: - P0-5 张力诊断状态字段

    /// 张力诊断弹窗是否显示
    @Published var showTensionModal: Bool = false

    /// 张力诊断加载中
    @Published var tensionLoading: Bool = false

    /// 张力诊断问题描述
    @Published var tensionStuckReason: String = ""

    /// 张力诊断结果
    @Published var tensionResult: TensionDiagnosis? = nil

    // MARK: - P0-4 辅助/托管撰稿模式状态（对齐 WorkArea.vue L953）

    /// 创作模式：assisted=辅助撰稿 / managed=托管撰稿
    @Published var workMode: String = "assisted"

    /// DAGRunStore 引用（用于判断 isAssistedReadOnly）
    @Published var dagRunStore: DAGRunStore

    /// 辅助侧只读：workMode == "assisted" 且 DAG 运行中（对齐 WorkArea.vue L1143-1145 isAssistedReadOnly）
    var isAssistedReadOnly: Bool {
        return workMode == "assisted" && dagRunStore.isRunning
    }

    // MARK: - P1-STATE-02 Desk 状态（对齐 useWorkbench.ts:30-39）

    /// 书名（对齐 useWorkbench.ts:30 bookTitle）
    @Published var bookTitle: String = ""

    /// 章节列表（精简，对齐 useWorkbench.ts:31 chapters）
    @Published var deskChapters: [DeskChapterItem] = []

    /// 是否有 Bible（对齐 useWorkbench.ts:33 bookMeta.has_bible）
    @Published var hasBible: Bool = false

    /// 是否有大纲（对齐 useWorkbench.ts:33 bookMeta.has_outline）
    @Published var hasOutline: Bool = false

    /// 页面加载中（对齐 useWorkbench.ts:35 pageLoading）
    @Published var pageLoading: Bool = false

    /// 当前章节 ID（对齐 useWorkbench.ts:36 currentChapterId）
    @Published var currentChapterId: Int? = nil

    /// 章节加载中（对齐 useWorkbench.ts:38 chapterLoading）
    @Published var chapterLoading: Bool = false

    /// 当前任务 ID（对齐 useWorkbench.ts:39 currentJobId）
    @Published var currentJobId: String? = nil

    /// 是否有结构（对齐 useWorkbench.ts:44-46 hasStructure）
    var hasStructure: Bool {
        return hasBible || hasOutline
    }

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
        self.dagRunStore = DAGRunStore(apiClient: apiClient, sseRegistry: sseRegistry)
    }

    // MARK: - 章节编辑

    /// 加载章节内容到编辑器
    /// - Parameter chapter: 章节对象
    func loadChapter(_ chapter: ChapterDTO) {
        chapterContent = chapter.content
        originalContent = chapter.content
        generationHint = chapter.generationHint
        hasUnsavedChanges = false
        review = nil
        structure = nil
        aiReviewResult = nil
    }

    /// 更新编辑内容
    /// - Parameter content: 新内容
    func updateContent(_ content: String) {
        chapterContent = content
        hasUnsavedChanges = content != originalContent
    }

    /// 更新生成约束
    /// - Parameter hint: 生成约束
    func updateGenerationHint(_ hint: String) {
        generationHint = hint
    }

    // MARK: - P0-4 workMode 持久化（对齐 WorkArea.vue L953 + PRD 验收标准 7）

    /// 从 UserDefaults 加载 workMode（key: "workMode_{novelId}"），默认 "assisted"
    /// - Parameter novelId: 小说 ID
    func loadWorkMode(novelId: String) {
        let key = "workMode_\(novelId)"
        let saved = UserDefaults.standard.string(forKey: key) ?? "assisted"
        workMode = saved
    }

    /// 保存 workMode 到 UserDefaults
    /// - Parameter novelId: 小说 ID
    func saveWorkMode(novelId: String) {
        let key = "workMode_\(novelId)"
        UserDefaults.standard.set(workMode, forKey: key)
    }

    /// 切换 workMode 并持久化
    /// - Parameter novelId: 小说 ID
    func toggleWorkMode(novelId: String) {
        workMode = workMode == "assisted" ? "managed" : "assisted"
        saveWorkMode(novelId: novelId)
    }

    // MARK: - P1-STATE-02 Desk 加载（对齐 useWorkbench.ts:52-79 loadDesk）

    /// 加载工作台数据（并行 novel + chapters）— 对齐 useWorkbench.ts:52-79
    /// - Parameter novelId: 小说 ID
    func loadDesk(novelId: String) async {
        do {
            // 并行加载 novel + chapters（对齐 Promise.all）
            async let novelData: NovelDTO = apiClient.request(APIEndpoint.Novels.get(novelId: novelId))
            async let chaptersData: [ChapterDTO] = apiClient.request(APIEndpoint.Chapters.list(novelId: novelId))

            let (novel, chapters) = await (try novelData, try chaptersData)

            bookTitle = novel.title.isEmpty ? novelId : novel.title
            hasBible = novel.hasBible
            hasOutline = novel.hasOutline

            // 映射为精简章节列表（对齐 useWorkbench.ts:63-68）
            deskChapters = chapters.map { ch in
                DeskChapterItem(
                    id: ch.number,
                    number: ch.number,
                    title: ch.title,
                    wordCount: ch.wordCount
                )
            }
        } catch {
            Logger.data.error("loadDesk 失败: \(error.localizedDescription)")
        }
    }

    /// 加载工作台数据 + 可选统计 — 对齐 useWorkbench.ts:81-92 loadData
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - includeStats: 是否同时加载统计
    func loadData(novelId: String, includeStats: Bool = false) async {
        pageLoading = true
        if includeStats {
            async let deskTask: Void = loadDesk(novelId: novelId)
            async let statsTask: Void = StatsStore().loadBookAllStats(slug: novelId, days: 30, force: true)
            _ = await (deskTask, statsTask)
        } else {
            await loadDesk(novelId: novelId)
        }
        pageLoading = false
    }

    // MARK: - P1-STATE-02 goToChapter 404 自动创建（对齐 useWorkbench.ts:125-159）

    /// 判断错误是否为 404 — 对齐 useWorkbench.ts:119-123 is404
    private func is404(_ error: Error) -> Bool {
        let detail = error.localizedDescription
        if detail.contains("404") { return true }
        if detail.lowercased().contains("not found") { return true }
        if detail.contains("不存在") { return true }
        return false
    }

    /// 跳转到章节（404 自动创建空白记录）— 对齐 useWorkbench.ts:125-159 goToChapter
    /// - Parameters:
    ///   - id: 章节号
    ///   - nodeTitle: 节点标题（用于新建空白章节）
    ///   - novelId: 小说 ID
    func goToChapter(id: Int, nodeTitle: String?, novelId: String) async {
        guard id >= 1 else {
            errorMessage = "无效的章节号"
            return
        }

        chapterLoading = true
        do {
            // 尝试获取章节
            let chapter: ChapterDTO
            do {
                chapter = try await apiClient.request(
                    APIEndpoint.Chapters.get(novelId: novelId, chapterNumber: id)
                )
            } catch {
                if !is404(error) { throw error }
                // 404：静默创建空白记录（对齐 useWorkbench.ts:137-138）
                let ensureBody = AnyCodable(["title": nodeTitle ?? ""])
                let _: ChapterDTO = try await apiClient.request(
                    APIEndpoint.Chapters.ensure(novelId: novelId, chapterNumber: id),
                    body: ensureBody
                )
                // 重新获取
                chapter = try await apiClient.request(
                    APIEndpoint.Chapters.get(novelId: novelId, chapterNumber: id)
                )
            }

            currentChapterId = id
            chapterContent = chapter.content
            originalContent = chapter.content
            hasUnsavedChanges = false

            // 若是新建的空白章节，刷新侧栏列表（对齐 useWorkbench.ts:143-146）
            let existed = deskChapters.contains { $0.number == id }
            if !existed {
                await loadDesk(novelId: novelId)
            }
        } catch {
            errorMessage = "加载第\(id)章失败：\(error.localizedDescription)"
            currentChapterId = nil
            chapterContent = ""
        }
        chapterLoading = false
    }

    // MARK: - P1-STATE-02 handleJobCompleted（对齐 useWorkbench.ts:94-103）

    /// 任务完成后缓存失效 + 重载 — 对齐 useWorkbench.ts:94-103 handleJobCompleted
    /// - Parameter novelId: 小说 ID
    func handleJobCompleted(novelId: String) async {
        // 通知 StatsStore 失效缓存并重载
        // 对齐 useWorkbench.ts:96 statsStore.onJobCompleted
        // StatsStore 通过 EnvironmentObject 注入，这里发送通知
        NotificationCenter.default.post(
            name: Notification.Name("StatsStoreOnJobCompleted"),
            object: nil,
            userInfo: ["slug": novelId]
        )
        // 刷新工作台数据
        await loadDesk(novelId: novelId)
        // 发布 desk 刷新通知（Bible 软刷新等）
        bumpDeskTick()
    }

    // MARK: - 保存

    /// 保存章节内容
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func saveChapter(novelId: String, chapterNumber: Int) async {
        guard hasUnsavedChanges else { return }

        isSaving = true
        errorMessage = nil

        do {
            let updatedChapter: ChapterDTO = try await apiClient.request(
                APIEndpoint.Chapters.update(novelId: novelId, chapterNumber: chapterNumber),
                body: UpdateChapterContentRequest(content: chapterContent)
            )
            originalContent = chapterContent
            hasUnsavedChanges = false
            Logger.data.info("章节保存成功: 第\(chapterNumber)章, \(updatedChapter.wordCount)字")
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("章节保存失败: \(error.localizedDescription)")
        }

        isSaving = false
    }

    /// 保存生成约束
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func saveGenerationHint(novelId: String, chapterNumber: Int) async {
        do {
            let _: ChapterDTO = try await apiClient.request(
                APIEndpoint.Chapters.updateHint(novelId: novelId, chapterNumber: chapterNumber),
                body: UpdateChapterHintRequest(generationHint: generationHint)
            )
            Logger.data.info("生成约束保存成功: 第\(chapterNumber)章")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 审阅

    /// 获取章节审阅
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func loadReview(novelId: String, chapterNumber: Int) async {
        do {
            review = try await apiClient.request(
                APIEndpoint.Chapters.getReview(novelId: novelId, chapterNumber: chapterNumber)
            )
        } catch {
            // 审阅不存在时后端返回 404，不显示错误
            review = nil
        }
    }

    /// 保存章节审阅
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - status: 审阅状态
    ///   - memo: 审阅备注
    func saveReview(novelId: String, chapterNumber: Int, status: String, memo: String) async {
        do {
            review = try await apiClient.request(
                APIEndpoint.Chapters.saveReview(novelId: novelId, chapterNumber: chapterNumber),
                body: SaveChapterReviewRequest(status: status, memo: memo)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// AI 审阅章节
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - save: 是否保存审阅结果
    func aiReview(novelId: String, chapterNumber: Int, save: Bool = false) async {
        isGenerating = true
        errorMessage = nil

        do {
            aiReviewResult = try await apiClient.request(
                APIEndpoint.Chapters.aiReview(novelId: novelId, chapterNumber: chapterNumber),
                body: ChapterAIReviewRequest(save: save)
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    // MARK: - 结构分析

    /// 获取章节结构分析
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func loadStructure(novelId: String, chapterNumber: Int) async {
        do {
            structure = try await apiClient.request(
                APIEndpoint.Chapters.structure(novelId: novelId, chapterNumber: chapterNumber)
            )
        } catch {
            structure = nil
        }
    }

    // MARK: - 草稿

    /// 保存当前内容为草稿
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - source: 草稿来源（pre_regen=重新生成前 | manual_save=手动 | auto_gen=首次生成）
    func saveDraft(novelId: String, chapterNumber: Int, source: String = "pre_regen") async {
        do {
            // 【修复】后端期望 SaveDraftRequest（含 source 字段），而非空请求体。
            // 修复前发送 EmptyResponse()，source 字段缺失导致后端使用默认值。
            let _: ChapterDraftResponse = try await apiClient.request(
                APIEndpoint.Chapters.saveDraft(novelId: novelId, chapterNumber: chapterNumber),
                body: SaveDraftRequest(source: source)
            )
            await loadDrafts(novelId: novelId, chapterNumber: chapterNumber)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载草稿列表
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func loadDrafts(novelId: String, chapterNumber: Int) async {
        do {
            drafts = try await apiClient.request(
                APIEndpoint.Chapters.listDrafts(novelId: novelId, chapterNumber: chapterNumber)
            )
        } catch {
            drafts = []
        }
    }

    // MARK: - 计算

    /// 当前字数
    var currentWordCount: Int {
        return chapterContent.cangjieWordCount
    }

    /// 当前字数显示
    var currentWordCountDisplay: String {
        return chapterContent.cangjieWordCountDisplay
    }

    // MARK: - M5 单章生成 SSE（workflow.ts:375-511）

    /// 启动单章生成 SSE 流（workflow.ts:375-511 consumeGenerateChapterStream）
    ///
    /// POST /api/v1/novels/{novelId}/generate-chapter-stream
    /// data-only 格式，7类事件：phase/llm_chunk/beats_generated/approval_required/chunk/done/error
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - outline: 章节大纲（从 generationHint 或 chapter.outline 获取）
    func consumeGenerateChapterStream(
        novelId: String,
        chapterNumber: Int,
        outline: String
    ) {
        // 重置生成状态
        isGeneratingChapter = true
        generateChapterPhase = nil
        generateChapterContent = ""
        generateChapterConsistencyReport = nil
        generateChapterStyleWarnings = nil
        generateChapterBeats = nil
        errorMessage = nil

        // 【返工M5】记录当前生成的小说ID，用于在 approval_required/error/done 时显式 cancel SSE
        currentGenerateNovelId = novelId

        // 构造请求载荷（Q决策：只传必填字段 chapterNumber + outline，workflow.ts:159-174）
        let payload = GenerateChapterWithContextPayload(
            chapterNumber: chapterNumber,
            outline: outline
        )

        Logger.engine.info("启动单章生成 SSE: novel=\(novelId), chapter=\(chapterNumber)")

        // 启动 SSE 流（SSEStreamRegistry.startGenerateChapterStream）
        sseRegistry.startGenerateChapterStream(
            novelId: novelId,
            payload: payload,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleGenerateChapterSSEEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.isGeneratingChapter = false
                    self?.errorMessage = "单章生成连接失败: \(error.localizedDescription)"
                }
            }
        )
    }

    /// 处理单章生成 SSE 事件（workflow.ts:416-494）
    ///
    /// generate-chapter-stream 是 data-only 格式（无 event: 行），事件类型在 JSON data.type 字段中。
    /// 7类事件：phase/llm_chunk/beats_generated/approval_required/chunk/done/error
    private func handleGenerateChapterSSEEvent(_ event: SSEEvent) {
        // data-only 格式，用 generateChapterEventType 获取事件类型（workflow.ts:417）
        guard let eventType = event.generateChapterEventType else { return }
        guard let dict = event.decodeAsDictionary() else { return }

        switch eventType {
        case "phase":
            // phase 事件（workflow.ts:418-425）：更新 generateChapterPhase
            let phase = dict["phase"] as? String ?? ""
            generateChapterPhase = phase
            Logger.engine.info("单章生成阶段: \(phase)")

        case "beats_generated":
            // beats_generated 事件（workflow.ts:426-430）：用 parseStreamGeneratedBeats 解析
            let rawBeats = dict["beats"] as? [Any]
            let beats = parseStreamGeneratedBeats(rawBeats)
            generateChapterBeats = beats
            Logger.engine.info("单章生成节拍: \(beats.count)个")

        case "llm_chunk":
            // llm_chunk 事件（workflow.ts:431-436）：非正文 LLM 流式增量
            let stage = dict["stage"] as? String ?? ""
            let text = dict["text"] as? String ?? ""
            Logger.engine.info("单章生成 LLM chunk [\(stage)]: \(text.prefix(50))")

        case "approval_required":
            // approval_required 事件（workflow.ts:437-446）：终止流
            // 阶段3接线：打开 AI 审批面板 — aiInvocationStore.openFromResponse
            let sessionId = dict["session_id"] as? String ?? ""
            let status = dict["status"] as? String
            let nextAction = dict["next_action"] as? String
            Logger.engine.info("单章生成需要审批: sessionId=\(sessionId)")
            // 阶段3：接线到 AI 审批面板
            if !sessionId.isEmpty {
                // 先用 GET 获取完整 session 数据，再 openFromResponse
                Task {
                    do {
                        let payload: InvocationResponseDTO = try await APIClient.shared.request(
                            APIEndpoint.AIInvocation.get(sessionId: sessionId)
                        )
                        await MainActor.run {
                            aiInvocationStore.openFromResponse(payload)
                        }
                    } catch {
                        Logger.engine.error("审批面板打开失败: \(error.localizedDescription)")
                    }
                }
            }
            isGeneratingChapter = false
            // 显式 cancel SSE（原版 workflow.ts:446 return true 终止流）
            if let nid = currentGenerateNovelId {
                sseRegistry.cancelGenerateChapterStream(novelId: nid)
            }

        case "chunk":
            // chunk 事件（workflow.ts:447-452）：正文流式增量
            let text = dict["text"] as? String ?? ""
            generateChapterContent += text

        case "done":
            // done 事件（workflow.ts:453-483）：终止流
            handleGenerateChapterDoneEvent(dict)
            // 【返工M5】显式 cancel SSE（原版 done 也 return true 终止流）
            if let nid = currentGenerateNovelId {
                sseRegistry.cancelGenerateChapterStream(novelId: nid)
            }

        case "error":
            // error 事件（workflow.ts:484-490）：终止流
            let message = dict["message"] as? String ?? "生成失败"
            errorMessage = message
            isGeneratingChapter = false
            Logger.engine.error("单章生成失败: \(message)")
            // 【返工M5】显式 cancel SSE（原版 workflow.ts:489 return true 终止流）
            if let nid = currentGenerateNovelId {
                sseRegistry.cancelGenerateChapterStream(novelId: nid)
            }

        default:
            break
        }
    }

    /// 处理 done 事件（workflow.ts:453-483）
    private func handleGenerateChapterDoneEvent(_ dict: [String: Any]) {
        // content（workflow.ts:460）
        let content = dict["content"] as? String ?? ""

        // consistency_report：有则用，无则空（workflow.ts:454-458）
        let consistencyReport: ConsistencyReportDTO
        if let reportDict = dict["consistency_report"] as? [String: Any] {
            consistencyReport = parseConsistencyReport(reportDict)
        } else {
            consistencyReport = ConsistencyReportDTO()
        }

        // token_count（workflow.ts:461）
        let _ = dict["token_count"] as? Int ?? 0

        // beats 兜底（workflow.ts:464-467）
        let rawBeats = dict["beats"] as? [Any]
        let doneBeats = parseStreamGeneratedBeats(rawBeats)
        if !doneBeats.isEmpty {
            generateChapterBeats = doneBeats
        }

        // style_warnings（workflow.ts:468-470）
        if let warningsArray = dict["style_warnings"] as? [[String: Any]] {
            generateChapterStyleWarnings = warningsArray.map { parseStyleWarning($0) }
        }

        // ghost_annotations（workflow.ts:471-473）
        // 暂不使用，跳过

        // 更新状态
        generateChapterContent = content
        generateChapterConsistencyReport = consistencyReport
        chapterContent = content
        originalContent = content
        hasUnsavedChanges = false
        isGeneratingChapter = false

        Logger.engine.info("单章生成完成: \(content.count)字, issues=\(consistencyReport.issues.count), warnings=\(consistencyReport.warnings.count)")
    }

    /// 取消单章生成
    /// - Parameter novelId: 小说 ID
    func cancelGenerateChapterStream(novelId: String) {
        sseRegistry.cancelGenerateChapterStream(novelId: novelId)
        isGeneratingChapter = false
        generateInProgress = false
    }

    // MARK: - P0-2 生成弹窗方法（对齐 WorkArea.vue L1362-1920）

    /// 加载 LLM 配置档案列表（对齐 WorkArea.vue L1362-1376 loadLLMProfilesForModal）
    func loadLLMProfilesForModal() async {
        if !llmProfiles.isEmpty { return }
        llmProfilesLoading = true
        do {
            let panelData: LLMControlPanelData = try await apiClient.request(APIEndpoint.LLMControl.panel)
            llmProfiles = panelData.config.profiles
            if generateProfileId == nil, let activeId = panelData.config.activeProfileId {
                generateProfileId = activeId
            }
        } catch {
            // 静默失败，Picker 选项为空
            Logger.data.error("加载 LLM 配置档案失败: \(error.localizedDescription)")
        }
        llmProfilesLoading = false
    }

    /// 大纲失焦自动预分析场景（对齐 WorkArea.vue L1419-1434 onOutlineBlurAnalyze）
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func onOutlineBlurAnalyze(novelId: String, chapterNumber: Int) async {
        let outline = generateOutline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outline.isEmpty, !outlineBlurAnalyzing, !generateInProgress else { return }

        outlineBlurAnalyzing = true
        do {
            let analysis = try await analyzeScene(novelId: novelId, chapterNumber: chapterNumber, outline: outline)
            blurSceneCache = analysis.rawData ?? AnyCodable([:])
        } catch {
            blurSceneCache = nil
        }
        outlineBlurAnalyzing = false
    }

    /// 场记分析（对齐 WorkArea.vue L1770-1780 + workflow.ts L230-238）
    /// POST /novels/{novelId}/scene-director/analyze
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - outline: 大纲文本
    /// - Returns: 场记分析结果
    func analyzeScene(novelId: String, chapterNumber: Int, outline: String) async throws -> SceneDirectorAnalysis {
        let bodyDict: [String: Any] = [
            "chapter_number": chapterNumber,
            "outline": outline
        ]
        let body = AnyCodable(bodyDict)
        let result: SceneDirectorAnalysis = try await apiClient.request(
            APIEndpoint.Workflow.analyzeScene(novelId: novelId),
            body: body
        )
        return result
    }

    /// 上下文预览（对齐 WorkArea.vue L1402-1417 + workflow.ts L902-918）
    /// POST /novels/{novelId}/context/retrieve
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - outline: 大纲文本
    ///   - maxTokens: 最大 Token 数（默认 16000）
    ///   - sceneDirectorResult: 场记分析结果（可选）
    func retrieveContext(
        novelId: String,
        chapterNumber: Int,
        outline: String,
        maxTokens: Int = 16000,
        sceneDirectorResult: AnyCodable? = nil
    ) async {
        loadingContext = true
        do {
            var bodyDict: [String: Any] = [
                "chapter_number": chapterNumber,
                "outline": outline,
                "max_tokens": maxTokens
            ]
            if let sdr = sceneDirectorResult {
                bodyDict["scene_director_result"] = sdr.value
            }
            let body = AnyCodable(bodyDict)
            contextPreview = try await apiClient.request(
                APIEndpoint.Workflow.retrieveContext(novelId: novelId),
                body: body
            )
        } catch {
            contextPreview = nil
        }
        loadingContext = false
    }

    /// 构建提示词变量字典（对齐 WorkArea.vue L1378-1387 buildPromptVariables）
    /// - Returns: 合并后的变量字典，无变量时返回 nil
    func buildPromptVariables() -> [String: String]? {
        var vars: [String: String] = [:]
        for pair in scriptPromptVarPairs {
            if !pair.key.isEmpty { vars[pair.key] = pair.value }
        }
        for pair in prosePromptVarPairs {
            if !pair.key.isEmpty { vars[pair.key] = pair.value }
        }
        return vars.isEmpty ? nil : vars
    }

    /// 添加 SSE 日志行（对齐 WorkArea.vue L1099-1102 pushGenerateSseLog）
    /// - Parameters:
    ///   - tag: 日志标签（phase/chunk/beats/done/error/SSE/规划/正文）
    ///   - msg: 日志消息
    func pushGenerateSseLog(tag: String, msg: String) {
        let line = GenerateStreamLogLine(tag: tag, msg: msg)
        generateSseLog.append(line)
        // 限制日志行数（对齐 GENERATE_STREAM_LOG_LIMIT）
        let maxLines = 200
        if generateSseLog.count > maxLines {
            generateSseLog = Array(generateSseLog.suffix(maxLines))
        }
    }

    /// 开始生成（对齐 WorkArea.vue L1734-1920 handleStartGenerate）
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 目标章节号
    ///   - chapterTitle: 章节标题（用于默认大纲）
    func startGenerate(novelId: String, chapterNumber: Int, chapterTitle: String) async {
        generateInProgress = true
        generateSseLog = []
        generateStreamPhase = ""
        generatedContent = ""
        sceneDirectorError = ""
        streamPhaseLabel = "连接中…"
        streamProgressPct = 8
        streamStats = ChunkStats()
        pushGenerateSseLog(tag: "SSE", msg: "正在连接 generate-chapter-stream…")

        // 场记分析逻辑（对齐 WorkArea.vue L1768-1780）
        var sceneDirectorResult: AnyCodable? = blurSceneCache
        if useSceneDirector && sceneDirectorResult == nil {
            analyzingScene = true
            do {
                let outline = generateOutline.isEmpty ? "第\(chapterNumber)章：承接前情，推进主线" : generateOutline
                let analysis = try await analyzeScene(novelId: novelId, chapterNumber: chapterNumber, outline: outline)
                sceneDirectorResult = analysis.rawData ?? AnyCodable([:])
            } catch {
                sceneDirectorError = error.localizedDescription
            }
            analyzingScene = false
        }

        let defaultOutline = "第\(chapterNumber)章：承接前情，推进主线"

        // 重新生成模式：先快照当前内容（对齐 WorkArea.vue L1785-1825）
        if isRegenerationMode {
            savingDraftBeforeRegen = true
            do {
                let _: ChapterDraftResponse = try await apiClient.request(
                    APIEndpoint.Chapters.saveDraft(novelId: novelId, chapterNumber: chapterNumber),
                    body: SaveDraftRequest(source: "pre_regen")
                )
            } catch {
                // 快照失败不阻断生成（对齐 WorkArea.vue L1792-1821）
                pushGenerateSseLog(tag: "SSE", msg: "历史草稿快照失败，继续生成")
            }
            savingDraftBeforeRegen = false
        }

        // 构建完整 payload（对齐 WorkArea.vue L1827-1845）
        let payload = GenerateChapterWithContextPayload(
            chapterNumber: chapterNumber,
            outline: generateOutline.isEmpty ? defaultOutline : generateOutline,
            sceneDirectorResult: sceneDirectorResult,
            regenerationGuidance: isRegenerationMode && !regenerationGuidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? regenerationGuidance.trimmingCharacters(in: .whitespacesAndNewlines)
                : nil,
            profileId: generateProfileId,
            scriptPromptTemplate: useCustomScriptPrompt ? (customScriptTemplate.isEmpty ? nil : customScriptTemplate) : nil,
            prosePromptTemplate: useCustomProsePrompt ? (customProseTemplate.isEmpty ? nil : customProseTemplate) : nil,
            promptVariables: buildPromptVariables()
        )

        // 启动 SSE 流
        consumeGenerateChapterStream(novelId: novelId, payload: payload)
    }

    /// 扩展版 consumeGenerateChapterStream（接受完整 payload）
    /// P0-2：不再只传 chapterNumber + outline，而是传完整 GenerateChapterWithContextPayload
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - payload: 完整生成请求载荷
    func consumeGenerateChapterStream(novelId: String, payload: GenerateChapterWithContextPayload) {
        isGeneratingChapter = true
        generateChapterPhase = nil
        generateChapterContent = ""
        generateChapterConsistencyReport = nil
        generateChapterStyleWarnings = nil
        generateChapterBeats = nil
        errorMessage = nil
        currentGenerateNovelId = novelId

        Logger.engine.info("启动单章生成 SSE (完整 payload): novel=\(novelId), chapter=\(payload.chapterNumber)")

        sseRegistry.startGenerateChapterStream(
            novelId: novelId,
            payload: payload,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleGenerateChapterSSEEventWithModal(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.isGeneratingChapter = false
                    self?.generateInProgress = false
                    self?.errorMessage = "单章生成连接失败: \(error.localizedDescription)"
                    self?.pushGenerateSseLog(tag: "error", msg: error.localizedDescription)
                }
            }
        )
    }

    /// 处理 SSE 事件（带弹窗日志更新，对齐 WorkArea.vue L1848-1920）
    private func handleGenerateChapterSSEEventWithModal(_ event: SSEEvent) {
        guard let eventType = event.generateChapterEventType else { return }
        guard let dict = event.decodeAsDictionary() else { return }

        switch eventType {
        case "phase":
            let phase = dict["phase"] as? String ?? ""
            let message = dict["message"] as? String ?? ""
            generateChapterPhase = phase
            generateStreamPhase = phase
            streamPhaseLabel = streamPhaseToLabel(phase)
            streamProgressPct = streamPhaseToProgress(phase)
            pushGenerateSseLog(tag: "SSE", msg: message.isEmpty ? streamPhaseToLogLabel(phase) : message)

        case "beats_generated":
            let rawBeats = dict["beats"] as? [Any]
            let beats = parseStreamGeneratedBeats(rawBeats)
            generateChapterBeats = beats
            generateStreamPhase = "prose"
            streamPhaseLabel = streamPhaseToLabel("prose")
            streamProgressPct = streamPhaseToProgress("prose")
            pushGenerateSseLog(tag: "规划", msg: beats.isEmpty ? "规划未返回拆拍" : "历史拆拍结果 ×\(beats.count)")

        case "llm_chunk":
            let stage = dict["stage"] as? String ?? ""
            let text = dict["text"] as? String ?? ""
            if stage == "outline_partition" {
                generateStreamPhase = "outline_planning"
                streamPhaseLabel = "章节执行剧本准备…"
                streamProgressPct = max(streamProgressPct, streamPhaseToProgress("outline_planning"))
            }

        case "approval_required":
            let sessionId = dict["session_id"] as? String ?? ""
            if !sessionId.isEmpty {
                Task {
                    do {
                        let payload: InvocationResponseDTO = try await APIClient.shared.request(
                            APIEndpoint.AIInvocation.get(sessionId: sessionId)
                        )
                        await MainActor.run {
                            aiInvocationStore.openFromResponse(payload)
                        }
                    } catch {
                        Logger.engine.error("审批面板打开失败: \(error.localizedDescription)")
                    }
                }
            }
            isGeneratingChapter = false
            generateInProgress = false
            if let nid = currentGenerateNovelId {
                sseRegistry.cancelGenerateChapterStream(novelId: nid)
            }

        case "chunk":
            let text = dict["text"] as? String ?? ""
            generatedContent += text
            generateChapterContent = generatedContent
            let statsDict = dict["stats"] as? [String: Any]
            if let chars = statsDict?["chars"] as? Int {
                streamStats = ChunkStats(
                    chars: chars,
                    chunks: (statsDict?["chunks"] as? Int ?? streamStats.chunks) + 1,
                    estimatedTokens: statsDict?["estimated_tokens"] as? Int ?? 0
                )
            }

        case "done":
            handleGenerateChapterDoneEvent(dict)
            pushGenerateSseLog(tag: "SSE", msg: "done · 生成完成")
            streamProgressPct = 100
            streamPhaseLabel = "已完成"
            generateInProgress = false
            if let nid = currentGenerateNovelId {
                sseRegistry.cancelGenerateChapterStream(novelId: nid)
            }

        case "error":
            let message = dict["message"] as? String ?? "生成失败"
            errorMessage = message
            isGeneratingChapter = false
            generateInProgress = false
            pushGenerateSseLog(tag: "error", msg: message)
            if let nid = currentGenerateNovelId {
                sseRegistry.cancelGenerateChapterStream(novelId: nid)
            }

        default:
            break
        }
    }

    /// 停止生成（对齐 WorkArea.vue stopGenerate）
    func stopGenerate(novelId: String) {
        cancelGenerateChapterStream(novelId: novelId)
        generateInProgress = false
        streamPhaseLabel = ""
        streamProgressPct = 0
    }

    /// 清空生成草稿（对齐 WorkArea.vue L1441-1444 clearGeneratedDraft）
    func clearGeneratedDraft() {
        generatedContent = ""
        generateChapterContent = ""
    }

    /// 保存生成内容到所选章节（对齐 WorkArea.vue L1598-1614 handleSaveGenerated）
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func saveGeneratedToChapter(novelId: String, chapterNumber: Int) async {
        isSaving = true
        do {
            let _: ChapterDTO = try await apiClient.request(
                APIEndpoint.Chapters.update(novelId: novelId, chapterNumber: chapterNumber),
                body: UpdateChapterContentRequest(content: generatedContent)
            )
            chapterContent = generatedContent
            originalContent = generatedContent
            hasUnsavedChanges = false
            Logger.data.info("生成内容保存成功: 第\(chapterNumber)章")
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
        isSaving = false
    }

    /// 打开生成弹窗（对齐 WorkArea.vue L1669-1693 handleGenerateChapter）
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapter: 当前章节
    func openGenerateModal(novelId: String, chapter: ChapterDTO) {
        isRegenerationMode = false
        regenerationGuidance = ""
        generateTargetChapterId = chapter.id
        generateOutline = "第\(chapter.number)章：\(chapter.title)\n\n承接前情，推进主线与人物节拍；保持人设与叙事节奏一致。"
        generatedContent = ""
        contextPreview = nil
        blurSceneCache = nil
        showGenerateModal = true
        Task { await loadLLMProfilesForModal() }
    }

    /// 打开重新生成弹窗（对齐 WorkArea.vue L1695-1732 handleRegenerateChapter）
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapter: 当前章节
    func openRegenerateModal(novelId: String, chapter: ChapterDTO) {
        isRegenerationMode = true
        regenerationGuidance = ""
        generateTargetChapterId = chapter.id
        generateOutline = "第\(chapter.number)章：\(chapter.title)\n\n承接前情，推进主线与人物节拍；保持人设与叙事节奏一致。"
        generatedContent = ""
        contextPreview = nil
        blurSceneCache = nil
        showGenerateModal = true
        Task { await loadLLMProfilesForModal() }
    }

    // MARK: - P0-5 张力诊断方法（对齐 WorkArea.vue L1323-1341 runTensionSlingshot）

    /// 运行张力诊断
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - stuckReason: 卡壳原因（可选）
    func runTensionDiagnosis(novelId: String, chapterNumber: Int, stuckReason: String?) async {
        tensionLoading = true
        do {
            let payload = TensionSlingshotPayload(
                novelId: novelId,
                chapterNumber: chapterNumber,
                stuckReason: stuckReason?.isEmpty == true ? nil : stuckReason
            )
            tensionResult = try await apiClient.request(
                APIEndpoint.Tools.tensionSlingshot(novelId: novelId),
                body: payload
            )
        } catch {
            tensionResult = nil
            errorMessage = "分析失败: \(error.localizedDescription)"
        }
        tensionLoading = false
    }

    /// 打开张力诊断弹窗
    /// - Parameter chapterNumber: 章节号
    func openTensionModal(chapterNumber: Int) {
        tensionResult = nil
        tensionStuckReason = ""
        showTensionModal = true
    }

    // MARK: - 一致性报告解析辅助

    /// 解析一致性报告（workflow.ts:454-458）
    private func parseConsistencyReport(_ dict: [String: Any]) -> ConsistencyReportDTO {
        let issues = (dict["issues"] as? [[String: Any]] ?? []).map { parseConsistencyIssue($0) }
        let warnings = (dict["warnings"] as? [[String: Any]] ?? []).map { parseConsistencyIssue($0) }
        let suggestions = dict["suggestions"] as? [String] ?? []
        return ConsistencyReportDTO(issues: issues, warnings: warnings, suggestions: suggestions)
    }

    /// 解析一致性问题（workflow.ts:242-247）
    private func parseConsistencyIssue(_ dict: [String: Any]) -> ConsistencyIssueDTO {
        return ConsistencyIssueDTO(
            type: dict["type"] as? String ?? "",
            severity: dict["severity"] as? String ?? "",
            description: dict["description"] as? String ?? "",
            location: dict["location"] as? Int ?? 0
        )
    }

    /// 解析文风警告（workflow.ts:255-261）
    private func parseStyleWarning(_ dict: [String: Any]) -> StyleWarning {
        return StyleWarning(
            pattern: dict["pattern"] as? String ?? "",
            text: dict["text"] as? String ?? "",
            start: dict["start"] as? Int ?? 0,
            end: dict["end"] as? Int ?? 0,
            severity: dict["severity"] as? String ?? "info"
        )
    }
}

// MARK: - 提示词变量键值对（对齐 WorkArea.vue scriptPromptVarPairs / prosePromptVarPairs）

/// 提示词变量键值对，对应原版 n-dynamic-input preset="pair" 的数据结构
struct PromptVarPair: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String

    init(key: String = "", value: String = "") {
        self.key = key
        self.value = value
    }
}

// MARK: - SSE 日志行（对齐 generationStreamPresentation.ts GenerateStreamLogLine）

/// SSE 日志行，对应原版 GenerateStreamLogLine
struct GenerateStreamLogLine: Identifiable, Equatable {
    let id = UUID()
    let tag: String
    let msg: String

    /// tag → 颜色类型（对齐 generateStreamTagType）
    var tagColor: String {
        switch tag {
        case "phase", "SSE": return "info"
        case "chunk", "正文": return "success"
        case "beats", "规划": return "warning"
        case "done": return "success"
        case "error": return "error"
        default: return "info"
        }
    }
}

// MARK: - P1-STATE-02 Desk 章节列表项（对齐 useWorkbench.ts:31 chapters 格式）

/// 精简章节列表项，对齐 useWorkbench.ts:63-68 章节映射格式
struct DeskChapterItem: Identifiable, Equatable {
    let id: Int
    let number: Int
    let title: String
    let wordCount: Int
}
