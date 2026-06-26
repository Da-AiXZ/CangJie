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
    @StateObject private var dagStore = DAGStore()

    /// 是否显示自动驾驶生成流
    @State private var showChapterStream = false

    /// 是否显示宏观规划弹窗
    @State private var showMacroPlan = false

    var body: some View {
        VStack(spacing: 0) {
            // P0-4：顶部 header — workMode 开关
            workModeHeader

            // P0-4：双视图 ZStack（辅助侧 + 托管侧同时保留在内存，opacity 切换不用 if/else 销毁）
            // 对齐 WorkArea.vue L22-26 注释：切到辅助撰稿时若卸载 AutopilotPanel，
            // 其 onUnmounted 会 stopChapterStream()，章节 SSE 断开会导致全托管写作异常。
            ZStack(alignment: .top) {
                // 辅助撰稿侧
                assistedStack
                    .opacity(workbenchStore.workMode == "assisted" ? 1 : 0)
                    .offset(y: workbenchStore.workMode == "assisted" ? 0 : -1000)

                // 托管撰稿侧
                managedStack
                    .opacity(workbenchStore.workMode == "managed" ? 1 : 0)
                    .offset(y: workbenchStore.workMode == "managed" ? 0 : 1000)
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
                // P0-4：加载 workMode 持久化状态
                workbenchStore.loadWorkMode(novelId: novelId)
                // P0-4 集成遗留：DAGRunStore ← → DAGStore 注入
                dagStore.setDAGRunStore(workbenchStore.dagRunStore)
                workbenchStore.dagRunStore.setDAGStore(dagStore)
                await dagStore.hydrateDagForNovel(novelId: novelId)
                await dagStore.loadDAGStatus(novelId: novelId)
                // 启动 DAG 事件 SSE（托管侧需要实时事件）
                dagStore.startDAGEvents(novelId: novelId)
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
        // P0-2：AI 生成弹窗
        .sheet(isPresented: $workbenchStore.showGenerateModal) {
            NavigationStack {
                if let novelId = appState.currentNovelId {
                    ChapterGenerateModalView(
                        novelId: novelId,
                        chapters: novelStore.chapters,
                        currentChapterNumber: novelStore.currentChapter?.number ?? 1
                    )
                    .environmentObject(workbenchStore)
                }
            }
        }
        // P0-5：张力诊断弹窗
        .sheet(isPresented: $workbenchStore.showTensionModal) {
            NavigationStack {
                if let novelId = appState.currentNovelId {
                    TensionDiagnosisModalView(
                        novelId: novelId,
                        chapterNumber: novelStore.currentChapter?.number ?? 1
                    )
                    .environmentObject(workbenchStore)
                }
            }
        }
    }

    // MARK: - P0-4 workMode 开关 header

    private var workModeHeader: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(workbenchStore.workMode == "assisted" ? "辅助撰稿" : "托管撰稿")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.primary)

            Toggle("", isOn: Binding(
                get: { workbenchStore.workMode == "managed" },
                set: { newValue in
                    workbenchStore.workMode = newValue ? "managed" : "assisted"
                    if let novelId = appState.currentNovelId {
                        workbenchStore.saveWorkMode(novelId: novelId)
                    }
                }
            ))
            .labelsHidden()
            .tint(Theme.primary)

            Text(workbenchStore.workMode == "assisted" ? "辅助" : "托管")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 辅助撰稿侧

    @ViewBuilder
    private var assistedStack: some View {
        VStack(spacing: 0) {
            // P0-4：isAssistedReadOnly 警告横幅（对齐 WorkArea.vue L27-36）
            if workbenchStore.isAssistedReadOnly {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.warning)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("全托管运行中")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.warning)
                        Text("本侧仅只读；不能保存、改稿、快速生成或改章节元素。请切换到\u{201C}托管撰稿\u{201D}看驾驶舱与监控，或停止托管后再编辑。")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(Theme.warning.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.xs)
            }

            // 原有三栏布局
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
        }
        .disabled(workbenchStore.isAssistedReadOnly)
    }

    // MARK: - 托管撰稿侧

    @ViewBuilder
    private var managedStack: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let novelId = appState.currentNovelId {
                    // 控制面板（含 P0-4 startRun/stopRun 按钮）
                    AutopilotControlPanel(novelId: novelId)
                        .environmentObject(autopilotStore)
                        .environmentObject(workbenchStore)

                    // DAG 画布
                    DAGCanvasView(novelId: novelId)
                        .environmentObject(dagStore)
                        .frame(minHeight: 400)

                    // 日志流
                    AutopilotLogStream(novelId: novelId)
                        .environmentObject(autopilotStore)
                        .frame(minHeight: 300)
                } else {
                    Text("请先选择一部小说")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background)
    }

    // MARK: - 中栏内容

    @ViewBuilder
    private var centerColumn: some View {
        if showChapterStream {
            ChapterStreamView()
                .environmentObject(autopilotStore)
        } else if let chapter = novelStore.currentChapter {
            ChapterEditorView(chapter: chapter)
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
