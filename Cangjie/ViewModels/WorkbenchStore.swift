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

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
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
            let sessionId = dict["session_id"] as? String ?? ""
            let status = dict["status"] as? String
            let nextAction = dict["next_action"] as? String
            Logger.engine.info("单章生成需要审批: sessionId=\(sessionId)")
            // 阶段1：显示提示，不阻塞
            errorMessage = "需要AI审批（审批面板后续实现）"
            if let status = status {
                errorMessage = "需要AI审批 [\(status)]"
            }
            isGeneratingChapter = false

        case "chunk":
            // chunk 事件（workflow.ts:447-452）：正文流式增量
            let text = dict["text"] as? String ?? ""
            generateChapterContent += text

        case "done":
            // done 事件（workflow.ts:453-483）：终止流
            handleGenerateChapterDoneEvent(dict)

        case "error":
            // error 事件（workflow.ts:484-490）：终止流
            let message = dict["message"] as? String ?? "生成失败"
            errorMessage = message
            isGeneratingChapter = false
            Logger.engine.error("单章生成失败: \(message)")

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
