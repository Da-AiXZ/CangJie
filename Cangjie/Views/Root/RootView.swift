//
//  RootView.swift
//  Cangjie
//
//  根视图：HStack 两栏布局（侧边栏 + 内容区），不使用 NavigationSplitView。
//
//  【修复】原实现用 NavigationSplitView，其 content 闭包里用 switch 切换不同类型视图
//  （HomeView/WorkbenchView/SettingsView 等），iOS 16 AttributeGraph 在视图类型切换时
//  assertion 崩溃（EXC_BREAKPOINT）。改为 HStack + NavigationStack 彻底避免。
//

import SwiftUI

/// 根视图，管理两栏布局与全局导航。
struct RootView: View {

    // MARK: - 环境对象

    @EnvironmentObject var appState: AppState

    // MARK: - 状态

    /// 是否显示新建小说 Sheet
    @State private var showCreateNovel = false

    /// 是否显示新书向导
    @State private var showOnboardingWizard = false

    // MARK: - 本地 Store

    @StateObject private var novelStore = NovelStore()
    @StateObject private var settingsStore = SettingsStore()

    // MARK: - Body

    var body: some View {
        // 【修复】用 HStack + NavigationStack 代替 NavigationSplitView
        // NavigationSplitView 的 content 闭包 switch 不同视图类型会触发
        // iOS 16 AttributeGraph assertion 崩溃
        HStack(spacing: 0) {
            // 左栏：侧边栏导航（固定宽度）
            SidebarView()
                .environmentObject(appState)
                .frame(width: 240)
                .background(Theme.secondaryBackground)

            Divider()

            // 右栏：内容区（NavigationStack 包裹，根据 sidebarSelection 切换）
            NavigationStack {
                contentColumn
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showCreateNovel) {
            CreateNovelSheet(
                onCreated: { novel in
                    showCreateNovel = false
                    appState.selectNovel(novel.id)
                    novelStore.selectNovel(novel)
                    DispatchQueue.main.async {
                        showOnboardingWizard = true
                    }
                }
            )
            .environmentObject(appState)
            .environmentObject(novelStore)
        }
        .fullScreenCover(isPresented: $showOnboardingWizard) {
            if let novel = novelStore.currentNovel {
                OnboardingWizardView(novel: novel) {
                    showOnboardingWizard = false
                    appState.sidebarSelection = .workbench
                }
                .environmentObject(appState)
            } else {
                Color.clear
                    .onAppear {
                        showOnboardingWizard = false
                        appState.sidebarSelection = .bookshelf
                    }
            }
        }
        .task {
            if appState.needsServerConfig {
                appState.needsServerConfig = false
            }
            await novelStore.loadNovels()
        }
        .environmentObject(novelStore)
        .environmentObject(settingsStore)
    }

    // MARK: - 内容区

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
                    .environmentObject(appState)
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

    // MARK: - 占位视图

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

private struct SnapshotContainerView: View {
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
