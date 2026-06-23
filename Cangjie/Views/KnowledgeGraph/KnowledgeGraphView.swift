//
//  KnowledgeGraphView.swift
//  Cangjie
//
//  知识图谱页：用 ForceDirectedGraph 渲染三元组（主语-谓词-宾语）。
//  节点按实体类型着色，边显示关系标签。
//  顶部统计栏（三元组数/实体数/关系数）。调 KnowledgeGraphStore。
//

import SwiftUI

/// 知识图谱页
struct KnowledgeGraphView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var kgStore = KnowledgeGraphStore()

    @State private var selectedTriple: KnowledgeTriple?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部统计栏
            statsBar

            // 图谱/表格切换
            TabView {
                // 力导向图
                graphTab
                    .tabItem {
                        Label("图谱", systemImage: "network")
                    }

                // 三元组表格
                TriplesTableView(triples: kgStore.triples, onTap: { triple in
                    selectedTriple = triple
                })
                .tabItem {
                    Label("列表", systemImage: "list.bullet")
                }
            }
            .tabViewStyle(.automatic)
        }
        .navigationTitle("知识图谱")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let novelId = appState.currentNovelId {
                await kgStore.loadTriples(novelId: novelId)
                await kgStore.loadStatistics(novelId: novelId)
            }
        }
        .sheet(item: $selectedTriple) { triple in
            InferenceEvidenceView(triple: triple)
                .environmentObject(kgStore)
        }
    }

    // MARK: - 统计栏

    private var statsBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            statItem(label: "三元组", value: "\(kgStore.triples.count)", icon: "link")

            Divider()
                .frame(height: 24)

            statItem(label: "实体", value: "\(entityCount)", icon: "circle.grid.cross")

            Divider()
                .frame(height: 24)

            statItem(label: "关系", value: "\(relationCount)", icon: "arrow.triangle.branch")

            Spacer()

            // 搜索
            if !kgStore.triples.isEmpty {
                Button {
                    // 刷新
                    if let novelId = appState.currentNovelId {
                        Task { await kgStore.loadTriples(novelId: novelId) }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 图谱 Tab

    private var graphTab: some View {
        Group {
            if kgStore.triples.isEmpty {
                emptyState
            } else {
                ForceDirectedGraph(
                    nodes: graphNodes,
                    edges: graphEdges,
                    nodeColor: { node in entityColor(node.type) },
                    nodeRadius: { _ in 22 },
                    nodeLabel: { $0.label },
                    edgeColor: { _ in Theme.textTertiary.opacity(0.4) },
                    edgeLabel: { $0.label },
                    onTapNode: { nodeId in
                        // 查找该实体相关的三元组
                        if let triple = kgStore.triples.first(where: { $0.subjectEntityId == nodeId || $0.objectEntityId == nodeId }) {
                            selectedTriple = triple
                        }
                    }
                )
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "network")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)

            Text("暂无知识三元组")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            Text("写作后系统会自动从章节中提取知识三元组")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 数据转换

    /// 三元组转图节点
    private var graphNodes: [ForceSimulation.GraphNode] {
        var nodeSet = Set<String>()
        var nodes: [ForceSimulation.GraphNode] = []

        for triple in kgStore.triples {
            let subjectId = triple.subjectEntityId ?? triple.subject
            if !nodeSet.contains(subjectId) {
                nodeSet.insert(subjectId)
                nodes.append(ForceSimulation.GraphNode(
                    id: subjectId,
                    label: triple.subject,
                    type: triple.entityType ?? "unknown"
                ))
            }

            let objectId = triple.objectEntityId ?? triple.object
            if !nodeSet.contains(objectId) {
                nodeSet.insert(objectId)
                nodes.append(ForceSimulation.GraphNode(
                    id: objectId,
                    label: triple.object,
                    type: "object"
                ))
            }
        }

        return nodes
    }

    /// 三元组转图边
    private var graphEdges: [ForceSimulation.GraphEdge] {
        return kgStore.triples.map { triple in
            let sourceId = triple.subjectEntityId ?? triple.subject
            let targetId = triple.objectEntityId ?? triple.object
            return ForceSimulation.GraphEdge(
                id: triple.id,
                source: sourceId,
                target: targetId,
                label: triple.predicate
            )
        }
    }

    // MARK: - 统计

    private var entityCount: Int {
        var entities = Set<String>()
        for triple in kgStore.triples {
            entities.insert(triple.subject)
            entities.insert(triple.object)
        }
        return entities.count
    }

    private var relationCount: Int {
        return Set(kgStore.triples.map { $0.predicate }).count
    }

    // MARK: - 辅助

    private func statItem(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.primary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private func entityColor(_ type: String) -> Color {
        switch type {
        case "character": return Theme.primary
        case "location": return Theme.warning
        case "item", "prop": return Theme.info
        case "event": return Theme.success
        case "organization": return Theme.statusBypassed
        default: return Theme.textSecondary
        }
    }
}
