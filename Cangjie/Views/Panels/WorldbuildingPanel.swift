//
//  WorldbuildingPanel.swift
//  Cangjie
//
//  世界观五维度编辑（物理/社会/魔法/科技/文化），表单，调 BibleStore。
//

import SwiftUI

struct WorldbuildingPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bibleStore = BibleStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let bible = bibleStore.bible {
                    // 世界设定列表
                    ForEach(bible.worldSettings) { setting in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "globe.asia.australia.fill").foregroundColor(Theme.primary)
                                Text(setting.name).font(Theme.headlineFont())
                                Spacer()
                                Text(setting.settingType).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            }
                            if !setting.description.isEmpty {
                                Text(setting.description).font(.system(size: 12)).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }

                    Divider()

                    // 文风
                    if !bible.style.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("文风公约").font(.system(size: 12, weight: .semibold))
                            Text(bible.style).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                    }

                    // 风格笔记
                    ForEach(bible.styleNotes) { note in
                        HStack {
                            Text(note.category).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.primary).frame(width: 60, alignment: .leading)
                            Text(note.content).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                    }
                } else {
                    Text("暂无世界观数据")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await bibleStore.loadBible(novelId: novelId)
            }
        }
    }
}
