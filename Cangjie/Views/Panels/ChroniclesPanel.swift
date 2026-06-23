//
//  ChroniclesPanel.swift
//  Cangjie
//
//  双螺旋编年史（双轨 TimelineView：剧情时间线+现实时间线），调对应 Store。
//

import SwiftUI

struct ChroniclesPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var chronicles: ChroniclesResponse?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let chron = chronicles {
                    ForEach(chron.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            // 章节号
                            Text("第\(row.chapterIndex)章")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.primary)

                            // 剧情事件
                            if !row.storyEvents.isEmpty {
                                ForEach(row.storyEvents) { event in
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill").font(.system(size: 8)).foregroundColor(Theme.info)
                                        Text(event.title).font(.system(size: 10, weight: .medium))
                                    }
                                    if !event.description.isEmpty {
                                        Text(event.description).font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(2)
                                    }
                                }
                            }

                            // 快照
                            if !row.snapshots.isEmpty {
                                ForEach(row.snapshots) { snap in
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill").font(.system(size: 8)).foregroundColor(Theme.success)
                                        Text(snap.name).font(.system(size: 10))
                                        Text(snap.kind).font(.system(size: 8)).foregroundColor(Theme.textTertiary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                } else {
                    Text("加载中…").font(Theme.captionFont()).foregroundColor(Theme.textTertiary)
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                do {
                    chronicles = try await APIClient.shared.request(APIEndpoint.Chronicles.get(novelId: novelId))
                } catch {}
            }
        }
    }
}
