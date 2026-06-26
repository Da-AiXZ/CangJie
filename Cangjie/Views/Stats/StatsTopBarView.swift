//
//  StatsTopBarView.swift
//  Cangjie
//
//  顶栏统计条，显示 GlobalStats 4 指标。对齐原版 stats 组件。
//

import SwiftUI

/// 顶栏统计条视图
struct StatsTopBarView: View {
    @StateObject private var statsStore = StatsStore()

    var body: some View {
        HStack(spacing: 0) {
            if let global = statsStore.globalStats {
                topBarItem(icon: "books.vertical.fill", value: global.totalBooks, label: "书籍")
                divider
                topBarItem(icon: "doc.text.fill", value: global.totalChapters, label: "章节")
                divider
                topBarItem(icon: "textformat.size", value: global.totalWords, label: "字数")
                divider
                topBarItem(icon: "person.2.fill", value: global.totalCharacters, label: "角色")
            } else if statsStore.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity)
            } else {
                Text("统计加载失败")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
        .task {
            await statsStore.loadGlobalStats()
        }
    }

    private func topBarItem(icon: String, value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.primary)
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 24)
    }
}
