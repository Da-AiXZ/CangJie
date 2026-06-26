//
//  ChapterGenerateModalView.swift
//  Cangjie
//
//  P0-2 AI 生成弹窗，对齐 WorkArea.vue L334-703。
//  8 个功能模块：目标章节选择 / 大纲输入+场记预分析 / 场记分析开关 /
//  LLM 配置档案选择 / 自定义提示词模板 / 上下文预览 / SSE 实时日志 / 重新生成模式。
//

import SwiftUI

/// AI 生成弹窗（对齐 WorkArea.vue L334-703）
struct ChapterGenerateModalView: View {

    /// 当前小说 ID
    let novelId: String

    /// 章节列表
    let chapters: [ChapterDTO]

    /// 当前章节号
    let currentChapterNumber: Int

    @EnvironmentObject var workbenchStore: WorkbenchStore

    /// AI 设置折叠区展开状态
    @State private var aiSettingsExpanded: Bool = false
    @State private var scriptPromptExpanded: Bool = false
    @State private var prosePromptExpanded: Bool = false

    /// 上下文预览三层折叠
    @State private var layer1Expanded: Bool = false
    @State private var layer2Expanded: Bool = false
    @State private var layer3Expanded: Bool = false

    /// 章节搜索文本
    @State private var chapterSearchText: String = ""

    /// 弹窗内错误提示
    @State private var localError: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 提示信息
                infoAlert

                // 模块1-3 + 8：配置区
                configSection

                // 模块4-5：AI 设置折叠区
                aiSettingsSection

                // 模块6：上下文预览
                contextPreviewSection

                // 模块7：SSE 实时日志 + 进度条
                if workbenchStore.generateInProgress || !workbenchStore.generatedContent.isEmpty {
                    generateContentSection
                }
            }
            .padding()
        }
        .navigationTitle(workbenchStore.isRegenerationMode ? "重新生成本章" : "AI 生成本章")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    workbenchStore.showGenerateModal = false
                }
                .disabled(workbenchStore.generateInProgress)
            }
            ToolbarItem(placement: .primaryAction) {
                if workbenchStore.generateInProgress {
                    Button("停止") {
                        workbenchStore.stopGenerate(novelId: novelId)
                    }
                }
            }
        }
    }

    // MARK: - 提示信息

    private var infoAlert: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Theme.info)
                .font(.system(size: 14))
            Text("选择目标章节与大纲后流式生成。一致性报告与俗套句式命中会出现在右侧侧栏；此处可审阅正文并保存到所选章节。")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(10)
        .background(Theme.info.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - 配置区（模块1-3 + 8）

    private var configSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("配置")
                .font(.system(size: 14, weight: .semibold))

            // 模块1：目标章节选择
            VStack(alignment: .leading, spacing: 6) {
                Text("目标章节")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                chapterSelector
            }

            // 模块2：大纲输入 + 场记预分析
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("大纲")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    if workbenchStore.outlineBlurAnalyzing {
                        Text("场景预分析中…")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.info)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.info.opacity(0.15))
                            .cornerRadius(8)
                    } else if workbenchStore.blurSceneCache != nil {
                        Text("已预分析")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.success.opacity(0.15))
                            .cornerRadius(8)
                    }
                }

                TextEditor(text: $workbenchStore.generateOutline)
                    .font(.system(size: 13))
                    .frame(minHeight: 60, maxHeight: 120)
                    .padding(4)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(6)
                    .disabled(workbenchStore.generateInProgress)
                    .onSubmit {
                        Task {
                            await workbenchStore.onOutlineBlurAnalyze(
                                novelId: novelId,
                                chapterNumber: currentChapterNumber
                            )
                        }
                    }
            }

            // 模块3：场记分析开关
            HStack(spacing: 8) {
                Toggle("", isOn: $workbenchStore.useSceneDirector)
                    .labelsHidden()
                    .disabled(workbenchStore.generateInProgress)

                Text("场记分析")
                    .font(.system(size: 12))

                Text("若失焦未预分析，则在点击生成时再分析场景（与预分析二选一即可）")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }

            // 场记分析错误提示
            if !workbenchStore.sceneDirectorError.isEmpty {
                Text("场记分析失败（不影响生成）：\(workbenchStore.sceneDirectorError)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.warning)
                    .padding(8)
                    .background(Theme.warning.opacity(0.1))
                    .cornerRadius(6)
            }

            // 模块8：重新生成模式 — 改进方向输入
            if workbenchStore.isRegenerationMode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("重新生成将覆盖现有正文。点击开始生成前，原内容会自动保存为历史草稿。")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.warning)
                        .padding(8)
                        .background(Theme.warning.opacity(0.1))
                        .cornerRadius(6)

                    Text("改进方向")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    TextEditor(text: $workbenchStore.regenerationGuidance)
                        .font(.system(size: 13))
                        .frame(minHeight: 40, maxHeight: 80)
                        .padding(4)
                        .background(Theme.secondaryBackground)
                        .cornerRadius(6)
                        .disabled(workbenchStore.generateInProgress)
                }
            }

            // 生成按钮
            Button {
                Task {
                    guard let targetChapter = modalTargetChapter else {
                        localError = "请选择目标章节"
                        return
                    }
                    localError = ""
                    await workbenchStore.startGenerate(
                        novelId: novelId,
                        chapterNumber: targetChapter.number,
                        chapterTitle: targetChapter.title
                    )
                }
            } label: {
                HStack {
                    if workbenchStore.savingDraftBeforeRegen {
                        ProgressView().scaleEffect(0.7)
                        Text("快照原内容…")
                    } else if workbenchStore.generateInProgress {
                        if workbenchStore.analyzingScene {
                            ProgressView().scaleEffect(0.7)
                            Text("分析场景中...")
                        } else {
                            ProgressView().scaleEffect(0.7)
                            Text("生成中...")
                        }
                    } else if workbenchStore.isRegenerationMode {
                        Text("开始重新生成")
                    } else {
                        Text("开始生成")
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                workbenchStore.generateInProgress ||
                workbenchStore.savingDraftBeforeRegen ||
                workbenchStore.generateTargetChapterId == nil ||
                workbenchStore.isAssistedReadOnly
            )

            if !localError.isEmpty {
                Text(localError)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.error)
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - 章节选择器（filterable Picker）

    private var chapterSelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 搜索框
            TextField("搜索章节…", text: $chapterSearchText)
                .font(.system(size: 12))
                .textFieldStyle(.roundedBorder)
                .disabled(workbenchStore.generateInProgress)

            // 章节列表
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredChapters) { ch in
                        HStack {
                            Text("第\(ch.number)章")
                                .font(.system(size: 12, weight: .medium))
                            if !ch.title.isEmpty {
                                Text("· \(ch.title)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if workbenchStore.generateTargetChapterId == ch.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            workbenchStore.generateTargetChapterId == ch.id
                                ? Theme.primary.opacity(0.1)
                                : Color.clear
                        )
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !workbenchStore.generateInProgress {
                                workbenchStore.generateTargetChapterId = ch.id
                                workbenchStore.blurSceneCache = nil
                                workbenchStore.contextPreview = nil
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
            .background(Theme.secondaryBackground)
            .cornerRadius(6)
        }
    }

    /// 过滤后的章节列表
    private var filteredChapters: [ChapterDTO] {
        if chapterSearchText.isEmpty {
            return chapters
        }
        return chapters.filter { ch in
            "第\(ch.number)章".contains(chapterSearchText) ||
            ch.title.contains(chapterSearchText)
        }
    }

    /// 弹窗内选中的目标章节
    private var modalTargetChapter: ChapterDTO? {
        guard let id = workbenchStore.generateTargetChapterId else { return nil }
        return chapters.first { $0.id == id }
    }

    // MARK: - AI 设置折叠区（模块4-5）

    private var aiSettingsSection: some View {
        DisclosureGroup(isExpanded: $aiSettingsExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                // 模块4：LLM 配置档案选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("LLM 配置档案")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)

                    HStack {
                        Picker("LLM 配置档案", selection: $workbenchStore.generateProfileId) {
                            Text("使用系统默认激活档案").tag(String?.none)
                            ForEach(workbenchStore.llmProfiles) { profile in
                                Text("\(profile.name) (\(profile.model))").tag(Optional(profile.id))
                            }
                        }
                        .disabled(workbenchStore.generateInProgress || workbenchStore.llmProfilesLoading)

                        if workbenchStore.llmProfilesLoading {
                            ProgressView().scaleEffect(0.6)
                        }

                        if workbenchStore.generateProfileId != nil {
                            Button("清除") {
                                workbenchStore.generateProfileId = nil
                            }
                            .font(.system(size: 10))
                            .disabled(workbenchStore.generateInProgress)
                        }
                    }

                    Text("选择特定模型档案；留空则使用系统默认激活档案")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }

                // 模块5：六模块剧本提示词
                DisclosureGroup(isExpanded: $scriptPromptExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("使用自定义模板", isOn: $workbenchStore.useCustomScriptPrompt)
                            .disabled(workbenchStore.generateInProgress)

                        if workbenchStore.useCustomScriptPrompt {
                            TextEditor(text: $workbenchStore.customScriptTemplate)
                                .font(.system(size: 12))
                                .frame(minHeight: 60, maxHeight: 120)
                                .padding(4)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(6)
                                .disabled(workbenchStore.generateInProgress)

                            Text("变量（对应模板中的 {{变量名}}）")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)

                            promptVarPairsEditor(pairs: $workbenchStore.scriptPromptVarPairs)
                        }
                    }
                } label: {
                    Text("六模块剧本提示词")
                        .font(.system(size: 12, weight: .medium))
                }

                // 模块5：剧本转正文提示词
                DisclosureGroup(isExpanded: $prosePromptExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("使用自定义模板", isOn: $workbenchStore.useCustomProsePrompt)
                            .disabled(workbenchStore.generateInProgress)

                        if workbenchStore.useCustomProsePrompt {
                            TextEditor(text: $workbenchStore.customProseTemplate)
                                .font(.system(size: 12))
                                .frame(minHeight: 60, maxHeight: 120)
                                .padding(4)
                                .background(Theme.secondaryBackground)
                                .cornerRadius(6)
                                .disabled(workbenchStore.generateInProgress)

                            Text("变量（对应模板中的 {{变量名}}）")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)

                            promptVarPairsEditor(pairs: $workbenchStore.prosePromptVarPairs)
                        }
                    }
                } label: {
                    Text("剧本转正文提示词")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Text("AI 设置")
                    .font(.system(size: 13, weight: .semibold))
                Text("模型档案与提示词")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.info)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.info.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// 动态键值对编辑器（对齐 n-dynamic-input preset="pair"）
    @ViewBuilder
    private func promptVarPairsEditor(pairs: Binding<[PromptVarPair]>) -> some View {
        VStack(spacing: 6) {
            ForEach(pairs.wrappedValue.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField("变量名", text: Binding(
                        get: { pairs.wrappedValue[index].key },
                        set: { pairs.wrappedValue[index].key = $0 }
                    ))
                    .font(.system(size: 11))
                    .textFieldStyle(.roundedBorder)

                    TextField("值", text: Binding(
                        get: { pairs.wrappedValue[index].value },
                        set: { pairs.wrappedValue[index].value = $0 }
                    ))
                    .font(.system(size: 11))
                    .textFieldStyle(.roundedBorder)

                    Button {
                        pairs.wrappedValue.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(Theme.error)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                pairs.wrappedValue.append(PromptVarPair())
            } label: {
                Label("添加变量", systemImage: "plus.circle.fill")
                    .font(.system(size: 11))
            }
        }
    }

    // MARK: - 上下文预览（模块6）

    private var contextPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text("上下文预览")
                        .font(.system(size: 13, weight: .semibold))
                    Text("AI 实际接收到的三层信息")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                Button {
                    Task {
                        guard let ch = modalTargetChapter else { return }
                        await workbenchStore.retrieveContext(
                            novelId: novelId,
                            chapterNumber: ch.number,
                            outline: workbenchStore.generateOutline.isEmpty
                                ? "第\(ch.number)章：承接前情，推进主线"
                                : workbenchStore.generateOutline,
                            sceneDirectorResult: workbenchStore.blurSceneCache
                        )
                    }
                } label: {
                    HStack {
                        if workbenchStore.loadingContext {
                            ProgressView().scaleEffect(0.6)
                        }
                        Text(workbenchStore.contextPreview != nil ? "重新获取" : "预览")
                            .font(.system(size: 11))
                    }
                }
                .disabled(workbenchStore.loadingContext)
            }

            if let preview = workbenchStore.contextPreview, modalTargetChapter != nil {
                // Token 分布 Tag
                HStack(spacing: 6) {
                    tokenTag(text: "L1 核心 \(preview.tokenUsage.layer1) tok", color: Theme.info)
                    tokenTag(text: "L2 检索 \(preview.tokenUsage.layer2) tok", color: Theme.success)
                    tokenTag(text: "L3 近期 \(preview.tokenUsage.layer3) tok", color: Theme.warning)
                    tokenTag(
                        text: "合计 \(preview.tokenUsage.total) / \(preview.tokenUsage.limit)",
                        color: Theme.textSecondary
                    )
                }

                // 进度条
                if preview.tokenUsage.limit > 0 {
                    ProgressView(
                        value: min(1.0, Double(preview.tokenUsage.total) / Double(preview.tokenUsage.limit))
                    )
                    .tint(preview.tokenUsage.usageRatio > 0.9 ? Theme.warning : Theme.success)
                }

                // 三层可折叠内容
                DisclosureGroup(isExpanded: $layer1Expanded) {
                    Text(preview.layer1.content.isEmpty ? "（无内容）" : preview.layer1.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Layer 1 · 核心设定（Bible + 伏笔）")
                        .font(.system(size: 11, weight: .medium))
                }

                DisclosureGroup(isExpanded: $layer2Expanded) {
                    Text(preview.layer2.content.isEmpty ? "（向量检索未启用或无匹配）" : preview.layer2.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Layer 2 · 智能检索（向量相关段落）")
                        .font(.system(size: 11, weight: .medium))
                }

                DisclosureGroup(isExpanded: $layer3Expanded) {
                    Text(preview.layer3.content.isEmpty ? "（无内容）" : preview.layer3.content)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text("Layer 3 · 近期章节（滑动窗口）")
                        .font(.system(size: 11, weight: .medium))
                }
            } else {
                Text("点击预览查看 AI 生成时实际使用的上下文内容及 token 分布。")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// Token 分布 Tag
    private func tokenTag(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(8)
    }

    // MARK: - 生成内容区 + SSE 日志（模块7）

    private var generateContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("生成内容")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                if !workbenchStore.generatedContent.isEmpty && !workbenchStore.generateInProgress {
                    Button("保存到所选章节") {
                        Task {
                            guard let ch = modalTargetChapter else { return }
                            await workbenchStore.saveGeneratedToChapter(
                                novelId: novelId,
                                chapterNumber: ch.number
                            )
                        }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderedProminent)

                    Button("清空") {
                        workbenchStore.clearGeneratedDraft()
                    }
                    .font(.system(size: 11))
                    .disabled(workbenchStore.generateInProgress)
                }
            }

            // 进度条 + 阶段标签 + 统计
            if workbenchStore.generateInProgress {
                VStack(spacing: 4) {
                    ProgressView(value: Double(workbenchStore.streamProgressPct), total: 100)
                        .tint(Theme.primary)

                    HStack {
                        Text(workbenchStore.streamPhaseLabel.isEmpty ? "准备中…" : workbenchStore.streamPhaseLabel)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)

                        Spacer()

                        Text("\(workbenchStore.streamStats.chars) 字 · ~\(workbenchStore.streamStats.estimatedTokens) tokens")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            // SSE 实时日志
            if workbenchStore.generateInProgress {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("实时日志 · SSE")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("\(workbenchStore.generateSseLog.count) 条")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }

                    // 事件流滚动列表
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(workbenchStore.generateSseLog) { line in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(line.tag)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(sseTagColor(line.tagColor))
                                        .cornerRadius(4)

                                    Text(line.msg)
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }

                            if workbenchStore.generateSseLog.isEmpty {
                                Text("等待 SSE…")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(6)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(6)
                }
            }

            // 生成内容编辑器
            TextEditor(text: $workbenchStore.generatedContent)
                .font(.system(size: 13))
                .frame(minHeight: 120, maxHeight: 300)
                .padding(4)
                .background(Theme.secondaryBackground)
                .cornerRadius(6)
                .disabled(workbenchStore.generateInProgress)
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }

    /// SSE tag 颜色映射
    private func sseTagColor(_ colorType: String) -> Color {
        switch colorType {
        case "info": return Theme.info
        case "success": return Theme.success
        case "warning": return Theme.warning
        case "error": return Theme.error
        default: return Theme.info
        }
    }
}
