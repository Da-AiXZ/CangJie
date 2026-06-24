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

    /// 小说 ID（T04 新增，NodeDetailPanel/NodeContextMenu 需要）
    var novelId: String = ""

    /// 缩放
    @GestureState private var scale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 0.8

    /// 平移
    @GestureState private var offset: CGSize = .zero
    @State private var currentOffset: CGSize = .zero

    /// 选中的节点
    @State private var selectedNodeId: String?

    /// 节点详情弹窗 — 决策6：用 .sheet 呈现 NodeDetailPanel
    @State private var showNodeDetail = false

    /// 上下文菜单状态 — 决策7：自定义 overlay
    @State private var contextMenuState: ContextMenuState?

    /// 最后触摸位置（用于长按定位）
    @State private var lastTouchLocation: CGPoint = .zero

    /// 布局结果缓存
    @State private var layoutResult: SugiyamaLayout.LayoutResult?

    /// 动画相位（running 节点脉冲）
    @State private var pulsePhase: CGFloat = 0

    /// 上下文菜单状态结构
    struct ContextMenuState: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let nodeId: String
        let nodeEnabled: Bool
        let nodeType: String
    }

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
                // 追踪触摸位置（用于长按定位），不干扰其他手势
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if abs(value.translation.width) < 1 && abs(value.translation.height) < 1 {
                                lastTouchLocation = value.startLocation
                            }
                        }
                )
                .onTapGesture { location in
                    handleTap(at: location, in: geometry)
                }
                // 决策7：长按触发上下文菜单
                .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 12, perform: {
                    handleLongPress(in: geometry)
                })

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
            // 决策7：上下文菜单 overlay（自定义浮层）
            if let menuState = contextMenuState {
                NodeContextMenu(
                    x: menuState.x,
                    y: menuState.y,
                    nodeId: menuState.nodeId,
                    nodeEnabled: menuState.nodeEnabled,
                    nodeType: menuState.nodeType,
                    onDetail: { nodeId in
                        // 对齐 NodeContextMenu.vue:16 emit detail → 打开 NodeDetailPanel
                        selectedNodeId = nodeId
                        showNodeDetail = true
                    },
                    onToggle: { nodeId in
                        // 对齐 NodeContextMenu.vue:20 emit toggle → 调 dagStore.toggleNode
                        Task {
                            await dagStore.toggleNode(novelId: novelId, nodeId: nodeId)
                        }
                    },
                    onClose: {
                        contextMenuState = nil
                    }
                )
                .environmentObject(dagStore)
                .transition(.opacity)
                .zIndex(9999)
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
        // 决策6：用 .sheet 呈现 NodeDetailPanel，替换原有简单 nodeDetailSheet
        .sheet(isPresented: $showNodeDetail) {
            if let nodeId = selectedNodeId {
                NodeDetailPanel(novelId: novelId, nodeId: nodeId)
                    .environmentObject(dagStore)
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
            let path = roundRect.path(in: rect)

            // 填充色
            let fillColor = nodeFillColor(status)
            context.fill(path, with: .color(fillColor.opacity(0.15)))

            // 边框色
            let strokeColor = nodeStrokeColor(status)
            let borderWidth: CGFloat = status == "running" ? 2.5 + pulsePhase : 2
            context.stroke(
                roundRect.path(in: rect),
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: borderWidth, lineCap: .round)
            )

            // 顶部色条（分类色）
            let headerRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 4)
            let headerPath = RoundedRectangle(cornerRadius: 4).path(in: headerRect)
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
        // 关闭上下文菜单（如有）
        contextMenuState = nil

        // 命中测试
        if let node = hitTest(at: point) {
            selectedNodeId = node.id
            showNodeDetail = true
        }
    }

    // MARK: - 长按处理（决策7：触发上下文菜单）

    /// 长按节点 → 弹出 NodeContextMenu — 对齐 NodeContextMenu.vue 长按触发
    private func handleLongPress(in geometry: GeometryProxy) {
        // 使用最后触摸位置进行命中测试
        if let node = hitTest(at: lastTouchLocation) {
            let nodeDef = dagStore.nodes.first { $0.id == node.id }
            let nodeType = nodeDef?.type ?? ""
            let nodeEnabled = nodeDef?.enabled ?? true

            // 创建上下文菜单状态（对齐 NodeContextMenu.vue:61-68 menuStyle 定位）
            contextMenuState = ContextMenuState(
                x: lastTouchLocation.x,
                y: lastTouchLocation.y,
                nodeId: node.id,
                nodeEnabled: nodeEnabled,
                nodeType: nodeType
            )
        }
    }

    // MARK: - 命中测试

    /// 反变换坐标并命中测试节点
    private func hitTest(at point: CGPoint) -> SugiyamaLayout.PositionedNode? {
        guard let result = layoutResult else { return nil }

        let transformedX = (point.x - currentOffset.width - offset.width) / (currentScale * scale)
        let transformedY = (point.y - currentOffset.height - offset.height) / (currentScale * scale)

        for node in result.nodes {
            let dx = abs(transformedX - node.x)
            let dy = abs(transformedY - node.y)
            if dx < 70 && dy < 25 {
                return node
            }
        }
        return nil
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
