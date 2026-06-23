//
//  AutopilotLogStream.swift
//  Cangjie
//
//  日志流 ScrollView：终端等宽字体，SSE 接收 log-stream，按 level 着色，自动滚底。
//  对齐 Vue3 AutopilotTerminalLog.vue 的终端样式 + 筛选 + 自动滚底。
//

import SwiftUI

/// 自动驾驶日志流
struct AutopilotLogStream: View {

    let novelId: String

    @EnvironmentObject var autopilotStore: AutopilotStore

    @State private var autoScroll: Bool = true
    @State private var searchText: String = ""
    @State private var hideHttp: Bool = false
    @State private var importantOnly: Bool = false

    // MARK: - 筛选

    /// 筛选后的日志
    private var filteredLogs: [LogStreamEvent] {
        var result = autopilotStore.logs

        // 隐藏 HTTP
        if hideHttp {
            result = result.filter { !($0.message ?? "").lowercased().contains("http") }
        }

        // 只看重要
        if importantOnly {
            result = result.filter { event in
                let level = event.level?.lowercased() ?? ""
                return level == "error" || level == "warning" || level == "critical"
            }
        }

        // 搜索
        if !searchText.isEmpty {
            result = result.filter { event in
                (event.message ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            // 筛选栏
            filterBar

            // 日志列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if filteredLogs.isEmpty {
                            Text("暂无日志")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(Theme.textTertiary)
                                .padding(Theme.Spacing.lg)
                        } else {
                            ForEach(filteredLogs.indices, id: \.self) { index in
                                logRow(filteredLogs[index])
                                    .id(index)
                            }

                            // 底部锚点
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .padding(Theme.Spacing.xs)
                }
                .background(Color.black.opacity(0.9))
                .onChange(of: filteredLogs.count) { _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }

            // 底部状态
            bottomStatusBar
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(Theme.CornerRadius.medium)
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // SSE 连接指示灯
            Circle()
                .fill(autopilotStore.sseConnected ? Theme.success : Theme.error)
                .frame(width: 6, height: 6)

            Text("实时日志")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // 日志计数
            Text("\(filteredLogs.count)/\(autopilotStore.logs.count) 行")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Theme.textTertiary)

            // 回到底部按钮
            if !autoScroll {
                Button("回到底部") {
                    autoScroll = true
                }
                .font(.system(size: 10))
                .foregroundColor(Theme.info)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - 筛选栏

    private var filterBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // 搜索
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                TextField("搜索…", text: $searchText)
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.1))
            .cornerRadius(4)

            // 筛选按钮
            filterChip("隐藏 HTTP", isOn: $hideHttp)
            filterChip("只看重要", isOn: $importantOnly)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))
    }

    // MARK: - 底部状态

    private var bottomStatusBar: some View {
        HStack {
            Toggle("自动滚底", isOn: $autoScroll)
                .font(.system(size: 10))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.success)

            Spacer()

            Text("after_seq 断点续传")
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - 日志行

    private func logRow(_ event: LogStreamEvent) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // 时间
            if let timestamp = event.timestamp, !timestamp.isEmpty {
                Text(formatTime(timestamp))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.gray)
                    .frame(width: 60, alignment: .leading)
            }

            // 级别
            if let level = event.level, !level.isEmpty {
                Text(level.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(levelColor(level))
                    .frame(width: 50, alignment: .leading)
            }

            // 消息
            Text(event.message ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(messageColor(event.level))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
    }

    // MARK: - 辅助

    private func filterChip(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 10))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isOn.wrappedValue ? Theme.primary.opacity(0.3) : Color.white.opacity(0.1))
                .foregroundColor(isOn.wrappedValue ? Theme.primary : .white)
                .cornerRadius(4)
        }
    }

    /// 日志级别颜色
    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "error", "critical": return Color.red
        case "warning", "warn": return Color.yellow
        case "info": return Color.green
        case "debug": return Color.gray
        default: return Color.white
        }
    }

    /// 消息颜色
    private func messageColor(_ level: String?) -> Color {
        guard let level = level?.lowercased() else { return Color.white }
        switch level {
        case "error", "critical": return Color(red: 1.0, green: 0.6, blue: 0.6)
        case "warning", "warn": return Color(red: 1.0, green: 0.9, blue: 0.5)
        default: return Color.white.opacity(0.9)
        }
    }

    /// 格式化时间
    private func formatTime(_ timestamp: String) -> String {
        // 取后 8 位（时间部分）
        if timestamp.count > 8 {
            return String(timestamp.suffix(8))
        }
        return timestamp
    }
}
