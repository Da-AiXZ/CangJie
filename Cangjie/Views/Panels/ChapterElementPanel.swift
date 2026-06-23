//
//  ChapterElementPanel.swift
//  Cangjie
//
//  章节元素（当前章节涉及的实体/地点/道具/伏笔引用）。
//

import SwiftUI

struct ChapterElementPanel: View {
    @EnvironmentObject var novelStore: NovelStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let chapter = novelStore.currentChapter {
                    elementSection("角色", icon: "person.2.fill", items: extractCharacters(from: chapter.content))
                    elementSection("地点", icon: "mappin.and.ellipse", items: extractLocations(from: chapter.content))
                    elementSection("道具", icon: "shippingbox.fill", items: [])
                    elementSection("伏笔引用", icon: "lightbulb.fill", items: [])
                } else {
                    Text("请先选择章节")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
    }

    private func elementSection(_ title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.primary)
            if items.isEmpty {
                Text("暂无").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
            } else {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private func extractCharacters(from content: String) -> [String] {
        // 简化：从引号对话中提取说话人
        return []
    }

    private func extractLocations(from content: String) -> [String] {
        return []
    }
}
