//
//  LocationSetupStep.swift
//  Cangjie
//
//  向导第3步：地点 SSE 流式生成。
//  对齐 Vue3 NovelSetupGuide.vue:427-520 Step 3 的地点流式生成 + 可编辑列表。
//  SSE 事件：data(location/location_chunk)/phase/done/error
//

import SwiftUI

/// 地点创建步骤（SSE 流式生成）
struct LocationSetupStep: View {

    @EnvironmentObject var store: OnboardingStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if store.generatingLocations {
                    // 生成中：流式地点卡片
                    generatingView
                } else if store.locationsGenerated {
                    // 生成完成：可编辑地点列表
                    generatedView
                } else {
                    // 初始状态：启动生成
                    startView
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear {
            if !store.locationsGenerated && !store.generatingLocations {
                Task {
                    // 启动 locations 阶段 SSE（NovelSetupGuide.vue:1627, stage="locations"）
                    await store.startBibleGeneration(stage: "locations")
                }
            }
        }
    }

    // MARK: - 初始状态

    private var startView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("正在准备生成地点…")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)

            ProgressView()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - 生成中（NovelSetupGuide.vue:427-520 流式地点卡片）

    private var generatingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 生成头部
            HStack(spacing: Theme.Spacing.md) {
                ProgressView()
                Text(store.phaseMessage.isEmpty ? "AI 正在构思地点..." : store.phaseMessage)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 审批提示
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

            // 流式地点卡片列表
            if !store.streamingLocations.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(store.streamingLocations) { loc in
                        streamingLocationCard(loc)
                    }
                }
            }
        }
    }

    /// 流式地点卡片
    private func streamingLocationCard(_ loc: GeneratedLocation) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(Theme.primary)

                Text(loc.name.isEmpty ? "未命名地点" : loc.name)
                    .font(Theme.headlineFont())

                if !loc.locationType.isEmpty {
                    Text("[\(loc.locationType)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            if !loc.description.isEmpty {
                Text(loc.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.primary.opacity(0.05))
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 生成完成

    private var generatedView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 可编辑地点列表
            if !store.editableLocations.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(store.editableLocations) { loc in
                        editableLocationCard(loc)
                    }
                }
            } else if let bible = store.bible, !bible.locations.isEmpty {
                // 从 Bible 加载的地点
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(bible.locations) { location in
                        bibleLocationCard(location)
                    }
                }
            } else {
                // 空状态
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.textTertiary)

                    Text("暂无地点")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.xl)
            }

            // 重新生成按钮
            Button {
                Task {
                    await store.startBibleGeneration(stage: "locations")
                }
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    /// 可编辑地点卡片
    private func editableLocationCard(_ loc: GeneratedLocation) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(Theme.primary)

                Text(loc.name)
                    .font(Theme.headlineFont())

                if !loc.locationType.isEmpty {
                    Text("[\(loc.locationType)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            if !loc.description.isEmpty {
                Text(loc.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    /// Bible 地点卡片
    private func bibleLocationCard(_ location: LocationDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(Theme.primary)

                Text(location.name)
                    .font(Theme.headlineFont())

                if !location.locationType.isEmpty {
                    Text("[\(location.locationType)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            if !location.description.isEmpty {
                Text(location.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }
}
