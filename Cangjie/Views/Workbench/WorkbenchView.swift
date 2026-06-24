//
//  WorkbenchView.swift
//  Cangjie
//
//  工作台三栏布局（HStack 实现，不嵌套 NavigationSplitView）：
//  左：章节树导航 / 中：正文编辑或生成流 / 右：上下文面板 TabView。
//  对齐 Vue3 Workbench.vue 的 n-split 三栏布局。
//
//  【修复】原实现用 NavigationSplitView，但 RootView 已经有一个 NavigationSplitView，
//  在其 content 闭包里再嵌套 NavigationSplitView 会导致 iOS 16 AttributeGraph
//  assertion 崩溃（EXC_BREAKPOINT）。改为 HStack 三栏布局避免嵌套。
//
//  【修复】工具栏新增「宏观规划」按钮，弹出 MacroPlanModal 手动触发宏观规划。
//  对齐原版 Vue MacroPlanModal.vue：宏观规划在工作台手动触发，不在向导中调 macro API。
//  弹窗关闭后刷新结构树（confirm 已在 OnboardingStore.startMacroPlanning 内完成）。
//

import SwiftUI

/// 工作台主视图
struct WorkbenchView: View {

    @EnvironmentObject var novelStore: NovelStore
    @EnvironmentObject var appState: AppState

    @StateObject private var workbenchStore = WorkbenchStore()
    @StateObject private var structureStore = StructureStore()
    @StateObject private var autopilotStore = AutopilotStore()

    /// 是否显示自动驾驶生成流
    @State private var showChapterStream = false

    /// 是否显示宏观规划弹窗
    @State private var showMacroPlan = false

    var body: some View {
        // 【修复】用 HStack 代替 NavigationSplitView，避免嵌套 NavigationSplitView
        // 导致 iOS 16 AttributeGraph assertion 崩溃
        HStack(spacing: 0) {
            // 左栏：章节导航（固定宽度）
            StoryNavigatorView()
                .environmentObject(novelStore)
                .environmentObject(structureStore)
                .frame(width: 260)

            Divider()

            // 中栏：正文编辑 / 生成流
            centerColumn
                .frame(maxWidth: .infinity)

            Divider()

            // 右栏：上下文面板（固定宽度，仅当选中章节时显示）
            if novelStore.currentChapter != nil {
                ContextPanelTabView()
                    .environmentObject(novelStore)
                    .environmentObject(workbenchStore)
                    .frame(width: 320)
            }
        }
        .navigationTitle(novelStore.currentNovel?.title ?? "工作台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // 宏观规划按钮（结构树为空时显示提醒圆点，引导用户先生成）
                // 【修复 F3】currentNovelId 为 nil 时禁用，避免传空串给 MacroPlanModal 导致 API 404
                Button {
                    showMacroPlan = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "wand.and.stars")
                        if structureStore.tree.isEmpty {
                            Circle()
                                .fill(Theme.warning)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .disabled(appState.currentNovelId == nil)

                // 切换章节流 / 正文编辑
                Button {
                    showChapterStream.toggle()
                } label: {
                    Image(systemName: showChapterStream ? "doc.text" : "car.fill")
                }
            }
        }
        .task {
            if let novelId = appState.currentNovelId {
                await structureStore.loadTree(novelId: novelId)
                await autopilotStore.refreshStatus(novelId: novelId)
            }
        }
        .onChange(of: novelStore.currentChapter?.id) { _ in
            if let chapter = novelStore.currentChapter {
                workbenchStore.loadChapter(chapter)
            }
        }
        .onChange(of: autopilotStore.isRunning) { isRunning in
            if isRunning {
                showChapterStream = true
            }
        }
        .sheet(isPresented: $showMacroPlan, onDismiss: {
            // 宏观规划弹窗关闭后刷新结构树
            // （confirm 已在 OnboardingStore.startMacroPlanning 内自动完成写入 DB）
            if let novelId = appState.currentNovelId {
                Task {
                    await structureStore.loadTree(novelId: novelId)
                }
            }
        }) {
            MacroPlanModal(novelId: appState.currentNovelId ?? "")
        }
        // 阶段3：AI 审批面板（单章生成 approval_required 接线）
        .sheet(isPresented: $workbenchStore.aiInvocationStore.visible) {
            NavigationStack {
                AIInvocationReviewPanel(store: workbenchStore.aiInvocationStore)
            }
        }
    }

    // MARK: - 中栏内容

    @ViewBuilder
    private var centerColumn: some View {
        if showChapterStream {
            ChapterStreamView()
                .environmentObject(autopilotStore)
        } else if let chapter = novelStore.currentChapter {
            ChapterContentPanel(chapter: chapter)
                .environmentObject(workbenchStore)
                .environmentObject(novelStore)
        } else {
            emptyContentPlaceholder
        }
    }

    // MARK: - 空占位

    private var emptyContentPlaceholder: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("请从左侧选择一个章节")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
