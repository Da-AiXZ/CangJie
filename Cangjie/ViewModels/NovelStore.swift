//
//  NovelStore.swift
//  Cangjie
//
//  书目 CRUD + 章节列表 + 当前选中小说/章节状态。
//  调用 T01 的 APIClient + APIEndpoint。
//

import SwiftUI
import Foundation

/// 书目 Store，管理小说列表、当前选中小说、章节列表。
@MainActor
final class NovelStore: ObservableObject {

    // MARK: - 状态

    /// 小说列表
    @Published var novels: [NovelDTO] = []

    /// 当前选中的小说
    @Published var currentNovel: NovelDTO?

    /// 当前小说的章节列表
    @Published var chapters: [ChapterDTO] = []

    /// 当前选中的章节
    @Published var currentChapter: ChapterDTO?

    /// 加载状态
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - API 客户端

    private let apiClient: APIClient

    // MARK: - 初始化

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 小说 CRUD

    /// 加载小说列表
    func loadNovels() async {
        isLoading = true
        errorMessage = nil

        do {
            novels = try await apiClient.request(APIEndpoint.Novels.list)
            Logger.data.info("加载小说列表成功，共 \(self.novels.count) 部")
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("加载小说列表失败: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// 获取小说详情
    /// - Parameter novelId: 小说 ID
    func loadNovel(_ novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let novel: NovelDTO = try await apiClient.request(APIEndpoint.Novels.get(novelId: novelId))
            currentNovel = novel
            chapters = novel.chapters
            Logger.data.info("加载小说详情成功: \(novel.title)")
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("加载小说详情失败: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// 创建小说
    /// - Parameter request: 创建请求
    /// - Returns: 创建的小说
    @discardableResult
    func createNovel(_ request: CreateNovelRequest) async throws -> NovelDTO {
        let novel: NovelDTO = try await apiClient.request(APIEndpoint.Novels.create, body: request)
        novels.append(novel)
        Logger.data.info("创建小说成功: \(novel.title)")
        return novel
    }

    /// 更新小说
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - request: 更新请求
    func updateNovel(_ novelId: String, request: UpdateNovelRequest) async throws {
        let novel: NovelDTO = try await apiClient.request(APIEndpoint.Novels.update(novelId: novelId), body: request)
        if let index = novels.firstIndex(where: { $0.id == novelId }) {
            novels[index] = novel
        }
        if currentNovel?.id == novelId {
            currentNovel = novel
        }
    }

    /// 更新小说阶段
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - stage: 新阶段
    func updateNovelStage(_ novelId: String, stage: String) async throws {
        let novel: NovelDTO = try await apiClient.request(
            APIEndpoint.Novels.updateStage(novelId: novelId),
            body: UpdateStageRequest(stage: stage)
        )
        if let index = novels.firstIndex(where: { $0.id == novelId }) {
            novels[index] = novel
        }
        if currentNovel?.id == novelId {
            currentNovel = novel
        }
    }

    /// 删除小说
    /// - Parameter novelId: 小说 ID
    func deleteNovel(_ novelId: String) async {
        do {
            try await apiClient.send(APIEndpoint.Novels.delete(novelId: novelId))
            novels.removeAll { $0.id == novelId }
            if currentNovel?.id == novelId {
                currentNovel = nil
                chapters = []
                currentChapter = nil
            }
            Logger.data.info("删除小说成功: \(novelId)")
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("删除小说失败: \(error.localizedDescription)")
        }
    }

    /// 更新全自动模式
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - enabled: 是否开启
    func updateAutoApproveMode(_ novelId: String, enabled: Bool) async throws {
        let novel: NovelDTO = try await apiClient.request(
            APIEndpoint.Novels.updateAutoApproveMode(novelId: novelId),
            body: UpdateAutoApproveRequest(autoApproveMode: enabled)
        )
        if let index = novels.firstIndex(where: { $0.id == novelId }) {
            novels[index] = novel
        }
        if currentNovel?.id == novelId {
            currentNovel = novel
        }
    }

    // MARK: - 章节操作

    /// 加载章节列表（单独请求，因为 chapters 是嵌套在 novel 里的）
    func loadChapters(_ novelId: String) async {
        do {
            chapters = try await apiClient.request(APIEndpoint.Chapters.list(novelId: novelId))
            Logger.data.info("加载章节列表成功，共 \(self.chapters.count) 章")
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("加载章节列表失败: \(error.localizedDescription)")
        }
    }

    /// 获取章节详情
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    func loadChapter(novelId: String, chapterNumber: Int) async {
        do {
            currentChapter = try await apiClient.request(
                APIEndpoint.Chapters.get(novelId: novelId, chapterNumber: chapterNumber)
            )
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("加载章节详情失败: \(error.localizedDescription)")
        }
    }

    /// 选择章节
    /// - Parameter chapter: 章节对象
    func selectChapter(_ chapter: ChapterDTO) {
        currentChapter = chapter
    }

    /// 选择小说
    /// - Parameter novel: 小说对象
    func selectNovel(_ novel: NovelDTO) {
        currentNovel = novel
        chapters = novel.chapters
        currentChapter = nil
    }

    /// 获取小说统计
    /// - Parameter novelId: 小说 ID
    /// - Returns: 统计信息
    func getStatistics(_ novelId: String) async throws -> NovelStatistics {
        return try await apiClient.request(APIEndpoint.Novels.statistics(novelId: novelId))
    }
}
