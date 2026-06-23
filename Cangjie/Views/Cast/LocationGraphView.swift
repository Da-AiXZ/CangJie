//
//  LocationGraphView.swift
//  Cangjie
//
//  地点关系图：用 ForceDirectedGraph，节点=地点，边=地理/叙事关系。
//

import SwiftUI

/// 地点关系图
struct LocationGraphView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var bibleStore = BibleStore()

    var body: some View {
        Group {
            if let bible = bibleStore.bible, !bible.locations.isEmpty {
                ForceDirectedGraph(
                    nodes: locationNodes(bible.locations),
                    edges: locationEdges(bible.locations),
                    nodeColor: { node in locationTypeColor(node.type) },
                    nodeRadius: { _ in 24 },
                    nodeLabel: { $0.label },
                    edgeColor: { _ in Theme.textTertiary.opacity(0.4) },
                    edgeLabel: { $0.label }
                )
            } else if bibleStore.isLoading {
                ProgressView("加载地点…")
            } else {
                emptyState
            }
        }
        .navigationTitle("地点关系")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let novelId = appState.currentNovelId {
                await bibleStore.loadBible(novelId: novelId)
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)

            Text("暂无地点数据")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 数据转换

    private func locationNodes(_ locations: [LocationDTO]) -> [ForceSimulation.GraphNode] {
        return locations.map { location in
            ForceSimulation.GraphNode(
                id: location.id,
                label: location.name,
                type: location.locationType
            )
        }
    }

    /// 构建地点关系边（基于 parentId 层级 + 同类型关联）
    private func locationEdges(_ locations: [LocationDTO]) -> [ForceSimulation.GraphEdge] {
        var edges: [ForceSimulation.GraphEdge] = []

        // 父子关系边
        for location in locations {
            if let parentId = location.parentId,
               locations.contains(where: { $0.id == parentId }) {
                edges.append(ForceSimulation.GraphEdge(
                    id: "edge_\(location.id)_\(parentId)",
                    source: parentId,
                    target: location.id,
                    label: "包含"
                ))
            }
        }

        return edges
    }

    // MARK: - 颜色辅助

    private func locationTypeColor(_ type: String) -> Color {
        switch type {
        case "city": return Theme.primary
        case "region": return Theme.info
        case "building": return Theme.warning
        case "faction": return Theme.statusBypassed
        case "realm": return Theme.success
        default: return Theme.textSecondary
        }
    }
}
