//
//  WorldlineDAGView.swift
//  Cangjie
//
//  世界线 Git 图：自定义 Canvas 绘制世界线 DAG（checkout/hard-reset/merge 操作历史）。
//  泳道图布局（每个世界线一条泳道），节点=操作，边=派生关系。
//  调 SnapshotStore。
//

import SwiftUI

/// 世界线 DAG 视图
struct WorldlineDAGView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = SnapshotStore()

    /// 缩放/平移
    @GestureState private var scale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 0.9
    @GestureState private var offset: CGSize = .zero
    @State private var currentOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // 统计条
            statsBar

            // Canvas DAG
            GeometryReader { geo in
                Canvas { context, size in
                    drawWorldline(context: context, size: size)
                }
                .scaleEffect(currentScale * scale)
                .offset(x: currentOffset.width + offset.width, y: currentOffset.height + offset.height)
                .gesture(MagnificationGesture().updating($scale) { v, s, _ in s = v }.onEnded { v in currentScale = max(0.3, min(2, currentScale * v)) })
                .gesture(DragGesture().updating($offset) { v, s, _ in s = v.translation }.onEnded { v in
                    currentOffset.width += v.translation.width
                    currentOffset.height += v.translation.height
                })
            }
        }
        .navigationTitle("世界线")
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadSnapshots(novelId: novelId)
                await store.loadCheckpoints(novelId: novelId)
            }
        }
    }

    // MARK: - 统计条

    private var statsBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            statItem("快照", "\(store.snapshots.count)", Theme.primary)
            statItem("检查点", "\(store.checkpoints.count)", Theme.warning)
            statItem("HEAD", store.headCheckpointId?.prefix(8).description ?? "—", Theme.success)
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.secondaryBackground)
    }

    private func statItem(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - Canvas 绘制

    private func drawWorldline(context: GraphicsContext, size: CGSize) {
        let checkpoints = store.checkpoints
        guard !checkpoints.isEmpty else { return }

        let laneCount = computeLanes(checkpoints)
        let laneHeight: CGFloat = 50
        let laneWidth: CGFloat = 30
        let nodeRadius: CGFloat = 8
        let startX: CGFloat = 40

        // 泳道标签
        for i in 0..<laneCount {
            let y = startY(i)
            context.draw(
                Text("分支 \(i + 1)").font(.system(size: 9)).foregroundColor(Theme.textTertiary),
                at: CGPoint(x: 15, y: y + laneHeight / 2)
            )
        }

        // 绘制每个检查点作为节点
        var prevPositions: [String: CGPoint] = [:]
        for (index, cp) in checkpoints.enumerated() {
            let lane = laneAssignment(cp.id, checkpoints)
            let y = startY(max(0, min(laneCount - 1, lane))) + laneHeight / 2
            let x = startX + CGFloat(index) * (laneWidth + nodeRadius * 3)

            let pos = CGPoint(x: x, y: y)

            // 节点
            let rect = CGRect(x: pos.x - nodeRadius, y: pos.y - nodeRadius, width: nodeRadius * 2, height: nodeRadius * 2)
            let circle = Path(ellipseIn: rect)
            context.fill(circle, with: .color(cp.isHead ? Theme.primary : cpColor(cp.triggerType)))
            context.stroke(circle, with: .color(cp.isHead ? Theme.primary : cpColor(cp.triggerType).opacity(0.5)), lineWidth: 1.5)

            // 标签
            let label = cp.triggerReason.isEmpty ? cp.triggerType : cp.triggerReason
            context.draw(
                Text(label).font(.system(size: 8)).foregroundColor(Theme.textSecondary),
                at: CGPoint(x: pos.x, y: pos.y + nodeRadius + 8)
            )
            // 章节
            if let ch = cp.chapterNumber {
                context.draw(
                    Text("第\(ch)章").font(.system(size: 7)).foregroundColor(Theme.textTertiary),
                    at: CGPoint(x: pos.x, y: pos.y + nodeRadius + 18)
                )
            }

            // 父边
            if let parentId = cp.parentId, let parentPos = prevPositions[parentId] {
                var path = Path()
                path.move(to: parentPos)
                let midX = (parentPos.x + pos.x) / 2
                path.addCurve(to: pos, control1: CGPoint(x: midX, y: parentPos.y), control2: CGPoint(x: midX, y: pos.y))
                context.stroke(path, with: .color(Theme.textTertiary.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }

            // 前序节点水平连线（同泳道）
            if index > 0 {
                let prev = checkpoints[index - 1]
                let prevLane = laneAssignment(prev.id, checkpoints)
                let prevY = startY(max(0, min(laneCount - 1, prevLane))) + laneHeight / 2
                let prevX = startX + CGFloat(index - 1) * (laneWidth + nodeRadius * 3)

                if abs(prevY - y) < 5 {
                    var path = Path()
                    path.move(to: CGPoint(x: prevX, y: prevY))
                    path.addLine(to: CGPoint(x: x, y: y))
                    context.stroke(path, with: .color(Theme.textTertiary.opacity(0.2)), lineWidth: 0.5)
                }
            }

            prevPositions[cp.id] = pos
        }
    }

    // MARK: - 泳道计算

    private func computeLanes(_ checkpoints: [CheckpointDTO]) -> Int {
        let maxBranches = max(1, checkpoints.filter { $0.parentId == nil }.count)
        return min(maxBranches + 1, 5)
    }

    private func startY(_ lane: Int) -> CGFloat {
        return 30 + CGFloat(lane) * 50
    }

    private func laneAssignment(_ id: String, _ checkpoints: [CheckpointDTO]) -> Int {
        return abs(id.hashValue) % max(1, computeLanes(checkpoints))
    }

    private func cpColor(_ type: String) -> Color {
        switch type {
        case "CHAPTER": return Theme.primary
        case "ACT": return Theme.warning
        case "MILESTONE": return Theme.success
        case "MANUAL": return Theme.info
        case "AUTO": return Theme.statusBypassed
        default: return Theme.textSecondary
        }
    }
}
