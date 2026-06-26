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

    // P1-VIEW-04 节点详情 + 三元组抽屉
    @State private var selectedLocation: LocationDTO?
    @State private var showTriplesDrawer: Bool = false

    // E-3：实际三元组数据（从 API 加载）
    @State private var allTriples: [KnowledgeTriple] = []

    /// E-3：按选中地点节点过滤的三元组
    private var filteredTriples: [KnowledgeTriple] {
        guard let locationName = selectedLocation?.name else { return allTriples }
        return allTriples.filter { triple in
            triple.subject == locationName || triple.object == locationName
        }
    }

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
                    edgeLabel: { $0.label },
                    onTapNode: { nodeId in
                        // P1-VIEW-04 节点点击 → 详情面板
                        selectedLocation = bible.locations.first { $0.id == nodeId }
                    }
                )
            } else if bibleStore.isLoading {
                ProgressView("加载地点…")
            } else {
                emptyState
            }
        }
        .navigationTitle("地点关系")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showTriplesDrawer = true
                } label: {
                    Image(systemName: "network")
                }
            }
        }
        .task {
            if let novelId = appState.currentNovelId {
                await bibleStore.loadBible(novelId: novelId)
                // E-3：加载实际三元组数据
                await loadTriples(novelId: novelId)
            }
        }
        .sheet(item: $selectedLocation) { location in
            // P1-VIEW-04 节点详情面板
            locationDetailSheet(location)
        }
        .sheet(isPresented: $showTriplesDrawer) {
            // P1-VIEW-04 三元组抽屉
            if let novelId = appState.currentNovelId {
                KnowledgeTriplesDrawer(
                    novelId: novelId,
                    triples: filteredTriples,
                    focusEntityName: selectedLocation?.name,
                    defaultEntityType: "location"
                )
            }
        }
    }

    // MARK: - P1-VIEW-04 地点详情面板

    @ViewBuilder
    private func locationDetailSheet(_ location: LocationDTO) -> some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("名称", value: location.name)
                    LabeledContent("类型", value: location.locationType)
                    if !location.description.isEmpty {
                        LabeledContent("描述", value: location.description)
                    }
                }

                Section {
                    Button {
                        selectedLocation = nil
                        showTriplesDrawer = true
                    } label: {
                        Label("查看相关三元组", systemImage: "network")
                    }
                }
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { selectedLocation = nil }
                }
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

    // MARK: - E-3 三元组加载

    /// 加载知识三元组数据
    private func loadTriples(novelId: String) async {
        do {
            let response: [KnowledgeTriple] = try await APIClient.shared.request(
                APIEndpoint.KnowledgeGraph.triples(novelId: novelId)
            )
            allTriples = response
        } catch {
            allTriples = []
        }
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
