//
//  WorkbenchView.swift
//  Cangjie
//
//  工作台三栏 NavigationSplitView：
//  左：章节树导航 / 中：正文编辑或生成流 / 右：上下文面板 TabView。
//  对齐 Vue3 Workbench.vue 的 n-split 三栏布局。
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

    var body: some View {
        NavigationSplitView {
            // 左栏：章节导航
            StoryNavigatorView()
                .environmentObject(novelStore)
                .environmentObject(structureStore)
        } content: {
            // 中栏：正文编辑 / 生成流
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
        } detail: {
            // 右栏：上下文面板
            if novelStore.currentChapter != nil {
                ContextPanelTabView()
                    .environmentObject(novelStore)
                    .environmentObject(workbenchStore)
            } else {
                Color.clear
            }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(novelStore.currentNovel?.title ?? "工作台")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
