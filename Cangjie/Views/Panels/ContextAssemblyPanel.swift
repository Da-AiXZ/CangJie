//
//  ContextAssemblyPanel.swift
//  Cangjie
//
//  上下文装配（当前章节生成时的上下文预览：角色摘要+前情提要+伏笔锚点+世界设定片段）。
//

import SwiftUI

struct ContextAssemblyPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var novelStore: NovelStore
    @StateObject private var bibleStore = BibleStore()
    @StateObject private var foreshadowStore = ForeshadowStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // 角色摘要
                if !bibleStore.characters.isEmpty {
                    section("角色摘要", icon: "person.2.fill") {
                        ForEach(bibleStore.characters.prefix(5)) { ch in
                            HStack {
                                Text(ch.name).font(.system(size: 10, weight: .medium))
                                if !ch.coreMotivation.isEmpty {
                                    Text("— \(ch.coreMotivation)").font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(1)
                                }
                            }
                        }
                    }
                }

                // 前情提要
                section("前情提要", icon: "text.book.closed") {
                    let completedChapters = novelStore.chapters.filter { $0.status == "completed" }
                    if completedChapters.isEmpty {
                        Text("暂无已完成章节").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                    } else {
                        ForEach(completedChapters.suffix(3)) { ch in
                            Text("第\(ch.number)章 \(ch.title)").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                        }
                    }
                }

                // 伏笔锚点
                section("伏笔锚点", icon: "lightbulb.fill") {
                    let pending = foreshadowStore.pendingEntries
                    if pending.isEmpty {
                        Text("暂无待闭合伏笔").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                    } else {
                        ForEach(pending.prefix(5)) { entry in
                            Text("• \(entry.question)").font(.system(size: 9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                        }
                    }
                }

                // 世界设定片段
                if !bibleStore.worldSettings.isEmpty {
                    section("世界设定", icon: "globe.asia.australia.fill") {
                        ForEach(bibleStore.worldSettings.prefix(3)) { setting in
                            Text("• \(setting.name): \(setting.description.prefix(30))").font(.system(size: 9)).foregroundColor(Theme.textSecondary).lineLimit(1)
                        }
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await bibleStore.loadBible(novelId: novelId)
                await foreshadowStore.loadEntries(novelId: novelId)
            }
        }
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.primary)
            content()
        }
    }
}
