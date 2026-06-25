//
//  ChapterAuditSectionView.swift
//  Cangjie
//
//  一致性报告子组件，对齐原版 ChapterStatusPanel.vue:194-198 引用的 ConsistencyReportPanel。
//  独立新建（决策5），不内联到 ChapterStatusPanel。
//

import SwiftUI

/// 章节审计/一致性报告子组件
///
/// 对齐原版 `components/workbench/ConsistencyReportPanel.vue`。
/// 被 ChapterStatusPanelView 引用，展示一致性问题+建议+token统计。
struct ChapterAuditSectionView: View {

    /// 一致性报告（对齐 props.report）
    let report: ConsistencyReportDTO

    /// token 数（对齐 props.tokenCount）
    let tokenCount: Int

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 对齐 token 统计
            HStack {
                Text("Token 数")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Text("\(tokenCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }

            // 对齐 问题列表
            if !report.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("问题（\(report.issues.count)）")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.error)
                    ForEach(report.issues) { issue in
                        issueRow(issue)
                    }
                }
            }

            // 对齐 警告列表
            if !report.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("警告（\(report.warnings.count)）")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.warning)
                    ForEach(report.warnings) { warning in
                        issueRow(warning)
                    }
                }
            }

            // 对齐 建议
            if !report.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("建议")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.info)
                    ForEach(report.suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                            .font(.system(size: 11))
                            .padding(8)
                            .background(Theme.info.opacity(0.08))
                            .cornerRadius(6)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if report.issues.isEmpty && report.warnings.isEmpty && report.suggestions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.success)
                    Text("一致性检查通过")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.success)
                }
            }
        }
    }

    // MARK: - 问题行

    private func issueRow(_ issue: ConsistencyIssueDTO) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(issue.type)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(severityColor(issue.severity).opacity(0.15))
                    .cornerRadius(3)
                    .foregroundColor(severityColor(issue.severity))
                Text(issue.description)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textPrimary)
            }
            if issue.location > 0 {
                Text("约第 \(issue.location) 字")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(8)
        .background(severityColor(issue.severity).opacity(0.06))
        .cornerRadius(6)
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "error": return Theme.error
        case "warning": return Theme.warning
        case "info": return Theme.info
        default: return Theme.textSecondary
        }
    }
}
