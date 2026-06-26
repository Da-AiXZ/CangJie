//
//  StatsSidebarView.swift
//  Cangjie
//
//  侧栏统计面板，从 StatsStore 读取（走缓存）。对齐原版 stats 组件。
//

import SwiftUI

/// 侧栏统计面板视图
struct StatsSidebarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var statsStore = StatsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 全局统计
                if let global = statsStore.globalStats {
                    StatCardView(title: "总书籍", value: "\(global.totalBooks)", icon: "books.vertical.fill")
                    StatCardView(title: "总章节", value: "\(global.totalChapters)", icon: "doc.text.fill")
                    StatCardView(title: "总字数", value: "\(global.totalWords)", icon: "textformat.size", trendColor: Theme.success)
                    StatCardView(title: "总角色", value: "\(global.totalCharacters)", icon: "person.2.fill", trendColor: Theme.info)
                } else if statsStore.isLoading {
                    ProgressView("加载统计中…")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("暂无统计数据")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                // 当前书籍统计
                if let novelId = appState.currentNovelId,
                   let bookStats = statsStore.getBookStats(novelId) {
                    Divider()
                    Text("本书统计")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    StatCardView(title: "已完成章节", value: "\(bookStats.completedChapters)/\(bookStats.totalChapters)", icon: "checkmark.circle.fill", trendColor: Theme.success)
                    StatCardView(title: "总字数", value: "\(bookStats.totalWords)", icon: "textformat.size")
                    StatCardView(title: "平均章节字数", value: "\(Int(bookStats.avgChapterWords))", icon: "chart.bar.fill")
                    StatCardView(title: "完成率", value: String(format: "%.0f%%", bookStats.completionRate * 100), icon: "percent", trendColor: bookStats.completionRate >= 0.5 ? Theme.success : Theme.warning)
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            await statsStore.loadGlobalStats()
            if let novelId = appState.currentNovelId {
                await statsStore.loadBookStats(slug: novelId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StatsStoreOnJobCompleted"))) { notification in
            if let slug = notification.userInfo?["slug"] as? String {
                Task {
                    await statsStore.loadBookStats(slug: slug, force: true)
                    await statsStore.loadGlobalStats(force: true)
                }
            }
        }
    }
}
