//
//  TrendChartView.swift
//  Cangjie
//
//  折线趋势图（A-1），对齐原版 components/charts/TrendChart.vue。
//  使用 Swift Charts LineMark + AreaMark 渐变（Q2 决策）。
//

import SwiftUI
import Charts

// MARK: - 趋势图数据点

/// 趋势图数据点，对齐原版 TrendChart.vue:11-14 TrendData
struct TrendChartData: Identifiable {
    let id = UUID()
    let date: String
    let value: Double
}

// MARK: - 趋势图视图

/// 折线趋势图，对齐原版 components/charts/TrendChart.vue。
///
/// LineMark 平滑曲线 + AreaMark 渐变（gradientStart → gradientEnd）。
/// 配色使用 ChartColors.primary / gradientStart / gradientEnd。
struct TrendChartView: View {

    let data: [TrendChartData]
    var title: String = "趋势图"
    var height: CGFloat = 400

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Chart(data) { point in
                LineMark(
                    x: .value("日期", point.date),
                    y: .value("数值", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(ChartColors.primary)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("日期", point.date),
                    y: .value("数值", point.value)
                )
                .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        .linearGradient(
                            colors: [ChartColors.gradientStart, ChartColors.gradientEnd],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(height: height)
        }
    }
}
