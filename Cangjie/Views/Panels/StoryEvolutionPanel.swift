//
//  StoryEvolutionPanel.swift
//  Cangjie
//
//  故事演化（角色/世界观/关系演化时间线），调 EvolutionStore。
//

import SwiftUI

struct StoryEvolutionPanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = EvolutionStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if store.snapshots.isEmpty {
                    Text("暂无演化记录").font(Theme.captionFont()).foregroundColor(Theme.textTertiary).padding()
                } else {
                    // 计数
                    HStack(spacing: Theme.Spacing.md) {
                        ForEach(store.counts.sorted(by: { $0.key < $1.key }), id: \.key) { status, count in
                            VStack(spacing: 1) {
                                Text("\(count)").font(.system(size: 14, weight: .bold, design: .rounded))
                                Text(status).font(.system(size: 8)).foregroundColor(Theme.textTertiary)
                            }
                        }
                    }

                    // 时间线
                    ForEach(store.snapshots.prefix(20)) { snap in
                        HStack(alignment: .top, spacing: 6) {
                            VStack {
                                Circle().fill(statusColor(snap.status)).frame(width: 8, height: 8)
                                Rectangle().fill(Theme.textTertiary.opacity(0.3)).frame(width: 2)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("第\(snap.chapterNumber)章").font(.system(size: 11, weight: .medium))
                                Text(snap.status).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                                if let date = snap.createdAt { Text(date).font(.system(size: 8)).foregroundColor(Theme.textTertiary) }
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadSnapshots(novelId: novelId)
            }
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s { case "approved": return Theme.success; case "rejected": return Theme.error; case "pending": return Theme.warning; default: return Theme.textSecondary }
    }
}
