//
//  ProgressRingChartView.swift
//  Cangjie
//
//  环形进度图（A-1），对齐原版 components/charts/ProgressChart.vue。
//  使用 Canvas 自绘环形（Q2 决策：SectorMark 需 iOS 17+，iOS 16 用 Canvas）。
//

import SwiftUI

// MARK: - 环形进度图视图

/// 环形进度图，对齐原版 components/charts/ProgressChart.vue。
///
/// Canvas 自绘环形：completed 弧（ChartColors.success）+ remaining 弧（ChartColors.gray）。
/// 中心显示 "completed/total" 文本。
struct ProgressRingChartView: View {

    let completed: Int
    let total: Int
    var height: CGFloat = 300

    /// 安全的完成数（不超过总数）
    private var safeCompleted: Int {
        return min(completed, total)
    }

    /// 剩余数
    private var remaining: Int {
        return max(0, total - safeCompleted)
    }

    /// 完成比例（0.0 ~ 1.0）
    private var progress: Double {
        guard total > 0 else { return 0.0 }
        return Double(safeCompleted) / Double(total)
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 20
                let lineWidth: CGFloat = 20

                // remaining 弧（灰色背景）
                let remainingPath = Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                context.stroke(remainingPath, with: .color(ChartColors.gray), lineWidth: lineWidth)

                // completed 弧（成功色）
                if progress > 0 {
                    let endAngle = 360.0 * progress
                    let completedPath = Path { path in
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + endAngle),
                            clockwise: false
                        )
                    }
                    context.stroke(completedPath, with: .color(ChartColors.success), lineWidth: lineWidth)
                }
            }
            .frame(width: height, height: height)

            // 中心文本
            VStack(spacing: 2) {
                Text("\(safeCompleted)/\(total)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
        }
        .frame(height: height)
    }
}
