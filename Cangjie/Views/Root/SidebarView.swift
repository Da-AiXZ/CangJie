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

    /// A-2：PromptPlaza Bridge（shouldOpenPlaza 联动跳转）
    @ObservedObject private var promptPlazaBridge = PromptPlazaBridge.shared

    /// A-2：PromptPlaza Store（Badge 角标数据）
    @StateObject private var promptPlazaStore = PromptPlazaStore()

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
        .task {
            // A-2：加载 PromptPlaza 数据用于 Badge 角标
            await promptPlazaStore.loadPlazaInit()
        }
        .onChange(of: promptPlazaBridge.shouldOpenPlaza) { shouldOpen in
            // A-2：shouldOpenPlaza 联动跳转
            if shouldOpen {
                appState.sidebarSelection = .promptPlaza
                _ = promptPlazaBridge.consumeOpenRequest()
            }
        }
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
            HStack(spacing: 4) {
                Text(destination.rawValue)

                // A-2：PromptPlaza Badge 角标（提示词数量）
                if destination == .promptPlaza {
                    let count = promptPlazaStore.nodes.count
                    if count > 0 {
                        Text("\(min(count, 99))\(count > 99 ? "+" : "")")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        } icon: {
            Image(systemName: destination.iconName)
                .foregroundColor(appState.sidebarSelection == destination ? Theme.primary : Theme.textSecondary)
                .frame(width: 24)
        }
        .tag(destination)
    }
}

// MARK: - A-2 shouldOpenPlaza 联动

/// SidebarView 的 shouldOpenPlaza 联动修饰符。
///
/// 当 PromptPlazaBridge.shouldOpenPlaza 为 true 时，
/// 自动切换侧栏选中到 promptPlaza。
struct ShouldOpenPlazaModifier: ViewModifier {
    @ObservedObject var bridge: PromptPlazaBridge
    @Binding var selection: SidebarDestination?

    func body(content: Content) -> some View {
        content
            .onChange(of: bridge.shouldOpenPlaza) { shouldOpen in
                if shouldOpen {
                    selection = .promptPlaza
                    bridge.consumeOpenSignal()
                }
            }
    }
}
