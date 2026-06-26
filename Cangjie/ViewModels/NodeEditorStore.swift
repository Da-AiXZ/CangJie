//
//  NodeEditorStore.swift
//  Cangjie
//
//  DAG 节点 Prompt 编辑器状态管理 — 模板编辑 / 变量注入 / 预览 / 保存。
//  对齐原项目 stores/nodeEditorStore.ts L1-109（10 state + 6 action）。
//

import SwiftUI
import Foundation

/// DAG 节点 Prompt 编辑器 Store — 对齐 nodeEditorStore.ts
@MainActor
final class NodeEditorStore: ObservableObject {

    /// 共享单例（DAGCanvasView 和 NodeEditorView 共享同一实例）
    static let shared = NodeEditorStore()

    // MARK: - State（10 个，对齐 nodeEditorStore.ts:9-27）

    /// 编辑器是否打开 — nodeEditorStore.ts:10
    @Published var isOpen: Bool = false
    /// 当前编辑节点 ID — nodeEditorStore.ts:11
    @Published var nodeId: String?
    /// 当前小说 ID — nodeEditorStore.ts:12
    @Published var novelId: String?
    /// 当前 Prompt 模板文本 — nodeEditorStore.ts:15
    @Published var promptTemplate: String = ""
    /// 原始模板（用于比较是否有改动）— nodeEditorStore.ts:16
    @Published var originalTemplate: String = ""
    /// 变量键值对 — nodeEditorStore.ts:19
    @Published var variables: [String: String] = [:]
    /// 渲染后的预览文本 — nodeEditorStore.ts:22
    @Published var renderedPrompt: String = ""
    /// 服务端预览加载中 — nodeEditorStore.ts:23
    @Published var isPreviewLoading: Bool = false
    /// 保存中 — nodeEditorStore.ts:26
    @Published var isSaving: Bool = false

    // MARK: - 计算属性

    /// 是否有未保存的改动 — nodeEditorStore.ts:27 computed
    var hasUnsavedChanges: Bool {
        return promptTemplate != originalTemplate
    }

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - Actions（6 个，对齐 nodeEditorStore.ts:29-89）

    /// 打开编辑器，初始化状态 — 对齐 nodeEditorStore.ts:31-38
    /// - Parameters:
    ///   - nId: 小说 ID
    ///   - nNodeId: 节点 ID
    ///   - template: Prompt 模板文本
    ///   - vars: 变量键值对
    func open(nId: String, nNodeId: String, template: String, vars: [String: String]) {
        novelId = nId
        nodeId = nNodeId
        promptTemplate = template
        originalTemplate = template
        variables = vars
        isOpen = true
    }

    /// 关闭编辑器，清空状态 — 对齐 nodeEditorStore.ts:40-48
    func close() {
        isOpen = false
        nodeId = nil
        novelId = nil
        promptTemplate = ""
        originalTemplate = ""
        variables = [:]
        renderedPrompt = ""
    }

    /// 调用 GET /dag/{novelId}/nodes/{nodeId}/prompt 获取服务端渲染预览 — 对齐 nodeEditorStore.ts:50-61
    func loadPreview() async {
        // 对齐 nodeEditorStore.ts:51 if (!novelId.value || !nodeId.value) return
        guard let nId = novelId, let nNodeId = nodeId else { return }
        isPreviewLoading = true
        defer { isPreviewLoading = false }

        do {
            // 对齐 dag.ts:66 getRenderedPrompt → GET /dag/{novelId}/nodes/{nodeId}/prompt
            // 返回 { node_id, template, variables, rendered }
            let response: RenderedPromptResponse = try await apiClient.request(
                APIEndpoint.DAG.nodePrompt(novelId: nId, nodeId: nNodeId)
            )
            // 对齐 nodeEditorStore.ts:54 renderedPrompt.value = result.rendered
            renderedPrompt = response.rendered
        } catch {
            // 对齐 nodeEditorStore.ts:56-58 catch → renderedPrompt.value = '预览加载失败'
            renderedPrompt = "预览加载失败"
        }
    }

    /// 本地变量替换（{{key}} → value），不请求后端 — 对齐 nodeEditorStore.ts:63-69
    func renderLocalPreview() {
        // 对齐 nodeEditorStore.ts:64 let rendered = promptTemplate.value
        var rendered = promptTemplate
        // 对齐 nodeEditorStore.ts:65-67 for (const [key, value] of Object.entries(variables.value))
        for (key, value) in variables {
            // 对齐 nodeEditorStore.ts:66 rendered.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), value || `[${key}]`)
            let replacement = value.isEmpty ? "[\(key)]" : value
            rendered = rendered.replacingOccurrences(
                of: "{{\(key)}}",
                with: replacement,
                options: .literal
            )
        }
        // 对齐 nodeEditorStore.ts:68 renderedPrompt.value = rendered
        renderedPrompt = rendered
    }

    /// 调用 PUT /dag/{novelId}/nodes/{nodeId} 保存 prompt_template + prompt_variables — 对齐 nodeEditorStore.ts:71-85
    func save() async throws {
        // 对齐 nodeEditorStore.ts:72 if (!novelId.value || !nodeId.value) return
        guard let nId = novelId, let nNodeId = nodeId else { return }
        isSaving = true
        defer { isSaving = false }

        // 对齐 nodeEditorStore.ts:75-78 dagApi.updateNodeConfig(novelId, nodeId, { prompt_template, prompt_variables })
        let body = NodePromptUpdateBody(
            promptTemplate: promptTemplate,
            promptVariables: variables
        )

        // PUT /dag/{novelId}/nodes/{nodeId}
        try await apiClient.send(APIEndpoint.DAG.updateNode(novelId: nId, nodeId: nNodeId), body: body)

        // 对齐 nodeEditorStore.ts:79 originalTemplate.value = promptTemplate.value
        originalTemplate = promptTemplate
    }

    /// 恢复到 originalTemplate — 对齐 nodeEditorStore.ts:87-89
    func resetToDefault() {
        promptTemplate = originalTemplate
    }
}

// MARK: - 服务端渲染预览响应模型

/// GET /dag/{novelId}/nodes/{nodeId}/prompt 返回结构 — 对齐 dag.ts:67
struct RenderedPromptResponse: Codable {
    let nodeId: String
    let template: String
    let variables: [String: String]
    let rendered: String

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case template
        case variables
        case rendered
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.nodeId = try c.decodeIfPresent(String.self, forKey: .nodeId) ?? ""
        self.template = try c.decodeIfPresent(String.self, forKey: .template) ?? ""
        self.variables = try c.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
        self.rendered = try c.decodeIfPresent(String.self, forKey: .rendered) ?? ""
    }
}

// MARK: - 节点 Prompt 更新请求体

/// PUT /dag/{novelId}/nodes/{nodeId} 请求体 — 对齐 nodeEditorStore.ts:75-78
/// { prompt_template: string, prompt_variables: Record<string, string> }
struct NodePromptUpdateBody: Encodable {
    let promptTemplate: String
    let promptVariables: [String: String]

    enum CodingKeys: String, CodingKey {
        case promptTemplate = "prompt_template"
        case promptVariables = "prompt_variables"
    }
}
