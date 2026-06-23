//
//  StorylinePanel.swift
//  Cangjie
//
//  故事线（主线/支线列表+进度+当前章节涉及的故事线），调 GovernanceStore。
//

import SwiftUI

struct StorylinePanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = GovernanceStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                if store.storylines.isEmpty {
                    Text("暂无故事线").font(Theme.captionFont()).foregroundColor(Theme.textTertiary).padding()
                } else {
                    ForEach(store.storylines) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Circle().fill(line.resolvedChapter != nil ? Theme.success : Theme.warning).frame(width: 6, height: 6)
                                Text(line.title).font(.system(size: 12, weight: .medium))
                                Spacer()
                                if let s = line.status { Text(s).font(.system(size: 9)).foregroundColor(Theme.textTertiary) }
                            }
                            HStack(spacing: 8) {
                                if let ch = line.introducedChapter { Text("第\(ch)章引入").font(.system(size: 9)).foregroundColor(Theme.textTertiary) }
                                if let rc = line.resolvedChapter { Text("→ 第\(rc)章闭合").font(.system(size: 9)).foregroundColor(Theme.success) }
                            }
                            if let tags = line.promiseTags, !tags.isEmpty {
                                Text(tags.map { "#\($0)" }.joined(separator: " ")).font(.system(size: 9)).foregroundColor(Theme.primary)
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
                await store.loadState(novelId: novelId)
            }
        }
    }
}
