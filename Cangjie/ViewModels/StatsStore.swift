//
//  StatsStore.swift
//  Cangjie
//
//  写作统计。
//

import SwiftUI
import Foundation

/// 统计 Store
@MainActor
final class StatsStore: ObservableObject {

    @Published var globalStats: GlobalStats?
    @Published var bookStats: BookStats?
    @Published var chapterStats: ChapterStats?
    @Published var writingProgress: [WritingProgress] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载全局统计
    func loadGlobalStats() async {
        isLoading = true
        errorMessage = nil

        do {
            // 后端 stats API 使用 SuccessResponse 封装
            let response: StatsSuccessResponse<GlobalStats> = try await apiClient.request(
                APIEndpoint.Stats.global
            )
            globalStats = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载书籍统计
    /// - Parameter slug: 小说 slug
    func loadBookStats(slug: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 构建自定义 URL（stats 路由使用 /book/{slug}）
            guard let url = APIConfig.shared.fullURL(path: "/book/\(slug)", prefix: APIConfig.statsPrefix) else {
                errorMessage = "无效的 URL"
                isLoading = false
                return
            }

            // 【修复】使用配置微秒日期格式的共享解码器
            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(path: "/book/\(slug)", prefix: APIConfig.statsPrefix, method: .get)
            )
            let response = try CangjieDecoder.shared.decode(StatsSuccessResponse<BookStats>.self, from: data)
            bookStats = response.data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载章节统计
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - chapterId: 章节 ID
    func loadChapterStats(slug: String, chapterId: Int) async {
        do {
            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/book/\(slug)/chapter/\(chapterId)",
                    prefix: APIConfig.statsPrefix, method: .get
                )
            )
            // 【修复】使用配置微秒日期格式的共享解码器
            let response = try CangjieDecoder.shared.decode(StatsSuccessResponse<ChapterStats>.self, from: data)
            chapterStats = response.data
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载写作进度
    /// - Parameters:
    ///   - slug: 小说 slug
    ///   - days: 天数
    func loadWritingProgress(slug: String, days: Int = 30) async {
        do {
            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/book/\(slug)/progress",
                    prefix: APIConfig.statsPrefix, method: .get,
                    queryItems: [URLQueryItem(name: "days", value: String(days))]
                )
            )
            // 【修复】使用配置微秒日期格式的共享解码器
            let response = try CangjieDecoder.shared.decode(StatsSuccessResponse<[WritingProgress]>.self, from: data)
            writingProgress = response.data
        } catch {
            errorMessage = error.localizedDescription
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
