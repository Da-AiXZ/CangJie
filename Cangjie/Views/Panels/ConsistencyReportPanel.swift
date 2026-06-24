//
//  ConsistencyReportPanel.swift
//  Cangjie
//
//  一致性报告面板：issues/warnings/suggestions 三组折叠列表 + 位置点击 + 空状态。
//  对齐原版 ConsistencyReportPanel.vue:1-189。
//  数据来源：WorkbenchStore.generateChapterConsistencyReport（SSE done事件解析）。
//  机制4：每个区块标注原版文件+行号。
//

import SwiftUI

/// 一致性报告面板 — ConsistencyReportPanel.vue:1-189
struct ConsistencyReportPanel: View {

    @EnvironmentObject var workbenchStore: WorkbenchStore

    /// 展开的折叠组 — ConsistencyReportPanel.vue:99-105 defaultExpanded
    @State private var expandedSections: Set<String> = []

    var body: some View {
        // ConsistencyReportPanel.vue:2 v-if="report"
        if let report = consistencyReport {
            VStack(alignment: .leading, spacing: 8) {
                // 区块1: 头部标题 + token数 — ConsistencyReportPanel.vue:3-6
                headerRow

                // 区块2: 有内容时显示折叠列表 — ConsistencyReportPanel.vue:8-66
                if hasAnyContent {
                    issuesSection(report)
                    warningsSection(report)
                    suggestionsSection(report)
                } else {
                    // 区块3: 无内容空状态 — ConsistencyReportPanel.vue:68
                    Text("暂无一致性问题或建议")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(10)
            .background(Theme.secondaryBackground.opacity(0.5))
            .cornerRadius(8)
        } else {
            // 无报告时不渲染 — ConsistencyReportPanel.vue:2
            Text("尚无一致性报告")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    // MARK: - 数据来源

    /// 一致性报告 — 从 WorkbenchStore 获取（SSE done事件解析）
    /// 对齐 workflow.ts:453-463 done事件 consistency_report
    private var consistencyReport: ConsistencyReportDTO? {
        return workbenchStore.generateChapterConsistencyReport
    }

    /// token 数 — ConsistencyReportPanel.vue:5
    private var tokenCount: Int? {
        // 从 WorkbenchStore 获取（如果有的话）
        return nil
    }

    // MARK: - 计算属性 — ConsistencyReportPanel.vue:89-105

    /// 是否有内容 — ConsistencyReportPanel.vue:89-97
    private var hasAnyContent: Bool {
        guard let report = consistencyReport else { return false }
        return !report.issues.isEmpty || !report.warnings.isEmpty || !report.suggestions.isEmpty
    }

    // MARK: - 头部 — ConsistencyReportPanel.vue:3-6

    private var headerRow: some View {
        HStack {
            Text("一致性报告")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if let tokenCount = tokenCount {
                Text("约 \(tokenCount) tokens")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - 问题列表 — ConsistencyReportPanel.vue:13-37

    private func issuesSection(_ report: ConsistencyReportDTO) -> some View {
        Group {
            if !report.issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        toggleSection("issues")
                    } label: {
                        HStack {
                            Text("问题 (\(report.issues.count))")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: expandedSections.contains("issues") ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)

                    if expandedSections.contains("issues") {
                        ForEach(Array(report.issues.enumerated()), id: \.offset) { _, item in
                            issueRow(item)
                        }
                    }
                }

                if !report.warnings.isEmpty || !report.suggestions.isEmpty {
                    Divider().padding(.vertical, 2)
                }
            }
        }
        .onAppear {
            // ConsistencyReportPanel.vue:99-105 defaultExpanded
            if !report.issues.isEmpty { expandedSections.insert("issues") }
            if !report.warnings.isEmpty { expandedSections.insert("warnings") }
            if !report.suggestions.isEmpty { expandedSections.insert("suggestions") }
        }
    }

    // MARK: - 警告列表 — ConsistencyReportPanel.vue:39-59

    private func warningsSection(_ report: ConsistencyReportDTO) -> some View {
        Group {
            if !report.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        toggleSection("warnings")
                    } label: {
                        HStack {
                            Text("警告 (\(report.warnings.count))")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: expandedSections.contains("warnings") ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)

                    if expandedSections.contains("warnings") {
                        ForEach(Array(report.warnings.enumerated()), id: \.offset) { _, item in
                            issueRow(item)
                        }
                    }
                }

                if !report.suggestions.isEmpty {
                    Divider().padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - 建议列表 — ConsistencyReportPanel.vue:61-65

    private func suggestionsSection(_ report: ConsistencyReportDTO) -> some View {
        Group {
            if !report.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        toggleSection("suggestions")
                    } label: {
                        HStack {
                            Text("建议 (\(report.suggestions.count))")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Image(systemName: expandedSections.contains("suggestions") ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.plain)

                    if expandedSections.contains("suggestions") {
                        // ConsistencyReportPanel.vue:62-64 ol > li
                        ForEach(Array(report.suggestions.enumerated()), id: \.offset) { index, suggestion in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textTertiary)
                                Text(suggestion)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 问题/警告行 — ConsistencyReportPanel.vue:15-35,41-57

    private func issueRow(_ item: ConsistencyIssueDTO) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // 严重程度标签 — ConsistencyReportPanel.vue:21-23
                Text(severityLabel(item.severity))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor(item.severity))
                    .cornerRadius(8)

                // 类型标签 — ConsistencyReportPanel.vue:24
                Text(item.type)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.textTertiary.opacity(0.15))
                    .cornerRadius(8)

                // 位置按钮 — ConsistencyReportPanel.vue:25-31
                Text("位置 \(item.location)")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.primary)

                Spacer()
            }
            // 描述 — ConsistencyReportPanel.vue:34
            Text(item.description)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 辅助方法 — ConsistencyReportPanel.vue:107-125

    private func toggleSection(_ name: String) {
        if expandedSections.contains(name) {
            expandedSections.remove(name)
        } else {
            expandedSections.insert(name)
        }
    }

    /// 严重程度着色 — ConsistencyReportPanel.vue:111-117 severityTag
    private func severityColor(_ sev: String) -> Color {
        let s = sev.lowercased()
        switch s {
        case "critical": return .red
        case "important": return .orange
        case "minor": return .blue
        default: return .gray
        }
    }

    /// 严重程度标签 — ConsistencyReportPanel.vue:119-125 severityLabel
    private func severityLabel(_ sev: String) -> String {
        let s = sev.lowercased()
        switch s {
        case "critical": return "严重"
        case "important": return "重要"
        case "minor": return "轻微"
        default: return sev.isEmpty ? "—" : sev
        }
    }
}
