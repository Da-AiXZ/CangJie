//
//  QualityGuardrailPanel.swift
//  Cangjie
//
//  质量护栏（雷达图 Canvas 五维度+违规列表+严重程度着色），调 MonitorStore。
//

import SwiftUI

struct QualityGuardrailPanel: View {
    @EnvironmentObject var appState: AppState

    /// 五维度评分（模拟数据，T05 接真实 API）
    @State private var dimensions: [(String, Double)] = [
        ("张力", 0.75), ("文风", 0.82), ("一致性", 0.90), ("Anti-AI", 0.65), ("节奏", 0.78)
    ]
    @State private var violations: [(String, String, String)] = [
        ("张力偏低", "warning", "第3章张力值低于警戒线"),
        ("AI味检测", "error", "检测到3处AI味短语"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // 雷达图
                Canvas { context, size in
                    drawRadar(context: context, size: size)
                }
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity)

                // 违规列表
                if !violations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("违规项").font(.system(size: 12, weight: .semibold))
                        ForEach(violations.indices, id: \.self) { i in
                            let v = violations[i]
                            HStack {
                                Circle().fill(severityColor(v.1)).frame(width: 6, height: 6)
                                Text(v.0).font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(v.2).font(.system(size: 10)).foregroundColor(Theme.textTertiary).lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.sm)
        }
        .background(Theme.background)
    }

    private func drawRadar(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35
        let n = dimensions.count

        // 网格
        for ring in 1...4 {
            var path = Path()
            for i in 0..<n {
                let angle = CGFloat(i) / CGFloat(n) * 2 * .pi - .pi / 2
                let r = radius * CGFloat(ring) / 4
                let p = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(Theme.textTertiary.opacity(0.2)), lineWidth: 0.5)
        }

        // 数据多边形
        var dataPath = Path()
        for (i, dim) in dimensions.enumerated() {
            let angle = CGFloat(i) / CGFloat(n) * 2 * .pi - .pi / 2
            let r = radius * dim.1
            let p = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { dataPath.move(to: p) } else { dataPath.addLine(to: p) }
        }
        dataPath.closeSubpath()
        context.fill(dataPath, with: .color(Theme.primary.opacity(0.2)))
        context.stroke(dataPath, with: .color(Theme.primary), lineWidth: 1.5)

        // 标签
        for (i, dim) in dimensions.enumerated() {
            let angle = CGFloat(i) / CGFloat(n) * 2 * .pi - .pi / 2
            let labelPos = CGPoint(x: center.x + (radius + 12) * cos(angle), y: center.y + (radius + 12) * sin(angle))
            context.draw(Text(dim.0).font(.system(size: 9)).foregroundColor(Theme.textSecondary), at: labelPos)
        }
    }

    private func severityColor(_ s: String) -> Color {
        switch s { case "error": return Theme.error; case "warning": return Theme.warning; default: return Theme.info }
    }
}
