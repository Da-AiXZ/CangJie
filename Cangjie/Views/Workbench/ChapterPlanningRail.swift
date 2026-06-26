//
//  ChapterPlanningRail.swift
//  Cangjie
//
//  右栏规划 Tab（节拍拆拍/微观节拍），对齐原版工作台右栏规划面板。
//

import SwiftUI

/// 章节规划轨道视图（右栏规划 Tab）
///
/// 显示章节微观节拍列表（ChapterMicroBeatPayload），支持查看节拍详情。
struct ChapterPlanningRail: View {
    let microBeats: [ChapterMicroBeatPayload]

    @State private var selectedBeatIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Label("微观节拍", systemImage: "list.bullet.indent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.primary)
                Spacer()
                Text("\(microBeats.count) 个节拍")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // 节拍列表
            if microBeats.isEmpty {
                Text("暂无微观节拍数据")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(microBeats.enumerated()), id: \.offset) { index, beat in
                            beatCard(index: index, beat: beat)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Theme.background)
    }

    // MARK: - 节拍卡片

    @ViewBuilder
    private func beatCard(index: Int, beat: ChapterMicroBeatPayload) -> some View {
        let isSelected = selectedBeatIndex == index
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(4)

                if let focus = beat.focus, !focus.isEmpty {
                    Text(focus)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                if let target = beat.targetWords {
                    Text("\(target)字")
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            Text(beat.description)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(isSelected ? nil : 3)

            if isSelected {
                // 展开详情
                if let conflict = beat.conflict, !conflict.isEmpty {
                    detailRow("冲突", conflict)
                }
                if let delta = beat.delta, !delta.isEmpty {
                    detailRow("变化", delta)
                }
                if let action = beat.visibleAction, !action.isEmpty {
                    detailRow("可见动作", action)
                }
                if let handoff = beat.handoffToNext, !handoff.isEmpty {
                    detailRow("交接", handoff)
                }
                if let must = beat.mustInclude, !must.isEmpty {
                    detailRow("必须包含", must.joined(separator: "、"))
                }
                if let mustNot = beat.mustNotInclude, !mustNot.isEmpty {
                    detailRow("禁止包含", mustNot.joined(separator: "、"))
                }
            }
        }
        .padding(10)
        .background(isSelected ? Theme.primary.opacity(0.05) : Theme.secondaryBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Theme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(6)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedBeatIndex = isSelected ? nil : index
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
