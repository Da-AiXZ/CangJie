//
//  AntiAIPanel.swift
//  Cangjie
//
//  Anti-AI 防御（扫描结果+违规短语列表+建议替换）。
//

import SwiftUI

struct AntiAIPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var workbenchStore: WorkbenchStore
    @State private var scanResult: AntiAIScanResult?
    @State private var isScanning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // 扫描按钮
                Button {
                    Task { await scan() }
                } label: {
                    Label(isScanning ? "扫描中…" : "扫描 AI 味", systemImage: "sparkles.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isScanning || workbenchStore.chapterContent.isEmpty)

                if let result = scanResult {
                    // 概要
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            statBlock("总命中", "\(result.totalHits)", Theme.warning)
                            statBlock("严重", "\(result.criticalHits)", Theme.error)
                            statBlock("警告", "\(result.warningHits)", Theme.warning)
                            statBlock("严重度", String(format: "%.1f", result.severityScore), result.severityScore > 5 ? Theme.error : Theme.success)
                        }
                        Text(result.overallAssessment).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                    }

                    // 违规短语
                    if !result.hits.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("违规短语").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                            ForEach(result.hits) { hit in
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack {
                                        Circle().fill(severityColor(hit.severity ?? "")).frame(width: 5, height: 5)
                                        Text(hit.pattern ?? "未知模式").font(.system(size: 11, weight: .medium))
                                        Spacer()
                                        Text(hit.category ?? "").font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                                    }
                                    if let excerpt = hit.excerpt { Text(excerpt).font(.system(size: 9)).foregroundColor(Theme.textTertiary).lineLimit(1) }
                                    if let suggestion = hit.suggestion { Text("→ \(suggestion)").font(.system(size: 9)).foregroundColor(Theme.success) }
                                }
                            }
                        }
                    }

                    // 建议
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("建议").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.primary)
                            ForEach(result.recommendations, id: \.self) { rec in
                                Text("• \(rec)").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
    }

    private func statBlock(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 8)).foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func severityColor(_ s: String) -> Color {
        switch s.lowercased() { case "critical", "error": return Theme.error; case "warning": return Theme.warning; default: return Theme.info }
    }

    private func scan() async {
        guard !workbenchStore.chapterContent.isEmpty else { return }
        isScanning = true
        let request = AntiAIScanRequest(content: workbenchStore.chapterContent, chapterId: nil)
        do {
            scanResult = try await APIClient.shared.request(APIEndpoint.AntiAI.scan, body: request)
        } catch {
            // 忽略错误
        }
        isScanning = false
    }
}
