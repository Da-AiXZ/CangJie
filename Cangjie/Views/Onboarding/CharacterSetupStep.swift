//
//  CharacterSetupStep.swift
//  Cangjie
//
//  向导第2步：角色 SSE 流式生成。
//  对齐 Vue3 NovelSetupGuide.vue:178-425 Step 2 的人物流式生成 + 可编辑列表。
//  SSE 事件：data(character/character_chunk)/phase/done/error
//

import SwiftUI

/// 角色创建步骤（SSE 流式生成）
struct CharacterSetupStep: View {

    @EnvironmentObject var store: OnboardingStore

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if store.generatingCharacters {
                    // 生成中：流式角色卡片（NovelSetupGuide.vue:201）
                    generatingView
                } else if store.charactersGenerated {
                    // 生成完成：可编辑角色列表（NovelSetupGuide.vue:178-425）
                    generatedView
                } else {
                    // 初始状态：启动生成
                    startView
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear {
            if !store.charactersGenerated && !store.generatingCharacters {
                Task {
                    // 启动 characters 阶段 SSE（NovelSetupGuide.vue:1567, stage="characters"）
                    await store.startBibleGeneration(stage: "characters")
                }
            }
        }
    }

    // MARK: - 初始状态

    private var startView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 48))
                .foregroundColor(Theme.textTertiary)

            Text("正在准备生成角色…")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)

            ProgressView()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - 生成中（NovelSetupGuide.vue:201 流式角色卡片）

    private var generatingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 生成头部
            HStack(spacing: Theme.Spacing.md) {
                ProgressView()
                Text(store.phaseMessage.isEmpty ? "AI 正在构思角色..." : store.phaseMessage)
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

            // 流式角色卡片列表（NovelSetupGuide.vue:201 v-for="char in streamingCharacters"）
            if !store.streamingCharacters.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(store.streamingCharacters) { char in
                        streamingCharacterCard(char)
                    }
                }
            }
        }
    }

    /// 流式角色卡片（NovelSetupGuide.vue:201-215 char-card--filled）
    private func streamingCharacterCard(_ char: EditableCharacter) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(char.name.isEmpty ? "未命名角色" : char.name)
                    .font(Theme.headlineFont())

                if !char.role.isEmpty {
                    Text("[\(char.role)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()
            }

            if !char.description.isEmpty {
                Text(char.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }

            if !char.gender.isEmpty || !char.age.isEmpty {
                Text("[\(char.gender) \(char.age)]")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textSecondary)
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

    // MARK: - 生成完成（NovelSetupGuide.vue:178-425 可编辑列表）

    private var generatedView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 可编辑角色列表
            if !store.editableCharacters.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(store.editableCharacters.indices, id: \.self) { index in
                        editableCharacterCard(index: index)
                    }
                }
            } else if let bible = store.bible, !bible.characters.isEmpty {
                // 从 Bible 加载的角色
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(bible.characters) { character in
                        bibleCharacterCard(character)
                    }
                }
            } else {
                // 空状态
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.textTertiary)

                    Text("暂无角色")
                        .font(Theme.bodyFont())
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.vertical, Theme.Spacing.xl)
            }

            // 重新生成按钮
            Button {
                Task {
                    await store.startBibleGeneration(stage: "characters")
                }
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    /// 可编辑角色卡片
    private func editableCharacterCard(index: Int) -> some View {
        let char = store.editableCharacters[index]

        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(char.name)
                    .font(Theme.headlineFont())

                if !char.role.isEmpty {
                    Text("[\(char.role)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                if !char.gender.isEmpty || !char.age.isEmpty {
                    Text("[\(char.gender) \(char.age)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let revealChapter = char.revealChapter {
                    Text("POV 第\(revealChapter)章揭示")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !char.description.isEmpty {
                Text(char.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }

            // 详细字段
            VStack(alignment: .leading, spacing: 4) {
                if !char.personality.isEmpty {
                    detailRow(label: "性格", value: char.personality)
                }
                if !char.coreMotivation.isEmpty {
                    detailRow(label: "核心动机", value: char.coreMotivation)
                }
                if !char.coreBelief.isEmpty {
                    detailRow(label: "核心信念", value: char.coreBelief)
                }
                if !char.verbalTic.isEmpty {
                    detailRow(label: "声线", value: char.verbalTic)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    /// Bible 角色卡片
    private func bibleCharacterCard(_ character: CharacterDTO) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(character.name)
                    .font(Theme.headlineFont())

                if !character.gender.isEmpty || !character.age.isEmpty {
                    Text("[\(character.gender) \(character.age)]")
                        .font(Theme.captionFont())
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let revealChapter = character.revealChapter {
                    Text("POV 第\(revealChapter)章揭示")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if !character.description.isEmpty {
                Text(character.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 4) {
                if !character.personality.isEmpty {
                    detailRow(label: "性格", value: character.personality)
                }
                if !character.coreMotivation.isEmpty {
                    detailRow(label: "核心动机", value: character.coreMotivation)
                }
                if !character.coreBelief.isEmpty {
                    detailRow(label: "核心信念", value: character.coreBelief)
                }
                if !character.verbalTic.isEmpty {
                    detailRow(label: "声线", value: character.verbalTic)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    // MARK: - 详情行

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
