//
//  DAGStore.swift
//  Cangjie
//
//  DAG 定义获取 + DAG 事件 SSE + 节点状态更新。
//

import SwiftUI
import Foundation

/// DAG Store
@MainActor
final class DAGStore: ObservableObject {

    // MARK: - 状态

    @Published var dagDefinition: DAGDefinition?
    @Published var dagStatus: DAGStatusResponse?
    @Published var nodeEvents: [DAGEvent] = []
    @Published var isLoading: Bool = false
    @Published var sseConnected: Bool = false
    @Published var errorMessage: String?

    // MARK: - T04 新增状态（对齐 dagStore.ts:26-44）

    /// 节点类型注册表 — 对齐 dagStore.ts:26 nodeTypeRegistry
    @Published var nodeTypeRegistry: [String: NodeMeta] = [:]
    /// 后端 linkage_kernel 导出 — 对齐 dagStore.ts:28 registryLinkage
    @Published var registryLinkage: DagRegistryLinkageResponse?
    /// 默认 DAG 中未在 NodeRegistry 注册的类型 — 对齐 dagStore.ts:30 registryGaps
    @Published var registryGaps: [DagRegistryGapItem] = []
    /// linkage 加载是否失败 — 对齐 dagStore.ts:32 registryLinkageFailed
    @Published var registryLinkageFailed: Bool = false
    /// 节点实时提示词缓存（按 nodeId） — 对齐 dagStore.ts:41 nodePromptLive
    @Published var nodePromptLive: [String: NodePromptLive] = [:]
    /// 当前选中节点 ID — 对齐 dagStore.ts:44 selectedNodeId
    @Published var selectedNodeId: String?

    // MARK: - 依赖

    private let apiClient: APIClient
    private let sseRegistry: SSEStreamRegistry

    init(apiClient: APIClient = .shared, sseRegistry: SSEStreamRegistry = .shared) {
        self.apiClient = apiClient
        self.sseRegistry = sseRegistry
    }

    // MARK: - DAG 定义

    /// 加载 DAG 定义
    /// - Parameter novelId: 小说 ID
    func loadDAG(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            dagDefinition = try await apiClient.request(APIEndpoint.DAG.get(novelId: novelId))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载 DAG 运行状态
    /// - Parameter novelId: 小说 ID
    func loadDAGStatus(novelId: String) async {
        do {
            dagStatus = try await apiClient.request(APIEndpoint.DAG.status(novelId: novelId))
        } catch {
            Logger.data.error("加载 DAG 状态失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 节点操作

    /// 切换节点启禁用
    /// - Parameters:
    ///   - novelId: 小说 ID
    ///   - nodeId: 节点 ID
    func toggleNode(novelId: String, nodeId: String) async {
        do {
            let updatedDag: DAGDefinition = try await apiClient.request(
                APIEndpoint.DAG.toggleNode(novelId: novelId, nodeId: nodeId)
            )
            dagDefinition = updatedDag
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - T04 新增：节点类型注册表（对齐 dagStore.ts:181-199 loadNodeTypeRegistry）

    /// 加载节点类型注册表 + linkage — 对齐 dagStore.ts:181-199
    /// GET /dag/registry/types + GET /dag/registry/linkage（Promise.allSettled 模拟）
    func loadNodeTypeRegistry() async {
        // 对齐 dagStore.ts:182-185 Promise.allSettled
        // 用 async 并行 + 独立 try-catch 模拟 allSettled
        async let typesResult: NodeTypeRegistryResponse? = {
            do {
                return try await apiClient.request(APIEndpoint.DAG.registryTypes)
            } catch {
                Logger.data.error("加载节点注册表失败: \(error.localizedDescription)")
                return nil
            }
        }()

        async let linkageResult: DagRegistryLinkageResponse? = {
            do {
                return try await apiClient.request(APIEndpoint.DAG.registryLinkage)
            } catch {
                Logger.data.error("加载 linkage 失败: \(error.localizedDescription)")
                return nil
            }
        }()

        let (typesRes, linkRes) = await (typesResult, linkageResult)

        // 对齐 dagStore.ts:186-188 typesR.status === 'fulfilled'
        if let types = typesRes {
            nodeTypeRegistry = types.types
        }

        // 对齐 dagStore.ts:189-198 linkR.status === 'fulfilled' / rejected
        if let link = linkRes {
            registryLinkage = link
            registryLinkageFailed = false
            if let gaps = link.registryGaps, !gaps.missing.isEmpty {
                registryGaps = gaps.missing
            } else {
                registryGaps = []
            }
        } else {
            registryLinkage = nil
            registryLinkageFailed = true
            computeRegistryGapsLocal()
        }
    }

    // MARK: - T04 新增：并行加载 DAG + 注册表 + linkage（对齐 dagStore.ts:128-166 hydrateDagForNovel）

    /// 并行加载 DAG + 注册表 + linkage（首屏推荐） — 对齐 dagStore.ts:128-166
    func hydrateDagForNovel(novelId: String) async {
        isLoading = true
        errorMessage = nil
        registryLinkageFailed = false

        // 对齐 dagStore.ts:133-137 Promise.allSettled([getDAG, listNodeTypes, getRegistryLinkage])
        async let dagResult: DAGDefinition? = {
            do {
                return try await apiClient.request(APIEndpoint.DAG.get(novelId: novelId))
            } catch {
                return nil
            }
        }()

        async let typesResult: NodeTypeRegistryResponse? = {
            do {
                return try await apiClient.request(APIEndpoint.DAG.registryTypes)
            } catch {
                return nil
            }
        }()

        async let linkageResult: DagRegistryLinkageResponse? = {
            do {
                return try await apiClient.request(APIEndpoint.DAG.registryLinkage)
            } catch {
                return nil
            }
        }()

        let (dagR, typesR, linkR) = await (dagResult, typesResult, linkageResult)

        // 对齐 dagStore.ts:138-145 dagR
        if let dag = dagR {
            dagDefinition = dag
            errorMessage = nil
        } else {
            dagDefinition = nil
            errorMessage = "加载 DAG 失败"
        }

        // 对齐 dagStore.ts:146-148 typesR
        if let types = typesR {
            nodeTypeRegistry = types.types
        }

        // 对齐 dagStore.ts:149-162 linkR
        if let link = linkR {
            registryLinkage = link
            registryLinkageFailed = false
            if let gaps = link.registryGaps, !gaps.missing.isEmpty {
                registryGaps = gaps.missing
            } else {
                registryGaps = []
            }
        } else {
            registryLinkage = nil
            registryLinkageFailed = true
            if dagR != nil && typesR != nil {
                computeRegistryGapsLocal()
            } else {
                registryGaps = []
            }
        }

        isLoading = false
    }

    // MARK: - T04 新增：本地计算注册表缺口（对齐 dagStore.ts:115-125 computeRegistryGapsLocal）

    /// 本地计算注册表缺口 — 对齐 dagStore.ts:115-125
    private func computeRegistryGapsLocal() {
        guard let dag = dagDefinition, !nodeTypeRegistry.isEmpty else {
            registryGaps = []
            return
        }
        registryGaps = dag.nodes
            .filter { nodeTypeRegistry[$0.type] == nil }
            .map { DagRegistryGapItem(nodeId: $0.id, nodeType: $0.type) }
    }

    // MARK: - T04 新增：加载节点实时提示词（对齐 dagStore.ts:312-320 loadNodePromptLive）

    /// 加载节点实时提示词 — 对齐 dagStore.ts:312-320
    /// GET /dag/{novel_id}/nodes/{node_id}/prompt-live
    func loadNodePromptLive(novelId: String, nodeId: String) async -> NodePromptLive? {
        do {
            let result: NodePromptLive = try await apiClient.request(
                APIEndpoint.DAG.nodePromptLive(novelId: novelId, nodeId: nodeId)
            )
            // 对齐 dagStore.ts:315 nodePromptLive.value.set(nodeId, result)
            nodePromptLive[nodeId] = result
            return result
        } catch {
            // 对齐 dagStore.ts:317-319 catch → return null
            Logger.data.error("加载节点提示词失败 (\(nodeId)): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - T04 新增：更新节点配置（内存更新，不走 API）（对齐 dagStore.ts:290-305）

    /// 更新节点运行参数 — 对齐 dagStore.ts:290-305
    /// ★ 照搬原版：只做内存更新，不走 PUT API（原版注释"暂时直接更新内存中的DAG定义（不走数据库）"）
    func updateNodeConfig(novelId: String, nodeId: String, config: [String: Any]) {
        // 对齐 dagStore.ts:293-301
        guard let dag = dagDefinition else { return }
        guard let index = dag.nodes.firstIndex(where: { $0.id == nodeId }) else { return }

        // 合并配置（对齐 dagStore.ts:296-300）
        if let temperature = config["temperature"] as? Double {
            dagDefinition?.nodes[index].config?.temperature = temperature
        }
        // 对齐 dagStore.ts:297 — 只有 key 存在时才更新
        if let maxTokens = config["max_tokens"] as? Int {
            dagDefinition?.nodes[index].config?.maxTokens = maxTokens
        }
        if let timeoutSeconds = config["timeout_seconds"] as? Int {
            dagDefinition?.nodes[index].config?.timeoutSeconds = timeoutSeconds
        }
        if let maxRetries = config["max_retries"] as? Int {
            dagDefinition?.nodes[index].config?.maxRetries = maxRetries
        }
        if let modelOverride = config["model_override"] as? String {
            dagDefinition?.nodes[index].config?.modelOverride = modelOverride
        }
    }

    // MARK: - SSE 订阅

    /// P0-8：DAGRunStore 引用（事件分发委托）
    private weak var dagRunStore: DAGRunStore?

    /// 设置 DAGRunStore 引用（延迟注入）
    func setDAGRunStore(_ store: DAGRunStore) {
        self.dagRunStore = store
    }

    /// 启动 DAG 事件 SSE — P0-8 修改：事件处理改为调用 DAGRunStore 分发
    /// - Parameter novelId: 小说 ID
    func startDAGEvents(novelId: String) {
        sseRegistry.startDAGEvents(
            novelId: novelId,
            onEvent: { [weak self] event in
                Task { @MainActor in
                    self?.handleDAGEvent(event)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        )
        sseConnected = true
    }

    /// 停止 DAG 事件 SSE
    /// - Parameter novelId: 小说 ID
    func stopDAGEvents(novelId: String) {
        sseRegistry.cancelStream(type: .dagEvents, novelId: novelId)
        sseConnected = false
    }

    /// 处理 DAG 事件 — P0-8 修改：事件分发委托给 DAGRunStore
    private func handleDAGEvent(_ event: SSEEvent) {
        // DAG 事件使用 event+data 格式
        guard let dagEvent = try? event.decode(DAGEvent.self) else { return }

        // 忽略心跳和连接事件
        if dagEvent.type == "heartbeat" || dagEvent.type == "connected" {
            return
        }

        // P0-8：事件分发委托给 DAGRunStore（如果已注入）
        // 传递原始 SSEEvent，让 DAGRunStore 正确处理 dag_run_complete 等特殊事件
        if let runStore = dagRunStore {
            runStore.dispatchSSEEvent(event)
        }

        // 保留原有事件追加逻辑（向后兼容）
        nodeEvents.append(dagEvent)

        // 保留最近 100 条
        if nodeEvents.count > 100 {
            nodeEvents.removeFirst(nodeEvents.count - 100)
        }

        // 节点状态变更时刷新状态
        if dagEvent.type == "node_status_change" {
            if let novelId = dagEvent.novelId.isEmpty ? nil : dagEvent.novelId {
                Task { await self.loadDAGStatus(novelId: novelId) }
            }
        }
    }

    // MARK: - 便捷属性

    /// 节点列表
    var nodes: [NodeDefinition] {
        return dagDefinition?.nodes ?? []
    }

    /// 边列表
    var edges: [EdgeDefinition] {
        return dagDefinition?.edges ?? []
    }

    /// 节点状态字典
    var nodeStates: [String: NodeRunState] {
        return dagStatus?.nodeStates ?? [:]
    }

    // MARK: - T04 新增：选择节点（对齐 dagStore.ts:281-283 selectNode）

    /// 选择节点 — 对齐 dagStore.ts:281-283
    func selectNode(_ nodeId: String?) {
        selectedNodeId = nodeId
    }
}
