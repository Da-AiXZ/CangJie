//
//  MonitorDashboardView.swift
//  Cangjie
//
//  监控大盘主页：张力曲线 + 文风漂移 + 质量雷达 + 一致性报告 + 进度统计。
//  ScrollView 分区布局。调 MonitorStore。
//  对齐 Vue3 AutopilotMetricsDashboard.vue 的分区布局。
//

import SwiftUI

/// 监控大盘
struct MonitorDashboardView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var monitorStore = MonitorStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // 张力曲线
                if let curve = monitorStore.tensionCurve {
                    TensionChartView(curve: curve)
                } else if monitorStore.isLoading {
                    loadingCard("张力曲线")
                } else {
                    emptyCard("张力曲线", icon: "chart.line.uptrend.xyaxis")
                }

                // 文风漂移
                if !monitorStore.voiceDrifts.isEmpty {
                    voiceDriftSection
                }

                // 进度图
                if let curve = monitorStore.tensionCurve, !curve.points.isEmpty {
                    ProgressChartView(points: curve.points)
                }

                // 伏笔统计
                if let stats = monitorStore.foreshadowStats {
                    foreshadowStatsCard(stats)
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle("监控大盘")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let novelId = appState.currentNovelId {
                await monitorStore.loadAll(novelId: novelId)
            }
        }
    }

    // MARK: - 文风漂移

    private var voiceDriftSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("文风漂移检测", systemImage: "waveform.path.ecg")
                .font(Theme.headlineFont())

            ForEach(monitorStore.voiceDrifts) { drift in
                VoiceDriftGauge(drift: drift)
            }
        }
        .cardStyle()
    }

    // MARK: - 伏笔统计

    private func foreshadowStatsCard(_ stats: ForeshadowStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("伏笔统计", systemImage: "lightbulb.fill")
                .font(Theme.headlineFont())

            HStack(spacing: Theme.Spacing.lg) {
                statItem(label: "已埋下", value: "\(stats.totalPlanted)", color: Theme.info)
                statItem(label: "已闭合", value: "\(stats.totalResolved)", color: Theme.success)
                statItem(label: "待处理", value: "\(stats.pending)", color: Theme.warning)
                statItem(label: "遗忘风险", value: "\(stats.forgottenRisk)", color: Theme.error)
            }

            // 闭合率进度条
            VStack(alignment: .leading, spacing: 4) {
                Text("闭合率")
                    .font(.system(size: 12))
                ProgressView(value: stats.resolutionRate / 100, total: 1.0)
                    .tint(stats.resolutionRate >= 70 ? Theme.success : Theme.warning)
                Text(String(format: "%.1f%%", stats.resolutionRate))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    // MARK: - 辅助

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadingCard(_ title: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
            Text("加载\(title)…")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }

    private func emptyCard(_ title: String, icon: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)
            Text(title)
                .font(Theme.headlineFont())
                .foregroundColor(Theme.textSecondary)
            Text("暂无数据")
                .font(Theme.captionFont())
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.secondaryBackground)
        .cornerRadius(Theme.CornerRadius.large)
    }
}
