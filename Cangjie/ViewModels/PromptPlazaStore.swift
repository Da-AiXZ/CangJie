//
//  PromptPlazaStore.swift
//  Cangjie
//
//  提示词分类/模板/版本/渲染/调试/对比。
//

import SwiftUI
import Foundation

/// 提示词广场 Store
@MainActor
final class PromptPlazaStore: ObservableObject {

    @Published var plazaInit: PromptPlazaInit?
    @Published var categories: [PromptCategoryInfo] = []
    @Published var nodes: [PromptNode] = []
    @Published var stats: PromptStats?
    @Published var currentNode: PromptNode?
    @Published var versions: [PromptVersion] = []
    @Published var renderResult: PromptRenderResult?
    @Published var debugResult: PromptDebugResult?
    @Published var comparison: PromptComparison?
    @Published var templates: [PromptTemplate] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// 加载广场初始化数据
    func loadPlazaInit() async {
        isLoading = true
        errorMessage = nil

        do {
            plazaInit = try await apiClient.request(APIEndpoint.LLMControl.promptsPlazaInit)
            categories = plazaInit?.categories ?? []
            nodes = plazaInit?.nodes ?? []
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载统计
    func loadStats() async {
        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.LLMControl.promptsStats)
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                stats = try? CangjieDecoder.shared.decode(PromptStats.self, from: data)
            }
        } catch {
            Logger.data.error("加载提示词统计失败: \(error.localizedDescription)")
        }
    }

    /// 加载提示词节点详情
    func loadNode(nodeKey: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptNode(nodeKey: nodeKey)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                currentNode = try? CangjieDecoder.shared.decode(PromptNode.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载版本列表
    func loadVersions(nodeKey: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptVersions(nodeKey: nodeKey)
            )
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                versions = try CangjieDecoder.shared.decode([PromptVersion].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 更新提示词
    func updatePrompt(nodeKey: String, content: String, changeLog: String?) async {
        let request = PromptUpdateRequest(content: content, changeLog: changeLog)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.updatePrompt(nodeKey: nodeKey),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                currentNode = try? CangjieDecoder.shared.decode(PromptNode.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 渲染提示词
    func renderPrompt(nodeKey: String, variables: [String: String]) async {
        let request = PromptRenderRequest(nodeKey: nodeKey, variables: variables)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.renderPrompt(nodeKey: nodeKey),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                renderResult = try? CangjieDecoder.shared.decode(PromptRenderResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 调试提示词
    func debugPrompt(nodeKey: String, variables: [String: String]) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.debugPrompt(nodeKey: nodeKey),
                body: AnyCodable(["variables": variables])
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                debugResult = try? CangjieDecoder.shared.decode(PromptDebugResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 版本对比
    func compareVersions(v1Id: String, v2Id: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.comparePrompts(v1Id: v1Id, v2Id: v2Id)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                comparison = try? CangjieDecoder.shared.decode(PromptComparison.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 回滚提示词
    func rollbackPrompt(nodeKey: String, versionId: String) async {
        do {
            try await apiClient.send(
                APIEndpoint.LLMControl.rollbackPrompt(nodeKey: nodeKey, versionId: versionId)
            )
            await loadVersions(nodeKey: nodeKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 加载模板列表
    func loadTemplates() async {
        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.LLMControl.promptsTemplates)
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                templates = try CangjieDecoder.shared.decode([PromptTemplate].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
