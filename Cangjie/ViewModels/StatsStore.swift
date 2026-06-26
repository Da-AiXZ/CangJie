//
//  StatsStore.swift
//  Cangjie
//
//  写作统计 Store，对齐原版 stores/statsStore.ts。
//  3 个 Dictionary 缓存 + force 参数 + onJobCompleted/onChapterSaved/clearCache/clearError。
//  loadBookStats 走 v1 API Novels.statistics（U1 决策）。
//

import SwiftUI
import Foundation

/// 统计 Store，对齐原版 statsStore.ts
@MainActor
final class StatsStore: ObservableObject {

    // MARK: - 状态

    /// 全局统计
    @Published var globalStats: GlobalStats?

    /// 书籍统计缓存（key: slug）— 对齐 statsStore.ts:13 bookStatsCache
    @Published private(set) var bookStatsCache: [String: BookStats] = [:]

    /// 章节统计缓存（key: "slug:chapterId"）— 对齐 statsStore.ts:14 chapterStatsCache
    @Published private(set) var chapterStatsCache: [String: ChapterStats] = [:]

    /// 写作进度缓存（key: "slug:days"）— 对齐 statsStore.ts:15 progressCache
    @Published private(set) var progressCache: [String: [WritingProgress]] = [:]

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Getters（对齐 statsStore.ts:25-50）

    /// 是否有全局统计
    var hasGlobalStats: Bool {
        return globalStats != nil
    }

    /// 获取书籍统计（从缓存）
    func getBookStats(_ slug: String) -> BookStats? {
        return bookStatsCache[slug]
    }

    /// 获取章节统计（从缓存）
    func getChapterStats(_ key: String) -> ChapterStats? {
        return chapterStatsCache[key]
    }

    /// 获取写作进度（从缓存）
    func getProgress(_ slug: String) -> [WritingProgress]? {
        // 尝试匹配 "slug:" 前缀的任意 days 键
        for (key, value) in progressCache {
            if key.hasPrefix("\(slug):") {
                return value
            }
        }
        return nil
    }

    /// 是否已缓存
    func isCached(type: String, key: String? = nil) -> Bool {
        switch type {
        case "global":
            return globalStats != nil
        case "book":
            return key.map { bookStatsCache[$0] != nil } ?? false
        case "chapter":
            return key.map { chapterStatsCache[$0] != nil } ?? false
        case "progress":
            return key.map { progressCache[$0] != nil } ?? false
        default:
            return false
        }
    }

    // MARK: - Actions（对齐 statsStore.ts:60-234）

    /// 加载全局统计 — 对齐 statsStore.ts:60-78 loadGlobalStats
    /// - Parameter force: 强制刷新（忽略缓存）
    func loadGlobalStats(force: Bool = false) async {
        if !force && globalStats != nil {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 后端 stats API 使用 SuccessResponse 封装
            // Stats.global → GET /api/stats/global（T01 修正后的路径）
            let response: StatsSuccessResponse<GlobalStats> = try await apiClient.request(
                APIEndpoint.Stats.global
            )
            globalStats = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载书籍统计 — 对齐 statsStore.ts:85-103 loadBookStats
    /// U1 决策：改调 Novels.statistics（v1 API /api/v1/novels/{slug}/statistics），非 /api/stats/book/{slug}
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - force: 强制刷新（忽略缓存）
    func loadBookStats(slug: String, force: Bool = false) async {
        if !force && bookStatsCache[slug] != nil {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // U1：对齐原项目 statsStore.ts:94 — novelApi.getNovelStatistics(slug)
            // 走 v1 API：GET /api/v1/novels/{slug}/statistics
            let stats: BookStats = try await apiClient.request(
                APIEndpoint.Novels.statistics(novelId: slug)
            )
            bookStatsCache[slug] = stats
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载章节统计 — 对齐 statsStore.ts:111-131 loadChapterStats
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - chapterId: 章节 ID
    ///   - force: 强制刷新（忽略缓存）
    func loadChapterStats(slug: String, chapterId: Int, force: Bool = false) async {
        let cacheKey = "\(slug):\(chapterId)"

        if !force && chapterStatsCache[cacheKey] != nil {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Stats.chapter → GET /api/stats/book/{slug}/chapter/{chapterId}（T01 修正后的路径）
            let response: StatsSuccessResponse<ChapterStats> = try await apiClient.request(
                APIEndpoint.Stats.chapter(slug: slug, chapterId: chapterId)
            )
            chapterStatsCache[cacheKey] = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载写作进度 — 对齐 statsStore.ts:139-159 loadProgress
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - days: 天数（默认 30）
    ///   - force: 强制刷新（忽略缓存）
    func loadProgress(slug: String, days: Int = 30, force: Bool = false) async {
        let cacheKey = "\(slug):\(days)"

        if !force && progressCache[cacheKey] != nil {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Stats.progress → GET /api/stats/book/{slug}/progress?days={days}（T01 修正后的路径）
            let response: StatsSuccessResponse<[WritingProgress]> = try await apiClient.request(
                APIEndpoint.Stats.progress(slug: slug, days: days)
            )
            progressCache[cacheKey] = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 并行加载书籍统计 + 写作进度 — 对齐 statsStore.ts:167-193 loadBookAllStats
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - days: 天数（默认 30）
    ///   - force: 强制刷新（忽略缓存）
    func loadBookAllStats(slug: String, days: Int = 30, force: Bool = false) async {
        let bookCached = bookStatsCache[slug] != nil
        let progressCacheKey = "\(slug):\(days)"
        let progressCached = progressCache[progressCacheKey] != nil

        if !force && bookCached && progressCached {
            return
        }

        isLoading = true
        errorMessage = nil

        // 并行加载（对齐原版 Promise.all）
        async let bookStatsTask: Void = loadBookStats(slug: slug, force: force)
        async let progressTask: Void = loadProgress(slug: slug, days: days, force: force)
        _ = await (bookStatsTask, progressTask)

        isLoading = false
    }

    /// 清除所有缓存 — 对齐 statsStore.ts:198-203 clearCache
    func clearCache() {
        globalStats = nil
        bookStatsCache.removeAll()
        chapterStatsCache.removeAll()
        progressCache.removeAll()
    }

    /// 清除错误状态 — 对齐 statsStore.ts:208-210 clearError
    func clearError() {
        errorMessage = nil
    }

    /// 任务完成后失效缓存并重载 — 对齐 statsStore.ts:216-222 onJobCompleted
    /// - Parameter slug: 小说 slug
    func onJobCompleted(slug: String) {
        bookStatsCache.removeValue(forKey: slug)
        Task {
            await loadBookStats(slug: slug, force: true)
            await loadGlobalStats(force: true)
        }
    }

    /// 章节保存后失效缓存并重载 — 对齐 statsStore.ts:229-234 onChapterSaved
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - chapterId: 章节 ID
    func onChapterSaved(slug: String, chapterId: Int) {
        bookStatsCache.removeValue(forKey: slug)
        Task {
            await loadBookStats(slug: slug, force: true)
        }
    }
}

// MARK: - EndpointInfoWrapper

extension APIEndpoint {
    /// 包装器，用于动态创建端点信息
    struct EndpointInfoWrapper: EndpointInfo {
        let path: String
        let method: HTTPMethod
        var prefix: String
        var queryItems: [URLQueryItem]

        init(path: String, prefix: String = APIEndpoint.defaultPrefix, method: HTTPMethod = .get, queryItems: [URLQueryItem] = []) {
            self.path = path
            self.prefix = prefix
            self.method = method
            self.queryItems = queryItems
        }
    }
}
