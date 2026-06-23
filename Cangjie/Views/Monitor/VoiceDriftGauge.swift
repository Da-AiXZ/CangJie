//
//  VoiceDriftGauge.swift
//  Cangjie
//
//  文风漂移仪表盘：自定义 Canvas 半圆仪表盘（指针+刻度+色区）。
//  对齐 Vue3 VoiceDriftIndicator.vue 的仪表盘效果。
//

import SwiftUI

/// 文风漂移仪表盘
struct VoiceDriftGauge: View {

    let drift: VoiceDrift

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // 仪表盘 Canvas
            Canvas { context, size in
                drawGauge(context: context, size: size)
            }
            .frame(width: 100, height: 60)

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(drift.characterName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.system(size: 11))
                        .foregroundColor(statusColor)
                }

                Text("漂移指数：\(String(format: "%.2f", drift.driftScore))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)

                Text("样本数：\(drift.sampleCount)")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.tertiaryBackground)
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - Canvas 绘制

    private func drawGauge(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.85)
        let radius = min(size.width, size.height * 1.5) * 0.4

        // 半圆弧（从 180° 到 0°）
        let startAngle = Angle.degrees(180)
        let endAngle = Angle.degrees(0)

        // 色区背景弧
        // 绿色区（0~0.3）
        var greenPath = Path()
        greenPath.addArc(center: center, radius: radius,
                         startAngle: startAngle,
                         endAngle: Angle.degrees(180 - 180 * 0.3),
                         clockwise: false)
        context.stroke(greenPath, with: .color(Theme.success), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // 黄色区（0.3~0.5）
        var yellowPath = Path()
        yellowPath.addArc(center: center, radius: radius,
                          startAngle: Angle.degrees(180 - 180 * 0.3),
                          endAngle: Angle.degrees(180 - 180 * 0.5),
                          clockwise: false)
        context.stroke(yellowPath, with: .color(Theme.warning), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // 红色区（0.5~1.0）
        var redPath = Path()
        redPath.addArc(center: center, radius: radius,
                       startAngle: Angle.degrees(180 - 180 * 0.5),
                       endAngle: endAngle,
                       clockwise: false)
        context.stroke(redPath, with: .color(Theme.error), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // 指针
        let needleAngle = 180 - 180 * min(max(drift.driftScore, 0), 1)
        let needleEnd = CGPoint(
            x: center.x + radius * 0.85 * cos(needleAngle * .pi / 180),
            y: center.y - radius * 0.85 * sin(needleAngle * .pi / 180)
        )
        var needlePath = Path()
        needlePath.move(to: center)
        needlePath.addLine(to: needleEnd)
        context.stroke(needlePath, with: .color(Theme.textPrimary), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // 中心圆点
        let dotRect = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: dotRect), with: .color(Theme.textPrimary))
    }

    // MARK: - 辅助

    private var statusColor: Color {
        switch drift.status {
        case "normal": return Theme.success
        case "warning": return Theme.warning
        case "critical": return Theme.error
        default: return Theme.textSecondary
        }
    }

    private var statusLabel: String {
        switch drift.status {
        case "normal": return "正常"
        case "warning": return "警告"
        case "critical": return "严重"
        default: return drift.status
        }
    }
}
