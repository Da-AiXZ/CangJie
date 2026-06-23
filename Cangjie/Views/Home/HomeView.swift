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
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("书架")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
            Text("我的书目")
                .font(Theme.titleFont())
                .frame(maxWidth: .infinity, alignment: .leading)

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
                }
            }
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
