//
//  ConsistencyReportPanel.swift
//  Cangjie
//
//  一致性报告（冲突点列表+严重程度+涉及章节+修复建议）。
//

import SwiftUI

struct ConsistencyReportPanel: View {
    @EnvironmentObject var appState: AppState

    @State private var issues: [(String, String, String, String)] = [
        ("角色年龄矛盾", "warning", "第3章 vs 第7章", "检查时间线流逝"),
        ("地点描述不一致", "error", "第5章 vs 第12章", "统一地点描述细节"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if issues.isEmpty {
                    Text("暂无一致性问题").font(.system(size: 12)).foregroundColor(Theme.success).padding()
                } else {
                    ForEach(issues.indices, id: \.self) { i in
                        let issue = issues[i]
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Circle().fill(severityColor(issue.1)).frame(width: 6, height: 6)
                                Text(issue.0).font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(issue.1).font(.system(size: 8)).foregroundColor(severityColor(issue.1))
                            }
                            Text(issue.2).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                            Text("→ \(issue.3)").font(.system(size: 9)).foregroundColor(Theme.success)
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
    }

    private func severityColor(_ s: String) -> Color {
        switch s { case "error": return Theme.error; case "warning": return Theme.warning; default: return Theme.info }
    }
}
