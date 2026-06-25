//
//  CastStore.swift
//  Cangjie
//
//  人物关系图数据。
//

import SwiftUI
import Foundation

/// Cast Store
@MainActor
final class CastStore: ObservableObject {

    @Published var castGraph: CastGraph?
    @Published var coverage: CastCoverage?
    @Published var searchResults: CastSearchResult?
    @Published var narrativeProfiles: [String: CharacterNarrativeProfile] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载人物关系图
    /// - Parameter novelId: 小说 ID
    func loadCastGraph(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            castGraph = try await apiClient.request(APIEndpoint.Cast.graph(novelId: novelId))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 搜索角色
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - query: 搜索关键词
    func search(novelId: String, query: String) async {
        do {
            // 【修复】修复前构建了带 q 查询参数的 URL 但未使用，
            // 直接调用 download 时丢失了查询参数，导致搜索功能失效。
            // 现在使用 EndpointInfoWrapper 正确传递查询参数。
            let data = try await apiClient.download(
                APIEndpoint.EndpointInfoWrapper(
                    path: "/novels/\(novelId)/cast/search",
                    prefix: APIEndpoint.defaultPrefix,
                    method: .get,
                    queryItems: [URLQueryItem(name: "q", value: query)]
                )
            )
            searchResults = try CangjieDecoder.shared.decode(CastSearchResult.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载覆盖分析
    /// - Parameter novelId: 小说 ID
    func loadCoverage(novelId: String) async {
        do {
            coverage = try await apiClient.request(APIEndpoint.Cast.coverage(novelId: novelId))
        } catch {
            Logger.data.error("加载覆盖分析失败: \(error.localizedDescription)")
        }
    }

    /// 加载角色叙事画像
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - characterId: 角色 ID
    func loadNarrativeProfile(novelId: String, characterId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.Cast.narrativeProfile(novelId: novelId, characterId: characterId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let profile = try? CangjieDecoder.shared.decode(CharacterNarrativeProfile.self, from: data)
                if let profile = profile {
                    narrativeProfiles[characterId] = profile
                }
            }
        } catch {
            Logger.data.error("加载角色叙事画像失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 便捷属性

    var characters: [CastCharacter] {
        return castGraph?.characters ?? []
    }

    var relationships: [CastRelationship] {
        return castGraph?.relationships ?? []
    }

    // MARK: - 批次2 新增：选角调度（对齐 cast.ts:82-96 ChapterCastManager.vue:191-234）

    /// 选角调度响应（scheduleCast 后存储）
    @Published var scheduleResponse: CastScheduleResponse?
    @Published var isScheduling: Bool = false

    /// 选角调度 — 对齐 cast.ts scheduleAndPersist/analyzeOutline
    ///
    /// 原版两个方法底层都是 POST /novels/{id}/cast/schedule，区别在 mode 字段：
    /// - mode="suggest" → analyzeOutline（dry-run，不写库）
    /// - mode="apply" → scheduleAndPersist（写入 chapter_elements）
    ///
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - chapterNumber: 章节号
    ///   - mode: .suggest（预览）或 .apply（落库）— 对齐决策3
    ///   - outline: 大纲文本（可选）
    func scheduleCast(novelId: String, chapterNumber: Int, mode: CastScheduleMode, outline: String? = nil) async {
        isScheduling = true
        errorMessage = nil

        do {
            let request = CastScheduleRequest(
                chapterNumber: chapterNumber,
                outline: outline,
                mode: mode.rawValue
            )
            scheduleResponse = try await apiClient.request(
                APIEndpoint.Cast.schedule(novelId: novelId),
                body: request
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isScheduling = false
    }

    /// 选角调度模式 — 对齐决策3
    enum CastScheduleMode: String {
        case suggest  // dry-run（对齐 analyzeOutline）
        case apply    // 落库（对齐 scheduleAndPersist）
    }
}
