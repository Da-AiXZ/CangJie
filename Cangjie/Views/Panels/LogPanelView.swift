//
//  LogPanelView.swift
//  Cangjie
//
//  实时日志面板（A-6），对齐原版 components/panels/LogPanel.vue。
//  U1 决策：移植为独立孤立组件，完整实现 API（addLog/clearLogs/autoScroll/500 上限/4 级颜色/HH:MM:SS）。
//  原项目 LogPanel.vue 是孤立组件（defineExpose 暴露 addLog 但全前端无调用方），仓颉保持孤立。
//

import SwiftUI

// MARK: - 日志级别

/// 日志级别，对齐原版 LogPanel.vue:40-42 LogEntry.level
/// 注：原版 LogEntry 为 API 层模型（JobModels.LogEntry，Codable），
/// 此处 LogLevel 为面板 UI 专用，与 JobModels.LogEntry.level（String）不同。
enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case debug = "DEBUG"
    case error = "ERROR"
    case warning = "WARNING"

    /// 级别颜色，对齐原版 LogPanel.vue:187-201
    var color: Color {
        switch self {
        case .info: return Color(red: 0x4e/255, green: 0xc9/255, blue: 0xb0/255)    // #4ec9b0
        case .debug: return Color(red: 0x9c/255, green: 0xdc/255, blue: 0xfe/255)    // #9cdcfe
        case .error: return Color(red: 0xf4/255, green: 0x87/255, blue: 0x71/255)    // #f48771
        case .warning: return Color(red: 0xdc/255, green: 0xdc/255, blue: 0xaa/255)  // #dcdcaa
        }
    }
}

// MARK: - 日志条目

/// 面板日志条目，对齐原版 LogPanel.vue:38-42 LogEntry 的 UI 展示结构。
///
/// 注意：与 `JobModels.LogEntry`（API 层 Codable 模型，字段 timestamp/level/logger/message）
/// 是不同类型。本类型为面板 UI 专用（UUID 标识 + LogLevel 枚举），避免与 API 模型重名冲突。
struct LogPanelEntry: Identifiable, Equatable {
    let id = UUID()
    let time: String
    let level: LogLevel
    let message: String
}

// MARK: - 日志面板状态

/// 日志面板状态，管理日志列表、自动滚动等。
/// 对齐原版 LogPanel.vue:44-77 的响应式状态 + 方法。
final class LogPanelState: ObservableObject {

    /// 日志列表（最多 500 条）— LogPanel.vue:44
    @Published var logs: [LogPanelEntry] = []

    /// 自动滚动开关 — LogPanel.vue:46
    @Published var autoScroll: Bool = true

    /// 日志上限 — LogPanel.vue:60
    private let maxLogs = 500

    /// 标准化日志级别 — LogPanel.vue:48-52
    private func normalizeLevel(_ level: String) -> LogLevel {
        let u = level.uppercased()
        if let logLevel = LogLevel(rawValue: u) {
            return logLevel
        }
        return .info
    }

    /// 生成 HH:MM:SS 时间戳 — LogPanel.vue:55-56
    private func currentTimeString() -> String {
        let now = Date()
        let calendar = Calendar.current
        let hour = String(format: "%02d", calendar.component(.hour, from: now))
        let minute = String(format: "%02d", calendar.component(.minute, from: now))
        let second = String(format: "%02d", calendar.component(.second, from: now))
        return "\(hour):\(minute):\(second)"
    }

    /// 添加日志 — LogPanel.vue:54-69
    /// - Parameters:
    ///   - level: 日志级别字符串
    ///   - message: 日志消息
    func addLog(level: String, message: String) {
        let entry = LogPanelEntry(
            time: currentTimeString(),
            level: normalizeLevel(level),
            message: message
        )
        logs.append(entry)

        // 超过上限移除最早 — LogPanel.vue:60-62
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    /// 清空日志 — LogPanel.vue:71-73
    func clearLogs() {
        logs.removeAll()
    }

    /// 切换自动滚动 — LogPanel.vue:75-77
    func toggleAutoScroll() {
        autoScroll.toggle()
    }
}

// MARK: - 日志面板视图

/// 实时日志面板，对齐原版 components/panels/LogPanel.vue。
///
/// U1 决策：孤立组件，API 同原版（addLog/clearLogs/autoScroll/500 上限/4 级颜色/HH:MM:SS）。
/// 不发明数据源（原项目也从未接线调用方）。
struct LogPanelView: View {

    @StateObject private var state = LogPanelState()

    var body: some View {
        VStack(spacing: 0) {
            // 头部 — LogPanel.vue:3-14
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.green.opacity(0.6), radius: 5)

                    Text("实时日志")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("清空") {
                        state.clearLogs()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(state.autoScroll ? "自动滚屏开" : "自动滚屏关") {
                        state.toggleAutoScroll()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(state.autoScroll ? Theme.primary : nil)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.25))

            Divider()
                .background(Color.white.opacity(0.08))

            // 空状态 — LogPanel.vue:16
            if state.logs.isEmpty {
                Text("连接建立后，后端日志会显示在这里")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0x64/255, green: 0x74/255, blue: 0x8b/255))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            } else {
                // 日志列表 — LogPanel.vue:18-31
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(state.logs) { log in
                                HStack(spacing: 10) {
                                    Text(log.time)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Color(red: 0x64/255, green: 0x74/255, blue: 0x8b/255))
                                        .frame(minWidth: 64, alignment: .leading)

                                    Text(log.level.rawValue)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(log.level.color)
                                        .frame(minWidth: 60, alignment: .leading)

                                    Text(log.message)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(Color(red: 0xcb/255, green: 0xd5/255, blue: 0xe1/255))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(state.logs.last?.id == log.id ? Color.white.opacity(0.04) : Color.clear)
                                .cornerRadius(3)
                                .id(log.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: state.logs.count) { _ in
                        if state.autoScroll, let lastId = state.logs.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0x1a/255, green: 0x1d/255, blue: 0x24/255),
                    Color(red: 0x0f/255, green: 0x11/255, blue: 0x15/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
