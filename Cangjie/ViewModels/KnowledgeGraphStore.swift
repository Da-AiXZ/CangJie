//
//  KnowledgeGraphStore.swift
//  Cangjie
//
//  三元组查询 + 统计 + 推断证据。
//

import SwiftUI
import Foundation

/// 知识图谱 Store
@MainActor
final class KnowledgeGraphStore: ObservableObject {

    @Published var triples: [KnowledgeTriple] = []
    @Published var statistics: KnowledgeGraphStatistics?
    @Published var searchResults: [KnowledgeSearchHit] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载三元组
    /// - Parameter novelId: 小说 ID
    func loadTriples(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 后端返回可能是数组或字典
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.triples(novelId: novelId)
            )
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                triples = try JSONDecoder().decode([KnowledgeTriple].self, from: data)
            } else if let dict = raw.dictionaryValue, let items = dict["triples"] {
                let data = try JSONSerialization.data(withJSONObject: items)
                triples = try JSONDecoder().decode([KnowledgeTriple].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载统计
    func loadStatistics(novelId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.statistics(novelId: novelId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                statistics = try? JSONDecoder().decode(KnowledgeGraphStatistics.self, from: data)
            }
        } catch {
            Logger.data.error("加载 KG 统计失败: \(error.localizedDescription)")
        }
    }

    /// 搜索
    func search(novelId: String, query: String, topK: Int? = nil) async {
        let request = KnowledgeGraphSearchRequest(query: query, topK: topK)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.KnowledgeGraph.search(novelId: novelId),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? JSONDecoder().decode(KnowledgeSearchResponse.self, from: data)
                searchResults = response?.hits ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 确认三元组
    func confirmTriple(tripleId: String) async {
        do {
            try await apiClient.send(APIEndpoint.KnowledgeGraph.confirmTriple(tripleId: tripleId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除三元组
    func deleteTriple(tripleId: String) async {
        do {
            try await apiClient.send(APIEndpoint.KnowledgeGraph.deleteTriple(tripleId: tripleId))
            triples.removeAll { $0.id == tripleId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 索引
    func index(novelId: String) async {
        do {
            try await apiClient.send(APIEndpoint.KnowledgeGraph.index(novelId: novelId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
