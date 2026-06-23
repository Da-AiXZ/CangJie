//
//  CharacterPsychePanel.swift
//  Cangjie
//
//  角色心理面板：核心信念/禁忌/声线/创伤/防御机制/演化时间线。
//  可展开详情，调 BibleStore/CastStore。
//

import SwiftUI

/// 角色心理面板
struct CharacterPsychePanel: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var snapshotStore = SnapshotStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if snapshotStore.characterPsyches.isEmpty {
                    emptyState
                } else {
                    ForEach(snapshotStore.characterPsyches) { psyche in
                        psycheCard(psyche)
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background)
        .task {
            if let novelId = appState.currentNovelId {
                await snapshotStore.loadCharacterPsyches(novelId: novelId)
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)
            Text("暂无角色心理数据")
                .font(Theme.bodyFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    // MARK: - 心理卡片

    private func psycheCard(_ psyche: CharacterPsyche) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // 名字
            HStack {
                Text(psyche.name)
                    .font(Theme.headlineFont())
                if !psyche.role.isEmpty {
                    Text(psyche.role)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.info.opacity(0.2))
                        .cornerRadius(4)
                }
                Spacer()
                if psyche.traumaCount > 0 {
                    Label("\(psyche.traumaCount)", systemImage: "bolt.heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.error)
                }
            }

            // 核心信念
            if !psyche.coreBelief.isEmpty {
                detailRow(label: "核心信念", value: psyche.coreBelief, icon: "lightbulb.fill")
            }

            // 禁忌
            if !psyche.taboo.isEmpty {
                detailRow(label: "禁忌", value: psyche.taboo, icon: "hand.raised.fill", color: Theme.error)
            }

            // 声线标签
            if !psyche.voiceTag.isEmpty {
                detailRow(label: "声线", value: psyche.voiceTag, icon: "waveform")
            }

            // 创伤
            if !psyche.wound.isEmpty {
                detailRow(label: "创伤", value: psyche.wound, icon: "heart.text.square.fill", color: Theme.warning)
            }
        }
        .cardStyle()
    }

    // MARK: - 详情行

    private func detailRow(label: String, value: String, icon: String, color: Color = Theme.textPrimary) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
