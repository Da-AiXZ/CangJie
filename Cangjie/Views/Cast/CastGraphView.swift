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
    // P1-VIEW-03 搜索高亮
    @State private var searchText: String = ""
    @State private var highlightIds: Set<String> = []
    @State private var searchDebounceTask: Task<Void, Never>?
    // P1-VIEW-03 Coverage + 三元组抽屉
    @State private var showCoverage: Bool = false
    @State private var showTriplesDrawer: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // P1-VIEW-03 搜索栏（对齐 Cast.vue:398-421）
            searchBar

            contentView
        }
        .navigationTitle("人物关系")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showCoverage = true
                    } label: {
                        Label("角色覆盖", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    Button {
                        showTriplesDrawer = true
                    } label: {
                        Label("三元组", systemImage: "network")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            if let novelId = appState.currentNovelId {
                await castStore.loadCastGraph(novelId: novelId)
            }
        }
        .sheet(item: $selectedCharacter) { character in
            characterDetailSheet(character)
        }
        .sheet(isPresented: $showCoverage) {
            if let novelId = appState.currentNovelId {
                NavigationStack {
                    CastCoveragePanel(novelId: novelId)
                        .navigationTitle("角色覆盖")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("关闭") { showCoverage = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showTriplesDrawer) {
            if let novelId = appState.currentNovelId,
               let graph = castStore.castGraph {
                KnowledgeTriplesDrawer(
                    novelId: novelId,
                    triples: [],
                    focusEntityName: selectedCharacter?.name,
                    defaultEntityType: "character"
                )
            }
        }
    }

    // MARK: - P1-VIEW-03 搜索栏

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
                .font(.system(size: 12))
            TextField("搜索角色…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onChange(of: searchText) { newValue in
                    // debounce 300ms（对齐 Cast.vue:398-421）
                    searchDebounceTask?.cancel()
                    searchDebounceTask = Task {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        if !Task.isCancelled {
                            await performSearch(query: newValue)
                        }
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    highlightIds.removeAll()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.secondaryBackground)
    }

    // MARK: - P1-VIEW-03 搜索执行

    private func performSearch(query: String) async {
        guard let novelId = appState.currentNovelId, !query.isEmpty else {
            highlightIds.removeAll()
            return
        }
        do {
            // 调用 Cast.search 端点（对齐 castApi.searchCast）
            let results: AnyCodable = try await APIClient.shared.request(
                APIEndpoint.Cast.search(novelId: novelId)
            )
            // 解析返回的 id 集合
            if let resultsArray = results.arrayValue as? [[String: Any]] {
                highlightIds = Set(resultsArray.compactMap { $0["id"] as? String })
            }
        } catch {
            // 搜索失败时本地过滤
            if let graph = castStore.castGraph {
                let queryLower = query.lowercased()
                highlightIds = Set(graph.characters
                    .filter { $0.name.lowercased().contains(queryLower) }
                    .map { $0.id })
            }
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
