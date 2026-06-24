//
//  ChapterGenerationPanel.swift
//  Cangjie
//
//  单章生成面板：phase 进度 + 正文流式 + 一致性报告。
//  对齐 workflow.ts:375-511 的 7 类 SSE 事件 UI 展示。
//  Q6决策：简化版 UI，最低要求：触发按钮 + phase 进度 + 正文流式 + done 后一致性报告。
//

import SwiftUI

/// 单章生成面板
struct ChapterGenerationPanel: View {

    let chapter: ChapterDTO

    @EnvironmentObject var workbenchStore: WorkbenchStore
    @EnvironmentObject var novelStore: NovelStore

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // 生成中：phase 进度 + 正文流式
            if workbenchStore.isGeneratingChapter {
                generatingView
            }

            // done 后：一致性报告
            if let report = workbenchStore.generateChapterConsistencyReport {
                consistencyReportView(report)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground.opacity(0.5))
    }

    // MARK: - 生成中视图

    private var generatingView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // phase 进度条（workflow.ts:418-425 phase 事件）
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView()
                    .scaleEffect(0.8)

                if let phase = workbenchStore.generateChapterPhase {
                    Text(phaseLabel(phase))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.primary)
                } else {
                    Text("正在连接...")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                // 取消按钮
                Button {
                    if let novelId = novelStore.currentNovel?.id {
                        workbenchStore.cancelGenerateChapterStream(novelId: novelId)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            // 正文流式渲染（workflow.ts:447-452 chunk 事件实时追加）
            if !workbenchStore.generateChapterContent.isEmpty {
                ScrollView {
                    Text(workbenchStore.generateChapterContent)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
                .padding(Theme.Spacing.sm)
                .background(Theme.background)
                .cornerRadius(Theme.CornerRadius.medium)
            }
        }
    }

    // MARK: - 一致性报告视图（workflow.ts:453-483 done 事件）

    private func consistencyReportView(_ report: ConsistencyReportDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(Theme.success)
                Text("一致性报告")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("问题 \(report.issues.count) · 警告 \(report.warnings.count)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }

            // 问题列表
            if !report.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(report.issues) { issue in
                        HStack(alignment: .top) {
                            Circle()
                                .fill(Theme.error)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("[\(issue.severity)] \(issue.type)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.error)
                                Text(issue.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textPrimary)
                                Text("位置: 第\(issue.location)字")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                    }
                }
            }

            // 警告列表
            if !report.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(report.warnings) { warning in
                        HStack(alignment: .top) {
                            Circle()
                                .fill(Theme.warning)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("[\(warning.severity)] \(warning.type)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Theme.warning)
                                Text(warning.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                }
            }

            // 建议
            if !report.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("改进建议")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    ForEach(report.suggestions.indices, id: \.self) { index in
                        Text("• \(report.suggestions[index])")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }

            // 文风警告（workflow.ts:468-470 style_warnings）
            if let styleWarnings = workbenchStore.generateChapterStyleWarnings, !styleWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("文风警告")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    ForEach(styleWarnings) { warning in
                        HStack(alignment: .top) {
                            Image(systemName: warning.severity == "warning" ? "exclamationmark.triangle" : "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(warning.severity == "warning" ? Theme.warning : Theme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(warning.pattern)
                                    .font(.system(size: 11, weight: .medium))
                                Text(warning.text)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 辅助

    /// phase 中文标签（workflow.ts:354）
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
}
