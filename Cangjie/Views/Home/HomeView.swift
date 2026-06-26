//
//  HomeView.swift
//  Cangjie
//
//  书架主页：LazyVGrid 卡片网格，+号新建 sheet，长按上下文菜单，下拉刷新。
//  对齐 Vue3 Home.vue 交互：卡片网格 + 搜索 + 空状态 + 加载骨架。
//

import SwiftUI

/// 书架主页
struct HomeView: View {

    @EnvironmentObject var novelStore: NovelStore

    /// 点击新建回调
    var onCreateNovel: () -> Void

    /// 点击书目回调
    var onOpenNovel: (NovelDTO) -> Void

    // MARK: - 本地状态

    @State private var searchQuery: String = ""

    // B-1：批量操作状态
    /// 是否处于批量选择模式
    @State private var batchMode: Bool = false
    /// 选中的书目 ID 集合
    @State private var selectedBookIds: Set<String> = []
    /// 是否显示"查看全部"弹窗
    @State private var showAllBooks: Bool = false
    /// 是否显示高级设置
    @State private var showAdvanced: Bool = false
    /// 高级设置：自定义章数
    @State private var customTargetChapters: Int = 100
    /// 高级设置：每章字数
    @State private var customWordsPerChapter: Int = 2500

    // MARK: - 筛选

    /// 搜索过滤后的书目
    private var filteredNovels: [NovelDTO] {
        guard !searchQuery.isEmpty else { return novelStore.novels }
        return novelStore.novels.filter { novel in
            novel.title.localizedCaseInsensitiveContains(searchQuery) ||
            novel.lockedGenre.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    // MARK: - 网格列

    /// 自适应网格列
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Theme.Spacing.md)
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                // 标题区
                headerSection

                // 搜索栏
                if !novelStore.novels.isEmpty {
                    searchBar
                }

                // 内容区
                if novelStore.isLoading {
                    loadingState
                } else if novelStore.novels.isEmpty {
                    emptyState
                } else if filteredNovels.isEmpty {
                    noResultsState
                } else {
                    booksGrid

                    // B-1：批量操作栏
                    if batchMode && !selectedBookIds.isEmpty {
                        batchActionBar
                    }

                    // B-1：高级设置切换
                    if showAdvanced {
                        advancedSettingsSection
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("书架")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    // B-1：批量操作切换按钮
                    if !novelStore.novels.isEmpty {
                        Button {
                            batchMode.toggle()
                            if !batchMode {
                                selectedBookIds.removeAll()
                            }
                        } label: {
                            Image(systemName: batchMode ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 18))
                        }
                    }

                    Button(action: onCreateNovel) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
            }
        }
        .refreshable {
            await novelStore.loadNovels()
        }
        .alert("错误", isPresented: .constant(novelStore.errorMessage != nil)) {
            Button("确定") {
                novelStore.errorMessage = nil
            }
        } message: {
            Text(novelStore.errorMessage ?? "")
        }
    }

    // MARK: - 标题区

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("我的书目")
                    .font(Theme.titleFont())
                    .frame(maxWidth: .infinity, alignment: .leading)

                // B-1：高级设置切换
                if !novelStore.novels.isEmpty {
                    Button {
                        showAdvanced.toggle()
                    } label: {
                        Image(systemName: showAdvanced ? "slider.horizontal.3.fill" : "slider.horizontal.3")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if !novelStore.novels.isEmpty {
                Text("\(novelStore.novels.count) 本")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textTertiary)

            TextField("搜索书名或类型…", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - 书目网格

    private var booksGrid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(filteredNovels) { novel in
                // B-1：批量模式下显示选中状态
                if batchMode {
                    NovelCardView(novel: novel) {
                        toggleBookSelection(novel.id)
                    }
                    .overlay(
                        Group {
                            if selectedBookIds.contains(novel.id) {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Theme.primary, lineWidth: 2)
                            }
                        }
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: selectedBookIds.contains(novel.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedBookIds.contains(novel.id) ? Theme.primary : Theme.textTertiary)
                            .padding(8)
                    }
                    .contextMenu {
                        Button {
                            toggleBookSelection(novel.id)
                        } label: {
                            Label(selectedBookIds.contains(novel.id) ? "取消选中" : "选中", systemImage: "checkmark")
                        }
                    }
                } else {
                    NovelCardView(novel: novel) {
                        onOpenNovel(novel)
                    }
                    .contextMenu {
                        Button {
                            onOpenNovel(novel)
                        } label: {
                            Label("进入工作台", systemImage: "book.fill")
                        }

                        Button(role: .destructive) {
                            Task {
                                await novelStore.deleteNovel(novel.id)
                            }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }

                        // B-1：查看全部弹窗
                        Button {
                            showAllBooks = true
                        } label: {
                            Label("查看全部", systemImage: "list.bullet")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAllBooks) {
            // B-1：查看全部弹窗
            NavigationStack {
                List(novelStore.novels) { novel in
                    Button {
                        showAllBooks = false
                        onOpenNovel(novel)
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(Theme.primary)
                            VStack(alignment: .leading) {
                                Text(novel.title)
                                    .font(.system(size: 14, weight: .medium))
                                Text("\(novel.lockedGenre) · \(novel.chapters.count)章")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .navigationTitle("全部书目")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") { showAllBooks = false }
                    }
                }
            }
        }
    }

    // MARK: - B-1 批量操作栏

    /// 批量操作栏：全选/反选 + 删除选中
    private var batchActionBar: some View {
        HStack(spacing: 12) {
            // 全选/反选
            Button {
                if selectedBookIds.count == filteredNovels.count {
                    selectedBookIds.removeAll()
                } else {
                    selectedBookIds = Set(filteredNovels.map { $0.id })
                }
            } label: {
                Text(selectedBookIds.count == filteredNovels.count ? "取消全选" : "全选")
                    .font(.system(size: 13))
            }

            Spacer()

            // 删除选中
            Button(role: .destructive) {
                Task {
                    for id in selectedBookIds {
                        await novelStore.deleteNovel(id)
                    }
                    selectedBookIds.removeAll()
                    batchMode = false
                }
            } label: {
                Label("删除选中(\(selectedBookIds.count))", systemImage: "trash")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.error)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - B-1 高级设置

    /// 高级设置切换按钮（放在标题区下方）
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("高级设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            HStack {
                Text("自定义章数")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Stepper("\(customTargetChapters) 章", value: $customTargetChapters, in: 1...500, step: 10)
                    .font(.system(size: 12))
            }

            HStack {
                Text("每章字数")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Stepper("\(customWordsPerChapter) 字", value: $customWordsPerChapter, in: 1000...5000, step: 500)
                    .font(.system(size: 12))
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - B-1 批量选择辅助

    /// 切换书目选中状态
    private func toggleBookSelection(_ id: String) {
        if selectedBookIds.contains(id) {
            selectedBookIds.remove(id)
        } else {
            selectedBookIds.insert(id)
        }
    }

    // MARK: - 加载状态

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中…")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundColor(Theme.textTertiary)

            Text("还没有书目")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            Text("点击右上角 + 创建你的第一本书")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textTertiary)

            Button("创建第一本书") {
                onCreateNovel()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - 无搜索结果

    private var noResultsState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)

            Text("未找到匹配「\(searchQuery)」的书目")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)

            Button("清除搜索") {
                searchQuery = ""
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }
}
