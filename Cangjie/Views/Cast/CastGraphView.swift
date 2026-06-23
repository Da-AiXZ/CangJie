//
//  CastGraphView.swift
//  Cangjie
//
//  人物关系图：用 ForceDirectedGraph，节点=角色（头像+名字），边=关系（亲属/敌对/盟友/师徒等）。
//  调 CastStore。
//

import SwiftUI

/// 人物关系图
struct CastGraphView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var castStore = CastStore()

    @State private var selectedCharacter: CastCharacter?

    var body: some View {
        contentView
            .navigationTitle("人物关系")
            .task {
                if let novelId = appState.currentNovelId {
                    await castStore.loadCastGraph(novelId: novelId)
                }
            }
            .sheet(item: $selectedCharacter) { character in
                characterDetailSheet(character)
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if castStore.isLoading {
            VStack(spacing: Theme.Spacing.lg) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("加载人物关系…")
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let graph = castStore.castGraph, !graph.characters.isEmpty {
            ForceDirectedGraph(
                nodes: graphNodes(graph),
                edges: graphEdges(graph),
                nodeColor: { node in characterColor(node.type) },
                nodeRadius: { _ in 28 },
                nodeLabel: { $0.label },
                edgeColor: { edge in relationColor(edge.label) },
                edgeLabel: { $0.label },
                onTapNode: { nodeId in
                    selectedCharacter = graph.characters.first { $0.id == nodeId }
                }
            )
        } else {
            emptyState
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)

            Text("暂无角色关系数据")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            Text("生成 Bible 设定集后自动构建人物关系图")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 数据转换

    private func graphNodes(_ graph: CastGraph) -> [ForceSimulation.GraphNode] {
        return graph.characters.map { character in
            ForceSimulation.GraphNode(
                id: character.id,
                label: character.name,
                type: character.role
            )
        }
    }

    private func graphEdges(_ graph: CastGraph) -> [ForceSimulation.GraphEdge] {
        return graph.relationships.map { relation in
            ForceSimulation.GraphEdge(
                id: relation.id,
                source: relation.sourceId,
                target: relation.targetId,
                label: relation.label
            )
        }
    }

    // MARK: - 角色详情 Sheet

    private func characterDetailSheet(_ character: CastCharacter) -> some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("名字", value: character.name)
                    LabeledContent("角色", value: character.role)
                    if !character.traits.isEmpty {
                        LabeledContent("特征", value: character.traits)
                    }
                    if !character.note.isEmpty {
                        LabeledContent("备注", value: character.note)
                    }
                }

                if !character.aliases.isEmpty {
                    Section("别名") {
                        ForEach(character.aliases, id: \.self) { alias in
                            Text(alias)
                        }
                    }
                }

                if !character.storyEvents.isEmpty {
                    Section("故事事件") {
                        ForEach(character.storyEvents) { event in
                            VStack(alignment: .leading) {
                                Text(event.summary)
                                    .font(.system(size: 13))
                                if let chapter = event.chapterId {
                                    Text("第\(chapter)章 · \(event.importance)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(character.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { selectedCharacter = nil }
                }
            }
        }
    }

    // MARK: - 颜色辅助

    private func characterColor(_ role: String) -> Color {
        switch role {
        case "主角": return Theme.primary
        case "反派": return Theme.error
        case "配角": return Theme.info
        case "导师": return Theme.success
        default: return Theme.textSecondary
        }
    }

    private func relationColor(_ label: String) -> Color {
        switch label {
        case "亲属", "父母", "兄弟", "姐妹", "子女": return Theme.primary
        case "敌对", "仇人": return Theme.error
        case "盟友", "朋友": return Theme.success
        case "师徒", "导师": return Theme.warning
        case "恋人", "爱人": return Color.pink
        default: return Theme.textTertiary
        }
    }
}
