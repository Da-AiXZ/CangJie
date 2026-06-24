//
//  ChapterToolbar.swift
//  Cangjie
//
//  中栏顶部工具栏：章节标题/状态标签/字数/保存按钮/AI审阅按钮/生成提示按钮。
//  对齐 Vue3 WorkArea.vue 的章节头部信息。
//

import SwiftUI

/// 章节工具栏
struct ChapterToolbar: View {

    let chapter: ChapterDTO

    @EnvironmentObject var workbenchStore: WorkbenchStore
    @EnvironmentObject var novelStore: NovelStore

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 章节号
            Text("第\(chapter.number)章")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.primary)

            // 状态标签
            statusBadge

            Divider()
                .frame(height: 20)

            // 字数
            Text("\(chapter.wordCount) 字")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            // M5 单章生成按钮（workflow.ts:375）
            if workbenchStore.isGeneratingChapter {
                // 生成中：显示进度
                ProgressView()
                    .scaleEffect(0.7)
                if let phase = workbenchStore.generateChapterPhase {
                    Text(phaseLabel(phase))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.primary)
                }
            } else {
                // 生成按钮（workflow.ts:375 consumeGenerateChapterStream）
                Button {
                    Task {
                        if let novelId = novelStore.currentNovel?.id {
                            // 风险点 6.3：generationHint 可能为空，处理 nil 情况
                            let outline = workbenchStore.generationHint.isEmpty ? chapter.title : workbenchStore.generationHint
                            workbenchStore.consumeGenerateChapterStream(
                                novelId: novelId,
                                chapterNumber: chapter.number,
                                outline: outline
                            )
                        }
                    }
                } label: {
                    Label("生成", systemImage: "wand.and.stars")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                // 风险点 6.3：generationHint 为 nil 时禁用按钮 + 提示
                .disabled(workbenchStore.generationHint.isEmpty && chapter.title.isEmpty)
            }

            Divider()
                .frame(height: 20)

            // 保存指示
            if workbenchStore.isSaving {
                ProgressView()
                    .scaleEffect(0.7)
            } else if workbenchStore.hasUnsavedChanges {
                Text("未保存")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.warning)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.success)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    /// phase 中文标签（workflow.ts:354 phase 值：planning/context/script/prose/outline_planning/llm/post）
    private func phaseLabel(_ phase: String) -> String {
        switch phase {
        case "planning": return "规划中"
        case "context": return "上下文"
        case "script": return "剧本"
        case "prose": return "正文"
        case "outline_planning": return "大纲规划"
        case "llm": return "LLM"
        case "post": return "后处理"
        default: return phase
        }
    }

    // MARK: - 状态标签

    private var statusBadge: some View {
        let statusColor: Color = chapter.status == "completed" ? Theme.success : Theme.warning
        let statusText: String = chapter.status == "completed" ? "已完成" : "草稿"

        return Text(statusText)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor)
            .cornerRadius(4)
    }
}
