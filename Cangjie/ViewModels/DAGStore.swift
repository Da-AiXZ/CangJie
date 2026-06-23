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

    // MARK: - SSE 订阅

    /// 启动 DAG 事件 SSE
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

    /// 处理 DAG 事件
    private func handleDAGEvent(_ event: SSEEvent) {
        // DAG 事件使用 event+data 格式
        guard let dagEvent = try? event.decode(DAGEvent.self) else { return }

        // 忽略心跳和连接事件
        if dagEvent.type == "heartbeat" || dagEvent.type == "connected" {
            return
        }

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
}
