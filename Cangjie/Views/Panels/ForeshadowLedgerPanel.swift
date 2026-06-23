//
//  ForeshadowLedgerPanel.swift
//  Cangjie
//
//  伏笔手账本（伏笔列表+状态+来源章节+闭合章节+urgency 排序），调 ForeshadowStore。
//

import SwiftUI

struct ForeshadowLedgerPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = ForeshadowStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                if store.entries.isEmpty {
                    Text("暂无伏笔")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textTertiary)
                        .padding()
                } else {
                    ForEach(store.entries.sorted(by: urgencySort)) { entry in
                        entryRow(entry)
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadEntries(novelId: novelId)
            }
        }
    }

    private func urgencySort(_ a: ForeshadowEntry, _ b: ForeshadowEntry) -> Bool {
        if a.status == "pending" && b.status != "pending" { return true }
        if a.status != "pending" && b.status == "pending" { return false }
        return a.chapter < b.chapter
    }

    private func entryRow(_ entry: ForeshadowEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(statusColor(entry.status)).frame(width: 6, height: 6)
                Text(entry.question).font(.system(size: 12)).lineLimit(2)
                Spacer()
                Text(statusLabel(entry.status)).font(.system(size: 9)).foregroundColor(statusColor(entry.status))
            }
            HStack(spacing: 8) {
                Text("第\(entry.chapter)章埋").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                if let consumed = entry.consumedAtChapter {
                    Text("→ 第\(consumed)章闭合").font(.system(size: 9)).foregroundColor(Theme.success)
                }
                if entry.isPriorityForChapter { Text("优先").font(.system(size: 9)).foregroundColor(Theme.warning) }
            }
        }
        .padding(.vertical, 2)
    }

    private func statusColor(_ s: String) -> Color {
        switch s { case "pending": return Theme.warning; case "consumed": return Theme.success; default: return Theme.textTertiary }
    }
    private func statusLabel(_ s: String) -> String { s == "pending" ? "待闭合" : s == "consumed" ? "已闭合" : s }
}
