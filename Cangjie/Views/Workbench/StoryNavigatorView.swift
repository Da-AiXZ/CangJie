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

    var body: some View {
        List {
            // 章节列表（简化版：直接展示小说的 chapters）
            if !novelStore.chapters.isEmpty {
                Section("章节") {
                    ForEach(novelStore.chapters) { chapter in
                        chapterRow(chapter)
                    }
                }
            }

            // 结构树（如果已加载）
            if !structureStore.tree.isEmpty {
                Section("结构") {
                    ForEach(structureStore.tree) { node in
                        structureNodeRow(node, level: 0)
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

                // 章节号
                Text("第\(chapter.number)章")
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
