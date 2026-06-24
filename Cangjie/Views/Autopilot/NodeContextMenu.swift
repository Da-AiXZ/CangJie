//
//  NodeContextMenu.swift
//  Cangjie
//
//  DAG 节点右键/长按菜单（自定义 overlay 浮层）。
//  对齐 NodeContextMenu.vue:1-113。
//  决策7：用自定义 overlay，不用原生 .contextMenu。
//  LongPressGesture 触发，GeometryReader 定位，不超视口。
//

import SwiftUI

/// DAG 节点上下文菜单 — 对齐 NodeContextMenu.vue:1-113
struct NodeContextMenu: View {

    // MARK: - Props（对齐 NodeContextMenu.vue:32-38 defineProps）

    /// 菜单 X 坐标（屏幕坐标）
    let x: CGFloat
    /// 菜单 Y 坐标（屏幕坐标）
    let y: CGFloat
    /// 节点 ID
    let nodeId: String
    /// 节点是否启用
    let nodeEnabled: Bool
    /// 节点类型
    let nodeType: String

    // MARK: - 环境

    @EnvironmentObject var dagStore: DAGStore

    // MARK: - 回调

    /// 查看详情回调
    var onDetail: (String) -> Void
    /// 启禁用回调
    var onToggle: (String) -> Void
    /// 关闭回调
    var onClose: () -> Void

    // MARK: - 计算属性

    /// 节点类型标签 — 对齐 NodeContextMenu.vue:50-58 nodeTypeLabel
    private var nodeTypeLabel: String {
        if nodeType.isEmpty { return nodeId }
        if let meta = dagStore.nodeTypeRegistry[nodeType] {
            // 对齐 NodeContextMenu.vue:54 `${meta.icon} ${meta.display_name} (${catLabel})`
            let catLabel = CATEGORY_LABELS[meta.category] ?? meta.category
            return "\(meta.icon) \(meta.displayName) (\(catLabel))"
        }
        return nodeType
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            // 背景点击关闭
            Color.black.opacity(0.01)
                .onTapGesture { onClose() }

            // 菜单浮层 — 对齐 NodeContextMenu.vue:2-23
            menuView(in: geometry)
        }
    }

    // MARK: - 菜单视图（对齐 NodeContextMenu.vue:3-23）

    private func menuView(in geometry: GeometryProxy) -> some View {
        // 对齐 NodeContextMenu.vue:61-68 menuStyle（确保不超出视口）
        let menuWidth: CGFloat = 200
        let menuHeight: CGFloat = 150
        let maxX = geometry.size.width - menuWidth - 16
        let maxY = geometry.size.height - menuHeight - 16
        let clampedX = min(x, maxX)
        let clampedY = min(y, maxY)

        return VStack(spacing: 0) {
            // 对齐 NodeContextMenu.vue:10-12 节点信息头
            HStack {
                Text(nodeTypeLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // 对齐 NodeContextMenu.vue:13 divider
            Divider()

            // 对齐 NodeContextMenu.vue:16-18 查看详情
            menuButton("📋 查看详情", color: Theme.primary) {
                onDetail(nodeId)
                onClose()
            }

            Divider()

            // 对齐 NodeContextMenu.vue:20-22 启禁用（动态文本）
            menuButton(
                nodeEnabled ? "⛔ 禁用此节点" : "✅ 启用此节点",
                color: nodeEnabled ? Theme.warning : Theme.statusSuccess
            ) {
                onToggle(nodeId)
                onClose()
            }
        }
        .frame(width: menuWidth)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.small)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .position(x: clampedX + menuWidth / 2, y: clampedY + menuHeight / 2)
    }

    // MARK: - 菜单按钮（对齐 NodeContextMenu.vue:89-95 .menu-item）

    private func menuButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
