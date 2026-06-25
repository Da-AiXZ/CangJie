//
//  SidebarView.swift
//  Cangjie
//
//  侧边栏导航：书架/工作台/自动驾驶/设定集/知识图谱/DAG/提示词广场/监控/设置。
//  List + NavigationLink 风格，当前选中高亮。
//

import SwiftUI

/// 侧边栏导航视图
struct SidebarView: View {

    @EnvironmentObject var appState: AppState

    // MARK: - 导航分组

    /// 创作分组
    private let creationItems: [SidebarDestination] = [.bookshelf, .workbench, .autopilot]

    /// 设定分组
    private let worldbuildingItems: [SidebarDestination] = [.bible, .knowledgeGraph, .cast, .locations]

    /// 分析分组
    private let analysisItems: [SidebarDestination] = [.monitor, .promptPlaza, .governance]

    /// 工具分组
    private let toolItems: [SidebarDestination] = [.export, .snapshot, .trace, .debug]

    /// 系统分组
    private let systemItems: [SidebarDestination] = [.settings]

    // MARK: - Body

    var body: some View {
        List(selection: $appState.sidebarSelection) {
            // 顶部品牌区
            Section {
                brandHeader
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // 创作分组
            Section("创作") {
                ForEach(creationItems, id: \.self) { item in
                    sidebarRow(item)
                }
            }

            // 设定分组
            Section("设定") {
                ForEach(worldbuildingItems, id: \.self) { item in
                    sidebarRow(item)
                }
            }

            // 分析分组
            Section("分析") {
                ForEach(analysisItems, id: \.self) { item in
                    sidebarRow(item)
                }
            }

            // 工具分组
            Section("工具") {
                ForEach(toolItems, id: \.self) { item in
                    sidebarRow(item)
                }
            }

            // 系统分组
            Section {
                ForEach(systemItems, id: \.self) { item in
                    sidebarRow(item)
                }

                // 全局 LLM 入口按钮，对齐原版 StatsSidebar.vue 中的 GlobalLLMEntryButton appearance="sidebar"
                GlobalLLMEntryButton()
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("仓颉")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 品牌头部

    /// 顶部品牌区，显示应用图标和名称
    private var brandHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "book.fill")
                .font(.system(size: 28))
                .foregroundColor(Theme.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("仓颉")
                    .font(Theme.headlineFont())

                if let health = appState.healthStatus {
                    Text("v\(health.version)")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    // MARK: - 侧边栏行

    /// 侧边栏导航行
    private func sidebarRow(_ destination: SidebarDestination) -> some View {
        Label {
            Text(destination.rawValue)
        } icon: {
            Image(systemName: destination.iconName)
                .foregroundColor(appState.sidebarSelection == destination ? Theme.primary : Theme.textSecondary)
                .frame(width: 24)
        }
        .tag(destination)
    }
}
