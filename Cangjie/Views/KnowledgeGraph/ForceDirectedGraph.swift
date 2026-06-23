//
//  ForceDirectedGraph.swift
//  Cangjie
//
//  通用力导向图组件，参数化（节点渲染闭包/边渲染闭包/点击回调）。
//  内部用 ForceSimulation + Canvas，支持捏合缩放+拖拽平移+点击节点。
//  接收任意 [GraphNode]/[GraphEdge] 数据。
//

import SwiftUI

/// 通用力导向图视图
struct ForceDirectedGraph: View {

    /// 节点数据
    let nodes: [ForceSimulation.GraphNode]

    /// 边数据
    let edges: [ForceSimulation.GraphEdge]

    /// 节点颜色回调
    var nodeColor: (ForceSimulation.GraphNode) -> Color = { _ in .blue }

    /// 节点半径回调
    var nodeRadius: (ForceSimulation.GraphNode) -> CGFloat = { _ in 20 }

    /// 节点标签回调
    var nodeLabel: (ForceSimulation.GraphNode) -> String = { $0.label }

    /// 边颜色回调
    var edgeColor: (ForceSimulation.GraphEdge) -> Color = { _ in .gray.opacity(0.4) }

    /// 边标签回调
    var edgeLabel: ((ForceSimulation.GraphEdge) -> String)? = nil

    /// 点击节点回调
    var onTapNode: ((String) -> Void)? = nil

    /// 力导向模拟器
    @StateObject private var simulation = ForceSimulation()

    /// 缩放
    @GestureState private var scale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0

    /// 平移
    @GestureState private var offset: CGSize = .zero
    @State private var currentOffset: CGSize = .zero

    /// 拖拽中的节点
    @State private var draggingNodeId: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    drawEdges(context: context, size: size)
                    drawNodes(context: context, size: size)
                }
                .scaleEffect(currentScale * scale)
                .offset(x: currentOffset.width + offset.width)
                .offset(y: currentOffset.height + offset.height)
                .gesture(
                    MagnificationGesture()
                        .updating($scale) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            currentScale = max(0.3, min(3.0, currentScale * value))
                        }
                )
                .gesture(
                    DragGesture()
                        .updating($offset) { value, state, _ in
                            if draggingNodeId == nil {
                                state = value.translation
                            }
                        }
                        .onEnded { value in
                            if draggingNodeId == nil {
                                currentOffset.width += value.translation.width
                                currentOffset.height += value.translation.height
                            }
                        }
                )
                .onTapGesture { location in
                    handleTap(at: location, in: geometry)
                }
            }
        }
        .background(Color(.systemGray6))
        .onAppear {
            simulation.updateConfig(ForceSimulation.Config(
                canvasWidth: 800,
                canvasHeight: 600,
                nodeRadius: 25
            ))
            simulation.setGraph(nodes: nodes, edges: edges)
            simulation.start()
        }
        .onChange(of: nodes) { newNodes in
            simulation.setGraph(nodes: newNodes, edges: edges)
            simulation.start()
        }
        .onDisappear {
            simulation.stop()
        }
    }

    // MARK: - 绘制边

    private func drawEdges(context: GraphicsContext, size: CGSize) {
        for edge in edges {
            guard let (start, end) = simulation.edgeEndpoints(edge) else { continue }

            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

            let color = edgeColor(edge)
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // 边标签
            if let labelFn = edgeLabel {
                let midX = (start.x + end.x) / 2
                let midY = (start.y + end.y) / 2
                let labelText = Text(labelFn(edge))
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textSecondary)
                context.draw(labelText, at: CGPoint(x: midX, y: midY - 6))
            }
        }
    }

    // MARK: - 绘制节点

    private func drawNodes(context: GraphicsContext, size: CGSize) {
        for node in nodes {
            guard let pos = simulation.position(for: node.id) else { continue }

            let radius = nodeRadius(node)
            let color = nodeColor(node)

            // 节点圆形
            let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)
            let circle = Path(ellipseIn: rect)

            context.fill(circle, with: .color(color.opacity(0.2)))
            context.stroke(circle, with: .color(color), lineWidth: 2)

            // 节点标签
            let label = nodeLabel(node)
            let labelText = Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
            context.draw(labelText, at: CGPoint(x: pos.x, y: pos.y + radius + 8))
        }
    }

    // MARK: - 点击处理

    private func handleTap(at point: CGPoint, in geometry: GeometryProxy) {
        // 反变换坐标
        let transformedX = (point.x - currentOffset.width - offset.width) / (currentScale * scale)
        let transformedY = (point.y - currentOffset.height - offset.height) / (currentScale * scale)

        for node in nodes {
            guard let pos = simulation.position(for: node.id) else { continue }
            let radius = nodeRadius(node)
            let dx = transformedX - pos.x
            let dy = transformedY - pos.y
            if sqrt(dx * dx + dy * dy) <= radius + 5 {
                onTapNode?(node.id)
                return
            }
        }
    }
}
