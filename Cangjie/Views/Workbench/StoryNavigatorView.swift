//
//  StoryNavigatorView.swift
//  Cangjie
//
//  左栏：OutlineGroup 递归树（部/卷/幕/章），支持展开折叠，点击切换章节。
//  对齐 Vue3 ChapterList.vue 的 StoryStructureTree 交互。
//

import SwiftUI

/// 故事导航树视图
struct StoryNavigatorView: View {

    @EnvironmentObject var novelStore: NovelStore
    @EnvironmentObject var structureStore: StructureStore

    // B-2：视图切换状态
    /// 视图模式：tree（树形）/ flat（平铺）
    @State private var viewMode: ViewMode = .tree

    /// 平铺视图分页：当前显示数量（每次 50）
    @State private var visibleCount: Int = 50

    /// 是否显示宏观规划弹窗
    @State private var showMacroPlan: Bool = false

    // B-2：视图模式枚举
    enum ViewMode: String, CaseIterable {
        case tree = "树形"
        case flat = "平铺"
    }

    /// 生成偏好（用于 narrativeOrdinalLabel）
    private var generationPrefs: GenerationPrefsDTO? {
        return novelStore.currentNovel?.generationPrefs
    }

    /// 平铺视图可见章节
    private var visibleChapters: [ChapterDTO] {
        return Array(novelStore.chapters.prefix(visibleCount))
    }

    /// 剩余章节数
    private var remainingCount: Int {
        return max(0, novelStore.chapters.count - visibleCount)
    }

    var body: some View {
        List {
            // B-2：视图模式切换 Picker
            Section {
                Picker("视图", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch viewMode {
            case .tree:
                // B-2：树形视图
                treeViewSection
            case .flat:
                // B-2：平铺视图（分页 50/50）
                flatViewSection
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("章节")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        if let novelId = novelStore.currentNovel?.id {
                            await structureStore.loadTree(novelId: novelId)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            // B-2：幕→章规划入口
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showMacroPlan = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showMacroPlan) {
            // B-2：宏观规划弹窗
            if let novelId = novelStore.currentNovel?.id {
                MacroPlanModal(novelId: novelId)
            }
        }
    }

    // MARK: - B-2 树形视图

    private var treeViewSection: some View {
        Group {
            // 结构树（如果已加载）
            if !structureStore.tree.isEmpty {
                Section("结构") {
                    ForEach(structureStore.tree) { node in
                        structureNodeRow(node, level: 0)
                    }
                }
            }

            // 章节列表（树形模式显示全部）
            if !novelStore.chapters.isEmpty {
                Section("章节") {
                    ForEach(novelStore.chapters) { chapter in
                        chapterRow(chapter)
                    }
                }
            }

            // 空状态
            if novelStore.chapters.isEmpty && structureStore.tree.isEmpty {
                Text("暂无章节")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - B-2 平铺视图

    private var flatViewSection: some View {
        Group {
            if visibleChapters.isEmpty {
                Text("暂无章节")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
            } else {
                Section("章节（\(novelStore.chapters.count)）") {
                    ForEach(visibleChapters) { chapter in
                        // B-2：使用 narrativeOrdinalLabel 显示章号
                        flatChapterRow(chapter)
                    }

                    // B-2：查看更多（剩余 N 章）
                    if remainingCount > 0 {
                        Button {
                            visibleCount += 50
                        } label: {
                            HStack {
                                Spacer()
                                Text("查看更多（剩余 \(remainingCount) 章）")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 章节行

    private func chapterRow(_ chapter: ChapterDTO) -> some View {
        Button {
            novelStore.selectChapter(chapter)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // 状态指示点
                Circle()
                    .fill(chapter.status == "completed" ? Theme.success : Theme.warning)
                    .frame(width: 6, height: 6)

                // 章节号（B-2：使用 narrativeOrdinalLabel）
                Text(narrativeOrdinalLabel(chapter.number, generationPrefs))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                // 标题
                Text(chapter.title)
                    .font(Theme.bodyFont())
                    .lineLimit(1)
                    .foregroundColor(novelStore.currentChapter?.id == chapter.id ? Theme.primary : Theme.textPrimary)

                Spacer()

                // 字数
                if chapter.wordCount > 0 {
                    Text(formatWordCount(chapter.wordCount))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - B-2 平铺章节行

    /// 平铺视图章节行，使用 narrativeOrdinalLabel 显示章号
    private func flatChapterRow(_ chapter: ChapterDTO) -> some View {
        Button {
            novelStore.selectChapter(chapter)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                // 状态指示点
                Circle()
                    .fill(chapter.status == "completed" ? Theme.success : Theme.warning)
                    .frame(width: 6, height: 6)

                // B-2：使用 narrativeOrdinalLabel（阶段模式显示"第 N 阶段"，章模式显示"第 N 章"）
                Text(narrativeOrdinalLabel(chapter.number, generationPrefs))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                // 标题
                Text(chapter.title)
                    .font(Theme.bodyFont())
                    .lineLimit(1)
                    .foregroundColor(novelStore.currentChapter?.id == chapter.id ? Theme.primary : Theme.textPrimary)

                Spacer()

                // 字数
                if chapter.wordCount > 0 {
                    Text(formatWordCount(chapter.wordCount))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 结构节点行

    private func structureNodeRow(_ node: StoryNode, level: Int) -> some View {
        DisclosureGroup(isExpanded: .constant(true)) {
            if let children = node.children {
                ForEach(children) { child in
                    AnyView(structureNodeRow(child, level: level + 1))
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: nodeTypeIcon(node.nodeType))
                    .foregroundColor(nodeTypeColor(node.nodeType))
                    .font(.system(size: 12))

                Text(node.title)
                    .font(Theme.bodyFont())
                    .lineLimit(1)
            }
            .padding(.leading, CGFloat(level) * Theme.Spacing.xs)
        }
    }

    // MARK: - 辅助

    private func formatWordCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万", Double(count) / 10000)
        }
        return "\(count)"
    }

    private func nodeTypeIcon(_ type: String) -> String {
        switch type {
        case "part": return "book.fill"
        case "volume": return "books.vertical.fill"
        case "act": return "rectangle.split.3x1.fill"
        case "chapter": return "doc.text.fill"
        default: return "circle.fill"
        }
    }

    private func nodeTypeColor(_ type: String) -> Color {
        switch type {
        case "part": return Theme.primary
        case "volume": return Theme.info
        case "act": return Theme.warning
        case "chapter": return Theme.success
        default: return Theme.textSecondary
        }
    }
}
