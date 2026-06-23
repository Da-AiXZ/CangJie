//
//  TraceRecordView.swift
//  Cangjie
//
//  AI Trace 溯源：span 瀑布图（垂直时间轴，每条 span 一条彩色条，
//  颜色按 LLM 端点着色，宽度=耗时），点击 span 展开详情。
//  调 TraceStore。
//

import SwiftUI

/// AI Trace 溯源视图
struct TraceRecordView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var store = TraceStore()

    @State private var selectedSpan: AiTraceSpan?
    @State private var selectedTraceId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Trace 摘要列表
            if selectedTraceId == nil {
                traceList
            } else {
                // 时间线详情
                timelineDetail
            }
        }
        .navigationTitle("AI Trace")
        .task {
            if let novelId = appState.currentNovelId {
                await store.loadAITraces(novelId: novelId)
            }
        }
        .sheet(item: $selectedSpan) { span in
            spanDetailSheet(span)
        }
    }

    // MARK: - Trace 列表

    private var traceList: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                if store.aiTraces.isEmpty {
                    emptyState("暂无 AI Trace 记录", icon: "waveform.path")
                } else {
                    ForEach(store.aiTraces) { trace in
                        traceRow(trace)
                    }
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.background)
    }

    private func traceRow(_ trace: AiTraceSummary) -> some View {
        Button {
            selectedTraceId = trace.traceId
            if let novelId = appState.currentNovelId {
                Task { await store.loadTimeline(novelId: novelId, traceId: trace.traceId) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: trace.errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(trace.errorCount > 0 ? Theme.error : Theme.success)
                        .font(.system(size: 12))
                    Text(trace.traceId.prefix(12).description)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                    Spacer()
                    Text(trace.operation)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                HStack(spacing: Theme.Spacing.md) {
                    Label("\(trace.spanCount) span", systemImage: "rectangle.split.3x1").font(.system(size: 10)).foregroundColor(Theme.textSecondary)
                    if trace.errorCount > 0 {
                        Label("\(trace.errorCount) 错误", systemImage: "xmark.circle").font(.system(size: 10)).foregroundColor(Theme.error)
                    }
                    Spacer()
                    Text(formatRelativeTime(trace.startedAt)).font(.system(size: 9)).foregroundColor(Theme.textTertiary)
                }
            }
            .cardStyle(padding: Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 时间线详情

    private var timelineDetail: some View {
        VStack(spacing: 0) {
            // 返回按钮
            HStack {
                Button { selectedTraceId = nil } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回列表")
                    }
                    .font(.system(size: 12))
                }
                Spacer()
                if let tl = store.timeline {
                    Text("\(tl.spans.count) spans · \(tl.total) 条")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.secondaryBackground)

            // 瀑布图
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let tl = store.timeline {
                        // 计算时间范围
                        let allLatencies = tl.spans.compactMap { $0.latencyMs }
                        let maxLatency = max(1, allLatencies.max() ?? 100)
                        let sortedSpans = tl.spans.sorted { ($0.latencyMs ?? 0) > ($1.latencyMs ?? 0) }

                        ForEach(sortedSpans) { span in
                            waterfallRow(span, maxLatency: maxLatency)
                        }
                    } else if store.isLoading {
                        ProgressView("加载中…")
                    }
                }
                .padding(Theme.Spacing.md)
            }
        }
        .background(Theme.background)
    }

    // MARK: - 瀑布行

    private func waterfallRow(_ span: AiTraceSpan, maxLatency: Int) -> some View {
        let widthRatio = CGFloat(span.latencyMs ?? 0) / CGFloat(maxLatency)
        let barColor = spanColor(span)

        return Button {
            selectedSpan = span
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                // 标题行
                HStack(spacing: 4) {
                    Image(systemName: phaseIcon(span.phase))
                        .font(.system(size: 9))
                        .foregroundColor(barColor)
                    Text(span.operation)
                        .font(.system(size: 11, weight: .medium))
                    if let model = span.model {
                        Text(model)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textTertiary)
                    }
                    Spacer()
                    if let latency = span.latencyMs {
                        Text("\(latency)ms")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                // 代理行
                HStack(spacing: 4) {
                    Text(span.phase)
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(barColor.opacity(0.15))
                        .cornerRadius(3)

                    if span.error != nil {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Theme.error)
                    }
                }

                // 彩色条（宽度=耗时比例）
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor.opacity(0.12))
                            .frame(width: geo.size.width, height: 6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: max(4, geo.size.width * widthRatio), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.vertical, 4)

            Divider()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Span 详情 Sheet

    private func spanDetailSheet(_ span: AiTraceSpan) -> some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    LabeledContent("Phase", value: span.phase)
                    LabeledContent("Operation", value: span.operation)
                    if let nodeType = span.nodeType { LabeledContent("Node", value: nodeType) }
                    if let model = span.model { LabeledContent("Model", value: model) }
                    if let latency = span.latencyMs { LabeledContent("Latency", value: "\(latency)ms") }
                    if let input = span.tokenInput { LabeledContent("Input Tokens", value: "\(input)") }
                    if let output = span.tokenOutput { LabeledContent("Output Tokens", value: "\(output)") }
                    if let error = span.error { LabeledContent("Error", value: error) }
                }

                if let preview = span.promptPreview {
                    Section("Prompt Preview") {
                        Text(preview.stringValue)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                if let response = span.responsePreview {
                    Section("Response Preview") {
                        Text(response.stringValue)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                if let source = span.source {
                    Section("Source") { Text(source).font(.system(size: 11)) }
                }
            }
            .navigationTitle("Span 详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("关闭") { selectedSpan = nil } } }
        }
    }

    // MARK: - 辅助

    private func spanColor(_ span: AiTraceSpan) -> Color {
        if span.error != nil { return Theme.error }
        switch span.phase {
        case "context": return Theme.info
        case "execution", "writer": return Theme.primary
        case "validation", "tension", "style": return Theme.warning
        case "gateway", "breaker": return Theme.error
        case "review": return Theme.success
        default: return Theme.textSecondary
        }
    }

    private func phaseIcon(_ phase: String) -> String {
        switch phase {
        case "context": return "book.fill"
        case "execution", "writer": return "pencil.line"
        case "validation", "tension": return "checkmark.seal.fill"
        case "gateway": return "flag.checkered"
        case "review": return "eye.fill"
        default: return "circle.fill"
        }
    }

    private func emptyState(_ msg: String, icon: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 40)).foregroundColor(Theme.textTertiary)
            Text(msg).font(Theme.bodyFont()).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatRelativeTime(_ dateStr: String) -> String {
        let df = ISO8601DateFormatter()
        guard let date = df.date(from: dateStr) ?? ISODateFormatter.date(from: dateStr) else { return dateStr }
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        return "\(Int(interval / 86400))天前"
    }
}
