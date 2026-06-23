//
//  ChapterContentPanel.swift
//  Cangjie
//
//  中栏：章节正文 TextEditor + 工具栏（保存/字数统计/generation_hint 编辑/AI审阅）。
//  对齐 Vue3 WorkArea.vue 的编辑器交互。
//

import SwiftUI

/// 章节内容编辑面板
struct ChapterContentPanel: View {

    let chapter: ChapterDTO

    @EnvironmentObject var workbenchStore: WorkbenchStore
    @EnvironmentObject var novelStore: NovelStore

    @State private var showHintEditor = false
    @State private var showAIReview = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            ChapterToolbar(chapter: chapter)
                .environmentObject(workbenchStore)

            // 正文编辑器
            ScrollView {
                TextEditor(text: $workbenchStore.chapterContent)
                    .chapterEditorStyle(fontSizeScale: Theme.ipadScale)
                    .frame(minHeight: 500)
                    .scrollContentBackground(.hidden)
            }
            .background(Theme.background)

            // 底部状态栏
            bottomStatusBar
        }
        .background(Theme.background)
        .navigationTitle("第\(chapter.number)章 · \(chapter.title)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            workbenchStore.loadChapter(chapter)
        }
        .sheet(isPresented: $showHintEditor) {
            hintEditorSheet
        }
        .sheet(isPresented: $showAIReview) {
            aiReviewSheet
        }
        .alert("错误", isPresented: .constant(workbenchStore.errorMessage != nil)) {
            Button("确定") { workbenchStore.errorMessage = nil }
        } message: {
            Text(workbenchStore.errorMessage ?? "")
        }
    }

    // MARK: - 底部状态栏

    private var bottomStatusBar: some View {
        HStack(spacing: Theme.Spacing.md) {
            // 字数
            Label(workbenchStore.currentWordCountDisplay, systemImage: "text.alignleft")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            // 保存状态
            if workbenchStore.hasUnsavedChanges {
                Text("● 未保存")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.warning)
            } else {
                Text("已保存")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            // 保存按钮
            if workbenchStore.hasUnsavedChanges {
                Button {
                    Task {
                        if let novelId = novelStore.currentNovel?.id {
                            await workbenchStore.saveChapter(novelId: novelId, chapterNumber: chapter.number)
                        }
                    }
                } label: {
                    Label("保存", systemImage: "tray.and.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .disabled(workbenchStore.isSaving)
            }

            // 生成提示按钮
            Button {
                showHintEditor = true
            } label: {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

            // AI审阅按钮
            Button {
                showAIReview = true
            } label: {
                Label("AI审阅", systemImage: "sparkles")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 生成提示编辑 Sheet

    private var hintEditorSheet: some View {
        NavigationStack {
            Form {
                Section("生成提示（generation_hint）") {
                    TextEditor(text: $workbenchStore.generationHint)
                        .frame(minHeight: 120)
                }

                Section {
                    Text("生成提示将作为下一轮 AI 生成的约束条件，控制章节方向、情节节奏与风格倾向。")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .navigationTitle("生成提示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            if let novelId = novelStore.currentNovel?.id {
                                await workbenchStore.saveGenerationHint(novelId: novelId, chapterNumber: chapter.number)
                            }
                            showHintEditor = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI 审阅 Sheet

    private var aiReviewSheet: some View {
        NavigationStack {
            VStack {
                if let result = workbenchStore.aiReviewResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            // 评分
                            HStack {
                                Text("评分")
                                    .font(Theme.headlineFont())
                                Spacer()
                                Text("\(result.score)/100")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(scoreColor(result.score))
                            }

                            // 状态
                            if !result.status.isEmpty {
                                Label(result.status, systemImage: "checkmark.seal.fill")
                                    .foregroundColor(Theme.success)
                            }

                            // 备注内容
                            if !result.memo.isEmpty {
                                sectionCard(title: "审阅备注") {
                                    Text(result.memo)
                                        .font(Theme.bodyFont())
                                }
                            }

                            // 建议
                            if !result.suggestions.isEmpty {
                                sectionCard(title: "改进建议") {
                                    ForEach(result.suggestions.indices, id: \.self) { index in
                                        Text("• \(result.suggestions[index])")
                                            .font(Theme.bodyFont())
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                } else if workbenchStore.isGenerating {
                    VStack(spacing: Theme.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("AI 正在审阅章节…")
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    Text("点击下方按钮开始 AI 审阅")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxHeight: .infinity)
                }

                // 底部操作
                Button {
                    Task {
                        if let novelId = novelStore.currentNovel?.id {
                            await workbenchStore.aiReview(novelId: novelId, chapterNumber: chapter.number, save: true)
                        }
                    }
                } label: {
                    Label("开始 AI 审阅", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle("AI 审阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showAIReview = false }
                }
            }
        }
    }

    // MARK: - 辅助

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Theme.success }
        if score >= 60 { return Theme.warning }
        return Theme.error
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.headlineFont())
            content()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }
}
