//
//  DistributionChartView.swift
//  Cangjie
//
//  柱状分布图（A-1），对齐原版 components/charts/DistributionChart.vue。
//  使用 Swift Charts BarMark（Q2 决策）。
//

import SwiftUI
import Charts

// MARK: - 分布图数据点

/// 分布图数据点，对齐原版 DistributionChart.vue:11-14 DistributionData
struct DistributionChartData: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
}

// MARK: - 分布图视图

/// 柱状分布图，对齐原版 components/charts/DistributionChart.vue。
///
/// BarMark 柱状图，配色使用 ChartColors.primary。
struct DistributionChartView: View {

    let data: [DistributionChartData]
    var title: String = "分布图"
    var height: CGFloat = 400

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Chart(data) { point in
                BarMark(
                    x: .value("名称", point.name),
                    y: .value("数值", point.value)
                )
                .foregroundStyle(ChartColors.primary)
                .cornerRadius(4)
            }
            .frame(height: height)
        }
    }
}
