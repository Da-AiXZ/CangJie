//
//  WorldlineStore.swift
//  Cangjie
//
//  世界线 Store，对齐原版 WorldlineDAG.vue:297-758。
//  调真实 /worldline/graph API，管理 graphData/storylines/confluencePoints + 6种git交互。
//

import SwiftUI
import Foundation

/// 世界线 Store — WorldlineDAG.vue:297-758
@MainActor
final class WorldlineStore: ObservableObject {

    // MARK: - Published 状态

    /// 世界线图数据 — WorldlineDAG.vue:299 graphData
    @Published var graphData: WorldlineGraph?
    /// 故事线列表 — WorldlineDAG.vue:302 storylines
    @Published var storylines: [StorylineDTO] = []
    /// 汇流点列表 — WorldlineDAG.vue:303 confluencePoints
    @Published var confluencePoints: [ConfluencePointDTO] = []
    /// 选中节点 ID — WorldlineDAG.vue:304 selectedId
    @Published var selectedId: String?
    /// 加载状态
    @Published var isLoading: Bool = false
    /// 保存中（手动创建存档）
    @Published var isSaving: Bool = false
    /// 操作中状态（checkout/merge/hard-reset/delete）
    @Published var actionLoading: String?
    /// 错误消息
    @Published var errorMessage: String?
    /// 分支命名弹窗
    @Published var showBranchDialog: Bool = false

    // MARK: - 依赖

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    // MARK: - 数据加载 — WorldlineDAG.vue:568-585

    /// 加载世界线图 — WorldlineDAG.vue:568-578 load()
    func loadGraph(novelId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            graphData = try await apiClient.request(
                APIEndpoint.Worldline.graph(novelId: novelId)
            )
        } catch {
            errorMessage = error.localizedDescription
            Logger.data.error("加载世界线图失败: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// 加载故事线列表 — WorldlineDAG.vue:331-338 loadStorylines()
    func loadStorylines(novelId: String) async {
        do {
            storylines = try await apiClient.request(
                APIEndpoint.Workflow.getStorylines(novelId: novelId)
            )
        } catch {
            Logger.data.error("加载故事线列表失败: \(error.localizedDescription)")
        }
    }

    /// 加载汇流点 — WorldlineDAG.vue:340-346 loadConfluencePoints()
    func loadConfluencePoints(novelId: String) async {
        do {
            confluencePoints = try await apiClient.request(
                APIEndpoint.Worldline.confluenceList(novelId: novelId)
            )
        } catch {
            Logger.data.error("加载汇流点失败: \(error.localizedDescription)")
        }
    }

    /// 全量加载 — WorldlineDAG.vue:580-585 watch(slug)
    func loadAll(novelId: String) async {
        async let graph: Void = loadGraph(novelId: novelId)
        async let sl: Void = loadStorylines(novelId: novelId)
        async let cp: Void = loadConfluencePoints(novelId: novelId)
        _ = await (graph, sl, cp)
    }

    // MARK: - 6种 Git 交互 — WorldlineDAG.vue:639-758

    /// 手动创建存档 — WorldlineDAG.vue:639-654 handleManualCheckpoint
    func createManualCheckpoint(novelId: String) async {
        isSaving = true
        errorMessage = nil

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())
        let request = CreateWorldlineCheckpointRequest(
            triggerType: "MANUAL",
            name: "手动存档 \(timestamp)",
            description: nil,
            branchName: nil
        )

        do {
            let _: CreateWorldlineCheckpointResponse = try await apiClient.request(
                APIEndpoint.Worldline.createCheckpoint(novelId: novelId),
                body: request
            )
            await loadGraph(novelId: novelId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    /// 切换到检查点（checkout）— WorldlineDAG.vue:656-670 handleCheckout
    func checkout(novelId: String, checkpointId: String) async -> Bool {
        actionLoading = "checkout"
        errorMessage = nil

        do {
            let _: WorldlineCheckoutResult = try await apiClient.request(
                APIEndpoint.Worldline.checkout(novelId: novelId, checkpointId: checkpointId)
            )
            await loadAll(novelId: novelId)
            actionLoading = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionLoading = nil
            return false
        }
    }

    /// 汇入主线（merge）— WorldlineDAG.vue:672-694 handleMergeBranch
    func mergeBranch(novelId: String, branchId: String, branchName: String) async -> Bool {
        actionLoading = "merge"
        errorMessage = nil

        let request = MergeWorldlineBranchRequest(
            targetBranchName: "main",
            name: "\(branchName) 汇入主线",
            description: nil
        )

        do {
            let _: MergeWorldlineBranchResponse = try await apiClient.request(
                APIEndpoint.Worldline.mergeBranch(novelId: novelId, branchId: branchId),
                body: request
            )
            await loadAll(novelId: novelId)
            actionLoading = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionLoading = nil
            return false
        }
    }

    /// 硬重置（hardReset）— WorldlineDAG.vue:696-719 handleHardReset
    func hardReset(novelId: String, checkpointId: String) async -> Bool {
        actionLoading = "hard-reset"
        errorMessage = nil

        do {
            let _: WorldlineCheckoutResult = try await apiClient.request(
                APIEndpoint.Worldline.hardReset(novelId: novelId, checkpointId: checkpointId)
            )
            await loadAll(novelId: novelId)
            actionLoading = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionLoading = nil
            return false
        }
    }

    /// 删除检查点 — WorldlineDAG.vue:721-735 handleDelete
    func deleteCheckpoint(novelId: String, checkpointId: String) async -> Bool {
        actionLoading = "delete"
        errorMessage = nil

        do {
            try await apiClient.send(
                APIEndpoint.Worldline.deleteCheckpoint(novelId: novelId, checkpointId: checkpointId)
            )
            selectedId = nil
            await loadGraph(novelId: novelId)
            actionLoading = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionLoading = nil
            return false
        }
    }

    /// 创建分支 — WorldlineDAG.vue:737-758 handleCreateBranch
    func createBranch(novelId: String, fromCheckpointId: String, name: String, storylineId: String?) async -> Bool {
        actionLoading = "create-branch"
        errorMessage = nil

        let request = CreateWorldlineBranchRequest(
            name: name,
            fromCheckpointId: fromCheckpointId,
            storylineId: storylineId
        )

        do {
            let _: CreateWorldlineBranchResponse = try await apiClient.request(
                APIEndpoint.Worldline.createBranch(novelId: novelId),
                body: request
            )
            await loadAll(novelId: novelId)
            showBranchDialog = false
            actionLoading = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            actionLoading = nil
            return false
        }
    }

    // MARK: - 选择 — WorldlineDAG.vue:106 selectNode

    /// 选择节点（toggle）
    func selectNode(_ id: String) {
        if selectedId == id {
            selectedId = nil
        } else {
            selectedId = id
        }
    }

    // MARK: - 便捷属性

    /// 选中节点
    var selectedNode: WorldlineCheckpointNode? {
        guard let id = selectedId else { return nil }
        return graphData?.nodes.first { $0.id == id }
    }

    /// 节点列表
    var nodes: [WorldlineCheckpointNode] {
        graphData?.nodes ?? []
    }

    /// 边列表
    var edges: [WorldlineEdge] {
        graphData?.edges ?? []
    }

    /// 分支列表
    var branches: [WorldlineBranchInfo] {
        graphData?.branches ?? []
    }

    /// HEAD ID
    var headId: String? {
        graphData?.headId
    }

    /// 汇流点数
    var confluenceCount: Int {
        confluencePoints.count
    }

    /// 分支数
    var branchCount: Int {
        branches.count
    }
}
