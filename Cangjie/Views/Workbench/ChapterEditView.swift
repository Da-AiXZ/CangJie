//
//  ChapterEditView.swift
//  Cangjie
//
//  P0-3 独立章节编辑页，对齐原版 views/Chapter.vue（648 行完整移植）。
//
//  技术约定：
//  - NavigationStack push 呈现（禁用 NavigationSplitView）
//  - HStack 布局：左编辑区(72%) + 右侧栏(28%)
//  - Markdown 预览用 AttributedString(markdown:options:)（系统方案，Q5 决策）
//  - iOS 16+ 兼容
//  - 中文 UI 文案强调词用中文引号 \u{201C}\u{201D}（Lesson 15）
//

import SwiftUI

/// 独立章节编辑页，对齐原版 views/Chapter.vue
///
/// 布局：HStack 左编辑区(72%) + 右侧栏(28%)，禁用 NavigationSplitView
struct ChapterEditView: View {

    /// 小说 ID
    let novelId: String

    /// 初始章节编号
    let initialChapterNumber: Int

    /// 状态管理
    @StateObject private var store: ChapterEditStore

    /// dismiss 环境
    @Environment(\.dismiss) private var dismiss

    /// 选中的 Tab
    @State private var selectedTab: ChapterEditTab = .review

    /// 是否显示清空确认弹窗
    @State private var showClearConfirm = false

    /// 是否显示撤销全部确认弹窗
    @State private var showRevokeAllConfirm = false

    /// 是否显示撤销单条确认弹窗
    @State private var revokingTripleId: String?

    /// 导航目标章节编号（用于切换章节）
    @State private var pendingChapterSwitch: Int?

    // MARK: - 初始化

    init(novelId: String, chapterNumber: Int) {
        self.novelId = novelId
        self.initialChapterNumber = chapterNumber
        _store = StateObject(wrappedValue: ChapterEditStore(novelId: novelId, chapterNumber: chapterNumber))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            if store.pageLoading {
                loadingView
            } else {
                mainContent(geometry: geometry)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .task {
            if store.chapterContent.isEmpty {
                await store.loadChapter()
            }
        }
        .onDisappear {
            store.cancelDebounceTasks()
        }
        .alert("清空正文", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                store.clearContent()
            }
        } message: {
            Text("确定要清空全部正文内容吗？此操作不可撤销。")
        }
        .alert("撤销本章全部推断", isPresented: $showRevokeAllConfirm) {
            Button("取消", role: .cancel) {}
            Button("撤销", role: .destructive) {
                Task { await store.revokeAllInference() }
            }
        } message: {
            Text("将删除本章节点下的溯源；无剩余证据的推断三元组会被移除。确定？")
        }
        .alert("撤销此条推断", isPresented: Binding(
            get: { revokingTripleId != nil },
            set: { if !$0 { revokingTripleId = nil } }
        )) {
            Button("取消", role: .cancel) {
                revokingTripleId = nil
            }
            Button("撤销", role: .destructive) {
                if let tripleId = revokingTripleId {
                    Task { await store.revokeOneInference(tripleId: tripleId) }
                }
                revokingTripleId = nil
            }
        } message: {
            Text("将删除该 chapter_inferred 三元组及其溯源，确定？")
        }
        .alert("错误", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("确定") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载章节…")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 主内容

    private func mainContent(geometry: GeometryProxy) -> some View {
        let totalWidth = geometry.size.width
        let leftWidth = totalWidth * 0.72
        let rightWidth = totalWidth * 0.28

        return HStack(spacing: 0) {
            // 左侧编辑区（72%）
            editorArea
                .frame(width: leftWidth)

            Divider()

            // 右侧侧栏（28%）
            sidebarArea
                .frame(width: rightWidth)
        }
        .background(Theme.background)
    }

    // MARK: - 顶部工具栏

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "chevron.left")
                    Text("工作台")
                }
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: Theme.Spacing.sm) {
                // 章节标题
                Text("第 \(store.chapterNumber) 章")
                    .font(Theme.headlineFont())

                // 保存状态标签，对齐 Chapter.vue L14-16
                saveStatusTag
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            // 上一章/下一章按钮组，对齐 Chapter.vue L20-33
            prevNextButtonGroup

            // 工具下拉，对齐 Chapter.vue L35-37
            toolsMenu

            // 保存按钮，对齐 Chapter.vue L41-43
            Button {
                Task { await store.saveContent() }
            } label: {
                if store.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("保存")
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!store.contentDirty || store.isSaving)
        }
    }

    /// 保存状态标签
    private var saveStatusTag: some View {
        let color: Color
        switch store.saveStatus {
        case .saved: color = Theme.success
        case .saving: color = Theme.warning
        case .unsaved: color = Theme.textSecondary
        }

        return Text(store.saveStatus.displayText)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    /// 上一章/下一章按钮组
    private var prevNextButtonGroup: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Button {
                if let prevNum = store.prevChapterNumber() {
                    pendingChapterSwitch = prevNum
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9))
                    Text("上一章")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!store.canPrev)

            Button {
                if let nextNum = store.nextChapterNumber() {
                    pendingChapterSwitch = nextNum
                }
            } label: {
                HStack(spacing: 2) {
                    Text("下一章")
                        .font(.system(size: 12))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!store.canNext)
        }
        .onChange(of: pendingChapterSwitch) { newChapter in
            if let newChapter = newChapter {
                Task {
                    await store.switchToChapter(newChapter)
                }
                pendingChapterSwitch = nil
            }
        }
    }

    /// 工具下拉菜单，对齐 Chapter.vue L35-37
    private var toolsMenu: some View {
        Menu {
            Button {
                store.copyAllText()
            } label: {
                Label("复制全文", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("清空正文", systemImage: "trash")
            }
        } label: {
            Text("工具")
                .font(.system(size: 12))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - 左侧编辑区

    /// 编辑区，对齐 Chapter.vue L48-77
    private var editorArea: some View {
        VStack(spacing: 0) {
            // 正文编辑器或预览面板
            if store.showPreview {
                previewPanel
            } else {
                TextEditor(text: $store.chapterContent)
                    .font(Theme.editorFont(scale: Theme.ipadScale))
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                    .onChange(of: store.chapterContent) { _ in
                        store.onContentInput()
                    }
            }

            // 底部状态栏，对齐 Chapter.vue L58-68
            editorFooter
        }
        .background(Theme.background)
    }

    /// 底部状态栏，对齐 Chapter.vue L58-68
    private var editorFooter: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 字数
            Text("\(store.wordCount) 字")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            Divider()
                .frame(height: 12)

            // 行数
            Text("\(store.lineCount) 行")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            if !store.lastSaveTime.isEmpty {
                Divider()
                    .frame(height: 12)

                // 上次保存时间，对齐 Chapter.vue L64
                Text("上次保存 \(store.lastSaveTime)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // Markdown 预览切换按钮，对齐 Chapter.vue L66-68
            Button {
                store.showPreview.toggle()
                if store.showPreview {
                    store.updatePreview(immediate: true)
                }
            } label: {
                Text(store.showPreview ? "隐藏预览" : "Markdown 预览")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    /// 预览面板，对齐 Chapter.vue L71-76
    private var previewPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let attributed = store.previewAttributed {
                    Text(attributed)
                        .font(Theme.bodyFont())
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("（空内容）")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.secondaryBackground)
    }

    // MARK: - 右侧侧栏

    /// 侧栏区域，对齐 Chapter.vue L80-208
    private var sidebarArea: some View {
        VStack(spacing: 0) {
            // TabView segmented style，对齐 Chapter.vue L82
            Picker("", selection: $selectedTab) {
                Text("审定").tag(ChapterEditTab.review)
                Text("推断证据").tag(ChapterEditTab.inference)
                Text("信息").tag(ChapterEditTab.info)
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.sm)

            // Tab 内容
            ScrollView {
                switch selectedTab {
                case .review:
                    reviewTab
                        .padding(Theme.Spacing.sm)
                case .inference:
                    inferenceTab
                        .padding(Theme.Spacing.sm)
                case .info:
                    infoTab
                        .padding(Theme.Spacing.sm)
                }
            }
        }
        .background(Theme.tertiaryBackground)
    }

    // MARK: - 审定 Tab

    /// 审定 Tab，对齐 Chapter.vue L83-110
    private var reviewTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // 状态单选组，对齐 Chapter.vue L85-93
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("状态")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)

                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(ChapterReviewStatus.allCases, id: \.self) { status in
                        Button {
                            store.reviewStatus = status
                        } label: {
                            HStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: store.reviewStatus == status
                                      ? "largecircle.fill.circle"
                                      : "circle")
                                    .font(.system(size: 14))
                                Text(status.displayText)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(store.reviewStatus == status
                                            ? Theme.primary
                                            : Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // 批注文本域，对齐 Chapter.vue L94-96
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("批注")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)

                TextEditor(text: $store.reviewMemo)
                    .font(Theme.bodyFont())
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(Theme.Spacing.xs)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(Theme.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .stroke(Theme.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }

            // 操作按钮组，对齐 Chapter.vue L97-108
            VStack(spacing: Theme.Spacing.xs) {
                // 生成审读意见，对齐 Chapter.vue L98-99
                Button {
                    Task { await store.runAiReview(save: false) }
                } label: {
                    HStack {
                        if store.isAiReviewing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("生成审读意见")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isAiReviewing)

                // 生成并写入审定，对齐 Chapter.vue L100-103
                Button {
                    Task { await store.runAiReview(save: true) }
                } label: {
                    HStack {
                        if store.isAiReviewing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("生成并写入审定")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.info)
                .disabled(store.isAiReviewing)

                // 说明文字，对齐 Chapter.vue L104-106
                Text("基于合并正文（含 chapters/NNN 下分场景 parts）与大纲一句纲；\u{201C}生成意见\u{201D}仅填入上方表单项。")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 保存审定按钮，对齐 Chapter.vue L108
            Button {
                Task { await store.saveReview() }
            } label: {
                HStack {
                    if store.isSavingReview {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Text("保存审定")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isSavingReview)
        }
    }

    // MARK: - 推断证据 Tab

    /// 推断证据 Tab，对齐 Chapter.vue L112-188
    private var inferenceTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // 提示 Alert，对齐 Chapter.vue L118-120
            if !store.inferenceHint.isEmpty {
                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.info)
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.inferenceHintTitle)
                            .font(.system(size: 12, weight: .semibold))
                        Text(store.inferenceHint)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(Theme.Spacing.xs)
                .background(Theme.info.opacity(0.08))
                .cornerRadius(Theme.CornerRadius.small)
            }

            // 操作行，对齐 Chapter.vue L121-149
            HStack {
                Text("来自章节元素自动推断的 ")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                +
                Text("chapter_inferred")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                +
                Text(" 三元组及证据链")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                // 刷新按钮，对齐 Chapter.vue L126-134
                Button {
                    Task { await store.loadInferenceEvidence() }
                } label: {
                    HStack(spacing: 2) {
                        if store.inferenceLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                        }
                        Text("刷新")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(store.inferenceLoading)

                // 撤销本章全部推断，对齐 Chapter.vue L135-148
                Button(role: .destructive) {
                    showRevokeAllConfirm = true
                } label: {
                    Text("撤销本章全部推断")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(store.storyNodeId == nil || store.isRevokingAll)
            }

            // 空状态，对齐 Chapter.vue L151
            if !store.inferenceLoading && store.inferenceFacts.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.textTertiary)
                    Text("暂无本章推断记录")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)
            }

            // 推断列表，对齐 Chapter.vue L152-185
            ForEach(store.inferenceFacts) { item in
                inferenceFactCard(item)
            }
        }
    }

    /// 单条推断事实卡片，对齐 Chapter.vue L153-184
    private func inferenceFactCard(_ item: InferenceFactBundle) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // 三元组标题，对齐 Chapter.vue L156
            Text("\(item.fact.subject) —\(item.fact.predicate)→ \(item.fact.object)")
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)

            // 描述信息，对齐 Chapter.vue L160-165
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                // ID
                infoRow(label: "ID", value: item.fact.id)

                // 置信度
                infoRow(
                    label: "置信度",
                    value: item.fact.confidence != nil
                           ? String(format: "%.2f", item.fact.confidence!)
                           : "—"
                )
            }

            // 证据链，对齐 Chapter.vue L166-173
            if !item.provenance.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("证据链（rule / 元素行 / role）")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)

                    ForEach(item.provenance) { p in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)

                            Text(p.ruleId)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)

                            if let elementId = p.chapterElementId {
                                Text("· 元素 \(elementId)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }

                            Text("· \(p.role)")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }

            // 撤销此条推断按钮，对齐 Chapter.vue L174-182
            Button {
                revokingTripleId = item.fact.id
            } label: {
                HStack(spacing: 4) {
                    if store.revokingId == item.fact.id {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text("撤销此条推断")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Theme.warning)
            .disabled(store.revokingId == item.fact.id)
        }
        .padding(Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.small)
    }

    // MARK: - 信息 Tab

    /// 信息 Tab，对齐 Chapter.vue L190-207
    private var infoTab: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // 统计卡片，对齐 Chapter.vue L192-194
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                statCard(label: "字数", value: "\(store.wordCount)")
                statCard(label: "行数", value: "\(store.lineCount)")
                statCard(label: "段落", value: "\(store.paragraphCount)")
            }

            Divider()

            // 章节结构分析，对齐 Chapter.vue L196-202
            if let structure = store.chapterStructure {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("章节结构分析")
                        .font(Theme.headlineFont())
                        .foregroundColor(Theme.textSecondary)

                    statCard(label: "分析字数", value: "\(structure.wordCount)")
                    statCard(label: "分析段落", value: "\(structure.paragraphCount)")
                    statCard(label: "对话占比", value: String(format: "%.1f%%", structure.dialogueRatio * 100))
                    statCard(label: "场景数", value: "\(structure.sceneCount)")

                    // 节奏，对齐 Chapter.vue L201
                    HStack {
                        Text("节奏")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(structure.pacing)
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }

            Divider()

            // 创建/修改时间，对齐 Chapter.vue L204-205
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("创建")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(store.createTime)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                HStack {
                    Text("修改")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(store.updateTime)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - 辅助视图

    /// 信息行
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
        }
    }

    /// 统计卡片
    private func statCard(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

// MARK: - Tab 枚举

/// 章节编辑页 Tab 类型
enum ChapterEditTab: String, CaseIterable, Hashable {
    case review = "审定"
    case inference = "推断证据"
    case info = "信息"
}
