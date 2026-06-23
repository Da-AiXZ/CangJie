//
//  ChapterToolbar.swift
//  Cangjie
//
//  中栏顶部工具栏：章节标题/状态标签/字数/保存按钮/AI审阅按钮/生成提示按钮。
//  对齐 Vue3 WorkArea.vue 的章节头部信息。
//

import SwiftUI

/// 章节工具栏
struct ChapterToolbar: View {

    let chapter: ChapterDTO

    @EnvironmentObject var workbenchStore: WorkbenchStore

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 章节号
            Text("第\(chapter.number)章")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.primary)

            // 状态标签
            statusBadge

            Divider()
                .frame(height: 20)

            // 字数
            Text("\(chapter.wordCount) 字")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            // 保存指示
            if workbenchStore.isSaving {
                ProgressView()
                    .scaleEffect(0.7)
            } else if workbenchStore.hasUnsavedChanges {
                Text("未保存")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.warning)
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.success)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 状态标签

    private var statusBadge: some View {
        let statusColor: Color = chapter.status == "completed" ? Theme.success : Theme.warning
        let statusText: String = chapter.status == "completed" ? "已完成" : "草稿"

        return Text(statusText)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor)
            .cornerRadius(4)
    }
}
