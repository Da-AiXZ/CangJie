//
//  BibleStreamingStep.swift
//  Cangjie
//
//  向导第1步：Bible 流式生成。
//  SSE 逐 token 打字效果渲染（世界观/题材/时间线/文风），生成完成后可编辑调整。
//  对齐 Vue3 NovelSetupGuide.vue Step 1 的流式生成 + 骨架屏 + 维度逐项展示。
//

import SwiftUI

/// Bible 流式生成步骤
struct BibleStreamingStep: View {

    @EnvironmentObject var store: OnboardingStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if store.isProcessing {
                    // 生成中
                    generatingView
                } else if let bible = store.bible {
                    // 生成完成，可编辑
                    generatedView(bible)
                } else {
                    // 初始状态
                    startView
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear {
            if store.bible == nil && !store.isProcessing {
                Task {
                    await store.startBibleGeneration()
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

    // MARK: - 生成中

    private var generatingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 生成头部
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("正在生成文风公约与世界观…")
                        .font(Theme.headlineFont())
                    Text("AI 会先定文风，再逐维度构建您的世界")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 生成日志（逐 token 流式渲染）
            if !store.bibleGenerationLog.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(store.bibleGenerationLog.indices, id: \.self) { index in
                        let isLast = index == store.bibleGenerationLog.count - 1
                        (Text(store.bibleGenerationLog[index])
                            .font(Theme.bodyFont())
                            .foregroundColor(isLast ? Theme.textPrimary : Theme.textSecondary)
                            + (isLast ? Text("▎").foregroundColor(Theme.primary) : Text("")))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 骨架屏
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.textTertiary.opacity(0.2))
                            .frame(height: 16)
                            .shimmer()
                    }
                }
            }
        }
    }

    // MARK: - 生成完成

    private func generatedView(_ bible: BibleDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // 文风
            if !bible.style.isEmpty {
                sectionCard(title: "文风", icon: "textformat") {
                    Text(bible.style)
                        .font(Theme.bodyFont())
                }
            }

            // 角色
            if !bible.characters.isEmpty {
                sectionCard(title: "角色 (\(bible.characters.count))", icon: "person.2.fill") {
                    ForEach(bible.characters) { character in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(character.name)
                                .font(Theme.headlineFont())
                            if !character.description.isEmpty {
                                Text(character.description)
                                    .font(Theme.captionFont())
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        Divider()
                    }
                }
            }

            // 地点
            if !bible.locations.isEmpty {
                sectionCard(title: "地点 (\(bible.locations.count))", icon: "mappin.and.ellipse") {
                    ForEach(bible.locations) { location in
                        HStack {
                            Image(systemName: "mappin")
                                .foregroundColor(Theme.primary)
                            Text(location.name)
                                .font(Theme.bodyFont())
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // 世界设定
            if !bible.worldSettings.isEmpty {
                sectionCard(title: "世界设定 (\(bible.worldSettings.count))", icon: "globe.asia.australia.fill") {
                    ForEach(bible.worldSettings) { setting in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(setting.name)
                                .font(Theme.bodyFont())
                            if !setting.description.isEmpty {
                                Text(setting.description)
                                    .font(Theme.captionFont())
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
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
