//
//  TensionChartView.swift
//  Cangjie
//
//  张力心电图：Swift Charts LineMark 画张力曲线（X=章节 Y=张力值），
//  RuleMark 画警戒线，不同区间背景着色。
//  对齐 Vue3 TensionChart.vue 的 ECharts 配置。
//

import SwiftUI
import Charts

/// 圆面积辅助工具，用于 Charts PointMark 的 symbolSize 计算
struct CircleArea {
    /// 根据半径计算圆面积，用于 symbolSize
    static func plotSize(radius: CGFloat) -> CGFloat {
        return .pi * radius * radius
    }
}

/// 张力曲线图
struct TensionChartView: View {

    let curve: TensionCurveResponse

    /// 警戒线阈值（默认 5.0）
    private let threshold: Double = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // 标题
            HStack {
                Label("张力心电图", systemImage: "chart.line.uptrend.xyaxis")
                    .font(Theme.headlineFont())

                Spacer()

                // 平缓警告
                if let stats = curve.stats, stats.isFlat {
                    Label("曲线过于平缓", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.error)
                }
            }

            // 图表
            if !curve.points.isEmpty {
                Chart {
                    // 区域着色（低张力蓝、适中绿、高张力红）
                    RectangleMark(
                        xStart: .value("低张力区", 0),
                        xEnd: .value("高张力区", Double(curve.points.count + 1)),
                        yStart: .value("低", 0),
                        yEnd: .value("阈值", threshold)
                    )
                    .foregroundStyle(Theme.info.opacity(0.05))

                    RectangleMark(
                        xStart: .value("高张力区", 0),
                        xEnd: .value("高张力区末", Double(curve.points.count + 1)),
                        yStart: .value("阈值", threshold),
                        yEnd: .value("最高", 10)
                    )
                    .foregroundStyle(Theme.error.opacity(0.05))

                    // 张力曲线
                    ForEach(curve.points) { point in
                        LineMark(
                            x: .value("章节", point.chapter),
                            y: .value("张力", point.tension)
                        )
                        .foregroundStyle(point.evaluated ? tensionColor(point.tension) : Color.gray)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        // 数据点
                        PointMark(
                            x: .value("章节", point.chapter),
                            y: .value("张力", point.tension)
                        )
                        .foregroundStyle(point.evaluated ? tensionColor(point.tension) : Color.gray.opacity(0.5))
                        .symbolSize(CircleArea.plotSize(radius: point.evaluated ? 5 : 3))
                    }

                    // 警戒线
                    RuleMark(y: .value("警戒线", threshold))
                        .foregroundStyle(Theme.warning)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("警戒线")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.warning)
                        }
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) {
                        AxisValueLabel()
                            .font(.system(size: 10))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) {
                        AxisValueLabel()
                            .font(.system(size: 10))
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
            } else {
                Text("暂无张力数据")
                    .font(Theme.captionFont())
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }

            // 底部统计
            if let stats = curve.stats {
                HStack(spacing: Theme.Spacing.md) {
                    Text("\(stats.evaluatedCount) 章")
                        .font(.system(size: 10))

                    Divider().frame(height: 10)

                    Text("均值 \(String(format: "%.1f", stats.avgTension))")
                        .font(.system(size: 10))

                    Divider().frame(height: 10)

                    Text("峰值 \(String(format: "%.1f", stats.maxTension))")
                        .font(.system(size: 10))

                    Divider().frame(height: 10)

                    Text("方差 \(String(format: "%.2f", stats.variance))")
                        .font(.system(size: 10))

                    if stats.unevaluatedCount > 0 {
                        Divider().frame(height: 10)
                        Text("\(stats.unevaluatedCount) 章未评估")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.info)
                    }
                }
                .foregroundColor(Theme.textTertiary)
            }
        }
        .cardStyle()
    }

    // MARK: - 辅助

    /// 张力值对应颜色
    private func tensionColor(_ value: Double) -> Color {
        if value < 3.0 { return Theme.info }       // 低张力蓝
        if value < 5.0 { return Theme.warning }     // 偏低橙
        if value < 7.0 { return Theme.success }     // 适中绿
        if value < 9.0 { return Theme.primary }     // 较高品牌色
        return Theme.error                           // 极高红
    }
}
