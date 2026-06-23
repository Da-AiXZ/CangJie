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
            var url = APIEndpoint.Cast.search(novelId: novelId).url()!
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "q", value: query)]
            url = components?.url ?? url

            let request = apiClient.authMiddleware.makeAuthenticatedRequest(
                url: url, method: .get
            )
            // 使用 download 方法
            let data = try await apiClient.download(APIEndpoint.Cast.search(novelId: novelId))
            searchResults = try JSONDecoder().decode(CastSearchResult.self, from: data)
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
                let profile = try? JSONDecoder().decode(CharacterNarrativeProfile.self, from: data)
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
}
