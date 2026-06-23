//
//  RootView.swift
//  Cangjie
//
//  根视图三栏 NavigationSplitView（Sidebar/Content/Detail）。
//  iPad 横屏全展开，竖屏自适应。首次启动若无服务器配置→显示 ServerSetupSheet；
//  否则根据 AppState.selectedNovel 切换 Home/Workbench。
//

import SwiftUI

/// 根视图，管理三栏布局与全局导航。
///
/// - 三栏 NavigationSplitView：侧边栏 + 内容区 + 详情区
/// - 首次启动检查服务器配置，未配置时弹出 ServerSetupSheet
/// - 根据 AppState.currentNovelId 决定显示书架或工作台
struct RootView: View {

    // MARK: - 环境对象

    @EnvironmentObject var appState: AppState

    // MARK: - 状态

    /// 是否显示服务器配置 Sheet
    @State private var showServerSetup = false

    /// 是否显示新建小说 Sheet
    @State private var showCreateNovel = false

    /// 是否显示新书向导
    @State private var showOnboardingWizard = false

    // MARK: - 本地 Store

    @StateObject private var novelStore = NovelStore()
    @StateObject private var settingsStore = SettingsStore()

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            // 左栏：侧边栏导航
            SidebarView()
        } content: {
            // 中栏：内容区
            contentColumn
        } detail: {
            // 右栏：详情区（iPad 横屏显示，竖屏由系统自动管理）
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showServerSetup) {
            ServerConfigGuideView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showCreateNovel) {
            CreateNovelSheet(
                onCreated: { novel in
                    showCreateNovel = false
                    appState.selectNovel(novel.id)
                    novelStore.selectNovel(novel)
                    showOnboardingWizard = true
                }
            )
            .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showOnboardingWizard) {
            if let novel = novelStore.currentNovel {
                OnboardingWizardView(novel: novel) {
                    showOnboardingWizard = false
                    appState.sidebarSelection = .workbench
                }
                .environmentObject(appState)
            }
        }
        .task {
            // 启动时加载小说列表
            if appState.needsServerConfig {
                showServerSetup = true
            } else {
                await novelStore.loadNovels()
            }
        }
        .onChange(of: appState.needsServerConfig) { newValue in
            if newValue {
                showServerSetup = true
            }
        }
        .environmentObject(novelStore)
        .environmentObject(settingsStore)
    }

    // MARK: - 中栏内容

    /// 根据 sidebarSelection 显示对应内容
    @ViewBuilder
    private var contentColumn: some View {
        switch appState.sidebarSelection {
        case .bookshelf:
            HomeView(
                onCreateNovel: { showCreateNovel = true },
                onOpenNovel: { novel in
                    appState.selectNovel(novel.id)
                    novelStore.selectNovel(novel)
                    appState.sidebarSelection = .workbench
                }
            )
            .environmentObject(novelStore)

        case .workbench:
            if appState.currentNovelId != nil {
                WorkbenchView()
                    .environmentObject(novelStore)
            } else {
                emptyWorkbenchPlaceholder
            }

        case .autopilot:
            if let novelId = appState.currentNovelId {
                AutopilotConsoleView(novelId: novelId)
            } else {
                noNovelSelectedPlaceholder("请先选择一部小说")
            }

        case .bible:
            if let novelId = appState.currentNovelId {
                BiblePanelView(novelId: novelId)
            } else {
                noNovelSelectedPlaceholder("请先选择一部小说")
            }

        case .settings:
            SettingsView()
                .environmentObject(settingsStore)

        case .knowledgeGraph:
            KnowledgeGraphView()
                .environmentObject(appState)

        case .cast:
            CastGraphView()
                .environmentObject(appState)

        case .monitor:
            MonitorDashboardView()
                .environmentObject(appState)

        case .promptPlaza:
            PromptPlazaView()

        case .governance:
            GovernanceCockpitView()
                .environmentObject(appState)

        case .export:
            if appState.currentNovelId != nil {
                ExportView()
                    .environmentObject(appState)
            } else {
                noNovelSelectedPlaceholder("请先选择一部小说")
            }

        case .snapshot:
            if appState.currentNovelId != nil {
                SnapshotContainerView()
            } else {
                noNovelSelectedPlaceholder("请先选择一部小说")
            }

        case .trace:
            if appState.currentNovelId != nil {
                TraceRecordView()
                    .environmentObject(appState)
            } else {
                noNovelSelectedPlaceholder("请先选择一部小说")
            }

        case .locations:
            if appState.currentNovelId != nil {
                LocationGraphView()
                    .environmentObject(appState)
            } else {
                noNovelSelectedPlaceholder("请先选择一部小说")
            }

        case .none:
            HomeView(
                onCreateNovel: { showCreateNovel = true },
                onOpenNovel: { novel in
                    appState.selectNovel(novel.id)
                    novelStore.selectNovel(novel)
                    appState.sidebarSelection = .workbench
                }
            )
            .environmentObject(novelStore)
        }
    }

    // MARK: - 右栏详情

    /// 右栏详情内容
    @ViewBuilder
    private var detailColumn: some View {
        if appState.sidebarSelection == .workbench, appState.currentNovelId != nil {
            // 工作台模式下右栏显示上下文面板
            ContextPanelTabView()
                .environmentObject(novelStore)
        } else {
            // 默认显示空占位
            Color.clear
        }
    }

    // MARK: - 占位视图

    /// 工作台无小说选中时的占位
    private var emptyWorkbenchPlaceholder: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)

            Text("请先选择一部小说")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            Button("返回书架") {
                appState.sidebarSelection = .bookshelf
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    /// 未选择小说时的占位
    private func noNovelSelectedPlaceholder(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)

            Text(message)
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            Button("返回书架") {
                appState.sidebarSelection = .bookshelf
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

}

// MARK: - 快照容器视图

/// 快照容器：检查点时间线 + 世界线 DAG 双视图切换。
///
/// 侧边栏「快照」入口承载两个 T05 视图：
/// - 检查点时间线（CheckpointTimelineView）
/// - 世界线 DAG（WorldlineDAGView）
/// 通过顶部分段选择器切换，两者均通过 @EnvironmentObject 获取 AppState。
private struct SnapshotContainerView: View {

    /// 0 = 检查点时间线，1 = 世界线 DAG
    @State private var mode: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("快照视图", selection: $mode) {
                Text("检查点时间线").tag(0)
                Text("世界线 DAG").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.sm)

            if mode == 0 {
                CheckpointTimelineView()
            } else {
                WorldlineDAGView()
            }
        }
    }
}
