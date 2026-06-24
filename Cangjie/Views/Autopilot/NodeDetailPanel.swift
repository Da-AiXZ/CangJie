//
//  NodeDetailPanel.swift
//  Cangjie
//
//  DAG 节点详情面板（.sheet 呈现）。
//  对齐 NodeDetailPanel.vue:1-465（32条功能点）。
//  决策6：用 .sheet 呈现。决策9：写作遥测2500ms独立轮询。决策10：404不停止轮询。
//

import SwiftUI

/// DAG 节点详情面板 — 对齐 NodeDetailPanel.vue:1-465
struct NodeDetailPanel: View {

    // MARK: - Props（对齐 NodeDetailPanel.vue:148-152 defineProps）

    /// 小说 ID
    let novelId: String
    /// 节点 ID
    let nodeId: String

    // MARK: - 环境

    @EnvironmentObject var dagStore: DAGStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - 提示词状态（对齐 NodeDetailPanel.vue:161-162）

    @State private var promptLive: NodePromptLive?
    @State private var promptLoading: Bool = false

    // MARK: - 写作遥测状态（对齐 NodeDetailPanel.vue:165-166）

    /// GET /autopilot/{id}/status 拉取的实时块
    @State private var writingStatus: AutopilotStatus?
    /// 轮询错误信息
    @State private var writingPollError: String = ""
    /// 轮询 Task
    @State private var pollingTask: Task<Void, Never>?

    // MARK: - NodeEditorDrawer

    @State private var showEditorDrawer: Bool = false

    // MARK: - 常量

    /// 写作遥测节点类型 — 对齐 NodeDetailPanel.vue:168 WRITING_TELEMETRY_TYPES
    private let writingTelemetryTypes: Set<String> = ["exec_writer", "exec_beat"]
    /// 轮询间隔 2500ms — 决策9
    private let pollingIntervalMs: UInt64 = 2_500_000_000

    // MARK: - 计算属性

    /// 节点定义 — 对齐 NodeDetailPanel.vue:172-175 nodeDef
    private var nodeDef: NodeDefinition? {
        dagStore.dagDefinition?.nodes.first { $0.id == nodeId }
    }

    /// 节点是否启用 — 对齐 NodeDetailPanel.vue:177 nodeEnabled
    private var nodeEnabled: Bool {
        nodeDef?.enabled ?? true
    }

    /// 节点元数据 — 对齐 NodeDetailPanel.vue:179-182 meta
    private var meta: NodeMeta? {
        guard let nodeDef = nodeDef else { return nil }
        return dagStore.nodeTypeRegistry[nodeDef.type]
    }

    /// 是否显示写作遥测 — 对齐 NodeDetailPanel.vue:186-189 showWritingTelemetry
    private var showWritingTelemetry: Bool {
        guard let nodeType = meta?.nodeType else { return false }
        return writingTelemetryTypes.contains(nodeType)
    }

    /// 运行时状态 — 对齐 NodeDetailPanel.vue:229-232 runState
    private var runState: NodeRunState? {
        dagStore.nodeStates[nodeId]
    }

    /// 状态 — 对齐 NodeDetailPanel.vue:234-237 status
    private var status: String {
        if !nodeEnabled { return "disabled" }
        return runState?.status ?? "idle"
    }

    /// 是否运行中 — 对齐 NodeDetailPanel.vue:239 isRunning
    private var isRunning: Bool {
        status == "running"
    }

    /// 面板标题 — 对齐 NodeDetailPanel.vue:243-246 panelTitle
    private var panelTitle: String {
        meta?.displayName ?? nodeId
    }

    /// 状态条背景色 — 对齐 NodeDetailPanel.vue:250-262 STATUS_BAR_BG_MAP
    private var statusBarColor: Color {
        switch status {
        case "idle", "pending": return Color.gray.opacity(0.08)
        case "running": return Theme.statusRunning.opacity(0.12)
        case "success", "completed": return Theme.statusSuccess.opacity(0.12)
        case "warning": return Theme.statusWarning.opacity(0.12)
        case "error": return Theme.statusError.opacity(0.12)
        case "bypassed", "disabled": return Color.gray.opacity(0.06)
        default: return Color.gray.opacity(0.08)
        }
    }

    /// 状态标签 — 对齐 NodeDetailPanel.vue:264-274 STATUS_LABEL_MAP
    private var statusLabel: String {
        switch status {
        case "idle": return "⏹ 空闲"
        case "pending": return "⏳ 等待中"
        case "running": return "▶️ 运行中"
        case "success": return "成功"
        case "warning": return "警告"
        case "error": return "错误"
        case "bypassed": return "⏭ 已旁路"
        case "disabled": return "已禁用"
        case "completed": return "已完成"
        default: return status
        }
    }

    /// 分类标签 — 对齐 NodeDetailPanel.vue:290-293 categoryLabel
    private var categoryLabel: String {
        guard let meta = meta else { return "" }
        return CATEGORY_LABELS[meta.category] ?? meta.category
    }

    /// 提示词来源标签 — 对齐 NodeDetailPanel.vue:297-305 sourceLabel
    private var sourceLabel: String {
        guard let promptLive = promptLive else { return "" }
        switch promptLive.source {
        case "cpms": return "CPMS 广场"
        case "config": return "节点配置"
        case "meta": return "节点默认"
        case "none": return "无"
        default: return promptLive.source
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let meta = meta {
                        nodeDetailContent(meta: meta)
                    } else {
                        // 对齐 NodeDetailPanel.vue:116-118 detail-empty
                        Text("未找到节点信息")
                            .foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(16)
            }
            .navigationTitle(panelTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                footerView
            }
        }
        .onAppear {
            loadPromptLive()
            startWritingTelemetryPolling()
        }
        .onDisappear {
            stopWritingTelemetryPolling()
        }
        .onChange(of: nodeId) { _ in
            // 对齐 NodeDetailPanel.vue:308-319 节点切换时重新加载
            promptLive = nil
            loadPromptLive()
            stopWritingTelemetryPolling()
            startWritingTelemetryPolling()
        }
        .sheet(isPresented: $showEditorDrawer) {
            // 决策8：NodeDetailPanel底部"配置运行参数"按钮触发NodeEditorDrawer
            NodeEditorDrawer(
                novelId: novelId,
                nodeId: nodeId
            )
            .environmentObject(dagStore)
        }
    }

    // MARK: - 节点详情内容（对齐 NodeDetailPanel.vue:12-113）

    @ViewBuilder
    private func nodeDetailContent(meta: NodeMeta) -> some View {
        // ① Dify 风格状态条 — 对齐 NodeDetailPanel.vue:14-22
        statusBarView(meta: meta)

        // ② 基本信息 — 对齐 NodeDetailPanel.vue:24-35
        basicInfoSection(meta: meta)

        // ③ CPMS 提示词来源 — 对齐 NodeDetailPanel.vue:37-55
        promptSourceSection()

        // ④ 提示词预览 — 对齐 NodeDetailPanel.vue:57-63
        if let promptLive = promptLive, !promptLive.system.isEmpty {
            promptPreviewSection(system: promptLive.system)
        }

        // ⑤ 端口信息 — 对齐 NodeDetailPanel.vue:65-80
        portInfoSection(meta: meta)

        // ⑥ 全托管写作遥测 — 对齐 NodeDetailPanel.vue:82-97
        if showWritingTelemetry {
            writingTelemetrySection()
        }

        // ⑦ 默认下游 — 对齐 NodeDetailPanel.vue:99-113
        if !meta.defaultEdges.isEmpty {
            defaultEdgesSection(meta: meta)
        }
    }

    // MARK: - ① 状态条（对齐 NodeDetailPanel.vue:14-22）

    @ViewBuilder
    private func statusBarView(meta: NodeMeta) -> some View {
        HStack(spacing: 8) {
            // 对齐 NodeDetailPanel.vue:15 status-icon
            if !meta.icon.isEmpty {
                Text(meta.icon)
                    .font(.system(size: 18))
            }
            // 对齐 NodeDetailPanel.vue:16 status-label
            Text(statusLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            // 对齐 NodeDetailPanel.vue:17 已禁用 tag
            if !nodeEnabled {
                Text("已禁用")
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
            } else if isRunning {
                // 对齐 NodeDetailPanel.vue:18-21 运行中 tag
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("运行中")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Theme.statusRunning.opacity(0.15))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(statusBarColor)
        .cornerRadius(8)
    }

    // MARK: - ② 基本信息（对齐 NodeDetailPanel.vue:24-35）

    @ViewBuilder
    private func basicInfoSection(meta: NodeMeta) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("基本信息")
            // 对齐 NodeDetailPanel.vue:27-34 detail-grid
            infoRow("节点类型", meta.nodeType, isCode: true)
            infoRow("分类", categoryLabel)
            infoRow("描述", meta.description.isEmpty ? "无" : meta.description)
        }
    }

    // MARK: - ③ CPMS 提示词来源（对齐 NodeDetailPanel.vue:37-55）

    @ViewBuilder
    private func promptSourceSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("提示词来源")
            if let promptLive = promptLive {
                // 对齐 NodeDetailPanel.vue:40-52 detail-grid
                infoRow("CPMS Key", promptLive.cpmsNodeKey.isEmpty ? "无" : promptLive.cpmsNodeKey, isCode: true)
                infoRow("来源", sourceLabel)
            } else if promptLoading {
                // 对齐 NodeDetailPanel.vue:53
                Text("加载中...")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            } else {
                // 对齐 NodeDetailPanel.vue:54
                Text("点击节点查看提示词来源")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - ④ 提示词预览（对齐 NodeDetailPanel.vue:57-63）

    @ViewBuilder
    private func promptPreviewSection(system: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("提示词预览")
            // 对齐 NodeDetailPanel.vue:60-62 system.slice(0, 500)
            Text(String(system.prefix(500)) + (system.count > 500 ? "..." : ""))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.secondaryBackground)
                .cornerRadius(8)
        }
    }

    // MARK: - ⑤ 端口信息（对齐 NodeDetailPanel.vue:65-80）

    @ViewBuilder
    private func portInfoSection(meta: NodeMeta) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("端口")
            // 对齐 NodeDetailPanel.vue:68-73 input_ports
            if !meta.inputPorts.isEmpty {
                portRow(label: "输入：", ports: meta.inputPorts, color: Theme.textTertiary)
            }
            // 对齐 NodeDetailPanel.vue:74-79 output_ports
            if !meta.outputPorts.isEmpty {
                portRow(label: "输出：", ports: meta.outputPorts, color: Theme.info)
            }
        }
    }

    // MARK: - ⑥ 写作遥测（对齐 NodeDetailPanel.vue:82-97）

    @ViewBuilder
    private func writingTelemetrySection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("全托管写作遥测")
            // 对齐 NodeDetailPanel.vue:85 writingPollError
            if !writingPollError.isEmpty {
                Text(writingPollError)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            } else if let ws = writingStatus {
                // 对齐 NodeDetailPanel.vue:86-95 detail-grid
                infoRow("阶段", ws.currentStage.isEmpty ? "—" : ws.currentStage)
                // 对齐 NodeDetailPanel.vue:90 writing_substep_label
                infoRow("子步骤", ws.writingSubstepLabel ?? ws.writingSubstep ?? "—")
                // 对齐 NodeDetailPanel.vue:91-92 accumulated_words / chapter_target_words
                infoRow("章节字数", "\(ws.accumulatedWords ?? 0) / \(ws.chapterTargetWords ?? 0)")
                // 对齐 NodeDetailPanel.vue:93-94 context_tokens
                infoRow("上下文 token", "\(ws.contextTokens ?? 0)")
            } else {
                // 对齐 NodeDetailPanel.vue:96
                Text("加载中…")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    // MARK: - ⑦ 默认下游（对齐 NodeDetailPanel.vue:99-113）

    @ViewBuilder
    private func defaultEdgesSection(meta: NodeMeta) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("默认下游")
            // 对齐 NodeDetailPanel.vue:102-112 default-edges tags
            FlowLayout(spacing: 4) {
                ForEach(meta.defaultEdges, id: \.self) { target in
                    Text(getNodeLabel(target))
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.info.opacity(0.12))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - 底部（对齐 NodeDetailPanel.vue:120-134 footer）

    @ViewBuilder
    private var footerView: some View {
        HStack {
            // 对齐 NodeDetailPanel.vue:123-130 启禁用 Switch（can_disable 条件）
            if meta?.canDisable == true {
                HStack(spacing: 8) {
                    Text("启用节点")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                    Toggle("", isOn: Binding(
                        get: { nodeEnabled },
                        set: { _ in handleToggleNode() }
                    ))
                    .labelsHidden()
                    .scaleEffect(0.8)
                }
            }
            Spacer()
            // 决策8：配置运行参数按钮（打开NodeEditorDrawer）
            Button {
                showEditorDrawer = true
            } label: {
                Text("配置运行参数")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.bordered)
            // 对齐 NodeDetailPanel.vue:132 关闭按钮
            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.secondaryBackground)
    }

    // MARK: - 辅助视图

    /// 区块标题 — 对齐 NodeDetailPanel.vue:381-387 .section-title
    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .textCase(.uppercase)
    }

    /// 信息行 — 对齐 NodeDetailPanel.vue:389-407 .detail-grid
    private func infoRow(_ label: String, _ value: String, isCode: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            if isCode {
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(2)
            } else {
                Text(value)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
        }
    }

    /// 端口行 — 对齐 NodeDetailPanel.vue:68-79 port-row
    private func portRow(label: String, ports: [NodePort], color: Color) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 36, alignment: .leading)
            FlowLayout(spacing: 4) {
                ForEach(ports, id: \.name) { port in
                    Text(port.name)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .cornerRadius(6)
                }
            }
        }
    }

    /// 获取节点标签 — 对齐 NodeDetailPanel.vue:333-336 getNodeLabel
    private func getNodeLabel(_ type: String) -> String {
        return dagStore.nodeTypeRegistry[type]?.displayName ?? type
    }

    // MARK: - 加载提示词（对齐 NodeDetailPanel.vue:308-331 watch nodeId/show）

    private func loadPromptLive() {
        guard !nodeId.isEmpty else { return }
        promptLoading = true
        Task {
            // 对齐 NodeDetailPanel.vue:314 dagStore.loadNodePromptLive
            let result = await dagStore.loadNodePromptLive(novelId: novelId, nodeId: nodeId)
            await MainActor.run {
                self.promptLive = result
                self.promptLoading = false
            }
        }
    }

    // MARK: - 写作遥测轮询（决策9+10）

    /// 启动写作遥测轮询 — 2500ms 硬编码，404 不停止
    private func startWritingTelemetryPolling() {
        // 对齐 NodeDetailPanel.vue:216-227 watch → 只有 show && telemetry 时才启动
        guard showWritingTelemetry else { return }
        guard !novelId.isEmpty else { return }

        pollingTask = Task {
            // 立即执行一次
            await fetchWritingTelemetry()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: pollingIntervalMs)
                guard !Task.isCancelled else { break }
                await fetchWritingTelemetry()
            }
        }
    }

    /// 停止轮询
    private func stopWritingTelemetryPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// 拉取写作遥测 — 对齐 NodeDetailPanel.vue:191-209 fetchWritingTelemetry
    private func fetchWritingTelemetry() async {
        do {
            let raw: AnyCodable = try await APIClient.shared.request(
                APIEndpoint.Autopilot.status(novelId: novelId)
            )
            if let data = try? JSONSerialization.data(withJSONObject: raw.value) {
                let status = try? CangjieDecoder.shared.decode(AutopilotStatus.self, from: data)
                await MainActor.run {
                    self.writingStatus = status
                    self.writingPollError = ""
                }
            }
        } catch let error as APIError {
            // 决策10：404 显示"该书暂无托管状态"但不停止轮询
            // 对齐 NodeDetailPanel.vue:197-200 isAutopilotNotFoundError
            if case .notFound = error {
                await MainActor.run {
                    self.writingStatus = nil
                    self.writingPollError = "该书暂无托管状态"
                }
                return
            }
            // 其他错误 — 对齐 NodeDetailPanel.vue:202-208
            await MainActor.run {
                self.writingPollError = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                self.writingPollError = error.localizedDescription
            }
        }
    }

    // MARK: - 节点启禁用（对齐 NodeDetailPanel.vue:340-344 handleToggleNode）

    private func handleToggleNode() {
        Task {
            await dagStore.toggleNode(novelId: novelId, nodeId: nodeId)
        }
    }
}

// MARK: - FlowLayout（简单的流式布局，用于端口标签和默认下游）

/// 简单的水平流式布局，自动换行
struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth && lineWidth > 0 {
                totalWidth = max(totalWidth, lineWidth)
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalWidth = max(totalWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
