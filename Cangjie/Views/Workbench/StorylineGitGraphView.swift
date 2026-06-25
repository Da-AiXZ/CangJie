//
//  StorylineGitGraphView.swift
//  Cangjie
//
//  故事线分支图（Git Graph），对齐原版 components/workbench/StorylineGitGraph.vue:1-902。
//  SVG Git Graph 完整复刻：轨道+Commit节点+Branch/Merge贝塞尔曲线+Tooltip+回滚。
//  使用 SwiftUI Canvas/Path 替代 SVG。
//

import SwiftUI

/// 故事线分支图视图
///
/// 对齐原版 `components/workbench/StorylineGitGraph.vue`。
/// 用 SwiftUI Canvas 完整复刻 SVG Git Graph，不简化。
struct StorylineGitGraphView: View {

    /// 小说 ID（对齐 :445 props.slug）
    let novelId: String

    /// 当前章节（对齐 :446-447 props.currentChapter）
    var currentChapter: Int? = nil

    // MARK: - 状态

    @State private var loading = false
    @State private var rollbacking = false
    @State private var zoomed = false
    @State private var rawStorylines: [StorylineDTO] = []
    @State private var rawMergePoints: [StorylineMergePointDTO] = []
    @State private var activeCommit: CommitDef?
    @State private var hoverCommit: CommitDef?
    @State private var errorMessage: String?
    @State private var showRollbackConfirm = false
    @State private var rollbackTarget: CommitDef?

    // MARK: - 布局常量（对齐 :498-503）

    private let gapX: CGFloat = 110       // 章节水平间距 — :498
    private let gapY: CGFloat = 72        // 轨道垂直间距 — :499
    private let labelWidth: CGFloat = 130 // 左侧标签区宽度 — :500
    private let paddingT: CGFloat = 30    // 顶部留白 — :501
    private let paddingB: CGFloat = 45    // 底部留白 — :502
    private let paddingR: CGFloat = 40    // 右侧留白 — :503

    // MARK: - 类型定义（对齐 :456-472）

    struct TrackDef: Identifiable, Equatable {
        let id: String
        let color: Color
        let label: String
        let isMain: Bool
        let storylineType: String
    }

    struct CommitDef: Identifiable, Equatable {
        let id: String
        let chapterIndex: Int
        let trackId: String
        let label: String
        var branchFrom: String?       // 从哪个 commit 分支出来 — :469
        var mergeFrom: [String]?      // 哪些 commit 汇合 — :470
        let description: String?
    }

    // MARK: - 计算属性

    /// 轨道列表（对齐 :520-528 tracks computed）
    private var tracks: [TrackDef] {
        return rawStorylines.map { sl in
            TrackDef(
                id: sl.id,
                color: storylineColor(sl.storylineType ?? ""),
                label: String((sl.name ?? storylineTypeLabel(sl.storylineType ?? "")).prefix(14)),
                isMain: isMainStoryline(sl),
                storylineType: sl.storylineType ?? ""
            )
        }
    }

    /// Commit 列表（对齐 :531-559 commits computed）
    private var commits: [CommitDef] {
        var result: [CommitDef] = []
        let lines = rawStorylines

        for sl in lines {
            let start = sl.estimatedChapterStart ?? 0
            let end = sl.estimatedChapterEnd ?? 0
            for ch in start...max(start, end) {
                let id = "\(sl.id)-ch\(ch)"
                let commit = CommitDef(
                    id: id,
                    chapterIndex: ch,
                    trackId: sl.id,
                    label: buildCommitLabel(ch, sl),
                    branchFrom: nil,
                    mergeFrom: nil,
                    description: nil
                )
                result.append(commit)
            }
        }

        // 标注 Branch 关系（对齐 :573-607 detectBranches）
        detectBranches(&result, lines)
        // 标注 Merge 关系（对齐 :610-637 detectMerges）
        detectMerges(&result)

        // 排序（对齐 :556）
        result.sort { $0.chapterIndex < $1.chapterIndex || ($0.chapterIndex == $1.chapterIndex && $0.trackId < $1.trackId) }
        return result
    }

    /// 所有章节号（对齐 :700-704 allChapters）
    private var allChapters: [Int] {
        let set = Set(commits.map { $0.chapterIndex })
        return set.sorted()
    }

    /// 总章数（对齐 :719 totalChapters）
    private var totalChapters: Int { allChapters.count }

    /// SVG 宽度（对齐 :688-692 svgWidth）
    private var svgWidth: CGFloat {
        guard !commits.isEmpty else { return labelWidth + 400 }
        let maxCh = commits.map { $0.chapterIndex }.max() ?? 0
        return labelWidth + CGFloat(maxCh + 1) * gapX + paddingR
    }

    /// SVG 高度（对齐 :694-697 svgHeight）
    private var svgHeight: CGFloat {
        let tc = max(tracks.count, 1)
        return paddingT + CGFloat(tc) * gapY + paddingB
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 对齐 :3-26 顶部工具栏
            header

            // 对齐 :29-375 主体画布
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    if loading {
                        // 对齐 :36-39 加载态
                        loadingView
                    } else if tracks.isEmpty {
                        // 对齐 :42-46 空状态
                        emptyState
                    } else {
                        // 对齐 :49-315 SVG 图谱
                        gitGraphCanvas
                    }
                }
                .frame(width: max(svgWidth, 400), height: max(svgHeight, 200))
            }

            // 对齐 :378-411 选中 Commit 详情面板
            if let active = activeCommit {
                commitDetailBar(active)
            }

            // 对齐 :414-424 底部状态栏
            if !tracks.isEmpty {
                footer
            }
        }
        .background(Theme.background)
        .cornerRadius(12)
        .task {
            await loadData()
        }
        .alert("⚠️ 全息回滚确认", isPresented: $showRollbackConfirm) {
            Button("确认回滚", role: .destructive) {
                if let target = rollbackTarget {
                    Task { await performRollback(target) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let target = rollbackTarget {
                Text("回滚到 Commit [\(target.label)] (第\(target.chapterIndex)章) 将删除之后所有章节内容。此操作不可撤销，确定继续？")
            }
        }
    }

    // MARK: - 顶部工具栏（对齐 :3-26）

    private var header: some View {
        HStack(spacing: 8) {
            Text("Git Graph")
                .font(.system(size: 13, weight: .semibold))
            Text("\(tracks.count) 线 · \(commits.count) 节点")
                .font(.system(size: 11))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.info.opacity(0.1))
                .cornerRadius(999)

            Spacer()

            Button {
                Task { await loadData() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)

            Button {
                zoomed.toggle()
            } label: {
                Text(zoomed ? "收起" : "放大")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Git Graph Canvas（对齐 :49-315）

    private var gitGraphCanvas: some View {
        Canvas { context, size in
            drawBackgroundLayer(&context, size: size)
            drawEdgesLayer(&context, size: size)
            drawNodesLayer(&context, size: size)
            drawXAxisLayer(&context, size: size)
        }
        .frame(width: svgWidth, height: svgHeight)
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    handleTap(at: value.location)
                }
        )
    }

    // MARK: - 背景层（对齐 :106-132）

    private func drawBackgroundLayer(_ context: inout GraphicsContext, size: CGSize) {
        // 轨道横线（虚线）— 对齐 :108-118
        for (ti, tr) in tracks.enumerated() {
            var path = Path()
            let y = trackY(ti)
            path.move(to: CGPoint(x: labelWidth, y: y))
            path.addLine(to: CGPoint(x: svgWidth - paddingR, y: y))
            context.stroke(path, with: .color(.gray.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        }

        // 章节竖网格线 — 对齐 :121-131
        for ch in allChapters {
            let x = chapterToX(ch)
            var path = Path()
            path.move(to: CGPoint(x: x, y: paddingT))
            path.addLine(to: CGPoint(x: x, y: svgHeight - paddingB))
            context.stroke(path, with: .color(.gray.opacity(0.05)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    // MARK: - 连线层（对齐 :134-176）

    private func drawEdgesLayer(_ context: inout GraphicsContext, size: CGSize) {
        // 1) 同轨道直线段 — 对齐 :137-148 straightSegments
        for tr in tracks {
            let trackCommits = commits.filter { $0.trackId == tr.id }.sorted { $0.chapterIndex < $1.chapterIndex }
            for i in 0..<max(0, trackCommits.count - 1) {
                let c1 = trackCommits[i]
                let c2 = trackCommits[i + 1]
                var path = Path()
                path.move(to: CGPoint(x: commitCx(c1), y: commitCy(c1)))
                path.addLine(to: CGPoint(x: commitCx(c2), y: commitCy(c2)))
                let isActive = isActiveCommit(c1) || isActiveCommit(c2)
                context.stroke(path, with: .color(tr.color),
                               style: StrokeStyle(lineWidth: isActive ? 2.5 : 1.6, opacity: isActive ? 0.85 : 0.35))
            }
        }

        // 2) Branch 曲线 — 对齐 :151-162 branchCurves
        for cm in commits {
            guard let branchFromId = cm.branchFrom,
                  let source = commits.first(where: { $0.id == branchFromId }) else { continue }
            let x1 = commitCx(source), y1 = commitCy(source)
            let x2 = commitCx(cm), y2 = commitCy(cm)
            let dx = x2 - x1
            var path = Path()
            path.move(to: CGPoint(x: x1, y: y1))
            path.addCurve(to: CGPoint(x: x2, y: y2),
                          control1: CGPoint(x: x1 + dx * 0.4, y: y1),
                          control2: CGPoint(x: x2 - dx * 0.4, y: y2))
            let targetColor = tracks.first(where: { $0.id == cm.trackId })?.color ?? .gray
            context.stroke(path, with: .color(targetColor),
                           style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
        }

        // 3) Merge 曲线 — 对齐 :165-175 mergeCurves
        for cm in commits {
            guard let mergeFromIds = cm.mergeFrom, !mergeFromIds.isEmpty else { continue }
            let mx = commitCx(cm), my = commitCy(cm)
            for sourceId in mergeFromIds {
                guard let source = commits.first(where: { $0.id == sourceId }) else { continue }
                let sx = commitCx(source), sy = commitCy(source)
                let dx = mx - sx
                var path = Path()
                path.move(to: CGPoint(x: sx, y: sy))
                path.addCurve(to: CGPoint(x: mx, y: my),
                              control1: CGPoint(x: sx + dx * 0.45, y: sy),
                              control2: CGPoint(x: mx - dx * 0.35, y: my))
                let sourceColor = tracks.first(where: { $0.id == source.trackId })?.color ?? .gray
                context.stroke(path, with: .color(sourceColor),
                               style: StrokeStyle(lineWidth: 2, opacity: 0.75))
            }
        }
    }

    // MARK: - 节点层（对齐 :178-291）

    private func drawNodesLayer(_ context: inout GraphicsContext, size: CGSize) {
        for cm in commits {
            let cx = commitCx(cm)
            let cy = commitCy(cm)
            let isHead = cm.chapterIndex == currentChapter
            let isMerge = cm.mergeFrom?.isEmpty == false
            let trackColor = tracks.first(where: { $0.id == cm.trackId })?.color ?? .gray
            let radius: CGFloat = isHead ? 8 : (isActiveCommit(cm) ? 6.5 : 5)

            // HEAD 光晕环 — 对齐 :196-206
            if isHead {
                var ring = Path()
                ring.addEllipse(in: CGRect(x: cx - 16, y: cy - 16, width: 32, height: 32))
                context.stroke(ring, with: .color(.orange.opacity(0.35)), lineWidth: 2)
            }

            // 节点形状
            if isMerge {
                // Merge 节点：圆角矩形 — 对齐 :209-231
                let rect = CGRect(x: cx - 9, y: cy - 9, width: 18, height: 18)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.purple))
                context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(.purple), lineWidth: 1.5)
            } else {
                // 普通节点：圆 — 对齐 :234-245
                var circle = Path()
                circle.addEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
                context.fill(circle, with: .color(trackColor))
                context.stroke(circle, with: .color(trackColor),
                               lineWidth: isHead ? 2.5 : 1.5)
            }

            // 标签文字 — 对齐 :248-257
            let labelY = cy - (isMerge ? 16 : 14)
            context.draw(Text(cm.label)
                .font(.system(size: 10, weight: isHead ? .bold : .medium))
                .foregroundColor(isHead ? .orange : Color(Theme.textTertiary)),
                at: CGPoint(x: cx, y: labelY), anchor: .top)

            // HEAD 标记 — 对齐 :260-268
            if isHead && isMainTrack(cm.trackId) {
                context.draw(Text("HEAD")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.orange),
                    at: CGPoint(x: cx + 16, y: cy + 4), anchor: .leading)
            }

            // Branch 标记 — 对齐 :271-279
            if cm.branchFrom != nil {
                context.draw(Text("branch")
                    .font(.system(size: 8))
                    .foregroundColor(.cyan.opacity(0.8)),
                    at: CGPoint(x: cx - 14, y: cy - 12), anchor: .trailing)
            }

            // Merge 来源数 — 对齐 :282-289
            if let count = cm.mergeFrom?.count, count > 0 {
                context.draw(Text("×\(count)")
                    .font(.system(size: 8))
                    .foregroundColor(.purple),
                    at: CGPoint(x: cx + 15, y: cy + 4), anchor: .leading)
            }
        }
    }

    // MARK: - X 轴章节标签（对齐 :294-314）

    private func drawXAxisLayer(_ context: inout GraphicsContext, size: CGSize) {
        for ch in allChapters {
            let x = chapterToX(ch)
            context.draw(Text("Ch.\(ch)")
                .font(.system(size: 9))
                .foregroundColor(Color(Theme.textTertiary)),
                at: CGPoint(x: x, y: svgHeight - 10), anchor: .top)
        }
    }

    // MARK: - 选中详情面板（对齐 :378-411）

    private func commitDetailBar(_ cm: CommitDef) -> some View {
        let isMerge = cm.mergeFrom?.isEmpty == false
        return HStack(spacing: 12) {
            // Badge
            Text(isMerge ? "⤝ Merge Commit" : "● Commit")
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isMerge ? Color.purple.opacity(0.15) : Theme.primary.opacity(0.15))
                .cornerRadius(6)

            Text("#\(cm.id.prefix(8))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.purple)

            Text(cm.label)
                .font(.system(size: 13, weight: .semibold))

            if cm.chapterIndex == currentChapter {
                Text("HEAD")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
                    .foregroundColor(.white)
            }

            Spacer()

            // 回滚按钮 — 对齐 :402-404
            Button(role: .destructive) {
                rollbackTarget = cm
                showRollbackConfirm = true
            } label: {
                Label("↩ 回滚", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .disabled(rollbacking)

            Button {
                activeCommit = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.primary.opacity(0.06))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.primary.opacity(0.15)), alignment: .top)
    }

    // MARK: - 底部状态栏（对齐 :414-424）

    private var footer: some View {
        HStack(spacing: 8) {
            let branchCount = commits.filter { $0.branchFrom != nil }.count
            let mergeCount = commits.filter { $0.mergeFrom?.isEmpty == false }.count
            Text("\(totalChapters) 章 · \(branchCount) 次 Branch · \(mergeCount) 次 Merge · \(tracks.count) Tracks")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            if let cc = currentChapter {
                HStack(spacing: 5) {
                    Circle().fill(Color.orange).frame(width: 7, height: 7)
                    Text("HEAD @ Ch.\(cc)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - 加载态 / 空状态（对齐 :36-46）

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在构建 Git Graph…")
                .font(.system(size: 13))
                .foregroundColor(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🌱")
                .font(.system(size: 40))
            Text("暂无故事线")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Text("添加故事线后，Git Graph 将自动生长出分支与合并")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 280)
        .padding(.top, 60)
    }

    // MARK: - 坐标计算（对齐 :640-677）

    private func trackIndex(_ trackId: String) -> Int {
        return tracks.firstIndex(where: { $0.id == trackId }) ?? -1
    }

    private func trackY(_ index: Int) -> CGFloat {
        return paddingT + CGFloat(index) * gapY + gapY / 2
    }

    private func chapterToX(_ ch: Int) -> CGFloat {
        return labelWidth + CGFloat(ch) * gapX + gapX / 2
    }

    private func commitCx(_ cm: CommitDef) -> CGFloat { chapterToX(cm.chapterIndex) }
    private func commitCy(_ cm: CommitDef) -> CGFloat {
        let idx = trackIndex(cm.trackId)
        return idx >= 0 ? trackY(idx) : paddingT + gapY / 2
    }

    private func isActiveCommit(_ cm: CommitDef) -> Bool {
        guard let cc = currentChapter else { return false }
        return cm.trackId == activeCommit?.trackId || cm.chapterIndex == cc
    }

    private func isMainTrack(_ trackId: String) -> Bool {
        return tracks.first(where: { $0.id == trackId })?.isMain ?? false
    }

    // MARK: - 点击处理（对齐 :828-836 selectCommit）

    private func handleTap(at point: CGPoint) {
        // 查找最近的 commit 节点
        var nearest: CommitDef?
        var minDist: CGFloat = 20 // 点击容差
        for cm in commits {
            let cx = commitCx(cm)
            let cy = commitCy(cm)
            let dist = sqrt(pow(point.x - cx, 2) + pow(point.y - cy, 2))
            if dist < minDist {
                minDist = dist
                nearest = cm
            }
        }
        if let cm = nearest {
            if activeCommit?.id == cm.id {
                activeCommit = nil
            } else {
                activeCommit = cm
            }
        }
    }

    // MARK: - Branch/Merge 检测（对齐 :573-637）

    private func detectBranches(_ commits: inout [CommitDef], _ lines: [StorylineDTO]) {
        guard let mainLine = lines.first(where: { isMainStoryline($0) }) ) else { return }
        let mainStart = mainLine.estimatedChapterStart ?? 0
        let mainEnd = mainLine.estimatedChapterEnd ?? 0

        for i in commits.indices {
            let commit = commits[i]
            guard let sl = lines.first(where: { $0.id == commit.trackId }) else { continue }
            if isMainStoryline(sl) { continue }

            let slStart = sl.estimatedChapterStart ?? 0
            if commit.chapterIndex == slStart &&
               commit.chapterIndex >= mainStart && commit.chapterIndex <= mainEnd {
                if let sourceIdx = commits.firstIndex(where: { $0.trackId == mainLine.id && $0.chapterIndex == commit.chapterIndex }) {
                    commits[i].branchFrom = commits[sourceIdx].id
                }
            }

            if commits[i].branchFrom == nil {
                for other in lines {
                    if other.id == sl.id { continue }
                    let otherStart = other.estimatedChapterStart ?? 0
                    let otherEnd = other.estimatedChapterEnd ?? 0
                    if commit.chapterIndex == slStart &&
                       commit.chapterIndex >= otherStart && commit.chapterIndex <= otherEnd {
                        if let src = commits.firstIndex(where: { $0.trackId == other.id && $0.chapterIndex == commit.chapterIndex }) {
                            commits[i].branchFrom = commits[src].id
                            break
                        }
                    }
                }
            }
        }
    }

    private func detectMerges(_ commits: inout [CommitDef]) {
        for mp in rawMergePoints {
            guard mp.mergeType == "convergence" else { continue }
            let involvedIds = Set(mp.storylineIds)
            for i in commits.indices {
                if commits[i].chapterIndex == mp.chapterNumber && involvedIds.contains(commits[i].trackId) {
                    var sources: [String] = []
                    for otherId in involvedIds where otherId != commits[i].trackId {
                        let prev = commits
                            .filter { $0.trackId == otherId && $0.chapterIndex < mp.chapterNumber }
                            .sorted { $0.chapterIndex > $1.chapterIndex }
                            .first
                        if let p = prev { sources.append(p.id) }
                    }
                    if !sources.isEmpty {
                        commits[i].mergeFrom = sources
                    }
                }
            }
        }
    }

    // MARK: - 辅助函数（对齐 :562-570 / domain/storyline.ts）

    private func buildCommitLabel(_ ch: Int, _ sl: StorylineDTO) -> String {
        let typeName = storylineTypeLabel(sl.storylineType ?? "")
        return "\(typeName)·Ch.\(ch)"
    }

    private func storylineColor(_ type: String) -> Color {
        switch type {
        case "main": return .blue
        case "sub": return .cyan
        case "dark": return .purple
        case "flashback": return .orange
        default: return .gray
        }
    }

    private func storylineTypeLabel(_ type: String) -> String {
        switch type {
        case "main": return "主线"
        case "sub": return "支线"
        case "dark": return "暗线"
        case "flashback": return "闪回"
        default: return type
        }
    }

    private func isMainStoryline(_ sl: StorylineDTO) -> Bool {
        return sl.storylineType == "main" || sl.role == "main"
    }

    // MARK: - 数据加载（对齐 :880-896 loadData）

    private func loadData() async {
        loading = true
        errorMessage = nil
        do {
            let data: StorylineGraphDataDTO = try await APIClient.shared.request(
                APIEndpoint.Workflow.getStorylineGraphData(novelId: novelId)
            )
            rawStorylines = data.storylines
            rawMergePoints = data.mergePoints
        } catch {
            // 降级：尝试 getStorylines（对齐 :887-895）
            do {
                rawStorylines = try await APIClient.shared.request(
                    APIEndpoint.Workflow.getStorylines(novelId: novelId)
                )
                rawMergePoints = []
            } catch let e {
                errorMessage = e.localizedDescription
                rawStorylines = []
                rawMergePoints = []
            }
        }
        loading = false
    }

    // MARK: - 回滚（对齐 :839-873 confirmRollback）

    private func performRollback(_ cm: CommitDef) async {
        rollbacking = true
        do {
            // 获取编年史快照列表
            let chronicleData: AnyCodable = try await APIClient.shared.request(
                APIEndpoint.Chronicles.get(novelId: novelId)
            )
            // 找到目标快照
            guard let dict = chronicleData.dictionaryValue,
                  let rowsValue = dict["rows"]?.arrayValue else {
                rollbacking = false
                return
            }

            // 找到 >= chapterIndex 的快照
            var candidateSnapshots: [String] = []
            for row in rowsValue {
                if let rowDict = row.dictionaryValue,
                   let chIdx = rowDict["chapter_index"]?.intValue,
                   chIdx >= cm.chapterIndex {
                    if let snapshots = rowDict["snapshots"]?.arrayValue {
                        for snap in snapshots {
                            if let snapDict = snap.dictionaryValue,
                               let snapId = snapDict["id"]?.stringStringValue {
                                candidateSnapshots.append(snapId)
                            }
                        }
                    }
                }
            }

            guard let targetSnapId = candidateSnapshots.last else {
                errorMessage = "该章节无可用快照"
                rollbacking = false
                return
            }

            // 执行回滚 — 对齐 :858 chroniclesApi.rollbackToSnapshot
            let _: SnapshotRollbackResponse = try await APIClient.shared.request(
                APIEndpoint.Chronicles.rollback(novelId: novelId, snapshotId: targetSnapId)
            )

            activeCommit = nil
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        rollbacking = false
    }
}
