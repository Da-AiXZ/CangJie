//
//  BibleStreamingStep.swift
//  Cangjie
//
//  向导第1步：Bible 流式生成（文风公约 + 世界观5维度）。
//  对齐 Vue3 NovelSetupGuide.vue:26-176 Step 1 的流式生成 + 维度展示。
//  SSE 事件：phase/data(style/style_chunk/worldbuilding_chunk/worldbuilding_field/worldbuilding_dimension)/done/error
//

import SwiftUI

/// Bible 流式生成步骤
struct BibleStreamingStep: View {

    @EnvironmentObject var store: OnboardingStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if store.generatingBible {
                    // 生成中（NovelSetupGuide.vue:33-122）
                    generatingView
                } else if store.bibleGenerated {
                    // 生成完成，可编辑（NovelSetupGuide.vue:125-176）
                    generatedView
                } else {
                    // 初始状态
                    startView
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear {
            if !store.bibleGenerated && !store.generatingBible {
                Task {
                    // 启动 worldbuilding 阶段 SSE（NovelSetupGuide.vue:1480, stage="worldbuilding"）
                    await store.startBibleGeneration(stage: "worldbuilding")
                }
            }
        }
    }

    // MARK: - 初始状态

    private var startView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.primary)

            Text("正在准备生成设定集…")
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)

            ProgressView()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - 生成中（NovelSetupGuide.vue:33-122）

    private var generatingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 生成头部（NovelSetupGuide.vue:34-44）
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.phaseMessage.isEmpty ? "正在生成文风公约与世界观…" : store.phaseMessage)
                        .font(Theme.headlineFont())
                    Text("AI 会先定文风，再逐维度构建您的世界")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 审批提示（Q1/Q2决策）
            if !store.approvalMessage.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundColor(Theme.warning)
                    Text(store.approvalMessage)
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.warning)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.warning.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.medium)
            }

            // 文风公约实时预览（NovelSetupGuide.vue:114-121, SSE 生成中即可见）
            if !store.styleText.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(Theme.success)
                        Text("文风公约")
                            .font(Theme.headlineFont())
                        Text("已生成")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.success.opacity(0.2))
                            .cornerRadius(4)
                    }
                    Text(store.styleText)
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.secondaryBackground)
                .cornerRadius(Theme.CornerRadius.large)
            }

            // 世界观5维度流式卡片（NovelSetupGuide.vue:46-111）
            // Q决策：简化版 UI，不做5维度骨架屏逐字段流式高亮
            VStack(spacing: Theme.Spacing.md) {
                ForEach(WB_DIMS, id: \.self) { dim in
                    worldbuildingDimensionCard(dim)
                }
            }
        }
    }

    /// 世界观维度卡片（NovelSetupGuide.vue:52-110 field-card）
    private func worldbuildingDimensionCard(_ dim: String) -> some View {
        let fields = store.worldbuildingData[dim] ?? [:]
        let isActive = store.activeDimension == dim
        let isCompleted = store.completedDimensions.contains(dim)

        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(worldbuildingDimensionLabel(dim))
                    .font(Theme.headlineFont())

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                        .font(.system(size: 14))
                }

                Spacer()

                if isActive && store.generatingBible {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // 字段列表
            if !fields.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(fields.sorted(by: { $0.key < $1.key }), id: \.key) { field, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                            Text(value)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else if isActive {
                Text("正在生成\(worldbuildingDimensionLabel(dim))…")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(isActive ? Theme.primary.opacity(0.05) : Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(isActive ? Theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - 生成完成（NovelSetupGuide.vue:125-176）

    private var generatedView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // 文风公约（可编辑）
            sectionCard(title: "文风公约", icon: "textformat") {
                TextEditor(text: $store.styleText)
                    .font(Theme.bodyFont())
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }

            // 世界观维度
            ForEach(WB_DIMS, id: \.self) { dim in
                let fields = store.worldbuildingData[dim] ?? [:]
                if !fields.isEmpty {
                    sectionCard(title: worldbuildingDimensionLabel(dim), icon: "globe.asia.australia") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(fields.sorted(by: { $0.key < $1.key }), id: \.key) { field, value in
                                HStack(alignment: .top) {
                                    Text(field)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.textTertiary)
                                        .frame(width: 80, alignment: .leading)
                                    Text(value)
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                    }
                }
            }

            // 重新生成按钮
            Button {
                Task {
                    await store.startBibleGeneration(stage: "worldbuilding")
                }
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - 分区卡片

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.primary)
                Text(title)
                    .font(Theme.headlineFont())
            }

            content()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }
}
