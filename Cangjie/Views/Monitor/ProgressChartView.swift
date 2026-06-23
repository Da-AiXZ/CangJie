//
//  ProgressChartView.swift
//  Cangjie
//
//  写作进度图：Swift Charts BarMark 画各章节字数 + 目标线。
//

import SwiftUI
import Charts

/// 写作进度图
struct ProgressChartView: View {

    let points: [TensionPoint]

    /// 每章目标字数
    private let targetWordsPerChapter: Int = 2500

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("章节进度", systemImage: "chart.bar.fill")
                .font(Theme.headlineFont())

            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("章节", point.chapter),
                        y: .value("张力", point.tension)
                    )
                    .foregroundStyle(point.evaluated ? barColor(point.tension) : Color.gray.opacity(0.3))
                    .cornerRadius(2)
                }

                // 目标线
                RuleMark(y: .value("目标", 5.0))
                    .foregroundStyle(Theme.primary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: .automatic) {
                    AxisValueLabel()
                        .font(.system(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 5, 10]) {
                    AxisValueLabel()
                        .font(.system(size: 10))
                }
            }
            .frame(height: 150)
        }
        .cardStyle()
    }

    private func barColor(_ tension: Double) -> Color {
        if tension < 3.0 { return Theme.info }
        if tension < 7.0 { return Theme.success }
        return Theme.error
    }
}
