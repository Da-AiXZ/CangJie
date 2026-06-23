//
//  StoryPhasePanel.swift
//  Cangjie
//
//  故事阶段（三幕/五幕结构定位+当前阶段+阶段转换条件），调 SnapshotStore。
//

import SwiftUI

struct StoryPhasePanel: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = SnapshotStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if let phase = store.storyPhase {
                    // 当前阶段
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前阶段").font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textTertiary)
                        Text(phaseLabel(phase.phase)).font(Theme.headlineFont()).foregroundColor(Theme.primary)
                        if !phase.description.isEmpty {
                            Text(phase.description).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                        }
                        ProgressView(value: phase.progress).tint(Theme.primary)
                        Text("\(Int(phase.progress * 100))%").font(.system(size: 10)).foregroundColor(Theme.textTertiary)
                    }

                    // 转换条件
                    HStack {
                        Image(systemName: phase.canAdvance ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundColor(phase.canAdvance ? Theme.success : Theme.textTertiary)
                        Text(phase.canAdvance ? "可推进到下一阶段" : "条件未满足").font(.system(size: 11))
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
                await store.loadStoryPhase(novelId: novelId)
            }
        }
    }

    private func phaseLabel(_ phase: String) -> String {
        switch phase {
        case "setup": return "第一幕 · 铺设"
        case "rising": return "上升阶段"
        case "midpoint": return "中点"
        case "falling": return "下降阶段"
        case "climax": return "高潮"
        case "resolution": return "结局"
        default: return phase
        }
    }
}
