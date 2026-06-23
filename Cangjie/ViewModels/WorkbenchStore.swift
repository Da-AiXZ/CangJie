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

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
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
}
