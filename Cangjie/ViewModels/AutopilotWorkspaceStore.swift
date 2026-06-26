//
//  AutopilotWorkspaceStore.swift
//  Cangjie
//
//  托管撰稿主工作区顶栏分页状态，对齐原版 stores/autopilotWorkspaceStore.ts。
//

import SwiftUI
import Foundation

/// 托管撰稿主工作区顶栏分页，对齐原版 autopilotWorkspaceStore.ts:5 AutopilotWorkspaceTab
enum AutopilotWorkspaceTab: String, CaseIterable, Hashable {
    case cockpit
    case governance
    case dashboard
    case operations

    /// 中文标签
    var label: String {
        switch self {
        case .cockpit: return "全托管驾驶"
        case .governance: return "总编辑驾驶舱"
        case .dashboard: return "仪表盘"
        case .operations: return "监控 · DAG"
        }
    }

    /// 短标签
    var shortLabel: String {
        switch self {
        case .cockpit: return "驾驶舱"
        case .governance: return "总编辑"
        case .dashboard: return "仪表盘"
        case .operations: return "工作流"
        }
    }

    /// 描述
    var description: String {
        switch self {
        case .cockpit: return "启动、暂停与写作进度"
        case .governance: return "叙事契约、故事线与治理报告"
        case .dashboard: return "张力曲线与质量指标"
        case .operations: return "实时日志与 DAG 画布"
        }
    }
}

/// 「监控 + DAG」页内子视图，对齐原版 autopilotWorkspaceStore.ts:8 AutopilotOperationsSubview
enum AutopilotOperationsSubview: String, CaseIterable, Hashable {
    case monitor
    case dag
}

/// 托管撰稿主工作区 Store，对齐原版 autopilotWorkspaceStore.ts:42-75
@MainActor
final class AutopilotWorkspaceStore: ObservableObject {

    /// 当前激活的 Tab
    @Published var activeTab: AutopilotWorkspaceTab = .cockpit

    /// operations 页内子视图
    @Published var operationsSubview: AutopilotOperationsSubview = .monitor

    /// B-3/Q4：cockpit SSE 是否已连接（常驻）
    private var cockpitSSEConnected: Bool = false

    /// B-3/Q4：operations SSE 是否已连接（仅 operations Tab）
    private var operationsSSEConnected: Bool = false

    /// B-3/Q4：当前 novelId（用于 SSE 连接）
    private var currentNovelId: String?

    // MARK: - B-3/Q4 SSE 生命周期管理

    /// 进入工作区 — 连接 cockpit 写作 SSE（常驻）
    /// - Parameter novelId: 小说 ID
    func enterWorkspace(novelId: String) {
        currentNovelId = novelId
        // 连接 cockpit SSE（常驻，Tab 切换不断）
        if !cockpitSSEConnected {
            cockpitSSEConnected = true
            // 实际 SSE 连接由 AutopilotStore 管理，此处标记状态
            // AutopilotStore 在 View 层注入时自动连接 autopilot stream
            Logger.engine.info("AutopilotWorkspace: cockpit SSE 连接（常驻）novel=\(novelId)")
        }
    }

    /// 离开工作区 — 断开全部 SSE
    func leaveWorkspace() {
        // 断开 cockpit SSE
        if cockpitSSEConnected {
            cockpitSSEConnected = false
            Logger.engine.info("AutopilotWorkspace: cockpit SSE 断开")
        }
        // 断开 operations SSE
        if operationsSSEConnected {
            disconnectOperationsSSE()
        }
        currentNovelId = nil
    }

    /// 切换 Tab — 对齐 setTab，B-3/Q4 按 Tab 连断 operations SSE
    func setTab(_ tab: AutopilotWorkspaceTab) {
        let previousTab = activeTab
        activeTab = tab

        // B-3/Q4：切到 operations → 连接 DAG/日志 SSE
        if tab == .operations && !operationsSSEConnected {
            connectOperationsSSE()
        }
        // B-3/Q4：从 operations 切走 → 断开 DAG/日志 SSE
        if previousTab == .operations && tab != .operations {
            disconnectOperationsSSE()
        }
    }

    /// 连接 operations SSE（DAG 事件流 + 日志流）
    private func connectOperationsSSE() {
        operationsSSEConnected = true
        // DAG SSE 由 DAGRunStore 管理，此处标记状态
        Logger.engine.info("AutopilotWorkspace: operations SSE 连接（DAG/日志）")
    }

    /// 断开 operations SSE
    private func disconnectOperationsSSE() {
        operationsSSEConnected = false
        Logger.engine.info("AutopilotWorkspace: operations SSE 断开")
    }

    /// 设置 operations 子视图 — 对齐 setOperationsSubview
    /// 设置为 dag 时自动切换到 operations Tab
    func setOperationsSubview(_ view: AutopilotOperationsSubview) {
        operationsSubview = view
        if view == .dag {
            setTab(.operations)  // B-3/Q4：通过 setTab 确保 SSE 连接管理
        }
    }

    /// 打开 DAG 视图 — 对齐 openDag
    func openDag() {
        setTab(.operations)
        operationsSubview = .dag
    }

    /// 打开监控视图 — 对齐 openMonitor
    func openMonitor() {
        setTab(.operations)
        operationsSubview = .monitor
    }
}
