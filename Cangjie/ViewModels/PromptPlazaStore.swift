//
//  PromptPlazaStore.swift
//  Cangjie
//
//  提示词广场 Store：分类/模板/节点/版本/渲染/调试/对比/沙盒/变量/绑定/导入导出。
//  阶段2 完全重写——补齐原版 llmControl.ts:356-476 全部 23 个 API 方法。
//

import SwiftUI
import Foundation

/// 提示词广场 Store
@MainActor
final class PromptPlazaStore: ObservableObject {

    // MARK: - 状态

    /// 广场初始化结果（PlazaInitResult: stats + categories + nodesByCategory）
    @Published var plazaInit: PlazaInitResult?
    /// 分类列表
    @Published var categories: [PromptCategoryInfo] = []
    /// 全部节点（从 nodesByCategory 扁平化，供列表筛选用）
    @Published var nodes: [PromptNode] = []
    /// 统计信息
    @Published var stats: PromptStats?
    /// 当前节点详情
    @Published var currentNodeDetail: PromptNodeDetail?
    /// 版本列表
    @Published var versions: [PromptVersion] = []
    /// 版本详情
    @Published var currentVersionDetail: PromptVersionDetail?
    /// 渲染结果
    @Published var renderResult: RenderResult?
    /// 调试结果
    @Published var debugResult: DebugResult?
    /// 版本对比结果
    @Published var comparison: VersionCompareResult?
    /// 模板列表
    @Published var templates: [PromptTemplate] = []
    /// COT 调用链结果
    @Published var chainResult: PromptChainResult?
    /// 沙盒渲染结果
    @Published var sandboxResult: SandboxResult?
    /// 变量列表
    @Published var variables: [VariableSchema] = []
    /// 节点绑定结果
    @Published var bindings: NodeBindingsResult?
    /// 导入结果
    @Published var importResult: ImportResponse?
    /// 导出数据
    @Published var exportData: [String: AnyCodable] = [:]
    /// 是否正在加载
    @Published var isLoading: Bool = false
    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 广场初始化（llmControl.ts:358 plazaInit）

    /// 加载广场初始化数据（GET /llm-control/prompts/plaza-init）
    func loadPlazaInit() async {
        isLoading = true
        errorMessage = nil

        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.LLMControl.promptsPlazaInit)
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                plazaInit = try? CangjieDecoder.shared.decode(PlazaInitResult.self, from: data)
                categories = plazaInit?.categories ?? []
                // 从 nodesByCategory 扁平化节点列表
                nodes = (plazaInit?.nodesByCategory ?? [:]).values.flatMap { $0 }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 统计（llmControl.ts:361 getStats）

    /// 加载统计（GET /llm-control/prompts/stats）
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

    // MARK: - 分类信息（llmControl.ts:364 getCategoriesInfo）

    /// 加载分类信息（GET /llm-control/prompts/categories-info）
    func loadCategoriesInfo() async {
        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.LLMControl.promptsCategoriesInfo)
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                categories = try CangjieDecoder.shared.decode([PromptCategoryInfo].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 模板列表（llmControl.ts:367 listTemplates）

    /// 加载模板列表（GET /llm-control/prompts/templates）
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

    // MARK: - 创建模板（llmControl.ts:370 createTemplate）

    /// 创建模板包（POST /llm-control/prompts/templates）
    func createTemplate(_ payload: CreateTemplatePayload) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.createTemplate,
                body: payload
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? CangjieDecoder.shared.decode(CreateTemplateResponse.self, from: data)
                if let template = response?.template {
                    templates.append(template)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 节点列表（llmControl.ts:374 listNodes）

    /// 列举节点（GET /llm-control/prompts?category=&template_id=&search=）
    /// Store 层手动构建 URL query（决策2）
    func listNodes(category: String? = nil, templateId: String? = nil, search: String? = nil) async -> [PromptNode] {
        do {
            var queryItems: [URLQueryItem] = []
            if let category = category { queryItems.append(URLQueryItem(name: "category", value: category)) }
            if let templateId = templateId { queryItems.append(URLQueryItem(name: "template_id", value: templateId)) }
            if let search = search { queryItems.append(URLQueryItem(name: "search", value: search)) }

            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.prompts
            )
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                return (try? CangjieDecoder.shared.decode([PromptNode].self, from: data)) ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return []
    }

    // MARK: - 按分类获取节点（llmControl.ts:384 listNodesByCategory）

    /// 按分类分组获取节点（GET /llm-control/prompts/by-category）
    func loadNodesByCategory() async -> [String: [PromptNode]] {
        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.LLMControl.promptsByCategory)
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                return (try? CangjieDecoder.shared.decode([String: [PromptNode]].self, from: data)) ?? [:]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        return [:]
    }

    // MARK: - 节点详情（llmControl.ts:388 getNodeDetail）

    /// 加载节点详情（GET /llm-control/prompts/{nodeKey}）
    func loadNodeDetail(nodeKey: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptNode(nodeKey: nodeKey)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                currentNodeDetail = try? CangjieDecoder.shared.decode(PromptNodeDetail.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 创建节点（llmControl.ts:392 createNode）

    /// 创建自定义节点（POST /llm-control/prompts/nodes）
    func createNode(_ payload: CreateNodePayload) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.createPromptNode,
                body: payload
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? CangjieDecoder.shared.decode(CreateNodeResponse.self, from: data)
                if let node = response?.node {
                    nodes.append(node)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 删除节点（llmControl.ts:396 deleteNode）

    /// 删除自定义节点（DELETE /llm-control/prompts/nodes/{nodeId}）
    func deleteNode(nodeId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.deletePromptNode(nodeId: nodeId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? CangjieDecoder.shared.decode(DeleteNodeResponse.self, from: data)
                if response != nil {
                    nodes.removeAll { $0.id == nodeId }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 版本历史（llmControl.ts:402 getNodeVersions）

    /// 加载版本列表（GET /llm-control/prompts/{nodeKey}/versions）
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

    // MARK: - 版本详情（llmControl.ts:406 getVersionDetail）

    /// 加载版本详情（GET /llm-control/prompts/versions/{versionId}）
    func loadVersionDetail(versionId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptVersion(versionId: versionId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                currentVersionDetail = try? CangjieDecoder.shared.decode(PromptVersionDetail.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 更新节点（llmControl.ts:410 updateNode）

    /// 更新提示词（PUT /llm-control/prompts/{nodeKey}）
    func updateNode(nodeKey: String, payload: PromptUpdatePayload) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.updatePrompt(nodeKey: nodeKey),
                body: payload
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? CangjieDecoder.shared.decode(UpdateNodeResponse.self, from: data)
                // 更新后重新加载节点详情
                if response?.node != nil {
                    await loadNodeDetail(nodeKey: nodeKey)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 回滚节点（llmControl.ts:416 rollbackNode）

    /// 回滚提示词到指定版本（POST /llm-control/prompts/{nodeKey}/rollback/{versionId}）
    func rollbackNode(nodeKey: String, versionId: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.rollbackPrompt(nodeKey: nodeKey, versionId: versionId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let response = try? CangjieDecoder.shared.decode(RollbackNodeResponse.self, from: data)
                if response != nil {
                    await loadVersions(nodeKey: nodeKey)
                    await loadNodeDetail(nodeKey: nodeKey)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 版本对比（llmControl.ts:422 compareVersions）

    /// 版本对比（GET /llm-control/prompts/compare/{v1Id}/{v2Id}）
    func compareVersions(v1Id: String, v2Id: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.comparePrompts(v1Id: v1Id, v2Id: v2Id)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                comparison = try? CangjieDecoder.shared.decode(VersionCompareResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 渲染提示词（llmControl.ts:428 renderPrompt）

    /// 渲染提示词（POST /llm-control/prompts/{nodeKey}/render）
    /// 请求体：{ variables: Record<string, unknown> }，nodeKey 在 URL 路径中
    func renderPrompt(nodeKey: String, variables: [String: AnyCodable]) async {
        let payload = RenderPayload(variables: variables)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.renderPrompt(nodeKey: nodeKey),
                body: payload
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                renderResult = try? CangjieDecoder.shared.decode(RenderResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 导出（llmControl.ts:437 exportAll）

    /// 导出所有提示词（GET /llm-control/prompts/export）
    func exportAll() async {
        do {
            let raw: AnyCodable = try await apiClient.request(APIEndpoint.LLMControl.exportPrompts)
            exportData = raw.dictionaryValue ?? [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 导入（llmControl.ts:441 importData）

    /// 导入提示词 JSON（POST /llm-control/prompts/import）
    func importData(payload: [String: AnyCodable]) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.importPrompts,
                body: AnyCodable(payload)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                importResult = try? CangjieDecoder.shared.decode(ImportResponse.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 调试（llmControl.ts:450 debugNode）

    /// 调试提示词（POST /llm-control/prompts/{nodeKey}/debug）
    /// 请求体：{ variables, validate_schemas: true }（决策3：validate_schemas 固定为 true）
    func debugNode(nodeKey: String, variables: [String: AnyCodable]) async {
        let request = DebugRequest(variables: variables, validateSchemas: true)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.debugPrompt(nodeKey: nodeKey),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                debugResult = try? CangjieDecoder.shared.decode(DebugResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - COT 调用链（llmControl.ts:457 getPromptChain）

    /// 获取节点调用链（GET /llm-control/prompts/{nodeKey}/chain）
    func loadChain(nodeKey: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptChain(nodeKey: nodeKey)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                chainResult = try? CangjieDecoder.shared.decode(PromptChainResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 沙盒渲染（llmControl.ts:461 sandboxRender）

    /// 沙盒渲染校验（POST /llm-control/prompts/{nodeKey}/sandbox）
    /// 请求体：{ system, user_template, variables }
    func sandboxRender(nodeKey: String, system: String, userTemplate: String, variables: [String: AnyCodable]) async {
        let request = SandboxRenderRequest(system: system, userTemplate: userTemplate, variables: variables)

        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptSandbox(nodeKey: nodeKey),
                body: request
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                sandboxResult = try? CangjieDecoder.shared.decode(SandboxResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 全局变量（llmControl.ts:468 listVariables）

    /// 获取全局变量注册表（GET /llm-control/prompts/variables?node_key=）
    /// Store 层手动构建 URL query（决策2）
    func loadVariables(nodeKey: String? = nil) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptVariables
            )
            if let array = raw.arrayValue {
                let data = try JSONSerialization.data(withJSONObject: array)
                variables = try CangjieDecoder.shared.decode([VariableSchema].self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 节点绑定（llmControl.ts:474 getNodeBindings）

    /// 获取节点绑定关系（GET /llm-control/prompts/{nodeKey}/bindings）
    func loadBindings(nodeKey: String) async {
        do {
            let raw: AnyCodable = try await apiClient.request(
                APIEndpoint.LLMControl.promptBindings(nodeKey: nodeKey)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                bindings = try? CangjieDecoder.shared.decode(NodeBindingsResult.self, from: data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 便捷属性

    /// 当前选中的节点（从 currentNodeDetail 中取基本信息）
    var currentNode: PromptNode? {
        guard let detail = currentNodeDetail else { return nil }
        return PromptNode(
            id: detail.id,
            nodeKey: detail.nodeKey,
            name: detail.name,
            description: detail.description,
            category: detail.category,
            source: detail.source,
            outputFormat: detail.outputFormat,
            contractModule: detail.contractModule,
            contractModel: detail.contractModel,
            tags: detail.tags,
            variables: detail.variables,
            variableNames: detail.variableNames,
            systemFile: detail.systemFile,
            isBuiltin: detail.isBuiltin,
            sortOrder: detail.sortOrder,
            templateId: detail.templateId,
            versionCount: detail.versionCount,
            systemPreview: detail.systemPreview,
            userTemplatePreview: detail.userTemplatePreview,
            hasUserEdit: detail.hasUserEdit
        )
    }
}
