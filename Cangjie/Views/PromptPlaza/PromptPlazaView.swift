//
//  PromptPlazaView.swift
//  Cangjie
//
//  提示词广场三栏（左：分类树 / 中：模板列表 / 右：详情）。
//  NavigationSplitView，调 PromptPlazaStore。
//  对齐 Vue3 提示词广场的交互布局。
//

import SwiftUI

/// 提示词广场
struct PromptPlazaView: View {

    @StateObject private var store = PromptPlazaStore()

    @State private var selectedCategory: String?
    @State private var selectedNode: PromptNode?

    var body: some View {
        NavigationSplitView {
            // 左栏：分类树
            List(selection: $selectedCategory) {
                Section("分类") {
                    ForEach(store.categories) { category in
                        Label {
                            HStack {
                                Text(category.label)
                                if category.promptCount ?? 0 > 0 {
                                    Text("\(category.promptCount!)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        } icon: {
                            Image(systemName: category.icon ?? "folder")
                        }
                        .tag(category.key)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("提示词")
        } content: {
            // 中栏：模板列表
            List(selection: $selectedNode) {
                ForEach(filteredNodes) { node in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.title ?? node.nodeKey)
                            .font(Theme.bodyFont())

                        if let category = node.category {
                            Text(category)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }

                        if let tags = node.tags, !tags.isEmpty {
                            HStack {
                                ForEach(tags.prefix(3), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 9))
                                        .foregroundColor(Theme.primary)
                                }
                            }
                        }
                    }
                    .tag(node)
                }
            }
            .navigationTitle(selectedCategory ?? "全部")
        } detail: {
            // 右栏：详情
            if let node = selectedNode {
                PromptDetailView(node: node)
                    .environmentObject(store)
            } else {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.textTertiary)
                    Text("选择一个提示词查看详情")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await store.loadPlazaInit()
        }
    }

    /// 按分类筛选
    private var filteredNodes: [PromptNode] {
        guard let category = selectedCategory else { return store.nodes }
        return store.nodes.filter { $0.category == category }
    }
}
