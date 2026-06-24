//
//  PromptVersionCompareView.swift
//  Cangjie
//
//  版本对比：左右两版并排，差异高亮。
//  对齐原版 llmControl.ts:197-204 VersionCompareResult（v1/v2 为对象，diff 为嵌套 Bool）。
//

import SwiftUI

/// 提示词版本对比视图
struct PromptVersionCompareView: View {

    let versions: [PromptVersion]
    var onCompare: (String, String) -> Void
    /// llmControl.ts:197-204 VersionCompareResult（原 PromptComparison→VersionCompareResult）
    let comparison: VersionCompareResult?

    @State private var v1Id: String = ""
    @State private var v2Id: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 版本选择
                HStack {
                    versionPicker(selection: $v1Id, label: "版本 A")
                    versionPicker(selection: $v2Id, label: "版本 B")

                    Button("对比") {
                        if !v1Id.isEmpty && !v2Id.isEmpty {
                            onCompare(v1Id, v2Id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(v1Id.isEmpty || v2Id.isEmpty || v1Id == v2Id)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.secondaryBackground)

                // 对比结果（llmControl.ts:197-204 VersionCompareResult）
                if let comparison = comparison {
                    ScrollView {
                        HStack(alignment: .top, spacing: 0) {
                            // llmControl.ts:198 v1 — PromptVersionDetail 对象
                            versionDetailPanel(title: "版本 A", detail: comparison.v1)
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.md)

                            Divider()

                            // llmControl.ts:199 v2 — PromptVersionDetail 对象
                            versionDetailPanel(title: "版本 B", detail: comparison.v2)
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.md)
                        }
                    }

                    // llmControl.ts:200-203 diff — 嵌套 Bool（原 diff: String? → diff: VersionDiff）
                    diffSection(comparison.diff)
                } else {
                    VStack {
                        Image(systemName: "arrow.left.and.right.square")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textTertiary)
                        Text("选择两个版本进行对比")
                            .font(Theme.bodyFont())
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("版本对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if versions.count >= 2 {
                    v1Id = versions[0].id
                    v2Id = versions[1].id
                }
            }
        }
    }

    // MARK: - 版本详情面板

    /// 展示 PromptVersionDetail 的 system_prompt + user_template
    private func versionDetailPanel(title: String, detail: PromptVersionDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.headlineFont())
            Text("v\(detail.versionNumber)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            // llmControl.ts:192 system_prompt
            Text("System:")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textTertiary)
            Text(detail.systemPrompt)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            // llmControl.ts:193 user_template
            Text("User:")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textTertiary)
            Text(detail.userTemplate)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - 差异展示（llmControl.ts:200-203 diff: VersionDiff）

    private func diffSection(_ diff: VersionDiff) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("差异")
                .font(Theme.headlineFont())

            // llmControl.ts:201 system_changed
            HStack {
                Image(systemName: diff.systemChanged ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(diff.systemChanged ? Theme.warning : Theme.success)
                Text("系统提示\(diff.systemChanged ? "已变更" : "无变更")")
                    .font(.system(size: 12))
            }

            // llmControl.ts:202 user_changed
            HStack {
                Image(systemName: diff.userChanged ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(diff.userChanged ? Theme.warning : Theme.success)
                Text("用户模板\(diff.userChanged ? "已变更" : "无变更")")
                    .font(.system(size: 12))
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.tertiaryBackground)
    }

    // MARK: - 版本选择器

    private func versionPicker(selection: Binding<String>, label: String) -> some View {
        Picker(label, selection: selection) {
            ForEach(versions) { version in
                Text("v\(version.versionNumber)").tag(version.id)
            }
        }
        .pickerStyle(.menu)
    }
}
