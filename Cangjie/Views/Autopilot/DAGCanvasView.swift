//
//  DAGCanvasView.swift
//  Cangjie
//
//  十步管线 DAG 自定义 Canvas 绘制。
//  用 SugiyamaLayout 算坐标，Canvas 画节点（圆角矩形+状态色+标签）+边（贝塞尔曲线+箭头）。
//  支持 MagnificationGesture 缩放 + DragGesture 平移 + 点击节点弹出详情。
//  节点状态着色（pending灰/running蓝动画/success绿/failed红/skipped黄）。
//  订阅 DAGStore.dagEvents 实时更新。
//  对齐 Vue3 DAGCanvas.vue + CustomNode.vue 的视觉效果。
//

import SwiftUI

/// DAG 画布视图
struct DAGCanvasView: View {

    @EnvironmentObject var dagStore: DAGStore

    /// 缩放
    @GestureState private var scale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 0.8

    /// 平移
    @GestureState private var offset: CGSize = .zero
    @State private var currentOffset: CGSize = .zero

    /// 选中的节点
    @State private var selectedNodeId: String?

    /// 节点详情弹窗
    @State private var showNodeDetail = false

    /// 布局结果缓存
    @State private var layoutResult: SugiyamaLayout.LayoutResult?

    /// 动画相位（running 节点脉冲）
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景网格
                backgroundGrid(in: geometry)

                // DAG 画布
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
                            currentScale = max(0.3, min(2.0, currentScale * value))
                        }
                )
                .gesture(
                    DragGesture()
                        .updating($offset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            currentOffset.width += value.translation.width
                            currentOffset.height += value.translation.height
                        }
                )
                .onTapGesture { location in
                    handleTap(at: location, in: geometry)
                }

                // 控制按钮
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            // 放大
                            buttonIcon("plus.magnifyingglass") {
                                currentScale = min(2.0, currentScale + 0.1)
                            }
                            // 缩小
                            buttonIcon("minus.magnifyingglass") {
                                currentScale = max(0.3, currentScale - 0.1)
                            }
                            // 重置
                            buttonIcon("arrow.counterclockwise") {
                                currentScale = 0.8
                                currentOffset = .zero
                            }
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.secondaryBackground.opacity(0.8))
                        .cornerRadius(Theme.CornerRadius.medium)
                    }
                    Spacer()
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(Color(.systemGray6))
        .onAppear {
            computeLayout()
            startPulseAnimation()
        }
        .onChange(of: dagStore.dagDefinition) { _ in
            computeLayout()
        }
        .sheet(isPresented: $showNodeDetail) {
            if let nodeId = selectedNodeId {
                nodeDetailSheet(nodeId)
            }
        }
    }

    // MARK: - 背景网格

    private func backgroundGrid(in geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            let gridSize: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 1)
                x += gridSize
            }
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 1)
                y += gridSize
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
    }

    // MARK: - 绘制边

    private func drawEdges(context: GraphicsContext, size: CGSize) {
        guard let result = layoutResult else { return }

        for edge in result.edges {
            guard edge.points.count >= 4 else { continue }

            let start = edge.points[0]
            let cp1 = edge.points[1]
            let cp2 = edge.points[2]
            let end = edge.points[3]

            var path = Path()
            path.move(to: start)
            path.addCurve(to: end, control1: cp1, control2: cp2)

            // 边颜色
            let strokeColor = edgeColor(edge)
            context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // 箭头
            drawArrow(context: context, from: cp2, to: end, color: strokeColor)
        }
    }

    // MARK: - 绘制节点

    private func drawNodes(context: GraphicsContext, size: CGSize) {
        guard let result = layoutResult else { return }

        for node in result.nodes {
            let nodeDef = dagStore.nodes.first { $0.id == node.id }
            let status = dagStore.nodeStates[node.id]?.status ?? "idle"
            let label = nodeDef?.label ?? node.id

            // 节点尺寸
            let nodeWidth: CGFloat = 140
            let nodeHeight: CGFloat = 50
            let rect = CGRect(
                x: node.x - nodeWidth / 2,
                y: node.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )

            // 圆角矩形
            let roundRect = RoundedRectangle(cornerRadius: 8)
            let path = Path(roundRect.path(in: rect))

            // 填充色
            let fillColor = nodeFillColor(status)
            context.fill(path, with: .color(fillColor.opacity(0.15)))

            // 边框色
            let strokeColor = nodeStrokeColor(status)
            let borderWidth: CGFloat = status == "running" ? 2.5 + pulsePhase : 2
            context.stroke(
                Path(roundRect.path(in: rect)),
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: borderWidth, lineCap: .round)
            )

            // 顶部色条（分类色）
            let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 4)
            let headerPath = Path(RoundedRectangle(cornerRadius: 4).path(in: headerRect))
            context.fill(headerPath, with: .color(categoryColor(nodeDef?.type ?? "")))

            // 节点标签
            let labelText = Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            context.draw(labelText, at: CGPoint(x: node.x, y: node.y - 5))

            // 状态标签
            let statusText = Text(statusLabel(status))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(strokeColor)
            context.draw(statusText, at: CGPoint(x: node.x, y: node.y + 12))

            // running 节点：进度环
            if status == "running" {
                let progress = dagStore.nodeStates[node.id]?.progress ?? 0
                let arcRect = rect.insetBy(dx: -4, dy: -4)
                var arcPath = Path()
                arcPath.addArc(
                    center: CGPoint(x: arcRect.midX, y: arcRect.midY),
                    radius: max(arcRect.width, arcRect.height) / 2,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * Double(progress)),
                    clockwise: false
                )
                context.stroke(arcPath, with: .color(Theme.statusRunning), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    // MARK: - 箭头

    private func drawArrow(context: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let angle = atan2(dy, dx)
        let arrowLength: CGFloat = 8

        let p1 = CGPoint(
            x: to.x - arrowLength * cos(angle - .pi / 6),
            y: to.y - arrowLength * sin(angle - .pi / 6)
        )
        let p2 = CGPoint(
            x: to.x - arrowLength * cos(angle + .pi / 6),
            y: to.y - arrowLength * sin(angle + .pi / 6)
        )

        var path = Path()
        path.move(to: to)
        path.addLine(to: p1)
        path.move(to: to)
        path.addLine(to: p2)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    // MARK: - 点击处理

    private func handleTap(at point: CGPoint, in geometry: GeometryProxy) {
        // 反变换坐标
        let transformedX = (point.x - currentOffset.width - offset.width) / (currentScale * scale)
        let transformedY = (point.y - currentOffset.height - offset.height) / (currentScale * scale)

        // 命中测试
        if let result = layoutResult {
            for node in result.nodes {
                let dx = abs(transformedX - node.x)
                let dy = abs(transformedY - node.y)
                if dx < 70 && dy < 25 {
                    selectedNodeId = node.id
                    showNodeDetail = true
                    return
                }
            }
        }
    }

    // MARK: - 布局计算

    private func computeLayout() {
        guard let dag = dagStore.dagDefinition else { return }

        let layoutNodes = dag.nodes.map { SugiyamaLayout.LayoutNode(id: $0.id, width: 140, height: 50) }
        let layoutEdges = dag.edges.map { SugiyamaLayout.LayoutEdge(id: $0.id, source: $0.source, target: $0.target) }

        layoutResult = SugiyamaLayout.layout(nodes: layoutNodes, edges: layoutEdges)
    }

    // MARK: - 脉冲动画

    private func startPulseAnimation() {
        Task {
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulsePhase = 1.5
                }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
            }
        }
    }

    // MARK: - 节点详情 Sheet

    private func nodeDetailSheet(_ nodeId: String) -> some View {
        let node = dagStore.nodes.first { $0.id == nodeId }
        let runState = dagStore.nodeStates[nodeId]

        return NavigationStack {
            Form {
                Section("节点信息") {
                    LabeledContent("ID", value: nodeId)
                    LabeledContent("类型", value: node?.type ?? "")
                    LabeledContent("标签", value: node?.label ?? "")
                    LabeledContent("状态", value: runState?.status ?? "idle")
                    LabeledContent("启用", value: node?.enabled == true ? "是" : "否")
                }

                if let state = runState {
                    Section("运行时") {
                        if state.durationMs > 0 {
                            LabeledContent("耗时", value: "\(state.durationMs)ms")
                        }
                        if state.progress > 0 {
                            LabeledContent("进度", value: "\(Int(state.progress * 100))%")
                        }
                        if let error = state.error {
                            LabeledContent("错误", value: error)
                        }
                    }

                    if !state.metrics.isEmpty {
                        Section("指标") {
                            ForEach(state.metrics.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                LabeledContent(key, value: String(format: "%.2f", value))
                            }
                        }
                    }
                }
            }
            .navigationTitle("节点详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { showNodeDetail = false }
                }
            }
        }
    }

    // MARK: - 颜色辅助

    private func nodeFillColor(_ status: String) -> Color {
        switch status {
        case "idle", "pending": return Color.gray.opacity(0.1)
        case "running": return Theme.statusRunning.opacity(0.1)
        case "success", "completed": return Theme.statusSuccess.opacity(0.1)
        case "error", "failed": return Theme.statusError.opacity(0.1)
        case "warning": return Theme.statusWarning.opacity(0.1)
        case "bypassed", "skipped": return Theme.statusBypassed.opacity(0.1)
        case "disabled": return Color.gray.opacity(0.05)
        default: return Color.gray.opacity(0.1)
        }
    }

    private func nodeStrokeColor(_ status: String) -> Color {
        switch status {
        case "idle", "pending": return Theme.statusIdle
        case "running": return Theme.statusRunning
        case "success", "completed": return Theme.statusSuccess
        case "error", "failed": return Theme.statusError
        case "warning": return Theme.statusWarning
        case "bypassed", "skipped": return Theme.statusBypassed
        case "disabled": return Theme.statusDisabled
        default: return Theme.textSecondary
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "idle": return "空闲"
        case "pending": return "等待"
        case "running": return "执行中"
        case "success", "completed": return "完成"
        case "error", "failed": return "失败"
        case "warning": return "警告"
        case "bypassed", "skipped": return "跳过"
        case "disabled": return "禁用"
        default: return status
        }
    }

    private func categoryColor(_ type: String) -> Color {
        switch type {
        case "ctx_world_rules", "ctx_facts": return Theme.info
        case "exec_outline", "exec_writer": return Theme.primary
        case "val_style", "val_tension", "val_anti_ai": return Theme.warning
        case "gateway_breaker": return Theme.error
        default: return Theme.textSecondary
        }
    }

    private func edgeColor(_ edge: SugiyamaLayout.PositionedEdge) -> Color {
        return Theme.textTertiary.opacity(0.5)
    }

    // MARK: - 控制按钮

    private func buttonIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
    }
}
