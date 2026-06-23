//
//  MacroPlanModal.swift
//  Cangjie
//
//  宏观规划弹窗（手动触发宏观规划 SSE 流式渲染，显示大纲生成过程，可编辑后确认）。
//

import SwiftUI

struct MacroPlanModal: View {
    let novelId: String
    @EnvironmentObject var appState: AppState
    @StateObject private var onboardingStore = OnboardingStore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 进度指示
                if onboardingStore.isProcessing {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("正在生成宏观结构…").font(Theme.captionFont()).foregroundColor(Theme.textSecondary)
                    }
                    .padding(Theme.Spacing.sm)
                }

                // SSE 事件渲染
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        if onboardingStore.macroPlanEvents.isEmpty {
                            Text("点击下方按钮开始宏观规划").font(Theme.captionFont()).foregroundColor(Theme.textTertiary).padding()
                        } else {
                            ForEach(onboardingStore.macroPlanEvents.indices, id: \.self) { i in
                                let event = onboardingStore.macroPlanEvents[i]
                                eventView(event)
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                }

                // 底部操作
                HStack {
                    Button("取消") { dismiss() }.buttonStyle(.bordered)
                    Spacer()
                    Button("开始规划") {
                        Task { await onboardingStore.startMacroPlanning() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(onboardingStore.isProcessing)

                    if onboardingStore.macroPlanStructure != nil {
                        Button("确认") { dismiss() }.buttonStyle(.borderedProminent).tint(Theme.success)
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("宏观规划")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                onboardingStore.createdNovel = NovelDTO(
                    id: novelId, title: "", author: "", targetChapters: 100,
                    stage: "planning", premise: "", chapters: [], totalWordCount: 0,
                    slug: "", hasBible: false, hasOutline: false, autopilotStatus: "stopped",
                    autoApproveMode: false, lockedGenre: "", lockedWorldPreset: "",
                    lockedStoryStructure: "", lockedPacingControl: "", lockedWritingStyle: "",
                    lockedSpecialRequirements: "", targetWordsPerChapter: 2500,
                    generationPrefs: AnyCodable([:])
                )
            }
        }
    }

    private func eventView(_ event: MacroPlanEvent) -> some View {
        switch event.type {
        case "status":
            return AnyView(Text(event.message ?? "").font(.system(size: 10)).foregroundColor(Theme.textSecondary))
        case "chunk":
            return AnyView(Text(event.text ?? "").font(.system(size: 11)).foregroundColor(Theme.textPrimary))
        case "node":
            return AnyView(HStack(spacing: 4) {
                Image(systemName: nodeIcon(event.nodeType ?? "")).foregroundColor(nodeColor(event.nodeType ?? "")).font(.system(size: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title ?? "").font(.system(size: 11, weight: .medium))
                    if let desc = event.description { Text(desc).font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(2) }
                }
            }.padding(.vertical, 2))
        case "done":
            return AnyView(Label("完成", systemImage: "checkmark.circle.fill").foregroundColor(Theme.success).font(.system(size: 12)))
        case "error":
            return AnyView(Label(event.error ?? "失败", systemImage: "xmark.circle.fill").foregroundColor(Theme.error).font(.system(size: 12)))
        default:
            return AnyView(EmptyView())
        }
    }

    private func nodeIcon(_ t: String) -> String { switch t { case "part": return "book.fill"; case "volume": return "books.vertical.fill"; case "act": return "rectangle.split.3x1.fill"; default: return "circle.fill" } }
    private func nodeColor(_ t: String) -> Color { switch t { case "part": return Theme.primary; case "volume": return Theme.info; case "act": return Theme.warning; default: return Theme.textSecondary } }
}
