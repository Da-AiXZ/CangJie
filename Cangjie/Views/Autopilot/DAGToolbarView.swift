//
//  DAGToolbarView.swift
//  Cangjie
//
//  DAG 工具栏，对齐原版 components/autopilot/DAGToolbar.vue:1-117。
//  DAG标题 + 节点统计Tag + 托管状态指示 + SSE连接灯 + 注册表缺口提示 + 版本号。
//

import SwiftUI

/// DAG 工具栏视图
///
/// 对齐原版 `components/autopilot/DAGToolbar.vue`。
/// 放置在 DAGCanvasView 顶部，显示 DAG 节点统计 + 托管状态 + SSE连接状态。
struct DAGToolbarView: View {

    /// 小说 ID（对齐 :99 props.novelId）
    let novelId: String

    /// DAG 统计（对齐 :100-108 props.dagStats）
    let dagStats: DAGStatsSummary?

    /// 托管模式状态（对齐 :110 props.autopilotStatus）
    let autopilotStatus: String

    /// SSE 连接状态（对齐 :111 props.sseConnected）
    let sseConnected: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            // 对齐 :3-78 toolbar-left
            leftSection
            Spacer()
            // 对齐 :80-85 toolbar-right
            rightSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.secondaryBackground)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.2)), alignment: .bottom)
    }

    // MARK: - 左侧区域（对齐 :3-78）

    private var leftSection: some View {
        HStack(spacing: 10) {
            // 对齐 :4 标题
            Text("🧭 DAG 可视化")
                .font(.system(size: 14, weight: .bold))

            // 对齐 :7-15 节点统计Tag
            if let stats = dagStats {
                HStack(spacing: 4) {
                    Text("\(stats.total) 节点 · \(stats.enabled) 启用")
                        .font(.system(size: 12))
                    if stats.running > 0 {
                        Text("· \(stats.running) 运行中")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.info)
                    }
                    if stats.error > 0 {
                        Text("· \(stats.error) 错误")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.error)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.tertiaryBackground)
                .cornerRadius(999)
            }

            // 对齐 :18-56 托管模式状态指示
            autopilotStatusTag

            // 对齐 :59-64 SSE 连接状态灯
            Circle()
                .fill(sseConnected ? Theme.success : Theme.error)
                .frame(width: 7, height: 7)
                .opacity(sseConnected ? 1.0 : 0.6)

            // 对齐 :66-77 注册表缺口提示
            registryGapTags
        }
    }

    // MARK: - 托管状态Tag（对齐 :18-56）

    private var autopilotStatusTag: some View {
        Group {
            switch autopilotStatus {
            case "running":
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("托管运行中")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.info.opacity(0.15))
                .cornerRadius(999)
                .foregroundColor(Theme.info)
            case "paused":
                Text("⏸️ 等待审阅")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.warning.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.warning)
            case "completed":
                Text("✅ 全书完成")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.success.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.success)
            case "error":
                Text("❌ 托管异常")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.error.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.error)
            default:
                EmptyView()
            }
        }
    }

    // MARK: - 注册表缺口提示（对齐 :66-77）

    private var registryGapTags: some View {
        Group {
            // 缺注册
            if registryGapCount > 0 {
                Text("缺注册 \(registryGapCount)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.error.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.error)
            } else if linkageFailed {
                Text("联动")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.warning.opacity(0.15))
                    .cornerRadius(999)
                    .foregroundColor(Theme.warning)
            }
        }
    }

    // MARK: - 右侧区域（对齐 :80-85）

    private var rightSection: some View {
        Group {
            if let stats = dagStats {
                Text("v\(stats.version)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - DAGStore 衍生属性

    @EnvironmentObject private var dagStore: DAGStore

    private var registryGapCount: Int { dagStore.registryGaps.count }
    private var linkageFailed: Bool { dagStore.registryLinkageFailed }
}

// MARK: - DAG 统计摘要（对齐 :100-108 props.dagStats）

/// DAG 统计摘要，对齐原版 DAGToolbar.vue:100-108 dagStats prop
struct DAGStatsSummary: Equatable {
    let total: Int
    let enabled: Int
    let running: Int
    let success: Int
    let error: Int
    let bypassed: Int
    let version: Int

    /// 从 DAGStore 状态构建
    @MainActor
    static func from(dagStore: DAGStore) -> DAGStatsSummary? {
        guard let dag = dagStore.dagDefinition else { return nil }
        let states = dagStore.nodeStates
        let total = dag.nodes.count
        var enabled = 0, running = 0, success = 0, error = 0, bypassed = 0
        for node in dag.nodes {
            if node.enabled { enabled += 1 }
            let st = states[node.id]?.status ?? "idle"
            switch st {
            case "running": running += 1
            case "success", "done": success += 1
            case "error", "failed": error += 1
            case "bypassed": bypassed += 1
            default: break
            }
        }
        let version = dagStore.dagStatus?.currentVersion ?? 1
        return DAGStatsSummary(total: total, enabled: enabled, running: running, success: success, error: error, bypassed: bypassed, version: version)
    }
}
