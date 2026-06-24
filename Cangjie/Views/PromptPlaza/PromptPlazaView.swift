//
//  PromptPlazaView.swift
//  Cangjie
//
//  提示词广场三栏（左：分类树 / 中：节点列表 / 右：详情）。
//  HStack 布局，调 PromptPlazaStore。
//  对齐原版 llmControl.ts:138-159 PromptNode + llmControl.ts:350-354 PlazaInitResult。
//
//  【修复】原用 NavigationSplitView，但 RootView 已有 NavigationSplitView，
//  嵌套会导致 iOS 16 崩溃。改为 HStack 布局。
//

import SwiftUI

/// 提示词广场
struct PromptPlazaView: View {

    @StateObject private var store = PromptPlazaStore()

    @State private var selectedCategory: String?
    @State private var selectedNode: PromptNode?

    var body: some View {
        // 用 HStack 代替 NavigationSplitView，避免嵌套崩溃
        HStack(spacing: 0) {
            // 左栏：分类树
            List(selection: $selectedCategory) {
                Section("分类") {
                    ForEach(store.categories) { category in
                        Label {
                            HStack {
                                // llmControl.ts:106 name（原 label→name）
                                Text(category.name)
                                // llmControl.ts:110 count（原 promptCount→count）
                                if category.count > 0 {
                                    Text("\(category.count)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        } icon: {
                            // llmControl.ts:107 icon
                            Image(systemName: category.icon.isEmpty ? "folder" : category.icon)
                        }
                        .tag(category.key)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(width: 220)

            Divider()

            // 中栏：节点列表
            List(selection: $selectedNode) {
                ForEach(filteredNodes) { node in
                    VStack(alignment: .leading, spacing: 4) {
                        // llmControl.ts:141 name（原 title→name）
                        Text(node.name.isEmpty ? node.nodeKey : node.name)
                            .font(Theme.bodyFont())

                        // llmControl.ts:143 category
                        if !node.category.isEmpty {
                            Text(node.category)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }

                        // llmControl.ts:148 tags
                        if !node.tags.isEmpty {
                            HStack {
                                ForEach(node.tags.prefix(3), id: \.self) { tag in
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
            .frame(maxWidth: .infinity)

            Divider()

            // 右栏：详情
            rightPanel
                .frame(width: 320)
        }
        .navigationTitle("提示词")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadPlazaInit()
        }
    }

    // MARK: - 右栏详情

    @ViewBuilder
    private var rightPanel: some View {
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

    /// 按分类筛选
    private var filteredNodes: [PromptNode] {
        guard let category = selectedCategory else { return store.nodes }
        return store.nodes.filter { $0.category == category }
    }
}
