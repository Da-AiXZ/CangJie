//
//  CharacterProfileCard.swift
//  Cangjie
//
//  角色档案卡片：名字/角色定位/核心信念/禁忌/声线/POV防火墙/心理状态/演化时间线展开。
//  对齐 Vue3 角色档案组件的详细字段展示。
//

import SwiftUI

/// 角色档案卡片
struct CharacterProfileCard: View {

    let character: CharacterDTO

    /// 是否展开详细字段
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // 头部：名字 + 状态标签
            headerRow

            // 简介
            if !character.description.isEmpty {
                Text(character.description)
                    .font(Theme.bodyFont())
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(isExpanded ? nil : 3)
            }

            // 基本字段
            VStack(alignment: .leading, spacing: 6) {
                if !character.personality.isEmpty {
                    detailRow(label: "性格", value: character.personality)
                }
                if !character.coreMotivation.isEmpty {
                    detailRow(label: "核心动机", value: character.coreMotivation)
                }
                if !character.innerLack.isEmpty {
                    detailRow(label: "内在缺失", value: character.innerLack)
                }
            }

            // 展开后的详细字段
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    if !character.background.isEmpty {
                        detailRow(label: "背景", value: character.background)
                    }
                    if !character.appearance.isEmpty {
                        detailRow(label: "外貌", value: character.appearance)
                    }
                    if !character.coreBelief.isEmpty {
                        detailRow(label: "核心信念", value: character.coreBelief)
                    }
                    if !character.verbalTic.isEmpty {
                        detailRow(label: "声线", value: character.verbalTic)
                    }
                    if !character.idleBehavior.isEmpty {
                        detailRow(label: "空闲行为", value: character.idleBehavior)
                    }
                    if !character.moralTaboos.isEmpty {
                        detailRow(label: "禁忌", value: character.moralTaboos.joined(separator: "、"))
                    }
                }

                // POV 防火墙
                if !character.hiddenProfile.isEmpty || character.revealChapter != nil {
                    Divider()
                    povFirewallSection
                }

                // 心理状态
                if character.mentalState != "NORMAL" || !character.mentalStateReason.isEmpty {
                    Divider()
                    mentalStateSection
                }
            }

            // 展开/收起按钮
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                    Text(isExpanded ? "收起" : "展开详情")
                        .font(.system(size: 12))
                }
                .foregroundColor(Theme.primary)
            }
        }
        .cardStyle()
    }

    // MARK: - 头部行

    private var headerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 性别图标
            Image(systemName: character.gender == "男" ? "person.fill" : "person.fill.turn.left")
                .font(.system(size: 16))
                .foregroundColor(Theme.primary)

            // 名字
            Text(character.name)
                .font(Theme.headlineFont())

            // 年龄
            if !character.age.isEmpty {
                Text("\(character.age)岁")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            // POV 防火墙标签
            if character.revealChapter != nil {
                Label("POV", systemImage: "eye.slash.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.warning)
                    .cornerRadius(3)
            }
        }
    }

    // MARK: - POV 防火墙

    private var povFirewallSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("POV 防火墙", systemImage: "shield.lefthalf.filled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.warning)

            if !character.publicProfile.isEmpty {
                detailRow(label: "公开信息", value: character.publicProfile)
            }
            if !character.hiddenProfile.isEmpty {
                detailRow(label: "隐藏信息", value: character.hiddenProfile)
            }
            if let revealChapter = character.revealChapter {
                detailRow(label: "揭示章节", value: "第\(revealChapter)章")
            }
        }
    }

    // MARK: - 心理状态

    private var mentalStateSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("心理状态", systemImage: "brain.head.profile")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(mentalStateColor)

            HStack {
                Text("状态：")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                Text(character.mentalState)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(mentalStateColor)
            }

            if !character.mentalStateReason.isEmpty {
                Text("原因：\(character.mentalStateReason)")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: - 辅助

    private var mentalStateColor: Color {
        switch character.mentalState.uppercased() {
        case "NORMAL": return Theme.success
        case "STRESSED", "ANXIOUS": return Theme.warning
        case "BROKEN", "TRAUMATIZED": return Theme.error
        default: return Theme.textSecondary
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
