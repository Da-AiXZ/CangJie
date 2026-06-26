//
//  PromptPlazaBridge.swift
//  Cangjie
//
//  DAG ↔ 提示词广场联动桥。
//  对齐原项目 stores/promptPlazaBridge.ts L1-107（8 个 state/method）。
//
//  职责：
//  1. DAG 节点类型 → CPMS node_key：来自后端 NodeMeta.cpms_node_key 与 GET /dag/registry/linkage
//  2. 提供 openPromptInPlaza() 方法，供 DAG 节点调用
//  3. 通过事件通知 PromptPlaza 打开并选中指定提示词
//  4. 提示词保存后回调通知 DAG 刷新
//

import SwiftUI
import Foundation

/// DAG ↔ 提示词广场联动桥 — 对齐 promptPlazaBridge.ts
@MainActor
final class PromptPlazaBridge: ObservableObject {

    /// 共享单例（DAGCanvasView 和 PromptDetailView 共享同一实例）
    static let shared = PromptPlazaBridge()

    // MARK: - State（对齐 promptPlazaBridge.ts:18-20）

    /// 当前需要打开的 nodeKey（由 DAG 节点设置）— promptPlazaBridge.ts:18
    @Published var pendingNodeKey: String?
    /// 是否需要打开广场（由 DAG 节点设置）— promptPlazaBridge.ts:20
    @Published var shouldOpenPlaza: Bool = false

    // MARK: - 回调（对齐 promptPlazaBridge.ts:23）

    /// 提示词保存后回调（DAG 视图注册，用于刷新节点提示词）— promptPlazaBridge.ts:23
    private var onPlazaSaved: ((String) -> Void)?

    // MARK: - 依赖

    /// DAGStore 引用（读取 nodeTypeRegistry / registryLinkage / dagDefinition）
    private weak var dagStore: DAGStore?

    // MARK: - 初始化

    init(dagStore: DAGStore? = nil) {
        self.dagStore = dagStore
    }

    /// 设置 DAGStore 引用（延迟注入，避免循环依赖）
    func setDAGStore(_ store: DAGStore) {
        self.dagStore = store
    }

    // MARK: - Methods（对齐 promptPlazaBridge.ts:26-94）

    /// 动态映射：DAG 节点类型 → CPMS node_key（三级查找）— 对齐 promptPlazaBridge.ts:26-43
    /// - Parameter dagNodeType: DAG 节点类型
    /// - Returns: CPMS node_key，找不到返回 nil
    func getCpmsKey(dagNodeType: String) -> String? {
        guard let dagStore = dagStore else { return nil }

        // 对齐 promptPlazaBridge.ts:30-33 第一级：meta.cpms_node_key
        if let meta = dagStore.nodeTypeRegistry[dagNodeType] {
            if !meta.cpmsNodeKey.isEmpty {
                return meta.cpmsNodeKey
            }
        }

        // 对齐 promptPlazaBridge.ts:34-37 第二级：registryLinkage.nodes.find { $0.node_type == dagNodeType }?.cpms_node_key
        if let linkage = dagStore.registryLinkage {
            if let row = linkage.nodes.first(where: { $0.nodeType == dagNodeType }) {
                if !row.cpmsNodeKey.isEmpty {
                    return row.cpmsNodeKey
                }
            }

            // 对齐 promptPlazaBridge.ts:38-41 第三级：registryLinkage.registry_cpms_by_type[dagNodeType]?.cpms_node_key
            if let entry = linkage.registryCpmsByType[dagNodeType] {
                if !entry.cpmsNodeKey.isEmpty {
                    return entry.cpmsNodeKey
                }
            }
        }

        // 对齐 promptPlazaBridge.ts:42 return null
        return nil
    }

    /// 按画布 node_id 解析 CPMS（先找 node.type 再调 getCpmsKey）— 对齐 promptPlazaBridge.ts:46-52
    /// - Parameter nodeId: 画布节点 ID
    /// - Returns: CPMS node_key，找不到返回 nil
    func getCpmsKeyForNodeId(nodeId: String) -> String? {
        guard let dagStore = dagStore else { return nil }
        // 对齐 promptPlazaBridge.ts:48-49 const dag = dagStore.dagDefinition; if (!dag) return null
        guard let dag = dagStore.dagDefinition else { return nil }
        // 对齐 promptPlazaBridge.ts:50 const node = dag.nodes.find(n => n.id === nodeId)
        guard let node = dag.nodes.first(where: { $0.id == nodeId }) else { return nil }
        // 对齐 promptPlazaBridge.ts:51 return node ? getCpmsKey(node.type) : null
        return getCpmsKey(dagNodeType: node.type)
    }

    /// 打开提示词广场并选中指定节点 — 对齐 promptPlazaBridge.ts:59-68
    /// - Parameters:
    ///   - nodeKey: CPMS node_key 或 DAG 节点类型
    ///   - isDagType: 如果传入的是 DAG 节点类型而非 CPMS key，设为 true
    func openPromptInPlaza(nodeKey: String, isDagType: Bool = false) {
        // 对齐 promptPlazaBridge.ts:60 const cpmsKey = isDagType ? getCpmsKey(nodeKey) : nodeKey
        let cpmsKey: String?
        if isDagType {
            cpmsKey = getCpmsKey(dagNodeType: nodeKey)
        } else {
            cpmsKey = nodeKey
        }

        // 对齐 promptPlazaBridge.ts:61-66 if (cpmsKey) { pendingNodeKey = cpmsKey } else { pendingNodeKey = nodeKey }
        if let key = cpmsKey, !key.isEmpty {
            pendingNodeKey = key
        } else {
            // 对齐 promptPlazaBridge.ts:64-65 即使找不到映射，也打开广场（用户可以自行搜索）
            pendingNodeKey = nodeKey
        }

        // 对齐 promptPlazaBridge.ts:67 shouldOpenPlaza.value = true
        shouldOpenPlaza = true
    }

    /// 消费打开请求（由 PromptPlaza 调用）— 对齐 promptPlazaBridge.ts:73-78
    /// - Returns: 待打开的 nodeKey，消费后重置状态
    func consumeOpenRequest() -> String? {
        // 对齐 promptPlazaBridge.ts:74 const key = pendingNodeKey.value
        let key = pendingNodeKey
        // 对齐 promptPlazaBridge.ts:75-76 shouldOpenPlaza = false; pendingNodeKey = null
        shouldOpenPlaza = false
        pendingNodeKey = nil
        // 对齐 promptPlazaBridge.ts:77 return key
        return key
    }

    /// 注册提示词保存回调（由 DAG 视图调用）— 对齐 promptPlazaBridge.ts:83-85
    /// - Parameter callback: 保存回调闭包
    func setOnPlazaSaved(callback: @escaping (String) -> Void) {
        onPlazaSaved = callback
    }

    /// 提示词广场保存后通知 DAG（由 PromptDetailView 调用）— 对齐 promptPlazaBridge.ts:90-94
    /// - Parameter nodeKey: 已保存的提示词 nodeKey
    func notifyPromptSaved(nodeKey: String) {
        // 对齐 promptPlazaBridge.ts:91-93 if (onPlazaSaved.value) { onPlazaSaved.value(nodeKey) }
        onPlazaSaved?(nodeKey)
    }
}
