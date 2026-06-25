//
//  WorldlineDAGView.swift
//  Cangjie
//
//  世界线 Git 图：Canvas 绘制边/时间线/汇流曲线 + SwiftUI View 叠加节点卡片。
//  调真实 /worldline/graph API（WorldlineStore），不再用 SnapshotStore 伪造。
//  对齐原版 WorldlineDAG.vue:1-770。
//

import SwiftUI

/// 世界线 DAG 视图 — 对齐 WorldlineDAG.vue:1-770
struct WorldlineDAGView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = WorldlineStore()

    // MARK: - 布局常量 — WorldlineDAG.vue:358-363

    private let nodeW: CGFloat = 154
    private let nodeH: CGFloat = 68
    private let colW: CGFloat = 170
    private let rowH: CGFloat = 88
    private let topPad: CGFloat = 42
    private let leftPad: CGFloat = 66

    // MARK: - 颜色常量 — WorldlineDAG.vue:381-402

    private let branchColors: [Color] = [
        Color(red: 0.094, green: 0.565, blue: 1.0),    // #1890ff
        Color(red: 0.322, green: 0.769, blue: 0.102),  // #52c41a
        Color(red: 0.980, green: 0.549, blue: 0.086),  // #fa8c16
        Color(red: 0.447, green: 0.180, blue: 0.820),  // #722ed1
        Color(red: 0.922, green: 0.184, blue: 0.588),  // #eb2f96
        Color(red: 0.075, green: 0.760, blue: 0.788),  // #13c2c2
    ]

    private let triggerColors: [String: Color] = [
        "CHAPTER": Color(red: 0.094, green: 0.565, blue: 1.0),   // #1890ff
        "MANUAL": Color(red: 0.980, green: 0.549, blue: 0.086),  // #fa8c16
        "STASH": Color(red: 0.549, green: 0.549, blue: 0.549),   // #8c8c8c
        "PRE_RESET": Color(red: 0.961, green: 0.137, blue: 0.176), // #f5222d
        "ACT": Color(red: 0.322, green: 0.769, blue: 0.102),     // #52c41a
        "MILESTONE": Color(red: 0.447, green: 0.180, blue: 0.820), // #722ed1
        "AUTO": Color(red: 0.094, green: 0.565, blue: 1.0),      // #1890ff
        "MERGE": Color(red: 0.086, green: 0.639, blue: 0.290),   // #16a34a
    ]

    // MARK: - 缩放/平移

    @GestureState private var scale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 0.9
    @GestureState private var offset: CGSize = .zero
    @State private var currentOffset: CGSize = .zero

    // MARK: - 确认弹窗

    @State private var showHardResetConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var newBranchName: String = ""
    @State private var newBranchStorylineId: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if store.isLoading && store.nodes.isEmpty {
                loadingView
            } else if store.nodes.isEmpty {
                emptyView
            } else {
                dagContent
            }
        }
        .navigationTitle("世界线")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadAll(novelId: novelId)
            }
        }
        .alert("硬重置确认", isPresented: $showHardResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认重置", role: .destructive) {
                guard let novelId = appState.currentNovelId,
                      let cpId = store.selectedId else { return }
                Task { _ = await store.hardReset(novelId: novelId, checkpointId: cpId) }
            }
        } message: {
            Text("硬重置将删除此节点之后的所有存档，此操作不可撤销。确定要回滚到此切片吗？")
        }
        .alert("删除存档确认", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let novelId = appState.currentNovelId,
                      let cpId = store.selectedId else { return }
                Task { _ = await store.deleteCheckpoint(novelId: novelId, checkpointId: cpId) }
            }
        } message: {
            Text("删除后无法恢复，确定要删除此存档吗？")
        }
        .sheet(isPresented: $store.showBranchDialog) {
            branchNamingSheet
        }
    }

    // MARK: - Header — WorldlineDAG.vue:4-15

    private var headerBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("世界线版本图")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("\(store.nodes.count)存档·\(store.branchCount)分支·\(store.confluenceCount)汇流")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)

            Spacer()

            Button {
                if let novelId = appState.currentNovelId {
                    Task { await store.createManualCheckpoint(novelId: novelId) }
                }
            } label: {
                if store.isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                }
            }
            .disabled(store.isSaving)

            Button {
                if let novelId = appState.currentNovelId {
                    Task { await store.loadAll(novelId: novelId) }
                }
            } label: {
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
            }
            .disabled(store.isLoading)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 加载态 — WorldlineDAG.vue:17

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("加载世界线…")
            Spacer()
        }
    }

    // MARK: - 空状态 — WorldlineDAG.vue:19-24

    private var emptyView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: "git.branch")
                .font(.system(size: 40))
                .foregroundColor(Theme.textTertiary)
            Text("暂无世界线记录")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
            Text("章节完成后将自动生成")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
            Spacer()
        }
    }

    // MARK: - DAG+Detail 分栏 — WorldlineDAG.vue:27

    private var dagContent: some View {
        let layout = computeLayout()
        return HStack(spacing: 0) {
            // DAG 画布
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Canvas 画边/时间线/汇流曲线
                    Canvas { context, _ in
                        drawEdges(context: context, layout: layout)
                        drawTimeMarkers(context: context, layout: layout)
                        drawConfluenceCurves(context: context, layout: layout)
                        drawBranchLabels(context: context, layout: layout)
                    }
                    .frame(width: layout.viewW, height: layout.viewH)

                    // SwiftUI View 叠加节点卡片
                    ForEach(layout.nodePositions) { pos in
                        nodeCard(pos: pos)
                            .position(x: pos.x + nodeW / 2, y: pos.y + nodeH / 2)
                    }
                }
                .padding(Theme.Spacing.sm)
            }

            // Detail 面板
            detailPanel
                .frame(width: 240)
                .background(Theme.secondaryBackground)
        }
    }

    // MARK: - 布局算法 — WorldlineDAG.vue:428-564

    /// 布局计算结构
    struct NodePos: Identifiable {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let cx: CGFloat
        let cy: CGFloat
        let name: String
        let isHead: Bool
        let isSelected: Bool
        let color: Color
        let triggerType: String
        let createdAt: String
        let anchorChapter: Int?
        let branchName: String
        let chapterLabel: String
        let triggerShort: String
        let sliceLabel: String
        let assetLabel: String
        let rollbackLabel: String
    }

    struct EdgePos {
        let x1: CGFloat
        let y1: CGFloat
        let x2: CGFloat
        let y2: CGFloat
        let kind: String?
    }

    struct ColInfo {
        let cx: CGFloat
        let name: String
        let color: Color
    }

    struct TimeMarker {
        let y: CGFloat
        let label: String
    }

    struct ConfluencePos {
        let cx: CGFloat
        let cy: CGFloat
        let path: Path
        let label: String
        let resolved: Bool
        let sourceName: String
        let targetName: String
    }

    struct LayoutResult {
        let nodePositions: [NodePos]
        let edgePositions: [EdgePos]
        let branchCols: [ColInfo]
        let timeMarkers: [TimeMarker]
        let confluencePositions: [ConfluencePos]
        let viewW: CGFloat
        let viewH: CGFloat
    }

    /// 完整布局计算 — WorldlineDAG.vue:428-564
    private func computeLayout() -> LayoutResult {
        let allNodes = store.nodes
        let allEdges = store.edges
        let allBranches = store.branches
        let headId = store.headId

        // 分支列分配 — WorldlineDAG.vue:428-440
        var branchOrder: [String] = []
        for b in allBranches {
            if !branchOrder.contains(b.name) {
                branchOrder.append(b.name)
            }
        }
        // 补充节点中的分支名
        for n in allNodes {
            if !branchOrder.contains(n.branchName) {
                branchOrder.append(n.branchName)
            }
        }
        // 确保 main 在第一位
        if let mainIdx = branchOrder.firstIndex(of: "main"), mainIdx != 0 {
            branchOrder.swapAt(mainIdx, 0)
        }
        if branchOrder.isEmpty {
            branchOrder = ["main"]
        }

        // 节点排序（按章节时间）— WorldlineDAG.vue:443-448
        let sorted = allNodes.sorted { a, b in
            let aCh = a.anchorChapter ?? a.worldSlice?.chapterNumber ?? 0
            let bCh = b.anchorChapter ?? b.worldSlice?.chapterNumber ?? 0
            if aCh != bCh { return aCh < bCh }
            return a.createdAt < b.createdAt
        }

        // 节点Y坐标 — WorldlineDAG.vue:451-454
        var nodeY: [String: CGFloat] = [:]
        for (i, n) in sorted.enumerated() {
            nodeY[n.id] = topPad + CGFloat(i) * rowH
        }

        // ViewBox — WorldlineDAG.vue:457-458
        let totalCols = max(1, branchOrder.count)
        let viewW = leftPad + CGFloat(totalCols) * colW + 18
        let viewH = topPad + CGFloat(max(1, sorted.count)) * rowH + 28

        // 分支列信息 — WorldlineDAG.vue:460-464
        let branchCols: [ColInfo] = branchOrder.enumerated().map { (idx, name) in
            ColInfo(
                cx: leftPad + CGFloat(idx) * colW + nodeW / 2,
                name: name == "main" ? "主线" : name,
                color: branchColor(idx)
            )
        }

        // 节点位置 — WorldlineDAG.vue:467-501
        var nodePositions: [NodePos] = []
        var nodeById: [String: WorldlineCheckpointNode] = [:]
        for n in sorted {
            nodeById[n.id] = n
            let branchIdx = branchOrder.firstIndex(of: n.branchName) ?? 0
            let x = leftPad + CGFloat(branchIdx) * colW
            let y = nodeY[n.id] ?? topPad
            let cx = x + nodeW / 2
            let cy = y + nodeH / 2
            let isHead = (n.id == headId)
            let isSelected = (n.id == store.selectedId)
            let color = nodeColor(triggerType: n.triggerType, branchIdx: branchIdx)

            let chNum = n.anchorChapter ?? n.worldSlice?.chapterNumber
            let chapterLabel = chNum != nil ? "第\(chNum!)章" : "—"
            let triggerShort = triggerLabel(n.triggerType)
            let sliceLabel = n.worldSlice?.location ?? ""
            let charCount = n.worldSlice?.characters?.count ?? 0
            let itemCount = n.worldSlice?.items?.count ?? 0
            let assetLabel = "角色\(charCount)·物品\(itemCount)"
            let rollbackLabel = n.rollbackSlice != nil ? "回滚→第\(n.rollbackSlice!.toChapter)章" : ""

            nodePositions.append(NodePos(
                id: n.id, x: x, y: y, cx: cx, cy: cy,
                name: n.name, isHead: isHead, isSelected: isSelected,
                color: color, triggerType: n.triggerType,
                createdAt: n.createdAt, anchorChapter: chNum,
                branchName: n.branchName,
                chapterLabel: chapterLabel, triggerShort: triggerShort,
                sliceLabel: sliceLabel, assetLabel: assetLabel,
                rollbackLabel: rollbackLabel
            ))
        }

        // 边位置 — WorldlineDAG.vue:503-516
        let edgePositions: [EdgePos] = allEdges.compactMap { edge in
            guard let fromPos = nodePositions.first(where: { $0.id == edge.from }),
                  let toPos = nodePositions.first(where: { $0.id == edge.to }) else {
                return nil
            }
            return EdgePos(
                x1: fromPos.cx, y1: fromPos.y + nodeH,
                x2: toPos.cx, y2: toPos.y,
                kind: edge.kind
            )
        }

        // 时间标记 — WorldlineDAG.vue:518-535
        var seenChapters: Set<Int> = []
        var timeMarkers: [TimeMarker] = []
        for n in sorted {
            let ch = n.anchorChapter ?? n.worldSlice?.chapterNumber
            if let ch = ch, !seenChapters.contains(ch) {
                seenChapters.insert(ch)
                let y = nodeY[n.id] ?? topPad
                timeMarkers.append(TimeMarker(y: y, label: "第\(ch)章"))
            }
        }

        // 汇流点 — WorldlineDAG.vue:537-561
        let maxChapter = maxChapterCalc(sorted: sorted)
        let maxNodeY = topPad + CGFloat(max(0, sorted.count - 1)) * rowH
        let usableH = max(rowH, maxNodeY - topPad)

        /// 章节→Y坐标映射 — WorldlineDAG.vue:554-556 chapterToY
        func chapterToY(_ chapter: Int) -> CGFloat {
            let ratio: CGFloat
            if maxChapter > 1 {
                ratio = CGFloat(max(0, chapter - 1)) / CGFloat(maxChapter - 1)
            } else {
                ratio = 0
            }
            return topPad + ratio * usableH
        }

        /// storylineId→分支名映射 — WorldlineDAG.vue:620-623 storylineBranchName
        func storylineBranchName(_ storylineId: String?) -> String {
            guard let sid = storylineId, !sid.isEmpty else { return "main" }
            // 先从 branches 查 storyline_id
            if let b = allBranches.first(where: { $0.storylineId == sid }) {
                return b.name
            }
            // 再从 storylines 查 role == "main"
            if let sl = store.storylines.first(where: { $0.id == sid }), isMainStoryline(sl) {
                return "main"
            }
            return "main"
        }

        /// storylineId→显示名映射
        func storylineDisplayName(_ storylineId: String?) -> String {
            guard let sid = storylineId, !sid.isEmpty else { return "主线" }
            if let sl = store.storylines.first(where: { $0.id == sid }) {
                return sl.name ?? sid.prefix(8).description
            }
            return sid.prefix(8).description
        }

        let confluencePositions: [ConfluencePos] = store.confluencePoints.enumerated().map { (idx, cp) in
            // source→target 分支列映射 — WorldlineDAG.vue:546-549
            let sourceBranchName = storylineBranchName(cp.sourceStorylineId)
            let targetBranchName = storylineBranchName(cp.targetStorylineId)
            let sourceBranchIdx = branchOrder.firstIndex(of: sourceBranchName) ?? 0
            let targetBranchIdx = branchOrder.firstIndex(of: targetBranchName) ?? 0
            let sourceCx = leftPad + CGFloat(sourceBranchIdx) * colW + nodeW / 2
            let targetCx = leftPad + CGFloat(targetBranchIdx) * colW + nodeW / 2
            let cy = chapterToY(cp.targetChapter)

            // 重叠偏移 — WorldlineDAG.vue:559 (index % 3) * 10
            let offset: CGFloat = CGFloat(idx % 3) * 10

            // 贝塞尔曲线: source分支列 → target分支列 — WorldlineDAG.vue:550-553
            var path = Path()
            path.move(to: CGPoint(x: sourceCx, y: cy))
            let midX = (sourceCx + targetCx) / 2
            path.addCurve(
                to: CGPoint(x: targetCx + offset, y: cy - 20),
                control1: CGPoint(x: midX, y: cy),
                control2: CGPoint(x: midX + offset, y: cy - 20)
            )

            // label: "Ch.N mergeType" — WorldlineDAG.vue:557-558
            let label = "Ch.\(cp.targetChapter) \(getConfluenceLabel(cp.mergeType))"

            return ConfluencePos(
                cx: targetCx + offset, cy: cy - 20,
                path: path,
                label: label,
                resolved: cp.resolved,
                sourceName: storylineDisplayName(cp.sourceStorylineId),
                targetName: storylineDisplayName(cp.targetStorylineId)
            )
        }

        return LayoutResult(
            nodePositions: nodePositions,
            edgePositions: edgePositions,
            branchCols: branchCols,
            timeMarkers: timeMarkers,
            confluencePositions: confluencePositions,
            viewW: viewW, viewH: viewH
        )
    }

    // MARK: - Canvas 绘制

    /// 绘制边 — WorldlineDAG.vue:65-73, 503-516
    private func drawEdges(context: GraphicsContext, layout: LayoutResult) {
        for edge in layout.edgePositions {
            var path = Path()
            path.move(to: CGPoint(x: edge.x1, y: edge.y1))
            let midY = (edge.y1 + edge.y2) / 2
            path.addCurve(
                to: CGPoint(x: edge.x2, y: edge.y2),
                control1: CGPoint(x: edge.x1, y: midY),
                control2: CGPoint(x: edge.x2, y: midY)
            )
            let isMerge = edge.kind == "merge"
            let color = isMerge ? Color(red: 0.086, green: 0.639, blue: 0.290) : Theme.textTertiary.opacity(0.4)
            let width: CGFloat = isMerge ? 2 : 1
            let style = StrokeStyle(lineWidth: width, dash: isMerge ? [] : [3, 3])
            context.stroke(path, with: .color(color), style: style)
        }
    }

    /// 绘制时间标记线 — WorldlineDAG.vue:48-63, 518-535
    private func drawTimeMarkers(context: GraphicsContext, layout: LayoutResult) {
        for marker in layout.timeMarkers {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: marker.y))
            path.addLine(to: CGPoint(x: layout.viewW, y: marker.y))
            context.stroke(path, with: .color(Theme.textTertiary.opacity(0.15)),
                          style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            context.draw(
                Text(marker.label)
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary),
                at: CGPoint(x: 4, y: marker.y - 8)
            )
        }
    }

    /// 绘制汇流贝塞尔曲线 — WorldlineDAG.vue:75-95, 537-561
    private func drawConfluenceCurves(context: GraphicsContext, layout: LayoutResult) {
        for cp in layout.confluencePositions {
            let color = cp.resolved
                ? Color(red: 0.322, green: 0.769, blue: 0.102).opacity(0.5)
                : Color(red: 0.980, green: 0.549, blue: 0.086).opacity(0.5)
            context.stroke(cp.path, with: .color(color),
                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            // 汇流点标记
            let rect = CGRect(x: cp.cx - 9, y: cp.cy - 9, width: 18, height: 18)
            context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(color.opacity(0.2)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 5), with: .color(color), lineWidth: 1)
            context.draw(
                Text(cp.label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(color),
                at: CGPoint(x: cp.cx, y: cp.cy)
            )
        }
    }

    /// 绘制分支列标签 — WorldlineDAG.vue:37-45, 460-464
    private func drawBranchLabels(context: GraphicsContext, layout: LayoutResult) {
        for col in layout.branchCols {
            // 分支竖线
            var path = Path()
            path.move(to: CGPoint(x: col.cx, y: topPad - 10))
            path.addLine(to: CGPoint(x: col.cx, y: layout.viewH - 10))
            context.stroke(path, with: .color(col.color.opacity(0.08)), lineWidth: colW - 8)

            // 标签
            context.draw(
                Text(col.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(col.color),
                at: CGPoint(x: col.cx, y: topPad - 20)
            )
        }
    }

    // MARK: - 节点卡片 — WorldlineDAG.vue:97-152

    private func nodeCard(pos: NodePos) -> some View {
        VStack(spacing: 0) {
            // accent 条 — WorldlineDAG.vue:112-114
            Rectangle()
                .fill(pos.color)
                .frame(width: nodeW, height: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(pos.chapterLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(pos.color)
                    Text(pos.triggerShort)
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    if pos.isHead {
                        Text("HEAD")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(pos.color)
                            .cornerRadius(3)
                    }
                }

                Text(compact(pos.name, max: 18))
                    .font(.system(size: 11, weight: pos.isHead ? .bold : .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                if !pos.sliceLabel.isEmpty {
                    Text(compact(pos.sliceLabel, max: 22))
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }

                Text(pos.assetLabel)
                    .font(.system(size: 8))
                    .foregroundColor(Theme.textTertiary)

                if !pos.rollbackLabel.isEmpty {
                    Text(pos.rollbackLabel)
                        .font(.system(size: 8))
                        .foregroundColor(Color(red: 0.961, green: 0.137, blue: 0.176))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: nodeW, height: nodeH - 4, alignment: .topLeading)
        }
        .frame(width: nodeW, height: nodeH)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(pos.isSelected ? pos.color.opacity(0.1) : Theme.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pos.color, lineWidth: pos.isSelected ? 2.5 : 1)
        )
        .onTapGesture {
            store.selectNode(pos.id)
        }
    }

    // MARK: - Detail 面板 — WorldlineDAG.vue:157-274

    private var detailPanel: some View {
        Group {
            if let node = store.selectedNode {
                selectedNodeDetail(node: node)
            } else {
                emptyDetailPanel
            }
        }
    }

    /// 选中节点详情 — WorldlineDAG.vue:157-262
    private func selectedNodeDetail(node: WorldlineCheckpointNode) -> some View {
        let branchInfo = store.branches.first { $0.name == node.branchName }
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // 触发类型标签 — WorldlineDAG.vue:159-161
                Text(triggerLabel(node.triggerType))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(triggerTagColor(node.triggerType))
                    .cornerRadius(10)

                // 节点名称 — WorldlineDAG.vue:162-164
                Text(node.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)

                // 时间+章节+分支 — WorldlineDAG.vue:166-174
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatTime(node.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                    if let ch = node.anchorChapter {
                        Text("第\(ch)章")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Text("分支: \(node.branchName == "main" ? "主线" : node.branchName)")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }

                // world_slice 网格 — WorldlineDAG.vue:175-202
                if let slice = node.worldSlice {
                    worldSliceGrid(slice: slice)
                }

                Divider()

                // 操作按钮 — WorldlineDAG.vue:206-260
                // 汇入主线（非main分支）— WorldlineDAG.vue:206-216
                if node.branchName != "main", let branch = branchInfo {
                    actionButton(
                        title: "汇入主线",
                        icon: "arrow.merge",
                        color: Theme.success,
                        loading: store.actionLoading == "merge"
                    ) {
                        Task { _ = await store.mergeBranch(novelId: appState.currentNovelId ?? "", branchId: branch.id, branchName: node.branchName) }
                    }
                }

                // 切换到此切片（checkout）— WorldlineDAG.vue:218-227
                actionButton(
                    title: "切换到此切片",
                    icon: "arrow.triangle.swap",
                    color: Theme.primary,
                    loading: store.actionLoading == "checkout"
                ) {
                    Task { _ = await store.checkout(novelId: appState.currentNovelId ?? "", checkpointId: node.id) }
                }

                // 从此分叉（createBranch）— WorldlineDAG.vue:229-237
                actionButton(
                    title: "从此分叉新支线",
                    icon: "git.branch",
                    color: Theme.info,
                    loading: false
                ) {
                    newBranchName = ""
                    newBranchStorylineId = nil
                    store.showBranchDialog = true
                }

                // 回滚到此切片（hardReset）— WorldlineDAG.vue:239-249
                actionButton(
                    title: "回滚到此切片",
                    icon: "arrow.uturn.backward",
                    color: Theme.error,
                    loading: store.actionLoading == "hard-reset"
                ) {
                    showHardResetConfirm = true
                }

                // 删除存档 — WorldlineDAG.vue:251-260
                actionButton(
                    title: "删除存档",
                    icon: "trash",
                    color: Theme.error,
                    loading: store.actionLoading == "delete"
                ) {
                    showDeleteConfirm = true
                }
            }
            .padding(Theme.Spacing.sm)
        }
    }

    /// world_slice 网格 — WorldlineDAG.vue:175-202
    private func worldSliceGrid(slice: WorldSlice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("世界切片")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            if let time = slice.timeAnchor, !time.isEmpty {
                sliceRow(label: "时间", value: time)
            }
            if let loc = slice.location, !loc.isEmpty {
                sliceRow(label: "地点", value: loc)
            }
            if let residue = slice.emotionalResidue, !residue.isEmpty {
                sliceRow(label: "情绪", value: residue)
            }
            if let chars = slice.characters, !chars.isEmpty {
                sliceRow(label: "角色", value: "\(chars.count)人")
                let preview = chars.prefix(4).map { $0.name }.joined(separator: "·")
                if !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 9))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                }
            }
            if let items = slice.items, !items.isEmpty {
                sliceRow(label: "物品", value: "\(items.count)件")
            }
        }
    }

    private func sliceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 30, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
            Spacer()
        }
    }

    /// 空详情面板 — WorldlineDAG.vue:263-274
    private var emptyDetailPanel: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: "hand.tap")
                .font(.system(size: 24))
                .foregroundColor(Theme.textTertiary)
            Text("点击存档查看操作")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)

            // 计划汇流列表 — WorldlineDAG.vue:268-273
            if !store.confluencePoints.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                Text("计划汇流")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                ForEach(store.confluencePoints.prefix(5)) { cp in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cp.resolved ? Theme.success : Theme.warning)
                            .frame(width: 6, height: 6)
                        Text("第\(cp.targetChapter)章")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                        Text("\(storylineDisplayName(cp.sourceStorylineId))→\(storylineDisplayName(cp.targetStorylineId))")
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                        Text(getConfluenceLabel(cp.mergeType))
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                    }
                }
            }
            Spacer()
        }
        .padding(Theme.Spacing.sm)
    }

    // MARK: - 分支命名 Sheet — WorldlineDAG.vue:278-293

    private var branchNamingSheet: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("从此节点分叉新支线")
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text("支线名称")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                TextField("输入支线名称", text: $newBranchName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("绑定故事线（可选）")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                Picker("故事线", selection: $newBranchStorylineId) {
                    Text("不绑定").tag(String?.none)
                    ForEach(store.storylines) { sl in
                        Text(sl.name ?? sl.id.prefix(8).description)
                            .tag(Optional(sl.id))
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button("取消") {
                    store.showBranchDialog = false
                }
                Spacer()
                Button("创建分支") {
                    guard let novelId = appState.currentNovelId,
                          let cpId = store.selectedId,
                          !newBranchName.isEmpty else { return }
                    Task {
                        _ = await store.createBranch(
                            novelId: novelId,
                            fromCheckpointId: cpId,
                            name: newBranchName,
                            storylineId: newBranchStorylineId
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newBranchName.isEmpty)
            }
        }
        .padding(Theme.Spacing.lg)
        .presentationDetents([.medium])
    }

    // MARK: - 操作按钮

    private func actionButton(title: String, icon: String, color: Color, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.08))
            .foregroundColor(color)
            .cornerRadius(6)
        }
        .disabled(loading)
    }

    // MARK: - 辅助函数 — WorldlineDAG.vue:381-631

    /// 分支颜色 — WorldlineDAG.vue:381-388
    private func branchColor(_ idx: Int) -> Color {
        return branchColors[idx % branchColors.count]
    }

    /// 节点颜色 — WorldlineDAG.vue:393-402
    private func nodeColor(triggerType: String, branchIdx: Int) -> Color {
        if triggerType == "STASH" || triggerType == "PRE_RESET" {
            return triggerColors[triggerType] ?? branchColor(branchIdx)
        }
        return branchColor(branchIdx)
    }

    /// 触发类型中文 — WorldlineDAG.vue:605-611
    private func triggerLabel(_ type: String) -> String {
        switch type {
        case "CHAPTER": return "章节"
        case "MANUAL": return "手动"
        case "STASH": return "暂存"
        case "PRE_RESET": return "重置前"
        case "ACT": return "幕"
        case "MILESTONE": return "里程碑"
        case "AUTO": return "自动"
        case "MERGE": return "汇流"
        default: return type
        }
    }

    /// 触发类型标签颜色 — WorldlineDAG.vue:625-631
    private func triggerTagColor(_ type: String) -> Color {
        switch type {
        case "CHAPTER": return Theme.info
        case "MANUAL": return Theme.warning
        case "STASH": return Theme.textTertiary
        case "PRE_RESET": return Theme.error
        case "ACT": return Theme.success
        case "MILESTONE": return Theme.warning
        case "AUTO": return Theme.info
        case "MERGE": return Theme.success
        default: return Theme.textTertiary
        }
    }

    /// storylineId→显示名映射（View级别，供 emptyDetailPanel 使用）
    private func storylineDisplayName(_ storylineId: String?) -> String {
        guard let sid = storylineId, !sid.isEmpty else { return "主线" }
        if let sl = store.storylines.first(where: { $0.id == sid }) {
            return sl.name ?? sid.prefix(8).description
        }
        return sid.prefix(8).description
    }

    /// 最大章节 — WorldlineDAG.vue:537-541
    private func maxChapterCalc(sorted: [WorldlineCheckpointNode]) -> Int {
        var maxCh = 1
        for n in sorted {
            if let ch = n.anchorChapter ?? n.worldSlice?.chapterNumber, ch > maxCh {
                maxCh = ch
            }
        }
        for cp in store.confluencePoints {
            if cp.targetChapter > maxCh {
                maxCh = cp.targetChapter
            }
        }
        return maxCh
    }

    /// 文本截断 — WorldlineDAG.vue:408-411
    private func compact(_ value: String, max: Int) -> String {
        if value.count > max {
            return String(value.prefix(max - 1)) + "…"
        }
        return value
    }

    /// 相对时间 — WorldlineDAG.vue:589-603
    private func formatTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: isoString) ?? Date()

        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))天前"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MM-dd HH:mm"
            return df.string(from: date)
        }
    }
}
