//
//  ForeshadowChapterSuggestionsPanelView.swift
//  Cangjie
//
//  待兑现疑问列表，对齐原版 components/workbench/ForeshadowChapterSuggestionsPanel.vue:1-113。
//  距离排序+checkbox+compact模式。复用ForeshadowEntry模型。
//

import SwiftUI

/// 待兑现伏笔建议面板
///
/// 对齐原版 `components/workbench/ForeshadowChapterSuggestionsPanel.vue`。
struct ForeshadowChapterSuggestionsPanelView: View {

    /// 小说 ID（对齐 :46 props.slug）
    let novelId: String

    /// 当前章节号（对齐 :47 props.currentChapterNumber）
    var currentChapterNumber: Int? = nil

    /// 嵌入模式（对齐 :48 props.embedded）
    var embedded: Bool = false

    /// 紧凑模式（对齐 :49 props.compact）
    var compact: Bool = false

    // MARK: - 状态

    @StateObject private var store = ForeshadowStore()
    @State private var picked: Set<String> = []

    // MARK: - 计算属性

    /// 提示文本（对齐 :61-65 hintText）
    private var hintText: String {
        return "与「伏笔账本」同源：列出待兑现疑问，按与当前章的距离排序（近者优先）。"
    }

    /// 待兑现疑问列表（对齐 :69-82 items computed）
    private var items: [(entry: ForeshadowEntry, distance: Int)] {
        guard let ch = currentChapterNumber else { return [] }
        let pending = store.entries.filter { $0.status == "pending" }
        var rows = pending.map { entry -> (ForeshadowEntry, Int) in
            (entry, abs(entry.chapter - ch))
        }
        rows.sort { a, b in
            if a.1 != b.1 { return a.1 < b.1 }
            return a.0.chapter < b.0.chapter
        }
        return rows.map { (entry: $0.0, distance: $0.1) }
    }

    // MARK: - Body

    var body: some View {
        if currentChapterNumber == nil {
            // 对齐 :3 空状态（未选章节）
            VStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.textTertiary)
                Text("请先选择章节")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if !hintText.isEmpty {
                    Text(hintText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }

                if store.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if items.isEmpty {
                    Text("暂无待兑现疑问")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    // 对齐 :9-33 列表
                    let maxItems = compact ? 5 : 12
                    ForEach(items.prefix(maxItems), id: \.entry.id) { row in
                        itemCard(row)
                    }
                }
            }
            .task {
                await load()
            }
            .onChange(of: novelId) { _ in Task { await load() } }
            .onChange(of: currentChapterNumber) { _ in Task { await load() } }
        }
    }

    // MARK: - 疑问卡片（对齐 :10-32）

    private func itemCard(_ row: (entry: ForeshadowEntry, distance: Int)) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 对齐 :18-21 checkbox
            Image(systemName: picked.contains(row.entry.id) ? "checkmark.square.fill" : "square")
                .foregroundColor(picked.contains(row.entry.id) ? Theme.primary : Theme.textTertiary)
                .onTapGesture {
                    togglePick(row.entry.id)
                }

            VStack(alignment: .leading, spacing: 6) {
                // 对齐 :23-28 标签行
                HStack(spacing: 6) {
                    Text("第\(row.entry.chapter)章埋入")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(999)

                    // 对齐 :25-27 距离Tag
                    Text(row.distance == 0 ? "同章" : "距本章 \(row.distance) 章")
                        .font(.system(size: 11))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.info.opacity(0.1))
                        .cornerRadius(999)
                        .foregroundColor(Theme.info)
                }

                // 对齐 :29 疑问文本
                Text(row.entry.question)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .padding(8)
        .background(Theme.secondaryBackground)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    // MARK: - checkbox 选中（对齐 :84-89 togglePick）

    private func togglePick(_ id: String) {
        if picked.contains(id) {
            picked.remove(id)
        } else {
            picked.insert(id)
        }
    }

    // MARK: - 加载（对齐 :91-100 load）

    private func load() async {
        guard !novelId.isEmpty else { return }
        await store.loadEntries(novelId: novelId)
        picked.removeAll()
    }
}
