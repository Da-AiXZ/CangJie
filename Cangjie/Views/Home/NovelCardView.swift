//
//  NovelCardView.swift
//  Cangjie
//
//  单个书目卡片：封面色块/标题/进度/最近更新时间/自动审批 Toggle。
//  对齐 Vue3 Home.vue 的 book-card 交互。
//

import SwiftUI

/// 书目卡片视图
struct NovelCardView: View {

    let novel: NovelDTO

    /// 点击回调
    var onTap: () -> Void

    // MARK: - 阶段颜色

    /// 根据小说阶段返回颜色
    private var stageColor: Color {
        switch novel.stage {
        case "planning": return Theme.info
        case "writing": return Theme.primary
        case "reviewing": return Theme.warning
        case "completed": return Theme.success
        default: return Theme.textSecondary
        }
    }

    /// 阶段中文标签
    private var stageLabel: String {
        return novel.stageEnum?.displayName ?? novel.stage
    }

    // MARK: - 进度

    /// 完成进度百分比
    private var progressPercentage: Double {
        guard novel.targetChapters > 0 else { return 0 }
        return min(1.0, Double(novel.chapters.filter { $0.status == "completed" }.count) / Double(novel.targetChapters))
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // 顶部：状态点 + 标题
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(stageColor)
                        .frame(width: 8, height: 8)

                    Text(novel.title.isEmpty ? "未命名" : novel.title)
                        .font(Theme.headlineFont())
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                }

                // 元数据行
                HStack(spacing: Theme.Spacing.xs) {
                    Text(stageLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(stageColor)
                        .cornerRadius(4)

                    if !novel.lockedGenre.isEmpty {
                        Text(novel.lockedGenre)
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // 统计信息
                HStack(spacing: Theme.Spacing.md) {
                    if !novel.chapters.isEmpty {
                        Label("\(novel.chapters.count) 章", systemImage: "book.fill")
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.textTertiary)
                    }

                    if novel.totalWordCount > 0 {
                        Text(formatWordCount(novel.totalWordCount))
                            .font(Theme.captionFont())
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                // 进度条
                if novel.targetChapters > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progressPercentage)
                            .tint(stageColor)
                            .scaleEffect(y: 0.7)

                        Text("\(Int(progressPercentage * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.secondaryBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .cardShadow(.light)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 辅助

    /// 格式化字数显示
    private func formatWordCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万字", Double(count) / 10000)
        }
        return "\(count)字"
    }
}
