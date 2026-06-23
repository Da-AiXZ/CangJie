//
//  StructureStore.swift
//  Cangjie
//
//  故事结构树 CRUD + 拖拽排序。
//

import SwiftUI
import Foundation

/// 故事结构 Store
@MainActor
final class StructureStore: ObservableObject {

    @Published var tree: [StoryNode] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载结构树
    /// - Parameter novelId: 小说 ID
    func loadTree(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.StoryStructure.get(novelId: novelId)
            )
            // 后端返回可能是节点数组或嵌套树
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                tree = try JSONDecoder().decode([StoryNode].self, from: data)
            } else if let dict = raw.dictionaryValue {
                let nodesData = try JSONSerialization.data(withJSONObject: dict["nodes"] ?? dict["children"] ?? [])
                tree = try JSONDecoder().decode([StoryNode].self, from: nodesData)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 创建节点
    func createNode(novelId: String, request: CreateNodeRequest) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.StoryStructure.createNode(novelId: novelId),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let node = try? JSONDecoder().decode(StoryNode.self, from: data)
                if let node = node {
                    tree.append(node)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 更新节点
    func updateNode(novelId: String, nodeId: String, request: UpdateNodeRequest) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.StoryStructure.updateNode(novelId: novelId, nodeId: nodeId),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let updated = try? JSONDecoder().decode(StoryNode.self, from: data)
                if let updated = updated, let index = tree.firstIndex(where: { $0.id == nodeId }) {
                    tree[index] = updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 删除节点
    func deleteNode(novelId: String, nodeId: String) async {
        do {
            try await apiClient.send(APIEndpoint.StoryStructure.deleteNode(novelId: novelId, nodeId: nodeId))
            tree.removeAll { $0.id == nodeId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 重排序
    func reorder(novelId: String, nodeIds: [String]) async {
        let request = ReorderRequest(nodeIds: nodeIds)

        do {
            try await apiClient.send(APIEndpoint.StoryStructure.reorder(novelId: novelId), body: request)
            // 重新排序本地数据
            tree.sort { (a, b) in
                let aIndex = nodeIds.firstIndex(of: a.id) ?? Int.max
                let bIndex = nodeIds.firstIndex(of: b.id) ?? Int.max
                return aIndex < bIndex
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 创建默认结构
    func createDefault(novelId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.StoryStructure.createDefault(novelId: novelId)
            )
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                tree = try JSONDecoder().decode([StoryNode].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
