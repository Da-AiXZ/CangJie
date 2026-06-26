//
//  BibleLocationsGraphPreviewView.swift
//  Cangjie
//
//  地点关系图预览（A-4），对齐原版 components/onboarding/BibleLocationsGraphPreview.vue。
//  接收 locations，渲染节点关系图（星型连接），按 location_type 着色。
//

import SwiftUI

// MARK: - 地点预览数据

/// 地点预览数据，对齐原版 BibleLocationsGraphPreview.vue 的 LocationDTO 输入。
struct LocationPreviewItem: Identifiable, Equatable {
    let id: String
    let name: String
    let locationType: String?
}

// MARK: - 地点类型颜色映射

/// 地点类型 → 颜色，对齐原版 GraphChart.vue 的 category 配色。
private func locationTypeColor(_ type: String?) -> Color {
    switch type ?? "" {
    case "city", "城镇": return .blue
    case "wilderness", "荒野": return .green
    case "dungeon", "地下城": return .purple
    case "landmark", "地标": return .orange
    case "region", "区域": return .teal
    default: return .gray
    }
}

/// 地点类型标签
private func locationTypeLabel(_ type: String?) -> String {
    guard let type = type, !type.isEmpty else { return "地点" }
    switch type {
    case "city": return "城镇"
    case "wilderness": return "荒野"
    case "dungeon": return "地下城"
    case "landmark": return "地标"
    case "region": return "区域"
    default: return type
    }
}

// MARK: - 地点关系图预览视图

/// 地点关系图预览，对齐原版 components/onboarding/BibleLocationsGraphPreview.vue。
///
/// 接收 locations，渲染节点关系图（星型连接），按 location_type 着色。
/// 星型弱连接：第一个节点为 hub，其余节点连接到 hub。
struct BibleLocationsGraphPreviewView: View {

    let locations: [LocationPreviewItem]

    /// 图表节点（id/name/category）
    private var graphNodes: [LocationPreviewItem] {
        return locations
    }

    /// 星型连接（hub → 其他节点）
    private var graphLinks: [(from: String, to: String)] {
        guard locations.count >= 2 else { return [] }
        let hub = locations[0].id
        return locations.dropFirst().map { (hub, $0.id) }
    }

    /// 分类标签（去重 + 排序）
    private var categoryLabels: [String] {
        var set = Set<String>()
        for loc in locations {
            set.insert(locationTypeLabel(loc.locationType))
        }
        return set.isEmpty ? ["地点"] : Array(set).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("地点分布预览（按类型着色；线表示同属一书世界观下的关联占位，可在工作台\u{201C}地点关系图\u{201D}中编辑三元组后细化）")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            if locations.isEmpty {
                Text("暂无地点数据")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                // 图例
                HStack(spacing: 12) {
                    ForEach(categoryLabels, id: \.self) { label in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(categoryColor(label))
                                .frame(width: 8, height: 8)
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }

                // 力导向图（Canvas 简易实现）
                locationGraphCanvas
                    .frame(height: 320)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(8)
            }
        }
    }

    /// 分类标签 → 颜色
    private func categoryColor(_ label: String) -> Color {
        switch label {
        case "城镇": return .blue
        case "荒野": return .green
        case "地下城": return .purple
        case "地标": return .orange
        case "区域": return .teal
        default: return .gray
        }
    }

    /// 节点位置计算（环形布局）
    private func nodePositions(_ size: CGSize) -> [String: CGPoint] {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 30
        var positions: [String: CGPoint] = [:]

        for (index, node) in graphNodes.enumerated() {
            if graphNodes.count == 1 {
                positions[node.id] = center
            } else {
                let angle: Double = (Double(index) / Double(graphNodes.count)) * 2.0 * .pi - .pi / 2
                positions[node.id] = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            }
        }
        return positions
    }

    /// Canvas 图形
    private var locationGraphCanvas: some View {
        Canvas { context, size in
            let positions = nodePositions(size)

            // 绘制连线
            for link in graphLinks {
                if let from = positions[link.from], let to = positions[link.to] {
                    var path = Path()
                    path.move(to: from)
                    path.addLine(to: to)
                    context.stroke(path, with: .color(Color.gray.opacity(0.3)), lineWidth: 1)
                }
            }

            // 绘制节点
            for node in graphNodes {
                if let pos = positions[node.id] {
                    let nodeColor = locationTypeColor(node.locationType)
                    let rect = CGRect(x: pos.x - 12, y: pos.y - 12, width: 24, height: 24)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(nodeColor)
                    )

                    // 节点名称
                    let text = Text(node.name)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textPrimary)
                    context.draw(text, at: CGPoint(x: pos.x, y: pos.y + 22))
                }
            }
        }
    }
}
